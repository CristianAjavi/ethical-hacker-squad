#!/usr/bin/env bash
# gate-issue-closure.sh
#
# DOCTRINE: a false-positive or false-negative issue is not closed by the fix.
# It is closed by the fix PLUS the check that stops it from coming back. A fix
# without a check is a scheduled relapse.
#
# WHAT IT DOES: if the body of a PR declares it closes (Fixes/Closes/Resolves)
# an issue labelled type/false-positive or type/false-negative, it requires the
# PR to touch at least one gate file or one file of the case corpus. If it does
# not touch one, it fails.
#
# EXIT CODES (deliberately distinguishable):
#   0 = I MEASURED and it is fine
#   1 = I MEASURED and it FAILS
#   2 = I COULD NOT MEASURE (no PR body, no gh, the API did not answer, ...)
#       An rc=0 never means "I did not check it".
#
# SECURITY: this script NEVER evaluates or executes the PR body. It only runs it
# through grep. The body arrives via a file or via the PR_BODY environment
# variable; it is never interpolated into a workflow `run:`.
#
# Usage:
#   scripts/gates/gate-issue-closure.sh [options]
#
# Options:
#   --pr N                 PR number (to resolve body and files with gh)
#   --repo OWNER/REPO      Repository (default: GITHUB_REPOSITORY or the origin remote)
#   --body-file F          File holding the PR body (wins over PR_BODY and over gh)
#   --changed-files F      File with one path per line (wins over git diff and over gh)
#   --deleted-files F      File with the paths DELETED by the PR (only meaningful
#                          alongside --changed-files; with git or gh it is derived).
#                          A deleted file does NOT count as a watched regression.
#   --labels-file F        Offline map "NUMBER<TAB or space>label" (one line per label)
#   --base REF             Base for `git diff` (default: GITHUB_BASE_REF, origin/main or main)
#   --emit-refs            Only prints the issue numbers of THIS repo the PR says it closes
#   --require-link         Also fails if the PR declares no closure at all (off by default)
#   -h, --help             This help
#
# Equivalent environment variables: PR_BODY, PR_NUMBER, GITHUB_REPOSITORY,
#   CHANGED_FILES_FILE, DELETED_FILES_FILE, LABELS_FILE, BASE_REF,
#   REGRESSION_LABELS (default "type/false-positive,type/false-negative"),
#   EVIDENCE_PATHS   (comma-separated globs; defaults below).

set -uo pipefail

RC_OK=0
RC_FAIL=1
RC_UNMEASURABLE=2

REGRESSION_LABELS="${REGRESSION_LABELS:-type/false-positive,type/false-negative}"
# The paths are set by contract G8 of docs/gate-requirements.md: "scripts/gates/",
# "tests/" or "references/knowledge/**". `cases/` does not exist in the repo and is
# not in the contract: keeping it was a dead path, and it was missing exactly where
# the corpus lives, so fixing a false negative by adding the case to the corpus (the
# main remedy the contract names) failed the gate. A gate that punishes the correct
# fix ends up being routed around. If the contract changes, change this line IN THE
# SAME PR.
# The corpus lives under skills/<skill>/references/knowledge/, not at the root: the
# glob has to match the REAL path, not the shorthand the contract uses to name it.
EVIDENCE_PATHS="${EVIDENCE_PATHS:-scripts/gates/*,tests/*,skills/*/references/knowledge/*}"

PR_NUMBER="${PR_NUMBER:-}"
REPO="${GITHUB_REPOSITORY:-}"
BODY_FILE=""
CHANGED_FILES_FILE="${CHANGED_FILES_FILE:-}"
DELETED_FILES_FILE="${DELETED_FILES_FILE:-}"
LABELS_FILE="${LABELS_FILE:-}"
BASE_REF="${BASE_REF:-}"
EMIT_REFS=0
REQUIRE_LINK=0

