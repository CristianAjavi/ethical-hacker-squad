#!/usr/bin/env bash
# Negative cases for scripts/time-repeat.py.
#
# The instrument exists because single-shot timings were being quoted as
# measurements, so the cases that matter are the ones where it must REFUSE to
# hand back a number: one run, a command that fails, a directory that is not
# there. A timing tool that answers anyway is worse than no timing tool, because
# its answer looks exactly like a real one.
#
#  1. one run is refused - a single sample cannot show a spread
#  2. two runs are enough
#  3. a command that fails is NOT MEASURED, never a slow run
#  4. a command that fails during warm-up is refused the same way
#  5. the failing run's own error text is shown, or nobody can fix it
#  6. no command at all is refused
#  7. a directory that does not exist is refused
#  8. a negative warm-up is refused
#  9. the warm-up is reported, not hidden
# 10. the output always carries the range, never the median alone
# 11. a wide spread is named as noise rather than quoted as a median
# 12. --max-spread turns a noisy box into exit 1, not a confident number
# 13. --max-spread that is met still exits 0
# 14. the command runs exactly as many times as asked, warm-ups included
# 15. a negative --contenders is refused
# 16. the contenders are really launched, all N+1 of them, every run
# 17. a contender that dies is NOT MEASURED, not a slow run
# 18. a contended median never travels without saying it was contended
# 19. --against alternates run for run; it does not run two blocks
# 20. two ranges that overlap are named as the box, not as a change - and
#     when the box pulls them apart, the case says so instead of blaming
#     the tool
# 21. two ranges that do not overlap are named as a real difference
# 22. a failing second arm is NOT MEASURED too, and says which arm
# 23. --against with nothing to run is refused, not quietly ignored
# 24. a stderr that is neither answer says so instead of guessing
# 25. a tool that splits two runs of ONE command is still caught
# 26. and ranges that really do not touch are COULD NOT MEASURE, not a pass

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$SELF_DIR/time-repeat.py"
PY="${EHS_PYTHON:-python3}"
LAB="$(mktemp -d "${TMPDIR:-/tmp}/ehs-timerepeat.XXXXXX")"
trap 'rm -rf "$LAB"' EXIT

pass=0; fail=0; unmeasured=0

# A case can also fail to CREATE the condition it needs. That is not a pass and
# it is not a defect in what is under test, so it gets neither counter: exit 2,
# the same word this repository uses everywhere else for a measurement that did
# not happen. A harness with only two answers has to file one of these as the
# other, and both directions are wrong - a red charged to code that is fine, or
# a green signed by a case that never ran its rule.
note_unmeasured() {   # <name> <why>
  echo "COULD NOT MEASURE  $1: $2"
  unmeasured=$((unmeasured + 1))
}

judge() {
  local name="$1" want="$2" needle="$3" absent="$4" rc="$5" out="$6" why=""
  [ "$rc" = "$want" ] || why="rc $rc, expected $want"
  if [ -z "$why" ] && [ "$needle" != "-" ]; then
    printf '%s' "$out" | grep -qE -- "$needle" || why="never said '$needle'"
  fi
  if [ -z "$why" ] && [ "$absent" != "-" ]; then
    printf '%s' "$out" | grep -qE -- "$absent" && why="said '$absent', which it must not"
  fi
  if [ -z "$why" ]; then
    echo "PASS  $name"; pass=$((pass + 1))
  else
    echo "FAILED  $name: $why"; fail=$((fail + 1))
    printf '%s\n' "$out" | sed -e 's/^/        | /' | head -14
  fi
}

t() { "$PY" "$TOOL" "$@" 2>&1; }

