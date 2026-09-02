#!/usr/bin/env bash
# scripts/gh/competitive-discovery.sh
#
# Asks whether the field this project compares itself against is still the field.
#
# WHY IT EXISTS
#   `competitive-freshness.sh` asks, for each product we measured, whether the
#   commit we pinned is still the tip. That is a good question about a fixed
#   list, and it cannot see the thing it is not looking at: a product that
#   entered the lane after the list was written. The list has been three
#   products since 2026-08-22 and nothing has ever re-opened it.
#
#   Measured on 2026-09-01: three searches of this project's own lane returned
#   `maxgfr/ultrasec` -- MIT, created 2026-06-16, pushed 2026-08-31, an agent
#   skill whose stated purpose is whole-repo cross-file taint security audit,
#   which is this project's exact lane -- and the baseline had never heard of
#   it. Nothing was wrong; nothing was looking. A comparison that only ever
#   re-checks the products it already knows reads, to a reader, as a comparison
#   against the field.
#
# THE BAR, AND WHY IT IS NOT POPULARITY
#   A candidate counts when its default branch carries one of the skill or agent
#   markers named in the baseline. Stars are NOT the bar: the product that
#   motivated this file had zero, and a popularity floor would have hidden it
#   exactly as the closed list did. The bar is "is it the same kind of thing",
#   which is answerable from the tree in one call.
#
# WHAT IT DOES AND DOES NOT SAY
#   It says a candidate is UNRESOLVED: neither pinned in `products` nor written
#   down in `declined`. It does NOT say the candidate is good, comparable on the
#   merits, or worth benchmarking. Those are judgements and they cost model
#   runs; this only refuses to let one pass unnamed. Declining is a first-class
#   answer and costs one line - what it may not be is silence.
#
#   An empty search is rc 2, never rc 0. A search that returns nothing in a lane
#   that provably has products has not established that the field is closed; it
#   has established that the instrument said nothing.
#
# Exit codes: 0 = every candidate is resolved | 1 = at least one is not
#             | 2 = could not measure (no gh/jq, no baseline, no discovery
#                   block, the search did not answer, or the cap was hit before
#                   the queries were exhausted)
#
# Usage:
#   scripts/gh/competitive-discovery.sh
#   scripts/gh/competitive-discovery.sh --baseline path/to/competitive-baseline.json

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$SELF_DIR/../.." && pwd -P)"
BASELINE="$ROOT/docs/competitive-baseline.json"

while [ $# -gt 0 ]; do
  case "$1" in
    --baseline) BASELINE="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,47p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) printf 'COULD NOT MEASURE: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done

for t in gh jq; do
  command -v "$t" >/dev/null 2>&1 || { printf 'COULD NOT MEASURE: %s is missing\n' "$t" >&2; exit 2; }
done
[ -r "$BASELINE" ] || { printf 'COULD NOT MEASURE: cannot read %s\n' "$BASELINE" >&2; exit 2; }

jq -e '.discovery.queries | length > 0' "$BASELINE" >/dev/null 2>&1 || {
  printf 'COULD NOT MEASURE: %s declares no discovery queries, so the lane is undefined\n' "$BASELINE" >&2
  exit 2; }

PER_QUERY="$(jq -r '.discovery.per_query // 8' "$BASELINE")"
MAX="$(jq -r '.discovery.max_candidates // 30' "$BASELINE")"
SELF="$(jq -r '.discovery.self // ""' "$BASELINE")"

printf '\n=== competitive discovery ===\n'
printf 'SCOPE     : is the set of products we compare against still the field?\n'
printf 'BAR       : carries a skill or agent marker. NOT popularity - the product that\n'
printf '            motivated this check had zero stars.\n'
printf 'OUT       : whether a candidate is any good, or comparable on the merits. It may\n'
printf '            be declined in one line; what it may not be is unnamed.\n\n'

# Everything the baseline already has an answer for, in either direction.
known="$(jq -r '[(.products[]?.repo), (.declined[]?.repo)] | .[] | ascii_downcase' "$BASELINE" | sort -u)"
PATTERNS="$(jq -r '.declined_patterns[]?.pattern' "$BASELINE")"