TMPDIR_GATE=""
cleanup() { [ -n "$TMPDIR_GATE" ] && rm -rf "$TMPDIR_GATE"; }
trap cleanup EXIT

say()  { printf '%s\n' "$*"; }
note() { printf '  - %s\n' "$*"; }
err()  { printf '%s\n' "$*" >&2; }

usage() { sed -n '2,43p' "$0" | sed 's/^# \{0,1\}//'; }

# The EVIDENCE_PATHS globs are split with IFS but are NOT expanded against the
# disk: `set -f` prevents "scripts/gates/*" from turning into the list of files
# that currently exist.
split_config() {
  local old_ifs="$IFS"
  set -f
  IFS=','
  # shellcheck disable=SC2206
  EVIDENCE_ARR=($EVIDENCE_PATHS)
  # shellcheck disable=SC2206
  REGRESSION_ARR=($REGRESSION_LABELS)
  IFS="$old_ifs"
  set +f
}

while [ $# -gt 0 ]; do
  case "$1" in
    --pr)            PR_NUMBER="${2:-}"; shift 2 ;;
    --repo)          REPO="${2:-}"; shift 2 ;;
    --body-file)     BODY_FILE="${2:-}"; shift 2 ;;
    --changed-files) CHANGED_FILES_FILE="${2:-}"; shift 2 ;;
    --deleted-files) DELETED_FILES_FILE="${2:-}"; shift 2 ;;
    --labels-file)   LABELS_FILE="${2:-}"; shift 2 ;;
    --base)          BASE_REF="${2:-}"; shift 2 ;;
    --emit-refs)     EMIT_REFS=1; shift ;;
    --require-link)  REQUIRE_LINK=1; shift ;;
    -h|--help)       usage; exit "$RC_OK" ;;
    *)               err "unknown option: $1"; usage >&2; exit "$RC_UNMEASURABLE" ;;
  esac
done

split_config

TMPDIR_GATE="$(mktemp -d 2>/dev/null)" || {
  err "COULD NOT MEASURE: I could not create a temporary directory."
  exit "$RC_UNMEASURABLE"
}

# ---------------------------------------------------------------------------
# 1. Repository
# ---------------------------------------------------------------------------
if [ -z "$REPO" ]; then
  origin="$(git remote get-url origin 2>/dev/null)" || origin=""
  case "$origin" in
    *github.com[:/]*)
      REPO="${origin#*github.com}"
      REPO="${REPO#:}"; REPO="${REPO#/}"; REPO="${REPO%.git}"
      ;;
  esac
fi

# ---------------------------------------------------------------------------
# 2. PR body
# ---------------------------------------------------------------------------
BODY_SRC=""
BODY_PATH="$TMPDIR_GATE/body.txt"
if [ -n "$BODY_FILE" ]; then
  if [ ! -r "$BODY_FILE" ]; then
    err "COULD NOT MEASURE: --body-file '$BODY_FILE' cannot be read."
    exit "$RC_UNMEASURABLE"
  fi
  cat -- "$BODY_FILE" > "$BODY_PATH"
  BODY_SRC="--body-file $BODY_FILE"
elif [ -n "${PR_BODY:-}" ]; then
  printf '%s\n' "$PR_BODY" > "$BODY_PATH"
  BODY_SRC="PR_BODY environment variable"
elif [ -n "$PR_NUMBER" ] && command -v gh >/dev/null 2>&1; then
  if gh pr view "$PR_NUMBER" ${REPO:+--repo "$REPO"} --json body --jq '.body' > "$BODY_PATH" 2>"$TMPDIR_GATE/gh.err"; then
    BODY_SRC="gh pr view $PR_NUMBER"
  else
    err "COULD NOT MEASURE: 'gh pr view $PR_NUMBER' failed:"
    err "$(cat "$TMPDIR_GATE/gh.err")"
    exit "$RC_UNMEASURABLE"
  fi
