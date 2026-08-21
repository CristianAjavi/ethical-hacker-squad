#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# build-changelog.sh - generates the CHANGELOG section of a stable release.
#
# THREAT MODEL OF THIS SCRIPT
#   Commit subjects are not trusted text: they can come from a PR of the
#   knowledge loop (bot/knowledge-*), that is, from content derived from the
#   internet. The CHANGELOG is published and also becomes the message of the
#   annotated tag. That is why every subject is SANITIZED:
#     - it is trimmed to a single line and to 120 characters
#     - control characters are removed
#     - the marks that would grant typographic or social control are
#       neutralized: backticks (code blocks), '<' '>' (raw HTML), '[' ']'
#       (links), '@' (mentions that notify real people) and '#' (auto-link to
#       issues/PRs, which would allow cross-referencing the release to any
#       issue in the repo).
#   The result is readable plain text, not active markdown.
#   WHAT THIS DOES NOT SOLVE (measured, we do not hide it): a bare URL is still
#   auto-linked by GitHub when rendering. What IS removed is the DISGUISED link
#   ([text](target)), which is the real risk: there the label lies about the
#   destination. A visible URL that says exactly where it goes is information,
#   not deception.
#
# USAGE
#   scripts/gh/build-changelog.sh --version <semver> --from <ref|""> --to <sha> \
#       [--date YYYY-MM-DD] [--repo owner/name]
#
# OUTPUT: the markdown section on stdout.
#
# EXIT CODES
#   0 = generated
#   1 = invalid input or range with no commits
#   2 = COULD NOT MEASURE (git missing or the range does not resolve)
# ---------------------------------------------------------------------------
set -uo pipefail

die1() { printf 'build-changelog: %s\n' "$*" >&2; exit 1; }
die2() { printf 'build-changelog: COULD NOT MEASURE - %s\n' "$*" >&2; exit 2; }

VERSION=""; FROM=""; TO=""; DATE=""; REPO="${GITHUB_REPOSITORY:-}"
while (( $# > 0 )); do
  case "$1" in
    --version) VERSION="${2:-}"; shift 2 ;;
    --from)    FROM="${2:-}";    shift 2 ;;
    --to)      TO="${2:-}";      shift 2 ;;
    --date)    DATE="${2:-}";    shift 2 ;;
    --repo)    REPO="${2:-}";    shift 2 ;;
    -h|--help) sed -n '2,29p' "$0"; exit 0 ;;
    *) die1 "unknown argument: $1" ;;
  esac
done

command -v git >/dev/null 2>&1 || die2 "git is missing"
[[ -n "$VERSION" ]] || die1 "--version is missing"
[[ -n "$TO" ]] || die1 "--to <sha> is missing"
[[ -n "$DATE" ]] || DATE=$(date -u +%Y-%m-%d)

git rev-parse -q --verify "$TO^{commit}" >/dev/null 2>&1 || die2 "the sha '$TO' does not resolve"
if [[ -n "$FROM" ]]; then
  git rev-parse -q --verify "$FROM^{commit}" >/dev/null 2>&1 || die2 "the base ref '$FROM' does not resolve"
  RANGE="${FROM}..${TO}"
else
  RANGE="$TO"
fi

# Sanitizing: one line, no control chars, no active markdown, <=120 characters.
sanitize() {
  printf '%s' "$1" \
    | tr '\r\n\t' '   ' \
    | LC_ALL=C tr -d '\000-\037\177' \
    | sed -e 's/[`<>][`<>]*/ /g' -e 's/[][]/ /g' -e 's/@/(at)/g' -e 's/#/(num)/g' \
    | sed -e 's/  */ /g' -e 's/^ //' -e 's/ $//' \
    | cut -c1-120
}

FEATS=""; FIXES=""; SECS=""; OTHERS=""; BREAKS=""
COUNT=0

# ONE RECORD PER COMMIT. See the note in next-version.sh: the body carries its
# own line breaks, so a format like '%H<TAB>%s<TAB>%b' made EVERY LINE of the
# body be treated as a separate commit. MEASURED: a single commit produced three
# CHANGELOG entries, two of them with text chosen by whoever wrote the body and
# with a fake "sha" (the first 7 characters of that line). That is, untrusted
# text published as if it were a real commit.
SHAS=$(git log --no-merges --format='%H' "$RANGE" 2>/dev/null)
[[ -n "$SHAS" ]] || die1 "there are no commits in the range '$RANGE'"

while IFS= read -r sha; do
  [[ -n "$sha" ]] || continue
  subject=$(git show -s --format='%s' "$sha")
  body=$(git show -s --format='%b' "$sha" | tr '\r\n' '  ')
  short="${sha:0:7}"
  COUNT=$((COUNT + 1))

  type=$(printf '%s' "$subject" | sed -nE 's/^([a-zA-Z]+)(\([^)]*\))?!?:.*/\1/p' | tr 'A-Z' 'a-z')
  desc=$(printf '%s' "$subject" | sed -E 's/^[a-zA-Z]+(\([^)]*\))?!?:[[:space:]]*//')
  [[ -n "$desc" ]] || desc="$subject"
  desc=$(sanitize "$desc")
  entry="- ${desc} (\`${short}\`)"

  if printf '%s' "$subject" | grep -qE '^[a-zA-Z]+(\([^)]*\))?!:' \
     || printf '%s' "$body" | grep -qE '(^|[[:space:]])BREAKING[ -]CHANGE:'; then
    BREAKS+="${entry}"$'\n'
  fi

  case "$type" in
    feat)              FEATS+="${entry}"$'\n' ;;
    fix)               FIXES+="${entry}"$'\n' ;;
    sec|security)      SECS+="${entry}"$'\n' ;;
    docs|chore|ci|refactor|test|build|perf|style) OTHERS+="${entry}"$'\n' ;;
    *)                 OTHERS+="${entry}"$'\n' ;;
  esac
done <<<"$SHAS"

printf '## %s — %s\n\n' "$VERSION" "$DATE"
if [[ -n "$REPO" ]]; then
  printf 'Promoted to `stable` from `main@%s`.\n' "${TO:0:7}"
  printf 'Diff: https://github.com/%s/compare/%s...%s\n\n' "$REPO" "${FROM:-$TO}" "$TO"
else
  printf 'Promoted to `stable` from `main@%s`.\n\n' "${TO:0:7}"
fi

emit() { # $1=title $2=body
  [[ -n "$2" ]] || return 0
  printf '### %s\n\n%s\n' "$1" "$2"
}
emit "Breaking changes" "$BREAKS"
emit "Security" "$SECS"
emit "New" "$FEATS"
emit "Fixes" "$FIXES"
emit "Other" "$OTHERS"

printf '_%s commit(s). Subjects sanitized to plain text: the CHANGELOG does not execute markdown from untrusted sources._\n' "$COUNT"
exit 0
