#!/usr/bin/env bash
# Self-test for run-batteries.sh.
#
# A runner that reports green is making a claim about batteries it never ran, so
# every case here is about the ways that claim goes wrong quietly: a battery that
# fails, one that cannot measure, none at all, a fixture stub padding the count,
# and a battery that eats the list it is being read from. The last one is the
# reason this runner reads over FD 3 and launches with </dev/null, and the mutant
# at the end proves that is load-bearing rather than folklore.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SUBJECT="$HERE/run-batteries.sh"
[ -f "$SUBJECT" ] || { echo "UNMEASURABLE the subject is missing: $SUBJECT"; exit 2; }

# This file runs blind to any ledger its caller is using, and every case that
# wants one builds its own. Found the hard way: run under run-batteries.sh -
# which exports EHS_TALLY_LEDGER - the "no ledger written" case inherited it,
# passed anyway, and the toy battery it launched wrote a line into the REAL
# ledger. A case that is green because of what it inherited is green for the
# wrong reason, and the artefact it polluted belonged to someone else.
unset EHS_TALLY_LEDGER

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-runner-XXXXXX")" || { echo "UNMEASURABLE no tmpdir"; exit 2; }
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  PASS  $1"; }
bad() { fail=$((fail+1)); echo "  FAIL  $1"; }

# battery <dir> <name> <exit-code> — a battery that does nothing but exit
battery() {
  mkdir -p "$1"
  printf '#!/usr/bin/env bash\nexit %s\n' "$3" > "$1/$2.selftest.sh"
  chmod +x "$1/$2.selftest.sh"
}

# says <dir> <name> <exit-code> <line> — a battery that prints something first
says() {
  mkdir -p "$1"
  printf '#!/usr/bin/env bash\necho "%s"\nexit %s\n' "$4" "$3" > "$1/$2.selftest.sh"
  chmod +x "$1/$2.selftest.sh"
}

run() { bash "$SUBJECT" "$1" >"$TMP/out" 2>&1; }

# runl <dir> <ledger> — the same run, with a tally ledger to fill in
runl() { EHS_TALLY_LEDGER="$2" bash "$SUBJECT" "$1" >"$TMP/out" 2>&1; }

echo "== the ordinary verdicts =="

battery "$TMP/green/a" one 0
battery "$TMP/green/b" two 0
run "$TMP/green"; rc=$?
[ "$rc" -eq 0 ] && ok "every battery behaving gives rc 0" || bad "expected rc 0, got $rc"
grep -q 'batteries run: 2' "$TMP/out" && ok "the count is reported" || bad "no count reported"

battery "$TMP/red" ok  0
battery "$TMP/red" bad 1
run "$TMP/red"; rc=$?
[ "$rc" -eq 1 ] && ok "a battery that fails gives rc 1" || bad "expected rc 1, got $rc"
grep -q 'did not behave.*bad.selftest.sh' "$TMP/out" \
  && ok "the failing battery is named, not just counted" || bad "the failure is anonymous"

echo "== could not measure outranks both green and red =="

battery "$TMP/unmeas" ok   0
battery "$TMP/unmeas" cant 2
run "$TMP/unmeas"; rc=$?
[ "$rc" -eq 2 ] && ok "a battery reporting 2 gives rc 2, never 0" || bad "expected rc 2, got $rc"

battery "$TMP/both" bad  1
battery "$TMP/both" cant 2
run "$TMP/both"; rc=$?
[ "$rc" -eq 2 ] && ok "2 outranks 1 when both happen" || bad "expected rc 2 when both, got $rc"

mkdir -p "$TMP/none" && : > "$TMP/none/README.md"
run "$TMP/none"; rc=$?
[ "$rc" -eq 2 ] && ok "finding no battery is rc 2, not a silent green" || bad "expected rc 2, got $rc"

run "$TMP/absent-root"; rc=$?
[ "$rc" -eq 2 ] && ok "an absent root is rc 2" || bad "expected rc 2 for an absent root, got $rc"

echo "== a fixture stub is not a battery =="

