#!/usr/bin/env bash
# scripts/gates/gate-untrusted-content.sh
#
# AI-22 and safety-contract rule 8 -- audited content is data, never
# instructions -- cannot be deleted, renumbered away, or softened into a
# suggestion without somebody editing the registry on purpose.
#
# WHY THIS EXISTS, measured. On 2026-09-02 the squad was pointed at its own
# repository. Rule 8 was deleted from SKILL.md and all 39 gates were run: the
# mutated tree failed in exactly the same places as the control. Not one gate
# went red. This repository's own doctrine is that prose which does not execute
# is not a control, and its self-protection clause was prose.
#
# WHAT IT DOES NOT DO, said plainly so nobody mistakes this for coverage: no
# static check makes a model OBEY a rule. This gate defends the text, not the
# behaviour. Obedience is a bench/ question, and `AI-22` has no bench case yet.
#
# EXIT CODES: 0 measured-OK · 1 measured-FAILS · 2 COULD NOT MEASURE.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/untrusted_content.py"

gate_header "untrusted-content (the clause that makes audited content data, not orders)"
gate_scope "every load-bearing clause of AI-22 and of the safety contract, present and still absolute"
gate_out_of_scope "whether a model OBEYS the rule: no static check measures that, and AI-22 has no bench case"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was measured"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$CORE" ]; then
  gate_warn "the measurement core is missing: $CORE"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

out="$(python3 "$CORE" "$ROOT" 2>&1)"; rc=$?
findings=0
while IFS= read -r line; do
  case "$line" in
    FINDING\ *)    gate_fail "${line#FINDING }"; findings=$((findings + 1)) ;;
    UNMEASURED\ *) gate_warn "${line#UNMEASURED }" ;;
    *)             [ -n "$line" ] && gate_info "$line" ;;
  esac
done <<< "$out"

# A python3 that dies also exits 1. The discriminator is the output: a verdict
# of 1 that named nothing is a crash, and a crash is never a measured failure.
if [ "$rc" -eq 1 ] && [ "$findings" -eq 0 ]; then
  gate_warn "the core exited 1 and named no finding: that is a crash, not a verdict"
  rc="$GATE_UNMEASURABLE"
fi

case "$rc" in
  0) gate_ok "the clause is present, whole, and still absolute" ;;
  1|2) : ;;
  *) gate_warn "the measurement core exited $rc: that is a crash, not a verdict"
     rc="$GATE_UNMEASURABLE" ;;
esac

gate_verdict "$rc"
exit "$rc"
