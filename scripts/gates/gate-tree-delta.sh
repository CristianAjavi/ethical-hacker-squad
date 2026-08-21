#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-tree-delta.sh — how much the served tree grew in THIS change.
#
# WHY IT EXISTS
#   gate-plugin-integrity.sh caps the absolute size of what is copied into every
#   user's plugin cache. Its own header names the weakness: an absolute cap is a
#   poor instrument for "a bot added too much at once", because it goes slack as
#   the corpus grows legitimately, and the only way to satisfy it eventually is
#   to delete knowledge. The control that keeps its meaning is a DELTA guard,
#   and that follow-up is this file.
#
# WHAT IT MEASURES
#   The byte size of the served tree (skills/ agents/) at HEAD minus its size at
#   the merge base with the target branch. Growth beyond the budget fails.
#
#   bot/*  16 KiB   the knowledge loop adds procedures, not chapters
#   human  64 KiB   a new pack plus its wiring measured ~45 KiB, so a legitimate
#                   change of the largest kind observed still fits
#
#   Shrinking is never a failure here: deleting corpus is a different decision,
#   reviewed by a person, and this gate does not have an opinion on it.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure. No git, no base ref, or a shallow clone that cannot reach the merge
# base is a 2 — an unmeasured delta is not a small one.
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
SERVED="${EHS_SERVED_ROOTS:-skills agents}"
BASE_REF="${EHS_BASE_REF:-origin/main}"
BOT_BUDGET="${EHS_TREE_DELTA_BOT_BYTES:-16384}"
HUMAN_BUDGET="${EHS_TREE_DELTA_HUMAN_BYTES:-65536}"

gate_header "tree-delta (how much this change adds to what every user installs)"
gate_scope "growth of $SERVED between the merge base and HEAD"
gate_out_of_scope "the absolute size of the tree - that is gate-plugin-integrity.sh"

command -v git >/dev/null 2>&1 || { gate_warn "git is not installed"; gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"; }
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || { gate_warn "$ROOT is not a git work tree"; gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"; }

if ! git -C "$ROOT" rev-parse --verify --quiet "$BASE_REF" >/dev/null; then
  gate_warn "the base ref '$BASE_REF' is not reachable (a shallow clone cannot measure a delta)"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

base="$(git -C "$ROOT" merge-base HEAD "$BASE_REF" 2>/dev/null)"
if [ -z "$base" ]; then
  gate_warn "no merge base between HEAD and $BASE_REF"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

tree_bytes() {  # <rev>
  # shellcheck disable=SC2086
  git -C "$ROOT" ls-tree -r -l "$1" -- $SERVED 2>/dev/null \
    | awk '{ total += $4 } END { printf "%d", total + 0 }'
}

before="$(tree_bytes "$base")"
after="$(tree_bytes HEAD)"
if [ "$before" -eq 0 ] || [ "$after" -eq 0 ]; then
  gate_warn "the served tree measured 0 bytes at one of the two revisions: $SERVED may not exist there"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

branch="${GITHUB_HEAD_REF:-$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)}"
case "$branch" in
  bot/*) budget="$BOT_BUDGET"; who="bot branch" ;;
  *)     budget="$HUMAN_BUDGET"; who="human branch" ;;
esac

delta=$(( after - before ))
gate_info "base $(printf '%.7s' "$base") · $before B → HEAD $after B · delta ${delta} B"
gate_info "branch '$branch' is a $who: budget ${budget} B"

if [ "$delta" -gt "$budget" ]; then
  gate_fail "this change adds ${delta} B to what every user installs, over the ${budget} B budget for a $who"
  gate_log "        Splitting files does not help: the budget is on the total. Either the addition"
  gate_log "        is worth a human decision to raise the budget in this file, or it is too much at once."
  gate_verdict "$GATE_FAIL"; exit "$GATE_FAIL"
fi

if [ "$delta" -lt 0 ]; then
  gate_ok "the served tree shrank by $(( -delta )) B; this gate has no opinion on deletions"
else
  gate_ok "growth of ${delta} B is within the ${budget} B budget for a $who"
fi
gate_verdict "$GATE_OK"
exit "$GATE_OK"
