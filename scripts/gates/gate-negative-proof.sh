#!/usr/bin/env bash
# scripts/gates/gate-negative-proof.sh
#
# docs/gate-requirements.md, on exit-code semantics:
#
#   "Every gate must be PROVED IN THE NEGATIVE: a fixture that makes it exit 1,
#    and a condition that makes it exit 2, both exercised in CI. A gate never
#    observed failing is a gate nobody knows works."
#
# That sentence was true of the document and not of the repository: measured
# against `run-all.sh --list`, four of seventeen gates had no negative proof of
# any kind, and three of them guard failures that are silent by construction.
# The batteries closed the gap; this gate is what stops it reopening, which is
# the second half this repository's closure rule always asks for.
#
# THE CONVENTION IT ENFORCES
#   A gate carries its negative proof in exactly one of two shapes:
#     * a sibling battery `<gate>.selftest.sh`, non-empty - 14 gates do this,
#       and the CI step that proves the gates in the negative discovers it; or
#     * an inline self-test, marked by the gate READING `${GATE_SELFTEST...}` -
#       the documented switch whose only effect is to cap the verdict at 2 when
#       the self-test is skipped, so a gate that has not measured itself can
#       never sign a green. Three gates do this.
#       The marker is matched as a parameter expansion, `${GATE_SELFTEST:` or
#       `${GATE_SELFTEST}`, and not as the bare substring: a plain
#       `grep GATE_SELFTEST` also matches `GATE_SELFTEST_RENAMED` and a comment
#       that merely mentions the switch, and a mutant proved it - renaming the
#       variable in a gate left this check green.
#   Anything else is a gate nobody has seen fail.
#
# WHAT IT DOES NOT CHECK, and will not pretend to
#   Whether the battery is any good: whether its cases are real, whether they
#   cover the rules that matter, whether an assertion is strong. Counting files
#   cannot answer that and a gate that implied otherwise would be worse than
#   this one. It answers exactly one question - does a negative proof exist -
#   and the reviewer answers the rest.
#
# Exit codes: 0 = measured and fine | 1 = measured and fails | 2 = could not measure.
#
# Usage:
#   scripts/gates/gate-negative-proof.sh
#   scripts/gates/gate-negative-proof.sh --gates-dir DIR --inventory FILE
#   scripts/gates/gate-negative-proof.sh --self-test
#
# Environment variables:
#   GATE_SELFTEST=0   skips the self-test; the verdict is then capped at 2.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

RUNNER="$SELF_DIR/run-all.sh"
FIXTURES="$SELF_DIR/fixtures/negative-proof"
GATES_DIR="$SELF_DIR"
INVENTORY=""
ONLY_SELFTEST=0
SELFTEST_SKIPPED=0

while [ $# -gt 0 ]; do
  case "$1" in
    --gates-dir) GATES_DIR="${2:-}"; shift 2 ;;
    --inventory) INVENTORY="${2:-}"; shift 2 ;;
    --self-test) ONLY_SELFTEST=1; shift ;;
    -h|--help) sed -n '2,42p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

TMPDIR_GATE="$(mktemp -d 2>/dev/null || mktemp -d -t gatenp)"
trap 'rm -rf "$TMPDIR_GATE"' EXIT

# Both inputs are PARAMETERS, never globals read from inside: a sibling gate in
# this directory accepted an option, announced it, and silently ignored it
# because its self-test cleared the global it read.
read_inventory() {  # <inventory-or-empty> <destination>
  if [ -n "$1" ]; then
    [ -r "$1" ] || return 1
    sed -e 's/^· //' -e 's/ .*$//' "$1" | grep -E '^[^ ]+$' | LC_ALL=C sort -u > "$2"
    return 0
  fi
  [ -x "$RUNNER" ] || return 1
  "$RUNNER" --list 2>/dev/null | sed -e 's/^· //' -e 's/ .*$//' | grep -E '^[^ ]+$' \
    | LC_ALL=C sort -u > "$2"
}

audit() {  # <gates-dir> <inventory-or-empty> <out>  -> 0 | 1 | 2
  local dir="$1" inventory="$2" out="$3"
  local inv="$TMPDIR_GATE/inv" g sib
  : > "$out"

  if [ -z "$dir" ] || [ ! -d "$dir" ]; then
    printf 'UNMEAS|the gates directory does not exist: %s\n' "$dir" >> "$out"
    return "$GATE_UNMEASURABLE"
  fi
  if ! read_inventory "$inventory" "$inv"; then
    printf 'UNMEAS|the gate inventory could not be read (no runner, or --inventory is unreadable)\n' >> "$out"
    return "$GATE_UNMEASURABLE"
  fi
  if [ ! -s "$inv" ]; then
    printf 'UNMEAS|the inventory is empty: there are no gates whose proof could be checked\n' >> "$out"
    return "$GATE_UNMEASURABLE"
  fi

  local n_sib=0 n_inline=0 n_none=0
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    if [ ! -f "$dir/$g" ]; then
      printf 'UNMEAS|%s is in the inventory and not in %s: I cannot read what I cannot find\n' "$g" "$dir" >> "$out"
      continue
    fi
    sib="$dir/${g%.*}.selftest.sh"
    if [ -s "$sib" ]; then
      n_sib=$((n_sib + 1))
    elif [ -e "$sib" ]; then
      printf 'EMPTY|%s\n' "$g" >> "$out"
      n_none=$((n_none + 1))
    elif grep -qE '\$\{GATE_SELFTEST[:}]' "$dir/$g" 2>/dev/null; then
      n_inline=$((n_inline + 1))
    else
      printf 'NONE|%s\n' "$g" >> "$out"
      n_none=$((n_none + 1))
    fi
  done < "$inv"

  printf 'STAT|gates|%s\n'          "$(wc -l < "$inv" | tr -d ' ')" >> "$out"
  printf 'STAT|sibling_battery|%d\n' "$n_sib" >> "$out"
  printf 'STAT|inline_selftest|%d\n' "$n_inline" >> "$out"
  printf 'STAT|no_proof|%d\n'        "$n_none" >> "$out"

  grep -q '^UNMEAS|' "$out" && return "$GATE_UNMEASURABLE"
  [ "$n_none" -gt 0 ] && return "$GATE_FAIL"
  return "$GATE_OK"
}

