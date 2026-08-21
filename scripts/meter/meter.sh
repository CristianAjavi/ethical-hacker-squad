#!/usr/bin/env bash
# scripts/meter/meter.sh
#
# THE METER. Prints the real state of this project as numbers: corpus size and
# six-field completeness, traceability, the PCC coverage baseline, the gate
# suite result and repository hygiene.
#
# EXIT CODE DOCTRINE (identical to the gates, applied to the meter itself):
#   0 = every metric MEASURED and nothing failing
#   1 = every metric MEASURED and at least one MEASURED FAILURE
#   2 = at least one metric COULD NOT BE MEASURED
#
# The rule this script exists to enforce: a metric that cannot be taken is
# printed as NOT MEASURED. It is never printed as zero and it is never omitted.
# A zero here always means "I counted, and the count was zero".
#
# Usage:
#   scripts/meter/meter.sh                  # human table
#   scripts/meter/meter.sh --json           # machine-readable JSON
#   scripts/meter/meter.sh --no-gates       # skip the gate run (it is the slow part)
#   scripts/meter/meter.sh --gates-timeout 300
#   scripts/meter/meter.sh --pr-context     # also run the gates that need a PR
#   scripts/meter/meter.sh --root DIR --packs F --families F --baseline F
#                                           # point the meter at a fixture tree
#                                           # (this is how meter.selftest.sh works)
#
# Dependencies: bash, python3. jq is OPTIONAL and is only used to validate the
# JSON output. A missing dependency degrades the affected section to NOT
# MEASURED; it never aborts the run with a stack trace.
#
# Compatible with bash 3.2 (the /bin/bash that ships with macOS): no associative
# arrays, no mapfile, no ${var^^}.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PACKS="$SELF_DIR/packs.json"
FAMILIES="$SELF_DIR/standards-families.json"
CORE="$SELF_DIR/lib/measure.py"

FORMAT="table"
RUN_GATES=1
GATES_TIMEOUT=600
PR_CONTEXT=""
BASELINE=""
ROOT_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --json)          FORMAT="json"; shift ;;
    --table)         FORMAT="table"; shift ;;
    --no-gates)      RUN_GATES=0; shift ;;
    --pr-context)    PR_CONTEXT="--pr-context"; shift ;;
    --gates-timeout) GATES_TIMEOUT="${2:-600}"; shift 2 ;;
    --baseline)      BASELINE="${2:-}"; shift 2 ;;
    --root)          ROOT_OVERRIDE="${2:-}"; shift 2 ;;
    --packs)         PACKS="${2:-}"; shift 2 ;;
    --families)      FAMILIES="${2:-}"; shift 2 ;;
    -h|--help)       sed -n '2,36p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) printf 'meter: unknown argument: %s (try --help)\n' "$1" >&2; exit 2 ;;
  esac
done

# Repo root: --root wins (that is how the self-test points the meter at a
# fixture); otherwise git if it answers, otherwise two levels up from here.
if [ -n "$ROOT_OVERRIDE" ]; then
  ROOT="$(cd "$ROOT_OVERRIDE" 2>/dev/null && pwd)" || {
    printf 'meter: NOT MEASURED - --root %s does not exist\n' "$ROOT_OVERRIDE" >&2
    exit 2
  }
else
  ROOT="$(cd "$SELF_DIR/../.." && pwd)"
  if command -v git >/dev/null 2>&1; then
    _top="$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null)" && [ -n "$_top" ] && ROOT="$_top"
  fi
fi

# ---------------------------------------------------------------------------
# Temp workspace. mktemp failing is itself a "cannot measure", not a crash.
# ---------------------------------------------------------------------------
TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t ehsmeter)" || {
  printf 'meter: NOT MEASURED - could not create a temporary directory\n' >&2
  exit 2
}
cleanup() { [ -n "${TMPD:-}" ] && [ -d "$TMPD" ] && find "$TMPD" -mindepth 0 -delete 2>/dev/null; }
trap cleanup EXIT

GATES_RAW="$TMPD/gates.out"
GATES_RC_FILE="$TMPD/gates.rc"

# ---------------------------------------------------------------------------
# run_guarded <seconds> <outfile> <rcfile> <cmd...>
# Portable watchdog: macOS has no coreutils `timeout`. The child writes its own
# exit code to <rcfile>, so the status never depends on `wait` still knowing the
# job. A timeout produces no rc file, which the core reads as NOT MEASURED.
# ---------------------------------------------------------------------------
run_guarded() {
  _secs="$1"; _out="$2"; _rcf="$3"; shift 3
  # `set -m` gives the background job its OWN process group, so a timeout can
  # kill the gate runner AND the gate it had launched. Killing only the wrapper
  # PID leaves the real work running behind a report that says it was stopped.
  # Job-control notices go to stderr, so stdout stays clean for --json.
  set -m 2>/dev/null
  ( "$@" >"$_out" 2>&1; printf '%s\n' "$?" >"$_rcf" ) &
  _pid=$!
  set +m 2>/dev/null
  _waited=0
  while kill -0 "$_pid" 2>/dev/null; do
    if [ "$_waited" -ge "$_secs" ]; then
      kill -TERM "-$_pid" 2>/dev/null || kill -TERM "$_pid" 2>/dev/null
      sleep 2
      kill -KILL "-$_pid" 2>/dev/null || kill -KILL "$_pid" 2>/dev/null
      printf 'timed out after %ss\n' "$_secs" >>"$_out"
      return 124
    fi
    sleep 1
    _waited=$((_waited + 1))
  done
  wait "$_pid" 2>/dev/null
  return 0
}

