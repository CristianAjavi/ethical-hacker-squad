#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-bench-blinding.sh — a pooled batch must not sort itself into arms.
#
# WHY IT EXISTS
#   Blinding is not only about names. When one batch pools claims from several
#   arms, anything that varies with the ARM rather than with the claim is a
#   label, and the SHAPE of a field does it as well as a word: one arm writing
#   `target/agent/answer.py` while another writes `agent/answer.py` lets a judge
#   sort the pool into groups and treat the groups differently.
#
#   Two of those were caught by eye on 2026-08-22, minutes before judging, in
#   the same round. Catching them by eye is not a control.
#
# WHAT IT MEASURES, for pooled batches only
#   No absolute path in a location field; no arm or harness word anywhere in the
#   batch; one location style across the whole batch.
#
# WHAT IT DOES NOT MEASURE
#   Whether the CONTENT of a claim gives its arm away — house vocabulary, a
#   citation habit, a statistic only one corpus supplies. That needs a reader,
#   not a regex, and a green here is NOT a blinding clearance. Batches judged
#   one arm at a time are skipped and named as skipped, because a judge holding
#   a single list has no groups to sort.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, missing core, an unreadable or unparseable batch).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/bench_blinding.py"

gate_header "bench-blinding (a pooled batch must not sort itself into arms)"
gate_scope "absolute paths in location fields, arm and harness words, and location-style uniformity across every pooled blinded batch"
gate_out_of_scope "whether a claim's prose gives its arm away, and single-arm batches, which are named rather than silently skipped"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was measured"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$CORE" ]; then
  gate_warn "the measurement core is missing: $CORE"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

out="$(python3 "$CORE" "$ROOT" 2>&1)"; rc=$?
while IFS= read -r line; do
  case "$line" in
    FINDING\ *)    gate_fail "${line#FINDING }" ;;
    UNMEASURED\ *) gate_warn "${line#UNMEASURED }" ;;
    *)             [ -n "$line" ] && gate_info "$line" ;;
  esac
done <<< "$out"

case "$rc" in
  0) gate_ok "every pooled batch is uniform: no absolute locations, no arm words, one location style" ;;
  1) gate_core_rc 1; rc="$GATE_RC" ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac
gate_verdict "$rc"
exit "$rc"
