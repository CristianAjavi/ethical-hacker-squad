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
# Exit codes: 0 = every battery behaved | 1 = one did not | 2 = could not measure
#             (no battery found, or a battery reported it could not measure).
set -uo pipefail

ROOT="${1:-scripts}"
LIST_ONLY=0
[ "${1:-}" = "--list" ] && { LIST_ONLY=1; ROOT="${2:-scripts}"; }

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

# report <battery> <rc> - fold one battery's outcome into the totals. BOTH paths
# below call this and neither keeps its own copy, so a serial run and a parallel
# run cannot drift into two different verdicts for the same exit code.
report() {
  case "$2" in
    0) echo "ok        $1" ;;
    2) err "COULD NOT MEASURE" "$1 could not run"
       unmeasured="$unmeasured $1"; worst=2 ;;
    *) err "SELFTEST FAILED" "$1 did not behave as specified"
       failed="$failed $1"; [ "$worst" -eq 2 ] || worst=1 ;;
  esac
}

# HOW MANY AT A TIME
#     MEASURED on this tree's 29 batteries, the two stacks alternated in one
#     session because this machine drifts: 364.7 s one at a time against 141.5 s
#     at four, 61% less, and the two ranges do not overlap. The slowest single
#     battery is 40.7 s and nineteen of the twenty-nine finish under 8 s, so
#     almost all of that wall clock was this runner waiting.
#
#     That gain did NOT exist when this paragraph was first written. While every
#     fixture case tarred the tree, four workers measured 247.9 s against a
#     serial 257.3 s - flat, because the copy was already saturating the disk and
#     a second worker had nothing to do but queue behind it. Overlapping the
#     batteries only started paying once `*.selftest.sh` cloned its fixture
#     instead of tarring it. The two changes look independent and are not: this
#     one was measured worthless first, and shipped only after the other landed.
#
#     They can overlap because each battery already builds its own `mktemp -d` -
#     nothing they write is shared - which is the same isolation argument that
#     made the reproduction cases safe to run side by side.
#
#     Bounded, never unbounded: 29 at once on a four-core runner would thrash,
#     and every duration a battery reports would stop meaning anything.
#     EHS_BATTERY_JOBS overrides the count, and 1 selects the serial path below,
#     which is this runner's original loop unchanged. The self-test compares the
#     two against each other on every run.
JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
case "$JOBS" in ''|*[!0-9]*) JOBS=1 ;; esac
[ "$JOBS" -ge 1 ] || JOBS=1
[ "$JOBS" -le 4 ] || JOBS=4
case "${EHS_BATTERY_JOBS:-}" in
  ''|*[!0-9]*) : ;;   # an unreadable setting is not a reason to refuse to measure
  *) [ "$EHS_BATTERY_JOBS" -ge 1 ] && JOBS="$EHS_BATTERY_JOBS" ;;
esac

if [ "$JOBS" -le 1 ]; then

# </dev/null is not decoration: the list of batteries is this loop's stdin over
# FD 3, and a battery that reads stdin - a `read`, a bare `cat`, a jq with no
# file - would swallow the rest of the list and the loop would end early,
# declaring green what it never ran.
while IFS= read -r t <&3; do
  [ -n "$t" ] || continue
  found=$((found + 1))
  group "$t"
  rc=0
  bash "$t" </dev/null || rc=$?
  endgrp
  report "$t" "$rc"
done 3< "$LIST"

else

# THE QUEUE IS `mkdir`, NOT A FIFO
#     `mkdir` succeeds for exactly one caller and fails for every other, and no
#     caller ever blocks waiting for another. That is the whole of the mutual
#     exclusion here.
#
#     The obvious alternative - several workers reading one shared FIFO - was
#     built and MEASURED first, and on bash 3.2 it splits and merges lines
#     between readers: 488 distinct lines out of 500, with fragments like
#     `-12item-0123item-0124`, followed by a deadlock on the mangled terminator.
#     A queue that hands a worker half a path runs half a battery and reports on
#     the other half.
#
#     A fixed slice per worker was the other candidate and is simpler still, but
#     these batteries cost between a fraction of a second and 40.7 s, so a slice
#     leaves most workers idle behind whoever drew the slow one. Simulated on the
#     measured serial costs at four workers: 118.4 s for a slice against 76.5 s
#     for this queue. The 1.5x gap between the two schedulers held up; the
#     absolute number did not, and the difference matters. That same simulation
#     forecast 76.5 s for a run that then measured 247.9 s, because it assumed a
#     battery costs the same whatever else is running - measured, four at a time
#     expand each other x2.0 to x4.5. It compares two schedulers. It does not
#     predict a clock, and it was not allowed to decide whether this path ships.
CLEAN="$TMPD/clean.txt"
awk 'length($0)' "$LIST" > "$CLEAN"
found="$(awk 'END { print NR + 0 }' "$CLEAN")"

w=0
while [ "$w" -lt "$JOBS" ]; do
  w=$((w + 1))
  (
    k=0
    while [ "$k" -lt "$found" ]; do
      k=$((k + 1))
      mkdir "$TMPD/claim-$k" 2>/dev/null || continue
      b="$(awk -v n="$k" 'NR == n { print; exit }' "$CLEAN")"
      # A worker decides nothing: it records what happened and stops there. The
      # parent folds the verdicts afterwards, in list order, so a parallel run
      # prints the report a serial run prints - only the order the work
      # FINISHED in differs, and that never reaches the output.
      brc=0
      bash "$b" </dev/null > "$TMPD/slot-$k.out" 2>&1 || brc=$?
      printf '%s\n' "$brc" > "$TMPD/slot-$k.rc"
    done
  ) &
done
wait

k=0
while [ "$k" -lt "$found" ]; do
  k=$((k + 1))
  t="$(awk -v n="$k" 'NR == n { print; exit }' "$CLEAN")"
  group "$t"
  [ -f "$TMPD/slot-$k.out" ] && cat "$TMPD/slot-$k.out"
  endgrp
  # A slot with no exit code is a battery whose worker never got to write one:
  # killed, out of memory, the machine gave out. That is COULD NOT MEASURE and
  # never a pass. Without a value that means "I do not know", an empty slot
  # reads as a zero and pads the green with a battery that never finished.
  rc="$(cat "$TMPD/slot-$k.rc" 2>/dev/null)"
  case "$rc" in ''|*[!0-9]*) rc=2 ;; esac
  report "$t" "$rc"
done

fi

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
