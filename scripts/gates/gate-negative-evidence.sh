#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-negative-evidence.sh — a verdict that says "no" must prove it looked.
#
# WHY IT EXISTS
#   Every check that never reached the code returns exactly what a working
#   control returns: nothing. A build that broke, a command that was not there
#   (`exit 127`), a fixture that went missing, a payload stopped two hops before
#   the parser — all of them produce the same silence as a defence that holds.
#   Reading that silence as "no bug" is the single cheapest way for a security
#   deliverable to be confidently wrong, and it is the finding-level twin of the
#   defect this repository's gates already refuse: an rc=0 that means "I did not
#   look". This gate carries the 0/1/2 doctrine down from the gates to the
#   findings.
#
#   The idea of demanding evidence that the test reached the sink is not ours;
#   it is the practice of the most rigorous project surveyed in
#   docs/competitive-analysis.md §2.5, and it is implemented here from the idea
#   alone — our own terms, our own criteria, our own code, zero lines borrowed.
#   What is ours to begin with is the exit-code doctrine it plugs into.
#
# WHAT IT MEASURES
#   A. THE RULE EXISTS AND IS COHERENT — in agents/ehs-verifier.md:
#      1. the four declared regions are present, balanced and non-empty:
#         reach-proof:scope (which verdicts owe a reach proof),
#         reach-proof:accept (what qualifies as one),
#         reach-proof:reject (what never does),
#         reach-proof:degrade (what the outcome becomes when there is none);
#      2. every verdict term named in scope/degrade is declared by
#         references/vocabulary.md, in the right dimension — the rule may not
#         invent vocabulary, and it may not drift when the vocabulary moves;
#      3. scope requires a reach proof of at least `verified` and `refuted`, and
#         of none of the three absence terms — asking an absence term for proof
#         of reach is a contradiction, it IS the absence;
#      4. degrade lands on exactly `inconclusive`, `not executed` and `blocked`:
#         the three reasons a measurement can be missing, kept apart. Merging
#         them is how "the build failed" comes to read as "no bug found";
#      5. reject names the three impostors that look like evidence and are not:
#         an exit status, an empty output, a green test suite.
#   B. NO FILE INSTRUCTS THE OPPOSITE — every .md in the repository is read by
#      scripts/gates/lib/negative-evidence.awk, which flags text that turns an
#      absence into a favourable verdict, disposes of a harness failure as a
#      pass, or equates an absence term with a good one.
#
# WHAT IT CANNOT MEASURE — stated, not implied
#   It reads SPECIFICATIONS, never a delivered audit. It cannot tell whether a
#   reach proof written in a real report is true, or even present: that needs the
#   machine-readable findings artifact (backlog item 7), and this rule is what
#   that schema will have to encode. It reads markdown only, and only in English.
#
# EXIT CODES (repo contract: an rc=0 never means "I did not check it")
#   0 = I MEASURED and it conforms
#   1 = I MEASURED and it FAILS
#   2 = I COULD NOT MEASURE — missing tool, missing detector, missing or
#       unparsable vocabulary.md, missing ehs-verifier.md, a self-test the
#       detector does not pass, or a file that silenced part of the scan.
#       Never a pass.
#
# USAGE
#   scripts/gates/gate-negative-evidence.sh
#   scripts/gates/gate-negative-evidence.sh --self-test   # only the fixtures
#
# ENVIRONMENT
#   EHS_REPO_ROOT    repo root (otherwise git, otherwise the script's ancestor)
#   GATE_SELFTEST=0  skip the self-test — the verdict is then capped at 2,
#                    because a detector that has not been measured cannot
#                    certify anything.
# ---------------------------------------------------------------------------
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FAILURES=0
N_CHECKED=0
ONLY_SELFTEST=0
SELFTEST_SKIPPED=0

ok()      { printf '  [OK]   %s\n' "$*"; N_CHECKED=$((N_CHECKED + 1)); }
fail()    { printf '  [FAIL] %s\n' "$*" >&2; N_CHECKED=$((N_CHECKED + 1)); FAILURES=$((FAILURES + 1)); }
info()    { printf '         %s\n' "$*"; }
section() { printf '\n== %s\n' "$*"; }

