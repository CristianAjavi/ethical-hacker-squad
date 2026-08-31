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
d["checks"]=[c for c in d["checks"] if c["name"]!="Security-Policy"]
p.write_text(json.dumps(d,indent=1))'

case_run gated-check-inconclusive 2 "came back inconclusive" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$F"'"
d=json.loads(p.read_text())
for c in d["checks"]:
    if c["name"]=="Security-Policy": c["score"]=-1
p.write_text(json.dumps(d,indent=1))'

# --- the relocated check ------------------------------------------------
# Branch-Protection is NOT gated: it is measured, printed, and answered for by
# named files. The four cases below are the ones that decide whether that is an
# honest arrangement or a hole with a paragraph in front of it.

# It is inconclusive on every real run. That must not block, and must not vanish.
case_run relocated-check-inconclusive-does-not-block 0 "Branch-Protection: -1, inconclusive" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$F"'"
d=json.loads(p.read_text())
for c in d["checks"]:
    if c["name"]=="Branch-Protection": c["score"]=-1
p.write_text(json.dumps(d,indent=1))'

# The mutant that matters: drop it from the gated list and say so NOWHERE. This
# is what softening the gate actually looks like from the inside, and before
# measurement 5 existed it came out as a clean green over a shorter list.
case_run check-dropped-without-being-relocated 1 "documented not-gated checks and" '
import os,json,pathlib
w=pathlib.Path(os.environ["EHS_WORK"])
p=w/"scripts/gates/data/scorecard-thresholds.json"
d=json.loads(p.read_text())
d["not_gated_here"]=[]
p.write_text(json.dumps(d,indent=1))'

# In both lists at once: one of the two is a leftover and which one decides
# whether the check has teeth, so the gate refuses to guess.
case_run check-both-gated-and-not-gated 1 "is declared as gated AND as not gated" '
import os,json,pathlib
w=pathlib.Path(os.environ["EHS_WORK"])
p=w/"scripts/gates/data/scorecard-thresholds.json"
d=json.loads(p.read_text())
d["checks"].append({"check":"Branch-Protection","min":8,"why":"leftover"})
p.write_text(json.dumps(d,indent=1))
doc=w/"docs/gate-requirements.md"
doc.write_text(doc.read_text().replace(
  "| `Security-Policy` | must be `10` |",
  "| `Branch-Protection` | `>= 8` | leftover |\n| `Security-Policy` | must be `10` |",1))'

# "Something else really checks it", pointing at a file that is not there.
case_run relocated-names-a-file-that-is-gone 1 "does not exist. A control retired" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"scripts/gh/protection-check.sh").unlink()'

# And the not-gated table deleted from the document while the data file still
# relocates the check: enforced in one place, unreadable in the other.
case_run not-gated-table-deleted-from-doc 1 "g9:not-gated" '
import os,pathlib,re
p=pathlib.Path(os.environ["EHS_WORK"])/"docs/gate-requirements.md"
p.write_text(re.sub(r"<!--\s*g9:not-gated\s*-->.*?<!--\s*/g9:not-gated\s*-->","",p.read_text(),flags=16))'

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
  echo "        And the gate cannot be softened by editing it: a check dropped from the gated"
  echo "        subset without being written into the not-gated table FAILS, a check in both"
  echo "        lists FAILS, a not-gated check naming a file that no longer exists FAILS, and"
  echo "        the not-gated one still has its live score printed on every run."
  exit 0
fi
exit 1
