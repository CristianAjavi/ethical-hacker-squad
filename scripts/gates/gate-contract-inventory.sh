#!/usr/bin/env bash
# scripts/gates/gate-contract-inventory.sh
#
# docs/gate-requirements.md opens with a rule about itself:
#
#   "If a gate and this document disagree, the disagreement is itself a bug -
#    fix both in the same pull request."
#
# Nothing executed that sentence. It is the same shape as issue #16, where
# `workflow-hardening` was a required context required by prose: a rule this
# repository states about itself and does not enforce. A gate that exists and
# appears in no row is a control nobody can find from the contract; a row naming
# a gate that does not exist is a control the contract promises and nobody runs.
#
# WHAT IT MEASURES
#   The inventory comes from `run-all.sh --list`, not from a glob of this
#   directory. The runner is the authority on what a gate is - it discovers
#   recursively and is not filtered by extension, so a gate written in Python or
#   living in a subdirectory counts - and asking it means this gate and the
#   runner cannot disagree about what exists.
#
#   Against that inventory, every `gate-*.sh` named in docs/gate-requirements.md
#   must exist, and every gate the runner discovers must be named somewhere in
#   the document. Which row, and what the row says, is a human's judgement and
#   is deliberately not checked here.
#
# Exit codes: 0 = measured and fine | 1 = measured and fails | 2 = could not measure.
#
# Usage:
#   scripts/gates/gate-contract-inventory.sh
#   scripts/gates/gate-contract-inventory.sh --doc FILE --inventory FILE
#   scripts/gates/gate-contract-inventory.sh --self-test
#
# Environment variables:
#   GATE_SELFTEST=0   skips the self-test; the verdict is then capped at 2.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

ROOT="$(gate_root)"
RUNNER="$SELF_DIR/run-all.sh"
FIXTURES="$SELF_DIR/fixtures/contract"
DOC="$ROOT/docs/gate-requirements.md"
INVENTORY=""
ONLY_SELFTEST=0
SELFTEST_SKIPPED=0

while [ $# -gt 0 ]; do
  case "$1" in
    --doc) DOC="${2:-}"; shift 2 ;;
    --inventory) INVENTORY="${2:-}"; shift 2 ;;
    --self-test) ONLY_SELFTEST=1; shift ;;
    -h|--help) sed -n '2,36p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

TMPDIR_GATE="$(mktemp -d 2>/dev/null || mktemp -d -t gateinv)"
trap 'rm -rf "$TMPDIR_GATE"' EXIT

# The runner prints one gate per line; a gate it will not run here is printed
# with a leading '· ' and its reason. Both are gates and both must be documented:
# "not run in this context" is not "does not exist".
# The inventory source is a PARAMETER, never a global read from inside.
# It was a global, and the self-test cleared it after its last fixture - in bash
# a `VAR=x func` assignment in front of a FUNCTION persists in the shell, unlike
# in front of an external command. The effect: `--inventory` was accepted,
# announced in the usage text, and silently ignored on every real run, which is
# how the compatibility check for one pull request came back with four findings
# that did not exist. An option that silently does nothing reads exactly like an
# option that works.
read_inventory() {  # <inventory-file-or-empty> <destination>
  if [ -n "$1" ]; then
    [ -r "$1" ] || return 1
    sed -e 's/^· //' -e 's/ .*$//' "$1" | grep -E '^[^ ]+$' | LC_ALL=C sort -u > "$2"
    return 0
  fi
  [ -x "$RUNNER" ] || return 1
  "$RUNNER" --list 2>/dev/null | sed -e 's/^· //' -e 's/ .*$//' | grep -E '^[^ ]+$' \
    | LC_ALL=C sort -u > "$2"
}

# `*.selftest.sh` is excluded on purpose: a self-test battery is not a gate and
# the runner does not list it as one, so the document naming
# `gate-corpus-contract.selftest.sh` in a sentence about how that gate is proved
# in the negative is correct prose, not a promise of a control that does not
# exist. Counting it as one made this gate report a phantom on its first run.
read_documented() {  # <doc> <destination>
  [ -r "$1" ] || return 1
  grep -oE '`gate-[A-Za-z0-9_.-]+`' "$1" | tr -d '`' \
    | grep -v '\.selftest\.' | LC_ALL=C sort -u > "$2"
}

compare() {  # <doc> <inventory-or-empty> <out>  -> 0 fine | 1 disagreement | 2 could not measure
  local doc="$1" inventory="$2" out="$3"
  local inv="$TMPDIR_GATE/inv" docd="$TMPDIR_GATE/doc"
  : > "$out"

  if ! read_inventory "$inventory" "$inv"; then
    printf 'UNMEAS|the gate inventory could not be read (no runner, or --inventory is unreadable)\n' >> "$out"
    return "$GATE_UNMEASURABLE"
  fi
  if [ ! -s "$inv" ]; then
    printf 'UNMEAS|the inventory is empty: a repository with no gates cannot be checked against a contract\n' >> "$out"
    return "$GATE_UNMEASURABLE"
  fi
  if ! read_documented "$doc" "$docd"; then
    printf 'UNMEAS|%s cannot be read: there is no contract to compare against\n' "$doc" >> "$out"
    return "$GATE_UNMEASURABLE"
  fi

  comm -23 "$inv" "$docd" | sed 's/^/UNDOCUMENTED|/' >> "$out"
  # A phantom is usually a suffix that was dropped, not a control that vanished:
  # the document says `gate-x` where the runner lists `gate-x.sh`, or where the
  # thing being discussed is `gate-x.selftest.sh` - which is excluded on purpose
  # and so reads as a promise of a gate. When the neighbour exists, say so: this
  # gate reported the bare finding twice in one sitting to the person writing the
  # prose, who had to work out the cause both times.
  comm -13 "$inv" "$docd" | while IFS= read -r g; do
    if grep -qxF "$g.sh" "$inv"; then
      printf 'PHANTOM|%s|the runner discovers `%s.sh`: add `.sh` for the gate itself, or `.selftest.sh` if you meant its battery\n' "$g" "$g"
    else
      printf 'PHANTOM|%s|\n' "$g"
    fi
  done >> "$out"
  printf 'STAT|inventory|%s\n'  "$(wc -l < "$inv"  | tr -d ' ')" >> "$out"
  printf 'STAT|documented|%s\n' "$(wc -l < "$docd" | tr -d ' ')" >> "$out"

  grep -qE '^(UNDOCUMENTED|PHANTOM)\|' "$out" && return "$GATE_FAIL"
  return "$GATE_OK"
}

