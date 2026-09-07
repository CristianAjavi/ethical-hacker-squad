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
# WHY THEY RUN AT THE SAME TIME NOW
#     Because the thing that stopped it was measured and then removed, in that
#     order. Nine batteries copied the whole repository once per case without
#     excluding `tooling/claude-cli/node_modules` - 259 MB of the tree's 322 MB,
#     which none of them reads - into a fresh directory every time, and one of
#     them peaked at 6168 MiB of its own temporary tree. Starting two of those
#     together was a way to run the disk out, so this loop stayed sequential on
#     a ten-core machine. With node_modules excluded (T-ehs-46) that same
#     battery peaks at 10.1 MiB, and `--jobs` became a real choice.
#
#     The default is deliberately below the core count: `coverage-sweep.mutants`
#     runs four workers of its own, and a runner that oversubscribes the box
#     makes every timing taken on it unreadable.
#
#     Output is buffered per battery and printed IN LIST ORDER, so a parallel
#     run and a sequential one produce the same transcript and the same verdict.
#     Only the wall clock differs. The printer walks the list from the first
#     battery to the last and waits at each one, so a slow battery early in the
#     list holds back the printing of faster ones behind it - a cosmetic delay,
#     deliberately preferred to a transcript whose order depends on which
#     machine ran it.
#
#     That serial printer is also where the ledger line is written. Appending
#     from the workers would put concurrent writes on one file and buy a
#     question nobody needs to answer; the printer is single-threaded by
#     construction, so the ordering is the list's and the file is written by one
#     process.
#
# THE RESULT THAT IS NEVER COMING
#     The printer waits at battery n for `n.rc` to appear. Written that way and
#     no other, its state has two values - "it is here" and "not yet" - and no
#     value for "it is never going to be". A launcher that ends early leaves the
#     printer waiting on a file nobody will write, and the job hangs until the
#     CI timeout kills it six hours later with nothing said about why.
#
#     That is not hypothetical: this file's own mutant case does exactly that.
#     It takes FD 3 away from the launcher so a battery that reads stdin eats
#     the rest of the list, which is the defect the case exists to prove - and
#     the parallel printer answered it by hanging instead of by counting.
#
#     So the launcher leaves a marker when its last worker is done, and the
#     printer reads the absence of `n.rc` beside the presence of that marker as
#     what it is: this battery has no result, which is COULD NOT MEASURE. The
#     stall bound underneath it covers the one path the marker cannot - a
#     launcher killed outright, which writes no marker and leaves no worker to
#     write anything either. Its default is far above any battery's runtime, so
#     it is a floor under an infinite wait and not a policy about slowness.
#
# Exit codes: 0 = every battery behaved | 1 = one did not | 2 = could not measure
#             (no battery found, or a battery reported it could not measure).
set -uo pipefail


LIST_ONLY=0
JOBS="${EHS_BATTERY_JOBS:-4}"
ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --list)   LIST_ONLY=1; shift ;;
    --jobs)   JOBS="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
    --jobs=*) JOBS="${1#--jobs=}"; shift ;;
    --)       shift ;;
    -*)       echo "  COULD NOT MEASURE: unknown option $1" >&2; exit 2 ;;
    *)        ROOT="$1"; shift ;;
  esac
done
ROOT="${ROOT:-scripts}"
LEDGER="${EHS_TALLY_LEDGER:-}"

# A worker count that is not a positive integer is not a slower run, it is an
# unmeasured one: `--jobs 0` would start nothing and report every battery green.
case "$JOBS" in
  ''|*[!0-9]*) echo "  COULD NOT MEASURE: --jobs takes a positive integer, got '$JOBS'" >&2; exit 2 ;;
esac
[ "$JOBS" -ge 1 ] || { echo "  COULD NOT MEASURE: --jobs takes a positive integer, got '$JOBS'" >&2; exit 2; }

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

total="$(grep -c . "$LIST")"
if [ "$total" -eq 0 ]; then
  err "COULD NOT MEASURE" "no self-test battery was found under $ROOT"
  exit 2
fi

