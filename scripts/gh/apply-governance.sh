#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# apply-governance.sh - declarative comparator for repository governance.
#
# It reads scripts/gh/governance.json (DESIRED state), reads the REAL state via
# GET from the GitHub API, and reports every difference. With --apply, and only
# with --apply, it mutates. By default it is --dry-run: it touches nothing.
#
# Dual purpose: it is both the applier and the DRIFT GATE. Run without flags it
# answers "does the real governance match the declared one?" with an exit code.
#
# EXIT CODES (doctrine: an rc=0 can never mean "I did not review it")
#   0  I measured everything I declared and it matches (or, with --apply, it was applied).
#   1  I measured and there IS DRIFT / a mutation failed. Real state != desired state.
#   2  I COULD NOT MEASURE some part (gh/jq missing, no session, no admin
#      permission, the stable branch does not exist yet, endpoint unavailable).
#      It never degrades to 0: "I could not check it" is not "it is fine".
#
# Precedence: if something is unmeasured AND something has drifted, 2 wins,
# because the honest verdict is "I do not know the full state".
#
# It runs NO mutation without --apply. It accepts NO tokens as arguments.
# ---------------------------------------------------------------------------
set -Eeuo pipefail

readonly RC_OK=0
readonly RC_DRIFT=1
readonly RC_UNMEASURED=2

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
STATE_FILE="${SCRIPT_DIR}/governance.json"

MODE="dry-run"
ALLOW_UNOBSERVED=0
SKIP_STABLE=0
DISCOVER_ONLY=0
OPT_NO_COLOR=0

# Compatible with bash 3.2 (the only one macOS ships): no ${x,,}, no associative
# arrays, no mapfile.
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# ---------------------------------------------------------------------------
# Presentation
# ---------------------------------------------------------------------------
c_reset=""; c_red=""; c_grn=""; c_yel=""; c_blu=""; c_dim=""
setup_colors() {
  if [[ $OPT_NO_COLOR -eq 1 || ! -t 1 || -n "${NO_COLOR:-}" ]]; then return; fi
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_grn=$'\033[32m'
  c_yel=$'\033[33m'; c_blu=$'\033[34m'; c_dim=$'\033[2m'
}

section() { printf '\n%s== %s%s\n' "$c_blu" "$1" "$c_reset"; }
ok()      { printf '   %sOK%s         %s\n' "$c_grn" "$c_reset" "$1"; N_OK=$((N_OK+1)); }
drift()   { printf '   %sDRIFT%s      %s\n' "$c_red" "$c_reset" "$1"; N_DRIFT=$((N_DRIFT+1)); }
applied() { printf '   %sAPPLIED%s    %s\n' "$c_grn" "$c_reset" "$1"; N_APPLIED=$((N_APPLIED+1)); }
failed()  { printf '   %sFAILED%s     %s\n' "$c_red" "$c_reset" "$1"; N_FAILED=$((N_FAILED+1)); }
unmeas()  { printf '   %sUNMEASURED%s %s\n' "$c_yel" "$c_reset" "$1"; N_UNMEASURED=$((N_UNMEASURED+1)); }
info()    { printf '   %sinfo%s       %s\n' "$c_dim" "$c_reset" "$1"; }
plan()    { printf '   %splan%s       %s\n' "$c_dim" "$c_reset" "$1"; }

N_OK=0; N_DRIFT=0; N_APPLIED=0; N_FAILED=0; N_UNMEASURED=0

fatal() {
  printf '\n%sABORT%s %s\n' "$c_red" "$c_reset" "$1" >&2
  exit "${2:-$RC_UNMEASURED}"
}

usage() {
  cat <<'EOF'
Usage: scripts/gh/apply-governance.sh [options]

  (no options)              DRY-RUN. Compares and reports. Mutates nothing.
  --apply                   Runs the required mutations. Explicit on purpose.
  --dry-run                 Explicit, this is the default.
  --discover-contexts       Only lists the check contexts actually observed in
                            the most recent commits of main. Useful to fill in
                            promotion.required_contexts without guessing. No mutation.
  --allow-unobserved-contexts
                            Allows declaring as required a context that has never
                            been observed. DANGEROUS: a misspelled name leaves main
                            impossible to merge forever.
  --skip-stable             Acknowledges that the stable branch does not exist yet
                            and does not count its absence as "unmeasured".
  --state <path>            Uses another desired-state file (default
                            scripts/gh/governance.json).
  --no-color                No ANSI colors.
  -h, --help                This help.

Exit codes: 0 matches / 1 there is drift or a mutation failed / 2 could not measure.
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)   MODE="apply" ;;
    --dry-run) MODE="dry-run" ;;
    --discover-contexts) DISCOVER_ONLY=1 ;;
    --allow-unobserved-contexts) ALLOW_UNOBSERVED=1 ;;
    --skip-stable) SKIP_STABLE=1 ;;
    --state) STATE_FILE="${2:-}"; shift ;;
    --no-color) OPT_NO_COLOR=1 ;;
    -h|--help) usage; exit "$RC_OK" ;;
    *) usage >&2; fatal "unknown argument: $1" "$RC_UNMEASURED" ;;
  esac
  shift