else
  err "COULD NOT MEASURE: there is no PR body. Pass --body-file, export PR_BODY or pass --pr N with gh available."
  exit "$RC_UNMEASURABLE"
fi

# Strip HTML comments: the PR template carries examples inside <!-- --> and they
# must not count as a closure declaration.
strip_html_comments() {
  awk '
    {
      line = $0
      out = ""
      while (1) {
        if (incomment) {
          p = index(line, "-->")
          if (p == 0) { line = ""; break }
          line = substr(line, p + 3); incomment = 0
        } else {
          p = index(line, "<!--")
          if (p == 0) { out = out line; line = ""; break }
          out = out substr(line, 1, p - 1)
          line = substr(line, p + 4); incomment = 1
        }
      }
      print out
    }
  ' "$1"
}
strip_html_comments "$BODY_PATH" > "$TMPDIR_GATE/body.clean"

# ---------------------------------------------------------------------------
# 3. Closing references
#    Keywords documented by GitHub: close, closes, closed, fix, fixes, fixed,
#    resolve, resolves, resolved. Forms: "#N" and "OWNER/REPO#N".
#    The form "KEYWORD <issue url>" is NOT documented as a closure, but it does
#    declare the intent to close, so the gate counts it (strict direction).
# ---------------------------------------------------------------------------
KEYWORDS='(close[sd]?|fix(e[sd])?|resolve[sd]?)'
REFPART='(#[0-9]+|[A-Za-z0-9._-]+/[A-Za-z0-9._-]+#[0-9]+|https://github\.com/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+/issues/[0-9]+)'

grep -Eio "(^|[^A-Za-z])${KEYWORDS}[[:space:]]*:?[[:space:]]+${REFPART}" \
  "$TMPDIR_GATE/body.clean" > "$TMPDIR_GATE/matches" 2>/dev/null

: > "$TMPDIR_GATE/refs.mine"
: > "$TMPDIR_GATE/refs.foreign"

repo_lc="$(printf '%s' "$REPO" | tr '[:upper:]' '[:lower:]')"

