#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# NEGATIVE TEST of the step that CHOOSES WHAT GETS PUBLISHED.
#
# The 'Pick the candidate commit' step of .github/workflows/release.yml is
# extracted verbatim from the YAML and run against synthetic git repositories:
# the test runs EXACTLY the code GitHub will run, not a copy that drifts.
#
# WHY THIS STEP. It answers "which tree becomes stable", so every other control
# in the pipeline sits downstream of it. It had a MEASURED hole:
# `git rev-list --before` filters by COMMIT DATE, and the commit date is chosen
# by whoever writes the commit (GIT_COMMITTER_DATE). Without --first-parent the
# walk also descends into merged branches. A knowledge-loop PR carrying a commit
# backdated 8 days and merged today was therefore selected as "already rested",
# with zero real rest -- and that tree had only ever existed inside the PR
# branch, so it was never a state of main and no CI of main ever judged it.
# The fix is --first-parent plus an explicit membership invariant, applied to
# the manual-dispatch path too. These cases keep both alive.
#
# HISTORY OF THIS FILE. It used to test the 'Decide' step of
# .github/workflows/promote-stable.yml, which concentrated cooldown, check runs,
# blocking issues, semver comparison, stable ancestry and tag collision in a
# single script emitting decision=/reason=. That workflow was removed during the
# integration (two workflows were promoting to stable, on the same cron, with
# incompatible version models) and release.yml spreads those checks across
# several steps and gates. The 17 old cases asserted a contract that no longer
# exists, so they were replaced rather than left returning rc=2 forever.
#
# STILL NOT COVERED HERE, said out loud: the check-run evidence by app id, the
# blocking-issue query and the semver comparison are exercised by other steps of
# release.yml that this suite does not extract. The tree-identity gate and the
# fast-forward assertion live in the 'promote' job and are likewise uncovered.
#
# EXIT CODES:  0 all good / 1 there is a hole / 2 I could not run the test
# ---------------------------------------------------------------------------
set -uo pipefail

SP="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SP/../../.." && pwd)"
WF="$ROOT/.github/workflows/release.yml"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
STEP="$WORK/candidate.sh"
PASS=0; FAIL=0

command -v python3 >/dev/null 2>&1 || { echo "  COULD NOT MEASURE: python3 is missing (rc 2)"; exit 2; }
command -v git     >/dev/null 2>&1 || { echo "  COULD NOT MEASURE: git is missing (rc 2)"; exit 2; }
python3 -c 'import yaml' 2>/dev/null || { echo "  COULD NOT MEASURE: PyYAML is missing (rc 2)"; exit 2; }
[ -f "$WF" ] || { echo "  COULD NOT MEASURE: $WF does not exist (rc 2)"; exit 2; }

python3 - "$WF" "$STEP" <<'PY' || exit 2
import sys, pathlib, yaml
d = yaml.safe_load(pathlib.Path(sys.argv[1]).read_text())
for s in d['jobs']['resolve']['steps']:
    if s.get('name') == 'Pick the candidate commit':
        pathlib.Path(sys.argv[2]).write_text(s['run']); break
else:
    sys.exit("cannot find the 'Pick the candidate commit' step in release.yml")
PY

# This git rejects approxidate in GIT_COMMITTER_DATE; it needs ISO 8601.
ago() { date -u -v-"$1"d +%Y-%m-%dT%H:%M:%S+0000 2>/dev/null \
        || date -u -d "$1 days ago" +%Y-%m-%dT%H:%M:%S+0000; }

new_repo() { # new_repo <dir>
  mkdir -p "$1"
  ( cd "$1"
    git init -q -b main
    git config user.email t@t; git config user.name t
    git config commit.gpgsign false )
}

commit() { # commit <repo> <message> <days-old> [file]
  local d; d=$(ago "$3")
  ( cd "$1"
    echo "$2" >> "${4:-marker.txt}"
    git add -A
    GIT_AUTHOR_DATE="$d" GIT_COMMITTER_DATE="$d" git commit -qm "$2" )
}

# 'origin' points at the repo itself: enough to populate refs/remotes/origin/*
sync_origin() {
  ( cd "$1"
    git remote remove origin 2>/dev/null || true
    git remote add origin "$PWD"
    git fetch -q --force origin '+refs/heads/*:refs/remotes/origin/*' )
}

