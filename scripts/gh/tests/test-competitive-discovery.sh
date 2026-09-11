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
# `a-control-the-search-cannot-see` is the third, and it is about the instrument
# rather than the lane. On 2026-09-10 the five text queries then in place
# returned 39 repositories and none of them was `trailofbits/skills`, a product
# in this exact lane with 7,033 stars: a text search ranks on name and
# description, and that repository is called `skills`. The run before had exited
# 0. `discovery.controls` names products the file has already resolved and that
# the sweep must therefore return; when one does not come back the run says so
# and exits 2, because a zero from an instrument that cannot see is not a zero.
# This case is the proof that it goes red - without it the control block could be
# deleted and every test here would stay green.
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
  */git/trees/HEAD*)
    repo="${path#repos/}"; repo="${repo%%/git/trees/HEAD*}"
    # TREE_DEAD names the repos whose tree call FAILS: a rate limit, a 403, a
    # repository that went private between the search and this call. Without this
    # the double can only ever say "no marker", which is a different statement
    # from "I could not look", and the suite could not tell them apart.
    case " ${TREE_DEAD:-} " in *" $repo "*) echo "gh: API rate limit exceeded" >&2; exit 1 ;; esac
    # TREES gives one repo a literal tree: `repo|path path path`, entries
    # separated by ';', a leading '!' on the repo meaning the tree came back
    # truncated. Without it every tree in this file is one of two shapes and a
    # case about WHERE the marker sits cannot be written at all.
    hit=""
    if [ -n "${TREES:-}" ]; then
      IFS=';' read -ra specs <<< "$TREES"
      for spec in "${specs[@]}"; do
        name="${spec%%|*}"; plist="${spec#*|}"; trunc=false
        case "$name" in !*) trunc=true; name="${name#!}" ;; esac
        [ "$name" = "$repo" ] || continue
        body='{"truncated":TRUNC,"tree":['; sep=""
        for p in $plist; do body="$body$sep{\"path\":\"$p\"}"; sep=","; done
        body="$body]}"; body="${body/TRUNC/$trunc}"
        emit "$body"; hit=1; break
      done
    fi
    [ -n "$hit" ] && exit 0
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
                 skill_markers: ["SKILL.md", ".claude-plugin", "agents", "skills"],
                 self: "us/ours" } } * $extra' > "$LAB/baseline.json"
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

echo
echo "== where the marker sits, measured over the 98 repos the real queries return"
# THE DEFECT. On 2026-09-10 the sweep's own queries returned 98 repositories.
# The tree call was NOT recursive, so only a marker in the root listing counted,
# and thirteen products of this exact lane went out through `continue`: nothing
# was printed, no counter moved, and the run ended "unresolved 0". Each case
# below is one real packaging shape, named after the repository it was measured
# on. Against the pre-patch file every one of them passes as rc 0 -- which is
# the whole point: a green that was the defect.
base
# S3DFX-CYBER/Claude-Skills-Security, erickmo/Claude-Skill-Security,
# ZhixiangLuo/10xProductivity: the skill lives under `.claude/`.
case_run marker-under-dot-claude 1 "UNRESOLVED  org/deep" \
  "org/known org/deep" "org/known" \
  "TREES=org/deep|README.md .claude .claude/skills .claude/skills/audit/SKILL.md"
# CapAhabb/Pentest-AI-Agents, netspectra/pentest-ai-agents: agents, same place.
case_run agents-under-dot-claude 1 "UNRESOLVED  org/deep" \
  "org/known org/deep" "org/known" \
  "TREES=org/deep|README.md .claude/agents .claude/agents/ad-attacks.md"
# angelapaia/web-security-audit-skill, superagents-lab/xcode27-skills,
# ljagiello/ctf-skills: the manifest one directory down, no `skills/` above it.
case_run skill-manifest-one-level-down 1 "UNRESOLVED  org/deep" \
  "org/known org/deep" "org/known" \
  "TREES=org/deep|README.md web-security-audit web-security-audit/SKILL.md"
# ghostsecurity/skills, toshipon/claude-code-security-audit-skill: inside a
# plugin, four levels down.
case_run skill-manifest-inside-a-plugin 1 "UNRESOLVED  org/deep" \
  "org/known org/deep" "org/known" \
  "TREES=org/deep|plugins/ghost/skills/exo/SKILL.md"
# BagelHole/DevOps-Security-Agent-Skills, hlsitechio/claude-skills-security:
# three levels, under a word nobody would have guessed to look under.
case_run skill-manifest-three-deep 1 "UNRESOLVED  org/deep" \
  "org/known org/deep" "org/known" \
  "TREES=org/deep|compliance/auditing/audit-logging/SKILL.md"
# ...and the top-level case the old rule DID catch still catches. A fix that
# widens must not drop what already worked.
case_run marker-at-the-root-still-counts 1 "UNRESOLVED  org/deep" \
  "org/known org/deep" "org/known" \
  "TREES=org/deep|README.md SKILL.md"

