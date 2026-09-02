#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-engagement-memory.sh — what this run is against the last one.
#
# WHY IT EXISTS
#   An audit that cannot remember the previous audit reports the same list every
#   time, and the reader cannot tell a defect that came back from one that never
#   left. The closest thing in the field is Mantis, whose Tier 1 key is sound - a
#   digest over fingerprint, CWE and target symbol, invariant to line shifts and
#   to paraphrased titles. What it does not survive is its own fallback: the
#   embedding tier catches every exception and returns a mock vector, the
#   dimension check then skips every candidate, and a deployment with no model
#   silently reports each run as entirely new. Nothing in the output says so.
#
#   So the contract here separates the measurement from its absence. `new` is a
#   claim that a comparison happened; `unmeasured` is the word for when it did
#   not, and it is a declared term rather than a missing field. And every
#   baseline finding is accounted for - continued by a finding or answered in
#   `carried_over` - because a finding that simply stops appearing reads, to
#   anyone diffing two artifacts, exactly like a finding that was fixed.
#
#   This gate owns the memory CONTRACT. The per-artifact arithmetic - invariants
#   20-29 - belongs to gate-findings-artifact.sh, which holds the schema and the
#   fixtures.
#
# WHAT IT MEASURES
#   1. vocabulary.md still declares dimensions 5 and 6, and still declares every
#      term the invariants branch on
#   2. `fingerprint.inputs` admits no line number - the one input this algorithm
#      exists to exclude, because a key that moves when a comment is inserted
#      above the defect reports every rebase as a fresh discovery
#   3. `ehs.fp/v1` is still specified well enough to reproduce, and every
#      fingerprint in the corpus does reproduce
#   4. findings-artifact.md numbers its invariants contiguously
#   5. every declared term is exercised by some fixture
#   6. the corpus exercises a baseline, a continuation, a collision and a
#      carried-over entry
#
#   6 is not "if I checked nothing I cannot measure". Each of those counters
#   reaches zero through a state someone can actually create - delete the v2
#   fixtures, drop the colliding pair, empty the list - and each such state
#   retires a control while every gate stays green. The gate says 2, and 2 is
#   not a pass.
#
# WHAT IT DOES NOT MEASURE
#   Whether a match is CORRECT. A fingerprint is a candidate key and says so:
#   measured over 117 real artifacts and 587 findings, no key over these fields
#   is unique. Deciding that two findings are the same defect is a judgement,
#   and this gate checks the arithmetic around it, not the judgement.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, a missing region, a corpus that stopped exercising this).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/engagement_memory.py"

gate_header "engagement-memory (what this run is against the last one)"
gate_scope "dimensions 5 and 6 of vocabulary.md, the fingerprint block of the schema, the invariant numbering of findings-artifact.md, and whether the corpus still exercises a comparison"
gate_out_of_scope "whether a match is correct - a fingerprint is a candidate key, and deciding two findings are the same defect is a judgement"

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
  0) gate_ok "the memory contract holds, every declared term is exercised, and every fingerprint reproduces" ;;
  1) gate_core_rc 1; rc="$GATE_RC" ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac
gate_verdict "$rc"
exit "$rc"