done
setup_colors

# ---------------------------------------------------------------------------
# Preconditions. Any failure here is rc=2: I cannot measure, not "it is fine".
# ---------------------------------------------------------------------------
command -v gh >/dev/null 2>&1 || fatal "the 'gh' CLI is missing. Without it I can read neither the real nor the desired state."
command -v jq >/dev/null 2>&1 || fatal "'jq' is missing. Without it I cannot compare structures."
[[ -f "$STATE_FILE" ]] || fatal "the desired-state file does not exist: $STATE_FILE"
jq -e . "$STATE_FILE" >/dev/null 2>&1 || fatal "$STATE_FILE is not valid JSON."

STATE="$(cat "$STATE_FILE")"
REPO="$(jq -r '.repo' <<<"$STATE")"
EXPECTED_ACCOUNT="$(jq -r '.expected_account' <<<"$STATE")"
ACTIONS_APP_ID="$(jq -r '.actions_app_id' <<<"$STATE")"
STABLE_BRANCH="$(jq -r '.promotion.stable_branch' <<<"$STATE")"
SOURCE_BRANCH="$(jq -r '.promotion.source_branch' <<<"$STATE")"

[[ "$REPO" == */* ]] || fatal "invalid .repo field in $STATE_FILE: '$REPO'"

MODE_NOTE=""
if [[ "$MODE" == "dry-run" ]]; then MODE_NOTE="(nothing is mutated)"; fi
printf '%s' "$c_dim"
cat <<EOF
repo            : $REPO
desired state   : $STATE_FILE
mode            : $MODE $MODE_NOTE
EOF
printf '%s' "$c_reset"

# --- Identity guard: the active gh account MUST be the expected one ---------
section "gh session identity"
if ! ACTIVE_LOGIN="$(gh api user --jq '.login' 2>/dev/null)"; then
  fatal "there is no usable gh session (gh api user failed). Run: gh auth login"
fi
if [[ "$ACTIVE_LOGIN" != "$EXPECTED_ACCOUNT" ]]; then
  fatal "the ACTIVE gh account is '$ACTIVE_LOGIN' and this repo requires '$EXPECTED_ACCOUNT'.
       This Mac has several gh accounts and pushing/mutating with the wrong one is a
       known and expensive mistake. Fix it with:  gh auth switch --user $EXPECTED_ACCOUNT
       I stop here: I would rather not measure than measure against the wrong identity."
fi
ok "active gh account = $ACTIVE_LOGIN (matches expected_account)"

# --- Access and permissions -------------------------------------------------
if ! REPO_JSON="$(gh api "repos/$REPO" 2>/dev/null)"; then
  fatal "I cannot read repos/$REPO (repo missing, no access, or token without the 'repo' scope)."
fi
IS_ADMIN="$(jq -r '.permissions.admin // false' <<<"$REPO_JSON")"
OWNER_TYPE="$(jq -r '.owner.type' <<<"$REPO_JSON")"
if [[ "$IS_ADMIN" != "true" ]]; then
  fatal "the active token has no ADMIN permission over $REPO. Branch protection and repo
       settings are not even READABLE without admin, so any verdict would be false. rc=2."
fi
ok "admin permission over $REPO (owner.type=$OWNER_TYPE)"
if [[ "$OWNER_TYPE" != "Organization" ]]; then
  info "personal-account repo: 'restrictions' (who can push) is org-only and goes as null."
fi

# ---------------------------------------------------------------------------
# Mutation helper. The ONLY point through which any write passes.
#   run_mutation "<description>" gh <args...>
# ---------------------------------------------------------------------------
run_mutation() {
  local desc="$1"; shift
  if [[ "$MODE" != "apply" ]]; then
    plan "$desc"
    printf '             %s$ %s%s\n' "$c_dim" "$*" "$c_reset"
    return 0
  fi
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?
  if [[ $rc -eq 0 ]]; then
    applied "$desc"
    return 0
  fi
  failed "$desc"
  printf '%s\n' "$out" | sed 's/^/             /' >&2
  return 1
}

# ---------------------------------------------------------------------------
# --discover-contexts: looks at which check runs have actually been observed.
# ---------------------------------------------------------------------------
discover_contexts() {
  section "Check contexts observed on $SOURCE_BRANCH (last 20 commits)"
  local shas
  if ! shas="$(gh api "repos/$REPO/commits?sha=$SOURCE_BRANCH&per_page=20" --jq '.[].sha' 2>/dev/null)"; then
    unmeas "I could not list the commits of $SOURCE_BRANCH"
    return
  fi
  local tmp; tmp="$(mktemp)"
  local sha
  # FD 3 + </dev/null: if 'gh' consumed stdin it would eat the rest of the commit
  # list and the discovery would come out short without saying so.
  while IFS= read -r sha <&3; do
    [[ -n "$sha" ]] || continue
    gh api "repos/$REPO/commits/$sha/check-runs" \
      --jq '.check_runs[] | "\(.name)\t\(.app.id)\t\(.conclusion)"' </dev/null 2>/dev/null >>"$tmp" || true
  done 3<<<"$shas"
  if [[ -s "$tmp" ]]; then
    sort -u "$tmp" | while IFS=$'\t' read -r name appid concl; do
      printf '   %-40s app_id=%-8s conclusion=%s\n' "$name" "$appid" "$concl"
      found=1
    done
  else
    info "no check run observed. There is no CI to report yet, or CI has not run on main."
  fi
  rm -f "$tmp"
}

observed_contexts() {
  # prints, one per line, "name\tapp_id" of the checks seen on main
  local shas sha
  shas="$(gh api "repos/$REPO/commits?sha=$SOURCE_BRANCH&per_page=20" --jq '.[].sha' 2>/dev/null)" || return 1
  while IFS= read -r sha <&3; do
    [[ -n "$sha" ]] || continue
    gh api "repos/$REPO/commits/$sha/check-runs" --jq '.check_runs[] | "\(.name)\t\(.app.id)"' </dev/null 2>/dev/null || true
  done 3<<<"$shas" | sort -u
}

if [[ $DISCOVER_ONLY -eq 1 ]]; then
  discover_contexts
  exit "$RC_OK"
fi

# ---------------------------------------------------------------------------
# 1) BRANCH PROTECTION
#    It is done BEFORE the repo settings on purpose: auto-merge is not a gate
#    but a trigger, and it only shows up when there is already a pending
#    requirement. Enabling allow_auto_merge before declaring the required
#    checks produces instant merges with no gate.
# ---------------------------------------------------------------------------
readonly NORM_FROM_PUT='{
  strict:              (.required_status_checks.strict // false),
  contexts:            ([ (.required_status_checks.checks // [])[] | "\(.context)@\(.app_id // 0)" ] | sort),
  enforce_admins:      (.enforce_admins // false),
  pr_required:         (.required_pull_request_reviews != null),
  approvals:           (.required_pull_request_reviews.required_approving_review_count // 0),
  code_owner_review:   (.required_pull_request_reviews.require_code_owner_reviews // false),
  dismiss_stale:       (.required_pull_request_reviews.dismiss_stale_reviews // false),
  last_push_approval:  (.required_pull_request_reviews.require_last_push_approval // false),
  force_pushes:        (.allow_force_pushes // false),
  deletions:           (.allow_deletions // false),
  linear_history:      (.required_linear_history // false),
  conversation_res:    (.required_conversation_resolution // false),
  lock_branch:         (.lock_branch // false),
  block_creations:     (.block_creations // false),
  fork_syncing:        (.allow_fork_syncing // false)
}'

readonly NORM_FROM_GET='{
  strict:              (.required_status_checks.strict // false),
  contexts:            ([ (.required_status_checks.checks // [])[] | "\(.context)@\(.app_id // 0)" ] | sort),
  enforce_admins:      (.enforce_admins.enabled // false),
  pr_required:         (.required_pull_request_reviews != null),
  approvals:           (.required_pull_request_reviews.required_approving_review_count // 0),
  code_owner_review:   (.required_pull_request_reviews.require_code_owner_reviews // false),
  dismiss_stale:       (.required_pull_request_reviews.dismiss_stale_reviews // false),
  last_push_approval:  (.required_pull_request_reviews.require_last_push_approval // false),
  force_pushes:        (.allow_force_pushes.enabled // false),
  deletions:           (.allow_deletions.enabled // false),
  linear_history:      (.required_linear_history.enabled // false),
  conversation_res:    (.required_conversation_resolution.enabled // false),
  lock_branch:         (.lock_branch.enabled // false),
  block_creations:     (.block_creations.enabled // false),
  fork_syncing:        (.allow_fork_syncing.enabled // false)
}'

# Injects actions_app_id into every required check: the declarative JSON only
# carries the context name, the app_id is global policy and lives in one place.
desired_protection() {
  local branch="$1"
  jq -c --argjson app "$ACTIONS_APP_ID" --arg b "$branch" '
    .branches[$b].protection
    | if .required_status_checks != null
      then .required_status_checks.checks =
             [ .required_status_checks.checks[] | {context: .context, app_id: $app} ]
      else . end
  ' <<<"$STATE"
}

check_branch_exists() {
  gh api "repos/$REPO/branches/$1" --jq '.name' >/dev/null 2>&1
}

# Anti self-DoS safeguard: never declare as required a context that has never
# been seen. A misspelled name leaves main impossible to merge and the Actions
# token is NOT admin, so nobody can unblock it on its own.
verify_contexts_observed() {
  local want="$1"   # newline-separated list of "ctx@appid"
  [[ -z "$want" ]] && return 0
  local obs rc=0
  if ! obs="$(observed_contexts)"; then
    unmeas "I could not list the check runs of $SOURCE_BRANCH to validate the required contexts"
    return 2
  fi
  local entry ctx app
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    ctx="${entry%@*}"; app="${entry##*@}"
    if grep -qF "$(printf '%s\t%s' "$ctx" "$app")" <<<"$obs"; then
      ok "required context '$ctx' (app_id=$app) OBSERVED on $SOURCE_BRANCH"
    else
      rc=1
      if [[ $ALLOW_UNOBSERVED -eq 1 ]]; then
        info "context '$ctx' (app_id=$app) NEVER observed, but --allow-unobserved-contexts is on"
        rc=0
      else
        drift "required context '$ctx' (app_id=$app) has NEVER been observed on $SOURCE_BRANCH.
             Declaring it would leave $SOURCE_BRANCH impossible to merge. Run
             --discover-contexts to see the real names, fix
             promotion.required_contexts / branches.$SOURCE_BRANCH in the JSON, or
             pass --allow-unobserved-contexts if you know what you are doing."
      fi
    fi
  done <<<"$want"
  return $rc
}

reconcile_branch_protection() {
  local branch="$1"
  section "Branch protection: $branch"

  local want; want="$(desired_protection "$branch")"
  if [[ -z "$want" || "$want" == "null" ]]; then
    unmeas "there is no protection declared for '$branch' in $STATE_FILE"
    return
  fi

  if ! check_branch_exists "$branch"; then
    if [[ $SKIP_STABLE -eq 1 && "$branch" == "$STABLE_BRANCH" ]]; then
      info "branch '$branch' does not exist yet; skipped by --skip-stable (explicitly acknowledged)"
    else
      unmeas "branch '$branch' DOES NOT EXIST yet, so I can neither verify nor apply its protection.
             The first promotion creates it (.github/workflows/release.yml). Run this
             script again AFTER that first promotion. rc=2 = 'I did not review it', not 'it is fine'."
    fi
    return
  fi

  local want_norm; want_norm="$(jq -S "$NORM_FROM_PUT" <<<"$want")"
  local want_ctx;  want_ctx="$(jq -r '.contexts[]' <<<"$want_norm")"

  local ctx_rc=0
  verify_contexts_observed "$want_ctx" || ctx_rc=$?
  if [[ $ctx_rc -ne 0 ]]; then
    info "I am not applying the protection of '$branch' until the required contexts are valid"
    return
  fi

  local have have_norm
  if have="$(gh api "repos/$REPO/branches/$branch/protection" 2>/dev/null)"; then
    have_norm="$(jq -S "$NORM_FROM_GET" <<<"$have")"
  else
    have_norm='null'
    info "branch '$branch' has no protection at all (GET -> 404 Branch not protected)"
  fi

  if [[ "$have_norm" == "$want_norm" ]]; then
    ok "$branch: the real protection matches the declared one"
    jq -r 'to_entries[] | "             \(.key) = \(.value|tostring)"' <<<"$want_norm"
    return
  fi

  drift "$branch: the real protection does NOT match the declared one"
  if [[ "$have_norm" == "null" ]]; then
    jq -r 'to_entries[] | "             + \(.key) = \(.value|tostring)"' <<<"$want_norm"
  else
    local k hv wv
    while IFS= read -r k; do
      hv="$(jq -r --arg k "$k" '.[$k]|tostring' <<<"$have_norm")"
      wv="$(jq -r --arg k "$k" '.[$k]|tostring' <<<"$want_norm")"
      [[ "$hv" == "$wv" ]] && continue
      printf '             %-20s actual=%-28s desired=%s\n' "$k" "$hv" "$wv"
    done < <(jq -r 'keys[]' <<<"$want_norm")
  fi

  local tmp; tmp="$(mktemp)"; printf '%s' "$want" >"$tmp"
  run_mutation "$branch: PUT /repos/$REPO/branches/$branch/protection (full replacement, idempotent)" \
    gh api --method PUT "repos/$REPO/branches/$branch/protection" --input "$tmp" || true
  rm -f "$tmp"
}

reconcile_branch_protection "$SOURCE_BRANCH"
reconcile_branch_protection "$STABLE_BRANCH"

# ---------------------------------------------------------------------------
# 2) REPO SETTINGS
# ---------------------------------------------------------------------------
section "Repository settings"
SETTING_KEYS="$(jq -r '.settings | keys[]' <<<"$STATE")"

settings_patch='{}'
for k in $SETTING_KEYS; do
  want="$(jq -r --arg k "$k" '.settings[$k]|tostring' <<<"$STATE")"
  have="$(jq -r --arg k "$k" '.[$k]|tostring' <<<"$REPO_JSON")"
  if [[ "$have" == "$want" ]]; then
    ok "$k = $have"
  else
    drift "$k: actual=$have desired=$want"
    settings_patch="$(jq -c --arg k "$k" --argjson v "$(jq -c --arg k "$k" '.settings[$k]' <<<"$STATE")" \
      '. + {($k): $v}' <<<"$settings_patch")"
  fi
done

if [[ "$settings_patch" != '{}' ]]; then
  tmp="$(mktemp)"; printf '%s' "$settings_patch" >"$tmp"
  run_mutation "PATCH /repos/$REPO ($(jq -r 'keys|join(", ")' <<<"$settings_patch"))" \
    gh api --method PATCH "repos/$REPO" --input "$tmp" || true
  rm -f "$tmp"
fi

# ---------------------------------------------------------------------------
# 3) TOPICS (PUT replaces the whole set -> declarative and idempotent)
# ---------------------------------------------------------------------------
section "Topics"
if have_topics="$(gh api "repos/$REPO/topics" --jq '.names|sort|join(",")' 2>/dev/null)"; then
  want_topics="$(jq -r '.topics|sort|join(",")' <<<"$STATE")"
  if [[ "$have_topics" == "$want_topics" ]]; then
    ok "topics = $have_topics"
  else
    drift "topics: actual=[$have_topics] desired=[$want_topics]"
    tmp="$(mktemp)"; jq -c '{names: .topics}' <<<"$STATE" >"$tmp"
    run_mutation "PUT /repos/$REPO/topics" gh api --method PUT "repos/$REPO/topics" --input "$tmp" || true
    rm -f "$tmp"
  fi
else
  unmeas "I could not read repos/$REPO/topics"
fi

# ---------------------------------------------------------------------------
# 4) LABELS. DELEGATED, not duplicated.
#    This block used to apply its own list of 6 labels from governance.json
#    while scripts/gh/labels.sh applied ANOTHER one. Two authorities over the
#    same resource: each saw the other's labels as "undeclared" and the leftover
#    label warning was permanent noise. The real taxonomy is the one in
#    labels.sh, because that is the one consumed by the issue forms,
#    gate-issue-closure.sh and gate-labels-taxonomy.sh, and the only one with a
#    --check mode with teeth. Here it is only checked, and the delegate's rc is
#    folded into the global verdict: a failure of the delegate can NEVER be left
#    as "I did not review it".
# ---------------------------------------------------------------------------
section "Labels (delegated to scripts/gh/labels.sh)"
LABELS_SH="${REPO_ROOT:-$(cd -- "${SCRIPT_DIR}/../.." && pwd)}/scripts/gh/labels.sh"
if [[ ! -x "$LABELS_SH" ]]; then
  unmeas "I cannot find an executable scripts/gh/labels.sh: the taxonomy has not been reviewed"
else
  labels_rc=0
  labels_out="$("$LABELS_SH" --repo "$REPO" --check 2>&1)" || labels_rc=$?
  printf '%s\n' "$labels_out" | sed 's/^/             /'
  case "$labels_rc" in
    0) ok "labels.sh --check: taxonomy complete and free of drift" ;;
    1) drift "labels.sh --check: the taxonomy has drifted. Fix it with 'scripts/gh/labels.sh --apply' (this script does NOT apply it: one owner per resource)" ;;
    *) unmeas "labels.sh --check could not measure (rc=$labels_rc)" ;;
  esac
fi

# ---------------------------------------------------------------------------
# 4b) THE CONTRACT INSIDE THE FILE. DELEGATED, for the same reason as labels.
#     promotion.required_contexts and branches.<source>.protection...checks are
#     two lists in this repository's own governance.json that must name the same
#     contexts. They did not, and nothing noticed: workflow-hardening was
#     verified by the promotion and required by no protection, so a red result
#     blocked no merge (issue #16). That comparison needs no network, so it lives
#     in a gate that runs on every pull request instead of waiting for someone to
#     run this script with admin credentials. Here it is only folded in, so a
#     failure of the delegate can never be left as "I did not review it".
# ---------------------------------------------------------------------------
section "The contract inside governance.json (delegated to gate-governance-contract.sh)"
CONTRACT_GATE="${REPO_ROOT:-$(cd -- "${SCRIPT_DIR}/../.." && pwd)}/scripts/gates/gate-governance-contract.sh"
if [[ ! -x "$CONTRACT_GATE" ]]; then
  unmeas "I cannot find an executable scripts/gates/gate-governance-contract.sh: the two lists have not been compared"
else
  contract_rc=0
  contract_out="$("$CONTRACT_GATE" 2>&1)" || contract_rc=$?
  printf '%s\n' "$contract_out" | sed 's/^/             /'
  case "$contract_rc" in
    0) ok "gate-governance-contract.sh: every declared required context is enforced by the protection" ;;
    1) drift "gate-governance-contract.sh: a context is required by prose and by nothing else. Fix the JSON, then apply it" ;;
    *) unmeas "gate-governance-contract.sh could not measure (rc=$contract_rc)" ;;
  esac
fi

# ---------------------------------------------------------------------------
# 5) VULNERABILITY ALERTS (Dependabot)
#    GET /vulnerability-alerts -> 204 enabled, 404 disabled.
# ---------------------------------------------------------------------------
section "Vulnerability alerts"
want_va="$(jq -r '.vulnerability_alerts' <<<"$STATE")"
va_rc=0
gh api "repos/$REPO/vulnerability-alerts" >/dev/null 2>&1 || va_rc=$?
if [[ $va_rc -eq 0 ]]; then have_va="true"; else have_va="false"; fi
if [[ "$have_va" == "$want_va" ]]; then
  ok "vulnerability_alerts = $have_va"
else
  drift "vulnerability_alerts: actual=$have_va desired=$want_va"
  if [[ "$want_va" == "true" ]]; then
    run_mutation "enable vulnerability alerts" gh api --method PUT "repos/$REPO/vulnerability-alerts" || true
  else
    run_mutation "disable vulnerability alerts" gh api --method DELETE "repos/$REPO/vulnerability-alerts" || true
  fi
fi

# ---------------------------------------------------------------------------
# 6) SECRET SCANNING + PUSH PROTECTION
#    API availability on a public repo of a personal Free account: NOT
#    VERIFIED. That is why a failure here counts as UNMEASURED, not as success.
# ---------------------------------------------------------------------------
section "Secret scanning"
want_ss="$(jq -r '.secret_scanning.enabled' <<<"$STATE")"
want_pp="$(jq -r '.secret_scanning.push_protection' <<<"$STATE")"
have_ss="$(jq -r '.security_and_analysis.secret_scanning.status // "unknown"' <<<"$REPO_JSON")"
have_pp="$(jq -r '.security_and_analysis.secret_scanning_push_protection.status // "unknown"' <<<"$REPO_JSON")"
want_ss_s=$([[ "$want_ss" == "true" ]] && echo enabled || echo disabled)
want_pp_s=$([[ "$want_pp" == "true" ]] && echo enabled || echo disabled)

if [[ "$have_ss" == "unknown" || "$have_pp" == "unknown" ]]; then
  unmeas "the response of repos/$REPO does not carry security_and_analysis (secret_scanning=$have_ss push_protection=$have_pp).
         Availability on a public repo of a personal Free account is NOT verified against official docs.
         I count it as UNMEASURED, never as correct."
elif [[ "$have_ss" == "$want_ss_s" && "$have_pp" == "$want_pp_s" ]]; then
  ok "secret_scanning=$have_ss push_protection=$have_pp"
else
  drift "secret_scanning: actual=$have_ss desired=$want_ss_s | push_protection: actual=$have_pp desired=$want_pp_s"
  tmp="$(mktemp)"
  jq -nc --arg ss "$want_ss_s" --arg pp "$want_pp_s" \
    '{security_and_analysis:{secret_scanning:{status:$ss},secret_scanning_push_protection:{status:$pp}}}' >"$tmp"
  run_mutation "PATCH /repos/$REPO (security_and_analysis)" \
    gh api --method PATCH "repos/$REPO" --input "$tmp" || true
  rm -f "$tmp"
fi

# ---------------------------------------------------------------------------
# 6b) DEPENDABOT SECURITY UPDATES
#     The confusable twin of section 5. `vulnerability_alerts` is the REPORTING
#     channel and is on; this is the AUTOMATIC FIXING channel and is off. It was
#     off on the live repository long before it was declared here, which is the
#     whole reason it is now declared: a correct value nobody wrote down is
#     indistinguishable from drift, and the next person to see `false` fixes it.
#
#     Read from the same security_and_analysis object as secret scanning, so it
#     inherits the same rule: absent object = UNMEASURED, never correct.
# ---------------------------------------------------------------------------
section "Dependabot security updates"
want_dsu="$(jq -r '.dependabot_security_updates' <<<"$STATE")"
have_dsu="$(jq -r '.security_and_analysis.dependabot_security_updates.status // "unknown"' <<<"$REPO_JSON")"
want_dsu_s=$([[ "$want_dsu" == "true" ]] && echo enabled || echo disabled)

if [[ "$have_dsu" == "unknown" ]]; then
  unmeas "the response of repos/$REPO does not carry security_and_analysis.dependabot_security_updates.
         A setting I could not read is not a setting I agree with; this is UNMEASURED, not correct."
elif [[ "$have_dsu" == "$want_dsu_s" ]]; then
  ok "dependabot_security_updates = $have_dsu"
else
  drift "dependabot_security_updates: actual=$have_dsu desired=$want_dsu_s.
         ON means Dependabot raises fix pull requests against every manifest in the dependency graph,
         bench/cases/** included, and those are answer keys - see _why_dependabot_security_updates."
  if [[ "$want_dsu" == "true" ]]; then
    run_mutation "enable Dependabot security updates" \
      gh api --method PUT "repos/$REPO/automated-security-fixes" || true
  else
    run_mutation "disable Dependabot security updates" \
      gh api --method DELETE "repos/$REPO/automated-security-fixes" || true
  fi
fi

# ---------------------------------------------------------------------------
# 6c) CENSUS OF security_and_analysis - the check that catches what 5, 6 and 6b
#     structurally cannot.
#
#     Each of those goes looking for a field it was told about. A setting nobody
#     was told about is precisely the one that gets missed, and that is not
#     hypothetical: dependabot_security_updates was live, off, correct, and
#     unmentioned anywhere in this repository until 2026-09-02, and two more
#     keys were in the same position when this block was written.
#
#     So the comparison runs from the API's key list rather than from ours, in
#     both directions. No --apply path: an undeclared key is a decision to take,
#     not a value to push, and a mutation here would let the script pick.
# ---------------------------------------------------------------------------
section "security_and_analysis census"
if ! jq -e 'has("security_and_analysis") and (.security_and_analysis != null)' >/dev/null 2>&1 <<<"$REPO_JSON"; then
  unmeas "the response of repos/$REPO carries no security_and_analysis object, so the census has nothing
         to enumerate. A list I could not read is not a list that agreed with me."
else
  sa_bad=0
  while IFS='|' read -r k have; do
    [ -n "$k" ] || continue
    want="$(jq -r --arg k "$k" '.security_and_analysis_declared[$k] // "UNDECLARED"' <<<"$STATE")"
    if [[ "$want" == "UNDECLARED" ]]; then
      drift "security_and_analysis.$k is $have and governance.json declares nothing about it.
         The value may well be right; nothing here knows that it is. Add it to
         security_and_analysis_declared with the reason, then this line goes away."
      sa_bad=1
    elif [[ "$want" != "$have" ]]; then
      drift "security_and_analysis.$k: actual=$have desired=$want"
      sa_bad=1
    fi
  done < <(jq -r '.security_and_analysis | to_entries[] | "\(.key)|\(.value.status)"' <<<"$REPO_JSON")

  while read -r k; do
    [ -n "$k" ] || continue
    if ! jq -e --arg k "$k" '.security_and_analysis | has($k)' >/dev/null 2>&1 <<<"$REPO_JSON"; then
      drift "governance.json declares security_and_analysis.$k and the API does not return it.
         Either the setting was renamed or removed upstream, or it never existed and the declaration
         has been reassuring a reader about nothing."
      sa_bad=1
    fi
  done < <(jq -r '.security_and_analysis_declared // {} | keys[]' <<<"$STATE")

  [ "$sa_bad" -eq 0 ] && ok "security_and_analysis census: every key returned is declared, and vice versa"
fi

# ---------------------------------------------------------------------------
# 7) COHERENCE: what is declared here vs what the promotion workflow consumes
# ---------------------------------------------------------------------------
section "Coherence with the promotion workflow"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
# The promotion lives in release.yml. promote-stable.yml existed on the
# wf/governance branch and was removed during the integration: there were TWO
# workflows promoting to stable, on the same cron, and on top of that with
# incompatible version models (one required semver in main's plugin.json, which
# is exactly what gate-plugin-version.sh forbids on the latest channel, so that
# one would have blocked forever).
WF="${REPO_ROOT}/.github/workflows/release.yml"
CI="${REPO_ROOT}/.github/workflows/ci.yml"
if [[ ! -f "$WF" ]]; then
  unmeas "I cannot find $WF: I cannot check that the workflow and this JSON talk about the same thing"
else
  if grep -q 'scripts/gh/governance.json' "$WF"; then
    ok "release.yml reads scripts/gh/governance.json (a single source of truth)"
  else
    drift "release.yml does NOT read governance.json: branch/label/cooldown names would be duplicated"
  fi

  # required_contexts are CHECK RUN NAMES, and a check run is named after the job's
  # 'name:' field. If they do not match ci.yml, the promotion waits forever for a
  # context that will never exist (or worse: --apply declares an impossible required
  # check and leaves main unmergeable). It is checked here, where it is declared.
  if [[ ! -f "$CI" ]]; then
    unmeas "I cannot find $CI: I cannot check that required_contexts exist as jobs"
  elif ! command -v python3 >/dev/null 2>&1; then
    unmeas "python3 is missing: I cannot parse $CI to check required_contexts"
  else
    # The checking script is written to a file: a heredoc INSIDE a command
    # substitution closes the parenthesis before the body and bash rejects it.
    ctx_py="$(mktemp)" || ctx_py=""
    if [[ -z "$ctx_py" ]]; then
      unmeas "I could not create a temp file to check required_contexts"
    else
      cat >"$ctx_py" <<'PYEOF'
import json, os, sys
try:
    import yaml
except ImportError:
    print("NOYAML"); sys.exit(3)
ci = yaml.safe_load(open(os.environ["CI_FILE"]).read())
names = {j.get("name") for j in (ci.get("jobs") or {}).values() if isinstance(j, dict)}
want = json.loads(os.environ["STATE_JSON"])["promotion"]["required_contexts"]
missing = [c for c in want if c not in names]
if missing:
    print("MISSING:" + ",".join(missing))
else:
    print("ALLPRESENT:" + ",".join(sorted(n for n in names if n)))
PYEOF
      ctx_rc=0
      # PYTHONSAFEPATH: the helper is written into a temporary directory and run
      # BY PATH, which puts that directory first on sys.path. On a host whose
      # temporary directory is shared, a yaml.py planted beside it would be
      # imported instead of the standard library. Found by a blinded audit of
      # this repository.
      ctx_out="$(PYTHONSAFEPATH=1 CI_FILE="$CI" STATE_JSON="$STATE" python3 "$ctx_py" 2>&1)" || ctx_rc=$?
      rm -f "$ctx_py"
      case "$ctx_out" in
        *NOYAML*)     unmeas "PyYAML is missing: I did not check that required_contexts exist as jobs of ci.yml" ;;
        ALLPRESENT:*) ok "required_contexts exist as a job 'name:' in ci.yml (jobs: ${ctx_out#ALLPRESENT:})" ;;
        MISSING:*)    drift "required_contexts that NO job of ci.yml produces: ${ctx_out#MISSING:}. The promotion would wait for a check that does not exist" ;;
        *)            unmeas "I could not check required_contexts against ci.yml (rc=$ctx_rc): $ctx_out" ;;
      esac
    fi
  fi

  gates_dir="${REPO_ROOT}/$(jq -r '.promotion.gates_dir' <<<"$STATE")"
  if [[ -d "$gates_dir" ]]; then
    # Recursive and not filtered by extension, exactly like scripts/gates/run-all.sh:
    # counting only '*.sh' at one level would leave out gates written in another
    # language or living in a subdirectory, and this 'OK' would speak of fewer gates
    # than there really are.
    n_gates="$(find "$gates_dir" -type f ! -name '.*' ! -name '*.md' ! -name '*.txt' \
                 ! -name '*.json' ! -name '*.yml' ! -name '*.yaml' ! -name '*.awk' \
                 ! -name 'run-all.sh' ! -path "$gates_dir/lib/*" ! -path "$gates_dir/fixtures/*" \
                 | wc -l | tr -d ' ')"
    if [[ "$n_gates" -gt 0 ]]; then
      ok "$gates_dir contains $n_gates gate(s)"
    else
      drift "$gates_dir exists but is EMPTY: promotion will be blocked (correct: fail-safe)"
    fi
  else
    unmeas "$gates_dir does not exist yet. Promotion will be blocked until then."
  fi
fi

# ---------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------
section "Summary"
printf '   reviewed OK : %d\n' "$N_OK"
printf '   drift       : %d\n' "$N_DRIFT"
printf '   applied     : %d\n' "$N_APPLIED"
printf '   failures    : %d\n' "$N_FAILED"
printf '   UNMEASURED  : %d\n' "$N_UNMEASURED"

cat <<EOF

   What this script does NOT review (say it out loud instead of faking coverage):
     - Who can push to a branch. On a personal-account repo 'restrictions' is
       org-only; it is INEXPRESSIBLE. The real guarantee comes from the gates, not the branch.
     - Rulesets. This repo uses classic protection on purpose; if a ruleset were ever
       created, it would stack with the classic one and the most restrictive would win.
       Manual detection: gh api repos/$REPO/rules/branches/$SOURCE_BRANCH
     - The content of the gates. Here it only checks that they exist and are declared.
EOF

if [[ $N_UNMEASURED -gt 0 ]]; then
  printf '\n%sVERDICT: rc=2 I COULD NOT MEASURE EVERYTHING.%s There are parts of the governance whose state I do not know.\n' "$c_yel" "$c_reset"
  exit "$RC_UNMEASURED"
fi
if [[ $N_FAILED -gt 0 ]]; then
  printf '\n%sVERDICT: rc=1 some mutation FAILED.%s\n' "$c_red" "$c_reset"
  exit "$RC_DRIFT"
fi
if [[ $N_DRIFT -gt 0 && "$MODE" != "apply" ]]; then
  printf '\n%sVERDICT: rc=1 THERE IS DRIFT.%s The real state does not match the declared one. Review the plan and run --apply.\n' "$c_red" "$c_reset"
  exit "$RC_DRIFT"
fi
if [[ $N_DRIFT -gt 0 && $N_APPLIED -eq 0 ]]; then
  printf '\n%sVERDICT: rc=1 there was drift and nothing was applied.%s\n' "$c_red" "$c_reset"
  exit "$RC_DRIFT"
fi
printf '\n%sVERDICT: rc=0 measured and conformant.%s\n' "$c_grn" "$c_reset"
exit "$RC_OK"