unmeasurable() {
  printf '\n[COULD NOT MEASURE] %s\n' "$*" >&2
  printf 'gate-negative-evidence: rc=2 (not a pass; it is the absence of a measurement)\n' >&2
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --self-test) ONLY_SELFTEST=1; shift ;;
    -h|--help) sed -n '2,72p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) unmeasurable "unknown argument: $1" ;;
  esac
done

# --- 0. tools --------------------------------------------------------------
section "tools"
for tool in awk grep sed sort mktemp find; do
  command -v "$tool" >/dev/null 2>&1 || unmeasurable "the tool '$tool' is missing"
done
ok "POSIX utilities available"

TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t ehsneg)" \
  || unmeasurable "I could not create a temporary directory"
cleanup() { [ -n "${TMPD:-}" ] && command rm -rf "$TMPD" 2>/dev/null; }
trap cleanup EXIT

DETECTOR="$SELF_DIR/lib/negative-evidence.awk"
FIXTURES="$SELF_DIR/fixtures/negative-evidence"
[ -f "$DETECTOR" ] || unmeasurable "the detector $DETECTOR is missing: there is nothing to scan with"
[ -r "$DETECTOR" ] || unmeasurable "the detector $DETECTOR is not readable"

# --- 1. root ---------------------------------------------------------------
if [ -n "${EHS_REPO_ROOT:-}" ]; then
  ROOT="$EHS_REPO_ROOT"
elif ROOT=$(git -C "$SELF_DIR" rev-parse --show-toplevel 2>/dev/null); then
  :
else
  ROOT="$(cd "$SELF_DIR/../.." && pwd)"
fi
[ -d "$ROOT/agents" ] || unmeasurable \
  "I cannot find agents/ under '$ROOT' (wrong cwd? this is not the plugin repo)"
info "root: $ROOT"

REFS="skills/ethical-hacker-squad/references"
VOCAB_REL="$REFS/vocabulary.md"
RULE_REL="agents/ehs-verifier.md"
VOCAB="$ROOT/$VOCAB_REL"
RULE="$ROOT/$RULE_REL"

# The three terms that mean "there is no measurement here". They are hardcoded
# in the gate on purpose: if this trichotomy lived in the document the gate
# polices, deleting a row would silently retire the check. Each one is verified
# below to be a declared verification term, so the gate and the vocabulary
# cannot drift apart in silence either.
ABSENCE_TERMS="inconclusive
not executed
blocked"

# The verdicts that can never be honest without a reach proof, whatever else the
# rule chooses to cover.
REQUIRED_SCOPE="verified
refuted"

printf '\n'
printf 'SCOPE     : the reach-proof rule declared in %s and its coherence with\n' "$RULE_REL"
printf '            %s; plus every .md in the repository, read for text\n' "$VOCAB_REL"
printf '            that instructs a favourable verdict in the absence of evidence.\n'
printf 'OUT       : delivered audit reports (no machine-readable finding exists yet);\n'
printf '            whether a reach proof written in a report is TRUE; non-markdown\n'
printf '            files; any language other than English.\n'

# ---------------------------------------------------------------------------
# region_scan <file> <region-name>
#   OPEN<TAB>line | CLOSE<TAB>line | BODY<TAB>line<TAB>text | ERR<TAB>line<TAB>why
#   COUNT<TAB>n
# ---------------------------------------------------------------------------
region_scan() {
  awk -v name="$2" '
    BEGIN {
      open_re  = "<!--[ \t]*reach-proof:" name "[ \t]*-->"
      close_re = "<!--[ \t]*/reach-proof:" name "[ \t]*-->"
    }
    $0 ~ close_re {
      if (!inside) print "ERR\t" NR "\tclosing marker without an opening one"
      else         print "CLOSE\t" NR
      inside=0; next
    }
    $0 ~ open_re {
      if (inside) print "ERR\t" NR "\tnested region"
      print "OPEN\t" NR; inside=1; n++; next
    }
    inside { print "BODY\t" NR "\t" $0 }
    END {
      if (inside) print "ERR\t" NR "\tregion opened and never closed"
      print "COUNT\t" n+0
    }
  ' "$1"
}

