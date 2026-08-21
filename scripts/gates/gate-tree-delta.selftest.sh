#!/usr/bin/env bash
# Self-test for gate-tree-delta.sh, on throwaway repositories built here rather
# than on this one: a delta gate can only be exercised by making a delta.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-tree-delta.sh"
command -v git >/dev/null 2>&1 || { echo "UNMEASURABLE git is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-tree-delta-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# build_repo <dir> — a minimal served tree on a `main` branch
build_repo() {
  local d="$1"
  mkdir -p "$d/skills/x" "$d/agents"
  head -c 20000 /dev/zero | tr '\0' 'a' > "$d/skills/x/pack.md"
  printf 'agent\n' > "$d/agents/a.md"
  git -C "$d" init -q -b main
  git -C "$d" -c user.email=t@e -c user.name=t add -A
  git -C "$d" -c user.email=t@e -c user.name=t commit -qm base
}

# case <name> <expected rc> <needle> <branch> <bytes to add>
case_run() {
  local name="$1" want="$2" needle="$3" branch="$4" add="$5"
  local d="$TMP/$name"; rm -rf "$d"; mkdir -p "$d"
  build_repo "$d"
  git -C "$d" checkout -q -b "$branch"
  if [ "$add" -gt 0 ]; then
    head -c "$add" /dev/zero | tr '\0' 'b' > "$d/skills/x/added.md"
  elif [ "$add" -lt 0 ]; then
    rm "$d/skills/x/pack.md"
  else
    printf 'note\n' >> "$d/agents/a.md"
  fi
  git -C "$d" -c user.email=t@e -c user.name=t add -A
  git -C "$d" -c user.email=t@e -c user.name=t commit -qm change
  local out rc
  out="$(EHS_REPO_ROOT="$d" EHS_BASE_REF=main GITHUB_HEAD_REF="$branch" bash "$GATE" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf 'ok       %-32s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-32s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -5; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-tree-delta.sh ==="
case_run small-growth-passes        0 "within the"        feat/small     1000
case_run human-budget-exceeded      1 "over the"          feat/big       70000
case_run bot-budget-exceeded        1 "bot branch"        bot/knowledge  20000
case_run bot-small-growth-passes    0 "bot branch"        bot/small      1000
case_run deletion-is-not-a-failure  0 "shrank"            feat/delete    -1

# unmeasurable: a repository whose base ref does not exist
d="$TMP/no-base"; mkdir -p "$d"; build_repo "$d"
out="$(EHS_REPO_ROOT="$d" EHS_BASE_REF=origin/does-not-exist bash "$GATE" 2>&1)"; rc=$?
if [ "$rc" -eq 2 ]; then printf 'ok       %-32s rc=2\n' base-ref-unreachable; pass=$((pass+1))
else printf 'FAILED   %-32s rc=%s (wanted 2)\n' base-ref-unreachable "$rc"; fail=$((fail+1)); fi

# unmeasurable: not a git work tree at all
d="$TMP/not-git"; mkdir -p "$d/skills"; printf 'x\n' > "$d/skills/f.md"
out="$(EHS_REPO_ROOT="$d" bash "$GATE" 2>&1)"; rc=$?
if [ "$rc" -eq 2 ]; then printf 'ok       %-32s rc=2\n' not-a-git-worktree; pass=$((pass+1))
else printf 'FAILED   %-32s rc=%s (wanted 2)\n' not-a-git-worktree "$rc"; fail=$((fail+1)); fi

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. The gate measures growth, respects the bot budget, ignores deletions,"
echo "        and reports could-not-measure instead of guessing."
exit 0
