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
# THE SECOND BLINDNESS, MEASURED ON 2026-09-10
#   The first blindness was a closed list. This one is in the sweep itself.
#   `gh search repos <words>` ranks on the words in a repository's name and
#   description, so a product owned by an organisation and named `skills` is
#   invisible to every phrasing of this lane, however large it is. Measured:
#   the five text queries in place returned 39 distinct repositories and not one
#   of them was `trailofbits/skills` (7,033 stars, Claude Code skills for
#   vulnerability detection and audit workflows) or `cloudflare/security-audit-
#   skill` (3,267 stars, MIT). The run before that one had exited 0 - every
#   candidate in the lane is named - and the sentence was true about the
#   candidates it saw and false about the lane.
#
#   Two things follow, and only together.
#
#   1. A topic-qualified sweep. `topic_queries` pairs a term with a GitHub topic,
#      which is metadata the owner sets rather than prose the ranker reads, and
#      it is how a generically named repository becomes reachable at all.
#   2. Known-positive controls. `discovery.controls` names products this file
#      has already resolved as being in the lane and that the sweep must return.
#      A control that comes back missing does not mean the product is gone; it
#      means this instrument can no longer see a thing it is pointed at, and
#      nothing it says about the rest of the lane survives that. The run exits 2.
#      Without controls, "no new entrant" and "I could not see" produce the same
#      exit code, which is the failure this check was built to refuse one level
#      up. A zero of a blind instrument is not a zero.
#
#   Controls take precedence over an unresolved candidate: an unresolved name is
#   a fact about the list, an unseen control is a fact about the instrument the
#   list-fact was derived from. The unresolved names are still printed, marked
#   provisional, because they are real; the verdict is 2 because the set they
#   belong to was not established.
#
# THE BAR, AND WHY IT IS NOT POPULARITY
#   A candidate counts when its default branch carries one of the skill or agent
#   markers named in the baseline. Stars are NOT the bar: the product that
#   motivated this file had zero, and a popularity floor would have hidden it
#   exactly as the closed list did. The bar is "is it the same kind of thing",
#   which is answerable from the tree in one call.
#
#   A topic sweep orders by stars, and that is not a popularity bar creeping in
#   through the ordering: every candidate it surfaces still has to carry a
#   marker, and a zero-star repository that carries one is a candidate exactly as
#   before. Stars decide who gets looked at first inside one query's limit, never
#   who counts - and the text queries, which are not star-ordered, keep the tail
#   reachable.
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
#                   block, the search did not answer, the cap was hit before the
#                   queries were exhausted, or a declared control was not
#                   returned by any query - the sweep is blind and its silence
#                   about everything else proves nothing)
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
CONTROLS="$(jq -r '.discovery.controls[]?.repo | ascii_downcase' "$BASELINE")"

printf '\n=== competitive discovery ===\n'
printf 'SCOPE     : is the set of products we compare against still the field?\n'
printf 'BAR       : carries a skill or agent marker. NOT popularity - the product that\n'
printf '            motivated this check had zero stars.\n'
printf 'OUT       : whether a candidate is any good, or comparable on the merits. It may\n'
printf '            be declined in one line; what it may not be is unnamed.\n\n'

# Everything the baseline already has an answer for, in either direction.
known="$(jq -r '[(.products[]?.repo), (.declined[]?.repo)] | .[] | ascii_downcase' "$BASELINE" | sort -u)"
PATTERNS="$(jq -r '.declined_patterns[]?.pattern' "$BASELINE")"

NL=$'\n'

# One line per sweep: KIND<TAB>TERM<TAB>TOPIC. A text query and a topic query
# differ only in the arguments handed to `gh search`, so they share the body -
# the counters, the cap and the marker test have to be the same for both or the
# two halves of the lane are not measured the same way.
SPECS="$( { jq -r '.discovery.queries[]? | "text\t\(.)\t"' "$BASELINE";
            jq -r '.discovery.topic_queries[]? | "topic\t\(.term)\t\(.topic)"' "$BASELINE"; } )"

# The bar itself. With no marker declared, nothing can ever match and the run
# would end at `unresolved 0` -- a verdict of "the lane is named" produced by an
# instrument with nothing to look for.
MARKERS="$(jq -r '.discovery.skill_markers[]?' "$BASELINE")"
[ -n "$MARKERS" ] || {
  printf 'COULD NOT MEASURE: %s declares no discovery.skill_markers, so nothing can match\n' "$BASELINE" >&2
  exit 2; }

