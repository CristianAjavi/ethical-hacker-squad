#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-benign-control.sh — a patch is verified by THREE runs, never by one.
#
# WHY IT EXISTS
#   "The attack no longer works" is produced by three different states of the
#   world and only one of them is a fix:
#     (a) the new control rejected the attack            -> fixed
#     (b) the patch broke the path for everybody         -> broken function
#     (c) nothing ever reached the code under test       -> nothing measured
#   A single run cannot tell them apart, so a verification that runs only the
#   attack is INCOMPLETE by construction. VER-08 of the remediation pack states
#   the rule; without a check, that rule is prose, and prose without a check is
#   debt. This gate is the check.
#
#   It is the finding-level twin of this repository's 0/1/2 gate doctrine: a run
#   that never reached the code is a `2`, not a `0`, and the same is true of a
#   verification whose benign run is missing.
#
# WHAT IT MEASURES  (it measures the SPECIFICATION, not an audit)
#   1. The rule exists exactly once in the served corpus, inside the pack that
#      must carry it, and inside a real procedure whose id matches its marker.
#   2. The rule still says the three things it has to say: a baseline run
#      against unpatched code, a benign run with a legitimate input, an attack
#      run — in that order, each with its required result.
#   3. Every verdict term the rule uses is declared under `verification` in
#      references/vocabulary.md. The rule cannot invent an outcome.
#   4. The benign row names a NON-favourable outcome: if (b) does not come out,
#      the verification may never be reported as verified.
#   5. The procedure carries the six mandatory fields of the corpus, its id
#      collides with nothing and leaves no numbering gap, and it is wired in —
#      listed in the pack index and cross-referenced from other procedures.
#      A rule nobody points at is a rule nobody reads.
#
# WHY A REGION MARKER AND NOT A GREP FOR A SENTENCE
#   A gate that greps for one sentence passes on a gutted rule that kept the
#   sentence, and fails on a correct rule that reworded it. The rule is wrapped
#   in <!-- benign-control:rule <ID> --> ... <!-- /benign-control:rule --> and
#   what is checked inside is STRUCTURE: three keyed rows, in order, whose
#   verdict terms come from the closed vocabulary. Rewording the prose keeps the
#   gate quiet; deleting a run does not.
#
# EXIT CODES (repo contract: an rc=0 never means "I did not check it")
#   0 = I MEASURED and it conforms
#   1 = I MEASURED and it FAILS (rule absent, gutted, duplicated, unwired, or a
#       malformed region in a file I could read)
#   2 = I COULD NOT MEASURE (missing tool, missing or unreadable remediation.md
#       or vocabulary.md, no `verification` dimension to validate terms against)
#
# ENVIRONMENT VARIABLES
#   EHS_REPO_ROOT     repo root (otherwise: git, otherwise the script ancestor)
#   EHS_MIN_XREFS     how many OTHER procedures must cite the rule (default 2)
# ---------------------------------------------------------------------------
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIN_XREFS="${EHS_MIN_XREFS:-2}"

FAILURES=0
N_CHECKED=0

ok()      { printf '  [OK]   %s\n' "$*"; N_CHECKED=$((N_CHECKED + 1)); }
fail()    { printf '  [FAIL] %s\n' "$*" >&2; N_CHECKED=$((N_CHECKED + 1)); FAILURES=$((FAILURES + 1)); }
info()    { printf '         %s\n' "$*"; }
section() { printf '\n== %s\n' "$*"; }

unmeasurable() {
  printf '\n[COULD NOT MEASURE] %s\n' "$*" >&2
  printf 'gate-benign-control: rc=2 (not a pass; it is absence of measurement)\n' >&2
  exit 2
}

# Counting lines with `grep -c . file || printf 0` LOOKS right and is not: on an
# empty file grep prints 0 AND exits 1, so the fallback appends a SECOND zero
# and every arithmetic test on the result errors out silently. The negative
# battery caught it — with the rule deleted the gate still returned 1, but
# through the wrong branch and with a nonsensical message. awk counts, always.
count_lines()  { awk 'END { print NR + 0 }' "$1"; }
count_nonempty() { printf '%s' "${1:-}" | awk 'NF { n++ } END { print n + 0 }'; }

