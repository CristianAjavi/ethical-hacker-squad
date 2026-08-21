#!/usr/bin/env bash
# Self-test for gate-triage-rules.sh. Each case breaks exactly one thing on a
# throwaway copy and asserts the exit code and the reason. The first case is the
# control: without it, a battery that stopped measuring looks like a clean run.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-triage-rules.sh"
if [ -n "${EHS_REPO_ROOT:-}" ]; then SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then :
else SRC="$(cd "$HERE/../.." && pwd)"; fi

command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-triage-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
K="skills/ethical-hacker-squad/references/knowledge"
R="skills/ethical-hacker-squad/references/triage.md"

case_run() {
  local name="$1" want="$2" needle="$3" mutation="$4" work="$TMP/$1"
  rm -rf "$work"; mkdir -p "$work"
  (cd "$SRC" && tar --exclude .git --exclude __pycache__ -cf - .) | (cd "$work" && tar -xf -)
  if [ -n "$mutation" ] && ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
    printf 'HARNESS  %-34s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
  fi
  local out rc
  out="$(EHS_REPO_ROOT="$work" bash "$GATE" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf 'ok       %-34s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-34s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -5; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-triage-rules.sh (source: $SRC) ==="

case_run control-untouched-repo 0 "no pack slipped backwards" ""

case_run converted-pack-loses-a-citation 1 "cite no triage rule" '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'/local-app.md"
p.write_text(re.sub(r"\nRules: FP[^\n]*\n","\n",p.read_text(),count=1))'

case_run citation-of-a-rule-that-does-not-exist 1 "does not declare" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'/web-api.md"
p.write_text(p.read_text().replace("Rules: FP-01","Rules: FP-99",1))'

case_run rule-ids-not-contiguous 1 "not contiguous" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'"
p.write_text(p.read_text().replace("| `FP-05` |","| `FP-55` |",1))'

case_run rule-gutted-to-a-stub 1 "a rule in name only" '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'"
s=p.read_text()
i=s.index("| `FP-07` |"); j=s.index("\n",i)
p.write_text(s[:i]+"| `FP-07` | it depends | ask |"+s[j:])'

case_run answer-vocabulary-broken 1 "is not declared" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'"
p.write_text(p.read_text().replace("NOT_APPLICABLE","N/A"))'

case_run finding-carrier-stops-pointing-here 1 "never points at" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"skills/ethical-hacker-squad/references/report.md"
p.write_text(p.read_text().replace("triage.md","the rules file"))'

case_run pack-with-no-conversion-policy 1 "no conversion policy" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/data/triage-conformance.json"
d=json.loads(p.read_text()); d["packs"].pop("mobile")
p.write_text(json.dumps(d,indent=2))'

case_run ratchet-turned-backwards 1 "below its floor" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/data/triage-conformance.json"
d=json.loads(p.read_text()); d["packs"]["mobile"]={"required":False,"floor":999}
p.write_text(json.dumps(d,indent=2))'

case_run rules-file-gone 2 "" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'").unlink()'

case_run conformance-data-unreadable 2 "" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/data/triage-conformance.json").write_text("{ not json")'

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. The gate fails when it must fail and separates could-not-measure from nothing-to-report."
exit 0