echo
echo "== and the reach it is NOT owed"
# The other half. `agents` and `skills` are ordinary words, and a rule that
# matches them anywhere swallows repositories that are not in this lane at all.
# Both shapes below are real: jmstar85/offensive-security and
# TheLunarCompany/lunar. Neither ships a Claude skill; both would have been
# reported as unnamed competitors.
case_run a-python-package-named-agents 0 "unresolved 0" \
  "org/known org/lib" "org/known" \
  "TREES=org/lib|README.md backend/app/agents backend/app/agents/__init__.py"
case_run a-service-directory-named-skills 0 "unresolved 0" \
  "org/known org/lib" "org/known" \
  "TREES=org/lib|packages/mcpx-server/src/services/skills/index.ts"
# A scanner is fed the thing it scans. cisco-ai-defense/skill-scanner,
# bruc3van/agent-skills-guard, KalarisLabs/Skill-Doctor and skyvanguard/Kryon
# carry markers only under a test corpus: counting them counts the judge as the
# subject, which is the pattern this repository has been burned by before.
case_run marker-only-in-an-eval-corpus 0 "unresolved 0" \
  "org/known org/scanner" "org/known" \
  "TREES=org/scanner|README.md evals/skills/malicious/SKILL.md"
case_run marker-only-in-test-fixtures 0 "unresolved 0" \
  "org/known org/scanner" "org/known" \
  "TREES=org/scanner|src-tauri/tests/fixtures/security/evil/SKILL.md"

echo
echo "== a tree nobody could read whole is not a tree with nothing in it"
# Unreachable before this change: a non-recursive tree is never truncated, so
# the candidate too deep to see was indistinguishable from the candidate that
# carries nothing. Both left through the same `continue`.
case_run truncated-tree-is-not-an-absence 2 "too large to read whole" \
  "org/known org/huge" "org/known" \
  "TREES=!org/huge|README.md src src/main.py"
# ...and truncation does not become an excuse: a truncated tree that DOES reach
# a marker is judged on what was reached.
case_run truncated-but-the-marker-was-reached 1 "UNRESOLVED  org/huge" \
  "org/known org/huge" "org/known" \
  "TREES=!org/huge|README.md .claude/skills/audit/SKILL.md"

echo
echo "== the bar has to exist"
# With no marker declared nothing can ever match, and the run would end at
# "unresolved 0": the lane is named, says an instrument with nothing to look
# for. Same family as the empty search above.
jq 'del(.discovery.skill_markers)' "$LAB/baseline.json" > "$LAB/b3.json" && mv "$LAB/b3.json" "$LAB/baseline.json"
case_run no-markers-declared 2 "declares no discovery.skill_markers" "org/known" "org/known"
# The controls, in both directions. A declared control that the search returns
# changes nothing; one it does not return takes the run to 2 even though every
# candidate that WAS seen is named - the lane looks clean and the instrument is
# what failed.
base '{"discovery":{"controls":[{"repo":"org/known","found_by":"q one","why":"w"}]}}'
case_run a-control-the-search-returns 0 "controls seen 1 of 1" \
  "org/known" "org/known"

base '{"discovery":{"controls":[{"repo":"org/known","found_by":"q one","why":"w"}]}}'
case_run a-control-the-search-cannot-see 2 "no query returned org/known" \
  "org/other" "org/other"

# ...and it outranks an unresolved candidate: the unresolved name is real and is
# still printed, but it came out of a sweep that has just been shown to be blind,
# so the verdict is 2 and the name is marked provisional.
base '{"discovery":{"controls":[{"repo":"org/known","found_by":"q one","why":"w"}]}}'
case_run a-blind-sweep-outranks-an-unresolved-name 2 "Provisional" \
  "org/newcomer" "org/newcomer"

# A topic query is swept exactly like a text query - same counters, same marker
# test - or the two halves of the lane are not measured the same way.
base '{"discovery":{"topic_queries":[{"term":"security","topic":"agent-skills"}]}}'
case_run a-topic-query-is-swept-too 1 "UNRESOLVED  org/newcomer" \
  "org/known org/newcomer" "org/known org/newcomer"

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

# A tree call that does not answer is not a repo without a marker. Same rule as
# empty-search above, one level down - and it is ONE call per candidate, so a
# rate-limited run used to drop every candidate and still print "every candidate
# in the lane is named" with rc 0.
base
case_run tree-silence-is-not-an-answer 2 "did not answer for its tree" \
  "org/known org/newcomer" "org/known org/newcomer" TREE_DEAD=org/newcomer

# "Already known" is an EXACT repository name. `$known` is a newline-joined blob
# and a substring test made the candidate `org/know` disappear into the declared
# `org/known`, which is a different repository.
base
case_run a-near-name-is-not-the-known-one 1 "unresolved 1" \
  "org/known org/know" "org/known org/know"

printf '\n  Summary: %d ok, %d failures\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
echo "  Result: OK. The check names a new entrant, ignores what is not the same kind of"
echo "          thing, honours a written decline, sweeps a topic query like a text one,"
echo "          refuses to sign a lane it has just been shown it cannot see, and never"
echo "          reads silence as a clean field."
exit 0
