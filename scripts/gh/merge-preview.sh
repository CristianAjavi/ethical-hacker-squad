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
# WHAT --chain ADDS, and why the plain mode was not enough
#   The plain mode merges the whole stack and then measures ONCE. That answers
#   "is the combination green", and it cannot answer "WHICH branch broke it" -
#   the only form of the answer anybody can act on, because the fix belongs on
#   one branch and the person who has to write it is its author.
#
#   Worse, it cannot tell a gate the merge BROKE from one that was already red
#   on the base. With no "before", every red reads as the combination's fault.
#
#   --chain measures the base first, then again after EVERY merge, and diffs the
#   two verdict maps BY GATE NAME. A gate that was 0 at one point and 1 at the
#   next is attributed to the branch merged in between, by name. That is the
#   difference between "something is wrong" and "gate-handover-contract.sh went
#   green -> FAIL when loop/iter4 landed, and no single branch would say so".
#
#   It costs one full suite pass per point. Measured on this repository on
#   2026-09-11: `run-all.sh --selftests` over origin/main takes 4m08s, so a
#   four-branch chain is five passes, about twenty-one minutes. That price is
#   why it is a flag and not the default.
#
#   A CONFLICT STOPS THE CHAIN. The plain mode skips the conflicting branch and
#   carries on, which is right when the question is "is the rest green". It is
#   wrong here: every point after a skipped branch measures a tree that is not
#   the chain, so a regression found later would be attributed to the wrong
#   branch - worse than not attributing it at all. The branches after a conflict
#   are printed as NOT MEASURED, by name, and the run cannot return 0.
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
#   scripts/gh/merge-preview.sh --chain br1 br2 # measure EVERY point and
#                                               # attribute each regression

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/../.." && pwd)"
BASE="origin/main"
LIST_ONLY=0
UNION=0
CHAIN=0
UNIONED=""
SKIP_GATES="gate-tree-delta.sh"
SKIP_WHY="its delta over a combined merge is a number nobody ships"

while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="${2:-}"; shift 2 ;;
    --list) LIST_ONLY=1; shift ;;
    --union) UNION=1; shift ;;
    --chain) CHAIN=1; shift ;;
    -h|--help) sed -n '2,72p' "${BASH_SOURCE[0]}"; exit 0 ;;
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

# DISCOVERY.
#
# Two things were wrong with asking `gh pr list` for every open pull request and
# merging whatever came back, and both were measured on this repository on
# 2026-09-11, when it had thirty of them open.
#
#   1. A pull request whose BASE is another pull request's branch is already
#      stacked. Merging its head into `main` drags its base in with it, so the
#      same work is counted twice and the tree measured is one nobody is going
#      to ship. Only the pull requests that actually target BASE are taken, and
#      every one left out is printed BY NAME with the reason - a branch dropped
#      in silence is the omission this file exists to stop.
#
#   2. An EMPTY answer from `gh` is not the same fact as "there is nothing
#      open". It is also what a missing token, the wrong account, a rate limit
#      and a network failure look like, and all four of them return zero rows
#      and exit clean. Reporting a green from a zero you never proved you could
#      have seen a one in is the whole disease this repository is built around.
#      So the empty answer is checked against a KNOWN POSITIVE: if the same
#      command with `--state all` returns at least one pull request, the query
#      works, the zero is a measurement, and there is genuinely nothing to
#      combine - which is a declared 0, printed as such, never an implied one.
#      If the control comes back empty too, the instrument is what is blind and
#      the answer is 2.
BRANCHES=("$@")
NOTHING_TO_COMBINE=0
if [ "${#BRANCHES[@]}" -eq 0 ]; then
  command -v gh >/dev/null 2>&1 || { echo "COULD NOT MEASURE: no branches given and gh is missing to discover the open pull requests" >&2; exit 2; }
  base_short="${BASE##*/}"
  gh_rows="$(gh pr list --state open --limit 200 --json number,headRefName,baseRefName \
              --jq 'sort_by(.number)[] | "\(.number)\t\(.headRefName)\t\(.baseRefName)"' 2>/dev/null)" || gh_rows=""
  EXCLUDED=""
  while IFS=$'\t' read -r num head base_of; do
    [ -n "$head" ] || continue
    if [ "$base_of" = "$base_short" ]; then
      BRANCHES+=("origin/$head")
    else
      EXCLUDED="$EXCLUDED
  #$num $head -> $base_of (stacked: its base is not $base_short)"
    fi
  done <<EOF
