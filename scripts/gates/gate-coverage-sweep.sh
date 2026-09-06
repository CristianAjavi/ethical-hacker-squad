#!/usr/bin/env bash
# scripts/gates/gate-coverage-sweep.sh
#
# Does every rule in a gate library have a case that would notice if the rule
# stopped firing?
#
# The batteries in this repository are green. That is a fact about the batteries
# and not yet a fact about the rules: a case can be green because the rule works,
# or because the case never exercised it and would pass either way. Nothing here
# could tell those apart. This does, mechanically: for each statement that
# RECORDS a problem, replace it with `pass` and run that library's battery. A
# battery still green over a silenced rule is a battery that was never testing
# it.
#
# It is deferred out of run-all.sh's default set for one reason and it is not
# scope: it costs MINUTES, because it runs a whole battery per report site.
# run-all.sh finishes in under a minute and is the thing people run before a
# push; putting an hour inside it is how a suite gets switched off. It runs
# weekly in .github/workflows/coverage-sweep.yml and on demand with
# EHS_SWEEP=1.
#
# Exit codes follow the doctrine in lib/common.sh: 0 measured and accounted for,
# 1 measured and a rule has no case, 2 COULD NOT MEASURE, which is never a pass.
#
# Usage:
#   EHS_SWEEP=1 scripts/gates/run-all.sh --only 'gate-coverage-sweep.sh'
#   scripts/gates/gate-coverage-sweep.sh                       # every library
#   scripts/gates/gate-coverage-sweep.sh --only triage_rules.py  # just this one
# Arguments are forwarded to lib/coverage_sweep.py. Sweeping the one library you
# just edited takes a minute; sweeping all of them takes three quarters of an
# hour, and a control nobody can afford to run is a control nobody runs.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

GATE="coverage-sweep"
ROOT="$(gate_root)"
JOBS="${EHS_SWEEP_JOBS:-4}"
ACCEPTED="$ROOT/scripts/gates/data/coverage-sweep-accepted.json"

gate_header "$GATE"
gate_scope "every statement in scripts/gates/lib/*.py that records a problem: silence it, and see whether that library's battery notices"
gate_out_of_scope "the SHELL gates, which have no library to mutate; whether a battery that DOES notice notices for the right reason; and whether the rule itself is correct - a covered rule can still be a wrong rule"

case "$JOBS" in
  ''|*[!0-9]*) gate_warn "EHS_SWEEP_JOBS is '$JOBS', which is not a job count"; exit "$GATE_UNMEASURABLE" ;;
esac
[ "$JOBS" -ge 1 ] || { gate_warn "EHS_SWEEP_JOBS is $JOBS; a sweep with no workers measures nothing"; exit "$GATE_UNMEASURABLE"; }

PY="${EHS_PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || { gate_warn "no $PY on PATH: the sweep cannot parse a library, so nothing was measured"; exit "$GATE_UNMEASURABLE"; }

ENGINE="$SELF_DIR/lib/coverage_sweep.py"
[ -r "$ENGINE" ] || { gate_warn "$ENGINE is missing or unreadable"; exit "$GATE_UNMEASURABLE"; }

# The engine parses with `ast` and needs a version that carries end_lineno, or a
# multi-line append silently collapses to its first line and every mutant dies
# by SyntaxError - which scores as coverage nobody has.
"$PY" - <<'EOF' >/dev/null 2>&1 || { gate_warn "the interpreter at ${EHS_PYTHON:-python3} is older than 3.8, so ast spans are unavailable and every mutant would be a syntax error"; exit 2; }
import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)
EOF

if [ -r "$ACCEPTED" ]; then
  gate_info "survivors already accounted for: $(basename "$ACCEPTED")"
else
  gate_info "no acceptance file, so every surviving report site is a failure"
fi
gate_info "this takes minutes: one full battery run per report site, $JOBS at a time"

# -u: a fifteen-minute step that prints nothing until it ends is indistinguishable
# from a hung one, in CI and in a terminal alike.
"$PY" -u "$ENGINE" --root "$ROOT" --jobs "$JOBS" --accepted "$ACCEPTED" ${EHS_SWEEP_JSON:+--json "$EHS_SWEEP_JSON"} "$@"
rc=$?

case "$rc" in
  0) gate_ok   "every rule that can be silenced has a case that notices, or an acceptance that says why not" ;;
  1) gate_fail "a rule can be silenced and no battery notices" ;;
  *) gate_warn "the sweep could not measure; see above" ; rc=$GATE_UNMEASURABLE ;;
esac
exit "$rc"
