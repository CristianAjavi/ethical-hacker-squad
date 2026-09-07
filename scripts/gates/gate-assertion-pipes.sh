#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-assertion-pipes.sh — an assertion may not hang on a pipe that can die.
#
# WHY IT EXISTS
#   Thirty assertions across twenty-three batteries were written this way:
#
#       printf '%s' "$out" | grep -q -- "$needle"
#
#   and the shape cannot tell "the gate never said it" from "my grep died".
#   `grep -q` exits 0 the instant it matches, so a MATCH makes the writer see
#   EPIPE, and a NON-match makes grep read to the end with no EPIPE. When a CI
#   run produced BOTH at once - a broken pipe AND a "never said" - the only
#   reading left was that grep itself had died, and the case had reported that
#   as a measured absence. It reported it while printing, two lines below, the
#   very sentence it claimed was missing.
#
#   The cause of that death was never established: one broken pipe in the whole
#   run, no `cannot allocate`, no `Killed`, no `No space left`. That IS the
#   finding. The idiom destroys the evidence it would need to diagnose itself,
#   so it can only be removed, not investigated.
#
# WHAT IT MEASURES
#   Any `*.selftest.sh` under scripts/ that pipes into a `grep -q`. The fix is
#   a here-string - `grep -q -- "$needle" <<<"$out"` - which is the same grep,
#   the same flags and the same pattern, with no pipe for a writer to die in.
#
# WHAT IT DOES NOT MEASURE
#   Whether a surviving grep's exit code is read correctly. A grep killed by a
#   signal is still indistinguishable from "not found" here, because separating
#   them changes every battery's tally line and the count gate that reads it.
#   That is tracked separately; this gate closes the mechanism that was
#   actually observed, and says plainly that it does not close the class.
#
#   It also says nothing about pipes into anything else: `| head`, `| sed`,
#   `| grep -E` for DISPLAY are not assertions, and a truncated display line
#   does not change a verdict.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no batteries found where they must be).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"
ROOT="${EHS_REPO_ROOT:-$(gate_root)}"

gate_header "assertion-pipes (a needle test may not hang on a pipe)"
gate_scope "every *.selftest.sh under scripts/: none may pipe into a \`grep -q\`, whose writer can die half-way and be read as a measured absence"
gate_out_of_scope "whether a grep that survives has its exit code read correctly, and pipes into anything that only DISPLAYS - a truncated display line changes no verdict"

if [ ! -d "$ROOT/scripts" ]; then
  gate_warn "there is no scripts/ directory under '$ROOT': nothing was read, which is not the same as nothing being there"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

# THE POPULATION IS ASKED FOR, NOT INVENTED. The first version of this gate
# globbed *.selftest.sh with find and came back with 37 where the runner has
# 35: the two extra were FIXTURES under scripts/gates/fixtures/, which contain
# on purpose whatever shape the fixture is there to exercise. A second
# predicate standing in for the real one measures something else, so the
# question goes to run-batteries.sh --list, which is what decides what a
# battery is around here.
RUNNER="$ROOT/scripts/run-batteries.sh"
if [ ! -f "$RUNNER" ]; then
  gate_warn "there is no scripts/run-batteries.sh under '$ROOT': nothing here can say which files are batteries"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
# The root goes in explicitly. run-batteries.sh defaults to `scripts` RELATIVE
# TO THE CWD, and run from anywhere else it lists nothing and still exits 0 with
# its complaint on stderr - so a gate that asked without saying where would read
# an empty list and blame the tree.
LIST="$(bash "$RUNNER" --list "$ROOT/scripts" 2>/dev/null)"
if [ -z "$LIST" ]; then
  gate_warn "run-batteries.sh --list named no battery under '$ROOT/scripts': a population of zero is not a clean population"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

n_files=0
hits=""
n_hits=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n_files=$((n_files + 1))
  # A pipe INTO grep -q. `||` before grep is not a pipe, hence the [^|] guard
  # on the character before the bar: it is what stops `x || grep -q` from being
  # counted, and it is the reason this gate reads 0 on a tree that is clean.
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    hits="$hits
  ${f#"$ROOT"/}:$line"
    n_hits=$((n_hits + 1))
  done <<<"$(grep -nE '[^|]\| *grep -q' "$f" 2>/dev/null | cut -d: -f1)"
done <<<"$LIST"

gate_info "batteries the runner lists, and this gate read: $n_files"
gate_info "assertions piped into grep -q: $n_hits"

if [ "$n_hits" -gt 0 ]; then
  gate_fail "an assertion hangs on a pipe whose writer can die half-way; use a here-string instead: grep -q -- \"\$needle\" <<<\"\$out\""
  printf '%s\n' "$hits"
  gate_verdict "$GATE_FAIL"; exit "$GATE_FAIL"
fi

gate_ok "no battery tests a needle through a pipe"
gate_verdict "$GATE_OK"; exit "$GATE_OK"
