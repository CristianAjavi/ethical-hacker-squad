#!/usr/bin/env bash
# Self-test for gate-verdict-vocabulary.sh, on throwaway copies of the corpus.
#
# The vocabulary exists because the drift was real: five spellings of the same
# verdict across four files, for one deliverable. This gate is what keeps that
# from coming back, and it had never been observed failing.
#
# The fixture is a COPY of the real files rather than a synthetic corpus, for
# the same reason the governance labs copy theirs: a hand-built vocabulary would
# drift from the one the gate actually polices, and the copy is known to conform
# because the gate says so on every run of this repository. Each case then
# breaks exactly one thing on that copy.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-verdict-vocabulary.sh"
ROOT="$(cd "$HERE/../.." && pwd)"
REFS="skills/ethical-hacker-squad/references"
[ -f "$GATE" ] || { echo "UNMEASURABLE $GATE is missing"; exit 2; }
[ -f "$ROOT/$REFS/vocabulary.md" ] || { echo "UNMEASURABLE the real vocabulary.md is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-vocab-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# build_corpus <dir> — the files this gate reads, copied from the real tree
build_corpus() {
  local d="$1" f
  for f in "$REFS/vocabulary.md" "$REFS/team.md" "$REFS/report.md" \
           "$REFS/traceability.md" "$REFS/bibliography.md" "$REFS/tooling.md" \
           "$REFS/knowledge/remediation.md" "agents/ehs-verifier.md"; do
    [ -f "$ROOT/$f" ] || continue
    mkdir -p "$d/$(dirname "$f")"
    cp "$ROOT/$f" "$d/$f"
  done
}

run_case() {  # <name> <expected rc> <needle> <mutation>
  local name="$1" want="$2" needle="$3" mutate="$4"
  local d="$TMP/$name"; rm -rf "$d"; mkdir -p "$d"
  build_corpus "$d"
  "$mutate" "$d"
  local out rc=0
  out="$(EHS_REPO_ROOT="$d" bash "$GATE" 2>&1)" || rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -qi -- "$needle"; }; then
    printf 'ok       %-36s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-36s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | grep -iE '\[fail\]|could not measure' | sed 's/^/         /' | head -4; fail=$((fail+1))
  fi
}

V() { printf '%s' "$1/skills/ethical-hacker-squad/references/vocabulary.md"; }

m_none()        { :; }
# a second row for a term already declared in the same dimension
m_dupe_term()   { awk '/^<!-- vocabulary:declare status -->/{print; found=1; next}
                       found && /^\|/ && !done2 {print; print "| `confirmed` | duplicated on purpose by the self-test |"; done2=1; next}
                       {print}' "$(V "$1")" > "$1/v.tmp" && mv "$1/v.tmp" "$(V "$1")"; }
# the same term declared and rejected: the vocabulary contradicting itself
m_declared_and_rejected() { awk '/^<!-- vocabulary:reject -->/{print; print "| `confirmed` | rejected on purpose by the self-test | use `confirmed` |"; next}
                       {print}' "$(V "$1")" > "$1/v.tmp" && mv "$1/v.tmp" "$(V "$1")"; }
# a rejected entry that is a bare common word: it would fire on ordinary prose
m_bare_word()   { awk '/^<!-- vocabulary:reject -->/{print; print "| `the` | a bare common word | — |"; next}
                       {print}' "$(V "$1")" > "$1/v.tmp" && mv "$1/v.tmp" "$(V "$1")"; }
# an exclusion pointing at a file that no longer exists hides nothing real
m_stale_exclusion() { rm -f "$1/$REFS/tooling.md"; }
# a use region that is opened and never closed
m_malformed_use()   { sed -i.bak 's|^<!-- /vocabulary:use -->$||' "$1/$REFS/team.md"; rm -f "$1/$REFS/team.md.bak"; }
# a use region naming a dimension the vocabulary does not declare
m_bad_dimension()   { sed -i.bak '1i\
<!-- vocabulary:use nonexistent -->\
- nonexistent: `x`\
<!-- /vocabulary:use -->
' "$1/$REFS/report.md"; rm -f "$1/$REFS/report.md.bak"; }
# a canonical file that lost its use region entirely
m_no_use_region()   { sed -i.bak '/vocabulary:use/d' "$1/agents/ehs-verifier.md"; rm -f "$1/agents/ehs-verifier.md.bak"; }
# a canonical file that no longer points at the vocabulary
m_no_reference()    { sed -i.bak 's/vocabulary\.md/somewhere-else.md/g' "$1/$REFS/report.md"; rm -f "$1/$REFS/report.md.bak"; }
# unmeasurable
m_no_vocab()    { rm -f "$(V "$1")"; }
m_empty_vocab() { : > "$(V "$1")"; }
m_drop_dimension() { awk '/^<!-- vocabulary:declare confidence -->/{skip=1} /^<!-- \/vocabulary:declare -->/{if(skip){skip=0;next}} !skip{print}' \
                       "$(V "$1")" > "$1/v.tmp" && mv "$1/v.tmp" "$(V "$1")"; }

echo "=== self-test: gate-verdict-vocabulary.sh ==="
echo "-- the vocabulary must not contradict itself"
run_case clean-corpus-passes         0 ""                       m_none
run_case term-declared-twice         1 "declared twice"         m_dupe_term
run_case declared-and-rejected       1 "contradicts itself"     m_declared_and_rejected
run_case rejected-bare-common-word   1 "bare common word"       m_bare_word

echo "-- the files that define a verdict must keep pointing at it"
run_case use-region-malformed        1 "malformed"              m_malformed_use
run_case use-region-unknown-dim      1 "does not exist"         m_bad_dimension
run_case canonical-without-region    1 "no vocabulary:use"      m_no_use_region
run_case canonical-without-reference 1 "orphaned"               m_no_reference
run_case stale-exclusion             1 "stale exclusion"        m_stale_exclusion

echo "-- could not measure (never a pass)"
run_case vocabulary-missing          2 "does not exist"         m_no_vocab
run_case vocabulary-empty            2 "empty"                  m_empty_vocab
run_case dimension-not-declared      2 "declares no dimension"  m_drop_dimension

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. The gate catches a vocabulary that contradicts itself, a"
echo "        definition file that stopped pointing at it, and an exemption that"
echo "        hides nothing - and refuses to measure against an absent vocabulary."
exit 0
