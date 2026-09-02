#!/usr/bin/env bash
# scripts/gates/gate-routing-stage.sh
#
# The routing stage dataset is forced by the routing table, and is not solvable
# by matching the table's own words.
#
# WHY IT EXISTS
#   `bench/stages/triage` was this repository's only per-stage dataset, against
#   nine shipped by `google/mantis`. Adding a second stage is only worth doing
#   if the second is built the way the first was: with a key the author does not
#   get to reinterpret.
#
#   Routing has that property and almost nothing else does. The answer to
#   "which role, which sections" is a ROW of `references/coverage.md`, so the
#   key names the row and this gate re-reads the file and takes the two cells
#   itself. A key that drifts from the table is a failure, not a disagreement
#   between two opinions.
#
#   It also has a failure mode the triage stage does not, and it is the reason
#   for the second half of this file. A routing case whose text repeats the
#   signal cell that routes it measures whether a model can string-match a
#   table it was handed. So the gate builds a router out of the table's own
#   words -- backticked tokens and the content words of each signal cell -- runs
#   it over the cases, and reports what that router scores. A set the trivial
#   router answers perfectly has nothing left to measure, and this gate fails
#   it. The number is REPORTED and only the perfect score is enforced: a
#   threshold picked after seeing the number is a threshold fitted to it.
#
# WHAT IT MEASURES
#   1. `cases.json` still hashes to the digest the key sealed.
#   2. Every case has exactly one key row and every key row exactly one case.
#   3. For each key row: the named row exists in `coverage.md` exactly once, and
#      the key's `role` and `sections` are that row's second and third cells,
#      character for character.
#   4. No presented field carries a role token, a pack file name, a section
#      marker or a procedure id -- all read out of `coverage.md`, never listed
#      here, so the scan forbids what the table actually declares.
#   5. The table-word router does not answer every case correctly.
#
# WHAT IT DOES NOT MEASURE
#   Whether a case is well chosen, whether the row the key names is the row a
#   careful reader would name, and whether the inventory fragment is realistic.
#   Those are editorial. This gate checks that the key is forced by the table
#   and that the set is not trivially string-matchable.
#
#   It also does not run the eval. No model has seen these cases; see
#   `bench/stages/routing/PREREGISTRATION.md`.
#
# Exit codes: 0 = measured and fine | 1 = measured and fails | 2 = could not measure.
#
# Usage:
#   scripts/gates/gate-routing-stage.sh
#   scripts/gates/gate-routing-stage.sh --root DIR
#   scripts/gates/gate-routing-stage.sh --self-test
#
# Environment variables:
#   GATE_SELFTEST=0   skips the self-test; the verdict is then capped at 2.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

ROOT="$(cd "${EHS_REPO_ROOT:-$(gate_root)}" && pwd -P)"
ONLY_SELFTEST=0
SELFTEST_SKIPPED=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --self-test) ONLY_SELFTEST=1; shift ;;
    -h|--help) sed -n '2,49p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

audit() {  # audit <root> [coverage-rel] [cases-rel] [key-rel] -> "rc|message" lines
  python3 "$SELF_DIR/lib/routing_stage.py" "$@"
}

selftest() {
  command -v python3 >/dev/null 2>&1 || { gate_warn "python3 is not on PATH"; return "$GATE_UNMEASURABLE"; }
  local work out
  work="$(mktemp -d)" || { gate_warn "cannot create a working directory"; return "$GATE_UNMEASURABLE"; }
  python3 "$SELF_DIR/lib/routing_stage_fixture.py" "$work" || {
    rm -rf "$work"; gate_warn "self-test: cannot build the fixture"; return "$GATE_UNMEASURABLE"; }

  # The healthy tree must be clean, and each of the other five is the healthy
  # tree with exactly one thing broken. A check that passes all six is a check
  # that is not reading the thing it claims to read.
  out="$(audit "$work/healthy")"
  if printf '%s\n' "$out" | grep -qE '^[12]\|'; then
    rm -rf "$work"; gate_fail "self-test: the healthy fixture returned '$out'"; return "$GATE_FAIL"
  fi

  local -a checks=(
    "role-drift|1|does not match the table"
    "stale-seal|1|no longer hashes"
    "leaked-role|1|names the role"
    "trivial-router|1|answers every case"
    "no-table|2|holds no routing row"
  )
  local spec name code phrase
  for spec in "${checks[@]}"; do
    name="${spec%%|*}"; spec="${spec#*|}"; code="${spec%%|*}"; phrase="${spec#*|}"
    out="$(audit "$work/$name")"
    if ! printf '%s\n' "$out" | grep -qF -- "$phrase"; then
      rm -rf "$work"
      gate_fail "self-test: fixture '$name' never said '$phrase'; it said: ${out//$'\n'/ / }"
      return "$GATE_FAIL"
    fi
    if ! printf '%s\n' "$out" | grep -q "^$code|"; then
      rm -rf "$work"
      gate_fail "self-test: fixture '$name' did not return $code; it said: ${out//$'\n'/ / }"
      return "$GATE_FAIL"
    fi
  done

  rm -rf "$work"
  return "$GATE_OK"
}

main() {
  gate_header "routing-stage (the key is forced by the routing table, and the set is not string-matchable)"
  gate_scope "bench/stages/routing: the seal on cases.json, the key's agreement with references/coverage.md cell for cell, the leak scan over presented fields, and what a router built from the table's own words scores"
  gate_out_of_scope "whether a case is well chosen and whether the row the key names is the row a careful reader would name - both editorial; and running the eval, which no model has done"

  if [ "${GATE_SELFTEST:-1}" != "0" ]; then
    selftest
    local st=$?
    [ "$st" -eq "$GATE_OK" ] || { gate_verdict "$st"; return "$st"; }
    gate_info "self-test: a key row disagreeing with the table, a stale seal, a role name leaked into a case, a set the trivial router answers perfectly, and a missing table all behave"
  else
    SELFTEST_SKIPPED=1
    gate_warn "self-test SKIPPED via GATE_SELFTEST=0: the verdict cannot be 0"
  fi

  if [ "$ONLY_SELFTEST" -eq 1 ]; then
    [ "$SELFTEST_SKIPPED" -eq 1 ] && { gate_warn "--self-test with GATE_SELFTEST=0: no test was run"; gate_verdict 2; return "$GATE_UNMEASURABLE"; }
    gate_ok "self-test passed; the repo was not audited (--self-test)"; gate_verdict 0; return "$GATE_OK"
  fi

  command -v python3 >/dev/null 2>&1 || { gate_warn "python3 is not on PATH"; gate_verdict 2; return "$GATE_UNMEASURABLE"; }

  local out rc=0
  out="$(audit "$ROOT")"
  while IFS='|' read -r code message; do
    [ -z "$code" ] && continue
    case "$code" in
      0) gate_info "$message" ;;
      1) gate_fail "$message"; rc=1 ;;
      *) gate_warn "$message"; [ "$rc" -eq 0 ] && rc=2 ;;
    esac
  done <<< "$out"

  case "$rc" in
    0)
      if [ "$SELFTEST_SKIPPED" -eq 1 ]; then
        gate_warn "the dataset agrees with the table, but the self-test was skipped: I cannot sign this result"
        gate_verdict 2; return "$GATE_UNMEASURABLE"
      fi
      gate_ok "the routing key is forced by references/coverage.md and the set is not answered by its words"
      gate_verdict 0; return "$GATE_OK" ;;
    1) gate_verdict 1; return "$GATE_FAIL" ;;
    *) gate_verdict 2; return "$GATE_UNMEASURABLE" ;;
  esac
}

main
exit $?
