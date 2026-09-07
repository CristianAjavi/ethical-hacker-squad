#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Proves gate-checks-ran.sh in the negative.
#
# The gate's whole job is to tell three states apart that GitHub renders
# identically as an empty check list:
#
#   * a pull request that produced no run and should have          -> rc 1
#   * a pull request pushed a moment ago whose runs do not exist yet -> rc 0
#   * a read that failed, so the count of runs is not zero but unknown -> rc 2
#
# Collapse any two of those and the gate becomes worse than nothing: it would
# either accuse every fresh push, or certify a silence it never measured. Every
# case below exists because one specific collapse is cheap to write by accident.
#
# There is a FOURTH state, and it is the one that reads most like calm: a pull
# request with a full green check list none of whose runs is the workflow that
# gates the change. Measured on this repository the day it was added: 3 of 24
# open pull requests had no CI run, and the gate as first written caught 1 - the
# only one with no run whatsoever. The cases from 16 on are about that state,
# and about the declaration the requirement is read from, which can go stale in
# both directions.
#
# The gate is driven through a `gh` double on PATH, so the code under test is
# the gate's real parsing and its real control flow - not a second
# implementation that happens to agree with it.
#
# EXIT CODES: 0 every case behaved / 1 a case did not / 2 could not run
# ---------------------------------------------------------------------------
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GATE="$HERE/gate-checks-ran.sh"
[ -r "$GATE" ] || { echo "  COULD NOT MEASURE: $GATE is missing (rc 2)"; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "  COULD NOT MEASURE: the gate needs jq and so does this test (rc 2)"; exit 2; }

LAB="$(mktemp -d)"; trap 'rm -rf "$LAB"' EXIT
mkdir -p "$LAB/bin"
REPO="acme/widget"

# An instant N minutes in the past, in the spelling the GitHub API uses. Both
# date(1) dialects are tried; if neither answers the test says so instead of
# quietly testing 1970.
ago() {
  local m="$1" out
  out="$(date -u -v-"${m}"M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" && { printf '%s' "$out"; return 0; }
  out="$(date -u -d "${m} minutes ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" && { printf '%s' "$out"; return 0; }
  return 1
}
OLD="$(ago 90)"  || { echo "  COULD NOT MEASURE: neither date(1) dialect produced a timestamp (rc 2)"; exit 2; }
NEW="$(ago 1)"   || { echo "  COULD NOT MEASURE: neither date(1) dialect produced a timestamp (rc 2)"; exit 2; }

# --- the gh double ---------------------------------------------------------
# Answers exactly the four calls the gate makes, from files the cases rewrite.
# Every exit code is a file too, so "this read failed" is a fixture and not a
# separate code path.
cat > "$LAB/bin/gh" <<'SH'
#!/bin/sh
lab="$LAB_DIR"
rc_of() { [ -r "$lab/$1" ] && cat "$lab/$1" || echo 0; }
case "$1" in
  auth) exit "$(rc_of auth_rc)" ;;
  pr)
    rc="$(rc_of list_rc)"; [ "$rc" -eq 0 ] || exit "$rc"
    cat "$lab/prs.tsv"; exit 0 ;;
  api)
    path="$2"
    case "$path" in
      */actions/runs*)
        # The gate asks for `.total_count, (.workflow_runs[].name)`: the count on
        # the first line, then one name per line. The double answers in that
        # shape so the code under test is the gate's real parsing.
        rc="$(rc_of runs_rc)"; [ "$rc" -eq 0 ] || exit "$rc"
        sha="${path##*head_sha=}"; sha="${sha%%&*}"
        awk -F'\t' -v s="$sha" '$1==s {print $2; if ($3 != "") {n=split($3, a, "|"); for (i=1; i<=n; i++) print a[i]} found=1}
                                END{if(!found) print "0"}' "$lab/runs.tsv"
        exit 0 ;;
      */commits/*)
        rc="$(rc_of dates_rc)"; [ "$rc" -eq 0 ] || exit "$rc"
        sha="${path##*/commits/}"
        awk -v s="$sha" '$1==s {print $2; found=1} END{if(!found) exit 1}' "$lab/dates.tsv"
        exit $? ;;
      *)
        rc="$(rc_of repo_rc)"; [ "$rc" -eq 0 ] || exit "$rc"
        cat "$lab/repo_name"; exit 0 ;;
    esac ;;
