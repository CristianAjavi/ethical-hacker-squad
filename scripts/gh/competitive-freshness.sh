#!/usr/bin/env bash
# scripts/gh/competitive-freshness.sh
#
# Says how old the competitive comparison is, by asking each measured product
# whether it has moved since the commit this project measured it at.
#
# WHY IT EXISTS
#   A comparison is a photograph. README.md carries the sentence this project's
#   whole competitive position rests on - "each of the field's three comparable
#   products falls outside a band somewhere; this corpus falls outside none" -
#   and it names the commit each product was measured at. What it does not carry
#   is a date, or any signal that the subject has moved since.
#
#   Measured on 2026-08-24, two of the three pins were already behind their
#   repository's HEAD, and both had been pushed that same day. Nothing in the
#   repository said so.
#
# WHAT IT DOES AND DOES NOT SAY
#   It answers ONE question: is the commit we measured still the tip? A product
#   that has moved has not necessarily got better, and this makes no claim that
#   it has. It says the photograph is old, which is the thing a reader cannot
#   otherwise tell.
#
#   Re-measuring is not this script's job and cannot be: that needs the harness
#   and model runs, and it is a decision about spend.
#
# Exit codes: 0 = every pin is still the tip | 1 = at least one has moved
#             | 2 = could not measure (no gh, no baseline, a repo that 404s)
#
# Usage:
#   scripts/gh/competitive-freshness.sh
#   scripts/gh/competitive-freshness.sh --baseline path/to/competitive-baseline.json

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$SELF_DIR/../.." && pwd -P)"
BASELINE="$ROOT/docs/competitive-baseline.json"

while [ $# -gt 0 ]; do
  case "$1" in
    --baseline) BASELINE="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) printf 'COULD NOT MEASURE: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done

for t in gh jq; do
  command -v "$t" >/dev/null 2>&1 || { printf 'COULD NOT MEASURE: %s is missing\n' "$t" >&2; exit 2; }
done
[ -r "$BASELINE" ] || { printf 'COULD NOT MEASURE: cannot read %s\n' "$BASELINE" >&2; exit 2; }

MEASURED_ON="$(jq -r '.measured_on // "unknown"' "$BASELINE")"
printf '\n=== competitive freshness ===\n'
printf 'MEASURED  : %s\n' "$MEASURED_ON"
printf 'SCOPE     : for each comparable product, is the commit we measured still the tip?\n'
printf 'OUT       : whether a product that moved got BETTER. Re-measuring needs the harness\n'
printf '            and model runs; this only says the photograph is old.\n\n'

moved=0; same=0; unmeas=0
while IFS=$'\t' read -r repo pinned; do
  [ -n "$repo" ] || continue
  head="$(gh api "repos/$repo/commits?per_page=1" --jq '.[0].sha' 2>/dev/null)"
  if [ -z "$head" ]; then
    printf '  COULD NOT MEASURE  %-32s the repository did not answer\n' "$repo"
    unmeas=$((unmeas + 1)); continue
  fi
  short="$(printf '%s' "$head" | cut -c1-7)"
  if [ "$short" = "$pinned" ]; then
    printf '  still the tip      %-32s %s\n' "$repo" "$pinned"
    same=$((same + 1))
  else
    pushed="$(gh api "repos/$repo" --jq '.pushed_at[0:10]' 2>/dev/null || echo '?')"
    printf '  MOVED              %-32s measured %s, now %s (pushed %s)\n' "$repo" "$pinned" "$short" "$pushed"
    moved=$((moved + 1))
  fi
done < <(jq -r '.products[] | select(.comparable and .pinned != null) | "\(.repo)\t\(.pinned)"' "$BASELINE")

printf '\n  still the tip %d · moved %d · could not measure %d\n' "$same" "$moved" "$unmeas"

if [ "$unmeas" -gt 0 ] && [ "$moved" -eq 0 ]; then
  printf '  VERDICT: 2 (COULD NOT MEASURE every product - this is not a pass)\n'; exit 2
fi
if [ "$moved" -gt 0 ]; then
  printf '  The comparison in README.md was taken on %s and %d of its subjects have moved since.\n' "$MEASURED_ON" "$moved"
  printf '  That does not make the numbers wrong; it makes them a photograph with a date.\n'
  printf '  VERDICT: 1 (measured, the comparison is stale)\n'; exit 1
fi
printf '  VERDICT: 0 (measured, every pin is still the tip)\n'
exit 0
