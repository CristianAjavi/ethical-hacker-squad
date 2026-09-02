#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-scope-contract.sh — the scope of work, reconciled against the run.
#
# WHY IT EXISTS
#   `engagement.scope` was one free-text sentence and nothing compared it to
#   anything. So two different failures were invisible in the same way: a
#   finding located outside the authorised tree, and an authorised target the
#   squad never opened. The second costs more. An audit that quietly skipped
#   half of what it was pointed at reads exactly like an audit that looked and
#   found nothing, and the client reads that silence as a clean result.
#
#   Three neighbouring products ship a scope file — PentAGI a template with an
#   eight-step operator check, PT-Agents a guard block grepped for in CI (which
#   this repo already enforces, in gate-agent-tools.sh), AgSec a portable
#   artifact. All three are PRE-ACTION. None of them reconciles the declaration
#   against the engagement that ran. That is what this gate adds.
#
# WHAT IT MEASURES
#   Both directions, on every artifact: nothing touched sits outside
#   `authorized` or inside `out_of_scope`, and nothing in `authorized` is
#   missing from `examined`. Plus the one shape rule JSON Schema cannot state —
#   `not-examined` has to carry its reason.
#
# USAGE
#   scripts/gates/gate-scope-contract.sh                     # the fixtures
#   scripts/gates/gate-scope-contract.sh --deliverable f.json
#
# WHAT IT DOES NOT MEASURE
#   Whether the authorisation is genuine, whether a non-`path` target was
#   respected, or whether an examination was any good. Those are reported as
#   unchecked rather than counted as verified, because a coverage number that
#   quietly stands in for coverage is the defect this gate exists to remove.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, an unreadable schema, no scope.md, no artifact at all,
# or a scope still written in the legacy string form).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/scope_contract.py"
TARGETS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --deliverable) shift; [ $# -gt 0 ] || { gate_warn "--deliverable needs a path"; exit "$GATE_UNMEASURABLE"; }
                   TARGETS+=("$1") ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
  shift
done

gate_header "scope-contract (what the squad was allowed to touch, against what it touched)"
if [ "${#TARGETS[@]}" -gt 0 ]; then
  gate_scope "the artifact(s) given: declared scope against their own findings and coverage"
else
  gate_scope "the fixtures under scripts/gates/fixtures/scope, good and bad"
fi
gate_out_of_scope "whether the authorisation is real - that reference is a string a person checks"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was measured"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$CORE" ]; then
  gate_warn "the measurement core is missing: $CORE"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

out="$(python3 "$CORE" "$ROOT" "${TARGETS[@]+"${TARGETS[@]}"}" 2>&1)"; rc=$?
findings=0
while IFS= read -r line; do
  [ -n "$line" ] || continue
  case "$line" in
    FINDING\ *)    gate_fail "${line#FINDING }"; findings=$((findings + 1)) ;;
    UNMEASURED\ *) gate_warn "${line#UNMEASURED }" ;;
    *)             gate_info "$line" ;;
  esac
done <<< "$out"

# python3 exits 1 when it falls over, which is the same 1 a measured failure
# uses. Eleven gates in this repo once reported a crash as a red they had
# measured. The discriminator is the OUTPUT: a failure that named no finding
# never found one, and "could not measure" is the only honest thing left.
if [ "$rc" -eq 1 ] && [ "$findings" -eq 0 ]; then
  gate_warn "the core exited 1 and named no finding: that is a crash, not a verdict"
  rc="$GATE_UNMEASURABLE"
fi

case "$rc" in
  0) gate_ok "every declared scope agrees with its run, in both directions" ;;
  1|2) : ;;
  *) gate_warn "the measurement core exited $rc: that is a crash, not a verdict"
     rc="$GATE_UNMEASURABLE" ;;
esac
gate_verdict "$rc"
exit "$rc"
