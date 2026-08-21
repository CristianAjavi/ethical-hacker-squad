#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# next-version.sh - computes the next semver for the stable channel from
# Conventional Commits, DETERMINISTICALLY and with no external dependencies.
#
# WHY NOT release-please / semantic-release
#   They fit technically (`simple` strategy + extra-files with a jsonpath over
#   $.version), but their operating model is "a human merges the Release PR".
#   Here the promotion to stable is automatic, so you would have to auto-merge a
#   PR opened by a bot inside main - exactly the vector this repo exists to
#   close - and on top of that grant contents:write + pull-requests:write to yet
#   another third-party action. Conventional Commits is used only as data INPUT;
#   the computation lives here, in ~100 auditable lines with no new surface.
#
# USAGE
#   scripts/gh/next-version.sh --current <semver> --from <ref|""> --to <sha> [--bump auto|patch|minor|major]
#
# OUTPUT (stdout, key=value format for $GITHUB_OUTPUT)
#   current_version=...
#   next_version=...
#   bump=major|minor|patch|none
#   commit_count=N
#
# EXIT CODES
#   0 = computed
#   1 = invalid input / nothing to publish
#   2 = COULD NOT MEASURE (git missing or the range does not resolve)
# ---------------------------------------------------------------------------
set -uo pipefail

SEMVER_RE='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'

die1() { printf 'next-version: %s\n' "$*" >&2; exit 1; }
die2() { printf 'next-version: COULD NOT MEASURE - %s\n' "$*" >&2; exit 2; }

CURRENT=""; FROM=""; TO=""; BUMP="auto"
while (( $# > 0 )); do
  case "$1" in
    --current) CURRENT="${2:-}"; shift 2 ;;
    --from)    FROM="${2:-}";    shift 2 ;;
    --to)      TO="${2:-}";      shift 2 ;;
    --bump)    BUMP="${2:-}";    shift 2 ;;
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    *) die1 "unknown argument: $1" ;;
  esac
done

command -v git >/dev/null 2>&1 || die2 "git is missing"
[[ -n "$TO" ]] || die1 "--to <sha> is missing"
[[ -n "$CURRENT" ]] || CURRENT="0.0.0"
[[ "$CURRENT" =~ $SEMVER_RE ]] || die1 "--current '$CURRENT' is not semver x.y.z"
case "$BUMP" in auto|patch|minor|major) ;; *) die1 "--bump '$BUMP' is invalid" ;; esac

git rev-parse -q --verify "$TO^{commit}" >/dev/null 2>&1 || die2 "the sha '$TO' does not resolve to a commit in this clone"

if [[ -n "$FROM" ]]; then
  git rev-parse -q --verify "$FROM^{commit}" >/dev/null 2>&1 || die2 "the base ref '$FROM' does not resolve"
  RANGE="${FROM}..${TO}"
else
  RANGE="$TO"   # full history: first release
fi

# ONE RECORD PER COMMIT, not one line per commit.
# A `git log --format='%H<TAB>%s<TAB>%b'` does NOT produce one line per commit:
# the body carries its own line breaks, so each line of the body was read as if
# it were another commit. MEASURED: a single `docs:` commit whose body contained
# the line `feat!: ...` was counted as 3 commits and forced a MAJOR bump. The
# commit body is untrusted text (it comes from PRs of the knowledge loop), so it
# cannot decide the version.
# Commits are enumerated by SHA first, and subject and body are requested separately.
SHAS=$(git log --no-merges --format='%H' "$RANGE" 2>/dev/null)
LOG_RC=$?
(( LOG_RC == 0 )) || die2 "git log failed over the range '$RANGE'"

COUNT=0
HAS_MAJOR=0
HAS_MINOR=0
while IFS= read -r sha; do
  [[ -n "$sha" ]] || continue
  COUNT=$((COUNT + 1))
  subject=$(git show -s --format='%s' "$sha")
  # the body is flattened to a single line: only a marker is searched inside it.
  body=$(git show -s --format='%b' "$sha" | tr '\r\n' '  ')
  # BREAKING: `type!:` in the subject or `BREAKING CHANGE:` in the body.
  if printf '%s' "$subject" | grep -qE '^[a-zA-Z]+(\([^)]*\))?!:'; then HAS_MAJOR=1; fi
  if printf '%s' "$body" | grep -qE '(^|[[:space:]])BREAKING[ -]CHANGE:'; then HAS_MAJOR=1; fi
  if printf '%s' "$subject" | grep -qE '^feat(\([^)]*\))?!?:'; then HAS_MINOR=1; fi
done <<<"$SHAS"

if (( COUNT == 0 )); then
  printf 'current_version=%s\n' "$CURRENT"
  printf 'next_version=%s\n' "$CURRENT"
  printf 'bump=none\n'
  printf 'commit_count=0\n'
  printf 'next-version: no new commits in %s - nothing to publish\n' "$RANGE" >&2
  exit 1
fi

if [[ "$BUMP" == "auto" ]]; then
  if   (( HAS_MAJOR )); then BUMP="major"
  elif (( HAS_MINOR )); then BUMP="minor"
  else                       BUMP="patch"
  fi
fi

IFS='.' read -r MA MI PA <<<"$CURRENT"
case "$BUMP" in
  major) MA=$((MA + 1)); MI=0; PA=0 ;;
  minor) MI=$((MI + 1)); PA=0 ;;
  patch) PA=$((PA + 1)) ;;
esac
NEXT="${MA}.${MI}.${PA}"

printf 'current_version=%s\n' "$CURRENT"
printf 'next_version=%s\n' "$NEXT"
printf 'bump=%s\n' "$BUMP"
printf 'commit_count=%s\n' "$COUNT"
exit 0