# ---------------------------------------------------------------------------
# SELF-TEST. Each fixture is a directory with `inventory.txt` and `doc.md`; the
# group it lives in is the verdict it must produce.
# ---------------------------------------------------------------------------
self_test() {
  local ok=1 d out rc want expected

  [ -d "$FIXTURES" ] || { gate_warn "self-test: I cannot find the fixtures in $FIXTURES"; return "$GATE_UNMEASURABLE"; }
  out="$TMPDIR_GATE/selftest.out"

  for want in bad good unmeasurable; do
    local found=0
    for d in "$FIXTURES/$want"/*/; do
      [ -d "$d" ] || continue
      found=1
      rc=0
      compare "$d/doc.md" "$d/inventory.txt" "$out" || rc=$?
      case "$want" in
        bad)          [ "$rc" -eq 1 ] || { gate_warn "NEGATIVE self-test failed: $(basename "$d") should FAIL (1) and gave $rc"; ok=0; } ;;
        good)         [ "$rc" -eq 0 ] || { gate_warn "POSITIVE self-test failed: $(basename "$d") should pass (0) and gave $rc"; sed 's/^/        /' "$out"; ok=0; } ;;
        unmeasurable) [ "$rc" -eq 2 ] || { gate_warn "self-test failed: $(basename "$d") should be UNMEASURABLE (2) and gave $rc"; ok=0; } ;;
      esac
      # An optional `.expected` sidecar asserts the WORDING, not just the verdict.
      # A gate that names the defect and stops there costs the reader the fix;
      # this one reported the same thing twice in one sitting to the person
      # writing the prose, who had to work out both times that a suffix was
      # missing. The name is the repository's existing sidecar convention on
      # purpose - `fixtures/findings` has 29 of them, and
      # gate-negative-proof-census.sh counts `.expected` files as ASSERTIONS. A
      # differently-named file would have worked and stayed outside the census
      # that exists to stop negative proof shrinking in silence.
      expected="${d%/}.expected"
      if [ -f "$expected" ]; then
        while IFS= read -r needle; do
          [ -n "$needle" ] || continue
          grep -qF "$needle" "$out" || {
            gate_warn "self-test: $(basename "$d") gave the right verdict but never says: $needle"; ok=0; }
        done < "$expected"
      fi
    done
    [ "$found" -eq 1 ] || { gate_warn "self-test: there are no '$want' fixtures"; ok=0; }
  done

  [ "$ok" -eq 1 ] && return "$GATE_OK"
  return "$GATE_UNMEASURABLE"
}

# ---------------------------------------------------------------------------
main() {
  gate_header "contract-inventory (the document and the gates name the same set)"
  gate_scope "every gate \`run-all.sh --list\` discovers is named in docs/gate-requirements.md, and every gate named there exists"
  gate_out_of_scope "WHICH row a gate belongs to, whether the row's status word is accurate, and whether the requirement text matches what the gate does - all three are a person's judgement; and \`*.selftest.sh\` batteries, which are not gates and which the runner does not list as such"

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
  compare "$DOC" "$INVENTORY" "$out" || rc=$?
  gate_info "contract: ${DOC#"$ROOT"/}"
  sed -n 's/^STAT|/· /p' "$out" | tr '|' ' '

  case "$rc" in
    2)
      sed -n 's/^UNMEAS|/  UNMEASURABLE /p' "$out"
      gate_verdict 2; return "$GATE_UNMEASURABLE" ;;
    1)
      grep '^UNDOCUMENTED|' "$out" | while IFS='|' read -r _k g; do
        gate_fail "$g is discovered by the runner and is named nowhere in the contract: a control nobody can find from the document"
      done
      grep '^PHANTOM|' "$out" | while IFS='|' read -r _k g hint; do
        [ -n "$hint" ] && hint=" - $hint"
        gate_fail "the contract names $g and the runner does not discover it: a control the document promises and nobody runs$hint"
      done
      gate_verdict 1; return "$GATE_FAIL" ;;
  esac

  if [ "$SELFTEST_SKIPPED" -eq 1 ]; then
    gate_warn "the two sets match, but the self-test was skipped: I cannot sign this result"
    gate_verdict 2; return "$GATE_UNMEASURABLE"
  fi
  gate_ok "the contract and the runner name the same set of gates"
  gate_verdict 0
  return "$GATE_OK"
}

main
exit $?
