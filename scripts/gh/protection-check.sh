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
#   TWO DEPTHS, and the tool says which one it reached.
#     FULL   - GET .../branches/<b>/protection, which needs ADMIN. Run locally by
#              the maintainer, this compares every declared field.
#     SHALLOW- GET .../branches/<b>, which any token can read, and whose
#              `protected` boolean answers ONE question: is the branch protected
#              at all? That is the question this repository got wrong, so it is
#              worth asking even when the details are out of reach.
#
#   The first draft asked for `permissions: administration: read` on the built-in
#   token. actionlint refuted it in CI: there is no such scope. The available
#   ones are actions, artifact-metadata, attestations, checks, contents,
#   deployments, discussions, id-token, issues, models, packages, pages,
#   pull-requests, repository-projects, security-events and statuses - none of
#   which grants admin. A workflow token therefore CANNOT read a protection
#   block, and the only way to the full comparison is an admin personal access
#   token stored as a secret in a public security repository, which is a larger
#   surface than the problem it solves.
#
#   So the workflow runs SHALLOW and says so. It catches the failure that
#   actually happened - `main` protected by nothing - and never claims the
#   fields it could not read.
#
# THE FIELD TABLE, and why it is a table and not a list of comparisons
#   This tool used to announce "the protection block" as its scope and compare
#   SEVEN normalised fields. `dismiss_stale_reviews: true` was declared in
#   governance.json, was sent in the PUT by apply-governance.sh, and was watched
#   by nothing here: turning it off in the live repository left this check
#   printing "Protection OK". A field that appears in no column passes for
#   approved, and that silence is the defect - not the missing comparison.
#
#   So every key the endpoint returns now has a DESTINATION, and there are only
#   two: compared, or ruled out with the reason written on its line. A key that
#   is in neither column is rc 2 - NOT a pass - because the next field GitHub
#   adds must not enter the same silence this comment describes.
#
#   COMPARED - the 15 normalised fields, the SAME 15 and the same names that
#   apply-governance.sh uses in NORM_FROM_GET. Two tools that compare the same
#   contract must not describe it in two vocabularies.
#     strict              <- required_status_checks.strict
#     contexts            <- required_status_checks.checks, as "context@app_id".
#                            The app pin is policy: an unpinned required check
#                            is satisfiable by any integration with write access
#                            publishing a green status without running anything.
#     pr_required         <- required_pull_request_reviews is present at all
#     approvals           <- required_pull_request_reviews.required_approving_review_count
#     code_owner_review   <- required_pull_request_reviews.require_code_owner_reviews
#     dismiss_stale       <- required_pull_request_reviews.dismiss_stale_reviews
#     last_push_approval  <- required_pull_request_reviews.require_last_push_approval
#     enforce_admins      <- enforce_admins.enabled
#     linear_history      <- required_linear_history.enabled
#     force_pushes        <- allow_force_pushes.enabled
#     deletions           <- allow_deletions.enabled
#     block_creations     <- block_creations.enabled
#     conversation_res    <- required_conversation_resolution.enabled
#     lock_branch         <- lock_branch.enabled
#     fork_syncing        <- allow_fork_syncing.enabled
#
#   NOT COMPARED, each with its reason. This is a ruling, not an omission.
#     url                              the endpoint's own self-link. Not policy.
#     required_signatures              GitHub returns it inside the block, but the
#                                      PUT apply-governance.sh issues cannot set
#                                      it - it lives behind its own endpoint,
#                                      POST/DELETE .../protection/required_signatures
#                                      - and governance.json does not declare it.
#                                      Not in the contract, so there is nothing
#                                      to compare it against.
#     required_status_checks.url       self-link. Not policy.
#     required_status_checks.contexts  the DEPRECATED mirror of `checks` with the
#     required_status_checks.contexts_url  app_id stripped out. Comparing it
#                                      would re-assert the same requirement
#                                      without the pin, which is the one thing
#                                      the pin exists for.
#     required_status_checks.enforcement_level  legacy mirror of enforce_admins,
#                                      which IS compared above.
#     required_pull_request_reviews.url  self-link. Not policy.
#     restrictions                     declared `null` in governance.json and NOT
#                                      returned by this endpoint on a personal
#                                      repository: user/app/team restrictions are
#                                      organization-only. There is no live value
#                                      to compare.
#
# A DECLARED BRANCH THAT DOES NOT EXIST IS `2`, NEVER `0`
#   `stable` does not exist until the first promotion creates it. Reporting that
#   as "fine" would be the exact failure this repository keeps finding: an
#   unmeasured thing reading like a measured one. The same rule covers a live
#   block that is missing a field the contract compares, and a live block that
#   carries a field this table has not ruled on.
#
# Exit codes: 0 = measured, live matches declared | 1 = measured, it does not
#             | 2 = could not measure (no gh, no token, a branch that is absent,
#                   a contract field missing from the live block, or a live field
#                   with no ruling in the table above)
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
    # The whole leading comment block, however long it grows. A fixed line range
    # here silently truncates the field table the day a row is added to it, and
    # a help text that hides half the policy is worse than none.
    -h|--help) awk 'NR>1 && /^#/ {print; next} NR>1 {exit}' "${BASH_SOURCE[0]}"; exit 0 ;;
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

