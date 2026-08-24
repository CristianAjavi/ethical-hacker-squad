#!/usr/bin/env bash
# scripts/gates/gate-bench-index.sh
#
# Every directory under bench/runs/ must be reachable from a document a reader
# arrives at. A run that exists and nothing points at is not published, whatever
# the file system says.
#
# WHY IT EXISTS
#   This project's one measured advantage is not detection - eighteen blinded
#   measurements say the corpus leads on none of that. It is that a reader can
#   CHECK the numbers: it answers yes to all six axes of a published
#   transparency rubric where no other product in the field exceeds one. A
#   result nobody can navigate to sits outside that claim.
#
#   Written after a run was added to this repository and left unlinked by the
#   person adding it, in the same session. The first thing it found was that.
#
# WHAT IT DOES NOT DECIDE
#   Whether a run is a measurement, a pre-registration, a retraction or a patch
#   bench. That taxonomy is editorial - it is what the project chooses to claim,
#   it is not derivable from the tree, and a gate that invented it would enforce
#   its author's opinion rather than the project's. The top-level README's
#   "eighteen blinded measurements" is therefore NOT checked here, and saying so
#   is part of the check: an unstated limit reads like coverage.
#
# Exit codes: 0 = measured and fine | 1 = measured and fails | 2 = could not measure.
#
# Usage:
#   scripts/gates/gate-bench-index.sh
#   scripts/gates/gate-bench-index.sh --root DIR
#   scripts/gates/gate-bench-index.sh --self-test

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

CORE="$SELF_DIR/lib/bench_index.py"
FIXTURES="$SELF_DIR/fixtures/bench-index"
ROOT="$(cd "${EHS_REPO_ROOT:-$(gate_root)}" && pwd -P)"
ONLY_SELFTEST=0
SELFTEST_SKIPPED=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --self-test) ONLY_SELFTEST=1; shift ;;
    -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t gatebidx)"
trap 'rm -rf "$TMPD"' EXIT

# PYTHONSAFEPATH: the helper is invoked BY PATH, so its own directory leads on
# sys.path rather than a working directory that may belong to a tree under audit.
run_core() { PYTHONSAFEPATH=1 python3 "$CORE" "$1" > "$2" 2>&1; }

self_test() {
  local ok=1 d out rc want
  [ -d "$FIXTURES" ] || { gate_warn "self-test: I cannot find the fixtures in $FIXTURES"; return "$GATE_UNMEASURABLE"; }
  out="$TMPD/selftest.out"
  for want in bad good unmeasurable; do
    local found=0
    for d in "$FIXTURES/$want"/*/; do
      [ -d "$d" ] || continue
      found=1; rc=0
      run_core "$d" "$out" || rc=$?
      case "$want" in
        bad)
          if [ "$rc" -ne 0 ] || ! grep -qE '^(UNINDEXED|BROKEN)\|' "$out"; then
            gate_warn "NEGATIVE self-test failed: $(basename "$d") should report a finding"; ok=0
          fi ;;
        good)
          if [ "$rc" -ne 0 ] || grep -qE '^(UNINDEXED|BROKEN|ERR)\|' "$out"; then
            gate_warn "POSITIVE self-test failed: $(basename "$d") should be clean:"; sed 's/^/        /' "$out"; ok=0
          fi ;;
        unmeasurable)
          if [ "$rc" -ne 2 ] || ! grep -q '^ERR|' "$out"; then
            gate_warn "self-test failed: $(basename "$d") should be UNMEASURABLE (rc 2 + ERR), gave rc=$rc"; ok=0
          fi ;;
      esac
    done
    [ "$found" -eq 1 ] || { gate_warn "self-test: there are no '$want' fixtures"; ok=0; }
  done
  [ "$ok" -eq 1 ] && return "$GATE_OK"
  return "$GATE_UNMEASURABLE"
}

main() {
  gate_header "bench-index (a run nobody can navigate to)"
  gate_scope "every directory under bench/runs/ is referenced from a document a reader arrives at - bench/README.md, README.md, CHANGELOG.md, docs/*.md - and every runs/ link in those resolves"
  gate_out_of_scope "WHICH KIND each run is - measurement, pre-registration, retraction, patch bench. That taxonomy is editorial rather than derivable, so the README's \"eighteen blinded measurements\" is not checked here; a run citing another run is also not an index, because runs pointing at each other is a graph with no entrance"

  [ -f "$CORE" ] || { gate_warn "the checker $CORE is missing"; gate_verdict 2; return "$GATE_UNMEASURABLE"; }
  command -v python3 >/dev/null 2>&1 || { gate_warn "there is no python3 in PATH"; gate_verdict 2; return "$GATE_UNMEASURABLE"; }

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
    [ "$SELFTEST_SKIPPED" -eq 1 ] && { gate_warn "--self-test with GATE_SELFTEST=0: no test was run"; gate_verdict 2; return "$GATE_UNMEASURABLE"; }
    gate_ok "self-test passed; the repo was not audited (--self-test)"; gate_verdict 0; return "$GATE_OK"
  fi

  local out="$TMPD/repo.out" rc=0
  run_core "$ROOT" "$out" || rc=$?
  sed -n 's/^STAT|/· /p' "$out" | tr '|' ' '

  if [ "$rc" -eq 2 ] || grep -q '^ERR|' "$out"; then
    sed -n 's/^ERR|/  UNMEASURABLE /p' "$out"; gate_verdict 2; return "$GATE_UNMEASURABLE"
  fi

  local n=0
  if grep -q '^UNINDEXED|' "$out"; then
    grep '^UNINDEXED|' "$out" | while IFS='|' read -r _k r; do
      gate_fail "bench/runs/$r is referenced by no index: it exists and a reader cannot get to it"
    done
    n=1
  fi
  if grep -q '^BROKEN|' "$out"; then
    grep '^BROKEN|' "$out" | while IFS='|' read -r _k r; do
      gate_fail "$r points at a run directory that does not exist"
    done
    n=1
  fi
  [ "$n" -eq 1 ] && { gate_verdict 1; return "$GATE_FAIL"; }

  if [ "$SELFTEST_SKIPPED" -eq 1 ]; then
    gate_warn "every run is indexed, but the self-test was skipped: I cannot sign this result"
    gate_verdict 2; return "$GATE_UNMEASURABLE"
  fi
  gate_ok "every run under bench/runs/ is reachable from an index, and every link resolves"
  gate_verdict 0
  return "$GATE_OK"
}

main
exit $?
