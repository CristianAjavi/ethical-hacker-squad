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
# WHAT IT MEASURES
#   For every OPEN pull request, whether its head commit produced at least one
#   workflow run. It does not care whether the runs passed - a red check is a
#   measurement and this gate is content with it. It cares only about the
#   difference between a verdict and no verdict at all.
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

gate_header "$GATE"
gate_scope "every OPEN pull request of $REPO has at least one workflow run on its head commit"
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

LIST="$(mktemp "${TMPDIR:-/tmp}/ehs-checks-ran.XXXXXX")"
trap 'rm -f "$LIST"' EXIT
gh pr list --repo "$REPO" --state open --limit 200 \
  --json number,headRefOid,mergeable,isDraft,title \
  --jq '.[] | [.number, .headRefOid, .mergeable, (.isDraft|tostring), .title] | @tsv' \
  > "$LIST" 2>/dev/null || {
  gate_warn "listing the open pull requests of $REPO failed"; exit "$GATE_UNMEASURABLE"; }

n_open=0; n_judged=0; n_young=0; n_bad=0
BAD=""; YOUNG=""
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
  runs="$(gh api "/repos/$REPO/actions/runs?head_sha=$sha&per_page=1" --jq '.total_count' 2>/dev/null)" || {
    gate_warn "#$num: the workflow runs of $sha could not be counted, and an uncounted run is not an absent one"
    exit "$GATE_UNMEASURABLE"; }
  case "$runs" in
    ''|*[!0-9]*) gate_warn "#$num: total_count came back as '$runs', which is not a count"; exit "$GATE_UNMEASURABLE" ;;
  esac

  if [ "$runs" -gt 0 ]; then
    n_judged=$((n_judged + 1))
    continue
  fi

  # Zero runs. Before calling it a fact, ask how old the head commit is - and
  # only here, because the answer changes the verdict only for the suspects.
  when="$(gh api "/repos/$REPO/commits/$sha" --jq '.commit.committer.date' 2>/dev/null)" || {
    gate_warn "#$num: $sha has no run and its date could not be read, so it cannot be told from a push of a second ago"
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

if [ "$n_bad" -gt 0 ]; then
  gate_fail "$n_bad of $n_judged open pull requests have NO workflow run at all on their head commit:$BAD"
  gate_log "  An empty check list is not a green one. Rebase the branch onto its base, or fix the trigger, and push again so a verdict exists."
  exit "$GATE_FAIL"
fi

gate_ok "$n_judged of $n_open open pull requests were judged and every one has a verdict on its head commit"
exit "$GATE_OK"