# A command that always works, and one that never does. `true` and `false` are
# too fast to time on some clocks, so the working one touches a counter file:
# case 14 needs to count invocations, and a no-op cannot be counted.
COUNT="$LAB/count"
: > "$COUNT"
cat > "$LAB/ok.sh" <<'EOF'
#!/bin/sh
echo x >> "$COUNTER"
exit 0
EOF
cat > "$LAB/bad.sh" <<'EOF'
#!/bin/sh
echo "the fixture failed on purpose" >&2
exit 3
EOF
chmod +x "$LAB/ok.sh" "$LAB/bad.sh"
export COUNTER="$COUNT"

# 1. One run cannot show a spread, and a figure with no spread beside it is the
#    whole thing this script exists to stop shipping.
out="$(t --runs 1 -- "$LAB/ok.sh")"; rc=$?
judge "one-run-is-refused" 2 "cannot show a spread" - "$rc" "$out"

# 2. Two is the floor, not a suggestion.
out="$(t --runs 2 -- "$LAB/ok.sh")"; rc=$?
judge "two-runs-are-enough" 0 "median" - "$rc" "$out"

# 3. A command that fails is NOT MEASURED. It is not a slow run, and averaging it
#    in would make a broken build look like a fast one.
out="$(t --runs 3 -- "$LAB/bad.sh")"; rc=$?
judge "a-failing-command-is-unmeasurable" 2 "COULD NOT MEASURE" "median" "$rc" "$out"

# 4. Same during warm-up: the refusal cannot depend on which phase broke.
out="$(t --runs 3 --warmup 1 -- "$LAB/bad.sh")"; rc=$?
judge "a-failing-warmup-is-unmeasurable" 2 "warm-up 1 exited 3" - "$rc" "$out"

# 5. And it shows what the command said, or the refusal is a dead end.
judge "the-failure-names-what-the-command-said" 2 "failed on purpose" - "$rc" "$out"

# 6.
out="$(t --runs 3)"; rc=$?
judge "no-command-is-refused" 2 "no command given" - "$rc" "$out"

# 7.
out="$(t --runs 2 --cwd "$LAB/nowhere" -- "$LAB/ok.sh")"; rc=$?
judge "a-missing-directory-is-refused" 2 "no directory" - "$rc" "$out"

# 8.
out="$(t --runs 2 --warmup -1 -- "$LAB/ok.sh")"; rc=$?
judge "a-negative-warmup-is-refused" 2 "cannot be negative" - "$rc" "$out"

# 9. A dropped run that nobody is told about is a number with a piece missing.
out="$(t --runs 2 --warmup 1 -- "$LAB/ok.sh")"; rc=$?
judge "the-warmup-is-reported-not-hidden" 0 "warm-up 1: .*\(dropped" - "$rc" "$out"

# 10. The median never travels alone.
out="$(t --runs 3 -- "$LAB/ok.sh")"; rc=$?
judge "the-median-never-travels-alone" 0 "median .*, range .* over 3 run" - "$rc" "$out"

# 11 and 12. A box too noisy to measure on has to SAY so. The fixture sleeps a
#     different amount each run, which is the only honest way to make a spread on
#     demand: faking it by editing the samples would prove nothing about the
#     script's own arithmetic.
cat > "$LAB/jitter.sh" <<'EOF'
#!/bin/sh
n=$(cat "$JITTER" 2>/dev/null || echo 0)
n=$((n + 1)); echo "$n" > "$JITTER"
[ "$n" -eq 2 ] && sleep 1
exit 0
EOF
chmod +x "$LAB/jitter.sh"
export JITTER="$LAB/jitter"

: > "$JITTER"
out="$(t --runs 3 -- "$LAB/jitter.sh")"; rc=$?
judge "a-wide-spread-is-named-as-noise" 0 "Quote the range, not the median" - "$rc" "$out"

: > "$JITTER"
out="$(t --runs 3 --max-spread 20 -- "$LAB/jitter.sh")"; rc=$?
judge "a-noisy-box-is-exit-1-not-a-number" 1 "OUTSIDE THE LIMIT" - "$rc" "$out"