# ---------------------------------------------------------------------------
# GATES. Run first: it is the slow part and it is the only measurement that
# executes other code.
# ---------------------------------------------------------------------------
GATES_SKIPPED=""
GATES_RC=""
GATES_RUNNER="$ROOT/scripts/gates/run-all.sh"

if [ "$RUN_GATES" -eq 0 ]; then
  GATES_SKIPPED="the gate suite was not run (--no-gates). Not running a check is not the same as passing it."
elif [ ! -f "$GATES_RUNNER" ]; then
  GATES_SKIPPED="gate runner not found at scripts/gates/run-all.sh"
elif ! command -v bash >/dev/null 2>&1; then
  GATES_SKIPPED="bash is not available to launch the gate runner"
else
  printf 'meter: running the gate suite (up to %ss)...\n' "$GATES_TIMEOUT" >&2
  if [ -n "$PR_CONTEXT" ]; then
    run_guarded "$GATES_TIMEOUT" "$GATES_RAW" "$GATES_RC_FILE" bash "$GATES_RUNNER" "$PR_CONTEXT"
  else
    run_guarded "$GATES_TIMEOUT" "$GATES_RAW" "$GATES_RC_FILE" bash "$GATES_RUNNER"
  fi
  _guard=$?
  if [ "$_guard" -eq 124 ]; then
    GATES_SKIPPED="the gate suite exceeded the ${GATES_TIMEOUT}s budget and was killed"
  elif [ ! -s "$GATES_RC_FILE" ]; then
    GATES_SKIPPED="the gate suite did not report an exit code"
  else
    GATES_RC="$(cat "$GATES_RC_FILE")"
  fi
fi

# ---------------------------------------------------------------------------
# CORE. python3 is what reads the corpus. Without it, corpus, traceability,
# PCC and hygiene are NOT MEASURED - and we still report the gates, because a
# partial measurement with declared holes beats no measurement at all.
# ---------------------------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  {
    printf '==============================================================================\n'
    printf '  ethical-hacker-squad - PROJECT METER\n'
    printf '==============================================================================\n\n'
    printf 'corpus       : NOT MEASURED - python3 is not on PATH\n'
    printf 'traceability : NOT MEASURED - python3 is not on PATH\n'
    printf 'pcc          : NOT MEASURED - python3 is not on PATH\n'
    printf 'hygiene      : NOT MEASURED - python3 is not on PATH\n'
    if [ -n "$GATES_SKIPPED" ]; then
      printf 'gates        : NOT MEASURED - %s\n' "$GATES_SKIPPED"
    else
      printf 'gates        : runner exit code %s\n' "$GATES_RC"
      grep -E 'discovered: [0-9]+ \| run:' "$GATES_RAW" 2>/dev/null | sed 's/^/               /'
    fi
    printf '\nVERDICT: exit 2 - COULD NOT MEASURE (install python3 to get the full meter)\n'
  } >&2
  if [ "$FORMAT" = "json" ]; then
    printf '{"schema":"ehs.meter/v1","verdict":{"exit_code":2,'
    printf '"meaning":"COULD NOT MEASURE","measured_failures":[],'
    printf '"not_measured":[{"metric":"all","reason":"python3 is not on PATH"}]}}\n'
  fi
  exit 2
fi

if [ ! -f "$CORE" ]; then
  printf 'meter: NOT MEASURED - measurement core missing at %s\n' "$CORE" >&2
  exit 2
fi

set -- --root "$ROOT" --packs "$PACKS" --families "$FAMILIES" --format "$FORMAT"
[ -n "$BASELINE" ] && set -- "$@" --baseline "$BASELINE"
if [ -n "$GATES_SKIPPED" ]; then
  set -- "$@" --gates-skipped "$GATES_SKIPPED"
else
  set -- "$@" --gates-raw "$GATES_RAW" --gates-rc "$GATES_RC"
fi

OUT="$TMPD/report.out"
python3 "$CORE" "$@" >"$OUT" 2>"$TMPD/core.err"
CODE=$?

if [ ! -s "$OUT" ]; then
  printf 'meter: NOT MEASURED - the measurement core produced no output (rc=%s)\n' "$CODE" >&2
  sed 's/^/  | /' "$TMPD/core.err" >&2
  exit 2
fi

# The core honours 0/1/2. Anything else means it died on the way, and a report
# produced by a crashed instrument is unknown state, not a measured failure.
case "$CODE" in
  0|1|2) : ;;
  *)
    printf 'meter: NOT MEASURED - the measurement core exited %s, outside the 0/1/2 contract\n' "$CODE" >&2
    sed 's/^/  | /' "$TMPD/core.err" >&2
    CODE=2
    ;;
esac

# jq is OPTIONAL: used only to prove the JSON we emit is well formed. Its
# absence is declared, never silently ignored.
if [ "$FORMAT" = "json" ]; then
  if command -v jq >/dev/null 2>&1; then
    if ! jq empty "$OUT" >/dev/null 2>&1; then
      printf 'meter: NOT MEASURED - the JSON produced is malformed (jq rejected it)\n' >&2
      exit 2
    fi
  else
    printf 'meter: note - jq is not installed, so the JSON was NOT validated before printing\n' >&2
  fi
fi

cat "$OUT"
[ -s "$TMPD/core.err" ] && sed 's/^/meter: /' "$TMPD/core.err" >&2
exit "$CODE"
