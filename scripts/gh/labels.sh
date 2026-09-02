#!/usr/bin/env bash
# labels.sh - repository label taxonomy, idempotent and dry by default.
#
# WHY IT EXISTS: the issue forms in .github/ISSUE_TEMPLATE apply hardcoded labels
# (`type/*`, `origin/*`, `status/needs-triage`). If a label does not exist in the
# repo, GitHub simply does not apply it and deterministic triage breaks silently.
# This script is the source of truth for that taxonomy and the gate that detects
# drift.
#
# MODES:
#   (default)      dry-run: prints the plan (create / update / unchanged). Mutates nothing.
#   --check        read-only gate: fails if a label is missing or color/description differ.
#   --apply        applies the changes (POST/PATCH). Requires explicit confirmation.
#
# EXIT CODES:
#   0 = MEASURED and it is fine
#       (dry-run: the whole plan was computed | --check: the taxonomy is complete and free of drift
#        | --apply: every change was applied)
#   1 = MEASURED and it FAILS
#       (--check: a label is missing or there is drift | --apply: some mutation failed)
#   2 = COULD NOT MEASURE
#       (no gh, no session, the repo is unknown, or the API did not answer)
#
# IT NEVER DELETES LABELS: renaming or removing a label moves historical issues and
# that is decided by hand. Leftover labels are listed as a warning, never touched.
#
# Usage:
#   scripts/gh/labels.sh [--repo OWNER/REPO] [--check | --apply] [--json] [-h]

set -uo pipefail

RC_OK=0
RC_FAIL=1
RC_UNMEASURABLE=2

MODE="dry-run"
REPO="${GITHUB_REPOSITORY:-}"
JSON_OUT=0

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)  REPO="${2:-}"; shift 2 ;;
    --check) MODE="check"; shift ;;
    --apply) MODE="apply"; shift ;;
    --dry-run) MODE="dry-run"; shift ;;
    --json)  JSON_OUT=1; shift ;;
    -h|--help) usage; exit "$RC_OK" ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit "$RC_UNMEASURABLE" ;;
  esac
done

# ---------------------------------------------------------------------------
# TAXONOMY  -  "name|color|description"
# No accents in the names: they travel inside the API URL path.
# ---------------------------------------------------------------------------
LABELS='
type/false-positive|d93f0b|The squad reported something that is not exploitable
type/false-negative|b60205|The squad missed a real finding
type/knowledge-gap|0e8a16|Missing coverage, technique or standard in the corpus
type/bug|d73a4a|The plugin does not do what it claims (install, flow, format)
type/enhancement|a2eeef|Improvement to an existing capability
type/documentation|0075ca|Documentation or skill copy only
type/maintenance|ededed|Repo infrastructure, CI, dependencies
area/security-lead|5319e7|Orchestration, role selection, final report
area/web-api|5319e7|Web AppSec, backend and API
area/mobile|5319e7|Android, iOS and APK
area/infra-cloud|5319e7|Infrastructure, cloud, containers
area/supply-chain|5319e7|Dependencies, secrets and supply chain
area/ai-safety|5319e7|AI, agents, LLM and chatbots
area/privacy-abuse|5319e7|Privacy, personal data and logic abuse
area/remediator|5319e7|Repair of confirmed findings
area/verifier|5319e7|Independent verification of fixes
area/plugin|1d76db|Packaging, marketplace and versioning
area/ci|1d76db|Workflows, gates and repository scripts
origin/human|c5def5|Opened by a person
origin/loop|c5def5|Opened by the automated knowledge loop
severity/critical|b60205|Critical impact
severity/high|d93f0b|High impact
severity/medium|fbca04|Medium impact
severity/low|c2e0c6|Low impact
severity/info|ededed|No direct impact, informational
status/needs-triage|fef2c0|Not classified yet
status/confirmed|0e8a16|Reproduced and accepted
status/not-reproducible|ededed|Could not be reproduced with what was provided
status/needs-info|fbca04|Missing information from the reporter
status/rejected|ededed|Out of scope or will not be fixed
status/resting|c5def5|In the cooldown period before promoting to stable
status/blocked|d4c5f9|Depends on something external
channel/latest|bfd4f2|Affects the latest channel (main branch)
channel/stable|bfd4f2|Affects the stable channel (stable branch)
channel/stable-blocked|b60205|Freezes automatic promotion to stable while it stays open
override/g7-reviewed|d4c5f9|G7: a maintainer sanctions this marked change moving a protected path
'

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
if ! command -v gh >/dev/null 2>&1; then
  printf 'COULD NOT MEASURE: the gh binary is missing (https://cli.github.com).\n' >&2
  exit "$RC_UNMEASURABLE"
