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

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$SELF_DIR/time-repeat.py"
PY="${EHS_PYTHON:-python3}"
LAB="$(mktemp -d "${TMPDIR:-/tmp}/ehs-timerepeat.XXXXXX")"
trap 'rm -rf "$LAB"' EXIT

pass=0; fail=0

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

echo
echo "$pass PASS / $fail FAILED"
[ "$fail" -eq 0 ]
