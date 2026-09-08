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
TOTAL_CASES=38

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

# row2 <gate> <first> <second>  - a row that declares BOTH self-tests.
row2() {
  printf '| something | running | `%s.sh` + self-test (%s cases) + --self-test (%s cases) |\n' \
    "$1" "$2" "$3" >> "$W/docs/gate-requirements.md"
}

# rowpair <gate> <n> <gate> <n>  - ONE row naming two gates, as `G1` and the
# workflow-hardening row really do. Pass "-" as a count to leave that gate
# undeclared while the other keeps its number. The backtick lives in a variable
# because inside double quotes it would be a command substitution.
rowpair() {
  local a b bt
  bt='`'
  case "$2" in -) a="$bt$1.sh$bt" ;; *) a="$bt$1.sh$bt + self-test ($2 cases)" ;; esac
  case "$4" in -) b="$bt$3.sh$bt" ;; *) b="$bt$3.sh$bt + self-test ($4 cases)" ;; esac
  printf '| something | running | %s, %s |\n' "$a" "$b" \
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
    sibling-and-flag|sibling-and-flag:*)
      # Offers BOTH, and OFFERS the flag rather than naming it: a real
      # comparison against "$1", which is one of the two shapes the gate reads
      # as a declaration. The sibling has to win the FIRST count, or a gate that
      # grew a battery would go on being read through its older inline flag -
      # and the flag has to be measured as the second, or it answers to nothing.
      local n="99"; case "$kind" in *:*) n="${kind#*:}" ;; esac
      { printf '#!/usr/bin/env bash\n'
        printf '[ "${1:-}" = "--self-test" ] || exit 0\n'
        printf 'echo "%s passed, 0 failed"\nexit 0\n' "$n"; } > "$d/$g.sh"
      { printf '#!/usr/bin/env bash\n'; printf '%s\n' "$@"; } > "$d/$g.selftest.sh"
      ;;
    sibling-and-mention)
      # NAMES the flag in a comment and does not answer it. A substring test
      # cannot tell this apart from the kind above, which is how the rule first
      # accused a gate whose header only explains what `--self-test` is.
      printf '#!/usr/bin/env bash\n# a gate invoked with --self-test is not a battery\nexit 0\n' > "$d/$g.sh"
      { printf '#!/usr/bin/env bash\n'; printf '%s\n' "$@"; } > "$d/$g.selftest.sh"
      ;;
    flag)
      { printf '#!/usr/bin/env bash\n'
        printf '[ "${1:-}" = "--self-test" ] || exit 0\n'
        printf '%s\n' "$@"; } > "$d/$g.sh"
      ;;
    inline)
      { printf '#!/usr/bin/env bash\n'; printf '%s\n' "$@"; } > "$d/$g.sh"
      ;;
    *) return 1 ;;
  esac
}

# checkno <name> <want-rc> <needle>  - like `check`, but the needle must be
# ABSENT. An absent needle is a blind zero unless something proves the run
# would print it: the mutant `the-fence-comes-down` is that proof - with the
# fence down this exact line appears and the case dies.
checkno() {
  local name="$1" want="$2" needle="$3" out rc
  out="$(EHS_REPO_ROOT="$W" EHS_TALLY_LEDGER="$LEDGER" bash "$GATE" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && ! grep -q -- "$needle" <<<"$out"; then
    printf 'ok       %-44s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-44s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '         must NOT say: %s\n' "$needle"
    printf '%s\n' "$out" | sed 's/^/         /'
    fail=$((fail+1))
  fi
}

# check <name> <want-rc> <needle>  - run the gate over the toy just built.
check() {
  local name="$1" want="$2" needle="$3" out rc
  out="$(EHS_REPO_ROOT="$W" EHS_TALLY_LEDGER="$LEDGER" bash "$GATE" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || grep -q -- "$needle" <<<"$out"; }; then
    printf 'ok       %-44s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-44s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    [ -n "$needle" ] && printf '         looked for: %s\n' "$needle"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -6; fail=$((fail+1))
  fi
  rm -rf "$W"
  LEDGER=""
}

# --- the tally ledger -------------------------------------------------------
# Empty unless a case sets it, and reset by check() so a ledger cannot leak from
# one case into the next and make a later one pass for the wrong reason.
LEDGER=""

if command -v sha256sum >/dev/null 2>&1; then
  digest() { sha256sum "$1" | cut -d' ' -f1; }
