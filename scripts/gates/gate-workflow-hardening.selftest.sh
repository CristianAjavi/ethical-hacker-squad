#!/usr/bin/env bash
# Self-test for the battery-reachability half of gate-workflow-hardening.sh.
# The gate's other rules are proved by the fixture trees under fixtures/hardening;
# this file covers the check added on 2026-08-28, which reads .github/workflows
# from the repository root and so cannot be driven by those fixtures.
#
# Each case mutates a throwaway copy and runs THE GATE FROM THAT COPY, so a case
# can blind the checker and prove which check produced the red.
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${EHS_REPO_ROOT:-}" ]; then SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then :
else SRC="$(cd "$HERE/../.." && pwd)"; fi
command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
python3 -c 'import yaml' 2>/dev/null || { echo "UNMEASURABLE pyyaml is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-wfh-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

case_run() {
  local name="$1" want="$2" needle="$3" mutation="$4" work="$TMP/$1"
  rm -rf "$work"; mkdir -p "$work"
  (cd "$SRC" && tar --exclude .git --exclude __pycache__ -cf - .) | (cd "$work" && tar -xf -)
  if [ -n "$mutation" ] && ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
    printf 'HARNESS  %-40s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
  fi
  local out rc
  out="$(EHS_REPO_ROOT="$work" bash "$work/scripts/gates/gate-workflow-hardening.sh" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf 'ok       %-40s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-40s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -6; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-workflow-hardening.sh, battery reachability (source: $SRC) ==="

case_run control-untouched 0 "none skippable by an earlier failure" ""

# The defect this check exists for: on 2026-08-25 gate-tree-delta went red and the
# battery step, having no condition, was skipped for twenty consecutive CI runs.
case_run battery-step-condition-removed 1 "runs the batteries after a step that can fail" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/".github/workflows/ci.yml"
t=p.read_text()
n=t.replace("        if: ${{ !cancelled() }}\n","",1)
assert n!=t, "the mutation changed nothing"
p.write_text(n)'

case_run battery-step-condition-removed-checker-blind 0 "" '
import os,pathlib
w=pathlib.Path(os.environ["EHS_WORK"])
p=w/".github/workflows/ci.yml"
t=p.read_text()
n=t.replace("        if: ${{ !cancelled() }}\n","",1)
assert n!=t
p.write_text(n)
c=w/"scripts/gates/lib/battery_step_reachable.py"
c.write_text(c.read_text().replace("print(f\"SKIPPABLE|","print(f\"SILENCED|"))'

# A condition that does not survive a failure is not a condition.
case_run condition-that-does-not-survive 1 "runs the batteries after a step that can fail" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/".github/workflows/ci.yml"
t=p.read_text()
n=t.replace("if: ${{ !cancelled() }}","if: ${{ success() }}",1)
assert n!=t
p.write_text(n)'

case_run workflows-unparseable 2 "" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/".github/workflows/ci.yml").write_text("{{ not yaml")'

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. A battery step that a red gate could skip turns this gate red."
exit 0
