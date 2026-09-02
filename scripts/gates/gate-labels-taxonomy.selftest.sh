#!/usr/bin/env bash
# Self-test for gate-labels-taxonomy.sh, on throwaway copies of the issue forms.
#
# The failure this gate prevents is silent by construction: if an issue form
# applies a label that scripts/gh/labels.sh does not declare, GitHub DROPS it
# without a word and the issue arrives unclassified. Deterministic triage stops
# working and nothing says so. A gate against a silent failure that has never
# been observed failing is worth exactly as much as no gate.
#
# This gate resolves its root from its own location and takes no override, so
# each case copies the gate INTO a throwaway tree and runs it from there rather
# than changing the gate to be testable.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/selftest-root.sh" 2>/dev/null || {
  echo "UNMEASURABLE the root guard is missing at $HERE/lib/selftest-root.sh"; exit 2; }
ROOT="$(ehs_selftest_root --here "$HERE")" || exit 2
GATE_REL="scripts/gates/gate-labels-taxonomy.sh"
[ -f "$ROOT/$GATE_REL" ] || { echo "UNMEASURABLE $GATE_REL is missing"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
python3 -c 'import yaml' 2>/dev/null || { echo "UNMEASURABLE PyYAML is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-labels-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

build_repo() {  # <dir> — everything this gate reads, copied from the real tree
  local d="$1" f
  mkdir -p "$d/scripts/gates" "$d/scripts/gh" "$d/.github/ISSUE_TEMPLATE"
  cp "$ROOT/$GATE_REL" "$d/$GATE_REL"
  for f in scripts/gates/gate-issue-closure.sh scripts/gh/labels.sh scripts/gh/governance.json; do
    [ -f "$ROOT/$f" ] && cp "$ROOT/$f" "$d/$f"
  done
  cp "$ROOT"/.github/ISSUE_TEMPLATE/* "$d/.github/ISSUE_TEMPLATE/" 2>/dev/null || true
}

run_case() {  # <name> <expected rc> <needle> <mutation>
  local name="$1" want="$2" needle="$3" mutate="$4"
  local d="$TMP/$name"; rm -rf "$d"; mkdir -p "$d"
  build_repo "$d"
  "$mutate" "$d"
  local out rc=0
  out="$(bash "$d/$GATE_REL" 2>&1)" || rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -qi -- "$needle"; }; then
    printf 'ok       %-36s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-36s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | grep -iE 'could not measure|- ' | sed 's/^/         /' | head -4; fail=$((fail+1))
  fi
}

# edit_form <dir> <python-expression-over-`doc`> — first form, rewritten in place
edit_form() {
  local d="$1" expr="$2"
  FORM_DIR="$d/.github/ISSUE_TEMPLATE" EXPR="$expr" python3 - <<'PY'
import os, pathlib, yaml
forms = sorted(p for p in pathlib.Path(os.environ["FORM_DIR"]).glob("*.yml") if p.name != "config.yml")
p = forms[0]
doc = yaml.safe_load(p.read_text())
exec(os.environ["EXPR"], {"doc": doc})
p.write_text(yaml.safe_dump(doc, sort_keys=False, allow_unicode=True))
PY
}

m_none()          { :; }
m_unknown_label() { edit_form "$1" 'doc["labels"] = ["type/does-not-exist"]'; }
m_no_labels()     { edit_form "$1" 'doc.pop("labels", None)'; }
m_no_name()       { edit_form "$1" 'doc.pop("name", None)'; }
m_bad_element()   { edit_form "$1" 'doc["body"].append({"type": "not-a-real-type", "attributes": {"label": "x"}})'; }
m_bad_dropdown()  { edit_form "$1" '''
for el in doc["body"]:
    if el.get("type") == "dropdown" and "options" in el.get("attributes", {}):
        el["attributes"]["options"].append("a-surface-nobody-labelled")
        break
'''; }
m_no_config()     { rm -f "$1/.github/ISSUE_TEMPLATE/config.yml"; }
m_blank_issues()  { printf 'blank_issues_enabled: true\n' > "$1/.github/ISSUE_TEMPLATE/config.yml"; }
m_bad_blocking()  { python3 - "$1/scripts/gh/governance.json" <<'PY'
import json, sys
p = sys.argv[1]
s = json.load(open(p))
s["promotion"]["blocking_issue_labels"] = ["channel/label-that-does-not-exist"]
json.dump(s, open(p, "w"), indent=2)
PY
}
m_no_closure_gate() { rm -f "$1/scripts/gates/gate-issue-closure.sh"; }
m_no_labels_sh()    { rm -f "$1/scripts/gh/labels.sh"; }
m_no_form_dir()     { rm -rf "$1/.github/ISSUE_TEMPLATE"; }

echo "=== self-test: gate-labels-taxonomy.sh ==="
echo "-- a label GitHub would drop in silence"
run_case clean-forms-pass            0 ""                        m_none
run_case label-not-in-taxonomy       1 "does not exist"          m_unknown_label
run_case form-declares-no-labels     1 "does not declare"        m_no_labels
run_case form-missing-mandatory-key  1 "mandatory key"           m_no_name
run_case invalid-element-type        1 "invalid element type"    m_bad_element
run_case dropdown-option-unmapped    1 "option"                  m_bad_dropdown

echo "-- the entry paths and the labels other tools depend on"
run_case config-yml-missing          1 "config.yml is missing"   m_no_config
run_case blank-issues-enabled        1 "blank_issues_enabled"    m_blank_issues
run_case blocking-label-unknown      1 "blocking label"          m_bad_blocking
run_case closure-gate-absent         1 "gate-issue-closure"      m_no_closure_gate

echo "-- could not measure (never a pass)"
run_case labels-sh-missing           2 "labels.sh"               m_no_labels_sh
run_case issue-template-dir-missing  2 "ISSUE_TEMPLATE"          m_no_form_dir

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. The gate catches a label GitHub would drop in silence, an entry"
echo "        path with no label at all, and a tool depending on a label nobody"
echo "        declares - and refuses to measure without the taxonomy."
exit 0