# Backticked tokens of a region body, lowercased, one per line.
region_tokens() { # stdin: region_scan output
  awk -F'\t' '
    $1=="BODY" {
      l=$3
      while (match(l, /`[^`]+`/)) {
        t=substr(l, RSTART+1, RLENGTH-2)
        gsub(/^[ \t]+|[ \t.,;:]+$/, "", t)
        if (t != "") print tolower(t)
        l=substr(l, RSTART+RLENGTH)
      }
    }'
}

# --- 2. the vocabulary, as the authority ------------------------------------
section "vocabulary.md, the authority for every term"
[ -f "$VOCAB" ] || unmeasurable \
  "$VOCAB_REL does not exist: the reach-proof rule names verdict terms and there is nothing to check them against"
[ -r "$VOCAB" ] || unmeasurable "$VOCAB_REL is not readable"

DECL="$TMPD/declared.tsv"
awk '
  {
    open_re  = "<!--[ \t]*vocabulary:declare([ \t]|-->)"
    close_re = "<!--[ \t]*/vocabulary:declare[ \t]*-->"
    if ($0 ~ close_re) { dim=""; inside=0; next }
    if ($0 ~ open_re) {
      l=$0
      sub(/.*vocabulary:[a-z]+[ \t]*/, "", l)
      sub(/[ \t]*-->.*/, "", l)
      dim=l; inside=1; next
    }
    if (inside && $0 ~ /^[ \t]*\|/) {
      if (match($0, /`[^`]+`/)) {
        t=substr($0, RSTART+1, RLENGTH-2)
        gsub(/^[ \t]+|[ \t]+$/, "", t)
        print tolower(dim) "\t" tolower(t)
      }
    }
  }
' "$VOCAB" >"$DECL" 2>/dev/null

N_DECL=$(grep -c . "$DECL" 2>/dev/null || true); N_DECL=${N_DECL:-0}
[ "$N_DECL" -gt 0 ] || unmeasurable \
  "$VOCAB_REL declares no term: I cannot check the reach-proof rule against an empty vocabulary"
for d in verification status; do
  cut -f1 "$DECL" | grep -Fxq "$d" \
    || unmeasurable "$VOCAB_REL declares no dimension '$d': the reach-proof rule cannot be checked"
done
ok "$VOCAB_REL parses: $N_DECL declared term(s), dimensions verification and status present"

declared_in() { # declared_in <dimension> <term>
  awk -F'\t' -v d="$1" -v t="$2" '$1==d && $2==t {found=1} END {exit !found}' "$DECL"
}

MISSING_ABS=""
while IFS= read -r t; do
  [ -n "$t" ] || continue
  declared_in verification "$t" || MISSING_ABS="$MISSING_ABS[$t] "
done <<EOF
$ABSENCE_TERMS
EOF
if [ -n "$MISSING_ABS" ]; then
  fail "$VOCAB_REL no longer declares as a verification outcome: $MISSING_ABS"
  info "those are the rungs of the degradation ladder. If one of them is gone, either the"
  info "vocabulary lost a way of saying 'I could not measure', or this gate is out of date."
  info "Both are defects; neither is a pass."
else
  ok "the three absence terms (inconclusive, not executed, blocked) are declared verification outcomes"
fi

# --- 3. the rule is declared ------------------------------------------------
section "the reach-proof rule in $RULE_REL"
[ -f "$RULE" ] || unmeasurable \
  "$RULE_REL does not exist: it is the file that has to carry the rule"
[ -r "$RULE" ] || unmeasurable "$RULE_REL is not readable"

RULE_OK=1
for r in scope accept reject degrade; do
  out="$TMPD/region-$r.txt"
  region_scan "$RULE" "$r" >"$out"
  cnt=$(awk -F'\t' '$1=="COUNT" {print $2}' "$out")
  err=$(awk -F'\t' '$1=="ERR" {printf "line %s (%s) ", $2, $3}' "$out")
  body=$(awk -F'\t' '$1=="BODY" && $3 ~ /[^ \t]/' "$out" | grep -c . || true)
  if [ -n "$err" ]; then
    fail "reach-proof:$r region is malformed in $RULE_REL: $err"
    RULE_OK=0
  elif [ "${cnt:-0}" -eq 0 ]; then
    fail "$RULE_REL declares no reach-proof:$r region: the rule is not stated, so nothing enforces it"
    RULE_OK=0
  elif [ "${cnt:-0}" -gt 1 ]; then
    fail "$RULE_REL declares reach-proof:$r $cnt times: two versions of the same rule is one too many"
    RULE_OK=0
  elif [ "${body:-0}" -eq 0 ]; then
    fail "the reach-proof:$r region of $RULE_REL is empty: a marker with nothing in it declares nothing"
    RULE_OK=0
  else
    ok "reach-proof:$r declared once, $body line(s)"
  fi