elif command -v shasum >/dev/null 2>&1; then
  digest() { shasum -a 256 "$1" | cut -d' ' -f1; }
else
  digest() { echo ""; }
fi

# led <file> <tally>  - one ledger line for a file that exists, keyed by its
# CONTENT. ledbad writes a line with a hash that belongs to nothing.
led() {
  LEDGER="$W/ledger.txt"
  printf '%s %s %s\n' "$(digest "$1")" "$1" "$2" >> "$LEDGER"
}
ledbad() {
  LEDGER="$W/ledger.txt"
  printf '%s %s %s\n' \
    "0000000000000000000000000000000000000000000000000000000000000000" \
    "$1" "$2" >> "$LEDGER"
}

echo "=== self-test: gate-declared-case-counts.sh (source: $SRC) ==="

# --- the count matches, read through each of the three conventions ----------
toy matches && row gate-a 4 && fake gate-a sibling 'echo "4 passed, 0 failed"' 'exit 0'
check a-count-that-matches 0 "every declared case count matches"

toy sib && row2 gate-a 4 99 && fake gate-a sibling-and-flag 'echo "4 passed, 0 failed"' 'exit 0'
check the-sibling-battery-beats-the-flag 0 "(sibling battery)"

toy flg && row gate-a 7 && fake gate-a flag 'echo "7 passed, 0 failed"' 'exit 0'
check the-flag-when-there-is-no-sibling 0 "(--self-test)"

toy inl && row gate-a 2 && fake gate-a inline 'echo "2 passed, 0 failed"' 'exit 0'
check inline-when-there-is-neither 0 "(inline on a normal run)"

# --- one row, more than one gate -------------------------------------------
# `.search` returns the first match on the line, so on a row naming two gates
# only the first was ever compared - and the real table has two such rows.
toy pair && rowpair gate-a 4 gate-b 7 \
  && fake gate-a sibling 'echo "4 passed, 0 failed"' 'exit 0' \
  && fake gate-b sibling 'echo "7 passed, 0 failed"' 'exit 0'
check both-gates-on-one-row-are-compared 0 "checked 2 self-test"

toy pair_drift && rowpair gate-a 4 gate-b 7 \
  && fake gate-a sibling 'echo "4 passed, 0 failed"' 'exit 0' \
  && fake gate-b sibling 'echo "2 passed, 0 failed"' 'exit 0'
check the-second-gate-on-the-row-drifts-too 1 "the row says 7 cases and the self-test runs 2"

# The lazy span is fenced so it cannot reach across a gate name. Unfenced, the
# first gate here would be handed the second one's 7 and accused of running 4.
toy fence && rowpair gate-a - gate-b 7 \
  && fake gate-a sibling 'echo "4 passed, 0 failed"' 'exit 0' \
  && fake gate-b sibling 'echo "7 passed, 0 failed"' 'exit 0'
# gate-a here declares nothing on purpose, so the undeclared-count rule
# reports it and the run is red either way. What this case asserts is the
# accusation that must NOT appear: gate-a accused of running 4 against a 7
# it never declared, which is what the neighbour's number crossing over
# looks like from the outside.
checkno a-count-does-not-cross-to-the-gate-before-it 1 "the row says 7 cases and the self-test runs 4"

# Declared twice with two numbers: the fixture prints the SECOND, so without the
# clash finding this row is green and one of the two claims is false anyway.
toy twice && row gate-a 4 && row gate-a 9 \
  && fake gate-a sibling 'echo "9 passed, 0 failed"' 'exit 0'
check the-same-gate-declared-twice-with-two-numbers 1 "declares it twice"

# --- a gate may carry TWO self-tests, and both have to answer ---------------
# `invocation` returns the first convention that matches, so the second
# self-test of a gate that has a sibling battery was compared against nothing:
# it could fall to a single case with the row still green. Both ends are
# findings, and the middle - a gate that only NAMES the flag - is not.
toy second && row gate-a 4 && fake gate-a sibling-and-flag:3 'echo "4 passed, 0 failed"' 'exit 0'
check a-second-self-test-nobody-declared 1 "AND its own --self-test"

toy phantom && row2 gate-a 4 5 && fake gate-a sibling 'echo "4 passed, 0 failed"' 'exit 0'
check a-declared-second-self-test-that-is-not-there 1 "no second self-test"

