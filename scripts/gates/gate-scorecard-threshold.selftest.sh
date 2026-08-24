#!/usr/bin/env bash
# Self-test for gate-scorecard-threshold.sh. Each case breaks exactly one thing on a
# throwaway copy and asserts the exit code AND the reason, including a control on the
# untouched fixture and four cases that must report could-not-measure.
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-scorecard-threshold.sh"
if [ -n "${EHS_REPO_ROOT:-}" ]; then SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then :
else SRC="$(cd "$HERE/../.." && pwd)"; fi
command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-scorecard-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
F="scripts/gates/fixtures/scorecard/good.json"

# case <name> <expected rc> <needle> <mutation>   (mutation sees EHS_WORK)
case_run() {
  local name="$1" want="$2" needle="$3" mutation="$4" work="$TMP/$1"
  rm -rf "$work"; mkdir -p "$work"
  (cd "$SRC" && tar --exclude .git --exclude __pycache__ -cf - .) | (cd "$work" && tar -xf -)
  if [ -n "$mutation" ] && ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
    printf 'HARNESS  %-40s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
  fi
  local out rc results="$work/$F"
  [ -f "$results" ] || results="$work/.absent.json"
  out="$(env -u SCORECARD_RESULTS EHS_REPO_ROOT="$work" bash "$GATE" --results "$results" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf 'ok       %-40s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-40s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -6; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-scorecard-threshold.sh (source: $SRC) ==="

case_run control-untouched-fixture 0 "at or above its declared minimum" ""

case_run gated-check-below-threshold 1 "below the declared minimum" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$F"'"
d=json.loads(p.read_text())
for c in d["checks"]:
    if c["name"]=="Token-Permissions": c["score"]=5
p.write_text(json.dumps(d,indent=1))'

case_run dangerous-workflow-not-perfect 1 "Dangerous-Workflow" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$F"'"
d=json.loads(p.read_text())
for c in d["checks"]:
    if c["name"]=="Dangerous-Workflow": c["score"]=9
p.write_text(json.dumps(d,indent=1))'

case_run gated-check-absent-from-results 2 "is not in the results at all" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$F"'"
d=json.loads(p.read_text())
d["checks"]=[c for c in d["checks"] if c["name"]!="Branch-Protection"]
p.write_text(json.dumps(d,indent=1))'

case_run gated-check-inconclusive 2 "came back inconclusive" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$F"'"
d=json.loads(p.read_text())
for c in d["checks"]:
    if c["name"]=="Branch-Protection": c["score"]=-1
p.write_text(json.dumps(d,indent=1))'

case_run aggregate-falls-past-the-contract 1 "more than the" '
import os,json,pathlib
w=pathlib.Path(os.environ["EHS_WORK"])
b=w/"docs/scorecard-baseline.json"
d=json.loads(b.read_text()); d["aggregate"]=9.0; b.write_text(json.dumps(d,indent=1))'

case_run aggregate-falls-within-the-contract 0 "against a baseline of" '
import os,json,pathlib
w=pathlib.Path(os.environ["EHS_WORK"])
b=w/"docs/scorecard-baseline.json"
d=json.loads(b.read_text()); d["aggregate"]=7.6; b.write_text(json.dumps(d,indent=1))'

case_run documented-thresholds-drift 1 "the documented G9 thresholds and" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"docs/gate-requirements.md"
p.write_text(p.read_text().replace("| `Token-Permissions` | `>= 9` |","| `Token-Permissions` | `>= 4` |",1))'

case_run results-absent 2 "" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"'"$F"'").unlink()'

case_run results-unparseable 2 "" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"'"$F"'").write_text("{")'

case_run thresholds-data-unusable 2 "" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/data/scorecard-thresholds.json").write_text("{")'

echo
echo "Summary: $pass ok, $fail failures"
if [ "$fail" -eq 0 ]; then
  echo "Result: OK. A gated check below its minimum fails, an inconclusive or absent check is"
  echo "        could-not-measure rather than a pass, the aggregate is judged by movement, and"
  echo "        the documented thresholds cannot drift from the enforced ones."
  exit 0
fi
exit 1