done

if [ "$RULE_OK" -eq 0 ]; then
  info "the coherence checks below are skipped for any region that is missing or malformed:"
  info "checking the content of a region I could not delimit would be guesswork."
fi

# --- 4. coherence: scope ----------------------------------------------------
section "coherence — which verdicts owe a reach proof"
SCOPE_TOK="$TMPD/scope-tokens.txt"
region_tokens <"$TMPD/region-scope.txt" | sort -u >"$SCOPE_TOK"
N_SCOPE=$(grep -c . "$SCOPE_TOK" 2>/dev/null || true); N_SCOPE=${N_SCOPE:-0}

if [ "$N_SCOPE" -eq 0 ]; then
  fail "the reach-proof:scope region names no verdict term: the rule applies to nothing"
else
  UNDECL=""
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    if ! declared_in verification "$t" && ! declared_in status "$t"; then
      UNDECL="$UNDECL[$t] "
    fi
  done <"$SCOPE_TOK"
  if [ -n "$UNDECL" ]; then
    fail "reach-proof:scope names term(s) that $VOCAB_REL does not declare as a verification outcome or a status: $UNDECL"
  else
    ok "the $N_SCOPE term(s) in reach-proof:scope are all declared verdict terms"
  fi

  MISSING_REQ=""
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    grep -Fxq "$t" "$SCOPE_TOK" || MISSING_REQ="$MISSING_REQ[$t] "
  done <<EOF
$REQUIRED_SCOPE
EOF
  if [ -n "$MISSING_REQ" ]; then
    fail "reach-proof:scope does not require a reach proof of: $MISSING_REQ"
    info "those two are the conclusive negatives: one says the attack no longer works, the"
    info "other says it never did. Neither is defensible if the check may not have run."
  else
    ok "the conclusive negatives (verified, refuted) both require a reach proof"
  fi

  CONTRADICT=""
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    grep -Fxq "$t" "$SCOPE_TOK" && CONTRADICT="$CONTRADICT[$t] "
  done <<EOF
$ABSENCE_TERMS
EOF
  if [ -n "$CONTRADICT" ]; then
    fail "reach-proof:scope demands a reach proof of an absence term: $CONTRADICT"
    info "that is a contradiction. Those terms exist precisely to be written when no reach"
    info "proof could be produced; requiring one turns the honest outcome into an unreachable one."
  else
    ok "no absence term is asked for a reach proof"
  fi
fi

# --- 5. coherence: the degradation ladder -----------------------------------
section "coherence — what a verdict becomes when the proof is missing"
DEG_TOK="$TMPD/degrade-tokens.txt"
DEG_VERD="$TMPD/degrade-verdicts.txt"
region_tokens <"$TMPD/region-degrade.txt" | sort -u >"$DEG_TOK"
: >"$DEG_VERD"
while IFS= read -r t; do
  [ -n "$t" ] || continue
  declared_in verification "$t" && printf '%s\n' "$t" >>"$DEG_VERD"
done <"$DEG_TOK"
sort -u "$DEG_VERD" -o "$DEG_VERD"

EXPECTED="$TMPD/expected-absence.txt"
printf '%s\n' "$ABSENCE_TERMS" | grep . | sort -u >"$EXPECTED"

MISS=$(comm -23 "$EXPECTED" "$DEG_VERD" | awk '{printf "[%s] ", $0}')
EXTRA=$(comm -13 "$EXPECTED" "$DEG_VERD" | awk '{printf "[%s] ", $0}')
if [ -n "$MISS" ]; then
  fail "the degradation ladder does not reach: $MISS"
  info "each rung is a different reason for a missing measurement — it ran and settled"
  info "nothing / it was never run / something external stopped it. Dropping one sends that"
  info "case somewhere else, and the somewhere else is always the flattering term."
fi
if [ -n "$EXTRA" ]; then
  fail "the degradation ladder lands on a conclusive verdict: $EXTRA"
  info "a missing reach proof may never degrade into a verdict that concludes something."
fi
[ -z "$MISS" ] && [ -z "$EXTRA" ] && \
  ok "a missing reach proof degrades to exactly: inconclusive, not executed, blocked"

