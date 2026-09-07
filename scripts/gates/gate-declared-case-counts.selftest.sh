#!/usr/bin/env bash
# Self-test for gate-declared-case-counts.sh.
#
# Every case but the last builds a TOY repository - a docs/gate-requirements.md
# with the rows it needs and a scripts/gates/ with fake gates that print a count
# and nothing else. That is deliberate: the gate under test RUNS the self-tests
# it finds, so a battery that mutated the real repository would spend forty
# seconds per case measuring other people's batteries instead of this one's
# reading of them. The toys make each case cost milliseconds and let a case
# assert a shape the real repository does not currently contain.
#
# The last case is the control, and it is the expensive one: the real tree, all
# twelve batteries, no mutation. A gate that only works on toys is a toy.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-declared-case-counts.sh"
if [ -n "${EHS_REPO_ROOT:-}" ]; then SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then :
else SRC="$(cd "$HERE/../.." && pwd)"; fi

command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
[ -f "$GATE" ] || { echo "UNMEASURABLE the gate is missing: $GATE"; exit 2; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-dcc-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# The gate does NOT run this battery: the control case below invokes the
# gate over the real tree, so a gate that ran it would recurse without a
# floor. That leaves this file as the only thing that can check its own
# row, and it does it with two assertions that close on each other: the
# document has to say TOTAL_CASES, and this run has to reach TOTAL_CASES.
# Raising one without the other leaves the file red.
TOTAL_CASES=21

# --------------------------------------------------------------------------
# toy <name>  - an empty repository shell.
toy() {
  W="$TMP/$1"
  rm -rf "$W"
  mkdir -p "$W/docs" "$W/scripts/gates" || return 1
  : > "$W/docs/gate-requirements.md"
}

# row <gate> <declared>  - the shape the real document uses.
row() {
  printf '| something | running | `%s.sh` + self-test (%s cases) |\n' "$1" "$2" \
    >> "$W/docs/gate-requirements.md"
}

# fake <gate> <kind> <line...>  - a gate whose self-test prints exactly what the
# case needs. `kind` picks which of the three invocation conventions it offers.
fake() {
  local g="$1" kind="$2"; shift 2
  local d="$W/scripts/gates"
  case "$kind" in
    sibling)
      printf '#!/usr/bin/env bash\nexit 0\n' > "$d/$g.sh"
      { printf '#!/usr/bin/env bash\n'; printf '%s\n' "$@"; } > "$d/$g.selftest.sh"
      ;;
    sibling-and-flag)
      # Offers BOTH. The sibling has to win, or a gate that grew a battery
      # would go on being read through its older inline flag.
      printf '#!/usr/bin/env bash\n# accepts --self-test\necho "99 passed, 0 failed"\nexit 0\n' > "$d/$g.sh"
      { printf '#!/usr/bin/env bash\n'; printf '%s\n' "$@"; } > "$d/$g.selftest.sh"
      ;;
    flag)
      { printf '#!/usr/bin/env bash\n# accepts --self-test\n'; printf '%s\n' "$@"; } > "$d/$g.sh"
      ;;
    inline)
      { printf '#!/usr/bin/env bash\n'; printf '%s\n' "$@"; } > "$d/$g.sh"
      ;;
    *) return 1 ;;
  esac
}

# check <name> <want-rc> <needle>  - run the gate over the toy just built.
check() {
  local name="$1" want="$2" needle="$3" out rc
  out="$(EHS_REPO_ROOT="$W" bash "$GATE" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf 'ok       %-44s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-44s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    [ -n "$needle" ] && printf '         looked for: %s\n' "$needle"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -6; fail=$((fail+1))
  fi
  rm -rf "$W"
}

echo "=== self-test: gate-declared-case-counts.sh (source: $SRC) ==="

# --- the count matches, read through each of the three conventions ----------
toy matches && row gate-a 4 && fake gate-a sibling 'echo "4 passed, 0 failed"' 'exit 0'
check a-count-that-matches 0 "every declared case count matches"

toy sib && row gate-a 4 && fake gate-a sibling-and-flag 'echo "4 passed, 0 failed"' 'exit 0'
check the-sibling-battery-beats-the-flag 0 "(sibling battery)"

toy flg && row gate-a 7 && fake gate-a flag 'echo "7 passed, 0 failed"' 'exit 0'
check the-flag-when-there-is-no-sibling 0 "(--self-test)"

toy inl && row gate-a 2 && fake gate-a inline 'echo "2 passed, 0 failed"' 'exit 0'
check inline-when-there-is-neither 0 "(inline on a normal run)"

# --- the drift this gate exists for, in both directions --------------------
toy up && row gate-a 3 && fake gate-a sibling 'echo "5 passed, 0 failed"' 'exit 0'
check the-row-says-fewer-than-it-runs 1 "the row says 3 cases and the self-test runs 5"

toy down && row gate-a 9 && fake gate-a sibling 'echo "5 passed, 0 failed"' 'exit 0'
check the-row-says-more-than-it-runs 1 "the row says 9 cases and the self-test runs 5"

# One drifted row among many that are fine still fails: a majority of correct
# rows is not a verdict.
toy one_of_five && row gate-a 1 && row gate-b 1 && row gate-c 8 && row gate-d 1 && row gate-e 1 \
  && fake gate-a sibling 'echo "1 passed, 0 failed"' 'exit 0' \
  && fake gate-b sibling 'echo "1 passed, 0 failed"' 'exit 0' \
  && fake gate-c sibling 'echo "3 passed, 0 failed"' 'exit 0' \
  && fake gate-d sibling 'echo "1 passed, 0 failed"' 'exit 0' \
  && fake gate-e sibling 'echo "1 passed, 0 failed"' 'exit 0'