# Reads paths on stdin, prints `MARKER<TAB>WHERE` for the first hit and nothing
# for none. The SCOPE of each marker is derived from the marker, so the baseline
# stays the only place that names one:
#
#   A marker carrying a dot -- `SKILL.md`, `.claude-plugin` -- is a name nobody
#   reaches for by accident, so it counts at any depth.
#
#   A marker that is an ordinary English word -- `agents`, `skills` -- counts
#   only at the repository root, under `.claude/`, or under `plugins/<x>/`: the
#   three places where packaging is the directory's only job. Without that
#   bound, `backend/app/agents/__init__.py` and
#   `mcpx/packages/mcpx-server/src/services/skills` -- a Python package and a
#   TypeScript service, both measured in the real sweep -- would read as
#   competitors, which is the same failure as the old line in the other
#   direction: a rule with more reach than it is owed. This bound is the ONLY
#   thing deciding it. A second filter that also excluded any path under
#   `src/`, `backend/` and friends was written first and then removed, because
#   no case could make it fail: the bound had already answered, so the filter
#   was cover, not measurement -- and it would have thrown out a legitimate
#   plugin named `api`.
#
#   And a marker that only ever appears under `fixtures/`, `evals/`, `tests/`
#   and their kin is the material a scanner is FED, not the product. Four real
#   candidates are exactly that -- a skill scanner's eval corpus, a guard's test
#   fixtures. Counting them counts the judge as the subject.
#
# The marker list travels in the environment, not in `-v`: awk runs escape
# processing on a `-v` assignment and the BSD awk on macOS dies outright on the
# newline between two markers ("newline in string"). It dies to stderr and the
# function then prints nothing, which this file reads as "carries no marker" --
# a silent zero from a crashed instrument. Measured: with `-v`, 0 of 98 real
# candidates matched; through ENVIRON, 55.
marker_hit() {
  EHS_MARKERS="$1" awk '
    BEGIN {
      n = split(ENVIRON["EHS_MARKERS"], M, "\n")
      split("fixtures fixture test tests testdata test-data eval evals bench \
             benchmarks sd-bench samples examples example corpus corpora \
             node_modules vendor third_party dist build", C, /[ \t\n]+/)
      for (i in C) if (C[i] != "") CORPUS[C[i]] = 1
    }
    {
      d = split($0, S, "/")
      corpus = 0
      for (i = 1; i < d; i++) if (tolower(S[i]) in CORPUS) corpus = 1
      if (corpus) next
      for (j = 1; j <= n; j++) {
        m = M[j]; if (m == "") continue
        for (i = 1; i <= d; i++) {
          if (S[i] != m) continue
          if (index(m, ".") > 0) { print m "\t" $0; exit }
          if (i == 1 || (i == 2 && S[1] == ".claude") || (i == 3 && S[1] == "plugins")) {
            w = S[1]; for (k = 2; k <= i; k++) w = w "/" S[k]
            print m "\t" w; exit
          }
        }
      }
    }'
}

