#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-corpus-contract.sh — the corpus still matches what the repo says about it.
#
# WHY IT EXISTS
#   Measured on 2026-08-21, on main: two holes in the procedure numbering, a
#   knowledge file declared in no pack (four procedures in no count), README
#   claiming 2,830 lines and 122 procedures against a real 3,331 and 139, the
#   corpus map missing a file entirely, team.md declaring three ranges short,
#   two identifier families cited by the corpus and declared nowhere, and
#   twenty-odd identifiers written as bare prose where no check can see them.
#   None of it was caught by anything, because every one of those numbers is
#   restated by hand and nothing was reading them back.
#
# WHAT IT MEASURES  (scripts/gates/lib/corpus_contract.py does the arithmetic)
#   1. numbering       contiguous from 01, no duplicates, per identifier family
#   2. declared counts corpus lines, procedures and file count, wherever stated
#   3. declared ranges the upper bound is the highest identifier that exists
#   4. pack headers    the ~N line estimate and the loading-map table
#   5. identifiers     every backticked token matches a known family, and no
#                      identifier is written outside backticks
#   6. roster          team.md, agents/ and packs.json name the same things
#   7. routing         every `pack.md §N` in coverage.md exists
#   8. reachability    every pack file, and every section of a routed file, is
#                      named by some row of coverage.md - or its pack declares
#                      in writing why no route reaches it
#
# WHAT IT DOES NOT MEASURE
#   Whether a procedure is CORRECT, whether an identifier maps to what the
#   standard actually says, and whether the traceability matrix lists every
#   procedure that cites a family. The first two need a reader; the third is
#   open work (28 procedures are absent from the matrix today).
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure. A missing interpreter or an unreadable data file is a 2, never a 0.
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/corpus_contract.py"

gate_header "corpus-contract (numbering, counts, identifiers, roster, routing, reachability)"
gate_scope "the corpus against every number and every name the repository states about it"
gate_out_of_scope "whether a procedure is correct, and whether the traceability matrix is complete"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was measured"
  gate_verdict "$GATE_UNMEASURABLE"
  exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$CORE" ]; then
  gate_warn "the measurement core is missing: $CORE"
  gate_verdict "$GATE_UNMEASURABLE"
  exit "$GATE_UNMEASURABLE"
fi

out="$(python3 "$CORE" "$ROOT" 2>&1)"
rc=$?

while IFS= read -r line; do
  case "$line" in
    FINDING\ *)    gate_fail "${line#FINDING }" ;;
    UNMEASURED\ *) gate_warn "${line#UNMEASURED }" ;;
    *)             gate_info "$line" ;;
  esac
done <<< "$out"

case "$rc" in
  0) gate_ok "every declared number, name and route matches the corpus on disk" ;;
  1) : ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac

gate_verdict "$rc"
exit "$rc"