esac
exit 1
SH
chmod +x "$LAB/bin/gh"

# --- the toy repository ------------------------------------------------------
# The gate reads its requirement from a declaration in the tree and confirms
# every declared name against the workflow files, so the tree is a fixture too.
# Two workflows, both triggered by pull_request, both required - the shape this
# repository actually has.
ROOT="$LAB/root"
WF="$ROOT/.github/workflows"
DECL="$ROOT/scripts/gates/data/required-workflows.json"
DEFAULT_NAMES='CI|PR-context gates'

wf_file() {  # path name pull_request(yes/no)
  mkdir -p "$WF"
  { printf 'name: %s\n' "$2"
    printf 'on:\n'
    [ "$3" = yes ] && printf '  pull_request:\n    branches: [main]\n'
    printf '  workflow_dispatch:\njobs:\n  a:\n    runs-on: ubuntu-latest\n    steps: []\n'
  } > "$WF/$1"
}

declare_required() {  # each argument is a required workflow name
  mkdir -p "$(dirname "$DECL")"
  { printf '{"required":['
    local first=1 w
    for w in "$@"; do
      [ "$first" -eq 1 ] || printf ','
      first=0
      printf '{"workflow":"%s","why":"a fixture"}' "$w"
    done
    printf '],"not_required":[]}'
  } > "$DECL"
}

exempt_workflow() {  # name - moves it to not_required with a reason
  local w="$1"
  jq --arg w "$w" '.required |= map(select(.workflow != $w))
                 | .not_required += [{"workflow":$w,"why":"a fixture exemption"}]' \
     "$DECL" > "$DECL.new" && mv "$DECL.new" "$DECL"
}

# --- fixture helpers -------------------------------------------------------
reset() {
  printf '%s' "$REPO" > "$LAB/repo_name"
  : > "$LAB/prs.tsv"; : > "$LAB/runs.tsv"; : > "$LAB/dates.tsv"
  for f in auth_rc list_rc runs_rc dates_rc repo_rc; do echo 0 > "$LAB/$f"; done
  rm -rf "$ROOT"
  wf_file ci.yml 'CI' yes
  wf_file issue-closure-gate.yml 'PR-context gates' yes
  wf_file scorecard.yml 'Scorecard (measurement)' no
  declare_required 'CI' 'PR-context gates'
}
add_pr() {  # number sha mergeable draft title
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" >> "$LAB/prs.tsv"
}
# set_runs <sha> <count> [names, pipe separated]
# The names default to every required workflow, so a case that only cares about
# "this pull request has its runs" keeps saying exactly that and nothing more.
set_runs() { printf '%s\t%s\t%s\n' "$1" "$2" "${3-$DEFAULT_NAMES}" >> "$LAB/runs.tsv"; }
set_date() { printf '%s\t%s\n' "$1" "$2" >> "$LAB/dates.tsv"; }

pass=0; fails=0
run_case() {  # name want_rc needle absent
  local name="$1" want="$2" needle="$3" absent="${4:-}" out rc bad=""
  out="$(env PATH="$LAB/bin:$PATH" LAB_DIR="$LAB" EHS_CHECKS_REPO="$REPO" \
             EHS_REPO_ROOT="$ROOT" EHS_CHECKS_GRACE_MIN=10 bash "$GATE" 2>&1)"; rc=$?
  [ "$rc" -eq "$want" ] || bad="rc=$rc, expected $want"
  if [ -n "$needle" ] && ! printf '%s' "$out" | grep -qi -- "$needle"; then
    bad="${bad:+$bad; }it never said '$needle'"
  fi
  if [ -n "$absent" ] && printf '%s' "$out" | grep -qi -- "$absent"; then
    bad="${bad:+$bad; }it said '$absent' and must not"
  fi
  if [ -z "$bad" ]; then
    printf '  [self-test OK]   %-52s rc=%s\n' "$name" "$rc"; pass=$((pass + 1))
  else
    printf '  [self-test FAIL] %-52s %s\n' "$name" "$bad"
    printf '%s\n' "$out" | sed 's/^/      /'; fails=$((fails + 1))
  fi
}