# Printed by every exit path, so a run always says what it did NOT look at.
out_of_scope() {
  printf '  NOT checked (out of scope by design):\n'
  printf '    - any real verification: this gate reads the SPECIFICATION. No machine-readable\n'
  printf '      finding is emitted yet, so no deliverable can be checked against the rule;\n'
  printf '    - the byte budget of the pack: that is gate-plugin-integrity.sh;\n'
  printf '    - whether the agent contracts under agents/ cite VER-08 by name. They reach it\n'
  printf '      through the pack index, and those files are not edited from here.\n'
}

die_fail() {
  section "summary"
  printf '  checked: %d check(s) before stopping\n' "$N_CHECKED"
  out_of_scope
  printf '\ngate-benign-control: rc=1 — %d MEASURED failure(s)\n' "$FAILURES" >&2
  exit 1
}

# --- 0. tools --------------------------------------------------------------
section "tools"
for tool in awk grep sed sort mktemp; do
  command -v "$tool" >/dev/null 2>&1 || unmeasurable "the tool '$tool' is missing"
done
ok "POSIX utilities available"

TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t ehsbenign)" \
  || unmeasurable "I could not create a temporary directory"
cleanup() { [ -n "${TMPD:-}" ] && command rm -rf "$TMPD" 2>/dev/null; }
trap cleanup EXIT

# --- 1. root and designated inputs -----------------------------------------
section "inputs"
if [ -n "${EHS_REPO_ROOT:-}" ]; then
  ROOT="$EHS_REPO_ROOT"
elif ROOT=$(git -C "$SELF_DIR" rev-parse --show-toplevel 2>/dev/null); then
  :
else
  ROOT="$(cd "$SELF_DIR/../.." && pwd)"
fi
[ -d "$ROOT/skills" ] || unmeasurable \
  "I cannot find skills/ under '$ROOT' (wrong cwd? this is not the plugin repo)"

REFS="skills/ethical-hacker-squad/references"
KDIR_REL="$REFS/knowledge"
REM_REL="$KDIR_REL/remediation.md"
VOCAB_REL="$REFS/vocabulary.md"
REM="$ROOT/$REM_REL"
VOCAB="$ROOT/$VOCAB_REL"
KDIR="$ROOT/$KDIR_REL"

[ -r "$REM" ] || unmeasurable "$REM_REL does not exist or cannot be read: the pack that must carry the rule is not there"
[ -s "$REM" ] || unmeasurable "$REM_REL is empty: there is nothing to measure"
[ -r "$VOCAB" ] || unmeasurable "$VOCAB_REL does not exist or cannot be read: the verdict terms of the rule cannot be validated"
[ -d "$KDIR" ] || unmeasurable "$KDIR_REL is not a directory: the corpus is not where it is declared to be"
info "root: $ROOT"
ok "$REM_REL and $VOCAB_REL are readable"

