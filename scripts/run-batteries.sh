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