$gh_rows
EOF
  if [ "${#BRANCHES[@]}" -eq 0 ]; then
    control="$(gh pr list --state all --limit 1 --json number --jq 'length' 2>/dev/null)" || control=""
    if [ "${control:-0}" -gt 0 ] 2>/dev/null; then
      NOTHING_TO_COMBINE=1
    else
      echo "COULD NOT MEASURE: no pull request targets $base_short, and the known-positive control (--state all) also came back empty - that is a blind instrument, not an empty repository" >&2
      exit 2
    fi
  fi
  if [ -n "$EXCLUDED" ]; then
    printf 'NOT IN THE CHAIN, and not in silence - their base is not %s:%s\n' "$base_short" "$EXCLUDED"
  fi
fi

if [ "$NOTHING_TO_COMBINE" -eq 1 ]; then
  printf '\n=== merge preview: %s + 0 branch(es) ===\n' "$BASE"
  printf 'Nothing targets %s today, and I proved I can see pull requests when there\n' "${BASE##*/}"
  printf 'are any: `gh pr list --state all` returned rows. There is no combination to\n'
  printf 'judge, so there is nothing that can be wrong with one.\n'
  printf '  0 (measured: nothing to combine)\n'
  exit 0
fi

printf '\n=== merge preview: %s + %d branch(es) ===\n' "$BASE" "${#BRANCHES[@]}"
printf 'ORDER     : %s\n' "${BRANCHES[*]}"
printf 'SKIPPED   : %s\n' "$SKIP_GATES"
printf 'WHY       : %s\n' "$SKIP_WHY"

if [ "$LIST_ONLY" -eq 1 ]; then exit 0; fi

git -C "$ROOT" rev-parse -q --verify "$BASE" >/dev/null 2>&1 || {
  printf 'COULD NOT MEASURE: the base %s does not resolve\n' "$BASE" >&2; exit 2; }

# The throwaway worktree needs an identity of its own. A merge that has to
# create a commit fails with "Please tell me who you are" wherever git has no
# global user.name - which is every CI runner, and any laptop that only ever
# configured identity per repository. This tool then reported that failure as a
# CONFLICT, which is a lie about the branches. Measured: green on a machine with
# a global identity, "merged 1 · conflicts 1" on a runner without one.
GIT_ID=(-c "user.name=merge-preview" -c "user.email=merge-preview@localhost")

WT="$(mktemp -d "${TMPDIR:-/tmp}/ehs-merge-preview-XXXXXX")"
cleanup() { git -C "$ROOT" worktree remove --force "$WT/tree" >/dev/null 2>&1 || true; rm -rf "$WT"; }
trap cleanup EXIT

git -C "$ROOT" worktree add --detach "$WT/tree" "$BASE" >/dev/null 2>&1 || {
  printf 'COULD NOT MEASURE: I could not create a worktree at %s\n' "$BASE" >&2; exit 2; }

# ---------------------------------------------------------------------------
# --chain: measure every point, and attribute every regression to ONE branch.
# ---------------------------------------------------------------------------

SKIP_ARGS=()
for g in $SKIP_GATES; do SKIP_ARGS+=(--skip "$g"); done

# measure_point <outfile>
#
# Writes one "<VERDICT> <name>" line per gate and per battery, so two points can
# be compared BY NAME rather than by a summary count. A count tells you the
# number moved; only the name tells you what to go and read.
#
# Two runners, because they discover different sets: run-all.sh --selftests
# covers scripts/gates/** (gates and the self-tests that live beside them), and
# the batteries outside that directory are launched one by one. Measured on
# origin/main on 2026-09-11: 57 names from the first, 6 from the second. Leaving
# the second set out would have made six batteries invisible to the comparison,
# which is exactly the silence this tool was written against.
measure_point() {
  local out="$1" rc=0 brc=0 v="" b=""
  : > "$out"
  ( cd "$WT/tree" && EHS_BASE_REF="$BASE" ./scripts/gates/run-all.sh --selftests "${SKIP_ARGS[@]}" ) \
    > "$WT/run.log" 2>&1 || rc=$?
  sed -e 's/\x1b\[[0-9;]*m//g' "$WT/run.log" \
    | awk '/^===== GATE SUMMARY =====/ {seen=1; next}
           seen && $1 ~ /^(OK|FAIL|UNMEASURABLE)$/ && $2 ~ /\.(sh|py)$/ { print $1, $2 }' \
    >> "$out"
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    brc=0
    ( cd "$WT/tree" && bash "$b" </dev/null >/dev/null 2>&1 ) || brc=$?
    case "$brc" in 0) v=OK ;; 2) v=UNMEASURABLE ;; *) v=FAIL ;; esac
    printf '%s %s\n' "$v" "$b" >> "$out"
  done < <(cd "$WT/tree" && find scripts -type d -name fixtures -prune -o -type f -name '*.selftest.sh' -print \
             | grep -v '^scripts/gates/' | LC_ALL=C sort)
  # A point with no names at all is not a green point: the runner did not run.
  [ -s "$out" ] || return 2
  return 0
}