# --- 2. the closed vocabulary the rule has to draw from --------------------
section "verification vocabulary"
TERMS="$TMPD/verification-terms.txt"
awk '
  /^<!-- vocabulary:declare[ \t]+verification[ \t]*-->/ { inreg = 1; next }
  /^<!-- \/vocabulary:declare -->/                     { inreg = 0; next }
  inreg && /^\|/ {
    if (match($0, /`[^`]+`/)) print substr($0, RSTART + 1, RLENGTH - 2)
  }
' "$VOCAB" | sort -u >"$TERMS" 2>/dev/null \
  || unmeasurable "$VOCAB_REL could not be parsed"

N_TERMS=$(count_lines "$TERMS")
[ "$N_TERMS" -ge 2 ] || unmeasurable \
  "$VOCAB_REL declares no usable 'verification' dimension ($N_TERMS term(s)): there is nothing to validate the rule's outcomes against"
grep -qx 'verified' "$TERMS" || unmeasurable \
  "$VOCAB_REL declares a 'verification' dimension without the term 'verified': this is not the dimension this gate needs"
ok "$N_TERMS verification term(s) declared in $VOCAB_REL"

is_term() { grep -qxF -- "$1" "$TERMS"; }

# --- 3. the rule region: exactly one, in the right file --------------------
section "location of the rule"
CORPUS_ROOTS=()
for d in skills agents; do [ -d "$ROOT/$d" ] && CORPUS_ROOTS+=("$ROOT/$d"); done
[ "${#CORPUS_ROOTS[@]}" -gt 0 ] || unmeasurable "neither skills/ nor agents/ exists under '$ROOT'"

HITS="$TMPD/hits.txt"
grep -rn --include='*.md' -e '<!-- benign-control:rule' "${CORPUS_ROOTS[@]}" >"$HITS" 2>/dev/null
N_HITS=$(count_lines "$HITS")

if [ "$N_HITS" -eq 0 ]; then
  fail "no benign-control rule region anywhere in the served corpus: the three-run rule was deleted or never written"
  die_fail
elif [ "$N_HITS" -gt 1 ]; then
  fail "$N_HITS benign-control rule regions found; two copies of a rule drift apart, so exactly one is allowed:"
  while IFS= read -r h; do info "${h#"$ROOT"/}"; done <"$HITS"
  die_fail
fi
HIT_FILE=$(cut -d: -f1 <"$HITS")
if [ "$HIT_FILE" != "$REM" ]; then
  fail "the rule lives in ${HIT_FILE#"$ROOT"/}, not in $REM_REL, which is the pack the verifier loads"
  die_fail
fi
ok "exactly one rule region, in $REM_REL"

# --- 4. the region parses, and belongs to a real procedure -----------------
section "shape of the region"
PARSED="$TMPD/parsed.txt"
awk '
  /^### [A-Z]+-[0-9]+/ {
    hdr = $0; sub(/^### /, "", hdr); split(hdr, a, " ")
    cur_id = a[1]; cur_line = NR
  }
  /<!-- benign-control:rule/ {
    id = ""
    if (match($0, /[A-Z]+-[0-9]+/)) id = substr($0, RSTART, RLENGTH)
    printf "OPEN\t%d\t%s\t%s\t%d\n", NR, id, cur_id, cur_line
    if (inreg) printf "BAD\ta region opens at line %d while another is still open\n", NR
    inreg = 1; next
  }
  /<!-- \/benign-control:rule -->/ {
    if (!inreg) printf "BAD\ta region closes at line %d without ever opening\n", NR
    inreg = 0; next
  }
  inreg { print "BODY\t" $0 }
  END { if (inreg) printf "BAD\tthe region opens and is never closed\n" }
' "$REM" >"$PARSED" 2>/dev/null || unmeasurable "$REM_REL could not be parsed"

if grep -q '^BAD' "$PARSED"; then
  while IFS=$'\t' read -r _ msg; do fail "malformed region in $REM_REL: $msg"; done < <(grep '^BAD' "$PARSED")
  die_fail
fi

OPEN_LINE=$(awk -F'\t' '$1=="OPEN"{print $2; exit}' "$PARSED")
MARK_ID=$(awk -F'\t' '$1=="OPEN"{print $3; exit}' "$PARSED")
PROC_ID=$(awk -F'\t' '$1=="OPEN"{print $4; exit}' "$PARSED")
PROC_LINE=$(awk -F'\t' '$1=="OPEN"{print $5; exit}' "$PARSED")

if [ -z "$MARK_ID" ]; then
  fail "the opening marker at $REM_REL:$OPEN_LINE carries no procedure id (expected: <!-- benign-control:rule VER-NN -->)"
  die_fail
fi
if [ -z "$PROC_ID" ]; then
  fail "the region at $REM_REL:$OPEN_LINE is not inside any '### <ID>' procedure: a rule outside a procedure is never loaded"
  die_fail
fi
if [ "$MARK_ID" != "$PROC_ID" ]; then
  fail "the marker says $MARK_ID and the procedure it sits in is $PROC_ID ($REM_REL:$PROC_LINE): the rule was pasted somewhere else"
  die_fail
fi
ID="$MARK_ID"
ok "the region belongs to procedure $ID ($REM_REL:$PROC_LINE)"

BODY="$TMPD/body.txt"
awk -F'\t' '$1=="BODY"{sub(/^BODY\t/, ""); print}' "$PARSED" >"$BODY"
[ -s "$BODY" ] || { fail "the region of $ID is empty: the markers survived, the rule did not"; die_fail; }

# --- 5. the three runs -----------------------------------------------------
section "the three runs"
# key | human label | word the row must contain
RUNS='a|baseline|unpatched
b|benign|legitimate
c|attack|attack'

PREV_POS=0
MISSING_RUN=0
while IFS='|' read -r key label word; do
  [ -n "$key" ] || continue
  row=$(grep -n "^| \*\*($key) $label\*\*" "$BODY" | head -1)
  if [ -z "$row" ]; then
    fail "run ($key) '$label' is missing from the rule of $ID: with fewer than three runs the verification cannot distinguish a fix from a broken path"
    MISSING_RUN=1
    continue
  fi
  pos=${row%%:*}
  text=${row#*:}
  if [ "$pos" -le "$PREV_POS" ]; then
    fail "run ($key) appears out of order in the rule of $ID (line $pos of the region): the order is baseline, benign, attack"
  fi
  PREV_POS="$pos"
  if printf '%s' "$text" | grep -qi -- "$word"; then
    ok "run ($key) '$label' present and mentions '$word'"
  else
    fail "run ($key) '$label' no longer mentions '$word': the row lost what makes it that run"
  fi
  printf '%s\n' "$text" >"$TMPD/row-$key.txt"
done <<EOF
$RUNS
EOF
[ "$MISSING_RUN" -eq 0 ] || die_fail

# --- 6. the outcomes it names are declared ---------------------------------
section "outcome terms"
UNKNOWN=""
N_TOKENS=0
while IFS= read -r tok; do
  [ -n "$tok" ] || continue
  N_TOKENS=$((N_TOKENS + 1))
  is_term "$tok" || UNKNOWN="$UNKNOWN $tok"
done < <(grep -o '`[^`]*`' "$BODY" | sed 's/^`//; s/`$//' | sort -u)

if [ -n "$UNKNOWN" ]; then
  fail "the rule of $ID uses verdict term(s) that $VOCAB_REL does not declare under 'verification':$UNKNOWN"
else
  ok "the $N_TOKENS backticked term(s) of the rule are all declared verification outcomes"
fi

# (b) is the check this whole procedure exists for: its failure branch may never
# be a favourable verdict.
if [ -f "$TMPD/row-b.txt" ]; then
  NEG=0
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    [ "$tok" = "verified" ] && continue
    is_term "$tok" && NEG=$((NEG + 1))
  done < <(grep -o '`[^`]*`' "$TMPD/row-b.txt" | sed 's/^`//; s/`$//' | sort -u)
  if [ "$NEG" -ge 1 ]; then
    ok "the benign row names a non-favourable outcome when (b) does not come out"
  else
    fail "the benign row of $ID names no outcome other than 'verified': a missing benign run must never round up to a pass"
  fi
fi

# --- 7. the incompleteness rule itself -------------------------------------
section "the rule about missing (b)"
MISSING_LINE=$(grep -n '^\*\*Missing (b)\*\*' "$BODY" | head -1)
if [ -z "$MISSING_LINE" ]; then
  fail "the rule of $ID no longer states what happens when (b) is missing (expected a line starting '**Missing (b)**')"
else
  mtext=${MISSING_LINE#*:}
  if printf '%s' "$mtext" | grep -qi 'incomplete'; then
    ok "a missing benign run is declared INCOMPLETE"
  else
    fail "the '**Missing (b)**' line of $ID does not say the verification is incomplete"
  fi
  if printf '%s' "$mtext" | grep -q '`partially verified`'; then
    ok "the incomplete case is mapped to a declared outcome"
  else
    fail "the '**Missing (b)**' line of $ID names no declared outcome for the incomplete case"
  fi
fi

# --- 8. the procedure is a real procedure of the corpus --------------------
section "procedure $ID"
SEC="$TMPD/section.txt"
awk -v start="$PROC_LINE" '
  NR < start { next }
  NR > start && (/^### /  || /^## /) { exit }
  { print }
' "$REM" >"$SEC"

MISSING_FIELDS=""
while IFS= read -r label; do
  [ -n "$label" ] || continue
  grep -q "^\*\*$label\*\*" "$SEC" || MISSING_FIELDS="$MISSING_FIELDS '$label'"
done <<'EOF'
Where to look
Vulnerable pattern
What rules it out (false positive)
Minimal test
Traceability
Tooling
EOF
if [ -n "$MISSING_FIELDS" ]; then
  fail "$ID is missing mandatory field(s):$MISSING_FIELDS (every procedure in this corpus carries all six)"
else
  ok "$ID carries the six mandatory fields"
fi

PREFIX=${ID%%-*}
NUM=${ID##*-}
DUP=$(grep -rc --include='*.md' "^### $ID " "$KDIR" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
if [ "$DUP" -eq 1 ]; then
  ok "$ID is used as a heading exactly once in the knowledge corpus"
else
  fail "$ID appears as a heading $DUP time(s) in $KDIR_REL: the id collides"
fi

NUMS="$TMPD/nums.txt"
grep -o "^### $PREFIX-[0-9][0-9]*" "$REM" | sed "s/^### $PREFIX-//" | sed 's/^0*//' | sort -n >"$NUMS"
GAPS=$(awk -v want=1 '{ while (want < $1) { printf "%s ", want; want++ } want = $1 + 1 }' "$NUMS")
if [ -n "$GAPS" ]; then
  fail "numbering gap in the $PREFIX series: ${GAPS}missing. A gap is a procedure that was lost, not a free slot"
else
  ok "the $PREFIX series runs without gaps up to $(tail -1 "$NUMS")"
fi

# --- 9. wired in, not just written -----------------------------------------
section "the rule is referenced"
IDX="$TMPD/index.txt"
awk '/^## Selective loading index/{f=1; next} f && /^## /{exit} f{print}' "$REM" >"$IDX"
if [ ! -s "$IDX" ]; then
  fail "$REM_REL has no 'Selective loading index' section: nothing routes a reader to any procedure"
elif grep -q "$ID" "$IDX"; then
  ok "$ID is listed in the pack's selective loading index"
else
  fail "$ID is not listed in the selective loading index of $REM_REL: a procedure nobody is routed to is a procedure nobody loads"
fi

XREFS=$(awk -v id="$ID" '
  /^### [A-Z]+-[0-9]+/ { hdr = $0; sub(/^### /, "", hdr); split(hdr, a, " "); cur = a[1]; next }
  cur != "" && cur != id && index($0, id) { print cur }
' "$REM" | sort -u)
N_XREFS=$(count_nonempty "$XREFS")
if [ "$N_XREFS" -ge "$MIN_XREFS" ]; then
  ok "$ID is cross-referenced from $N_XREFS other procedure(s): $(printf '%s' "$XREFS" | tr '\n' ' ')"
else
  fail "$ID is cited from only $N_XREFS other procedure(s) (minimum $MIN_XREFS): the single-run trap has to be signposted where verifiers actually are"
fi

# --- summary ---------------------------------------------------------------
section "summary"
printf '  checked: %d check(s) over procedure %s of %s\n' "$N_CHECKED" "$ID" "$REM_REL"
printf '  vocabulary source: %s (%d verification term(s))\n' "$VOCAB_REL" "$N_TERMS"
out_of_scope

if [ "$FAILURES" -gt 0 ]; then
  printf '\ngate-benign-control: rc=1 — %d MEASURED failure(s)\n' "$FAILURES" >&2
  exit 1
fi
printf '\ngate-benign-control: rc=0 — measured and conforming\n'
exit 0
