#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-checks-ran.sh - did the checks on every open pull request actually run?
#
# WHY THIS EXISTS, and it is not a hypothetical.
#   On 2026-09-06 pull request #100 was opened on this repository and produced
#   ZERO workflow runs. Not a failing one, not a queued one - none. Eighteen of
#   the twenty open pull requests had at least one; that one had nothing, and
#   nothing in this repository noticed for as long as it took to go looking by
#   hand.
#
#   The cause is ordinary and will happen again. GitHub builds a `pull_request`
#   event from the MERGE of head into base. When that merge does not exist -
#   the pull request was opened already in conflict - there is no ref to check
#   out and NO workflow starts. Not the ones filtered by base branch, not the
#   unfiltered ones either. The pull request page then shows an empty check
#   list, and an empty check list is what a brand-new pull request shows, what a
#   pull request whose runs are still being created shows, and what a reviewer
#   who has stopped reading names reads as "nothing is failing".
#
#   That is this repository's own exit-code doctrine broken one level up.
#   scripts/gates/lib/common.sh says rc 2 means COULD NOT MEASURE and is never a
#   pass. Every gate honours it about its own subject. None of them, and nothing
#   in CI, honoured it about the measurement itself: a suite that never ran
#   looked exactly like a suite with nothing to say.
#
#   The same silence has a second shape, found on 2026-09-07 and measured before
#   it was fixed. Pull request #105 produced runs - `gh pr checks` listed
#   NINETEEN, all green but the one expected red - and the CI workflow, which is
#   the one that runs the gates, the battery suite, the meter and the hardening
#   scan, had not run at all: ci.yml is filtered to `branches: [main, stable]`
#   and #105 was opened on a stacked branch. Retargeting it to main did not
#   start CI either, because the default `pull_request` types are `opened`,
#   `synchronize` and `reopened` - not `edited`. The pull request had to be
#   closed and reopened.
#
#   Over the 24 open pull requests that day, THREE had no CI run. This gate as
#   first written caught ONE of them: the only one with no run whatsoever. The
#   other two had a run - `PR-context gates`, the workflow with no base filter -
#   and "at least one run" is satisfied by a workflow that measures none of the
#   things CI measures.
#
# WHAT IT MEASURES
#   For every OPEN pull request, whether its head commit produced a run of every
#   REQUIRED workflow, named in scripts/gates/data/required-workflows.json. It
#   does not care whether the runs passed - a red check is a measurement and this
#   gate is content with it. It cares only about the difference between a verdict
#   and no verdict at all.
#
#   The requirement deliberately does NOT depend on the pull request's base. A
#   list derived from each workflow's own `branches:` filter would reproduce the
#   defect's own logic and conclude that a pull request missing CI was never
#   supposed to have it. What gates a change is a property of the repository.
#
#   The declaration is checked in both directions. A required name that matches
#   no workflow file stops the sweep at COULD NOT MEASURE, because accusing all
#   24 pull requests of missing a workflow that was merely renamed is a true
#   exit code with the wrong reason. And a workflow file triggered by
#   `pull_request` that appears in neither list is a finding: a new gating
#   workflow must not be able to arrive unrequired.
#
#   A pull request whose head commit is younger than the grace window is
#   EXCLUDED from the population rather than counted against it: GitHub creates
#   the runs a moment after the push, so a zero there is not yet a fact about the
#   pull request. The exclusions are printed, and if every open pull request is
#   inside the window the gate returns 2, because a population of nobody is not
#   a clean sweep.
#
# EXIT CODES
#   0  measured, every open pull request outside the grace window has a run
#   1  measured, at least one has none - each is named with why
#   2  COULD NOT MEASURE, which is never a pass
#
# KNOBS
#   EHS_CHECKS_REPO       owner/name to sweep (default: $GITHUB_REPOSITORY, else
#                         this repository)
#   EHS_REPO_ROOT         where to read the workflows and the declaration from
#   EHS_CHECKS_GRACE_MIN  minutes a head commit is given before its zero counts
#                         (default 30 - measured: over 124 first runs on this
#                         repository the commit-to-run delay had a median of 8 s
#                         and a MAXIMUM of 706 s, 11.8 min, so 10 would have
#                         accused 2 of them)
#
# WHERE IT RUNS
#   Anywhere a `gh` with read access to the repository exists. Unlike
#   gate-governance-drift.sh it needs no administration scope - open pull
#   requests and workflow runs are readable by the automatic GITHUB_TOKEN with
#   `contents: read` on a public repository - so .github/workflows/checks-ran.yml
#   runs it daily and on demand. It is deliberately NOT a `pull_request` job:
#   the pull request it would accuse is precisely the one where no job runs.
#   Locally scripts/gates/run-all.sh defers it unless EHS_LIVE_REPO is set,
#   because a gate that needs the network must not turn a plane-mode run red.
# ---------------------------------------------------------------------------
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"

