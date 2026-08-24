#!/usr/bin/env bash
# scripts/gh/protection-check.sh
#
# Reads the LIVE branch protection of every branch governance.json declares, and
# compares it against what that file says it should be. Read-only, always.
#
# WHY IT EXISTS
#   apply-governance.sh already compares the whole declared state against the
#   live repository, and it CANNOT run in Actions: it demands that the active gh
#   account be the maintainer's and that the token hold admin. Under the built-in
#   GITHUB_TOKEN neither is true, so that comparison only ever happens when a
#   person runs it by hand - which is why `main` sat with NO protection at all
#   while every gate was green, and the machinery manual said so in prose that
#   nothing executed.
#
#   This is the half of that comparison a workflow can actually do. `permissions:
#   administration: read` on the built-in token is enough to GET a branch's
#   protection, so it needs no personal access token and puts no admin secret
#   into a public repository - which was the other option, and a worse one.
#
# WHAT IT COMPARES, and what it does not
#   Only the protection block of the branches under `branches` in
#   governance.json: required status checks (context AND app id), linear history,
#   force pushes, deletions, conversation resolution, and whether a pull request
#   is required at all. Repository settings, topics, labels and vulnerability
#   alerts are NOT here: reading those needs admin, and pretending otherwise
#   would be a green about something never looked at. apply-governance.sh remains
#   the whole picture; this is the part that can run unattended.
#
# A DECLARED BRANCH THAT DOES NOT EXIST IS `2`, NEVER `0`
#   `stable` does not exist until the first promotion creates it. Reporting that
#   as "fine" would be the exact failure this repository keeps finding: an
#   unmeasured thing reading like a measured one.
#
# Exit codes: 0 = measured, live matches declared | 1 = measured, it does not
#             | 2 = could not measure (no gh, no token, a branch that is absent)
#
# Usage:
#   scripts/gh/protection-check.sh
#   scripts/gh/protection-check.sh --repo OWNER/NAME
#   scripts/gh/protection-check.sh --state path/to/governance.json

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$SELF_DIR/../.." && pwd -P)"
STATE="$ROOT/scripts/gh/governance.json"
REPO=""

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)  REPO="${2:-}"; shift 2 ;;
    --state) STATE="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,40p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) printf 'COULD NOT MEASURE: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done

for t in gh jq; do
  command -v "$t" >/dev/null 2>&1 || { printf 'COULD NOT MEASURE: %s is missing\n' "$t" >&2; exit 2; }
done
[ -r "$STATE" ] || { printf 'COULD NOT MEASURE: cannot read %s\n' "$STATE" >&2; exit 2; }
[ -n "$REPO" ] || REPO="$(jq -r '.repo // empty' "$STATE")"
[ -n "$REPO" ] || { printf 'COULD NOT MEASURE: no repository declared and none given\n' >&2; exit 2; }

APP_ID="$(jq -r '.actions_app_id // empty' "$STATE")"
[ -n "$APP_ID" ] || { printf 'COULD NOT MEASURE: governance.json declares no actions_app_id\n' >&2; exit 2; }

printf '\n=== protection-check: %s ===\n' "$REPO"
printf 'SCOPE     : the protection block of every branch declared under `branches`, read live\n'
printf 'OUT       : repository settings, topics, labels and vulnerability alerts - reading those\n'
printf '            needs admin, which a workflow token does not have. apply-governance.sh is the\n'
printf '            whole picture; this is the part that can run unattended.\n\n'

# The declared shape, normalised. `checks` carries the app id from the global
# policy, exactly as apply-governance.sh injects it before its PUT: a required
# check that is not pinned to the Actions app can be satisfied by any integration
# with write access publishing a green status without running anything.
declared() {  # <branch>
  jq -c --argjson app "$APP_ID" --arg b "$1" '
    .branches[$b].protection
    | { contexts:  ([ (.required_status_checks.checks // [])[] | "\(.context)@\($app)" ] | sort),
        strict:    (.required_status_checks.strict // false),
        linear:    (.required_linear_history // false),
        force:     (.allow_force_pushes // false),
        deletions: (.allow_deletions // false),
        conv_res:  (.required_conversation_resolution // false),
        pr:        (.required_pull_request_reviews != null) }' "$STATE"
}

live() {  # <branch>  -> json, or empty when the branch has no protection
  gh api "repos/$REPO/branches/$1/protection" 2>/dev/null | jq -c '
    { contexts:  ([ (.required_status_checks.checks // [])[] | "\(.context)@\(.app_id)" ] | sort),
      strict:    (.required_status_checks.strict // false),
      linear:    (.required_linear_history.enabled // false),
      force:     (.allow_force_pushes.enabled // false),
      deletions: (.allow_deletions.enabled // false),
      conv_res:  (.required_conversation_resolution.enabled // false),
      pr:        (.required_pull_request_reviews != null) }'
}

BRANCHES="$(jq -r '.branches | keys[]' "$STATE")"
[ -n "$BRANCHES" ] || { printf 'COULD NOT MEASURE: no branch declared under `branches`\n' >&2; exit 2; }

rc=0; n_ok=0; n_drift=0; n_unmeas=0
for b in $BRANCHES; do
  if ! gh api "repos/$REPO/branches/$b" >/dev/null 2>&1; then
    printf '  COULD NOT MEASURE  %-8s the branch does not exist yet, so its protection can be neither verified nor applied\n' "$b"
    n_unmeas=$((n_unmeas + 1)); continue
  fi
  want="$(declared "$b")"
  have="$(live "$b")"
  if [ -z "$have" ]; then
    printf '  DRIFT              %-8s has NO protection at all (GET -> 404). Every required check is required by nothing\n' "$b"
    n_drift=$((n_drift + 1)); continue
  fi
  if [ "$want" = "$have" ]; then
    printf '  ok                 %-8s live protection matches the declared one\n' "$b"
    n_ok=$((n_ok + 1)); continue
  fi
  printf '  DRIFT              %-8s live protection does NOT match the declared one\n' "$b"
  jq -n --argjson w "$want" --argjson h "$have" '
    $w | keys[] as $k | select($w[$k] != $h[$k])
    | "                     \($k): live=\($h[$k]|tostring) declared=\($w[$k]|tostring)"' -r
  n_drift=$((n_drift + 1))
done

printf '\n  branches: ok %d · drift %d · could not measure %d\n' "$n_ok" "$n_drift" "$n_unmeas"
if [ "$n_drift" -gt 0 ]; then
  printf '  Fix with: scripts/gh/apply-governance.sh --apply, run by an account with admin.\n'
  rc=1
elif [ "$n_unmeas" -gt 0 ]; then
  rc=2
fi
case "$rc" in
  0) printf '  VERDICT: 0 (measured, live matches declared)\n' ;;
  1) printf '  VERDICT: 1 (measured, it does not)\n' ;;
  *) printf '  VERDICT: 2 (COULD NOT MEASURE everything - this is not a pass)\n' ;;
esac
exit "$rc"
