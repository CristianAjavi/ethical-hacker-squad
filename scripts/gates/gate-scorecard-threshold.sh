#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-scorecard-threshold.sh — G9, the half of Scorecard that has teeth.
#
# WHY IT EXISTS
#   Scorecard has run here as measurement since the beginning, and the workflow
#   explains at length why the AGGREGATE must not be gated: it is a risk-weighted
#   average that EXCLUDES checks returning `?`, so it can fall for doing things
#   right. That reasoning is correct and it was also the whole story - nothing
#   gated on anything. This is the other half: the per-check subset that does
#   reflect real risk in a knowledge repository, at the thresholds
#   docs/gate-requirements.md has declared all along.
#
# WHAT IT MEASURES
#   The gated checks against their declared minimum; that BOTH documented tables
#   and the enforced data file still agree, check for check and number for
#   number; that every check sits in exactly one of the two, so a threshold
#   cannot be softened by deleting a row; that a check moved out of the gated
#   subset names a real file that checks the property instead, and that its live
#   score is printed anyway; and the aggregate by MOVEMENT rather than by level,
#   against a baseline a human edits - a workflow that could rewrite its own
#   baseline could ratchet itself down one run at a time.
#
#   A check Scorecard could not run comes back as -1. That is COULD NOT MEASURE,
#   never a pass.
#
# WHAT IT DOES NOT MEASURE
#   Every check outside the gated subset. They are published by the workflow and
#   deliberately not gated.
#
# Usage: scripts/gates/gate-scorecard-threshold.sh [--results FILE]
#        Environment: SCORECARD_RESULTS.
#   With no results file the gate exits 2. There is no offline default: a gate
#   that scores a fixture when the real results are missing reports the health of
#   the fixture.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, no results, an inconclusive check, an unusable data file).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"
ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/scorecard_threshold.py"
RESULTS="${SCORECARD_RESULTS:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --results) RESULTS="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    *)         shift ;;
  esac
done

gate_header "scorecard-threshold (the per-check subset that has teeth)"
gate_scope "the gated Scorecard checks against their declared minimum, BOTH documented tables against the enforced data file, that every check sits in exactly one of them, that what replaces a relocated check exists, and the aggregate by movement"
gate_out_of_scope "every check outside the gated subset: published, deliberately not gated"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was checked"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$CORE" ]; then
  gate_warn "the measurement core is missing: $CORE"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if [ -z "$RESULTS" ] || [ ! -f "$RESULTS" ]; then
  gate_warn "no Scorecard results to read (pass --results FILE or set SCORECARD_RESULTS). Scorecard needs the network and a repository token, so this gate runs in the scorecard workflow, not in the offline suite. A gate with no results has not passed; it has not run."
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

out="$(python3 "$CORE" "$ROOT" "$RESULTS" 2>&1)"; rc=$?
while IFS= read -r line; do
  case "$line" in
    FINDING\ *)      gate_fail "${line#FINDING }" ;;
    UNMEASURED\ *)   gate_warn "${line#UNMEASURED }" ;;
    NOT\ MEASURED*)  gate_out_of_scope "${line#NOT MEASURED: }" ;;
    *)               gate_info "$line" ;;
  esac
done <<< "$out"

case "$rc" in
  0) gate_ok "every gated check is at or above its declared minimum, and the aggregate did not fall" ;;
  1) gate_core_rc 1; rc="$GATE_RC" ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac
gate_verdict "$rc"
exit "$rc"