GATE="checks-ran"
REPO="${EHS_CHECKS_REPO:-${GITHUB_REPOSITORY:-CristianAjavi/ethical-hacker-squad}}"
GRACE_MIN="${EHS_CHECKS_GRACE_MIN:-30}"

ROOT="$(cd "${EHS_REPO_ROOT:-$(gate_root)}" && pwd -P)"
DECL="$ROOT/scripts/gates/data/required-workflows.json"
WFDIR="$ROOT/.github/workflows"
TRIGGERS="$HERE/lib/workflow-triggers.awk"

gate_header "$GATE"
gate_scope "every OPEN pull request of $REPO has a run of every REQUIRED workflow on its head commit"
gate_out_of_scope "whether those runs passed, and pull requests whose head is under ${GRACE_MIN} min old"

case "$GRACE_MIN" in
  ''|*[!0-9]*) gate_warn "EHS_CHECKS_GRACE_MIN is not a whole number of minutes: '$GRACE_MIN'"; exit "$GATE_UNMEASURABLE" ;;
esac

command -v gh >/dev/null 2>&1 || {
  gate_warn "the gh CLI is not installed, so no pull request can be read"; exit "$GATE_UNMEASURABLE"; }
command -v jq >/dev/null 2>&1 || {
  gate_warn "jq is not installed, and every answer here is JSON"; exit "$GATE_UNMEASURABLE"; }
gh auth status >/dev/null 2>&1 || {
  gate_warn "gh is not authenticated: every read would fail and an empty list would read as a clean sweep"; exit "$GATE_UNMEASURABLE"; }

# A positive control before believing an empty list. `gh pr list` answers rc 0
# with nothing at all when the repository is not the one you think it is, and a
# sweep of zero pull requests would then pass for a sweep that found nothing
# wrong. Confirm the repository answers to its own name first.
seen="$(gh api "/repos/$REPO" --jq '.full_name' 2>/dev/null)" || {
  gate_warn "GET /repos/$REPO did not answer, so an empty pull request list would prove nothing"; exit "$GATE_UNMEASURABLE"; }
[ "$seen" = "$REPO" ] || {
  gate_warn "GET /repos/$REPO answered for '$seen': the sweep would be of a different repository"; exit "$GATE_UNMEASURABLE"; }

# --- the declaration, and both directions of it -----------------------------
[ -r "$DECL" ] || {
  gate_warn "$DECL is missing: without a declaration there is no requirement, and no requirement is not a clean sweep"
  exit "$GATE_UNMEASURABLE"; }
REQUIRED="$(jq -r '.required[].workflow' "$DECL" 2>/dev/null)" || {
  gate_warn "$DECL did not parse as the declaration this gate reads"; exit "$GATE_UNMEASURABLE"; }
[ -n "$REQUIRED" ] || {
  gate_warn "$DECL declares no required workflow, so every pull request would pass by having nothing asked of it"
  exit "$GATE_UNMEASURABLE"; }
EXEMPT="$(jq -r '.not_required[]?.workflow' "$DECL" 2>/dev/null)"

[ -d "$WFDIR" ] || {
  gate_warn "$WFDIR is not there, so no required name can be confirmed to exist"; exit "$GATE_UNMEASURABLE"; }
[ -r "$TRIGGERS" ] || {
  gate_warn "$TRIGGERS is missing and the triggers cannot be read"; exit "$GATE_UNMEASURABLE"; }

TRIG="$(mktemp "${TMPDIR:-/tmp}/ehs-checks-trig.XXXXXX")"
trap 'rm -f "$TRIG"' EXIT
# shellcheck disable=SC2046
set -- $(find "$WFDIR" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)
[ "$#" -gt 0 ] || {
  gate_warn "$WFDIR holds no workflow file, so the declaration cannot be checked against anything"
  exit "$GATE_UNMEASURABLE"; }
awk -f "$TRIGGERS" "$@" > "$TRIG" 2>/dev/null || {
  gate_warn "reading the workflow triggers failed"; exit "$GATE_UNMEASURABLE"; }