# 13. And a limit that is met is still a pass, or the flag would only ever fail.
out="$(t --runs 2 --max-spread 100000 -- "$LAB/ok.sh")"; rc=$?
judge "a-met-limit-still-passes" 0 "median" "OUTSIDE THE LIMIT" "$rc" "$out"

# 14. It runs the command exactly as often as it says it does - warm-ups included.
#     A tool that quietly ran four times and reported five would be inventing a
#     sample, which is the same defect as inventing a number.
: > "$COUNT"
t --runs 3 --warmup 2 -- "$LAB/ok.sh" >/dev/null 2>&1
n="$(wc -l < "$COUNT" | tr -d ' ')"
judge "it-runs-the-command-as-often-as-it-says" 0 - - \
  "$([ "$n" = "5" ] && echo 0 || echo 9)" "ran $n time(s), expected 5"

# 15. Negative contention is not a thing, and a tool that accepted it would be
#     silently measuring the quiet case while the caller believed otherwise.
out="$(t --runs 2 --contenders -1 -- "$LAB/ok.sh")"; rc=$?
judge "a-negative-contenders-is-refused" 2 "contenders cannot be negative" - "$rc" "$out"

# 16. The contenders have to actually exist. `--contenders 2` that ran nothing
#     alongside would hand back the QUIET number under a contended label, which
#     is the worst possible failure for this flag: wrong, and labelled right.
: > "$COUNT"
t --runs 2 --contenders 2 -- "$LAB/ok.sh" >/dev/null 2>&1
n="$(wc -l < "$COUNT" | tr -d " ")"
judge "the-contenders-are-really-launched" 0 - - \
  "$([ "$n" = "6" ] && echo 0 || echo 9)" "ran $n time(s), expected 6 (2 runs x 3 copies)"

# 17. A contender that died is not contention. It is a box that could not run
#     the copies, and the run beside it measured a load that was not there.
#
#     The fixture tells the measured run from a contender by its stderr: the
#     tool captures the measured one through a pipe and sends the contenders to
#     /dev/null, so `[ -p /dev/fd/2 ]` is true for exactly one of them. That is
#     deliberate rather than a race on a counter file - and if someone ever
#     stops capturing that stderr, this case goes red, which is right, because
#     case 5 needs that capture to show the failing command's own words.
#     THREE states, not two. `[ -p /dev/fd/2 ]` answers "am I the measured
#     run?", and everything else used to be filed as "I am a contender" -
#     including "I could not tell". This case went red once in four runs of the
#     whole suite with the measured run reporting itself as a contender, 600
#     controlled repetitions did not reproduce it, and the cause is NOT
#     established. What is fixed here is the part that made it unreadable: a
#     stderr that is neither the captured pipe nor a contender's sink now says
#     so and exits 9, instead of quietly taking a branch it was never meant to.
cat > "$LAB/contender-bad.sh" <<"EOF"
#!/bin/sh
[ -p /dev/fd/2 ] && exit 0
if [ -c /dev/fd/2 ] || [ -f /dev/fd/2 ]; then
  echo "the contender failed on purpose" >&2
  exit 7
fi
echo "I cannot tell the captured pipe from a contender's sink: $(ls -l /dev/fd/2 2>&1)" >&2
exit 9
EOF
chmod +x "$LAB/contender-bad.sh"
out="$(t --runs 2 --contenders 1 -- "$LAB/contender-bad.sh")"; rc=$?
judge "a-dead-contender-is-unmeasurable" 2 "a contender exited 7" - "$rc" "$out"

# 24. The third state is reachable, and this proves it rather than asserting it
#     in a comment: with fd 2 CLOSED the script can say nothing at all, so rc 9
#     is the whole message - and no other path in that script produces a 9.
"$LAB/contender-bad.sh" 2>&-; rc=$?
judge "an-undecidable-stderr-says-so-instead-of-guessing" 9 - - "$rc" ""