while IFS= read -r m; do
  [ -n "$m" ] || continue
  ref="${m##* }"          # the last token is the reference
  ref="${ref##*[[:space:]]}"
  case "$ref" in
    https://github.com/*/issues/*)
      num="${ref##*/}"
      owner_repo="${ref#https://github.com/}"
      owner_repo="${owner_repo%/issues/*}"
      ;;
    \#*)
      num="${ref#\#}"
      owner_repo="$repo_lc"
      ;;
    */*\#*)
      num="${ref##*\#}"
      owner_repo="${ref%%\#*}"
      ;;
    *) continue ;;
  esac
  owner_repo="$(printf '%s' "$owner_repo" | tr '[:upper:]' '[:lower:]')"
  case "$num" in ''|*[!0-9]*) continue ;; esac
  if [ -n "$repo_lc" ] && [ "$owner_repo" != "$repo_lc" ]; then
    printf '%s#%s\n' "$owner_repo" "$num" >> "$TMPDIR_GATE/refs.foreign"
  elif [ -z "$repo_lc" ] && [ "$owner_repo" != "$repo_lc" ] && [ "$owner_repo" != "" ]; then
    # We do not know which repo is "this" one: we can assert neither that the
    # reference is foreign nor that it is ours.
    printf '%s#%s\n' "$owner_repo" "$num" >> "$TMPDIR_GATE/refs.foreign"
  else
    printf '%s\n' "$num" >> "$TMPDIR_GATE/refs.mine"
  fi
done < "$TMPDIR_GATE/matches"

sort -un "$TMPDIR_GATE/refs.mine" -o "$TMPDIR_GATE/refs.mine"
sort -u "$TMPDIR_GATE/refs.foreign" -o "$TMPDIR_GATE/refs.foreign"

if [ "$EMIT_REFS" -eq 1 ]; then
  cat "$TMPDIR_GATE/refs.mine"
  exit "$RC_OK"
fi

n_mine=$(wc -l < "$TMPDIR_GATE/refs.mine" | tr -d ' ')
n_foreign=$(wc -l < "$TMPDIR_GATE/refs.foreign" | tr -d ' ')

say "gate-issue-closure"
say "=================="
say "Repository         : ${REPO:-<unknown>}"
say "PR body            : $BODY_SRC"
say "Labels that require a watched regression: $REGRESSION_LABELS"
say "Paths that count as a watched regression: $EVIDENCE_PATHS"
say ""

if [ "$n_mine" -eq 0 ]; then
  say "CHECKED: the PR body declares no closure of any issue in this repository."
  if [ "$n_foreign" -gt 0 ]; then
    say "NOT CHECKED: references to other repositories (I cannot judge their taxonomy):"
    while IFS= read -r f; do note "$f"; done < "$TMPDIR_GATE/refs.foreign"
  fi
  if [ "$REQUIRE_LINK" -eq 1 ]; then
    say ""
    say "FAIL: --require-link is on and the PR declares no 'Fixes #N'."
    exit "$RC_FAIL"
  fi
  say ""
  say "Result: OK (nothing to require)."
  exit "$RC_OK"
fi

# ---------------------------------------------------------------------------
# 4. Labels of each referenced issue
# ---------------------------------------------------------------------------
labels_of() { # $1 = issue number -> prints one label per line; rc 2 if unreadable
  local n="$1"
  if [ -n "$LABELS_FILE" ]; then
    if [ ! -r "$LABELS_FILE" ]; then return 2; fi
    # If the issue is NOT in the map, that is "I could not measure", not "it has
    # no labels". An incomplete file cannot wave a PR through.
    local out
    if out="$(awk -v want="$n" '
      { gsub(/\r/, "") }
      $1 == want { found=1; $1=""; sub(/^[ \t]+/, ""); if (length($0)) print $0 }
      END { exit(found ? 0 : 1) }
    ' "$LABELS_FILE")"; then
      printf '%s\n' "$out"
      return 0
    fi
    return 2
  fi
  command -v gh >/dev/null 2>&1 || return 2
  [ -n "$REPO" ] || return 2
  local out attempt
  for attempt in 1 2; do
    if out="$(gh api "repos/$REPO/issues/$n" --jq '.labels[].name' 2>"$TMPDIR_GATE/api.err")"; then
      printf '%s\n' "$out"
      return 0
    fi
    # A real 404 (non-existent issue) vs a transient API failure: we retry once
    # and, if we are still uncertain, it is COULD NOT MEASURE, never a failure
    # of the PR.
    sleep 2
  done
  return 2
}

is_regression_label() {
  local l="$1" want
  for want in "${REGRESSION_ARR[@]}"; do
    want="$(printf '%s' "$want" | tr -d '[:space:]')"
    [ -n "$want" ] || continue
    [ "$l" = "$want" ] && return 0
  done
  return 1
}

: > "$TMPDIR_GATE/needs_regression"
unmeasured=0
say "Issues the PR says it closes in this repository:"
while IFS= read -r n; do
  [ -n "$n" ] || continue
  if lbls="$(labels_of "$n")"; then
    hit=""
    while IFS= read -r l; do
      [ -n "$l" ] || continue
      if is_regression_label "$l"; then hit="$l"; fi
    done <<EOF
$lbls
EOF
    if [ -n "$hit" ]; then
      note "#$n  labels: $(printf '%s' "$lbls" | tr '\n' ' ')  -> REQUIRES a watched regression ($hit)"
      printf '%s\n' "$n" >> "$TMPDIR_GATE/needs_regression"
    else
      note "#$n  labels: $(printf '%s' "$lbls" | tr '\n' ' ')  -> does not require a watched regression"
    fi
  else
    note "#$n  I COULD NOT READ ITS LABELS (gh missing, no repo, or the API did not answer)"
    unmeasured=1
  fi
done < "$TMPDIR_GATE/refs.mine"

if [ "$n_foreign" -gt 0 ]; then
  say ""
  say "NOT CHECKED: references to other repositories:"
  while IFS= read -r f; do note "$f"; done < "$TMPDIR_GATE/refs.foreign"
fi

if [ "$unmeasured" -eq 1 ]; then
  say ""
  say "Result: COULD NOT MEASURE. I assert neither that the PR is fine nor that it is wrong."
  exit "$RC_UNMEASURABLE"
fi

if [ ! -s "$TMPDIR_GATE/needs_regression" ]; then
  say ""
  say "Result: OK. No closed issue is of type false positive or false negative."
  exit "$RC_OK"
fi

# ---------------------------------------------------------------------------
# 5. Files touched by the PR
# ---------------------------------------------------------------------------
CHANGED="$TMPDIR_GATE/changed.txt"
# Files DELETED by the PR. Deleting the gate that catches you is NOT watching the
# regression: `git diff --name-only` lists deletions just like additions, so
# without this a PR could close a false positive by DELETING scripts/gates/...
# and come out green.
DELETED="$TMPDIR_GATE/deleted.txt"
: > "$DELETED"
DELETED_SRC=""            # empty = it was impossible to know what got deleted
CHANGED_SRC=""
if [ -n "$CHANGED_FILES_FILE" ]; then
  if [ ! -r "$CHANGED_FILES_FILE" ]; then
    err "COULD NOT MEASURE: --changed-files '$CHANGED_FILES_FILE' cannot be read."
    exit "$RC_UNMEASURABLE"
  fi
  cat -- "$CHANGED_FILES_FILE" > "$CHANGED"
  CHANGED_SRC="--changed-files $CHANGED_FILES_FILE"
  if [ -n "$DELETED_FILES_FILE" ]; then
    if [ ! -r "$DELETED_FILES_FILE" ]; then
      err "COULD NOT MEASURE: --deleted-files '$DELETED_FILES_FILE' cannot be read."
      exit "$RC_UNMEASURABLE"
    fi
    cat -- "$DELETED_FILES_FILE" > "$DELETED"
    DELETED_SRC="--deleted-files $DELETED_FILES_FILE"
  fi
else
  base="$BASE_REF"
  if [ -z "$base" ] && [ -n "${GITHUB_BASE_REF:-}" ]; then base="origin/$GITHUB_BASE_REF"; fi
  if [ -z "$base" ]; then
    if git rev-parse --verify -q origin/main >/dev/null 2>&1; then base="origin/main"
    elif git rev-parse --verify -q main >/dev/null 2>&1; then base="main"
    fi
  fi
  if [ -n "$base" ] && git rev-parse --verify -q "$base" >/dev/null 2>&1; then
    if ! git diff --name-only "$base"...HEAD > "$CHANGED" 2>"$TMPDIR_GATE/git.err"; then
      err "COULD NOT MEASURE: 'git diff $base...HEAD' failed: $(cat "$TMPDIR_GATE/git.err")"
      exit "$RC_UNMEASURABLE"
    fi
    CHANGED_SRC="git diff --name-only $base...HEAD"
    if ! git diff --name-only --diff-filter=D "$base"...HEAD > "$DELETED" 2>/dev/null; then
      err "COULD NOT MEASURE: I could not list the deleted files with --diff-filter=D."
      exit "$RC_UNMEASURABLE"
    fi
    DELETED_SRC="git diff --name-only --diff-filter=D $base...HEAD"
  elif [ -n "$PR_NUMBER" ] && command -v gh >/dev/null 2>&1 && [ -n "$REPO" ]; then
    if ! gh api --paginate "repos/$REPO/pulls/$PR_NUMBER/files" --jq '.[].filename' > "$CHANGED" 2>"$TMPDIR_GATE/api.err"; then
      err "COULD NOT MEASURE: the PR files API did not answer: $(cat "$TMPDIR_GATE/api.err")"
      exit "$RC_UNMEASURABLE"
    fi
    CHANGED_SRC="gh api repos/$REPO/pulls/$PR_NUMBER/files"
    if ! gh api --paginate "repos/$REPO/pulls/$PR_NUMBER/files" \
         --jq '.[] | select(.status == "removed") | .filename' > "$DELETED" 2>"$TMPDIR_GATE/api.err"; then
      err "COULD NOT MEASURE: I could not learn which files the PR deletes: $(cat "$TMPDIR_GATE/api.err")"
      exit "$RC_UNMEASURABLE"
    fi
    DELETED_SRC="gh api ... (status == removed)"
  else
    err "COULD NOT MEASURE: I could not obtain the PR file list (no valid git base and no gh)."
    exit "$RC_UNMEASURABLE"
  fi
fi

matches_evidence() {
  local f="$1" p
  for p in "${EVIDENCE_ARR[@]}"; do
    p="$(printf '%s' "$p" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -n "$p" ] || continue
    # shellcheck disable=SC2053
    if [[ "$f" == $p ]]; then return 0; fi
  done
  return 1
}

is_deleted() { # $1 = path -> rc 0 if the PR deletes it
  [ -s "$DELETED" ] || return 1
  awk -v want="$1" '$0 == want { found=1 } END { exit(found ? 0 : 1) }' "$DELETED"
}

: > "$TMPDIR_GATE/evidence.hits"
: > "$TMPDIR_GATE/evidence.deleted"
n_changed=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n_changed=$((n_changed + 1))
  if matches_evidence "$f"; then
    if is_deleted "$f"; then
      printf '%s\n' "$f" >> "$TMPDIR_GATE/evidence.deleted"
    else
      printf '%s\n' "$f" >> "$TMPDIR_GATE/evidence.hits"
    fi
  fi
done < "$CHANGED"

say ""
say "Files in the PR    : $n_changed  (source: $CHANGED_SRC)"
if [ -n "$DELETED_SRC" ]; then
  say "Deleted files      : $(wc -l < "$DELETED" | tr -d ' ')  (source: $DELETED_SRC)"
else
  say "Deleted files      : NOT CHECKED (I was not told which files the PR deletes; use --deleted-files)"
fi
if [ -s "$TMPDIR_GATE/evidence.deleted" ]; then
  say "Regression files the PR DELETES (they do not count as watching):"
  while IFS= read -r f; do note "$f"; done < "$TMPDIR_GATE/evidence.deleted"
fi
if [ -s "$TMPDIR_GATE/evidence.hits" ]; then
  say "Files that count as a watched regression:"
  while IFS= read -r f; do note "$f"; done < "$TMPDIR_GATE/evidence.hits"
  say ""
  say "Result: OK. The PR closes false positive/negative issues AND touches a gate or the case corpus."
  say "NOTICE (I cannot measure this myself): that the file really carries the case for this"
  say "       regression, and that the PR shows the negative run, is verified by human review."
  exit "$RC_OK"
fi

say "Files that count as a watched regression: NONE"
say ""
say "Result: FAIL."
say "The PR says it closes these issues:"
while IFS= read -r n; do note "#$n (false positive or false negative)"; done < "$TMPDIR_GATE/needs_regression"
if [ -s "$TMPDIR_GATE/evidence.deleted" ]; then
  say "...and the only thing it touches from: $EVIDENCE_PATHS it DELETES. Deleting the check"
  say "   that catches you is not watching the regression."
else
  say "...but it touches no file from: $EVIDENCE_PATHS"
fi
say ""
say "A fix without a check watching it is a scheduled relapse. Add the regression case"
say "(or the gate) that fails if the defect comes back, and declare it in the section"
say "'What is now watching the regression' of the PR template."
exit "$RC_FAIL"