# ---------------------------------------------------------------------------
# THE FIELD TABLE, in executable form. The comment header above explains each
# row; these three lists are what the code actually enforces, so a row that
# exists only in the prose is not a row.
# ---------------------------------------------------------------------------

# Top-level keys of the protection block that feed a compared field.
TOP_COMPARED='required_status_checks required_pull_request_reviews enforce_admins required_linear_history allow_force_pushes allow_deletions block_creations required_conversation_resolution lock_branch allow_fork_syncing'
# Top-level keys deliberately ruled out. See the header for the reason of each.
TOP_RULED_OUT='url required_signatures'
# Keys GitHub always returns for a protected branch. Their ABSENCE is not the
# "off" value, it means the block was not read whole, and that is rc 2.
# required_status_checks and required_pull_request_reviews are NOT here on
# purpose: absent is their legitimate "not configured", which governance.json
# itself declares as `null` for `stable`.
TOP_ALWAYS='enforce_admins required_linear_history allow_force_pushes allow_deletions block_creations required_conversation_resolution lock_branch allow_fork_syncing'
# Nested keys, same two columns.
RSC_COMPARED='strict checks'
RSC_RULED_OUT='url contexts contexts_url enforcement_level'
PRR_COMPARED='dismiss_stale_reviews require_code_owner_reviews require_last_push_approval required_approving_review_count'
PRR_RULED_OUT='url'

