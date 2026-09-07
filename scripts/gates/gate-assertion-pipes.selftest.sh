#!/usr/bin/env bash
# Self-test for gate-assertion-pipes.sh.
#
# Each case builds a throwaway tree holding the real run-batteries.sh - which is
# the authority on what a battery is - plus battery files written for the case,
# and asserts both the exit code and the reason.
#
# Three things this battery exists to hold down, all three learned from the
# gate's own first red:
#
#   - the population is ASKED FOR, not globbed. The first version of the gate
#     found 37 batteries where the runner has 35; the two extra were fixtures,
#     which contain on purpose whatever shape the fixture exercises. The case
#     `a fixture is not a battery` is that defect, kept alive.
#   - the runner is told WHERE to look. It defaults to `scripts` relative to the
#     cwd and, run from elsewhere, lists nothing while still exiting 0 with its
#     complaint on stderr. A gate that asked without saying where would read an
#     empty list and blame the tree.
#   - three cases must NOT fire. Without them a gate that reddened on every
#     tree would pass this battery, and the `[^|]` guard and the display-pipe
#     exemption would be accidents rather than decisions.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-assertion-pipes.sh"
if [ -n "${EHS_REPO_ROOT:-}" ]; then SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then :
else SRC="$(cd "$HERE/../.." && pwd)"; fi

