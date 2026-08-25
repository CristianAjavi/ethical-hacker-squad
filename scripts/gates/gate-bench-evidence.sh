#!/usr/bin/env bash
# A run page that cites evidence git will never publish is citing nothing.
#
# WHY THIS EXISTS
#     The instrument round wrote its eight reports to `reports/`, a directory
#     .gitignore has excluded since long before as "local audit output". `git add`
#     said nothing, the commit said "3 files changed", and the published page
#     said "all eight reports in reports/". The evidence was on a laptop and the
#     page claimed it shipped. Nothing failed - which is the problem.
#
# THE RULE
#     No file under bench/runs/ may be ignored. A run directory holding a file
#     git will never publish is a run whose evidence a reader cannot check, and
#     that is the one thing these pages exist to make possible.
#
# Exit codes: 0 = measured, nothing ignored | 1 = measured, ignored evidence |
#             2 = could not measure.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${EHS_REPO_ROOT:-$(cd "$HERE/../.." && pwd)}"
SUBDIR="${EHS_BENCH_RUNS:-bench/runs}"

command -v git >/dev/null 2>&1 || { echo "UNMEASURABLE git is absent: nothing was checked"; exit 2; }
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || {
  echo "UNMEASURABLE $ROOT is not a git work tree: ignore rules cannot be evaluated"; exit 2; }
[ -d "$ROOT/$SUBDIR" ] || { echo "UNMEASURABLE $SUBDIR does not exist under $ROOT"; exit 2; }

ignored="$(git -C "$ROOT" ls-files --others --ignored --exclude-standard -- "$SUBDIR" 2>/dev/null)"

if [ -n "$ignored" ]; then
  n="$(printf '%s\n' "$ignored" | grep -c .)"
  echo "FAIL  $n file(s) under $SUBDIR are ignored: a reader cannot reach evidence a run page cites"
  printf '%s\n' "$ignored" | sed 's/^/        /' | head -20
  [ "$n" -gt 20 ] && echo "        ... and $((n - 20)) more"
  echo "      Either track them or stop citing them. Renaming the directory to one the"
  echo "      other runs use is usually the fix; weakening .gitignore usually is not."
  exit 1
fi

tracked="$(git -C "$ROOT" ls-files -- "$SUBDIR" | grep -c . || true)"
echo "OK    nothing under $SUBDIR is ignored; $tracked file(s) tracked and reachable"
exit 0