# 18. 35 s and 140 s of the same battery do not contradict each other: they are
#     two conditions. A median that travels without its load misleads exactly
#     the way a median without its range does, so the condition is printed
#     against the number itself, not only in the header.
out="$(t --runs 2 --contenders 1 -- "$LAB/ok.sh")"; rc=$?
judge "a-contended-median-says-it-was-contended" 0 "2-way contention: median" - "$rc" "$out"

# 19. Alternation is the entire reason --against exists. The same battery gave
#     28.3 s, 40.4 s and 43.6 s in three blocks of five on one afternoon, each
#     block internally tight and no two blocks overlapping: a block against a
#     block compares two moments of the machine, not two commands. So the order
#     is checked directly - a tool that ran five of A and then five of B would
#     read identically in its output and be worthless.
cat > "$LAB/mark-a.sh" <<"EOF"
#!/bin/sh
printf A >> "$MARKS"
EOF
cat > "$LAB/mark-b.sh" <<"EOF"
#!/bin/sh
printf B >> "$MARKS"
EOF
cat > "$LAB/slow.sh" <<"EOF"
#!/bin/sh
sleep 0.4
EOF
chmod +x "$LAB/mark-a.sh" "$LAB/mark-b.sh" "$LAB/slow.sh"
export MARKS="$LAB/marks"
: > "$MARKS"
t --runs 3 --against "$LAB/mark-b.sh" -- "$LAB/mark-a.sh" >/dev/null 2>&1
seen="$(cat "$MARKS")"
judge "against-alternates-run-for-run" 0 - - \
  "$([ "$seen" = "ABABAB" ] && echo 0 || echo 9)" "order was '$seen', expected ABABAB"

# 20. The same command against itself cannot be a change. If the tool calls that
#     a difference, every A/B it ever signs is worthless in the same direction.
#
#     Two things changed here after this case was caught going red on work that
#     had not been touched. The arms are `slow.sh` and no longer `ok.sh`:
#     `ok.sh` finishes far under the 0.1 s the report prints, so its two ranges
#     are two pairs of zeros and a neighbouring process can pull them apart with
#     nothing in the transcript to show it. Counted before the change: 0 reds in
#     12 runs on an idle box, 1 in 8 with fourteen processes spinning beside it.
#
#     And the verdict line is no longer taken as evidence about itself. The
#     classifier reads the two ranges the tool PRINTED and decides on its own
#     whether they touch. Ranges that touch under a verdict of "difference" is a
#     defect in the tool and is still a FAILURE. Ranges that genuinely do not
#     touch, for two runs of one command, is the box moving under the case:
#     COULD NOT MEASURE, which is never a pass and is never charged to the tool.
#     Rounding cannot invent that gap - it is monotone, so ranges that are apart
#     at 0.1 s were apart before they were printed.
cat > "$LAB/overlap.awk" <<"AWK"
/range [0-9.]+-[0-9.]+ s over/ {
  if (match($0, /range [0-9.]+-[0-9.]+ s/)) {
    split(substr($0, RSTART + 6, RLENGTH - 8), r, "-")
    arms++
    lo[arms] = r[1] + 0
    hi[arms] = r[2] + 0
  }
}
/ranges do not overlap/ { said = "apart" }
/ranges OVERLAP/        { said = "together" }
END {
  if (arms != 2) {
    print "fail|the tool printed " arms " range(s) where two arms were asked for"
    exit
  }
  if (said == "") { print "fail|the tool printed no overlap verdict at all"; exit }
  span = sprintf("%.1f-%.1f s and %.1f-%.1f s", lo[1], hi[1], lo[2], hi[2])
  touch = !(hi[1] < lo[2] || hi[2] < lo[1])
  if (touch && said == "together")
    print "pass|"
  else if (touch && said == "apart")
    print "fail|the printed ranges " span " touch, and the tool called them a difference"
  else if (!touch && said == "together")
    print "fail|the printed ranges " span " do not touch, and the tool called them one box"
  else
    print "unmeasured|two runs of one command landed on " span ", which do not touch: the box moved under the case and the rule was never exercised"
}
AWK

