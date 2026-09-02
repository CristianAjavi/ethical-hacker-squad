#!/usr/bin/env bash
# Self-test for gate-findings-artifact.sh. Each case breaks one thing on a
# throwaway copy — a fixture, a sidecar, or one of the four sources of truth —
# and asserts the exit code and the reason.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-findings-artifact.sh"
. "$HERE/lib/selftest-root.sh" 2>/dev/null || {
  echo "UNMEASURABLE the root guard is missing at $HERE/lib/selftest-root.sh"; exit 2; }
SRC="$(ehs_selftest_root --here "$HERE")" || exit 2
command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-findings-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
F="scripts/gates/fixtures/findings"
R="skills/ethical-hacker-squad/references"

case_run() {
  local name="$1" want="$2" needle="$3" mutation="$4" work="$TMP/$1"
  rm -rf "$work"; mkdir -p "$work"
  (cd "$SRC" && tar --exclude .git --exclude __pycache__ -cf - .) | (cd "$work" && tar -xf -)
  if [ -n "$mutation" ] && ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
    printf 'HARNESS  %-38s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
  fi
  local out rc
  out="$(EHS_REPO_ROOT="$work" bash "$GATE" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf 'ok       %-38s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-38s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -5; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-findings-artifact.sh (source: $SRC) ==="

case_run control-untouched-fixtures 0 "every fixture failed for the reason" ""

case_run good-fixture-loses-a-required-field 1 "missing required field" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$F"'/good/01-conforming.json"
d=json.loads(p.read_text()); d["findings"][0].pop("impact"); p.write_text(json.dumps(d,indent=2))'

case_run bad-fixture-that-no-longer-fails 1 "validated cleanly" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$F"'/bad/03-invented-procedure.json"
d=json.loads(p.read_text()); d["findings"][0]["procedure"]="WEB-04"; p.write_text(json.dumps(d,indent=2))'

case_run bad-fixture-fails-for-another-reason 1 "wrong reason" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$F"'/bad/03-invented-procedure.expected"
p.write_text("an entirely different message\n")'

case_run fixture-without-a-sidecar 1 "no .expected sidecar" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"'"$F"'/bad/09-unknown-field.expected").unlink()'

case_run schema-field-nobody-documented 1 "field table does not explain it" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'/findings.schema.json"
d=json.loads(p.read_text())
d["properties"]["findings"]["items"]["properties"]["cvss_vector"]={"type":"string"}
p.write_text(json.dumps(d,indent=2))'

case_run field-documented-at-the-wrong-level 1 "does not explain it at that level" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'/findings-artifact.md"
p.write_text(p.read_text().replace("| `findings[].limits` |","| `limits` |",1))'

case_run field-table-invents-a-field 1 "which the schema does not declare there" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'/findings-artifact.md"
p.write_text(p.read_text().replace("| `findings[].impact` |","| `findings[].blast_radius` |",1))'

case_run vocabulary-region-gone 2 "" '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'/vocabulary.md"
p.write_text(p.read_text().replace("<!-- vocabulary:declare severity -->","<!-- gone -->",1))'

case_run schema-unreadable 2 "" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'/findings.schema.json").write_text("{ not json")'

case_run triage-rules-gone 2 "" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'/triage.md").unlink()'

case_run no-fixtures-at-all 2 "" '
import os,shutil,pathlib
shutil.rmtree(pathlib.Path(os.environ["EHS_WORK"])/"'"$F"'")'

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. The gate validates the artifact, checks that each negative fixture fails"
echo "        for its own reason, and reports could-not-measure when a source of truth is gone."
exit 0
