#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-refutation.sh - the clean fixture must be one edit from every rule it
# is supposed to be refuting.
#
# WHY IT EXISTS
#   This repository proves its gates can fail. `scripts/gates/fixtures/*/bad/`
#   holds 84 inputs that must be rejected, each with an `.expected` sidecar
#   naming the defect it stands for, and `gate-negative-proof-census.sh` keeps
#   that proof from shrinking in silence. Measured on 2026-09-11, the other
#   half of the balance was 31 inputs under `good/`, and for the family with
#   the most rules - `findings`, 29 bad inputs - it was exactly ONE.
#
#   A gate that never fires on a compliant input is not the same claim as a
#   gate that fires on a defective one, and it is the claim nothing here was
#   making. The failure it misses is the one that costs most: a rule that
#   accuses whoever complied. `maxgfr/ultrasec` shipped that defect and then
#   shipped the test for it on 2026-09-06 - `tests/sink-refutation.test.ts`,
#   560 lines - after its catalog's own note said "AES/GCM here is not a
#   finding" while the engine emitted the opposite, because the matcher read
#   the callee and never read the argument that decided it. Their fix is a
#   `refutedBy` clause, and their test is a case that trips the naive rule and
#   asserts it is refuted.
#
#   A clean fixture cannot make that claim on its own. `01-conforming.json`
#   validates clean, and so would an empty file: passing is only evidence
#   about false positives if the artifact sits ONE edit away from the rule.
#   That distance is what this gate measures, by making the edit.
#
# WHAT IT MEASURES
#   For every case in `scripts/gates/data/refutation-cases.json`:
#     1. the declared validator reports NOTHING over the untouched fixture;
#     2. the declared edit matches the fixture exactly once - an edit that no
#        longer matches is a case that has drifted off the artifact it was
#        written against, and is reported rather than skipped;
#     3. with the edit applied, in a directory named `good/` so the validator
#        judges the copy exactly as it judges the original, the validator
#        rejects it AND the rejection contains the declared needle. Rejected
#        for a different reason is a finding, not a pass: it is the shape
#        `gate-findings-artifact.sh` already refuses in its `.expected`
#        sidecars.
#   Plus two shapes that make the file itself hard to hollow out: two cases
#   declaring the same needle count once, and a case count below the floor in
#   the same file is a finding.
#
# WHAT IT DOES NOT MEASURE
#   Whether the rules are the right rules, whether the fixture is realistic,
#   or whether the families with no case here are safe. It proves the declared
#   distance exists. Nine cases over one fixture is what is declared today,
#   and the number is printed on every run so that "nine" cannot quietly
#   become "one".
#
# Exit codes: 0 = measured and fine | 1 = measured and fails | 2 = could not measure.
#
# Usage:
#   scripts/gates/gate-refutation.sh
#   scripts/gates/gate-refutation.sh --root DIR
#   scripts/gates/gate-refutation.sh --cases FILE
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

ROOT="$(cd "${EHS_REPO_ROOT:-$(gate_root)}" && pwd -P)"
CASES=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root)  ROOT="${2:-}"; shift 2 ;;
    --cases) CASES="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,58p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done
[ -n "$CASES" ] || CASES="$ROOT/scripts/gates/data/refutation-cases.json"

main() {
  gate_header "refutation (the clean fixture must be one edit from the rule it refutes)"
  gate_scope "every case in scripts/gates/data/refutation-cases.json: the fixture validates clean, the reverting edit still matches, and with it applied the validator rejects for the declared reason"
  gate_out_of_scope "whether the rules are the right rules, whether the fixture is realistic, and the families that declare no case at all - this proves the distance, it does not judge it"

  command -v python3 >/dev/null 2>&1 || {
    gate_warn "python3 is not on PATH: nothing was measured"
    gate_verdict 2; return "$GATE_UNMEASURABLE"
  }
  local core="$SELF_DIR/lib/refutation.py"
  [ -f "$core" ] || {
    gate_warn "the refutation engine is missing: lib/refutation.py"
    gate_verdict 2; return "$GATE_UNMEASURABLE"
  }

  local out rc=0
  out="$(python3 "$core" "$ROOT" "$CASES" 2>&1)"
  while IFS='|' read -r code message; do
    [ -z "$code" ] && continue
    case "$code" in
      0) gate_info "$message" ;;
      1) gate_fail "$message"; rc=1 ;;
      *) gate_warn "$message"; [ "$rc" -eq 0 ] && rc=2 ;;
    esac
  done <<< "$out"

  case "$rc" in
    0) gate_ok "every declared refutation case is one edit from its own rule"; gate_verdict 0; return "$GATE_OK" ;;
    1) gate_verdict 1; return "$GATE_FAIL" ;;
    *) gate_verdict 2; return "$GATE_UNMEASURABLE" ;;
  esac
}

main
exit $?