battery "$TMP/pruned" real 0
battery "$TMP/pruned/fixtures/some/tree" stub 1
run "$TMP/pruned"; rc=$?
[ "$rc" -eq 0 ] && ok "a failing stub under fixtures/ does not fail the run" \
                || bad "fixtures/ was not pruned: rc $rc"
grep -q 'batteries run: 1' "$TMP/out" \
  && ok "the stub does not pad the count either" || bad "the stub was counted"

echo "== a battery that reads stdin must not swallow the list =="

mkdir -p "$TMP/greedy"
printf '#!/usr/bin/env bash\ncat >/dev/null\nexit 0\n' > "$TMP/greedy/a-greedy.selftest.sh"
battery "$TMP/greedy" b-after 0
battery "$TMP/greedy" c-after 0
chmod +x "$TMP/greedy"/*.selftest.sh
run "$TMP/greedy"; rc=$?
[ "$rc" -eq 0 ] && ok "the greedy battery itself passes" || bad "greedy fixture rc $rc"
grep -q 'batteries run: 3' "$TMP/out" \
  && ok "all three ran — the greedy one did not eat the list" \
  || bad "the list was truncated: $(grep -o 'batteries run: [0-9]*' "$TMP/out")"

echo "== mutant: prove the protection is doing the work =="

# THREE edits, and it has to be three ON ONE OF THE TWO PLATFORMS. Take away
# FD 3 and </dev/null and put the worker back in the foreground, which is the
# shape the rule had when it lived inline in a CI step: the greedy battery eats
# the rest of the list and the count drops.
#
# The third edit is there because of a disagreement between bash versions that
# cost a red CI run to find. Bash redirects the stdin of an ASYNCHRONOUS command
# from /dev/null "in the absence of any explicit redirections", and the two
# shells do not read that clause the same way when the redirection sits on the
# enclosing loop's `done` rather than on the command. Measured, same commit:
#
#   bash 3.2.57 (macOS)  the worker inherits the list      -> mutant truncates
#   bash 5.x    (Linux)  the worker gets /dev/null anyway  -> mutant survives
#
# So a two-edit mutant proves the rule on one machine and proves nothing on the
# other, while reporting the same green. Putting the worker in the foreground
# removes that difference, and the mutant then dies on both.
#
# This case also went green over a broken protection once, and it is worth
# knowing how. When the runner learned to launch batteries in parallel, its
# count line was left counting ROWS OF THE LIST rather than results: the mutant
# truncated the list exactly as intended, the printer walked all three rows
# anyway, and "batteries run: 3" came out of a run in which one battery had run.
# The needle below is that count. A tally that reports work nobody did will
# cover for whatever broke it.
sed -e 's#while IFS= read -r t <&3; do#while IFS= read -r t; do#' \
    -e 's#done 3< "$LIST"#done < "$LIST"#' \
    -e 's#^    ) &$#    )#' \
    -e 's# </dev/null##' "$SUBJECT" > "$TMP/mutant.sh"
if cmp -s "$SUBJECT" "$TMP/mutant.sh"; then
  bad "the mutant did not apply: this battery would pass without measuring anything"
else
  bash "$TMP/mutant.sh" "$TMP/greedy" >"$TMP/mout" 2>&1
  if grep -q 'batteries run: 3' "$TMP/mout"; then
    bad "the mutant ALSO runs all three: the FD-3 and </dev/null are not what protects"
  else
    ok "the mutant truncates the list ($(grep -o 'batteries run: [0-9]*' "$TMP/mout" || echo 'none')) — the protection is load-bearing"
  fi
fi

echo "== --list names them without running them =="

battery "$TMP/listing" only 1
bash "$SUBJECT" --list "$TMP/listing" >"$TMP/out" 2>&1; rc=$?
[ "$rc" -eq 0 ] && grep -q 'only.selftest.sh' "$TMP/out" \
  && ok "--list prints the battery and does not run it" \
  || bad "--list misbehaved: rc $rc"

echo "== the tally ledger: what gets recorded, and what must not =="

# The gate that checks the case counts in docs/gate-requirements.md runs these
# same batteries. When this runner leaves its tallies behind, that gate reads
# them instead of running them again: measured 40.4 s -> 3.9 s, ranges apart.
# What it records is therefore load-bearing, and so is what it refuses to.

says "$TMP/led_ok" green 0 "5 passed, 0 failed"
runl "$TMP/led_ok" "$TMP/led_ok.txt"
if [ -s "$TMP/led_ok.txt" ] && grep -q '5 passed, 0 failed' "$TMP/led_ok.txt" \
   && [ "$(awk '{print length($1)}' "$TMP/led_ok.txt" | head -1)" = "64" ]; then
  ok "a green battery leaves one line: sha256, path, tally"
else
  bad "no usable ledger line: $(cat "$TMP/led_ok.txt" 2>&1 | head -1)"
fi

# A count read off a red battery is not a measurement. It must not reach the
# ledger at all, because on the other side a hit is trusted without a rerun.
says "$TMP/led_red" red 1 "3 passed, 1 failed"
runl "$TMP/led_red" "$TMP/led_red.txt"
[ ! -s "$TMP/led_red.txt" ] \
  && ok "a battery that came back red records nothing" \
  || bad "a red battery got into the ledger: $(head -1 "$TMP/led_red.txt")"

says "$TMP/led_mute" mute 0 "the battery ran and everything was fine"
runl "$TMP/led_mute" "$TMP/led_mute.txt"
[ ! -s "$TMP/led_mute.txt" ] \
  && ok "a battery that prints no tally records nothing" \
  || bad "a battery with no tally got in: $(head -1 "$TMP/led_mute.txt")"

# The default is off. A runner that wrote a ledger nobody asked for would be
# leaving a file in whatever directory it happened to be pointed at.
says "$TMP/led_off" green 0 "5 passed, 0 failed"
run "$TMP/led_off"
[ ! -e "$TMP/led_off.txt" ] \
  && ok "no EHS_TALLY_LEDGER, no ledger written" \
  || bad "a ledger appeared without being asked for"

# The key is the CONTENT. Change one byte of the battery and the old line can
# no longer answer for it - that is the whole staleness argument, measured.
says "$TMP/led_key" green 0 "5 passed, 0 failed"
runl "$TMP/led_key" "$TMP/led_key1.txt"
says "$TMP/led_key" green 0 "6 passed, 0 failed"
runl "$TMP/led_key" "$TMP/led_key2.txt"
k1="$(awk '{print $1}' "$TMP/led_key1.txt" | head -1)"
k2="$(awk '{print $1}' "$TMP/led_key2.txt" | head -1)"
if [ -n "$k1" ] && [ -n "$k2" ] && [ "$k1" != "$k2" ]; then
  ok "editing the battery changes the key, so an old line cannot answer for it"
else
  bad "the key did not move with the content: $k1 vs $k2"
fi

# The leak above, as a case: with a ledger in the ENVIRONMENT and none asked
# for, the runner must not write into it. Nothing else in this file would notice
# - the toy directory stays clean either way, and the line lands elsewhere.
says "$TMP/led_leak" green 0 "5 passed, 0 failed"
: > "$TMP/led_probe.txt"
EHS_TALLY_LEDGER="$TMP/led_probe.txt" bash "$SUBJECT" "$TMP/led_leak" >"$TMP/out" 2>&1
if [ -s "$TMP/led_probe.txt" ]; then
  ok "a ledger in the environment IS honoured, so the probe can tell silence apart"
else
  bad "the probe stayed empty: this case cannot tell a leak from a refusal"
fi

echo "== the workers, and what they must not change =="

# slow <dir> <name> <seconds> <line> - a battery that takes its time
slow() {
  mkdir -p "$1"
  printf '#!/usr/bin/env bash\nsleep %s\necho "%s"\nexit 0\n' "$3" "$4" > "$1/$2.selftest.sh"
  chmod +x "$1/$2.selftest.sh"
}

# A worker count that is not a positive integer must stop the run, not shrink
# it. `--jobs 0` starts nothing, and a runner that then printed "every battery
# behaved" would be reporting a green it never measured.
battery "$TMP/jobs" one 0
bash "$SUBJECT" --jobs 0 "$TMP/jobs" >"$TMP/out" 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "--jobs 0 is COULD NOT MEASURE, not a run of nothing" \
                || bad "--jobs 0 gave rc $rc"
grep -q 'every battery behaved' "$TMP/out" \
  && bad "--jobs 0 still claimed every battery behaved" \
  || ok "--jobs 0 claims nothing about the batteries"

bash "$SUBJECT" --jobs seven "$TMP/jobs" >"$TMP/out" 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "a non-numeric --jobs is COULD NOT MEASURE" \
                || bad "--jobs seven gave rc $rc"

bash "$SUBJECT" --jobs=3 "$TMP/jobs" >"$TMP/out" 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "--jobs=3 is accepted in the joined form" || bad "--jobs=3 gave rc $rc"
grep -q 'up to 3 at a time' "$TMP/out" \
  && ok "the count line declares how many ran at once" || bad "the worker count is not declared"

bash "$SUBJECT" --nonsense "$TMP/jobs" >"$TMP/out" 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "an unknown option is COULD NOT MEASURE, not ignored" \
                || bad "--nonsense gave rc $rc"

# The point of the buffered printer. `aaa` takes a second, `zzz` is instant, and
# `aaa` sorts first: whoever finishes first, the transcript reads in LIST order.
# Without that, the same commit produces a different log on every machine and
# two runs can only be compared by eye.
slow    "$TMP/order" aaa 1 "SLOW-FIRST"
says    "$TMP/order" zzz 0 "FAST-SECOND"
bash "$SUBJECT" --jobs 4 "$TMP/order" >"$TMP/out" 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "a slow battery beside a fast one still gives rc 0" || bad "rc $rc"
a="$(grep -n 'SLOW-FIRST'  "$TMP/out" | head -1 | cut -d: -f1)"
z="$(grep -n 'FAST-SECOND' "$TMP/out" | head -1 | cut -d: -f1)"
if [ -n "$a" ] && [ -n "$z" ] && [ "$a" -lt "$z" ]; then
  ok "the transcript is in list order, not in finishing order"
else
  bad "the slow battery printed at line '$a', the fast one at '$z'"
fi

# The control the case above needs: if BOTH batteries were fast, list order and
# finishing order would agree by accident and the case would pass on a runner
# that had no printer at all.
if [ -n "$a" ] && [ -n "$z" ]; then
  ok "both lines were found, so the order above was actually compared"
else
  bad "one of the two lines is missing: nothing was compared"
fi

# Serial and parallel must be the same measurement. Only the clock may differ.
battery "$TMP/same/a" one 0
says    "$TMP/same/b" two 0 "3 passed, 0 failed"
battery "$TMP/same/c" bad 1
bash "$SUBJECT" --jobs 1 "$TMP/same" >"$TMP/one.out" 2>&1; r1=$?
bash "$SUBJECT" --jobs 4 "$TMP/same" >"$TMP/four.out" 2>&1; r4=$?
[ "$r1" -eq "$r4" ] && ok "one worker and four give the same exit code ($r1)" \
                    || bad "one worker gave $r1, four gave $r4"
if diff <(grep -v 'at a time' "$TMP/one.out") \
        <(grep -v 'at a time' "$TMP/four.out") >/dev/null; then
  ok "one worker and four give the same transcript"
else
  bad "the transcript depends on the number of workers"
fi

# The ledger is written by the printer, which is serial by construction. Under
# four workers every green battery must still leave its line, and the red one
# must still leave none.
: > "$TMP/led_par.txt"
EHS_TALLY_LEDGER="$TMP/led_par.txt" bash "$SUBJECT" --jobs 4 "$TMP/same" >"$TMP/out" 2>&1
n="$(grep -c . "$TMP/led_par.txt")"
[ "$n" -eq 1 ] && ok "under four workers the ledger has the one line it should" \
               || bad "the ledger has $n lines, expected 1"
grep -q 'two.selftest.sh 3 passed, 0 failed' "$TMP/led_par.txt" \
  && ok "the parallel ledger line carries the right path and tally" \
  || bad "the parallel ledger line is wrong or missing"

# --list took its directory from $2 when --list was $1. The argument loop that
# --jobs needed had to keep that working, and a --list that silently walked the
# default directory would report someone else's batteries.
bash "$SUBJECT" --list "$TMP/order" >"$TMP/out" 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "--list with a directory still exits 0" || bad "--list gave rc $rc"
grep -q 'order/aaa.selftest.sh' "$TMP/out" \
  && ok "--list walks the directory it was given" || bad "--list ignored its argument"
grep -q 'SLOW-FIRST' "$TMP/out" \
  && bad "--list ran the batteries instead of listing them" \
  || ok "--list lists without running"

echo "== the result that is never coming =="

# The printer waits at battery n for its exit code. With two states - here and
# not yet - a launcher that ends early leaves it waiting on a file nobody will
# write, and a CI job hangs for six hours and then says nothing about why. The
# mutant above is exactly that shape, so it doubles as this case's fixture: it
# has to come back with a VERDICT, and quickly.
start="$(date +%s)"
EHS_BATTERY_STALL=5 bash "$TMP/mutant.sh" "$TMP/greedy" >"$TMP/hang.out" 2>&1
rc=$?
elapsed=$(( $(date +%s) - start ))
[ "$rc" -eq 2 ] && ok "a battery whose result never arrives is rc 2, not a hang" \
                || bad "expected rc 2 from the truncated run, got $rc"
# The number stays OUT of the PASS line on purpose: this transcript is compared
# between a one-worker run and a four-worker run, and a line carrying a clock
# reading would differ between them for a reason that has nothing to do with the
# thing being compared.
[ "$elapsed" -lt 60 ] && ok "it answered in seconds instead of waiting forever" \
                      || bad "it took ${elapsed}s: that is the hang, not a verdict"
grep -q 'produced no exit code' "$TMP/hang.out" \
  && ok "the batteries with no result are named and diagnosed" \
  || bad "the run ended without saying which battery produced nothing"
grep -q 'batteries run: 1' "$TMP/hang.out" \
  && ok "the count reports the 1 result, not the 3 rows of the list" \
  || bad "the count claims batteries it did not measure: $(grep -o "batteries run: [0-9]*" "$TMP/hang.out")"

# THE BOUND IS IN SECONDS, NOT IN POLLS. It was counted in polls of 0.2 s, so
# the documented 900 s floor fired at 180 and cut a battery that was still
# running - printing its half-written transcript under the word UNMEASURABLE and
# a headline that said the suite could not measure. This case is the smallest
# tree that tells the two readings apart: a battery that takes two seconds under
# a four-second bound. Read as polls, four is 0.8 s and the battery is declared
# resultless; read as seconds, it finishes with room to spare.
mkdir -p "$TMP/slowbat"
printf '#!/usr/bin/env bash\nsleep 2\necho "--- 1 passed, 0 failed ---"\nexit 0\n' \
  > "$TMP/slowbat/slow.selftest.sh"
chmod +x "$TMP/slowbat/slow.selftest.sh"
EHS_BATTERY_STALL=4 bash "$SUBJECT" "$TMP/slowbat" >"$TMP/slow.out" 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "a two-second battery survives a four-second bound" \
                || bad "a 2 s battery under a 4 s bound gave rc $rc: the bound is being read as polls, not seconds"
grep -q 'produced no exit code' "$TMP/slow.out" \
  && bad "the printer gave up on a battery that was still running" \
  || ok "the printer waited for the result instead of counting polls"

# A stall bound that is not a positive integer must stop the run. Left to mean
# "no bound", it would restore the hang through the back door.
battery "$TMP/stall" one 0
EHS_BATTERY_STALL=nope bash "$SUBJECT" "$TMP/stall" >"$TMP/out" 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "a non-numeric stall bound is COULD NOT MEASURE" \
                || bad "EHS_BATTERY_STALL=nope gave rc $rc"

echo
echo "$pass PASS / $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
exit 0
