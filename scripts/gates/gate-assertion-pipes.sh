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
#   Any shell file under scripts/ that pipes into a `grep -q`. The fix is a
#   here-string - `grep -q -- "$needle" <<<"$out"` - which is the same grep, the
#   same flags and the same pattern, with no pipe for a writer to die in.
#
#   The population was NARROWER THAN THE RULE for its first three versions: it
#   was whatever `run-batteries.sh --list` names, and a gate whose self-test runs
#   INLINE - invoked with `--self-test` rather than from a sibling file - is not
#   a battery, so its code was never read. That hole was invisible from inside
#   the gate: it reported a clean zero over the files it could see, which is the
#   most convincing shape a blind spot can take. Measured when it was finally
#   asked from outside: 13 files, 28 sites, three of them in a gate that had
#   just produced a red nobody could reproduce. So the population is now the
#   runner's list PLUS every other `*.sh` under scripts/, and the runner's list
#   is still asked for - it is what proves the wider glob did not lose anybody.
#
#   A line that is ONLY a comment is not an assertion, and is skipped. This file
#   quotes the forbidden shape twice to explain itself; a gate that reddened on
#   its own docstring would be deleted within the week.
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
gate_scope "every *.sh under scripts/ that is not a fixture - the batteries the runner names and the gates that self-test inline: none may pipe into a \`grep -q\`, whose writer can die half-way and be read as a measured absence"
gate_out_of_scope "whether a grep that survives has its exit code read correctly, pipes into anything that only DISPLAYS - a truncated display line changes no verdict - and lines that are only a comment, which assert nothing"

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

n_batteries="$(grep -c . <<<"$LIST")"

# THE WIDER POPULATION. Fixtures are pruned for the same reason the runner
# prunes them: a fixture holds on purpose whatever shape it is there to
# exercise.
# EL MISMO find QUE EL CORREDOR, forma por forma - `-type d -name fixtures
# -prune`, `-print`, `LC_ALL=C sort` - salvo el nombre buscado. Dos podas
# escritas distinto son dos podas que se pueden separar sin que nadie lo note.
ALL="$(find "$ROOT/scripts" -type d -name fixtures -prune -o -type f -name '*.sh' -print 2>/dev/null | LC_ALL=C sort)"
if [ -z "$ALL" ]; then
  gate_warn "no *.sh was found under '$ROOT/scripts': a population of zero is not a clean population"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

# THE WIDE LIST MUST CONTAIN THE NARROW ONE. The runner is still the authority
# on what a battery is; asking it here is what proves the glob widened the
# population instead of trading one blind spot for another. If a battery is
# missing from the glob, the count that follows is a lie and this gate says so
# rather than printing it.
while IFS= read -r b; do
  [ -n "$b" ] || continue
  if ! grep -qxF -- "$b" <<<"$ALL"; then
    gate_warn "the runner names a battery the file sweep did not reach: ${b#"$ROOT"/}. Any count over this population would be smaller than the truth"
    gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
  fi
done <<<"$LIST"

n_files=0
hits=""
n_hits=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n_files=$((n_files + 1))
  # A pipe INTO grep -q. `||` before grep is not a pipe, hence the [^|] guard
  # on the character before the bar: it is what stops `x || grep -q` from being
  # counted, and it is the reason this gate reads 0 on a tree that is clean.
  #
  # Whole-line comments come out first: they assert nothing, and this gate's own
  # header quotes the shape it forbids.
  #
  # ONE PASS, ONE PATTERN, for what is shown and for what is counted. The first
  # version had two spellings of the rule - a `grep -E` to display and a
  # `grep -coE` to count - and `-c` counts LINES while `-o` does not stop it,
  # so a line carrying two sites was reported as one. That is not a hypothesis:
  # it read 27 where there were 28, and the missing one was hunted through a
  # whole iteration as a discrepancy between two scripts. gsub returns how many
  # times it substituted, and substituting `&` leaves the line as it was.
  res="$(awk -v F="${f#"$ROOT"/}" '
    { l = $0; sub(/^[ \t]+/, "", l); if (substr(l, 1, 1) == "#") next
      n = gsub(/[^|][|] *grep -q/, "&")
      if (n > 0) { printf "  %s:%d\n", F, FNR; total += n } }
    END { printf "TOTAL %d\n", total + 0 }' "$f" 2>/dev/null)"
  [ -n "$res" ] || continue
  while IFS= read -r line; do
    case "$line" in
      "TOTAL "*) n_hits=$((n_hits + ${line#TOTAL })) ;;
      "") ;;
      *) hits="$hits
$line" ;;
    esac
  done <<<"$res"
done <<<"$ALL"

gate_info "batteries the runner lists: $n_batteries"
gate_info "shell files this gate read: $n_files"
gate_info "assertions piped into grep -q: $n_hits"

if [ "$n_hits" -gt 0 ]; then
  gate_fail "an assertion hangs on a pipe whose writer can die half-way; use a here-string instead: grep -q -- \"\$needle\" <<<\"\$out\""
  printf '%s\n' "$hits"
  gate_verdict "$GATE_FAIL"; exit "$GATE_FAIL"
fi

gate_ok "no file under scripts/ tests a needle through a pipe"
gate_verdict "$GATE_OK"; exit "$GATE_OK"
