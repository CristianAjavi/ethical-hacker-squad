#!/usr/bin/env bash
# scripts/gh/competitive-freshness.sh
#
# Says how old the competitive comparison is, by asking each measured product
# whether it has moved since the commit this project measured it at - and, when
# it has moved, whether anybody read the move.
#
# WHY IT EXISTS
#   A comparison is a photograph. README.md carries the sentence this project's
#   whole competitive position rests on - "each of the field's three comparable
#   products falls outside a band somewhere; this corpus falls outside none" -
#   and it names the commit each product was measured at. What it did not carry
#   is a date, or any signal that the subject has moved since.
#
#   Measured on 2026-08-24, two of the three pins were already behind their
#   repository's HEAD, and both had been pushed that same day. Nothing in the
#   repository said so.
#
# THE ACKNOWLEDGEMENT, ADDED 2026-09-10
#   Until this change the only question was "is the pin still the tip?". So a
#   product that moved went red for good: nothing a reader could do made it
#   green again, because re-measuring needs the harness and model runs. That is
#   the shape #83 already found in G7 - a control that shouts on every run and
#   blocks nothing is a control people stop reading - and on 2026-09-10 four of
#   the nine pinned products were in exactly that state.
#
#   The fix is not an exemption and not a list of tolerated repositories. It is
#   a third state the baseline can hold, two fields per product:
#
#     "reviewed_head" - the commit of the OTHER repository somebody read
#     "reviewed_at"   - the day they read it
#
#   Writing them asserts one thing: the diff between `pinned` and
#   `reviewed_head` was read, and it changes no cell of the comparison in
#   README.md. If it HAD changed a cell, the answer is a re-measurement that
#   moves `pinned` - not an acknowledgement.
#
#   The acknowledgement expires by construction. It names a commit, so the first
#   push past it puts the product back in red with nobody deciding to. That is
#   the entire mechanism, and it is why this is not an exemption: an exemption
#   is open-ended and a commit is not.
#
# WHAT IT DOES AND DOES NOT SAY
#   It does NOT measure that the reading happened. `reviewed_head` is a sentence
#   a human wrote, and no script can verify that a human read a diff. What it
#   does guarantee is that the claim is SPECIFIC - a commit, not "we looked" -
#   and that it dies on its own the moment the subject moves again.
#
#   A product that has moved has not necessarily got better, and this makes no
#   claim that it has. Re-measuring is not this script's job and cannot be.
#
#   `reviewed_at` is an ACKNOWLEDGEMENT, never a measurement. `measured_on` at
#   the top of the baseline is the date of the last real measurement; this
#   script does not read it for a verdict and never writes it. Stamping today
#   there because somebody read a diff is how a photograph acquires a false
#   date, which is the failure this whole file exists against.
#
# Exit codes: 0 = every pin is still the tip, or the moves are acknowledged and
#                 the acknowledgements are still current
#             1 = MEASURED RED: a product moved with no acknowledgement, or
#                 moved PAST the commit that was acknowledged
#             2 = could not measure (no gh, no baseline, a repo that 404s, or an
#                 acknowledgement this script cannot read). Never a pass.
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
    -h|--help) sed -n '2,67p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) printf 'COULD NOT MEASURE: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done

for t in gh jq; do
  command -v "$t" >/dev/null 2>&1 || { printf 'COULD NOT MEASURE: %s is missing\n' "$t" >&2; exit 2; }
done
[ -r "$BASELINE" ] || { printf 'COULD NOT MEASURE: cannot read %s\n' "$BASELINE" >&2; exit 2; }

MEASURED_ON="$(jq -r '.measured_on // "unknown"' "$BASELINE")"
printf '\n=== competitive freshness ===\n'
printf 'MEASURED  : %s  (the last real measurement; an acknowledgement never moves this)\n' "$MEASURED_ON"
printf 'SCOPE     : for each comparable product, is the commit we measured still the tip?\n'
printf '            If it is not, does the baseline acknowledge the move, and is that\n'
printf '            acknowledgement still current?\n'
printf 'OUT       : whether a product that moved got BETTER, and whether anyone truly read\n'
printf '            the diff. reviewed_head is a claim a human wrote; what this checks is\n'
printf '            that the claim names a commit and expires when the subject moves on.\n\n'

