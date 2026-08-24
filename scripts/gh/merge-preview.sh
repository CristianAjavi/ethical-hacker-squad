#!/usr/bin/env bash
# scripts/gh/merge-preview.sh
#
# Runs the whole verification suite over the tree that MERGING EVERY OPEN PULL
# REQUEST would produce, in a throwaway worktree, and touches nothing.
#
# WHY IT EXISTS
#   CI judges each pull request against `main`. It cannot judge the combination,
#   because no single branch has both halves of it. That gap is not theoretical:
#   one branch here added a self-test battery that enumerated the eight files a
#   gate reads, another split one of those files in two, and each was green on
#   its own. Merged, the gate asked for a file the battery did not copy and all
#   twelve of its cases came back "could not measure" - on a tree where nothing
#   was actually wrong. Nobody would have seen it until after the merge.
#
#   "Green on a branch" and "green on the merge" are two different
#   measurements. This runs the second one.
#
# WHAT IT DOES
#   1. Merges each branch into a detached worktree at BASE, in the order given.
#      A conflict is REPORTED and the branch is skipped - never auto-resolved by
#      default: guessing a resolution would measure a tree nobody is going to
#      ship. With --union it retries the conflicting files with git's own union
#      resolution, which keeps BOTH sides of every conflicting hunk in order.
#      That is right for a list or a table that only grows - the common case
#      when two branches each append a row to the same document - and wrong for
#      anything where the two sides contradict, which is why it is opt-in and
#      why every file resolved that way is printed by name.
#
#      Without it this tool would have missed the defect it was written for:
#      the branch carrying the broken battery conflicted on one table row, and
#      a skipped branch measures nothing.
#   2. Runs scripts/gates/run-all.sh over the result.
#   3. Runs every self-test battery under scripts/, fixtures pruned.
#
# EXIT CODES (repo contract)
#   0 = measured, and the merged tree is green
#   1 = measured, and something FAILS on the merged tree
#   2 = could not measure (no git, no gh when it is needed, a branch that does
#       not resolve, a conflict - an unmeasured combination is not a clean one)
#
# WHAT IT DOES NOT MEASURE, and says so on every run
#   gate-tree-delta.sh compares the served tree against the merge base. Merging
#   every branch at once makes that delta the SUM of every branch's growth,
#   which is not a number anybody will ever ship: pull requests land one at a
#   time and the base moves under each. It is skipped by name, printed as
#   skipped, and never silently dropped.
#
# Usage:
#   scripts/gh/merge-preview.sh                 # every open PR, oldest first
#   scripts/gh/merge-preview.sh br1 br2 br3     # exactly these, in this order
#   scripts/gh/merge-preview.sh --base stable br1
#   scripts/gh/merge-preview.sh --union             # keep both sides on a conflict
#   scripts/gh/merge-preview.sh --list          # print the branches and stop

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/../.." && pwd)"
BASE="origin/main"
LIST_ONLY=0
UNION=0
SKIP_GATES="gate-tree-delta.sh"
SKIP_WHY="its delta over a combined merge is a number nobody ships"

while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="${2:-}"; shift 2 ;;
    --list) LIST_ONLY=1; shift ;;
    --union) UNION=1; shift ;;
    -h|--help) sed -n '2,44p' "${BASH_SOURCE[0]}"; exit 0 ;;
    --) shift; break ;;
    -*) printf 'COULD NOT MEASURE: unknown argument %s\n' "$1" >&2; exit 2 ;;
    *) break ;;
  esac
done

# gate-actions-lint.sh delegates `run:` analysis to shellcheck and returns 2
# without it - which is correct, and would turn every local preview into "could
# not measure" for a reason that has nothing to do with the combination. CI runs
# it in its own job with the tool installed. Here it is skipped ONLY when the
# tool is genuinely absent, and the reason is printed either way.
if ! command -v shellcheck >/dev/null 2>&1; then
  SKIP_GATES="$SKIP_GATES gate-actions-lint.sh"
  SKIP_WHY="$SKIP_WHY; gate-actions-lint.sh because shellcheck is not installed here - install it for a local green that means what CI's means"
fi

command -v git >/dev/null 2>&1 || { echo "COULD NOT MEASURE: git is missing" >&2; exit 2; }
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || { echo "COULD NOT MEASURE: $ROOT is not a git work tree" >&2; exit 2; }

BRANCHES=("$@")
if [ "${#BRANCHES[@]}" -eq 0 ]; then
  command -v gh >/dev/null 2>&1 || { echo "COULD NOT MEASURE: no branches given and gh is missing to discover the open pull requests" >&2; exit 2; }
  while IFS= read -r b; do
    [ -n "$b" ] && BRANCHES+=("origin/$b")
  done < <(gh pr list --state open --json number,headRefName --jq 'sort_by(.number)[].headRefName' 2>/dev/null)
  [ "${#BRANCHES[@]}" -gt 0 ] || { echo "COULD NOT MEASURE: no open pull request was found and none was given" >&2; exit 2; }
fi

printf '\n=== merge preview: %s + %d branch(es) ===\n' "$BASE" "${#BRANCHES[@]}"
printf 'ORDER     : %s\n' "${BRANCHES[*]}"
printf 'SKIPPED   : %s\n' "$SKIP_GATES"
printf 'WHY       : %s\n' "$SKIP_WHY"

if [ "$LIST_ONLY" -eq 1 ]; then exit 0; fi

git -C "$ROOT" rev-parse -q --verify "$BASE" >/dev/null 2>&1 || {
  printf 'COULD NOT MEASURE: the base %s does not resolve\n' "$BASE" >&2; exit 2; }