printf '\n=== protection-check: %s ===\n' "$REPO"
printf 'SCOPE     : the protection block of every branch declared under `branches`, read live.\n'
printf '            15 fields compared, field by field, against governance.json. Every other key the\n'
printf '            endpoint returns is ruled out BY NAME in the header of this script, with its reason.\n'
printf '            A key in neither column is rc 2, never a pass.\n'
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
    | { strict:             (.required_status_checks.strict // false),
        contexts:           ([ (.required_status_checks.checks // [])[] | "\(.context)@\($app)" ] | sort),
        pr_required:        (.required_pull_request_reviews != null),
        approvals:          (.required_pull_request_reviews.required_approving_review_count // 0),
        code_owner_review:  (.required_pull_request_reviews.require_code_owner_reviews // false),
        dismiss_stale:      (.required_pull_request_reviews.dismiss_stale_reviews // false),
        last_push_approval: (.required_pull_request_reviews.require_last_push_approval // false),
        enforce_admins:     (.enforce_admins // false),
        linear_history:     (.required_linear_history // false),
        force_pushes:       (.allow_force_pushes // false),
        deletions:          (.allow_deletions // false),
        block_creations:    (.block_creations // false),
        conversation_res:   (.required_conversation_resolution // false),
        lock_branch:        (.lock_branch // false),
        fork_syncing:       (.allow_fork_syncing // false) }' "$STATE"
}

# Lists the keys of <object at path> that appear in neither column of the table.
unruled() {  # <json> <jq-path> <known words>
  printf '%s' "$1" | jq -r --arg known "$3" --arg p "$2" '
    ($known | split(" ")) as $k
    | (getpath($p | split(".") | map(select(length > 0))) // {})
    | if type == "object" then keys[] else empty end
    | select(. as $key | ($k | index($key)) | not)'
}

# Returns the normalised protection block, or NOTHING. The exit status of `gh`
# is checked before the body is parsed, and the body is then required to look
# like a protection block. Neither guard is decorative: with a token that may
# not read this endpoint, `gh` prints an ERROR OBJECT on stdout and exits
# non-zero, and piping that straight into jq yields every field at its default -
# an empty context list, every boolean false. That is indistinguishable from a
# branch protected by nothing, and it made this tool report DRIFT against a
# `main` that was correctly protected, on its first real run in a workflow.
# Crying wolf is the one failure this check cannot afford.
#
# THREE ANSWERS, and they travel on stdout because this runs in a command
# substitution - a subshell. An earlier draft set a global from in here and read
# it from the caller: the assignment happened in the subshell, the caller always
# saw it empty, and every unruled field was reported as "the token cannot read
# the block". The battery caught it. A normalised block always starts with `{`,
# so the `PROBLEM ` prefix cannot collide with one.
#   {...}       the normalised block
#   PROBLEM ... it was read, and it cannot be ruled on
#   (empty)     it could not be read at all
live() {  # <branch>
  local raw missing unruled_keys
  raw="$(gh api "repos/$REPO/branches/$1/protection" 2>/dev/null)" || return 0
  printf '%s' "$raw" | jq -e 'has("required_status_checks") or has("enforce_admins") or has("required_pull_request_reviews")' >/dev/null 2>&1 || return 0

  # A contract field that never arrived. Defaulting it to `false` would compare
  # this tool's own default against the declaration and call the result measured.
  missing="$(printf '%s' "$raw" | jq -r --arg need "$TOP_ALWAYS" '
    . as $o | ($need | split(" "))[] | . as $k | select($o | has($k) | not)' | tr '\n' ' ')"
  missing="${missing% }"
  if [ -n "$missing" ]; then
    printf 'PROBLEM the live block is missing field(s) the contract compares: %s' "$missing"
    return 0
  fi

  # A field GitHub returned that nobody has ruled on.
  unruled_keys="$( { unruled "$raw" "" "$TOP_COMPARED $TOP_RULED_OUT"
                     unruled "$raw" "required_status_checks" "$RSC_COMPARED $RSC_RULED_OUT" \
                       | sed 's/^/required_status_checks./'
                     unruled "$raw" "required_pull_request_reviews" "$PRR_COMPARED $PRR_RULED_OUT" \
                       | sed 's/^/required_pull_request_reviews./'; } | tr '\n' ' ')"
  unruled_keys="${unruled_keys% }"
  if [ -n "$unruled_keys" ]; then
    printf 'PROBLEM the live block carries field(s) the table has no ruling on: %s' "$unruled_keys"
    return 0
  fi

  printf '%s' "$raw" | jq -c '
    { strict:             (.required_status_checks.strict // false),
      contexts:           ([ (.required_status_checks.checks // [])[] | "\(.context)@\(.app_id)" ] | sort),
      pr_required:        (.required_pull_request_reviews != null),
      approvals:          (.required_pull_request_reviews.required_approving_review_count // 0),
      code_owner_review:  (.required_pull_request_reviews.require_code_owner_reviews // false),
      dismiss_stale:      (.required_pull_request_reviews.dismiss_stale_reviews // false),
      last_push_approval: (.required_pull_request_reviews.require_last_push_approval // false),
      enforce_admins:     (.enforce_admins.enabled // false),
      linear_history:     (.required_linear_history.enabled // false),
      force_pushes:       (.allow_force_pushes.enabled // false),
      deletions:          (.allow_deletions.enabled // false),
      block_creations:    (.block_creations.enabled // false),
      conversation_res:   (.required_conversation_resolution.enabled // false),
      lock_branch:        (.lock_branch.enabled // false),
      fork_syncing:       (.allow_fork_syncing.enabled // false) }'
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
  case "$have" in
    'PROBLEM '*)
      printf '  COULD NOT MEASURE  %-8s %s\n' "$b" "${have#PROBLEM }"
      printf '                     Rule on it in the field table at the top of scripts/gh/protection-check.sh:\n'
      printf '                     compare it, or write down why it is not compared. Silence is what this check exists to end.\n'
      n_unmeas=$((n_unmeas + 1)); continue ;;
  esac
  if [ -z "$have" ]; then
    # No protection block came back. That is either "there is none" or "this
    # token may not read one", and the two are not the same statement. The
    # `protected` boolean on the branch itself is readable by any token and
    # settles it.
    prot="$(gh api "repos/$REPO/branches/$b" --jq '.protected' 2>/dev/null)"
    case "$prot" in
      false)
        printf '  DRIFT              %-8s is NOT protected at all. Every required check is required by nothing\n' "$b"
        n_drift=$((n_drift + 1)) ;;
      true)
        printf '  COULD NOT MEASURE  %-8s is protected, but this token cannot read the protection block\n' "$b"
        printf '                     (that needs admin; there is no `administration` scope for a workflow token).\n'
        printf '                     Protected-at-all is confirmed; whether it MATCHES the declaration is not.\n'
        n_unmeas=$((n_unmeas + 1)) ;;
      *)
        printf '  COULD NOT MEASURE  %-8s neither the protection block nor the branch could be read\n' "$b"
        n_unmeas=$((n_unmeas + 1)) ;;
    esac
    continue
  fi
  if [ "$want" = "$have" ]; then
    printf '  ok                 %-8s live protection matches the declared one (15 fields compared)\n' "$b"
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