# transitions <prev> <now>
#
# Ranks OK < FAIL < UNMEASURABLE, so "went the wrong way" is one comparison and
# not a table of special cases. An UNMEASURABLE is ranked WORSE than a FAIL on
# purpose: a gate that stopped being able to measure has stopped defending
# anything, and it is the transition that reads most like a pass.
transitions() {
  awk 'function rank(v){ return v=="OK" ? 0 : (v=="FAIL" ? 1 : 2) }
       NR==FNR { p[$2]=$1; next }
       { n[$2]=$1 }
       END {
         for (k in n) {
           if (!(k in p))            { print "APPEARED", n[k], k; continue }
           if (p[k] == n[k])         continue
           if (rank(n[k]) > rank(p[k])) print "BROKE", p[k] "->" n[k], k
           else                        print "FIXED", p[k] "->" n[k], k
         }
         for (k in p) if (!(k in n))  print "VANISHED", p[k], k
       }' "$1" "$2" | LC_ALL=C sort
}

if [ "$CHAIN" -eq 1 ]; then
  printf '\n== point 0: the base, %s\n' "$BASE"
  printf '   (a red gate here is the base'"'"'s, not the chain'"'"'s. Without this\n'
  printf '    measurement every red later would be blamed on a merge.)\n'
  BASE_OK=1
  if ! measure_point "$WT/p0"; then
    printf '  COULD NOT MEASURE the base. Nothing after this can be attributed.\n'
    exit 2
  fi
  awk '{print $1}' "$WT/p0" | LC_ALL=C sort | uniq -c | sed 's/^/  /'
  grep -v '^OK ' "$WT/p0" | sed 's/^/  base is already: /' || true
  grep -q -v '^OK ' "$WT/p0" && BASE_OK=0

  RC=0
  CHAIN_BROKE=0 CHAIN_UNMEAS=0
  prev="$WT/p0"
  i=0
  STOPPED=""
  for b in "${BRANCHES[@]}"; do
    i=$((i + 1))
    if [ -n "$STOPPED" ]; then
      printf '\n== %s : NOT MEASURED (the chain stopped at %s)\n' "$b" "$STOPPED"
      RC=2
      continue
    fi
    printf '\n== point %d: + %s\n' "$i" "$b"
    if ! git -C "$ROOT" rev-parse -q --verify "$b" >/dev/null 2>&1; then
      printf '  UNRESOLVED  this ref does not exist\n'
      STOPPED="$b"; RC=2; continue
    fi
    if ! git -C "$WT/tree" "${GIT_ID[@]}" merge --no-edit -q "$b" >"$WT/merge.log" 2>&1; then
      printf '  CONFLICT, file by file and hunk by hunk:\n'
      while IFS= read -r f; do
        [ -n "$f" ] || continue
        hk="$(grep -c '^<<<<<<< ' "$WT/tree/$f" 2>/dev/null || true)"
        ln="$(grep -n '^<<<<<<< ' "$WT/tree/$f" 2>/dev/null | cut -d: -f1 | tr '\n' ' ' || true)"
        printf '    %-52s %s hunk(s) at line(s) %s\n' "$f" "${hk:-?}" "${ln:-?}"
      done < <(git -C "$WT/tree" diff --name-only --diff-filter=U)
      git -C "$WT/tree" merge --abort >/dev/null 2>&1 || true
      STOPPED="$b"; RC=2; continue
    fi
    printf '  merged clean for git. That is not the same as safe - measuring:\n'
    now="$WT/p$i"
    if ! measure_point "$now"; then
      printf '  COULD NOT MEASURE this point\n'
      RC=2; continue
    fi
    out="$(transitions "$prev" "$now")"
    if [ -z "$out" ]; then
      printf '  no gate or battery changed verdict.\n'
    else
      printf '%s\n' "$out" | while IFS=' ' read -r kind move name; do
        printf '    %-9s %-14s %s\n' "$kind" "$move" "$name"
      done
      # Two buckets, not one, and the ranking above decides which. A gate that
      # went OK->FAIL is a merge that BREAKS something and the chain is worth 1.
      # A gate that went OK->UNMEASURABLE stopped being able to measure at all,
      # and calling that a failure would claim a measurement nobody has: it is
      # worth 2, the same precedence run-all.sh uses. Matching '^BROKE ' for both
      # put every unmeasurable transition in the failing bucket.
      grep -qE '^BROKE [A-Z]+->FAIL ' <<<"$out" && CHAIN_BROKE=1
      grep -qE '^BROKE [A-Z]+->UNMEASURABLE ' <<<"$out" && CHAIN_UNMEAS=1
      grep -q '^VANISHED ' <<<"$out" && CHAIN_UNMEAS=1
    fi
    prev="$now"
  done

  printf '\n== verdict (chain)\n'
  [ "$BASE_OK" -eq 1 ] || printf '  the BASE was not all-green. Anything it was already red about is NOT\n  attributed to a branch above.\n'
  # A gate that stopped being MEASURABLE, or that disappeared from the run
  # altogether, has stopped defending anything - and it is the transition that
  # reads most like a pass, because nothing prints a FAIL. It cannot leave the
  # verdict at 0.
  [ "$CHAIN_UNMEAS" -eq 1 ] && [ "$RC" -ne 1 ] && RC=2
  if [ "$CHAIN_BROKE" -eq 1 ]; then
    RC=1
    printf '  1 (measured: a merge in this order BREAKS something, named above, and no\n'
    printf '     single branch would have said so)\n'
  elif [ "$RC" -eq 2 ]; then
    printf '  2 (COULD NOT MEASURE the whole chain - this is not a pass)\n'
  else
    printf '  0 (measured: every point in this order holds what the base held)\n'
  fi
  exit "$RC"
