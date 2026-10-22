#!/usr/bin/env bash
# scripts/gates/gate-verify-mirror.sh
#
# `scripts/verify.sh` claims to run what the `gates` job of CI runs. This checks
# the claim, in both directions, on every pull request.
#
# WHY IT EXISTS
#   The gates job runs two runners. Only one of them - `run-all.sh` - had a
#   local invocation anybody knew about, and docs/gate-requirements.md told
#   readers it was "everything". On 2026-09-02 a pull request body said "full
#   suite: 34 run, 34 green" and CI went red in that same job, on the other
#   runner, over eighteen cases. The count was honest about the runner it had
#   measured and silent about the one it had not.
#
#   `verify.sh` closes that. This gate stops `verify.sh` from drifting back into
#   a second opinion: a step CI runs and verify.sh omits makes a local green
#   worthless again, and a step verify.sh runs alone is a local red nobody is
#   obliged to fix. Both are failures here.
#
# WHY BOTH DIRECTIONS
#   One-directional registries are this repository's recurring defect - a list
#   that asks "is everything I name present?" and never "is everything present
#   named?". It has now been fixed in the report contract, in governance.json,
#   and here. The shape is the bug, not the subject.
#
# Exit codes: 0 = measured and fine | 1 = measured and fails | 2 = could not measure.
#
# Usage:
#   scripts/gates/gate-verify-mirror.sh
#   scripts/gates/gate-verify-mirror.sh --workflow F --script S --job NAME
#   scripts/gates/gate-verify-mirror.sh --self-test
#
# Environment variables:
#   GATE_SELFTEST=0   skips the self-test; the verdict is then capped at 2.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

CORE="$SELF_DIR/lib/verify_mirror.py"
ROOT="$(gate_root)"
WORKFLOW="$ROOT/.github/workflows/ci.yml"
SCRIPT="$ROOT/scripts/verify.sh"
JOB="gates"
ONLY_SELFTEST=0
SELFTEST_SKIPPED=0

while [ $# -gt 0 ]; do
  case "$1" in
    --workflow) WORKFLOW="${2:-}"; shift 2 ;;
    --script)   SCRIPT="${2:-}"; shift 2 ;;
    --job)      JOB="${2:-}"; shift 2 ;;
    --self-test) ONLY_SELFTEST=1; shift ;;
    -h|--help) sed -n '2,33p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t gatevm)"
trap 'rm -rf "$TMP"' EXIT

# One measurement: ask the script what it runs, ask the workflow what it runs,
# compare. `--list` is used rather than reading the array out of the file, so
# what is compared is what the script would actually execute.
run_core() { # workflow, script, job -> prints findings, returns core rc
  local wf="$1" sc="$2" jb="$3" steps="$TMP/steps.$$.$RANDOM"
  if [ ! -x "$sc" ]; then
    gate_warn "the mirror script is not executable: $sc"
    return "$GATE_UNMEASURABLE"
  fi
  if ! "$sc" --list >"$steps" 2>"$TMP/listerr"; then
    gate_warn "\`$sc --list\` failed; what it runs could not be read: $(head -3 "$TMP/listerr")"
    return "$GATE_UNMEASURABLE"
  fi
  PYTHONSAFEPATH=1 python3 "$CORE" "$wf" "$steps" "$jb"
}

# --- self-test ---------------------------------------------------------------
if [ "${GATE_SELFTEST:-1}" = "0" ] && [ "$ONLY_SELFTEST" = "0" ]; then
  SELFTEST_SKIPPED=1
else
  SELFTEST="$SELF_DIR/gate-verify-mirror.selftest.sh"
  if [ ! -x "$SELFTEST" ]; then
    gate_warn "the self-test is missing: $SELFTEST"
    exit "$GATE_UNMEASURABLE"
  fi
  if ! "$SELFTEST" >"$TMP/selftest.log" 2>&1; then
    gate_fail "the self-test did not pass; this gate's verdict means nothing until it does"
    sed 's/^/    /' "$TMP/selftest.log"
    exit "$GATE_UNMEASURABLE"
  fi
  gate_info "self-test: $(grep -cE '^  (PASS|ok)' "$TMP/selftest.log" || true) cases green"
  [ "$ONLY_SELFTEST" = "1" ] && exit "$GATE_OK"
fi

# --- the real comparison -----------------------------------------------------
gate_header "verify.sh mirrors the CI job it claims to mirror"
gate_scope "the \`run:\` steps of job '$JOB' in $(basename "$WORKFLOW") vs \`$(basename "$SCRIPT") --list\`, both directions"
gate_out_of_scope "whether those steps PASS - that is what running them is for - and the other CI jobs, which have no local mirror and do not claim one"

OUT="$(run_core "$WORKFLOW" "$SCRIPT" "$JOB")"; RC=$?
[ -n "$OUT" ] && printf '%s\n' "$OUT" | grep '^STAT|' | sed 's/^STAT|/· /; s/|/: /'

if [ "$RC" -eq "$GATE_UNMEASURABLE" ]; then
  gate_verdict "$GATE_UNMEASURABLE" "could not measure whether verify.sh mirrors CI"
  exit "$GATE_UNMEASURABLE"
fi

nmiss=$(printf '%s\n' "$OUT" | grep -c '^MISSING_LOCALLY|' || true)
nextra=$(printf '%s\n' "$OUT" | grep -c '^EXTRA_LOCALLY|' || true)
norder=$(printf '%s\n' "$OUT" | grep -c '^ORDER|' || true)

printf '%s\n' "$OUT" | grep '^MISSING_LOCALLY|' | while IFS='|' read -r _ cmd; do
  gate_fail "CI runs \`$cmd\` and verify.sh does not. A local green from verify.sh would not mean CI is green - which is the whole point of running it."
done
printf '%s\n' "$OUT" | grep '^EXTRA_LOCALLY|' | while IFS='|' read -r _ cmd; do
  gate_fail "verify.sh runs \`$cmd\` and job '$JOB' does not. Either CI should run it, or verify.sh is inventing a red nobody is obliged to fix."
done
printf '%s\n' "$OUT" | grep '^ORDER|' | while IFS='|' read -r _ pos cmd; do
  gate_fail "both run \`$cmd\`, at different positions (local index $pos). Order is part of the mirror: an inventory printed after the run it inventories is a different check."
done

# The cap applies to a would-be PASS and to nothing else, the way every other
# gate here does it. An unproved gate must not be believed when it says "fine";
# when it has just named a specific failure it has demonstrated it can fail, and
# downgrading that to "could not measure" would hide a real finding behind a
# caveat about the instrument.
if [ $((nmiss + nextra + norder)) -gt 0 ]; then
  gate_verdict "$GATE_FAIL" "verify.sh and job '$JOB' do not run the same steps"
  exit "$GATE_FAIL"
fi

if [ "$SELFTEST_SKIPPED" = "1" ]; then
  gate_warn "GATE_SELFTEST=0: the gate found nothing, and it never proved it could find anything"
  gate_verdict "$GATE_UNMEASURABLE" "verdict capped: a clean result from an unproved gate is not a pass"
  exit "$GATE_UNMEASURABLE"
fi

gate_ok "verify.sh runs exactly the steps of job '$JOB', in the same order"
gate_verdict "$GATE_OK" "measured, no findings"
exit "$GATE_OK"