verdict_overlap() {   # <name> <rc> <transcript>
  local name="$1" rc="$2" out="$3" v why
  if [ "$rc" != 0 ]; then
    judge "$name" 0 - - "$rc" "$out"
    return
  fi
  v="$(printf '%s\n' "$out" | awk -f "$LAB/overlap.awk")"
  why="${v#*|}"
  case "${v%%|*}" in
    pass) echo "PASS  $name"; pass=$((pass + 1)) ;;
    unmeasured) note_unmeasured "$name" "$why" ;;
    *) echo "FAILED  $name: $why"; fail=$((fail + 1))
       printf '%s\n' "$out" | sed -e 's/^/        | /' | head -14 ;;
  esac
}

out="$(t --runs 3 --against "$LAB/slow.sh" -- "$LAB/slow.sh")"; rc=$?
verdict_overlap "overlapping-ranges-are-the-box" "$rc" "$out"

# 21. And the opposite has to work, or the verdict would be a rubber stamp that
#     only ever says no.
out="$(t --runs 3 --against "$LAB/slow.sh" -- "$LAB/ok.sh")"; rc=$?
judge "disjoint-ranges-are-a-real-difference" 0 "ranges do not overlap" - "$rc" "$out"

# 22. The second arm is not a lesser arm: a failure there is NOT MEASURED just
#     the same, and the message has to say which side died or nobody can fix it.
out="$(t --runs 2 --against "$LAB/bad.sh" -- "$LAB/ok.sh")"; rc=$?
judge "a-failing-second-arm-is-unmeasurable" 2 "arm B" - "$rc" "$out"

# 23. `--against ""` is the shape a shell variable takes when it is empty. Taken
#     quietly it would time ONE arm and print a single median under a command
#     line that says two - the comparison would be missing and the output would
#     not say so.
out="$(t --runs 2 --against "" -- "$LAB/ok.sh")"; rc=$?
judge "against-with-nothing-to-run-is-refused" 2 "nothing to run" - "$rc" "$out"

# 25. NEGATIVE CONTROL for case 20's own classifier, first direction. A third
#     answer is a way to make any red disappear, so the day it arrives is the
#     day someone has to prove it did not. Ranges that TOUCH under a verdict of
#     "difference" is the mutant `todo-par-de-rangos-es-una-diferencia`, and it
#     has to stay caught: nothing the box does can produce that transcript.
seen="$(printf '%s\n' \
  "arm A: median 0.4 s, range 0.4-0.6 s over 3 run(s)" \
  "arm B: median 0.5 s, range 0.5-0.7 s over 3 run(s)" \
  "The two ranges do not overlap. That is a difference between the commands." \
  | awk -f "$LAB/overlap.awk")"
judge "a-tool-that-splits-one-command-is-still-caught" 0 - - \
  "$([ "${seen%%|*}" = fail ] && echo 0 || echo 9)" "the classifier answered '$seen'"

# 26. And the other direction, or the third answer would be indistinguishable
#     from a pass. Ranges that do NOT touch are the box, and the classifier has
#     to say so in its own words - not sign it green, not charge it to the tool.
seen="$(printf '%s\n' \
  "arm A: median 0.4 s, range 0.4-0.4 s over 3 run(s)" \
  "arm B: median 0.9 s, range 0.8-1.0 s over 3 run(s)" \
  "The two ranges do not overlap. That is a difference between the commands." \
  | awk -f "$LAB/overlap.awk")"
judge "ranges-that-really-do-not-touch-are-not-measured" 0 - - \
  "$([ "${seen%%|*}" = unmeasured ] && echo 0 || echo 9)" "the classifier answered '$seen'"

echo
echo "$pass PASS / $fail FAILED / $unmeasured COULD NOT MEASURE"
[ "$fail" -eq 0 ] || exit 1
[ "$unmeasured" -eq 0 ] || exit 2
exit 0