[ -x "$GATE" ] || { echo "UNMEASURABLE $GATE is not executable"; exit 2; }
RUNNER="$SRC/scripts/run-batteries.sh"
[ -f "$RUNNER" ] || { echo "UNMEASURABLE there is no $RUNNER to copy in"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-apipes-XXXXXX")" || { echo "UNMEASURABLE no temp dir"; exit 2; }
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# A tree with the real runner in it, and nothing else the gate reads.
scaffold() {
  local w="$1"
  mkdir -p "$w/scripts/gates"
  cp "$RUNNER" "$w/scripts/run-batteries.sh"
}

# THE BAR TRAVELS IN A VARIABLE, and not to dodge the gate. The lines below
# WRITE the forbidden shape into a throwaway battery so the gate has something
# to find; they assert nothing themselves, and a file that only looks like what
# it measures would put this gate in permanent red over its own fixtures. The
# written file still carries the shape whole, so nothing this battery proves is
# weakened - what changes is that an exemption list, which opens once and stays
# open, was not needed.
P='|'

# The line every clean battery is built from: same grep, same flags, no pipe.
CLEAN='out="hello"
grep -q -- "hello" <<<"$out" && echo yes'

case_run() {
  local name="$1" want="$2" needle="$3" build="$4" w="$TMP/$1"
  mkdir -p "$w"
  if ! ( set -e; eval "$build" ) >/dev/null 2>&1; then
    printf 'HARNESS  %-46s the tree could not be built\n' "$name"; fail=$((fail+1)); return
  fi

  local out rc
  out="$(EHS_REPO_ROOT="$w" bash "$GATE" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || grep -q -- "$needle" <<<"$out"; }; then
    printf 'ok       %-46s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-46s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -8; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-assertion-pipes.sh (source: $SRC) ==="

# --- the control ----------------------------------------------------------
case_run control-a-clean-battery 0 "no battery tests a needle through a pipe" '
scaffold "'"$TMP"'/control-a-clean-battery"
printf "%s\n" "$CLEAN" > "'"$TMP"'/control-a-clean-battery/scripts/gates/gate-a.selftest.sh"'

# The count is part of the verdict. A gate that read zero files would also
# report zero pipes, and this line is what separates the two.
case_run the-count-is-what-the-runner-lists 0 "this gate read: 3" '
w="'"$TMP"'/the-count-is-what-the-runner-lists"; scaffold "$w"
for n in a b c; do printf "%s\n" "$CLEAN" > "$w/scripts/gates/gate-$n.selftest.sh"; done'

# --- the shape the gate exists to remove ----------------------------------
case_run printf-piped-into-grep-q 1 "gate-a.selftest.sh:2" '
w="'"$TMP"'/printf-piped-into-grep-q"; scaffold "$w"
{ echo "out=hello"
  echo "if printf %s \"\$out\" $P grep -q -- \"hello\"; then echo yes; fi"
} > "$w/scripts/gates/gate-a.selftest.sh"'

case_run echo-piped-into-grep-qF 1 "assertions piped into grep -q: 1" '
w="'"$TMP"'/echo-piped-into-grep-qF"; scaffold "$w"
{ echo "out=hello"
  echo "echo \"\$out\" $P grep -qF \"hello\" && echo yes"
} > "$w/scripts/gates/gate-a.selftest.sh"'

# Two in one file and one in another: the gate reports sites, not files.
case_run every-site-is-named-not-just-the-file 1 "assertions piped into grep -q: 3" '
w="'"$TMP"'/every-site-is-named-not-just-the-file"; scaffold "$w"
{ echo "printf %s \"\$a\" $P grep -q x"
  echo "printf %s \"\$b\" $P grep -q y"
} > "$w/scripts/gates/gate-a.selftest.sh"
echo "echo \"\$c\" $P grep -qE z" > "$w/scripts/gates/gate-b.selftest.sh"'

# A battery outside scripts/gates/ is still a battery. The 7 sites this gate
# found after the first sweep lived in scripts/bench/ and scripts/meter/,
# directories the sweep's hand-written glob never reached.
case_run a-battery-outside-gates-still-counts 1 "meter/meter.selftest.sh:1" '
w="'"$TMP"'/a-battery-outside-gates-still-counts"; scaffold "$w"
mkdir -p "$w/scripts/meter"
echo "printf %s \"\$a\" $P grep -q x" > "$w/scripts/meter/meter.selftest.sh"'

# --- the three that must NOT fire -----------------------------------------
# `||` is not a pipe. Without this case the [^|] guard could be deleted and
# every battery in the repo would go red for a shape that has no writer at all.
case_run or-else-grep-q-is-not-a-pipe 0 "no battery tests a needle through a pipe" '
w="'"$TMP"'/or-else-grep-q-is-not-a-pipe"; scaffold "$w"
{ echo "[ -n \"\$a\" ] || grep -q x file"
  echo "true"
} > "$w/scripts/gates/gate-a.selftest.sh"'

# A pipe that only DISPLAYS is out of scope and says so in the header. A
# truncated display line changes no verdict.
case_run a-pipe-that-only-displays-is-allowed 0 "no battery tests a needle through a pipe" '
w="'"$TMP"'/a-pipe-that-only-displays-is-allowed"; scaffold "$w"
{ echo "printf %s \"\$out\" | grep -E oops | head -3"
  echo "printf %s \"\$out\" | sed s/a/b/"
} > "$w/scripts/gates/gate-a.selftest.sh"'

# THE FIRST RED THIS GATE EVER PRODUCED. A fixture holds on purpose whatever
# shape the fixture is there to exercise; the runner prunes them, so the gate
# must not see them. This case is the difference between 35 and 37.
case_run a-fixture-is-not-a-battery 0 "this gate read: 1" '
w="'"$TMP"'/a-fixture-is-not-a-battery"; scaffold "$w"
printf "%s\n" "$CLEAN" > "$w/scripts/gates/gate-a.selftest.sh"
mkdir -p "$w/scripts/gates/fixtures/negative-proof/bad/gates"
echo "printf %s \"\$a\" $P grep -q x" \
  > "$w/scripts/gates/fixtures/negative-proof/bad/gates/gate-alpha.selftest.sh"'

# --- could not measure: never a pass --------------------------------------
case_run no-scripts-directory 2 "nothing was read, which is not the same" '
mkdir -p "'"$TMP"'/no-scripts-directory/docs"'

case_run no-runner-to-ask 2 "nothing here can say which files are batteries" '
w="'"$TMP"'/no-runner-to-ask"; mkdir -p "$w/scripts/gates"
printf "%s\n" "$CLEAN" > "$w/scripts/gates/gate-a.selftest.sh"'

# A tree with a runner and no batteries is not a clean tree, it is an unread
# one. Reporting 0 pipes over 0 files would be the emptiest kind of green.
case_run runner-names-no-battery 2 "a population of zero is not a clean population" '
scaffold "'"$TMP"'/runner-names-no-battery"'

echo "--- $pass passed, $fail failed ---"
[ "$fail" -eq 0 ] || exit 1
exit 0
