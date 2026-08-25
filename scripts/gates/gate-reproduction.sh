#!/usr/bin/env bash
# scripts/gates/gate-reproduction.sh
#
# The executable probes still reproduce what the two keys say they should.
#
# WHY IT EXISTS
#   A neighbouring product ships proofs-of-concept and four sandbox backends to
#   run them in. This repository declared reproduction out of scope, and the
#   cost was measured rather than imagined: in the third-competitor round an
#   outside rubric docked a finding of ours for carrying no reproduction
#   evidence, and that round's own note records the deduction as our own
#   restriction appearing on somebody else's scoreboard.
#
#   The answer here is not their sandbox. This corpus carries TWO independent
#   keys over the same files - where each defect was planted, and what each
#   patch actually achieves - and the patches are deliberately imperfect, so
#   several are declared `not fixed`. Running the probes across the patched
#   variants checks the patch key while the patch key checks the probes. A
#   product with one key cannot run this check at all.
#
# WHAT IT MEASURES
#   That every probe reproduces its defect on the unpatched case, and that a
#   patch declared `not fixed` still reproduces while one declared `verified`
#   does not. Nine measurements over five defects and four patches.
#
# WHAT IT DOES NOT MEASURE, and will not pretend to
#   Whether a patch is good, whether the probe is the proof a reviewer would
#   have written, or anything about defects outside cli-packer. Of the 43
#   planted defects in this corpus only ten are reproducible without installing
#   anything, and five of those ten live in this one file; the rest need
#   `anthropic`, `sqlalchemy`, `marshmallow`, `flask_restful`, or are not Python
#   at all. A green here is five defects proved, not a bench reproduced.
#
# Exit codes: 0 = measured and fine | 1 = measured and fails | 2 = could not measure.
#
# Usage:
#   scripts/gates/gate-reproduction.sh
#   scripts/gates/gate-reproduction.sh --root DIR
#   scripts/gates/gate-reproduction.sh --self-test
#
# Environment variables:
#   GATE_SELFTEST=0   skips the self-test; the verdict is then capped at 2.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

ROOT="$(cd "${EHS_REPO_ROOT:-$(gate_root)}" && pwd -P)"
HARNESS="$SELF_DIR/../bench/reproduce.py"
ONLY_SELFTEST=0
SELFTEST_SKIPPED=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --self-test) ONLY_SELFTEST=1; shift ;;
    -h|--help) sed -n '2,42p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

# ---------------------------------------------------------------------------
# The self-test: two mutants, one for each way this gate can be wrong.
#
# A harness that only ever runs against a healthy tree is a harness nobody has
# watched fail. The first mutant makes the two keys disagree and demands a 1;
# the second removes what the run reads and demands a 2, because a tree that
# cannot be measured must never come back green.
# ---------------------------------------------------------------------------
selftest() {
  command -v python3 >/dev/null 2>&1 || { gate_warn "python3 is not on PATH"; return "$GATE_UNMEASURABLE"; }
  [ -f "$HARNESS" ] || { gate_warn "the harness is missing at $HARNESS"; return "$GATE_UNMEASURABLE"; }

  local work rc
  work="$(mktemp -d)" || { gate_warn "cannot create a working directory"; return "$GATE_UNMEASURABLE"; }
  # Cleaned up explicitly rather than with `trap ... RETURN`: bash propagates a
  # RETURN trap to the caller, and this one fired again as main() returned, when
  # $work no longer existed.

  # -- mutant 1: the patch key claims a patch works, the probe says otherwise --
  cp -R "$ROOT/bench" "$work/bench" 2>/dev/null || { rm -rf "$work"; gate_warn "cannot copy the bench"; return "$GATE_UNMEASURABLE"; }
  python3 - "$work/bench/patch-truth.json" <<'PY' || { rm -rf "$work"; gate_warn "cannot build the first mutant"; return "$GATE_UNMEASURABLE"; }
import json, sys
p = sys.argv[1]
doc = json.load(open(p))
for entry in doc["patches"]:
    if entry["id"] == "PC-02":
        entry["expected"] = "verified"   # PC-02 does not fix anything; the probe knows
json.dump(doc, open(p, "w"), indent=1)
PY
  python3 "$HARNESS" --root "$work" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -ne 1 ]; then
    rm -rf "$work"
    gate_fail "self-test: a patch key that contradicts the probes returned $rc, expected 1"
    return "$GATE_FAIL"
  fi

  # -- mutant 2: the reproduction key is gone -------------------------------
  rm -f "$work/bench/reproduction/cli-packer/key.json"
  python3 "$HARNESS" --root "$work" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -ne 2 ]; then
    rm -rf "$work"
    gate_fail "self-test: a tree with no reproduction key returned $rc, expected 2"
    return "$GATE_FAIL"
  fi

  rm -rf "$work"
  return "$GATE_OK"
}

main() {
  gate_header "reproduction (the probes still reproduce what both keys say)"
  gate_scope "every planted defect of bench/cases/cli-packer that carries a probe, run on the unpatched case and on each patch of it, against bench/ground-truth.json and bench/patch-truth.json"
  gate_out_of_scope "whether a patch is good, whether a probe is the proof a reviewer would have written, and the 38 planted defects that need a dependency or another language"

  if [ "${GATE_SELFTEST:-1}" != "0" ]; then
    selftest
    local st=$?
    [ "$st" -eq "$GATE_OK" ] || { gate_verdict "$st"; return "$st"; }
    gate_info "self-test: a contradicting patch key returns 1, a missing reproduction key returns 2"
  else
    SELFTEST_SKIPPED=1
    gate_warn "self-test SKIPPED via GATE_SELFTEST=0: the verdict cannot be 0"
  fi

  if [ "$ONLY_SELFTEST" -eq 1 ]; then
    [ "$SELFTEST_SKIPPED" -eq 1 ] && { gate_warn "--self-test with GATE_SELFTEST=0: no test was run"; gate_verdict 2; return "$GATE_UNMEASURABLE"; }
    gate_ok "self-test passed; the repo was not audited (--self-test)"; gate_verdict 0; return "$GATE_OK"
  fi

  command -v python3 >/dev/null 2>&1 || { gate_warn "python3 is not on PATH"; gate_verdict 2; return "$GATE_UNMEASURABLE"; }
  [ -f "$HARNESS" ] || { gate_warn "the harness is missing at $HARNESS"; gate_verdict 2; return "$GATE_UNMEASURABLE"; }

  local output rc
  output="$(python3 "$HARNESS" --root "$ROOT" 2>&1)"
  rc=$?
  printf '%s\n' "$output" | while IFS= read -r line; do [ -n "$line" ] && gate_info "${line# }"; done

  case "$rc" in
    0)
      if [ "$SELFTEST_SKIPPED" -eq 1 ]; then
        gate_warn "the probes agree with both keys, but the self-test was skipped: I cannot sign this result"
        gate_verdict 2; return "$GATE_UNMEASURABLE"
      fi
      gate_ok "every probe reproduces on the unpatched case, and every patch behaves as its key declares"
      gate_verdict 0; return "$GATE_OK"
      ;;
    1)
      gate_fail "a probe and a key disagree: one of the two is wrong and the run names both candidates"
      gate_verdict 1; return "$GATE_FAIL"
      ;;
    *)
      gate_warn "the reproduction run could not measure (harness exit $rc)"
      gate_verdict 2; return "$GATE_UNMEASURABLE"
      ;;
  esac
}

main
exit $?