# A file whose `on:` block the reader could not place is not a file with no
# pull_request trigger. Answering `no` there is how a required workflow stops
# being required without anybody deciding it.
puzzling="$(awk -F'\t' '$4=="unknown" {printf "\n  %s", $1}' "$TRIG")"
if [ -n "$puzzling" ]; then
  gate_warn "the \`on:\` block of these workflows was not understood, and an unread trigger is not an absent one:$puzzling"
  exit "$GATE_UNMEASURABLE"
fi
nameless="$(awk -F'\t' '$2=="" && $3=="yes" {printf "\n  %s", $1}' "$TRIG")"
if [ -n "$nameless" ]; then
  gate_warn "these pull_request workflows have no \`name:\`, so GitHub reports them by path and no declaration can name them:$nameless"
  exit "$GATE_UNMEASURABLE"
fi

# Direction one: a required name that matches no workflow. Left unchecked this
# would accuse every open pull request of missing it, which is a true exit code
# with the wrong reason.
ghost=""
while IFS= read -r w; do
  [ -n "$w" ] || continue
  awk -F'\t' -v w="$w" '$2==w {found=1} END{exit !found}' "$TRIG" || ghost="$ghost
  '$w'"
done <<EOF
$REQUIRED
EOF
if [ -n "$ghost" ]; then
  gate_warn "these names are required but match no workflow in $WFDIR - renamed, or on another branch:$ghost"
  gate_log "  Every open pull request would be accused of missing them. Fix the declaration, not the pull requests."
  exit "$GATE_UNMEASURABLE"
fi

# Direction two: a workflow triggered by pull_request that nobody declared. It
# gates changes and nothing asks whether it ran.
undeclared=""
while IFS=$'\t' read -r wfile wname wpr _; do
  [ "$wpr" = "yes" ] || continue
  printf '%s\n' "$REQUIRED" | grep -qxF -- "$wname" && continue
  printf '%s\n' "$EXEMPT"   | grep -qxF -- "$wname" && continue
  undeclared="$undeclared
  '$wname'  ($wfile)"
done < "$TRIG"
if [ -n "$undeclared" ]; then
  gate_fail "these workflows run on pull requests and appear in neither list of $DECL:$undeclared"
  gate_log "  Add each to \`required\`, or to \`not_required\` with the reason its absence is acceptable."
  exit "$GATE_FAIL"
fi

n_req=$(printf '%s\n' "$REQUIRED" | grep -c .)
gate_info "required on every pull request: $(printf '%s' "$REQUIRED" | tr '\n' ',' | sed 's/,$//;s/,/, /g')"

LIST="$(mktemp "${TMPDIR:-/tmp}/ehs-checks-ran.XXXXXX")"
trap 'rm -f "$LIST" "$TRIG"' EXIT
gh pr list --repo "$REPO" --state open --limit 200 \
  --json number,headRefOid,mergeable,isDraft,title \
  --jq '.[] | [.number, .headRefOid, .mergeable, (.isDraft|tostring), .title] | @tsv' \
  > "$LIST" 2>/dev/null || {
  gate_warn "listing the open pull requests of $REPO failed"; exit "$GATE_UNMEASURABLE"; }

n_open=0; n_judged=0; n_young=0; n_bad=0; n_missing=0
BAD=""; YOUNG=""; MISSING=""
now="$(date -u +%s)"

# `date` parses an ISO-8601 instant differently on BSD and GNU. Both spellings are
# tried and the failure is reported rather than silently becoming 0, which would
# date every commit to 1970 and make the grace window unreachable.
epoch_of() {
  local iso="$1" out
  out="$(date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$iso" +%s 2>/dev/null)" && { printf '%s' "$out"; return 0; }
  out="$(date -u -d "$iso" +%s 2>/dev/null)" && { printf '%s' "$out"; return 0; }
  return 1
}

while IFS=$'\t' read -r num sha mergeable draft title; do
  [ -n "${num:-}" ] || continue
  n_open=$((n_open + 1))
  # One call, two answers: how many runs exist and what they are called. The
  # names are the whole point - "at least one run" is satisfied by a workflow
  # that measures none of the things the required one measures.
  answer="$(gh api "/repos/$REPO/actions/runs?head_sha=$sha&per_page=100" --jq '.total_count, (.workflow_runs[].name)' 2>/dev/null)" || {
    gate_warn "#$num: the workflow runs of $sha could not be read, and an unread run is not an absent one"
    exit "$GATE_UNMEASURABLE"; }
  runs="$(printf '%s\n' "$answer" | head -1)"
  ran_names="$(printf '%s\n' "$answer" | tail -n +2)"
  case "$runs" in
    ''|*[!0-9]*) gate_warn "#$num: total_count came back as '$runs', which is not a count"; exit "$GATE_UNMEASURABLE" ;;
  esac
  missing=""
  if [ "$runs" -gt 0 ]; then
    while IFS= read -r w; do
      [ -n "$w" ] || continue
      printf '%s\n' "$ran_names" | grep -qxF -- "$w" || missing="$missing '$w'"
    done <<EOF
