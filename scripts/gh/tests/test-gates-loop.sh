#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# NEGATIVE TEST of the loop that runs the gates: scripts/gates/run-all.sh.
#
# INTEGRATION NOTE. This suite used to extract the loop from the 'gates' job of
# .github/workflows/promote-stable.yml. That workflow was removed when the four
# areas were merged: there were TWO workflows promoting to stable, on the same
# cron, with incompatible version models. The loop -- and every hole this suite
# found -- now lives in scripts/gates/run-all.sh, which is what release.yml runs
# on the candidate and what ci.yml runs on every PR. One implementation, one
# suite watching it.
#
# The question this suite answers is not "do the gates pass?" but the only one
# that really matters: "can this job say ALL GREEN without having run every
# gate?". Each case is a real way for that to happen:
#
#   1. A gate that reads from stdin. If the gate list travels through stdin, the
#      first 'cat', 'read', 'jq' with no file or 'xargs' swallows the rest of the
#      list and the loop ends early. No attacker is needed: a gate written
#      naturally is enough. (Real hole found and fixed.)
#   2. Gates that do not end in .sh. Discovering only '*.sh' turns any gate
#      written in Python or node into a gate that never runs.
#   3. Gates in subdirectories. A single-level discovery ignores them.
#   4. Files that look like gates and cannot be executed -> the honest verdict
#      is 2 (could not measure), never 0.
#
# The runner under test is the REAL scripts/gates/run-all.sh, copied into a
# throwaway lab: the test cannot drift out of sync with what CI executes.
#
# EXIT CODES:  0 all good / 1 there is a hole / 2 I could not run the test
# ---------------------------------------------------------------------------
set -uo pipefail
SP="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SP/../../.." && pwd)"
RUNNER="$ROOT/scripts/gates/run-all.sh"
COMMON="$ROOT/scripts/gates/lib/common.sh"

[ -f "$RUNNER" ] || { echo "  COULD NOT MEASURE: $RUNNER does not exist (rc 2)"; exit 2; }
[ -f "$COMMON" ] || { echo "  COULD NOT MEASURE: $COMMON does not exist (rc 2)"; exit 2; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
LAB="$TMP/lab"
PASS=0; FAIL=0

rc_gates() { ( cd "$LAB" && GITHUB_STEP_SUMMARY=/dev/null \
               bash scripts/gates/run-all.sh >/dev/null 2>&1 ); echo $?; }
res() {
  if [ "$2" = "$3" ]; then printf '  PASS  %-58s rc=%s\n' "$1" "$2"; PASS=$((PASS+1))
  else printf '  FAIL  %-58s rc=%s (expected %s)\n' "$1" "$2" "$3"; FAIL=$((FAIL+1)); fi
}
# Each case starts from a clean lab holding the REAL runner.
LABN=0
clean() {
  LABN=$((LABN + 1))
  LAB="$TMP/lab.$LABN"
  mkdir -p "$LAB/scripts/gates/lib"
  cp "$RUNNER" "$LAB/scripts/gates/run-all.sh"
  cp "$COMMON" "$LAB/scripts/gates/lib/common.sh"
}

echo "== The rc of each gate rules"
clean
res "empty directory -> 2 (zero gates = zero verification)" "$(rc_gates)" 2
printf '#!/usr/bin/env bash\nexit 0\n' >"$LAB/scripts/gates/a.sh"
res "one green gate -> 0" "$(rc_gates)" 0
printf '#!/usr/bin/env bash\nexit 1\n' >"$LAB/scripts/gates/b.sh"
res "one red gate -> 1" "$(rc_gates)" 1
printf '#!/usr/bin/env bash\nexit 2\n' >"$LAB/scripts/gates/b.sh"
# 2, not 1: run-all.sh keeps "I did not measure" apart from "I measured and it
# fails". Both are non-zero and both stop the promotion; what may never happen is 0.
res "a gate that could not measure -> 2 (never 0)" "$(rc_gates)" 2
printf '#!/usr/bin/env bash\nexit 7\n' >"$LAB/scripts/gates/b.sh"
res "unforeseen rc -> 2 (never read as success)" "$(rc_gates)" 2

echo ""
echo "== One gate CANNOT stop the others from running"
clean
# The greedy gate drains stdin. If the gate list travelled through stdin, it
# would eat the whole list and the two red gates behind it would never run.
printf '#!/usr/bin/env bash\ncat >/dev/null 2>&1\nexit 0\n' >"$LAB/scripts/gates/a-greedy.sh"
printf '#!/usr/bin/env bash\nexit 1\n'                      >"$LAB/scripts/gates/b-red.sh"
printf '#!/usr/bin/env bash\nexit 1\n'                      >"$LAB/scripts/gates/c-red.sh"
res "gate that consumes stdin + 2 red gates behind it -> 1" "$(rc_gates)" 1
OUT=$( cd "$LAB" && GITHUB_STEP_SUMMARY=/dev/null bash scripts/gates/run-all.sh 2>&1 )
RUN=$(printf '%s\n' "$OUT" | sed -n 's/.*| run: \([0-9][0-9]*\) |.*/\1/p' | head -n1)
res "all 3 gates actually ran (not only the first)" "${RUN:-0}" 3

echo ""
echo "== No gate is discovered halfway"
clean
printf '#!/usr/bin/env bash\nexit 0\n' >"$LAB/scripts/gates/ok.sh"
printf '#!/usr/bin/env python3\nimport sys; sys.exit(1)\n' >"$LAB/scripts/gates/critical.py"
chmod +x "$LAB/scripts/gates/critical.py"
res "executable .py gate that fails, next to a green .sh -> 1" "$(rc_gates)" 1

clean
printf '#!/usr/bin/env bash\nexit 0\n' >"$LAB/scripts/gates/ok.sh"
mkdir -p "$LAB/scripts/gates/supply-chain"
printf '#!/usr/bin/env bash\nexit 1\n' >"$LAB/scripts/gates/supply-chain/deep.sh"
res "gate in a subdirectory that fails -> 1" "$(rc_gates)" 1

clean
printf '#!/usr/bin/env bash\nexit 0\n' >"$LAB/scripts/gates/ok.sh"
printf 'import sys; sys.exit(1)\n' >"$LAB/scripts/gates/no-bit.py"   # without +x
res "file that looks like a gate and cannot be run -> 2 (could not measure)" "$(rc_gates)" 2

clean
printf '#!/usr/bin/env bash\nexit 0\n' >"$LAB/scripts/gates/ok.sh"
printf 'documentation, not a gate\n' >"$LAB/scripts/gates/README.md"
res "README.md in the directory is not mistaken for a gate -> 0" "$(rc_gates)" 0

echo ""
echo "  $PASS PASS / $FAIL FAIL"
[ "$FAIL" -eq 0 ] || exit 1
