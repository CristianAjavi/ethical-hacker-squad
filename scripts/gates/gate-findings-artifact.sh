#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-findings-artifact.sh — the deliverable's skeleton, validated.
#
# WHY IT EXISTS
#   The markdown report is what a person reads; nothing in it can be checked by
#   a machine, diffed between two engagements or scored. Four of the five
#   neighbouring products emit a machine-readable findings artifact and we did
#   not, which is also why nobody - us included - has ever measured this
#   squad's detection quality: there was nothing to count.
#
# WHAT IT MEASURES
#   The artifact against the four files that each own one thing: the schema owns
#   the shape, vocabulary.md owns the words, triage.md owns the rules, and
#   packs.json owns which procedures exist. Then the invariants that make it
#   worth having: `confirmed` demands a complete triage with nothing UNKNOWN and
#   nothing HOLDS, `probable` names its inferred link, `withdrawn` names its
#   reason, `candidate` never ships, no procedure or identifier is invented, and
#   no high-precision secret format travels inside the file.
#
# USAGE
#   scripts/gates/gate-findings-artifact.sh                     # the fixtures
#   scripts/gates/gate-findings-artifact.sh --deliverable f.json
#
# WHAT IT DOES NOT MEASURE
#   Whether a finding is true. A well-formed artifact can carry a confident
#   mistake; what this removes is the class where the prose says one thing and
#   the structure says another.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, an unreadable source of truth, no fixtures and no file).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/findings_artifact.py"
TARGETS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --deliverable) shift; [ $# -gt 0 ] || { gate_warn "--deliverable needs a path"; exit "$GATE_UNMEASURABLE"; }
                   TARGETS+=("$1") ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
  shift
done

gate_header "findings-artifact (the machine-readable half of a deliverable)"
if [ "${#TARGETS[@]}" -gt 0 ]; then
  gate_scope "the artifact(s) given, against the schema, the vocabulary, the triage rules and the corpus"
else
  gate_scope "the fixtures under scripts/gates/fixtures/findings, good and bad"
fi
gate_out_of_scope "whether a finding is true - a well-formed artifact can carry a confident mistake"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was measured"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$CORE" ]; then
  gate_warn "the measurement core is missing: $CORE"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

out="$(python3 "$CORE" "$ROOT" "${TARGETS[@]+"${TARGETS[@]}"}" 2>&1)"; rc=$?
while IFS= read -r line; do
  case "$line" in
    FINDING\ *)    gate_fail "${line#FINDING }" ;;
    UNMEASURED\ *) gate_warn "${line#UNMEASURED }" ;;
    *)             gate_info "$line" ;;
  esac
done <<< "$out"

case "$rc" in
  0) gate_ok "the artifact conforms, and every fixture failed for the reason it stands for" ;;
  1) gate_core_rc 1; rc="$GATE_RC" ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac
gate_verdict "$rc"
exit "$rc"