# 1. Baseline. Without it rc 0 is unreachable and the gate has stopped being a
#    measurement: a check that can only fail is a check nobody keeps.
reset
add_pr 1 aaa MERGEABLE false "a normal pull request"
add_pr 2 bbb MERGEABLE true  "a draft, which still gets runs"
add_pr 3 ccc CONFLICTING false "in conflict but its runs exist from before"
set_runs aaa 7; set_runs bbb 4; set_runs ccc 2
run_case "every open PR has a verdict -> passes" 0 "every one has all 2 required"

# 2. THE DEFECT THIS GATE WAS WRITTEN FOR. A pull request opened already in
#    conflict starts nothing at all, and an empty check list reads as calm.
reset
add_pr 1 aaa MERGEABLE false "a normal pull request"
add_pr 2 ddd CONFLICTING false "opened before its base moved"
set_runs aaa 7; set_runs ddd 0
set_date ddd "$OLD"
run_case "a conflicted PR with no run at all -> fails" 1 "#2"

# 3. The diagnosis has to name the conflict, not just the absence. Without the
#    cause the reader looks at the workflow triggers, which are innocent.
run_case "and it says the conflict is why nothing ran" 1 "no merge ref"

# 4. The same silence with a clean merge is a DIFFERENT bug - a trigger that
#    does not fire - and must not be reported as a conflict.
reset
add_pr 1 aaa MERGEABLE false "a normal pull request"
add_pr 2 eee MERGEABLE false "merges clean and still ran nothing"
set_runs aaa 7; set_runs eee 0
set_date eee "$OLD"
run_case "clean merge and no run -> blames the trigger, not a conflict" 1 "NOT a conflict"

# 5. THE FALSE POSITIVE THAT WOULD GET THIS GATE DELETED. GitHub creates the
#    runs a moment after the push, so a zero on a fresh head is not yet a fact.
reset
add_pr 1 aaa MERGEABLE false "a normal pull request"
add_pr 2 fff MERGEABLE false "pushed one minute ago"
set_runs aaa 7; set_runs fff 0
set_date fff "$NEW"
run_case "a head pushed a minute ago is excluded, not accused" 0 "too young"

# 6. But an exclusion is not a measurement. If EVERY open pull request is inside
#    the window the gate judged nobody, and a population of nobody is not a
#    clean sweep.
reset
add_pr 1 fff MERGEABLE false "pushed one minute ago"
set_runs fff 0
set_date fff "$NEW"
run_case "nothing left to judge -> 2, never a pass" 2 "nothing was judged"

# 7. An unreadable count is not a zero. Reporting 1 here would accuse a pull
#    request on the strength of a failed HTTP call.
reset
add_pr 1 aaa MERGEABLE false "a normal pull request"
set_runs aaa 5
echo 22 > "$LAB/runs_rc"
run_case "the runs endpoint fails -> 2, not 0 and not 1" 2 "could not be read"

# 8. Nor is a non-numeric answer. `total_count` absent from the JSON yields an
#    empty string, and an empty string compares equal to nothing safely.
reset
add_pr 1 aaa MERGEABLE false "a normal pull request"
set_runs aaa "null"
run_case "total_count is not a number -> 2" 2 "not a count"

# 9. A head with no run whose date will not read cannot be told from a push of a
#    second ago. That is the exact ambiguity the grace window exists to resolve.
reset
add_pr 1 ggg MERGEABLE false "no run and no date"
set_runs ggg 0
echo 9 > "$LAB/dates_rc"
run_case "the commit date fails to read -> 2" 2 "cannot be told from a push"

# 10. An empty list from the wrong repository is the failure that looks most like
#     success: rc 0, no output, nothing to report. The probe exists for it.
reset
printf '%s' "other/repo" > "$LAB/repo_name"
run_case "the probe answers for another repository -> 2" 2 "different repository"

# 11. And when the probe itself does not answer.
reset
echo 4 > "$LAB/repo_rc"
run_case "the repository probe does not answer -> 2" 2 "would prove nothing"

# 12. An unauthenticated gh reads every list as empty, which is a clean sweep
#     spelled exactly like a broken one.
reset
echo 1 > "$LAB/auth_rc"
run_case "gh not authenticated -> 2" 2 "not authenticated"

# 13. Listing the pull requests can fail on its own.
reset
echo 3 > "$LAB/list_rc"
run_case "listing the open pull requests fails -> 2" 2 "failed"

# 14. A repository with genuinely no open pull request passes, and says the
#     sweep was empty rather than implying it inspected something.
reset
run_case "no open pull request at all -> passes, and says so" 0 "no open pull request"

