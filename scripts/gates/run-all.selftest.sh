#!/usr/bin/env bash
# scripts/gates/run-all.selftest.sh
#
# Negative proof for the cost column the runner prints.
#
# Adding a field to a `|`-delimited record is one of the classic ways to break a
# report while every exit code stays right: the message shifts one column, the
# summary reads a duration where it expected prose, and the run still returns 0.
# So the cases here are not about the clock being accurate. They are about the
# three things that would be silently wrong:
#
#   - a verdict changed by the instrument that only meant to time it;
#   - a cost printed for a gate whose cost was never measured;
#   - a `0.0s` where the clock's resolution cannot support a zero.
#
# The gates are written by this file, not read from the repository: a battery
# that takes its input from the same place as the thing it measures proves
# nothing. `run-all.sh` finds its gates beside itself, so each case is a
# directory holding the real runner, the real library, and toy gates whose exit
# codes and durations this file chose.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib/common.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-runall.XXXXXX")" || {
  printf 'COULD NOT MEASURE: cannot create a working directory.\n' >&2; exit 2; }
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0; unmeasured=0

# A case that cannot run under the clock this shell has is NOT a pass. It is
# named, counted apart, and the reason is printed - the same treatment a gate
# gets when it cannot measure.
case_skip() {
  printf 'NOT MEASURED  %-41s %s\n' "$1" "$2"; unmeasured=$((unmeasured + 1))
}

# A case is a gates directory: the real runner, the real library, and the toy
# gates named on the command line as `name:exit_code:sleep_seconds`.
build() {
  local d="$1"; shift
  mkdir -p "$d/lib" || return 1
  cp "$HERE/run-all.sh" "$d/run-all.sh" || return 1
  cp "$HERE/lib/common.sh" "$d/lib/common.sh" || return 1
  local spec name code secs
  for spec in "$@"; do
    name="${spec%%:*}"; spec="${spec#*:}"
    code="${spec%%:*}"; secs="${spec#*:}"
    {
      printf '#!/usr/bin/env bash\n'
      [ "$secs" != "0" ] && printf 'sleep %s\n' "$secs"
      printf 'printf "toy gate %%s\\n" "%s"\n' "$name"
      printf 'exit %s\n' "$code"
    } > "$d/$name"
    chmod +x "$d/$name" || return 1
  done
}

# want_rc: the exit code the runner must still return. needle: text that must be
# present. absent: text that must NOT be. Either may be empty.
case_run() {
  local name="$1" want_rc="$2" needle="$3" absent="$4"; shift 4
  local work="$TMP/$name"
  if ! build "$work" "$@"; then
    printf 'HARNESS  %-46s could not build the case\n' "$name"; fail=$((fail+1)); return
  fi
  local out rc=0
  out="$(cd "$work" && bash ./run-all.sh 2>&1)" || rc=$?
  rm -rf "$work"

  local why=""
  [ "$rc" -eq "$want_rc" ] || why="exit $rc, expected $want_rc"
  if [ -z "$why" ] && [ -n "$needle" ] && ! printf '%s' "$out" | grep -qF -- "$needle"; then
    why="never said: $needle"
  fi
  if [ -z "$why" ] && [ -n "$absent" ] && printf '%s' "$out" | grep -qF -- "$absent"; then
    why="said what it must not: $absent"
  fi
  if [ -n "$why" ]; then
    printf 'FAILED   %-46s %s\n' "$name" "$why"; fail=$((fail+1))
  else
    printf 'ok       %-46s\n' "$name"; pass=$((pass+1))
  fi
}

printf '=== %s ===\n' "$(basename "$0")"

# THE VERDICT SURVIVES THE INSTRUMENT. One case per exit code the doctrine
# names, each asserting that the gate's own message is still on its own line and
# has not been shifted into the cost column by the extra field.
case_run 'a-green-gate-still-returns-0' 0 \
  'gate-green.sh — measured, no findings' '' \
  'gate-green.sh:0:0'

case_run 'a-failing-gate-still-returns-1' 1 \
  'gate-red.sh — measured, FAILS' '' \
  'gate-red.sh:1:0'

case_run 'an-unmeasurable-gate-still-returns-2' 2 \
  'gate-blind.sh — COULD NOT MEASURE' '' \
  'gate-blind.sh:2:0'

# A measured failure outranks a gate that could not measure: that is the
# doctrine, and a report that now sorts by cost is a way to lose it.
case_run 'a-failure-outranks-an-unmeasurable' 1 \
  'measured, FAILS' '' \
  'gate-red.sh:1:0' 'gate-blind.sh:2:0'

# THE COST IS REPORTED, AND ONLY WHERE IT WAS MEASURED.
case_run 'the-run-reports-what-it-cost' 0 \
  'cost: ' '' \
  'gate-green.sh:0:0'

# The honesty rule. Under the fallback clock - bash 3.2, one-second resolution,
# which is what macOS runs - a gate that finished inside the second has no
# measured duration. It must say so and must not print a zero it cannot support.
if [ -z "${EPOCHREALTIME:-}" ]; then
  case_run 'a-sub-second-gate-says-under-a-second' 0 \
    '(<1s)' '(0.0s)' \
    'gate-green.sh:0:0'
else
  case_skip 'a-sub-second-gate-says-under-a-second' \
    "this bash has EPOCHREALTIME, so the one-second clock is not the one running"
fi

# WHERE THE TIME WENT names a gate only when there is one to name.
case_run 'a-dominant-gate-is-named' 0 \
  'a tenth or more of it is in:' '' \
  'gate-slow.sh:0:3' 'gate-green.sh:0:0'

# Eleven gates, none of them a tenth of the run. Eleven is forced: with ten or
# fewer somebody is always at or over a tenth. Two instant gates were the first
# draft, and the negative control found that case green with the threshold set to
# name every gate - it was measuring silence, because under the one-second clock
# two instant gates total zero and the loop never reaches the threshold at all.
#
# It needs the millisecond clock for a second reason. `SECONDS` is off by up to a
# second per reading, so one unlucky boundary makes one of eleven one-second gates
# measure two - a fifth of the run - and the case goes red for the clock rather
# than for the rule. Where that clock is not available the case is not run and
# says so.
if [ -n "${EPOCHREALTIME:-}" ]; then
  case_run 'a-suite-of-equals-invents-no-culprit' 0 \
    'none of them a tenth of the run on its own' 'a tenth or more' \
    'gate-a.sh:0:0.3' 'gate-b.sh:0:0.3' 'gate-c.sh:0:0.3' 'gate-d.sh:0:0.3' \
    'gate-e.sh:0:0.3' 'gate-f.sh:0:0.3' 'gate-g.sh:0:0.3' 'gate-h.sh:0:0.3' \
    'gate-i.sh:0:0.3' 'gate-j.sh:0:0.3' 'gate-k.sh:0:0.3'
else
  case_skip 'a-suite-of-equals-invents-no-culprit' \
    "a one-second clock cannot tell eleven equal gates apart from one that dominates"
fi

printf '\n  %d PASS / %d FAIL / %d NOT MEASURED (clock: %s)\n' \
  "$pass" "$fail" "$unmeasured" \
  "$([ -n "${EPOCHREALTIME:-}" ] && printf 'millisecond' || printf 'one-second')"
if [ "$fail" -gt 0 ]; then
  gate_fail "the runner's cost column changes a verdict, or reports a cost it did not measure"
  gate_verdict 1; exit "$GATE_FAIL"
fi
gate_ok "every verdict survives the timing, and no cost is claimed that the clock could not measure"
gate_verdict 0; exit "$GATE_OK"