# The launcher runs in the background so the printer can report finished
# batteries while later ones are still going. Its `jobs -pr` therefore counts
# only the batteries it started, which is what the throttle has to bound.
#
# </dev/null is not decoration: the list of batteries is the launcher's stdin
# over FD 3, and a battery that reads stdin - a `read`, a bare `cat`, a jq with
# no file - would swallow the rest of the list and the loop would end early,
# declaring green what it never ran.
(
  i=0
  while IFS= read -r t <&3; do
    [ -n "$t" ] || continue
    i=$((i + 1))
    (
      rc=0
      bash "$t" </dev/null > "$TMPD/$i.out" 2>&1 || rc=$?
      # Written aside and moved into place: the printer takes the existence of
      # `$i.rc` as "this battery is finished", and a plain redirect creates the
      # file before the exit code has been written into it.
      echo "$rc" > "$TMPD/$i.rc.part" && mv "$TMPD/$i.rc.part" "$TMPD/$i.rc"
    ) &
    while [ "$(jobs -pr | wc -l)" -ge "$JOBS" ]; do sleep 0.2; done
  done 3< "$LIST"
  wait
  # Written aside and moved, for the same reason the exit codes are: the printer
  # takes this file's existence as "no further result is coming".
  : > "$TMPD/launcher.done.part" && mv "$TMPD/launcher.done.part" "$TMPD/launcher.done"
) &
launcher=$!

STALL="${EHS_BATTERY_STALL:-900}"
case "$STALL" in
  ''|*[!0-9]*) err "COULD NOT MEASURE" "EHS_BATTERY_STALL takes a positive integer, got '$STALL'"; exit 2 ;;
esac
# THE BOUND IS IN SECONDS AND THE POLL IS EVERY 0.2 s. Counted in polls instead,
# the documented 900 s floor was 180 s, and "a floor under an infinite wait and
# not a policy about slowness" - the sentence in this file's own header - was a
# policy about slowness with its threshold at a fifth of what everyone reading
# the variable would assume. It cut a battery that was still running and printed
# its half-written output underneath the word UNMEASURABLE.
STALL_TICKS=$((STALL * 5))

worst=0; found=0; failed=""; unmeasured=""
n=0
while [ "$n" -lt "$total" ]; do
  n=$((n + 1))
  t="$(sed -n "${n}p" "$LIST")"
  have=0; waited=0
  while [ "$have" -eq 0 ]; do
    if [ -f "$TMPD/$n.rc" ]; then have=1; break; fi
    if [ -f "$TMPD/launcher.done" ]; then
      # One more look before giving up: the result may have landed between the
      # two tests, and a race that discards a real exit code would report a
      # battery that ran as one that did not.
      [ -f "$TMPD/$n.rc" ] && have=1
      break
    fi
    [ "$waited" -ge "$STALL_TICKS" ] && break
    sleep 0.2
    waited=$((waited + 1))
  done
  group "$t"
  [ -f "$TMPD/$n.out" ] && cat "$TMPD/$n.out"
  endgrp
  # `found` counts batteries that came back with an exit code, not rows of the
  # list. A headline reading "batteries run: 3" for a run where one produced a
  # result and two produced nothing states something it did not measure - and
  # that is exactly what the mutant below produced before this line moved.
  if [ "$have" -eq 0 ]; then
    err "COULD NOT MEASURE" "$t produced no exit code; nothing is going to write one"
    unmeasured="$unmeasured $t"; worst=2
    continue
  fi
  rc="$(cat "$TMPD/$n.rc")"
  case "$rc" in
    ''|*[!0-9]*)
      err "COULD NOT MEASURE" "$t left '$rc' where its exit code should be"
      unmeasured="$unmeasured $t"; worst=2
      continue ;;
  esac
  found=$((found + 1))
  if [ "$rc" -eq 0 ] && [ -n "$LEDGER" ]; then
    tally="$(grep -oE '[0-9]+ passed, [0-9]+ failed(, [0-9]+ skipped)?' \
             "$TMPD/$n.out" | tail -1)"
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
done
wait "$launcher"

echo ""
echo "batteries run: $found (up to $JOBS at a time)"
[ -n "$failed" ]     && echo "did not behave:$failed"
[ -n "$unmeasured" ] && echo "could not measure:$unmeasured"
[ "$worst" -eq 0 ]   && echo "every battery behaved"
exit "$worst"