$REQUIRED
EOF
    if [ -z "$missing" ]; then
      n_judged=$((n_judged + 1))
      continue
    fi
    # Only now does one page stop being enough. Truncation cannot hide a name
    # that was already FOUND, so a pull request whose required workflows are all
    # in the first hundred is measured however many runs it has. It is the
    # absence that a prefix cannot prove, and that is exactly this branch.
    if [ "$runs" -gt 100 ]; then
      gate_warn "#$num: $runs runs on $sha, only the first 100 names were read, and$missing is not among them - which a prefix cannot establish"
      exit "$GATE_UNMEASURABLE"
    fi
  fi

  # Either no run at all, or a run of the wrong workflows. Before calling
  # either a fact, ask how old the head commit is - and only here, because the
  # answer changes the verdict only for the suspects. A pull request pushed a
  # moment ago can legitimately have one workflow created and not yet the next.
  when="$(gh api "/repos/$REPO/commits/$sha" --jq '.commit.committer.date' 2>/dev/null)" || {
    gate_warn "#$num: $sha is short of a verdict and its date could not be read, so it cannot be told from a push of a second ago"
    exit "$GATE_UNMEASURABLE"; }
  born="$(epoch_of "$when")" || {
    gate_warn "#$num: the commit date '$when' was not parsed by either date(1) dialect"
    exit "$GATE_UNMEASURABLE"; }
  age_min=$(( (now - born) / 60 ))

  if [ "$age_min" -lt "$GRACE_MIN" ]; then
    n_young=$((n_young + 1))
    YOUNG="$YOUNG
  #$num  pushed ${age_min} min ago, under the ${GRACE_MIN} min window"
    continue
  fi

  n_judged=$((n_judged + 1))

  # A pull request with runs but not the required ones is a DIFFERENT defect
  # from one with no run at all, and it reads differently to whoever fixes it:
  # there, the check list is empty; here, it is full and green. Keeping the two
  # tallies apart is the difference between a right exit code and a right
  # diagnosis.
  if [ "$runs" -gt 0 ]; then
    n_missing=$((n_missing + 1))
    MISSING="$MISSING
  #$num  ${age_min} min old, $runs run(s) on its head and NONE of them:$missing
        $title"
    continue
  fi

  n_bad=$((n_bad + 1))
  why="mergeable=$mergeable"
  case "$mergeable" in
    CONFLICTING) why="it is in CONFLICT, so GitHub has no merge ref to check out and starts nothing" ;;
    UNKNOWN)     why="GitHub has not computed its mergeability, which is also why it started nothing" ;;
    MERGEABLE)   why="it merges cleanly, so the cause is NOT a conflict - look at the workflow triggers" ;;
  esac
  BAD="$BAD
  #$num  ${age_min} min old, draft=$draft, $why
        $title"
done < "$LIST"

if [ -n "$YOUNG" ]; then
  gate_info "excluded as too young to have a verdict yet:$YOUNG"
fi

if [ "$n_open" -eq 0 ]; then
  gate_ok "$REPO has no open pull request; the sweep is empty and the repository answered to its own name"
  exit "$GATE_OK"
fi

if [ "$n_judged" -eq 0 ]; then
  gate_warn "all $n_open open pull requests are inside the ${GRACE_MIN} min window: nothing was judged, and a population of nobody is not a clean sweep"
  exit "$GATE_UNMEASURABLE"
fi

if [ "$n_bad" -gt 0 ] || [ "$n_missing" -gt 0 ]; then
  if [ "$n_bad" -gt 0 ]; then
    gate_fail "$n_bad of $n_judged open pull requests have NO workflow run at all on their head commit:$BAD"
    gate_log "  An empty check list is not a green one. Rebase the branch onto its base, or fix the trigger, and push again so a verdict exists."
  fi
  if [ "$n_missing" -gt 0 ]; then
    gate_fail "$n_missing of $n_judged open pull requests have runs but not the required one(s):$MISSING"
    gate_log "  A full check list is not a measured one either. These read as green and nothing they claim was tested."
  fi
  exit "$GATE_FAIL"
fi

gate_ok "$n_judged of $n_open open pull requests were judged and every one has all $n_req required workflow(s) on its head commit"
exit "$GATE_OK"