fi
if ! command -v jq >/dev/null 2>&1; then
  printf 'COULD NOT MEASURE: jq is missing.\n' >&2
  exit "$RC_UNMEASURABLE"
fi

if [ -z "$REPO" ]; then
  origin="$(git remote get-url origin 2>/dev/null)" || origin=""
  case "$origin" in
    *github.com[:/]*)
      REPO="${origin#*github.com}"; REPO="${REPO#:}"; REPO="${REPO#/}"; REPO="${REPO%.git}" ;;
  esac
fi
if [ -z "$REPO" ]; then
  printf 'COULD NOT MEASURE: I do not know which repository this is. Pass --repo OWNER/REPO.\n' >&2
  exit "$RC_UNMEASURABLE"
fi

# An empty taxonomy used to make --check say "OK. Taxonomy complete and free of drift"
# with rc=0 after checking ZERO labels: an rc=0 that meant "I reviewed nothing".
# With no declarations there is nothing to measure, and that is COULD NOT MEASURE.
N_DECLARED="$(printf '%s\n' "$LABELS" | grep -c '|')"
if [ "$N_DECLARED" -eq 0 ]; then
  printf 'COULD NOT MEASURE: the LABELS taxonomy is empty (0 labels declared).\n' >&2
  printf 'A "no drift" verdict over zero labels is not a measurement.\n' >&2
  exit "$RC_UNMEASURABLE"
fi

TMPD="$(mktemp -d)" || { printf 'COULD NOT MEASURE: could not create a temp dir.\n' >&2; exit "$RC_UNMEASURABLE"; }
trap 'rm -rf "$TMPD"' EXIT

# Current state of the repo: a single paginated call. If it fails, COULD NOT MEASURE.
if ! gh api --paginate "repos/$REPO/labels" --jq '.[] | [.name, .color, (.description // "")] | @tsv' \
     > "$TMPD/actual.tsv" 2>"$TMPD/api.err"; then
  printf 'COULD NOT MEASURE: the labels API did not answer for %s:\n%s\n' "$REPO" "$(cat "$TMPD/api.err")" >&2
  exit "$RC_UNMEASURABLE"
fi

lookup() { # $1 name -> prints "color\tdescription", rc 1 if it does not exist
  awk -F'\t' -v n="$1" '$1 == n { print $2 "\t" $3; found=1 } END { exit(found ? 0 : 1) }' "$TMPD/actual.tsv"
}

urlenc_name() { printf '%s' "$1" | sed 's|/|%2F|g'; }

n_create=0; n_update=0; n_same=0; n_err=0
: > "$TMPD/plan.txt"

printf 'labels.sh\n=========\n'
printf 'Repository : %s\n' "$REPO"
printf 'Mode       : %s\n' "$MODE"
printf 'Taxonomy   : %s labels declared\n\n' "$N_DECLARED"

while IFS='|' read -r name color desc; do
  [ -n "${name:-}" ] || continue
  case "$name" in \#*) continue ;; esac

  if cur="$(lookup "$name")"; then
    cur_color="${cur%%	*}"
    cur_desc="${cur#*	}"
    if [ "$cur_color" = "$color" ] && [ "$cur_desc" = "$desc" ]; then
      n_same=$((n_same + 1))
      printf '  =  %-28s unchanged\n' "$name"
      continue
    fi
    n_update=$((n_update + 1))
    printf '  ~  %-28s UPDATE color %s->%s | description "%s"->"%s"\n' \
      "$name" "$cur_color" "$color" "$cur_desc" "$desc"
    printf 'update\t%s\t%s\t%s\n' "$name" "$color" "$desc" >> "$TMPD/plan.txt"
  else
    n_create=$((n_create + 1))
    printf '  +  %-28s CREATE (color %s)\n' "$name" "$color"
    printf 'create\t%s\t%s\t%s\n' "$name" "$color" "$desc" >> "$TMPD/plan.txt"
  fi