seen=""; found=0; unresolved=0; capped=0; absorbed=0
while IFS= read -r q; do
  [ -n "$q" ] || continue
  hits="$(gh search repos "$q" --limit "$PER_QUERY" --json fullName \
            -q '.[].fullName' 2>/dev/null)" || hits=""
  if [ -z "$hits" ]; then
    printf '  COULD NOT MEASURE  the search for %s returned nothing\n' "$q"
    printf '\n  VERDICT: 2 (a silent instrument is not an empty field)\n'
    exit 2
  fi
  while IFS= read -r repo; do
    [ -n "$repo" ] || continue
    lower="$(printf '%s' "$repo" | tr 'A-Z' 'a-z')"
    [ "$lower" = "$(printf '%s' "$SELF" | tr 'A-Z' 'a-z')" ] && continue
    case " $seen " in *" $lower "*) continue ;; esac
    seen="$seen $lower"
    found=$((found + 1))
    if [ "$found" -gt "$MAX" ]; then capped=1; break 2; fi
    case "$known" in *"$lower"*) continue ;; esac
    # A pattern decline, reported by count. A per-repo line for an auto-generated
    # cluster is how a check becomes noise and stops being read; a pattern that
    # quietly starts eating the lane is how it stops being a check. The count is
    # what keeps the second from happening.
    by_pattern=""
    while IFS= read -r pat; do
      [ -n "$pat" ] || continue
      printf '%s' "$lower" | grep -Eq -- "$pat" && { by_pattern="$pat"; break; }
    done <<< "$PATTERNS"
    if [ -n "$by_pattern" ]; then absorbed=$((absorbed + 1)); continue; fi
    # One call, non-recursive: a marker at the top of the tree is enough to say
    # this is the same kind of artefact, and `skills` catches a nested SKILL.md.
    top="$(gh api "repos/$repo/git/trees/HEAD" --jq '.tree[].path' 2>/dev/null)" || top=""
    [ -n "$top" ] || continue
    marker=""
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      printf '%s\n' "$top" | grep -Fxq -- "$m" && { marker="$m"; break; }
    done < <(jq -r '.discovery.skill_markers[]?' "$BASELINE")
    [ -n "$marker" ] || continue
    unresolved=$((unresolved + 1))
    desc="$(gh api "repos/$repo" --jq '"\(.stargazers_count) stars · pushed \(.pushed_at[0:10]) · \(.description // "no description")"' 2>/dev/null || echo '?')"
    printf '  UNRESOLVED  %s\n              carries `%s` · %s\n' "$repo" "$marker" "${desc:0:150}"
  done <<< "$hits"
done < <(jq -r '.discovery.queries[]' "$BASELINE")

printf '\n  candidates seen %d · absorbed by a written pattern %d · unresolved %d\n' \
  "$found" "$absorbed" "$unresolved"
while IFS=$'\t' read -r pat n; do
  [ -n "$pat" ] || continue
  printf '  pattern covered %s when written: %s\n' "$n" "$pat"
done < <(jq -r '.declined_patterns[]? | "\(.pattern)\t\(.covered_when_written // "?")"' "$BASELINE")

if [ "$capped" -eq 1 ]; then
  printf '  The cap of %d candidates was reached before the queries were exhausted, so this\n' "$MAX"
  printf '  run did not see the whole lane. Raise discovery.max_candidates or narrow the\n'
  printf '  queries; do not read this as a clean result.\n'
  printf '  VERDICT: 2 (COULD NOT MEASURE the whole lane)\n'; exit 2
fi
if [ "$unresolved" -gt 0 ]; then
  printf '  Each one is either a product to pin in `products` or a line in `declined` saying\n'
  printf '  why it is not comparable. Silence is the answer this check exists to refuse.\n'
  printf '  VERDICT: 1 (measured, the field has moved past the list)\n'; exit 1
fi
printf '  VERDICT: 0 (measured, every candidate in the lane is named)\n'
exit 0