moved=0; same=0; unmeas=0; acked=0
# The separator is US (0x1f) and not a tab. A tab is IFS WHITESPACE, so bash
# collapses a run of them into one delimiter: a product with `reviewed_head`
# absent and `reviewed_at` present arrived here with the DATE sitting in
# `rhead`, and the tool reported "reviewed_head 2026-09-10 without a
# reviewed_at" - the right exit code for the wrong reason, which is the failure
# this whole file is written against. Found by the battery, not by reading.
while IFS=$'\037' read -r repo pinned rhead rat; do
  [ -n "$repo" ] || continue
  head="$(gh api "repos/$repo/commits?per_page=1" --jq '.[0].sha' 2>/dev/null)"
  if [ -z "$head" ]; then
    printf '  COULD NOT MEASURE  %-46s the repository did not answer\n' "$repo"
    unmeas=$((unmeas + 1)); continue
  fi
  short="$(printf '%s' "$head" | cut -c1-7)"

  if [ "$short" = "$pinned" ]; then
    printf '  still the tip      %-46s %s\n' "$repo" "$pinned"
    same=$((same + 1)); continue
  fi

  # From here the product HAS moved. The only question left is what the baseline
  # says about the move.
  pushed="$(gh api "repos/$repo" --jq '.pushed_at[0:10]' 2>/dev/null || echo '?')"

  if [ -z "$rhead" ] && [ -z "$rat" ]; then
    printf '  MOVED              %-46s measured %s, now %s (pushed %s)\n' "$repo" "$pinned" "$short" "$pushed"
    printf '                     nobody has recorded reading this move: no reviewed_head, no reviewed_at\n'
    moved=$((moved + 1)); continue
  fi

  # Half an acknowledgement is not an acknowledgement, and it is the one shape
  # that could turn into a false green: a reviewed_head matching HEAD with no
  # date would print the note and pass. It answers 2 instead.
  if [ -z "$rhead" ]; then
    printf '  COULD NOT MEASURE  %-46s reviewed_at %s without a reviewed_head - a date that\n' "$repo" "$rat"
    printf '                     acknowledges no commit cannot expire, so it cannot be read\n'
    unmeas=$((unmeas + 1)); continue
  fi
  if [ -z "$rat" ]; then
    printf '  COULD NOT MEASURE  %-46s reviewed_head %s without a reviewed_at - an\n' "$repo" "$rhead"
    printf '                     acknowledgement with no date is not an acknowledgement\n'
    unmeas=$((unmeas + 1)); continue
  fi
  if [[ ! "$rhead" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
    printf '  COULD NOT MEASURE  %-46s reviewed_head is not a commit: %s\n' "$repo" "$rhead"
    unmeas=$((unmeas + 1)); continue
  fi
  if [[ ! "$rat" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    printf '  COULD NOT MEASURE  %-46s reviewed_at is not an ISO date: %s\n' "$repo" "$rat"
    unmeas=$((unmeas + 1)); continue
  fi

  rshort="$(printf '%s' "$rhead" | cut -c1-7)"
  if [ "$rshort" = "$short" ]; then
    printf '  moved, read        %-46s %s -> %s\n' "$repo" "$pinned" "$short"
    printf '                     it moved, it was read on %s, and it changes no cell of the comparison\n' "$rat"
    acked=$((acked + 1)); continue
  fi

  printf '  MOVED PAST THE ACK %-46s acknowledged %s on %s, now %s (pushed %s)\n' \
    "$repo" "$rshort" "$rat" "$short" "$pushed"
  printf '                     the reading is spent: the subject moved again after it\n'
  moved=$((moved + 1))
done < <(jq -r '
  .products[]
  | select(.comparable and .pinned != null)
  | [ .repo, .pinned, (.reviewed_head // ""), (.reviewed_at // "") ]
  | join("\u001f")' "$BASELINE")

printf '\n  still the tip %d · moved and read %d · MOVED %d · could not measure %d\n' \
  "$same" "$acked" "$moved" "$unmeas"

# A verdict over zero subjects is not a verdict. labels.sh already refuses this
# exact shape - "an rc=0 that meant I reviewed nothing" - and so does
# scripts/run-batteries.sh. This loop runs zero times whenever the baseline loses
# `products`, or no entry is both `comparable` and `pinned`, and the fall-through
# was VERDICT 0.
if [ $((same + moved + unmeas)) -eq 0 ]; then
  printf '  %s declares no product that is both `comparable` and `pinned`, so this run\n' "$BASELINE"
  printf '  compared nothing. "Every pin is still the tip" over zero pins is not a pass.\n'
  printf '  VERDICT: 2 (COULD NOT MEASURE - there was nothing to compare)\n'
  exit 2
fi

# A pin is not a measurement. competitive-discovery.sh added six comparable
# products on 2026-09-01 that have never been run, and a freshness report that
# lists them beside the benchmarked three would read as though it had.
never="$(jq -r '[.products[] | select(.comparable and (.benchmarked == false))] | length' "$BASELINE" 2>/dev/null || echo 0)"
if [ "${never:-0}" -gt 0 ]; then
  printf '  %s comparable product(s) are PINNED BUT NEVER BENCHMARKED - a pin says where to look,\n' "$never"
  printf '  not what was found. They are named in the baseline with `benchmarked: false`:\n'
  jq -r '.products[] | select(.comparable and (.benchmarked == false)) | "    " + .repo' "$BASELINE"
fi

if [ "$unmeas" -gt 0 ] && [ "$moved" -eq 0 ]; then
  printf '  VERDICT: 2 (COULD NOT MEASURE - this is not a pass)\n'; exit 2
fi
if [ "$moved" -gt 0 ]; then
  printf '  The comparison in README.md was taken on %s and %d of its subjects have moved\n' "$MEASURED_ON" "$moved"
  printf '  past what the baseline acknowledges. That does not make the numbers wrong; it\n'
  printf '  makes them a photograph with a date. Either read the diff and record the commit\n'
  printf '  in reviewed_head/reviewed_at, or re-measure and move the pin itself.\n'
  printf '  VERDICT: 1 (measured, the comparison is stale)\n'; exit 1
fi
if [ "$acked" -gt 0 ]; then
  printf '  %d product(s) moved and were read: the acknowledgement names the commit, so the\n' "$acked"
  printf '  next push past it turns this red again with nobody deciding to. It is a receipt\n'
  printf '  with an expiry date, not an exemption - and it is NOT a re-measurement.\n'
fi
printf '  VERDICT: 0 (measured, every pin is still the tip or its move is acknowledged)\n'
exit 0