# --- 6. coherence: the impostors --------------------------------------------
section "coherence — the three impostors are named as non-proof"
REJ_BODY="$TMPD/reject-body.txt"
awk -F'\t' '$1=="BODY" {print tolower($3)}' "$TMPD/region-reject.txt" >"$REJ_BODY"
check_impostor() { # <label> <ere>
  if grep -qE "$2" "$REJ_BODY"; then
    ok "reach-proof:reject names $1 as something that is not a reach proof"
  else
    fail "reach-proof:reject does not name $1"
    info "it is one of the three things that look like evidence and are not: they are"
    info "produced identically by a control that works and by a check that never ran."
  fi
}
check_impostor "an exit status on its own" 'exit (status|code)|status of .?0'
check_impostor "an empty output"           'empty output|no (output|matches|match|findings|finding|hits|results)'
check_impostor "a green test suite"        'test suite|suite (is|was) green|green (test )?suite|passing suite'

# --- 7. self-test: the detector before the repository ------------------------
section "self-test of the detector"
self_test() {
  local ok_st=1 f expect got
  [ -d "$FIXTURES" ] || { printf '  self-test: fixtures not found in %s\n' "$FIXTURES" >&2; return 2; }

  local n_bad=0 n_good=0 n_unm=0
  for f in "$FIXTURES"/bad/*.md; do
    [ -e "$f" ] || { printf '  self-test: there are no negative fixtures\n' >&2; return 2; }
    n_bad=$((n_bad + 1))
    expect="$(sed -n 's/^<!--[ ]*gate-expect:[ ]*\([a-z-]*\).*/\1/p' "$f" | head -1)"
    if [ -z "$expect" ]; then
      printf '  self-test: fixture %s does not declare <!-- gate-expect: <rule> -->\n' "$(basename "$f")" >&2
      ok_st=0; continue
    fi
    got="$(awk -v FILE="$(basename "$f")" -f "$DETECTOR" "$f" 2>/dev/null | awk -F'|' -v r="$expect" '$1=="FAIL" && $4==r' | grep -c . || true)"
    if [ "${got:-0}" -lt 1 ]; then
      printf '  NEGATIVE self-test failed: %s must trigger [%s] and it did not\n' "$(basename "$f")" "$expect" >&2
      ok_st=0
    fi
  done

  for f in "$FIXTURES"/good/*.md; do
    [ -e "$f" ] || { printf '  self-test: there are no positive fixtures\n' >&2; return 2; }
    n_good=$((n_good + 1))
    got="$(awk -v FILE="$(basename "$f")" -f "$DETECTOR" "$f" 2>/dev/null | grep -c . || true)"
    if [ "${got:-0}" -ne 0 ]; then
      printf '  POSITIVE self-test failed: %s is correct text and the detector fired on it:\n' "$(basename "$f")" >&2
      awk -v FILE="$(basename "$f")" -f "$DETECTOR" "$f" 2>/dev/null | sed 's/^/        /' >&2
      ok_st=0
    fi
  done

  for f in "$FIXTURES"/unmeasurable/*.md; do
    [ -e "$f" ] || { printf '  self-test: there are no unmeasurable fixtures\n' >&2; return 2; }
    n_unm=$((n_unm + 1))
    if ! awk -v FILE="$(basename "$f")" -f "$DETECTOR" "$f" 2>/dev/null | grep -q '^UNMEAS|'; then
      printf '  self-test failed: %s must come out UNMEASURABLE and it came out silent\n' "$(basename "$f")" >&2
      ok_st=0
    fi
  done

  printf '  fixtures: %d that must fail, %d that must stay silent, %d that must be unmeasurable\n' \
    "$n_bad" "$n_good" "$n_unm"
  [ "$ok_st" -eq 1 ] && return 0
  return 2
}

if [ "${GATE_SELFTEST:-1}" != "0" ]; then
  if self_test; then
    ok "the detector still fires on what it must, and stays silent on what it must not"
  else
    unmeasurable "the detector does not pass its own self-test: any verdict it gave about the repository would be indefensible"
  fi
else
  printf '  self-test SKIPPED via GATE_SELFTEST=0\n' >&2
  SELFTEST_SKIPPED=1
fi

if [ "$ONLY_SELFTEST" -eq 1 ]; then
  if [ "$SELFTEST_SKIPPED" -eq 1 ]; then
    unmeasurable "--self-test together with GATE_SELFTEST=0: nothing was run"
  fi
  printf '\ngate-negative-evidence: self-test only — the detector measured itself and passed\n'
  exit 0
fi

# --- 8. the repository scan --------------------------------------------------
section "no file instructs a favourable verdict without a reach proof"
FILES="$TMPD/files.txt"
find "$ROOT" -type f -name '*.md' \
  ! -path "$ROOT/.git/*" \
  ! -path "$SELF_DIR/fixtures/*" \
  2>/dev/null | sed "s|^$ROOT/||" | LC_ALL=C sort -u >"$FILES"
N_FILES=$(grep -c . "$FILES" 2>/dev/null || true); N_FILES=${N_FILES:-0}
[ "$N_FILES" -gt 0 ] || unmeasurable "no .md file found under '$ROOT': there is nothing to scan"

RESULTS="$TMPD/scan.txt"; : >"$RESULTS"
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  [ -r "$ROOT/$rel" ] || { printf 'UNREADABLE|%s|0|unreadable|the file cannot be read\n' "$rel" >>"$RESULTS"; continue; }
  awk -v FILE="$rel" -f "$DETECTOR" "$ROOT/$rel" >>"$RESULTS" 2>/dev/null
done <"$FILES"

UNREAD=$(awk -F'|' '$1=="UNREADABLE" {printf "[%s] ", $2}' "$RESULTS")
[ -n "$UNREAD" ] && unmeasurable "unreadable file(s), so the scan has a hole in it: $UNREAD"

UNMEAS_HITS=$(awk -F'|' '$1=="UNMEAS"' "$RESULTS" | grep -c . || true)
if [ "${UNMEAS_HITS:-0}" -gt 0 ]; then
  awk -F'|' '$1=="UNMEAS" {printf "  %s:%s [%s] %s\n", $2, $3, $4, $5}' "$RESULTS" >&2
  unmeasurable "$UNMEAS_HITS file region(s) left part of a file outside the scan: I did not measure those files"
fi

HITS=0
while IFS='|' read -r kind f ln rule msg; do
  [ "$kind" = "FAIL" ] || continue
  fail "$f:$ln [$rule] $msg"
  HITS=$((HITS + 1))
done <"$RESULTS"
if [ "$HITS" -eq 0 ]; then
  ok "$N_FILES markdown file(s) scanned, none instructs a favourable verdict without evidence of reach"
  info "quoting the forbidden inference is allowed inside a reach-proof:counterexample region,"
  info "and only there, and only when the region also rejects it."
fi

# --- summary ----------------------------------------------------------------
section "summary"
printf '  checked: %d check(s) — the rule in %s against %d declared term(s),\n' \
  "$N_CHECKED" "$RULE_REL" "$N_DECL"
printf '           plus %d markdown file(s) read by the detector\n' "$N_FILES"
printf '  NOT checked (out of scope by design, not by omission):\n'
printf '    - delivered audit reports: no machine-readable finding is emitted yet (backlog #7).\n'
printf '      This gate proves the rule exists and that nothing contradicts it; it cannot prove\n'
printf '      that a reach proof written in a real report is true, or even present;\n'
printf '    - non-markdown files: scripts, workflows and issue templates;\n'
printf '    - languages other than English: the detector'"'"'s phrasebook is English only, so a\n'
printf '      translated corpus would pass unread — a known hole, declared rather than implied;\n'
printf '    - paraphrase: the detector matches phrasings, not meaning. It raises the cost of\n'
printf '      writing the defect; it does not make it impossible;\n'
printf '    - a sentence that both instructs the defect AND negates something unrelated\n'
printf '      ("...mark it as verified, this is not negotiable"): the negation suppresses the\n'
printf '      rule. That is the price paid for never firing on the twenty-odd correct passages\n'
printf '      in this corpus that refuse the inference in words, and it is a known evasion\n'
printf '      rather than an unknown one. Found by breaking a fixture, not by reasoning.\n'

if [ "$SELFTEST_SKIPPED" -eq 1 ]; then
  printf '\n' >&2
  unmeasurable "the self-test was skipped, so the detector was never measured: this run cannot return 0"
fi

if [ "$FAILURES" -gt 0 ]; then
  printf '\ngate-negative-evidence: rc=1 — %d MEASURED failure(s)\n' "$FAILURES" >&2
  exit 1
fi
printf '\ngate-negative-evidence: rc=0 — measured and conforming\n'
exit 0
