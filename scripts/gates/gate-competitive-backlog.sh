#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-competitive-backlog.sh — the roadmap, against the gate directory.
#
# WHY IT EXISTS
#   docs/competitive-analysis.md §5 is the plan for being better than the
#   neighbouring products: fifteen items, each naming the gate that would keep
#   it. It carried no status, so the only way to know what had shipped was to
#   grep and infer — and while items 1..7 were shipping, two gates went on
#   printing, in their out-of-scope declarations, that no machine-readable
#   finding was emitted yet and blaming item 7 for it.
#   The caveat was still true. The reason attached to
#   it was not, and a stale reason reads exactly like a live one.
#
#   `gate-contract-inventory.sh` already keeps docs/gate-requirements.md and the
#   gate directory in agreement, and says in as many words that "what the row
#   says is a human's judgement and is deliberately not checked here". This gate
#   is the other document and the other question: not whether a gate is named
#   somewhere, but whether what the row CLAIMS about it is still true.
#
# WHAT IT MEASURES
#   B1  every row's status is one of shipped / partial / open
#   B2  every shipped or partial row names a gate the runner actually has
#   B3  no open row is quietly kept by a gate that already exists
#   B4  no line in the repository calls a SHIPPED item missing
#
# WHAT IT DOES NOT MEASURE
#   Whether a shipped item is shipped WELL, or whether the gate named in a row
#   is the right gate for it. Both are judgement. This gate checks that the
#   claim and the directory agree, not that the claim was wise.
#
#   B4 reads ONE LINE at a time, and only present-tense absence: a claim split
#   across two lines, or a past-tense account of why an item was written, is
#   deliberately not a finding. See the note beside ABSENCE in the core.
#
#   A line carrying the token `backlog:quoted`, or sitting directly under one,
#   is exempt — this file, the docs and the self-test all have to QUOTE a stale
#   reason to explain it. Every exemption is counted and printed on the run, so
#   an excused line is a visible one; the token excuses that line and nothing
#   else.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, missing core, unreadable document, no Status column, no
# rows, an empty runner inventory, or no citation left to check).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/competitive_backlog.py"
DOC="${EHS_BACKLOG_DOC:-$ROOT/docs/competitive-analysis.md}"

gate_header "competitive-backlog (the roadmap, against the gate directory)"
gate_scope "the status of every backlog item against the gates the runner has, and every line in the repository that calls a shipped item missing"
gate_out_of_scope "whether a shipped item was shipped well, and whether the gate a row names is the right one for it"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was measured"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$CORE" ]; then
  gate_warn "the measurement core is missing: $CORE"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

# The inventory comes from the runner, not from a glob of this directory: the
# runner is the authority on what a gate is, and asking it means this gate and
# the runner cannot disagree about what exists.
inv="$(mktemp "${TMPDIR:-/tmp}/ehs-backlog-inv-XXXXXX")"
trap 'rm -f "$inv"' EXIT
if ! bash "$HERE/run-all.sh" --list > "$inv" 2>/dev/null; then
  gate_warn "the runner would not list its gates, so every row would look unkept"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

out="$(python3 "$CORE" "$ROOT" "$DOC" "$inv" 2>&1)"; rc=$?
emitted=0
while IFS= read -r line; do
  case "$line" in
    FINDING\ *)    gate_fail "${line#FINDING }"; emitted=$((emitted+1)) ;;
    UNMEASURED\ *) gate_warn "${line#UNMEASURED }" ;;
    *)             [ -n "$line" ] && gate_info "$line" ;;
  esac
done <<< "$out"

case "$rc" in
  0) gate_ok "every backlog row's status matches the gate directory, and nothing in the repository calls a shipped item missing" ;;
  # python exits 1 on an unhandled exception, and 1 is also this contract's
  # "measured, FAILS". They are told apart by the only thing that distinguishes
  # them: a real failure names its findings. Silence at rc=1 is a crash, and a
  # crash measured nothing. This was not hypothetical - the core called a list
  # as a function in every could-not-measure arm, and each of those arms
  # arrived here as a confident red.
  1) if [ "$emitted" -eq 0 ]; then
       gate_warn "the measurement core exited 1 and named no finding, so it crashed rather than measured"
       rc="$GATE_UNMEASURABLE"
     fi ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac
gate_verdict "$rc"
exit "$rc"