WT="$(mktemp -d "${TMPDIR:-/tmp}/ehs-merge-preview-XXXXXX")"
cleanup() { git -C "$ROOT" worktree remove --force "$WT/tree" >/dev/null 2>&1 || true; rm -rf "$WT"; }
trap cleanup EXIT

git -C "$ROOT" worktree add --detach "$WT/tree" "$BASE" >/dev/null 2>&1 || {
  printf 'COULD NOT MEASURE: I could not create a worktree at %s\n' "$BASE" >&2; exit 2; }

printf '\n== merging\n'
CONFLICTS=0 MERGED=0
for b in "${BRANCHES[@]}"; do
  if ! git -C "$ROOT" rev-parse -q --verify "$b" >/dev/null 2>&1; then
    printf '  UNRESOLVED  %-44s this ref does not exist\n' "$b"
    CONFLICTS=$((CONFLICTS + 1)); continue
  fi
  if git -C "$WT/tree" merge --no-edit -q "$b" >"$WT/merge.log" 2>&1; then
    printf '  merged      %s\n' "$b"
    MERGED=$((MERGED + 1))
    continue
  fi

  conflicted="$(git -C "$WT/tree" diff --name-only --diff-filter=U)"
  if [ "$UNION" -ne 1 ]; then
    printf '  CONFLICT    %-44s %s\n' "$b" "$(tr '\n' ' ' <<<"$conflicted")"
    git -C "$WT/tree" merge --abort >/dev/null 2>&1 || true
    CONFLICTS=$((CONFLICTS + 1))
    continue
  fi

  # Union resolution, by git's own implementation: stages 1/2/3 of each
  # conflicted path are handed to `git merge-file --union`, which keeps both
  # sides of every conflicting hunk in order. Anything it cannot resolve that
  # way still counts as a conflict.
  union_ok=1
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    git -C "$WT/tree" show ":1:$f" > "$WT/base" 2>/dev/null || : > "$WT/base"
    git -C "$WT/tree" show ":2:$f" > "$WT/ours" 2>/dev/null || { union_ok=0; break; }
    git -C "$WT/tree" show ":3:$f" > "$WT/theirs" 2>/dev/null || { union_ok=0; break; }
    if git merge-file --union "$WT/ours" "$WT/base" "$WT/theirs" >/dev/null 2>&1; then
      cp "$WT/ours" "$WT/tree/$f"
      git -C "$WT/tree" add -- "$f" >/dev/null 2>&1 || union_ok=0
      printf '  union       %s :: %s\n' "$b" "$f"
    else
      union_ok=0; break
    fi
  done <<<"$conflicted"

  if [ "$union_ok" -eq 1 ] && git -C "$WT/tree" commit --no-edit -q >/dev/null 2>&1; then
    printf '  merged      %s (union on %d file(s))\n' "$b" "$(grep -c . <<<"$conflicted")"
    MERGED=$((MERGED + 1))
  else
    printf '  CONFLICT    %-44s %s (union could not resolve it)\n' "$b" "$(tr '\n' ' ' <<<"$conflicted")"
    git -C "$WT/tree" merge --abort >/dev/null 2>&1 || true
    CONFLICTS=$((CONFLICTS + 1))
  fi
done

RC=0
if [ "$CONFLICTS" -gt 0 ]; then
  printf '\n  %d branch(es) did not merge. They are SKIPPED, never auto-resolved:\n' "$CONFLICTS"
  printf '  guessing a resolution measures a tree nobody is going to ship.\n'
  [ "$UNION" -eq 1 ] || printf '  --union retries a conflict by keeping BOTH sides of every hunk, which is\n  what an append-only table wants and what a real disagreement does not.\n'
  RC=2
fi

printf '\n== gates over the merged tree\n'
gates_rc=0
skip_args=()
for g in $SKIP_GATES; do skip_args+=(--skip "$g"); done
( cd "$WT/tree" && EHS_BASE_REF="$BASE" ./scripts/gates/run-all.sh "${skip_args[@]}" ) \
  > "$WT/gates.log" 2>&1 || gates_rc=$?
grep -E '^(OK|FAIL|UNMEASURABLE|discovered)' "$WT/gates.log" | sed 's/^/  /' | tail -40
case "$gates_rc" in
  0) : ;;
  1) RC=1 ;;
  *) [ "$RC" -eq 1 ] || RC=2 ;;
esac

printf '\n== self-test batteries over the merged tree\n'
bat_worst=0 bat_n=0
while IFS= read -r t; do
  [ -n "$t" ] || continue
  bat_n=$((bat_n + 1))
  rc=0
  ( cd "$WT/tree" && bash "$t" </dev/null >/dev/null 2>&1 ) || rc=$?
  case "$rc" in
    0) : ;;
    2) printf '  COULD NOT MEASURE  %s\n' "$t"; bat_worst=2 ;;
    *) printf '  FAILED             %s\n' "$t"; [ "$bat_worst" -eq 2 ] || bat_worst=1 ;;
  esac
done < <(cd "$WT/tree" && find scripts -type d -name fixtures -prune -o -type f -name '*.selftest.sh' -print | LC_ALL=C sort)
printf '  %d battery(ies), worst = %d\n' "$bat_n" "$bat_worst"
case "$bat_worst" in
  1) RC=1 ;;
  2) [ "$RC" -eq 1 ] || RC=2 ;;
esac

printf '\n== verdict\n'
printf '  merged %d · conflicts %d · gates rc=%d · batteries worst=%d\n' "$MERGED" "$CONFLICTS" "$gates_rc" "$bat_worst"
case "$RC" in
  0) printf '  0 (measured: the combination is green)\n' ;;
  1) printf '  1 (measured: the combination FAILS - and no single branch would have said so)\n' ;;
  *) printf '  2 (COULD NOT MEASURE the whole combination - this is not a pass)\n' ;;
esac
exit "$RC"