# --- a gate whose row declares nothing at all ------------------------------
# The state ten of the forty-one gates were in until 2026-09-07: not compared
# and not accused either, because the reading walks the DECLARATIONS and an
# absent row declares nothing to walk. Read off the files instead - a row can be
# deleted, a file cannot be talked away.
toy undeclared && row gate-b 4 \
  && fake gate-b inline 'echo "4 passed, 0 failed"' 'exit 0' \
  && fake gate-a inline 'echo "9 passed, 0 failed"' 'exit 0'
check a-gate-whose-row-declares-no-count 1 "declares no case count"

# And the other end: a sibling battery is a FILE under scripts/gates/ and is not
# a gate of its own. Demanding a row for `gate-b.selftest.sh` would make the
# rule unsatisfiable for every gate that has a battery, which is most of them.
toy sibfile && row gate-b 4 && fake gate-b sibling 'echo "4 passed, 0 failed"' 'exit 0'
check a-sibling-battery-is-not-a-gate-of-its-own 0 "checked 1 self-test"

toy second_drift && row2 gate-a 4 9 && fake gate-a sibling-and-flag:3 'echo "4 passed, 0 failed"' 'exit 0'
check the-second-count-is-compared-too 1 "the row says 9 cases and the self-test runs 3"

toy mention && row gate-a 4 && fake gate-a sibling-and-mention 'echo "4 passed, 0 failed"' 'exit 0'
check naming-the-flag-in-a-comment-is-not-offering-it 0 "every declared case count matches"

# A gate with no sibling already has its `--self-test` measured as its first and
# only one. Declaring it a second time is the stale row, not a second test.
toy first_is_flag && row2 gate-a 7 7 && fake gate-a flag 'echo "7 passed, 0 failed"' 'exit 0'
check a-flag-with-no-sibling-is-not-a-second 1 "no second self-test"

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

# --- the tally ledger: what it may answer, and what it may not -------------
# The battery under each of these prints a count that DISAGREES with the ledger
# line, so the case can only pass if the gate read the source it was meant to.

toy led_hit && row gate-a 4 && fake gate-a sibling 'echo "9 passed, 0 failed"' 'exit 0' \
  && led "$W/scripts/gates/gate-a.selftest.sh" "4 passed, 0 failed"
check a-battery-in-the-ledger-is-not-run-again 0 "earlier in this job, by run-batteries.sh"

# Edit one case and the hash misses. There is no staleness window to reason
# about because the key is the bytes, not the name.
toy led_stale && row gate-a 9 && fake gate-a sibling 'echo "9 passed, 0 failed"' 'exit 0' \
  && ledbad "$W/scripts/gates/gate-a.selftest.sh" "4 passed, 0 failed"
check a-ledger-entry-whose-file-changed-is-ignored 0 "(sibling battery)"

# run-batteries.sh records batteries. A gate whose self-test runs inline is not
# one, so its hash can never answer for it - not even if it somehow appeared.
toy led_inline && row gate-a 2 && fake gate-a inline 'echo "2 passed, 0 failed"' 'exit 0' \
  && led "$W/scripts/gates/gate-a.sh" "7 passed, 0 failed"
check the-ledger-cannot-answer-for-a-gate-run-inline 0 "(inline on a normal run)"

toy led_gone && row gate-a 4 && fake gate-a sibling 'echo "4 passed, 0 failed"' 'exit 0' \
  && LEDGER="$W/there-is-no-ledger-here.txt"
check a-ledger-that-is-not-there-runs-everything 0 "(sibling battery)"

toy led_junk && row gate-a 4 && fake gate-a sibling 'echo "4 passed, 0 failed"' 'exit 0' \
  && LEDGER="$W/ledger.txt" && printf 'not a ledger line\nnor this one\n' > "$W/ledger.txt"
check a-ledger-of-rubbish-runs-everything 0 "(sibling battery)"

# A shortcut that could only ever agree would be worthless. Drift read off the
# ledger is still drift.
toy led_drift && row gate-a 5 && fake gate-a sibling 'echo "5 passed, 0 failed"' 'exit 0' \
  && led "$W/scripts/gates/gate-a.selftest.sh" "3 passed, 0 failed"
check a-drifted-row-is-caught-through-the-ledger-too 1 "the row says 5 cases and the self-test runs 3"

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
if [ "$rc" -eq 2 ] && grep -q "crash, not a verdict" <<<"$out"; then
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
if [ "$rc" -eq 0 ] && grep -q "every declared case count matches" <<<"$out"; then
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