# 15. The grace window has to be a number. A typo that makes it empty would
#     compare as a string and exclude everything forever.
reset
add_pr 1 aaa MERGEABLE false "a normal pull request"
set_runs aaa 5
out="$(env PATH="$LAB/bin:$PATH" LAB_DIR="$LAB" EHS_CHECKS_REPO="$REPO" \
           EHS_REPO_ROOT="$ROOT" EHS_CHECKS_GRACE_MIN="ten" bash "$GATE" 2>&1)"; rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -qi 'whole number'; then
  printf '  [self-test OK]   %-52s rc=%s\n' "a non-numeric grace window -> 2" "$rc"; pass=$((pass + 1))
else
  printf '  [self-test FAIL] %-52s rc=%s\n' "a non-numeric grace window -> 2" "$rc"
  printf '%s\n' "$out" | sed 's/^/      /'; fails=$((fails + 1))
fi

# --- the fourth state: a full check list that measures nothing --------------

# 16. THE DEFECT OF 2026-09-07. Nineteen green checks and the workflow that runs
#     the gates never started. "At least one run" is satisfied by a workflow
#     that measures none of the things the required one measures.
reset
add_pr 1 aaa MERGEABLE false "a normal pull request"
add_pr 2 fff MERGEABLE false "green, and CI never ran on it"
set_runs aaa 6
set_runs fff 1 'PR-context gates'
set_date fff "$OLD"
run_case "runs, but not the required one -> fails" 1 "#2"

# 17. And it names the workflow that is missing. Without the name the reader has
#     a red gate and a list of nineteen green checks to stare at.
run_case "and it names the workflow that never ran" 1 "'CI'"

# 18. The two silences are DIFFERENT defects and must not be reported as one:
#     there the check list is empty, here it is full. A pull request with runs
#     must never be described as having none.
run_case "and it does not call a full check list an empty one" 1 "runs but not the required" "NO workflow run at all"

# 19. The grace window covers this state too. GitHub creates the runs one after
#     another, so a push of a moment ago can legitimately have one and not yet
#     the next - and accusing it would make the gate unusable on a live branch.
reset
add_pr 1 aaa MERGEABLE false "a normal pull request"
add_pr 2 ggg MERGEABLE false "pushed a moment ago, CI still being created"
set_runs aaa 6
set_runs ggg 1 'PR-context gates'
set_date ggg "$NEW"
run_case "a fresh push missing a workflow is excluded, not accused" 0 "under the 10 min window"

# 20. Names are matched whole. A required 'CI' must not be satisfied by a run
#     called 'CI extra' - substring matching is the cheapest way to write this
#     and it would certify a workflow that does not exist.
reset
add_pr 1 hhh MERGEABLE false "a run whose name merely contains the required one"
set_runs hhh 2 'CI extra|PR-context gates'
set_date hhh "$OLD"
run_case "a name that only contains the required one does not count" 1 "'CI'"

# 21. Both defects at once, each with its own tally and its own sentence. A gate
#     that folded them together would give a right exit code with half a
#     diagnosis.
reset
add_pr 1 iii CONFLICTING false "no run at all"
add_pr 2 jjj MERGEABLE false "runs, but not CI"
set_runs iii 0
set_runs jjj 1 'PR-context gates'
set_date iii "$OLD"; set_date jjj "$OLD"
run_case "one of each -> both are reported, separately" 1 "1 of 2 open pull requests have NO workflow run"
run_case "and the second is reported as its own kind" 1 "1 of 2 open pull requests have runs but not"

# --- the declaration, which can go stale in both directions -----------------

# 22. A required name that matches no workflow. Left unchecked every open pull
#     request is accused of missing it: a true exit code with the wrong reason,
#     and the fix would be applied to twenty-four innocent branches.
reset
declare_required 'CI' 'Nightly smoke'
add_pr 1 aaa MERGEABLE false "a normal pull request"
set_runs aaa 6
run_case "a required name no workflow answers to -> 2, not 24 accusations" 2 "match no workflow"

# 23. And it says which name, and that the declaration is what to fix.
run_case "and it names the ghost and points at the declaration" 2 "Nightly smoke"

