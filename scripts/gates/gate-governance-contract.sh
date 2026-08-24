#!/usr/bin/env bash
# scripts/gates/gate-governance-contract.sh
#
# The check that closes issue #16: a required context that is required by prose.
#
# WHY IT EXISTS
#   scripts/gh/governance.json carries two lists that have to agree:
#     promotion.required_contexts                     what the promotion verifies
#     branches.<source>.protection...checks           what a merge actually requires
#   `workflow-hardening` was in the first and not in the second, so the job ran on
#   every pull request and its red gated nothing. The blinded self-audit found it
#   (F-005); this gate is what stops it coming back.
#
# WHY IT IS SEPARATE FROM apply-governance.sh
#   That script needs `gh`, admin credentials and a live repository, so it runs
#   when a person runs it. This one compares two lists inside one file: it needs
#   no network, so it runs on every pull request like any other gate. The live
#   half stays where it was; `apply-governance.sh --check` folds this gate's
#   result in, the same way it delegates the label taxonomy to labels.sh.
#
# Exit codes: 0 = measured and fine | 1 = measured and fails | 2 = could not measure.
#
# Usage:
#   scripts/gates/gate-governance-contract.sh              # audits the repo's file
#   scripts/gates/gate-governance-contract.sh --file F     # audits another file
#   scripts/gates/gate-governance-contract.sh --self-test  # only the self-test
#
# Environment variables:
#   GATE_SELFTEST=0   skips the self-test; the verdict is then capped at 2.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

CORE="$SELF_DIR/lib/governance_contract.py"
FIXTURES="$SELF_DIR/fixtures/governance"
ROOT="$(gate_root)"
TARGET="$ROOT/scripts/gh/governance.json"
ONLY_SELFTEST=0
SELFTEST_SKIPPED=0

while [ $# -gt 0 ]; do
  case "$1" in
    --file) TARGET="${2:-}"; shift 2 ;;
    --self-test) ONLY_SELFTEST=1; shift ;;
    -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

TMPDIR_GATE="$(mktemp -d 2>/dev/null || mktemp -d -t gategov)"
trap 'rm -rf "$TMPDIR_GATE"' EXIT

# PYTHONSAFEPATH: the helper is invoked BY PATH, so its own directory goes first
# on sys.path - not a working directory that could belong to a tree under audit.
# The release `verify` job runs every gate with the candidate tree as cwd.
run_core() {  # <file> <out>
  PYTHONSAFEPATH=1 python3 "$CORE" "$1" > "$2" 2>&1
}