self_test() {
  local ok=1 d out rc want
  [ -d "$FIXTURES" ] || { gate_warn "self-test: I cannot find the fixtures in $FIXTURES"; return "$GATE_UNMEASURABLE"; }
  out="$TMPDIR_GATE/selftest.out"
  for want in bad good unmeasurable; do
    local found=0
    for d in "$FIXTURES/$want"/*/; do
      [ -d "$d" ] || continue
      found=1; rc=0
      audit "$d/gates" "$d/inventory.txt" "$out" || rc=$?
      case "$want" in
        bad)          [ "$rc" -eq 1 ] || { gate_warn "NEGATIVE self-test failed: $(basename "$d") should FAIL (1) and gave $rc"; ok=0; } ;;
        good)         [ "$rc" -eq 0 ] || { gate_warn "POSITIVE self-test failed: $(basename "$d") should pass (0) and gave $rc"; sed 's/^/        /' "$out"; ok=0; } ;;
        unmeasurable) [ "$rc" -eq 2 ] || { gate_warn "self-test failed: $(basename "$d") should be UNMEASURABLE (2) and gave $rc"; ok=0; } ;;
      esac
    done
    [ "$found" -eq 1 ] || { gate_warn "self-test: there are no '$want' fixtures"; ok=0; }
  done
  [ "$ok" -eq 1 ] && return "$GATE_OK"
  return "$GATE_UNMEASURABLE"
}

main() {
  gate_header "negative-proof (a gate never observed failing)"
  gate_scope "every gate in \`run-all.sh --list\` carries a non-empty sibling \`<gate>.selftest.sh\`, or reads \`\${GATE_SELFTEST}\` for an inline self-test"
  gate_out_of_scope "whether that proof is any GOOD - whether its cases are real, cover the rules that matter, or assert anything strong. Counting files cannot answer that, and the reviewer does"

  if [ "${GATE_SELFTEST:-1}" != "0" ]; then
    self_test
    local st=$?
    if [ "$st" -ne 0 ]; then
      gate_warn "the gate does NOT pass its own self-test; any result over the repo would be indefensible"
      gate_verdict 2; return "$GATE_UNMEASURABLE"
    fi
    gate_info "self-test passed (negative, positive and unmeasurable fixtures in $FIXTURES)"
  else
    gate_warn "self-test SKIPPED via GATE_SELFTEST=0: the verdict cannot be 0"
    SELFTEST_SKIPPED=1
  fi

  if [ "$ONLY_SELFTEST" -eq 1 ]; then
    if [ "$SELFTEST_SKIPPED" -eq 1 ]; then
      gate_warn "--self-test with GATE_SELFTEST=0: no test was run"; gate_verdict 2; return "$GATE_UNMEASURABLE"
    fi
    gate_ok "self-test passed; the repo was not audited (--self-test)"
    gate_verdict 0; return "$GATE_OK"
  fi

  local out="$TMPDIR_GATE/repo.out" rc=0
  audit "$GATES_DIR" "$INVENTORY" "$out" || rc=$?
  sed -n 's/^STAT|/· /p' "$out" | tr '|' ' '

  if [ "$rc" -eq 2 ]; then
    sed -n 's/^UNMEAS|/  UNMEASURABLE /p' "$out"
    gate_verdict 2; return "$GATE_UNMEASURABLE"
  fi
  if [ "$rc" -eq 1 ]; then
    grep '^NONE|'  "$out" | while IFS='|' read -r _k g; do
      gate_fail "$g has no negative proof: no \`${g%.*}.selftest.sh\` beside it and it never reads \`\${GATE_SELFTEST}\`. Nobody has seen it fail"
    done
    grep '^EMPTY|' "$out" | while IFS='|' read -r _k g; do
      gate_fail "${g%.*}.selftest.sh exists and is EMPTY: a battery in name only reads like a proof and is not one"
    done
    gate_verdict 1; return "$GATE_FAIL"
  fi

  if [ "$SELFTEST_SKIPPED" -eq 1 ]; then
    gate_warn "every gate carries a proof, but the self-test was skipped: I cannot sign this result"
    gate_verdict 2; return "$GATE_UNMEASURABLE"
  fi
  gate_ok "every gate carries a negative proof"
  gate_verdict 0
  return "$GATE_OK"
}

main
exit $?
