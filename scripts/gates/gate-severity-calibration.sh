#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-severity-calibration.sh — the ceilings, and whether they were applied.
#
# WHY IT EXISTS
#   Severity was the one dimension of vocabulary.md with no discipline behind
#   it. The measured error is inflation, not deflation: four LLMs judged against
#   SSVC's decision points over 384 real vulnerabilities "tended to over-predict
#   risk" (arXiv:2510.18508), and 68% of trained CVSS users re-rated the same
#   vulnerabilities differently on a second pass (arXiv:2308.15259). There is no
#   external oracle to import either - CVSS, EPSS, SSVC and the Exploitability
#   Index agree at kappa near zero over 600 vulnerabilities (arXiv:2508.13644).
#   So the discipline has to be ours, and it has to be checkable.
#
#   references/triage.md answers that with SEV-01..SEV-10: absolute caps, each
#   answerable, each a CEILING rather than a score. This gate owns the
#   catalogue. The per-finding arithmetic - invariants 12-19 - belongs to
#   gate-findings-artifact.sh, which already holds the schema and the fixtures.
#
# WHAT IT MEASURES
#   1. the caps region exists, its ids run contiguously from SEV-01, none twice
#   2. every ceiling is a severity term vocabulary.md declares
#   3. no ceiling is the top of the order - a cap that forbids nothing is not one
#   4. every tier is one of always / on trigger / derived, and one is `always`
#   5. the count in triage.md's title and the range cited in vocabulary.md both
#      match the rows actually declared
#   6. vocabulary.md still STATES the order, and states the one this gate was
#      built for
#   7. the cap arithmetic ran at least once over the fixtures
#   8. at least one fixture carries a `critical` or `high` finding
#
#   7 and 8 are not "if I checked nothing I cannot measure". Both reach zero in
#   a state someone can actually create - answer every cap NOT_APPLICABLE, or
#   drop every fixture to `medium` - and that state is the silent retirement of
#   the control. The gate says 2, and 2 is not a pass.
#
# WHAT IT DOES NOT MEASURE
#   Whether a cap is the RIGHT one for a given finding, and whether an answer is
#   honest. The first needs a reviewer; the second is what the evidence is for.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, a missing region, an order this gate cannot vouch for).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/severity_calibration.py"

gate_header "severity-calibration (the caps that rule a finding down)"
gate_scope "the caps region of triage.md, the ceilings it names, the tiers it declares, the order vocabulary.md states, and whether the cap arithmetic actually ran"
gate_out_of_scope "whether a cap is the right one for a finding, and whether an answer is honest"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was measured"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$CORE" ]; then
  gate_warn "the measurement core is missing: $CORE"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

out="$(python3 "$CORE" "$ROOT" 2>&1)"; rc=$?
while IFS= read -r line; do
  case "$line" in
    FINDING\ *)    gate_fail "${line#FINDING }" ;;
    UNMEASURED\ *) gate_warn "${line#UNMEASURED }" ;;
    *)             gate_info "$line" ;;
  esac
done <<< "$out"

case "$rc" in
  0) gate_ok "every ceiling is a term vocabulary.md declares, and the arithmetic ran" ;;
  1) gate_core_rc 1; rc="$GATE_RC" ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac
gate_verdict "$rc"
exit "$rc"
