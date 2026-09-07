#!/usr/bin/env bash
# Run every self-test battery in the tree.
#
# WHY THIS FILE EXISTS AT ALL
#     The rule - anything named `*.selftest.sh` is a battery and gets run,
#     wherever it lives - was written once, inline, inside a CI step. That made
#     it unreproducible on a laptop: locally the only battery runner was
#     `scripts/gates/run-all.sh --selftests`, which walks `scripts/gates/` and
#     nothing else, so `scripts/bench/`'s batteries ran in CI and nowhere a
#     maintainer could see. Two paths to the same effect with different reach is
#     how a green comes to mean something other than it looks like.
#
#     So the rule lives here, once, and CI calls this.
#
# DISCOVERY
#     By convention, not by list. A battery added tomorrow in a directory that
#     does not exist today is covered the day it lands - the previous version of
#     this rule named two directories and a third matched neither.
#
#     `fixtures/` is PRUNED rather than filtered afterwards. A gate whose rule is
#     "a battery is a file named <gate>.selftest.sh" can only be proved by a
#     fixture tree that CONTAINS such a file, and those stubs are not batteries:
#     running them would inflate the count, and a stub that exits 0 would pad the
#     green with something that measures nothing.
#
# THE TALLY LEDGER (optional, off unless EHS_TALLY_LEDGER names a file)
#     `gate-declared-case-counts` compares the case count each row of
#     docs/gate-requirements.md declares against what the self-test runs - and
#     to do that it RUNS the self-test. Five of those self-tests are batteries
#     this file also runs, so a CI job that calls both ran them twice: measured
#     59.3 s of duplicated work (median of 3, spread 2%).
#
#     So when EHS_TALLY_LEDGER is set, every battery that exits 0 leaves one
#     line here - `<sha256 of the battery file> <path> <its tally>` - and the
#     gate answers those rows from the ledger instead of running them again.
#
#     The key is the CONTENT of the file, never its name. A tally is reusable
#     only if the bytes that produced it are the bytes that would run now: edit
#     one case, check out another branch, and the hash misses and the battery
#     runs. There is no staleness window to reason about because there is no
#     window, and a miss costs exactly what today costs.
#
#     Only a battery that exited 0 is recorded. A count read off a red battery
#     is not a measurement, and the gate refuses those on its own side too.
#
# Exit codes: 0 = every battery behaved | 1 = one did not | 2 = could not measure
#             (no battery found, or a battery reported it could not measure).
set -uo pipefail


ROOT="${1:-scripts}"
LIST_ONLY=0
[ "${1:-}" = "--list" ] && { LIST_ONLY=1; ROOT="${2:-scripts}"; }
LEDGER="${EHS_TALLY_LEDGER:-}"

# No digest tool, no ledger line - and then the gate runs the battery, which is
# what it does today. Degrading to the slow path is the only safe degradation.
if command -v sha256sum >/dev/null 2>&1; then
  digest() { sha256sum "$1" | cut -d' ' -f1; }
elif command -v shasum >/dev/null 2>&1; then
  digest() { shasum -a 256 "$1" | cut -d' ' -f1; }
else
  digest() { :; }
fi

# GitHub annotations when running there, plain text on a laptop. Same verdict.
if [ -n "${GITHUB_ACTIONS:-}" ]; then
  group()  { echo "::group::$1"; }
  endgrp() { echo "::endgroup::"; }
  err()    { echo "::error title=$1::$2"; }
else
  group()  { echo "--- $1"; }
  endgrp() { :; }
  err()    { echo "  $1: $2"; }
fi

[ -d "$ROOT" ] || { err "COULD NOT MEASURE" "$ROOT does not exist"; exit 2; }

TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t batteries)" || {
  err "COULD NOT MEASURE" "I could not create a temporary directory"; exit 2; }
trap 'rm -rf "$TMPD"' EXIT
LIST="$TMPD/batteries.txt"

find "$ROOT" -type d -name fixtures -prune -o \
     -type f -name '*.selftest.sh' -print | LC_ALL=C sort > "$LIST"

if [ "$LIST_ONLY" -eq 1 ]; then cat "$LIST"; exit 0; fi

worst=0; found=0; failed=""; unmeasured=""

# </dev/null is not decoration: the list of batteries is this loop's stdin over
# FD 3, and a battery that reads stdin - a `read`, a bare `cat`, a jq with no
# file - would swallow the rest of the list and the loop would end early,
# declaring green what it never ran.
while IFS= read -r t <&3; do
  [ -n "$t" ] || continue
  found=$((found + 1))
  group "$t"
  rc=0
  # tee, not a redirect to a file: stdout keeps streaming as it did, stderr is
  # untouched and still goes to stderr. `$?` after a pipeline reads the LAST
  # command in it, so the battery's own code is taken from PIPESTATUS.
  bash "$t" </dev/null | tee "$TMPD/out"
  rc=${PIPESTATUS[0]}
  endgrp
  if [ "$rc" -eq 0 ] && [ -n "$LEDGER" ]; then
    tally="$(grep -oE '[0-9]+ passed, [0-9]+ failed(, [0-9]+ skipped)?' \
             "$TMPD/out" | tail -1)"
    sha="$(digest "$t")"
    if [ -n "$tally" ] && [ -n "$sha" ]; then
      printf '%s %s %s\n' "$sha" "$t" "$tally" >> "$LEDGER"
    fi
  fi
  case "$rc" in
    0) echo "ok        $t" ;;
    2) err "COULD NOT MEASURE" "$t could not run"
       unmeasured="$unmeasured $t"; worst=2 ;;
    *) err "SELFTEST FAILED" "$t did not behave as specified"
       failed="$failed $t"; [ "$worst" -eq 2 ] || worst=1 ;;
  esac
done 3< "$LIST"

if [ "$found" -eq 0 ]; then
  err "COULD NOT MEASURE" "no self-test battery was found under $ROOT"
  exit 2
fi

echo ""
echo "batteries run: $found"
[ -n "$failed" ]     && echo "did not behave:$failed"
[ -n "$unmeasured" ] && echo "could not measure:$unmeasured"
[ "$worst" -eq 0 ]   && echo "every battery behaved"
exit "$worst"
