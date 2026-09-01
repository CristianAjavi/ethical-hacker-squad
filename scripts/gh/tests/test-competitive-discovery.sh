#!/usr/bin/env bash
# Tests scripts/gh/competitive-discovery.sh against a GitHub API double.
#
# The case that matters is `new-product-in-the-lane`. On 2026-09-01 the lane
# held maxgfr/ultrasec - MIT, this project's exact purpose, pushed two days
# earlier - and docs/competitive-baseline.json had never heard of it, because
# competitive-freshness.sh only ever re-checks the products already on the list.
# A check that cannot tell a new entrant from a known one is worth nothing.
#
# `zero-stars-still-counts` is the second: the product that motivated the file
# had none, so a popularity floor would have hidden it exactly as the closed
# list did, and this proves the bar is the marker and not the stars.
#
# Zero network.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

SP="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd -- "$SP/../../.." && pwd -P)"
TOOL="$ROOT/scripts/gh/competitive-discovery.sh"
[ -f "$TOOL" ] || { echo "  COULD NOT MEASURE: competitive-discovery.sh is missing (rc 2)"; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "  COULD NOT MEASURE: jq is missing (rc 2)"; exit 2; }

LAB="$(mktemp -d)"; trap 'rm -rf "$LAB"' EXIT
mkdir -p "$LAB/bin"
pass=0; fail=0

# The double. HITS names what the search returns; MARKED names the repos whose
# tree carries a marker. Everything else answers, but with a bare tree.
cat > "$LAB/bin/gh" <<'GH'
#!/usr/bin/env bash
sub=""; path=""; q=""; jqf=""; want=""
for a in "$@"; do
  case "$want" in jq) jqf="$a"; want=""; continue ;; skip) want=""; continue ;; esac
  case "$a" in
    --jq|-q) want=jq ;;
    --limit|--json) want=skip ;;
    -*) ;;
    search|api) [ -z "$sub" ] && sub="$a" ;;
    repos) [ "$sub" = search ] && continue || path="$a" ;;
    *) if [ "$sub" = search ] && [ -z "$q" ]; then q="$a"; elif [ -z "$path" ]; then path="$a"; fi ;;
  esac
done
emit() { if [ -n "$jqf" ]; then printf '%s' "$1" | jq -r "$jqf"; else printf '%s\n' "$1"; fi; }
if [ "$sub" = search ]; then
  [ "${EMPTY_SEARCH:-0}" = 1 ] && exit 0
  body="[]"; for r in $HITS; do body="$(printf '%s' "$body" | jq -c --arg r "$r" '. + [{fullName:$r}]')"; done
  emit "$body"; exit 0
fi
case "$path" in
  */git/trees/HEAD)
    repo="${path#repos/}"; repo="${repo%/git/trees/HEAD}"
    case " $MARKED " in
      *" $repo "*) emit '{"tree":[{"path":"README.md"},{"path":"SKILL.md"}]}' ;;
      *)           emit '{"tree":[{"path":"README.md"},{"path":"src"}]}' ;;
    esac ;;
  repos/*) emit '{"stargazers_count":0,"pushed_at":"2026-09-01T00:00:00Z","description":"d"}' ;;
  *) exit 1 ;;
esac
GH
chmod +x "$LAB/bin/gh"

base() {  # base <extra-json>
  local extra="${1-}"; [ -n "$extra" ] || extra='{}'
  jq -n --argjson extra "$extra" '{
    measured_on: "2026-01-01",
    products: [ { repo: "org/known", pinned: "aaaaaaa", comparable: true, rounds: [] } ],
    declined: [],
    declined_patterns: [],
    discovery: { queries: ["q one"], per_query: 8, max_candidates: 30,
                 skill_markers: ["SKILL.md"], self: "us/ours" } } * $extra' > "$LAB/baseline.json"
}

case_run() {  # case_run <name> <want-rc> <needle> <hits> <marked> [env...]
  local name="$1" want="$2" needle="$3" hits="$4" marked="$5"; shift 5
  local out rc
  out="$(env "$@" PATH="$LAB/bin:$PATH" HITS="$hits" MARKED="$marked" \
         bash "$TOOL" --baseline "$LAB/baseline.json" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf '  ok       %-34s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf '  FAILED   %-34s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/           /' | tail -6; fail=$((fail+1))
  fi
}

echo "=== self-test: competitive-discovery.sh (zero network) ==="

base
case_run everything-already-named 0 "every candidate in the lane is named" \
  "org/known" "org/known"

# The defect this file exists for.
case_run new-product-in-the-lane 1 "UNRESOLVED  org/newcomer" \
  "org/known org/newcomer" "org/known org/newcomer"

# The bar is the marker. A repo in the search results with no skill marker is
# not a candidate, however it ranks.
case_run no-marker-is-not-a-candidate 0 "unresolved 0" \
  "org/known org/plainrepo" "org/known"

# ...and the marker is enough on its own: zero stars must still fail, because
# the product that motivated this check had none.
case_run zero-stars-still-counts 1 "UNRESOLVED  org/tiny" \
  "org/known org/tiny" "org/known org/tiny"

# Our own repository is never a candidate against itself.
case_run self-is-never-a-candidate 0 "unresolved 0" \
  "org/known us/ours" "org/known us/ours"

base '{"declined":[{"repo":"org/newcomer","seen":"2026-09-01","reason":"different class"}]}'
case_run a-written-decline-resolves-it 0 "unresolved 0" \
  "org/known org/newcomer" "org/known org/newcomer"

base '{"declined_patterns":[{"pattern":"^org/farm-[0-9]+$","seen":"2026-09-01","covered_when_written":2,"reason":"cluster"}]}'
case_run a-pattern-absorbs-a-cluster 0 "absorbed by a written pattern 2" \
  "org/known org/farm-1 org/farm-2" "org/known org/farm-1 org/farm-2"

# ...but a pattern may not absorb what it does not match.
case_run a-pattern-does-not-absorb-the-rest 1 "UNRESOLVED  org/real" \
  "org/known org/farm-1 org/real" "org/known org/farm-1 org/real"

# A silent instrument is not an empty field. This is the rule that fires when a
# query dies, and it fired on the first real run.
base
case_run empty-search-is-not-a-clean-field 2 "silent instrument" \
  "org/known" "org/known" EMPTY_SEARCH=1

# The cap is a cost ceiling, and hitting it means the lane was not seen whole.
base '{"discovery":{"max_candidates":1}}'
case_run cap-reached-is-not-a-pass 2 "COULD NOT MEASURE the whole lane" \
  "org/known org/newcomer org/third" "org/newcomer org/third"

# No lane declared at all: the check cannot run, and must not say it did.
jq 'del(.discovery)' "$LAB/baseline.json" > "$LAB/b2.json" && mv "$LAB/b2.json" "$LAB/baseline.json"
case_run no-lane-declared 2 "declares no discovery queries" "org/known" "org/known"

printf '\n  Summary: %d ok, %d failures\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
echo "  Result: OK. The check names a new entrant, ignores what is not the same kind of"
echo "          thing, honours a written decline, and never reads silence as a clean field."
exit 0