# ---------------------------------------------------------------------------
# SELF-TEST. Each negative fixture declares, in a `_gate_expect` field, the
# finding it must produce - JSON has no comments, so the convention differs from
# the YAML fixtures and the intent does not.
# ---------------------------------------------------------------------------
self_test() {
  local ok=1 f out expect rc

  if [ ! -d "$FIXTURES" ]; then
    gate_warn "self-test: I cannot find the fixtures in $FIXTURES"
    return "$GATE_UNMEASURABLE"
  fi

  out="$TMPDIR_GATE/selftest.out"

  for f in "$FIXTURES"/bad/*.json; do
    [ -e "$f" ] || { gate_warn "self-test: there are no negative fixtures"; return "$GATE_UNMEASURABLE"; }
    rc=0; run_core "$f" "$out" || rc=$?
    expect="$(sed -n 's/.*"_gate_expect"[ ]*:[ ]*"\([^"]*\)".*/\1/p' "$f" | head -1)"
    if [ -z "$expect" ]; then
      gate_warn "self-test: fixture $(basename "$f") does not declare \"_gate_expect\""
      ok=0
      continue
    fi
    if [ "$rc" -ne 0 ]; then
      gate_warn "NEGATIVE self-test failed: $(basename "$f") should be MEASURED (rc 0 from the core) and the core returned $rc"
      ok=0
      continue
    fi
    if ! grep -q "^${expect}|" "$out"; then
      gate_warn "NEGATIVE self-test failed: $(basename "$f") should produce '$expect' and it produced:"
      sed 's/^/        /' "$out"
      ok=0
    fi
  done

  for f in "$FIXTURES"/good/*.json; do
    [ -e "$f" ] || { gate_warn "self-test: there are no positive fixtures"; return "$GATE_UNMEASURABLE"; }
    rc=0; run_core "$f" "$out" || rc=$?
    if [ "$rc" -ne 0 ] || grep -qE '^(MISSING|ERR)\|' "$out"; then
      gate_warn "POSITIVE self-test failed: $(basename "$f") should come out clean (rc=$rc):"
      sed 's/^/        /' "$out"
      ok=0
    fi
  done

  for f in "$FIXTURES"/unmeasurable/*.json; do
    [ -e "$f" ] || continue
    rc=0; run_core "$f" "$out" || rc=$?
    if [ "$rc" -ne 2 ] || ! grep -q '^ERR|' "$out"; then
      gate_warn "self-test failed: $(basename "$f") should come out UNMEASURABLE (rc 2 + ERR) and gave rc=$rc"
      ok=0
    fi
  done

  [ "$ok" -eq 1 ] && return "$GATE_OK"
  return "$GATE_UNMEASURABLE"
}

# ---------------------------------------------------------------------------
main() {
  gate_header "governance-contract (a required check that nothing requires)"
  gate_scope "inside scripts/gh/governance.json: every context in \`promotion.required_contexts\` must also appear in \`branches.<source_branch>.protection.required_status_checks.checks\`"
  gate_out_of_scope "the LIVE state of the repository - whether GitHub actually enforces what this file declares is apply-governance.sh's job, and it needs credentials this gate does not have"

  if [ ! -f "$CORE" ]; then
    gate_warn "the checker $CORE is missing"; gate_verdict 2; return "$GATE_UNMEASURABLE"
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    gate_warn "there is no python3 in PATH"; gate_verdict 2; return "$GATE_UNMEASURABLE"
  fi

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
  run_core "$TARGET" "$out" || rc=$?
  gate_info "audited file: ${TARGET#"$ROOT"/}"

  if [ "$rc" -eq 2 ]; then
    sed -n 's/^ERR|/  UNMEASURABLE /p' "$out"
    gate_verdict 2; return "$GATE_UNMEASURABLE"
  fi
  if [ "$rc" -ne 0 ]; then
    gate_warn "the checker returned an unexpected code $rc"
    sed 's/^/        /' "$out"
    gate_verdict 2; return "$GATE_UNMEASURABLE"
  fi

  sed -n 's/^STAT|/· /p' "$out" | tr '|' ' '

  local nmissing
  nmissing="$(grep -c '^MISSING|' "$out" 2>/dev/null || true)"
  nmissing="${nmissing:-0}"

  grep '^EXTRA|' "$out" 2>/dev/null | while IFS='|' read -r _k ctx; do
    gate_info "'$ctx' is enforced by the protection and not declared in required_contexts: stricter than declared, not a finding"
  done

  if [ "$nmissing" -gt 0 ]; then
    grep '^MISSING|' "$out" | while IFS='|' read -r _k ctx; do
      gate_fail "'$ctx' is declared in promotion.required_contexts and is NOT in the branch protection: the job runs on every pull request and its red blocks no merge. Required by prose is not required"
    done
    gate_verdict 1; return "$GATE_FAIL"
  fi

  if [ "$SELFTEST_SKIPPED" -eq 1 ]; then
    gate_warn "no disagreement found, but the self-test was skipped: I cannot sign this result"
    gate_verdict 2; return "$GATE_UNMEASURABLE"
  fi

  gate_ok "every declared required context is enforced by the branch protection"
  gate_verdict 0
  return "$GATE_OK"
}

main
exit $?