check one-drifted-row-among-four-good-ones 1 "1 declared case count"

# --- how the count is read -------------------------------------------------
# The total is passed PLUS failed. A gate that read only the first number would
# call this row drifted.
toy total && row gate-a 5 && fake gate-a sibling 'echo "3 passed, 2 failed"' 'exit 0'
check the-total-is-passed-plus-failed 0 "5, and 5 ran"

# A battery that prints a running count per group ends with the summary. The
# first line is not the answer.
toy last && row gate-a 4 && fake gate-a sibling 'echo "1 passed, 0 failed"' \
  'echo "2 passed, 0 failed"' 'echo "4 passed, 0 failed"' 'exit 0'
check the-last-count-line-is-the-summary 0 "4, and 4 ran"

# --- the third number, which CI found the hard way -------------------------
# gate-reproduction runs 33 cases on macOS and 32 on Linux: one needs
# sandbox-exec and its skip branch counted toward neither pass nor fail, so the
# battery shrank by platform and the row was right only on a Mac.
toy skipped && row gate-a 3 && fake gate-a sibling 'echo "2 passed, 0 failed, 1 skipped"' 'exit 0'
check a-skipped-case-still-counts-toward-the-row 0 "1 skipped here"

toy skipped_extra && row gate-a 3 && fake gate-a sibling 'echo "3 passed, 0 failed, 1 skipped"' 'exit 0'
check a-skip-the-document-did-not-count 1 "the row says 3 cases and the self-test runs 4"

# --- could not measure, which is never a pass ------------------------------
toy mute && row gate-a 6 && fake gate-a sibling 'echo "the self-test ran and everything was fine"' 'exit 0'
check a-self-test-that-says-nothing 2 "prints no"

toy red && row gate-a 4 && fake gate-a sibling 'echo "3 passed, 1 failed"' 'exit 1'
check a-self-test-that-came-back-red 2 "red battery"

toy ghost && row gate-nowhere 5
check a-row-naming-a-gate-that-is-not-there 2 "no such file"

toy empty && printf '| a table with no case count at all |\n' > "$W/docs/gate-requirements.md"
check a-document-with-not-one-count 2 "blind zero"

toy nodoc && rm -f "$W/docs/gate-requirements.md"
check a-document-that-is-not-there 2 "cannot read"

toy nogates && rm -rf "$W/scripts/gates"
check no-scripts-gates-directory 2 "no scripts/gates"

# --- the one row the gate refuses to run, and says so ----------------------
toy self_row && row gate-declared-case-counts 21 && row gate-a 2 \
  && fake gate-a sibling 'echo "2 passed, 0 failed"' 'exit 0'
check the-row-for-this-gate-is-not-run-from-here 0 "NOT run here: gate-declared-case-counts"

# --- a crash is not a verdict ----------------------------------------------
# The core is Python, and Python exits 1 when it dies. Without the guard, a
# traceback would read as "measured, and two rows drifted" with no row named.
crash="$TMP/crash"
mkdir -p "$crash/scripts/gates/lib" "$crash/root"
cp "$GATE" "$crash/scripts/gates/" && cp "$HERE/lib/common.sh" "$crash/scripts/gates/lib/"
printf 'import sys\nsys.exit(1)\n' > "$crash/scripts/gates/lib/declared_case_counts.py"
out="$(EHS_REPO_ROOT="$crash/root" bash "$crash/scripts/gates/gate-declared-case-counts.sh" 2>&1)"; rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q "crash, not a verdict"; then
  printf 'ok       %-44s rc=%s\n' "a-crash-is-not-a-verdict" "$rc"; pass=$((pass+1))
else
  printf 'FAILED   %-44s rc=%s (wanted 2)\n' "a-crash-is-not-a-verdict" "$rc"
  printf '%s\n' "$out" | sed 's/^/         /' | tail -6; fail=$((fail+1))
fi

# --- this battery's own row, which the gate cannot check for it ------------
declared_here="$(grep '^|.*gate-declared-case-counts\.sh' \
  "$SRC/docs/gate-requirements.md" 2>/dev/null \
  | grep -o 'self-test ([0-9]* cases)' | grep -o '[0-9]*' | head -1)"
if [ "${declared_here:-}" = "$TOTAL_CASES" ]; then
  printf 'ok       %-44s rc=0\n' "my-own-row-says-what-this-battery-runs"; pass=$((pass+1))
else
  printf 'FAILED   %-44s the document says "%s" and this file runs %s\n' \
    "my-own-row-says-what-this-battery-runs" "${declared_here:-<no row>}" "$TOTAL_CASES"
  fail=$((fail+1))
fi

# --- the control: the real tree, every real battery, no mutation -----------
out="$(EHS_REPO_ROOT="$SRC" bash "$GATE" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "every declared case count matches"; then
  printf 'ok       %-44s rc=%s\n' "control-the-real-repository" "$rc"; pass=$((pass+1))
else
  printf 'FAILED   %-44s rc=%s (wanted 0)\n' "control-the-real-repository" "$rc"
  printf '%s\n' "$out" | sed 's/^/         /' | tail -8; fail=$((fail+1))
fi

echo "--- $pass passed, $fail failed ---"
# The other half of the pair above. A case added and not counted would leave the
# document's number true of nothing.
if [ "$((pass + fail))" -ne "$TOTAL_CASES" ]; then
  echo "UNMEASURABLE this file declares $TOTAL_CASES cases and ran $((pass + fail))"
  exit 2
fi
[ "$fail" -eq 0 ] || exit 1
exit 0
