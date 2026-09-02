#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-triage-rules.sh — the false-positive discipline, checked instead of hoped.
#
# WHY IT EXISTS
#   Every procedure carries a `What rules it out (false positive)` field, and
#   until now it was free prose: nothing named the rules, nothing required an
#   answer, and nothing could check that a specialist had worked through them.
#   The competitive analysis is blunt about it - the two most rigorous
#   neighbouring products enforce a finite, named triage list through a schema,
#   and ours was distributed hygiene nobody verified. Distributed beats
#   centralised only if the distributed part is checked.
#
# WHAT IT MEASURES
#   1. references/triage.md declares FP-01..FP-NN in its marked region,
#      contiguous, unique, each stating the condition and what a HOLDS requires
#   2. every FP-id cited anywhere under skills/ or agents/ exists
#   3. the four answers are declared, and the files that carry findings
#      (team.md, report.md) point at the rules and use that vocabulary
#   4. conformance per pack, RATCHETED: a pack marked `required` cites rules in
#      every procedure; a pack still being converted may never fall below the
#      floor it has already reached
#
# WHAT IT DOES NOT MEASURE
#   Whether the rules cited are the RIGHT ones for that procedure, and whether
#   an answer given during an engagement is honest. The first needs a reviewer;
#   the second is what the report's evidence is for.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, a data file that will not parse, an unreadable pack).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/triage_rules.py"

gate_header "triage-rules (the false-positive rules, and who cites them)"
gate_scope "the rule set, every citation of it, the answer vocabulary, and per-pack conformance"
gate_out_of_scope "whether the rules cited are the right ones for that procedure, and whether an answer is honest"

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
  0) gate_ok "the rule set is closed, every citation resolves, and no pack slipped backwards" ;;
  1) gate_core_rc 1; rc="$GATE_RC" ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac
gate_verdict "$rc"
exit "$rc"