seen=""; found=0; unresolved=0; capped=0; absorbed=0; provisional=""; blind=0
while IFS=$'\t' read -r kind q topic; do
  [ -n "$q" ] || continue
  case "$kind" in
    topic) label="$q +topic:$topic"
           hits="$(gh search repos "$q" --topic "$topic" --sort stars \
                     --limit "$PER_QUERY" --json fullName -q '.[].fullName' 2>/dev/null)" || hits="" ;;
    *)     label="$q"
           hits="$(gh search repos "$q" --limit "$PER_QUERY" --json fullName \
                     -q '.[].fullName' 2>/dev/null)" || hits="" ;;
  esac
  if [ -z "$hits" ]; then
    printf '  COULD NOT MEASURE  the search for %s returned nothing\n' "$label"
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
    # EXACT repo name, not substring. `$known` is a newline-joined blob, so
    # `*"$lower"*` made the candidate `acme/scanner` count as already known
    # because the blob held `acme/scanner-pro`. The `seen` guard four lines up
    # already compares the delimited way; this one did not.
    case "$NL$known$NL" in *"$NL$lower$NL"*) continue ;; esac
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
    # One call, RECURSIVE, and the marker is matched as a path SEGMENT at the
    # depth where that marker means something. The old line read a NON-recursive
    # tree, so it only ever saw the top level. Measured on 2026-09-10 over the 98
    # repositories this file's own queries return, that cost thirteen products of
    # this exact lane -- packaged as `.claude/skills`, `.claude/agents`,
    # `<skill-name>/SKILL.md`, `plugins/<x>/skills/<y>/SKILL.md` or
    # `compliance/auditing/<x>/SKILL.md` -- and it cost them through `continue`,
    # which is to say in silence.
    tree_rc=0
    tree_json="$(gh api "repos/$repo/git/trees/HEAD?recursive=1" 2>/dev/null)" || tree_rc=$?
    paths="$(printf '%s' "$tree_json" | jq -r '.tree[]?.path' 2>/dev/null)"
    if [ "$tree_rc" -ne 0 ] || [ -z "$paths" ]; then
      # A silent instrument is not an empty field. This used to `continue`, so a
      # rate-limited run - one call per candidate, up to max_candidates of them -
      # dropped every candidate and still printed "every candidate in the lane is
      # named".
      printf '  COULD NOT MEASURE  %s did not answer for its tree; I cannot say what it carries\n' "$repo"
      blind=$((blind + 1))
      continue
    fi
    hit="$(printf '%s\n' "$paths" | marker_hit "$MARKERS")"
    marker="${hit%%$'\t'*}"
    if [ -z "$marker" ]; then
      # A tree GitHub would not hand over whole cannot establish an absence
      # either. The old code could not reach this branch: a non-recursive tree is
      # never truncated, so the one candidate whose packaging is too deep to see
      # was indistinguishable from one that carries nothing.
      if [ "$(printf '%s' "$tree_json" | jq -r '.truncated // false' 2>/dev/null)" = true ]; then
        printf '  COULD NOT MEASURE  %s has a tree too large to read whole; I cannot say it\n' "$repo"
        printf '                     carries no marker, only that I did not reach one\n'
        blind=$((blind + 1))
      fi
      continue
    fi
    where="${hit#*$'\t'}"
    unresolved=$((unresolved + 1))
    provisional="$provisional $repo"
    desc="$(gh api "repos/$repo" --jq '"\(.stargazers_count) stars · pushed \(.pushed_at[0:10]) · \(.description // "no description")"' 2>/dev/null || echo '?')"
    printf '  UNRESOLVED  %s\n              carries `%s` at `%s` · %s\n' "$repo" "$marker" "$where" "${desc:0:150}"
  done <<< "$hits"
done <<< "$SPECS"

printf '\n  candidates seen %d · absorbed by a written pattern %d · unresolved %d · unreadable %d\n' \
  "$found" "$absorbed" "$unresolved" "$blind"
while IFS=$'\t' read -r pat n; do
  [ -n "$pat" ] || continue
  printf '  pattern covered %s when written: %s\n' "$n" "$pat"
done < <(jq -r '.declined_patterns[]? | "\(.pattern)\t\(.covered_when_written // "?")"' "$BASELINE")

# The controls. Checked against what the sweep SAW, before any of the reasons a
# candidate is dropped afterwards - a control is a question about visibility, not
# about whether it would have counted.
missing_controls=""; n_controls=0
while IFS= read -r c; do
  [ -n "$c" ] || continue
  n_controls=$((n_controls + 1))
  case " $seen " in *" $c "*) ;; *) missing_controls="$missing_controls $c" ;; esac
done <<< "$CONTROLS"
if [ "$n_controls" -eq 0 ]; then
  printf '  no controls declared - this run cannot tell an empty lane from a blind sweep\n'
else
  printf '  controls seen %d of %d\n' "$((n_controls - $(printf '%s' "$missing_controls" | wc -w | tr -d ' ')))" "$n_controls"
fi
if [ -n "$missing_controls" ]; then
  for c in $missing_controls; do
    printf '  BLIND      no query returned %s, a product this file already names\n' "$c"
  done
  printf '  The sweep cannot see something it is pointed at, so it has established nothing\n'
  printf '  about what it did not return. Fix the queries, not this line.\n'
  [ -n "$provisional" ] && printf '  Provisional (real, but from an incomplete sweep):%s\n' "$provisional"
  printf '  VERDICT: 2 (COULD NOT MEASURE - a control was invisible)\n'; exit 2
fi

if [ "$capped" -eq 1 ]; then
  printf '  The cap of %d candidates was reached before the queries were exhausted, so this\n' "$MAX"
  printf '  run did not see the whole lane. Raise discovery.max_candidates or narrow the\n'
  printf '  queries; do not read this as a clean result.\n'
  printf '  VERDICT: 2 (COULD NOT MEASURE the whole lane)\n'; exit 2
fi
if [ "$blind" -gt 0 ]; then
  printf '  %d candidate(s) could not be read whole, or at all. A candidate nobody could look\n' "$blind"
  printf '  at is not a candidate that carries nothing, and this run may not be read as one.\n'
  printf '  VERDICT: 2 (COULD NOT MEASURE every candidate)\n'; exit 2
fi
if [ "$unresolved" -gt 0 ]; then
  printf '  Each one is either a product to pin in `products` or a line in `declined` saying\n'
  printf '  why it is not comparable. Silence is the answer this check exists to refuse.\n'
  printf '  VERDICT: 1 (measured, the field has moved past the list)\n'; exit 1
fi
printf '  VERDICT: 0 (measured, every candidate in the lane is named)\n'
exit 0
