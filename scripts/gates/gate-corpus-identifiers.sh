#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-corpus-identifiers.sh — the ids the corpus declares, and the ids it cites.
#
# WHY IT EXISTS
#   The coverage report of 2026-08-16 designed this check in section 1.3, named
#   its three assertions A1/A2/A3, and it was never built. Until now nothing
#   stopped two procedures sharing an id, nothing noticed a hole in a pack's
#   numbering, and nothing checked that a cited standards identifier exists.
#
#   The third is the one with teeth, and the corpus's own citation policy says
#   why: "Inventing a plausible-looking ID is a fabrication, and a fabricated
#   identifier is worse than no identifier because it survives review by looking
#   correct." `A11:2025` and `CICD-SEC-14` read as real to every reader who does
#   not hold the standard open beside them.
#
# WHAT IT MEASURES
#   A1  no procedure id is declared twice anywhere in the corpus
#   A2  no hole in any pack's numbering - a jump is the shape a procedure lost
#       in a merge leaves behind
#   A3  every cited identifier of a bounded standard falls inside the scheme
#       references/traceability.md declares, and the gate's bounds are checked
#       against that document on every run rather than trusted
#
# WHAT IT DOES NOT MEASURE
#   Whether a valid identifier is the RIGHT one for the procedure that cites it:
#   `CWE-79` where `CWE-89` belongs is a real defect and this gate cannot see it.
#   Nor does it check families whose ids are not enumerable from a declared
#   bound - CWE, CAPEC, ATT&CK, ATLAS and the MASTG test numbers are cited by
#   number, and a format-only check on them would pass anything shaped right,
#   which is a green that means nothing. Those need a reviewer or a lookup.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, missing core, unreadable corpus, or traceability.md no
# longer declaring the scheme this gate enforces).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/corpus_identifiers.py"

gate_header "corpus-identifiers (the ids it declares, and the ids it cites)"
gate_scope "duplicate procedure ids, holes in a pack's numbering, and every cited identifier of a standard whose scheme traceability.md bounds"
gate_out_of_scope "whether a valid identifier is the right one for the procedure citing it, and families with no enumerable bound (CWE, CAPEC, ATT&CK, ATLAS, MASTG numbers)"

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
    *)             [ -n "$line" ] && gate_info "$line" ;;
  esac
done <<< "$out"

case "$rc" in
  0) gate_ok "no id is declared twice, no pack skips a number, and every bounded identifier the corpus cites exists" ;;
  1) : ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac
gate_verdict "$rc"
exit "$rc"