run_step() { # run_step <repo> <soak_days> [input_sha] -> prints "rc|sha"
  local out rc
  : >"$WORK/gh_output"
  out=$( cd "$1" && SOAK_DAYS="$2" INPUT_SHA="${3:-}" \
         GITHUB_OUTPUT="$WORK/gh_output" bash "$STEP" 2>&1 )
  rc=$?
  printf '%s\n' "$out" > "$WORK/last_out"
  printf '%s|%s\n' "$rc" "$(grep '^sha=' "$WORK/gh_output" | tail -1 | cut -d= -f2-)"
}

res() { # res <name> <got> <want>
  if [ "$2" = "$3" ]; then printf '  PASS  %-56s %s\n' "$1" "$2"; PASS=$((PASS+1))
  else printf '  FAIL  %-56s got=%s want=%s\n' "$1" "$2" "$3"
       sed 's/^/        | /' "$WORK/last_out" | tail -8
       FAIL=$((FAIL+1)); fi
}

# --------------------------------------------------------------------------
echo "== The rest window is real time on main, not a date somebody typed"
# main: rested(20d). A side branch carries a commit BACKDATED to 8 days that is
# merged TODAY: the documented way of faking having rested.
LAB="$WORK/lab1"; new_repo "$LAB"
commit "$LAB" "rested" 20
RESTED=$( cd "$LAB"; git rev-parse HEAD )
( cd "$LAB"; git checkout -q -b bot/knowledge-2026-W31 )
commit "$LAB" "backdated-inside-a-branch" 8 corpus.md
BACKDATED=$( cd "$LAB"; git rev-parse HEAD )
( cd "$LAB"; git checkout -q main )
NOW=$(ago 0)
( cd "$LAB"; GIT_AUTHOR_DATE="$NOW" GIT_COMMITTER_DATE="$NOW" \
    git merge -q --no-ff bot/knowledge-2026-W31 -m "Merge knowledge loop" )
sync_origin "$LAB"

R=$(run_step "$LAB" 7); GOT="${R#*|}"
res "the backdated commit is NOT chosen" \
    "$([ "$GOT" = "$BACKDATED" ] && echo chosen || echo rejected)" "rejected"
res "the commit that really rested is chosen" \
    "$([ "$GOT" = "$RESTED" ] && echo yes || echo no)" "yes"

# --------------------------------------------------------------------------
echo ""
echo "== The manual path cannot smuggle in what the automatic one rejects"
R=$(run_step "$LAB" 7 "$BACKDATED")
res "workflow_dispatch with the backdated SHA -> rc 1" "${R%%|*}" "1"
R=$(run_step "$LAB" 7 "$RESTED")
res "workflow_dispatch with a real main commit -> rc 0" "${R%%|*}" "0"

# A commit that only ever lived inside a branch and was NEVER merged.
LAB2="$WORK/lab2"; new_repo "$LAB2"
commit "$LAB2" "base" 30
( cd "$LAB2"; git checkout -q -b side )
commit "$LAB2" "never-merged" 20
ORPHAN=$( cd "$LAB2"; git rev-parse HEAD )
( cd "$LAB2"; git checkout -q main )
commit "$LAB2" "main-moves-on" 15
sync_origin "$LAB2"
R=$(run_step "$LAB2" 7 "$ORPHAN")
res "workflow_dispatch with a commit outside main -> rc 1" "${R%%|*}" "1"

# --------------------------------------------------------------------------
echo ""
echo "== 'Nothing has rested yet' is not 'publish anything'"
LAB3="$WORK/lab3"; new_repo "$LAB3"
commit "$LAB3" "brand-new" 0
sync_origin "$LAB3"
R=$(run_step "$LAB3" 7)
res "every commit younger than the window -> rc 0 and empty sha" "${R%%|*}:${R#*|}" "0:"

# --------------------------------------------------------------------------
echo ""
echo "== The window is honoured, it is not decorative"
LAB4="$WORK/lab4"; new_repo "$LAB4"
commit "$LAB4" "three-days-old" 3
sync_origin "$LAB4"
R=$(run_step "$LAB4" 7)
res "3-day-old commit with a 7-day window -> not eligible" "${R#*|}" ""
R=$(run_step "$LAB4" 1)
res "the same commit with a 1-day window -> eligible" \
    "$([ -n "${R#*|}" ] && echo eligible || echo no)" "eligible"

echo ""
echo "  $PASS PASS / $FAIL FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