done <<EOF
$LABELS
EOF

# Labels that exist in the repo and are not declared: they are reported, not touched.
: > "$TMPD/extra.txt"
while IFS=$'\t' read -r name _color _desc; do
  [ -n "${name:-}" ] || continue
  # EXACT name comparison: with grep -F "$name|" the default label "bug" would
  # match the line "type/bug|..." and stay hidden.
  if ! printf '%s\n' "$LABELS" | awk -F'|' -v n="$name" '$1 == n { found=1 } END { exit(found?0:1) }'; then
    printf '%s\n' "$name" >> "$TMPD/extra.txt"
  fi
done < "$TMPD/actual.tsv"

printf '\nSummary: create=%d update=%d unchanged=%d\n' "$n_create" "$n_update" "$n_same"
if [ -s "$TMPD/extra.txt" ]; then
  printf 'WARNING (not touched, delete them by hand if appropriate): labels not declared in the taxonomy:\n'
  while IFS= read -r e; do printf '  ?  %s\n' "$e"; done < "$TMPD/extra.txt"
fi

if [ "$JSON_OUT" -eq 1 ]; then
  jq -n --argjson c "$n_create" --argjson u "$n_update" --argjson s "$n_same" \
        --arg repo "$REPO" --arg mode "$MODE" \
        '{repo:$repo, mode:$mode, create:$c, update:$u, unchanged:$s}'
fi

case "$MODE" in
  check)
    printf '\nREVIEWED: existence, color and description of the %d declared labels.\n' \
      "$N_DECLARED"
    printf 'NOT REVIEWED: undeclared labels (listed above as a warning).\n'
    if [ "$n_create" -gt 0 ] || [ "$n_update" -gt 0 ]; then
      printf '\nResult: FAIL. The repo taxonomy does not match scripts/gh/labels.sh.\n'
      printf 'Fix it with: scripts/gh/labels.sh --apply\n'
      exit "$RC_FAIL"
    fi
    printf '\nResult: OK. Taxonomy complete and free of drift.\n'
    exit "$RC_OK"
    ;;
  dry-run)
    printf '\nThis was a DRY-RUN: nothing has been mutated.\n'
    printf 'To apply it: scripts/gh/labels.sh --apply   (requires write access to the repo)\n'
    printf 'To use it as a gate: scripts/gh/labels.sh --check\n'
    exit "$RC_OK"
    ;;
  apply)
    if [ ! -s "$TMPD/plan.txt" ]; then
      printf '\nNothing to apply. Result: OK.\n'
      exit "$RC_OK"
    fi
    printf '\nApplying %d changes...\n' "$(wc -l < "$TMPD/plan.txt" | tr -d ' ')"
    while IFS=$'\t' read -r action name color desc; do
      [ -n "${action:-}" ] || continue
      if [ "$action" = "create" ]; then
        if gh api -X POST "repos/$REPO/labels" \
             -f name="$name" -f color="$color" -f description="$desc" >/dev/null 2>"$TMPD/err"; then
          printf '  +  %s created\n' "$name"
        else
          n_err=$((n_err + 1)); printf '  !  %s FAILED: %s\n' "$name" "$(cat "$TMPD/err")" >&2
        fi
      else
        if gh api -X PATCH "repos/$REPO/labels/$(urlenc_name "$name")" \
             -f new_name="$name" -f color="$color" -f description="$desc" >/dev/null 2>"$TMPD/err"; then
          printf '  ~  %s updated\n' "$name"
        else
          n_err=$((n_err + 1)); printf '  !  %s FAILED: %s\n' "$name" "$(cat "$TMPD/err")" >&2
        fi
      fi
    done < "$TMPD/plan.txt"
    if [ "$n_err" -gt 0 ]; then
      printf '\nResult: FAIL. %d mutations failed. It is idempotent: you can re-run it.\n' "$n_err"
      exit "$RC_FAIL"
    fi
    printf '\nResult: OK. Re-run it with --check to confirm no drift is left.\n'
    exit "$RC_OK"
    ;;
esac

printf 'COULD NOT MEASURE: unknown mode "%s".\n' "$MODE" >&2
exit "$RC_UNMEASURABLE"