# 24. The other direction: a workflow that runs on pull requests and appears in
#     neither list. It gates changes and nothing asks whether it ran.
reset
wf_file nightly.yml 'Nightly smoke' yes
add_pr 1 aaa MERGEABLE false "a normal pull request"
set_runs aaa 6
run_case "a pull_request workflow in neither list -> fails" 1 "neither list"

# 25. An exemption is honoured, and it is what keeps case 24 from being a rule
#     nobody can satisfy. An optional workflow belongs in not_required WITH a
#     reason, and then its absence is not a finding.
reset
wf_file nightly.yml 'Nightly smoke' yes
declare_required 'CI' 'PR-context gates' 'Nightly smoke'
exempt_workflow 'Nightly smoke'
add_pr 1 aaa MERGEABLE false "a normal pull request"
set_runs aaa 6
run_case "an exempt workflow is not required and not a finding" 0 "every one has all 2 required"

# 26. No declaration at all. Silently requiring nothing would make every pull
#     request pass for the reason that nothing was asked of it.
reset
rm -f "$DECL"
add_pr 1 aaa MERGEABLE false "a normal pull request"
set_runs aaa 6
run_case "no declaration -> 2, never an empty requirement" 2 "no requirement is not a clean sweep"

# 27. A declaration that requires nothing is the same hole written by hand.
reset
printf '{"required":[],"not_required":[]}' > "$DECL"
add_pr 1 aaa MERGEABLE false "a normal pull request"
set_runs aaa 6
run_case "a declaration requiring nothing -> 2" 2 "declares no required workflow"

# 28. A workflow whose `on:` block the reader cannot place. Answering "no
#     pull_request trigger" there is how a required workflow stops being
#     required without anybody deciding it.
reset
printf 'name: Flow style\non: [pull_request]\njobs: {}\n' > "$WF/flow.yml"
add_pr 1 aaa MERGEABLE false "a normal pull request"
set_runs aaa 6
run_case "an unreadable on: block -> 2, not a silent no" 2 "not understood"

# 29. A pull_request workflow with no `name:`. GitHub reports it by path, so no
#     declaration can name it and the requirement could never be stated.
reset
printf 'on:\n  pull_request:\njobs: {}\n' > "$WF/unnamed.yml"
add_pr 1 aaa MERGEABLE false "a normal pull request"
set_runs aaa 6
run_case "a pull_request workflow with no name: -> 2" 2 "no \`name:\`"

# 30. One page of names is a prefix. If a required workflow is NOT among the
#     hundred that were read, its absence is not a fact.
reset
add_pr 1 kkk MERGEABLE false "a very busy head commit"
set_runs kkk 150 'PR-context gates'
set_date kkk "$OLD"
run_case "over a page of runs and a name not seen -> 2" 2 "a prefix cannot establish"

# 31. ...and the same truncation does NOT stop a verdict when every required
#     name was found. Truncation can hide an absence, never a presence, and a
#     gate that went unmeasurable on any busy pull request would be turned off.
reset
add_pr 1 lll MERGEABLE false "just as busy, and CI is right there"
set_runs lll 150
run_case "over a page of runs with every required name found -> passes" 0 "every one has all 2 required"

# 32. An `on:` block whose events sit at an indentation the reader cannot place.
#     This case exists because a probe caught the reader answering "no, parsed
#     fine" to `on:` followed by a SIX-space `pull_request:` - a silent no is
#     how a required workflow stops being required.
reset
printf 'name: Odd indent\non:\n      pull_request:\njobs: {}\n' > "$WF/odd.yml"
add_pr 1 aaa MERGEABLE false "a normal pull request"
set_runs aaa 6
run_case "an on: block indented oddly -> 2, not a silent no" 2 "not understood"

# 33. `pull_request_target` is a DIFFERENT trigger: it runs against the base, with
#     the base's secrets, and it is not what gates a pull request's own code.
#     Counting it as pull_request would demand a declaration entry for a workflow
#     that never judges the change.
reset
printf 'name: Target only\non:\n  pull_request_target:\n    types: [opened]\njobs: {}\n' > "$WF/target.yml"
add_pr 1 aaa MERGEABLE false "a normal pull request"
set_runs aaa 6
run_case "pull_request_target is not pull_request -> passes" 0 "every one has all 2 required"

printf '\n  %d PASS / %d FAIL\n' "$pass" "$fails"
[ "$fails" -eq 0 ] || exit 1
exit 0
