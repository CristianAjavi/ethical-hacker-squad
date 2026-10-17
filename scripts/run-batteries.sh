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

# EHS_GATE_SET=pull_request keeps the batteries a pull request has to prove:
# the battery of every gate in that set (scripts/gates/data/gate-sets.json) and
# the listed batteries of what users run. Every other battery runs in the weekly
# workflow, which calls this script without the variable. The deferred ones are
# printed by name: a battery that is not run here must not look like one that
# passed.
DEFERRED_BATTERIES=""
if [ "${EHS_GATE_SET:-}" = "pull_request" ]; then
  SETS="$ROOT/gates/data/gate-sets.json"
  python3 - "$SETS" "$LIST" > "$LIST.pr" <<'PY' || { err "COULD NOT MEASURE" "cannot read $SETS"; exit 2; }
import json, os, sys
sets = json.load(open(sys.argv[1]))
gates = set(sets["pull_request"])
extra = set(sets.get("pull_request_batteries", []))
for path in open(sys.argv[2]).read().split():
    name = os.path.basename(path)
    if "/gates/" in path and name.endswith(".selftest.sh"):
        keep = name.replace(".selftest.sh", ".sh") in gates
    else:
        keep = any(path.endswith(e.split("/", 1)[1]) if e.startswith("scripts/") else path.endswith(e) for e in extra)
    print(("KEEP " if keep else "DEFER ") + path)
PY
  DEFERRED_BATTERIES="$(awk '$1 == "DEFER" { printf " %s", $2 }' "$LIST.pr")"
  awk '$1 == "KEEP" { print $2 }' "$LIST.pr" > "$LIST"
fi

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
  # The set is this run's choice, not the battery's: a battery that drives this
  # script on a fixture tree must see the default behaviour.
  EHS_GATE_SET= bash "$t" </dev/null || rc=$?
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
[ -n "$DEFERRED_BATTERIES" ] && echo "deferred to the weekly run (not run here, not passed):$DEFERRED_BATTERIES"
[ "$worst" -eq 0 ]   && echo "every battery behaved"
exit "$worst"
