#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-mutant-bank.sh — do the batteries measure what their names claim?
#
# WHY IT EXISTS
#   Every other gate in this directory asks whether the repository is correct.
#   None of them asks whether the batteries that guard those gates are worth
#   anything. They cannot: a battery reports on the gate, and nothing reports on
#   the battery. The gap is not theoretical. A case named
#   `the-copy-renamed-around-the-rule` was green for weeks proving nothing - its
#   fixture used a version string the lockfile already carried, so the value
#   check fired first and returned the expected code, and the name path the case
#   was named after was never reached.
#
# WHAT IT MEASURES
#   For each entry in scripts/gates/data/mutant-bank.json: one named line of one
#   gate is silenced in a throwaway clone of the tree, the battery that claims to
#   cover it is run there, and the outcome is compared against what the bank says
#   should happen. Three outcomes, not two - a mutant caught by SOME case but not
#   by the case that claims the rule is a finding, because the case still does
#   not deserve its name.
#
#   `expect: survives` entries are checked in the other direction too. If someone
#   adds the coverage the bank records as missing, this gate goes RED asking for
#   the bank to be updated. A bank that can only fail one way rots quietly.
#
# WHAT IT DOES NOT MEASURE
#   Every rule that is not in the bank. This gate is a floor under the batteries,
#   not a coverage percentage, and it says so on every run rather than implying
#   the batteries are sound.
#
# THE TREE IS NEVER TOUCHED
#   Mutations land in a clone under TMPDIR that is deleted when its battery
#   returns. The working tree is read once, to build the pattern the clones come
#   from. An earlier draft mutated in place behind a sentinel and a verified
#   restore; the clone made all of that unnecessary along with its worst case.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, no bank, a bank entry whose anchor is gone, a battery
# already red before any mutation, or not enough free space for a clone).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"
ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/mutant_bank.py"
# A seam for the self-test, which needs to point the gate at a bank written for
# one case. It fails closed: an override at an absent or empty path is a 2.
BANK="${EHS_MUTANT_BANK:-$HERE/data/mutant-bank.json}"

gate_header "mutant-bank (break one gate rule, demand the battery notice)"
gate_scope "each rule named in data/mutant-bank.json, broken in a clone and measured against the battery case that claims it"
gate_out_of_scope "every gate rule the bank does not name, and the batteries' behaviour on inputs no mutant produces"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: no mutant was run, which is not the same as the batteries being sound"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$CORE" ]; then
  gate_warn "the measurement core is missing: $CORE"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$BANK" ]; then
  gate_warn "there is no bank at $BANK"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

out="$(EHS_REPO_ROOT="$ROOT" python3 "$CORE" --bank "$BANK" 2>&1)"; rc=$?
while IFS= read -r line; do
  case "$line" in
    FINDING\ *)     gate_fail "${line#FINDING }" ;;
    UNMEASURED\ *)  gate_warn "${line#UNMEASURED }" ;;
    COULD\ NOT\ MEASURE*) gate_warn "${line#COULD NOT MEASURE: }" ;;
    NOT\ SCANNED*)  gate_out_of_scope "${line#NOT SCANNED: }" ;;
    *)              gate_info "$line" ;;
  esac
done <<< "$out"

case "$rc" in
  0) gate_ok "every banked rule, when broken, is caught by the case that claims it, and the accepted survivors are still exactly the ones the bank names" ;;
  1) : ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac
gate_verdict "$rc"
exit "$rc"