fi

printf '\n== merging\n'
CONFLICTS=0 MERGED=0
for b in "${BRANCHES[@]}"; do
  if ! git -C "$ROOT" rev-parse -q --verify "$b" >/dev/null 2>&1; then
    printf '  UNRESOLVED  %-44s this ref does not exist\n' "$b"
    CONFLICTS=$((CONFLICTS + 1)); continue
  fi
  if git -C "$WT/tree" "${GIT_ID[@]}" merge --no-edit -q "$b" >"$WT/merge.log" 2>&1; then
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
      UNIONED="$UNIONED $f"
    else
      union_ok=0; break
    fi
  done <<<"$conflicted"

  if [ "$union_ok" -eq 1 ] && git -C "$WT/tree" "${GIT_ID[@]}" commit --no-edit -q >/dev/null 2>&1; then
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

# A union resolution keeps BOTH sides of every conflicting hunk. That is what a
# person would write when two branches each append a row to the same table, and
# it is wrong when both carry the SAME row with different text - the result has
# the row twice, saying two things. Nothing here can tell those apart, and a
# green measured on such a tree is true about the gates and false about the tree
# anybody will ship. Measured the hard way: this tool reported rc=0 on a tree
# with two duplicated rows, and the report was read as "the combination is fine".
if [ -n "$UNIONED" ]; then
  printf '\n  RESOLVED BY UNION, and not by anybody: %s\n' "$(printf '%s' "$UNIONED" | tr ' ' '\n' | sort -u | tr '\n' ' ')"
  printf '  Every conflicting hunk in those files kept BOTH sides. Right where two\n'
  printf '  branches each ADD something; wrong where both change the same line, which\n'
  printf '  leaves it present twice. This verdict is about the GATES over that tree,\n'
  printf '  not about those resolutions being the ones you would have written.\n'
  printf '  Read the diff of those files before trusting a green here.\n'
fi
case "$RC" in
  0) printf '  0 (measured: the combination is green)\n' ;;
  1) printf '  1 (measured: the combination FAILS - and no single branch would have said so)\n' ;;
  *) printf '  2 (COULD NOT MEASURE the whole combination - this is not a pass)\n' ;;
esac
exit "$RC"
