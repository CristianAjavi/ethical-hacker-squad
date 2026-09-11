#!/usr/bin/env bash
# Self-test for gate-discovery-controls.sh.
#
# Every case is a mutation of a baseline that passes, because the only evidence
# that a gate measures anything is that it goes red when the thing it watches is
# broken - and the thing it watches here is a control block, which is itself a
# device for not trusting a green. The last case is the one that matters in the
# other direction: the repository's real baseline has to pass, or the rule is one
# nobody can satisfy.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-discovery-controls.sh"
REAL="$(cd "$HERE/../.." && pwd)/docs/competitive-baseline.json"
command -v jq >/dev/null 2>&1 || { echo "UNMEASURABLE jq is missing"; exit 2; }
[ -f "$GATE" ] || { echo "UNMEASURABLE the gate is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-disc-controls-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# A minimal baseline that satisfies every rule. Mutants are jq edits of this.
base() {
  jq -n '{
    products: [ { repo: "org/one", pinned: "aaaaaaa" }, { repo: "org/two", pinned: "bbbbbbb" } ],
    declined: [ { repo: "org/three", reason: "different class" } ],
    discovery: {
      queries: ["first query", "second query"],
      topic_queries: [ { term: "security", topic: "agent-skills" } ],
      controls: [ { repo: "org/one", found_by: "first query", why: "w" },
                  { repo: "org/three", found_by: "security +topic:agent-skills", why: "w" } ],
      per_query: 8,
      max_candidates: 24,
      self: "us/ours"
    } }' > "$TMP/b.json"
}

# case_run <name> <want-rc> <needle> [jq-mutation]
case_run() {
  local name="$1" want="$2" needle="$3" mut="${4-}"
  base
  if [ -n "$mut" ]; then jq "$mut" "$TMP/b.json" > "$TMP/m.json" && mv "$TMP/m.json" "$TMP/b.json"; fi
  local out rc
  out="$(bash "$GATE" --baseline "$TMP/b.json" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf 'ok       %-34s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-34s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -6; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-discovery-controls.sh ==="

case_run a-wired-probe-passes 0 "every control is resolved"

# C1 - the mutation that produced the defect this gate exists for: the controls
# go away and the sweep is blind again, with nothing red to say so.
case_run no-controls-at-all      1 "cannot tell an empty lane" 'del(.discovery.controls)'
case_run controls-emptied-out    1 "no control is declared"    '.discovery.controls = []'

# C2 - a control the file has never resolved is a candidate wearing a label.
case_run control-not-resolved    1 "not named in products or declined" \
  '.discovery.controls[0].repo = "org/never-heard-of"'

# C3 - a control wired to nothing, or to a query that was deleted.
case_run control-without-found-by 1 "declares no found_by" 'del(.discovery.controls[0].found_by)'
case_run found-by-names-no-query  1 "is not one of the declared queries" \
  '.discovery.controls[0].found_by = "a query nobody declares"'
case_run topic-query-deleted      1 "is not one of the declared queries" \
  'del(.discovery.topic_queries)'

# C4 - a control that is us. The sweep skips self, so it could never be seen and
# would take every run to rc 2 for a reason that is not about the lane.
case_run control-is-self 1 "the sweep skips self" \
  '.products += [{repo:"us/ours"}] | .discovery.controls += [{repo:"us/ours",found_by:"first query",why:"w"}]'

# C5
case_run duplicate-control 1 "declared twice" \
  '.discovery.controls += [{repo:"org/one",found_by:"first query",why:"w"}]'

# C6 - the cap bites before the queries are exhausted, so a control the run never
# reached is indistinguishable from one the search could not see.
case_run cap-bites-before-the-queries 1 "can stop before the queries are exhausted" \
  '.discovery.max_candidates = 10'
case_run cap-follows-a-new-query 1 "can stop before the queries are exhausted" \
  '.discovery.queries += ["third query"]'

# Could not measure, which is not a pass.
out="$(bash "$GATE" --baseline "$TMP/does-not-exist.json" 2>&1)"; rc=$?
if [ "$rc" -eq 2 ]; then printf 'ok       %-34s rc=2\n' missing-baseline; pass=$((pass+1))
else printf 'FAILED   %-34s rc=%s (wanted 2)\n' missing-baseline "$rc"; fail=$((fail+1)); fi

printf 'not json\n' > "$TMP/bad.json"
out="$(bash "$GATE" --baseline "$TMP/bad.json" 2>&1)"; rc=$?
if [ "$rc" -eq 2 ]; then printf 'ok       %-34s rc=2\n' baseline-is-not-json; pass=$((pass+1))
else printf 'FAILED   %-34s rc=%s (wanted 2)\n' baseline-is-not-json "$rc"; fail=$((fail+1)); fi

jq 'del(.discovery)' "$TMP/b.json" > "$TMP/nodisc.json"
out="$(bash "$GATE" --baseline "$TMP/nodisc.json" 2>&1)"; rc=$?
if [ "$rc" -eq 2 ]; then printf 'ok       %-34s rc=2\n' no-discovery-block; pass=$((pass+1))
else printf 'FAILED   %-34s rc=%s (wanted 2)\n' no-discovery-block "$rc"; fail=$((fail+1)); fi

# Reachability: a rule nobody can satisfy is not a rule. The real file has to pass.
if [ -f "$REAL" ]; then
  out="$(bash "$GATE" --baseline "$REAL" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then printf 'ok       %-34s rc=0\n' the-real-baseline-passes; pass=$((pass+1))
  else printf 'FAILED   %-34s rc=%s (wanted 0)\n' the-real-baseline-passes "$rc"
       printf '%s\n' "$out" | sed 's/^/         /' | tail -6; fail=$((fail+1)); fi
else
  printf 'FAILED   %-34s the real baseline is missing\n' the-real-baseline-passes; fail=$((fail+1))
fi

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. The gate goes red when the controls are deleted, emptied, unresolved,"
echo "        unwired, self-referential or duplicated, and when the cap could bite first;"
echo "        it reports could-not-measure instead of guessing; and the real file passes."
exit 0
