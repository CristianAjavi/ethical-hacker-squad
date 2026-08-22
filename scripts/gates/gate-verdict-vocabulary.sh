#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-verdict-vocabulary.sh — one closed vocabulary for every finding verdict.
#
# WHY IT EXISTS
#   The same deliverable was described with five different term sets across four
#   files. Measured before this gate existed:
#     references/report.md          verified / partially verified / not executed / blocked
#     agents/ehs-verifier.md body   verified / partially verified / not verified / blocked / withdrawn
#     agents/ehs-verifier.md front  verified / partial / unverified
#     references/team.md            verified / partial / unverified
#     knowledge/remediation-verification.md  "four states", one spelled differently again
#   A reader cannot tell whether `not verified`, `unverified` and `not executed`
#   are three states or one state written three ways. Neither can the model that
#   has to pick one. The vocabulary is now declared once, in
#   skills/ethical-hacker-squad/references/vocabulary.md, and this gate is what
#   keeps the other files from drifting away from it again.
#
# WHAT IT MEASURES
#   1. vocabulary.md parses, declares the four expected dimensions, and is
#      internally consistent (no term both declared and rejected, no duplicate
#      inside a dimension).
#   2. Every `<!-- vocabulary:use <dims> -->` region in the corpus and in
#      agents/ contains only terms declared for those dimensions.
#   3. No file of the corpus or of agents/ uses a REJECTED term as a verdict.
#   4. The four normalised files still carry a use region and still point at
#      vocabulary.md — undoing the normalisation is itself a failure.
#   5. The declared exclusions still exist, so the exclusion list cannot rot into
#      a silent hole.
#
# HOW FALSE POSITIVES ARE AVOIDED  (read this before adding a term)
#   A gate that greps English prose for words like `verified`, `blocked`, `high`
#   or `secure` fires on correct files and gets switched off within a week. This
#   one was written against a MEASURED false positive: knowledge/web-api.md
#   contains `Secure` and `SESSION_COOKIE_SECURE` — the cookie attribute and a
#   Django setting, not a claim that anything is secure. Three mechanisms keep
#   the gate quiet:
#
#   a) SINGLE WORDS ARE ONLY CHECKED INSIDE DELIMITED REGIONS. Terms such as
#      `verified` or `high` are validated only between vocabulary:use markers,
#      where the markers themselves prove the author was writing a verdict.
#      Outside a region those words are ordinary English and are ignored.
#   b) REJECTED TERMS ARE MATCHED AS MARKUP, NOT AS PROSE. Everywhere in the
#      corpus, a rejected term counts only when it appears inside backticks or
#      in bold — which is how this repository writes every verdict. Prose
#      matching is enabled only inside the four normalised files, and only for
#      rejected terms that are multi-word or carry an un-/non- prefix, so
#      "unverifiable" is never mistaken for "unverified" (word boundaries) and
#      a bare adjective is never mistaken for a verdict.
#   c) FILES IN A DIFFERENT NAMESPACE ARE EXCLUDED BY NAME, NEVER BY GLOB.
#      traceability.md, bibliography.md and tooling.md use `not verified` about
#      the provenance of a standard, not about a check. The exclusion is three
#      file names, printed on every run, and the gate fails if one of them no
#      longer exists.
#
# EXIT CODES (repo contract: an rc=0 never means "I did not check it")
#   0 = I MEASURED and it conforms
#   1 = I MEASURED and it FAILS
#   2 = I COULD NOT MEASURE (missing tool, missing/unparsable vocabulary.md,
#       missing canonical file). Never a pass.
#
# ENVIRONMENT VARIABLES
#   EHS_REPO_ROOT   repo root (otherwise: git, otherwise the script's ancestor)
# ---------------------------------------------------------------------------
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FAILURES=0
N_CHECKED=0

ok()      { printf '  [OK]   %s\n' "$*"; N_CHECKED=$((N_CHECKED + 1)); }
fail()    { printf '  [FAIL] %s\n' "$*" >&2; N_CHECKED=$((N_CHECKED + 1)); FAILURES=$((FAILURES + 1)); }
info()    { printf '         %s\n' "$*"; }
section() { printf '\n== %s\n' "$*"; }

unmeasurable() {
  printf '\n[COULD NOT MEASURE] %s\n' "$*" >&2
  printf 'gate-verdict-vocabulary: rc=2 (not a pass; it is absence of measurement)\n' >&2
  exit 2
}

# --- 0. tools --------------------------------------------------------------
section "tools"
for tool in awk grep sed sort mktemp; do
  command -v "$tool" >/dev/null 2>&1 || unmeasurable "the tool '$tool' is missing"
done
ok "POSIX utilities available"

TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t ehsvocab)" \
  || unmeasurable "I could not create a temporary directory"
cleanup() { [ -n "${TMPD:-}" ] && command rm -rf "$TMPD" 2>/dev/null; }
trap cleanup EXIT

DECL="$TMPD/declared.tsv"    # dimension<TAB>term
REJ="$TMPD/rejected.txt"     # one rejected term per line
: >"$DECL"; : >"$REJ"

# --- 1. root ---------------------------------------------------------------
if [ -n "${EHS_REPO_ROOT:-}" ]; then
  ROOT="$EHS_REPO_ROOT"
elif ROOT=$(git -C "$SELF_DIR" rev-parse --show-toplevel 2>/dev/null); then
  :
else
  ROOT="$(cd "$SELF_DIR/../.." && pwd)"
fi
[ -d "$ROOT/skills" ] || unmeasurable \
  "I cannot find skills/ under '$ROOT' (wrong cwd? this is not the plugin repo)"
info "root: $ROOT"

REFS="skills/ethical-hacker-squad/references"
VOCAB_REL="$REFS/vocabulary.md"
VOCAB="$ROOT/$VOCAB_REL"

# ---------------------------------------------------------------------------
# The MANDATORY FLOOR lives here, in the gate, not in the document it polices.
# If the list of files that must conform lived in vocabulary.md, deleting a line
# from that document would silently stop the check. These four files are the
# ones that define what a verdict is; each must carry a use region and point at
# the vocabulary.
# ---------------------------------------------------------------------------
CANONICAL="$REFS/team.md
$REFS/report.md
$REFS/knowledge/remediation-verification.md
agents/ehs-verifier.md"

# Files in a DIFFERENT namespace: they say `not verified` about the provenance
# of a standard or a bibliographic entry, never about a check. Excluded from the
# rejected-term scan by name, never by pattern, and their existence is verified
# below so the list cannot rot.
EXCLUDED="$REFS/traceability.md
$REFS/bibliography.md
$REFS/tooling.md"

DIMENSIONS="status severity confidence verification"

printf '\n'
printf 'SCOPE     : verdict terms in agents/*.md and in the skill corpus, against %s\n' "$VOCAB_REL"
printf 'OUT       : real audit reports (we do not emit a machine-readable one yet);\n'
printf '            the cross-dimension invariants of vocabulary.md; GitHub issue\n'
printf '            labels (severity/*, status/*), which are a separate namespace.\n'

# --- 2. the vocabulary itself ----------------------------------------------
section "vocabulary.md"
[ -f "$VOCAB" ] || unmeasurable \
  "$VOCAB_REL does not exist: there is no declared vocabulary to measure against"
[ -r "$VOCAB" ] || unmeasurable "$VOCAB_REL is not readable"
[ -s "$VOCAB" ] || unmeasurable "$VOCAB_REL is empty"

# Table rows inside a declare/reject region contribute their FIRST backticked
# token. Header and separator rows carry no backticks and are skipped by
# construction, so no row-counting heuristics are needed.
extract_region_terms() { # $1=file  $2=marker name (declare|reject)
  awk -v marker="$2" '
    {
      open_re  = "<!--[ \t]*vocabulary:" marker "([ \t]|-->)"
      close_re = "<!--[ \t]*/vocabulary:" marker "[ \t]*-->"
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
  ' "$1"
}

extract_region_terms "$VOCAB" declare >"$DECL" 2>/dev/null
extract_region_terms "$VOCAB" reject | cut -f2 | sort -u >"$REJ" 2>/dev/null

N_DECL=$(grep -c . "$DECL" 2>/dev/null || true); N_DECL=${N_DECL:-0}
N_REJ=$(grep -c . "$REJ" 2>/dev/null || true);   N_REJ=${N_REJ:-0}

[ "$N_DECL" -gt 0 ] || unmeasurable \
  "$VOCAB_REL declares no term: I cannot measure conformance against an empty vocabulary"

for d in $DIMENSIONS; do
  if ! cut -f1 "$DECL" | grep -Fxq "$d"; then
    unmeasurable "$VOCAB_REL declares no dimension '$d': that dimension cannot be measured"
  fi
done
ok "$VOCAB_REL parses: $N_DECL term(s) over the dimensions [$DIMENSIONS], $N_REJ rejected"

for d in $DIMENSIONS; do
  info "$d: $(awk -F'\t' -v d="$d" '$1==d {printf "%s ", $2}' "$DECL")"
done

# --- 3. internal consistency of the vocabulary ------------------------------
section "internal consistency of the vocabulary"

DUP=$(sort "$DECL" | uniq -d | awk -F'\t' '{printf "%s/%s ", $1, $2}')
if [ -n "$DUP" ]; then
  fail "term(s) declared twice inside the same dimension: $DUP"
else
  ok "no term is declared twice inside its dimension"
fi
info "note: high/medium/low intentionally live in both 'severity' and 'confidence'; that"
info "      collision is declared in vocabulary.md and is not treated as an error."

BOTH=""
while IFS= read -r rterm; do
  [ -n "$rterm" ] || continue
  if cut -f2 "$DECL" | grep -Fxq "$rterm"; then BOTH="$BOTH[$rterm] "; fi
done <"$REJ"
if [ -n "$BOTH" ]; then
  fail "term(s) both declared and rejected — the vocabulary contradicts itself: $BOTH"
else
  ok "no term is both declared and rejected"
fi

# SHAPE OF A REJECTED TERM. A rejected term must be multi-word or carry an
# un-/non- prefix, so that it cannot collide with ordinary English. This is not
# advice, it is checked: the first version of this gate allowed a bare `partial`
# on the list and it fired on "a `partial` refund" - a Rails partial and HTTP 206
# Partial Content would have done the same. `secure` would fire on the `Secure`
# cookie attribute that knowledge/web-api.md contains today. A rule about the
# gate's own inputs, left as prose, is a rule that decays.
PROSE_REJ="$TMPD/prose-rejected.txt"; : >"$PROSE_REJ"
BARE=""
while IFS= read -r rterm; do
  [ -n "$rterm" ] || continue
  case "$rterm" in
    *" "*|un*|non*) printf '%s\n' "$rterm" >>"$PROSE_REJ" ;;
    *)              BARE="$BARE[$rterm] " ;;
  esac
done <"$REJ"
if [ -n "$BARE" ]; then
  fail "rejected term(s) that are a bare common word: $BARE"
  info "a rejected term must be multi-word or carry an un-/non- prefix, or it will fire on"
  info "ordinary English. Govern that word with the definitions instead, as vocabulary.md"
  info "does for 'partial' and 'secure'."
else
  ok "every rejected term is multi-word or un-/non- prefixed, so none can collide with ordinary English"
fi

# --- 4. the scan set --------------------------------------------------------
section "scan set"
FILES="$TMPD/files.txt"
{
  find "$ROOT/agents" -type f -name '*.md' 2>/dev/null
  find "$ROOT/skills" -type f -name '*.md' 2>/dev/null
} | sed "s|^$ROOT/||" | LC_ALL=C sort -u >"$FILES"

N_FILES=$(grep -c . "$FILES" 2>/dev/null || true); N_FILES=${N_FILES:-0}
[ "$N_FILES" -gt 0 ] || unmeasurable "no .md file found under agents/ or skills/"

# vocabulary.md necessarily contains every rejected term (it defines them) and is
# excluded from the rejected-term scan. It is still checked as the authority in
# sections 2 and 3.
SCAN="$TMPD/scan.txt"
grep -Fxv "$VOCAB_REL" "$FILES" >"$SCAN"
STALE=""
while IFS= read -r ex; do
  [ -n "$ex" ] || continue
  if [ ! -f "$ROOT/$ex" ]; then STALE="$STALE[$ex] "; continue; fi
  grep -Fxv "$ex" "$SCAN" >"$SCAN.tmp" && mv "$SCAN.tmp" "$SCAN"
done <<EOF
$EXCLUDED
EOF
N_SCAN=$(grep -c . "$SCAN" 2>/dev/null || true); N_SCAN=${N_SCAN:-0}
ok "$N_SCAN file(s) in the rejected-term scan, out of $N_FILES .md under agents/ and skills/"
info "excluded, other namespace (provenance of standards, not verdicts):"
while IFS= read -r ex; do [ -n "$ex" ] && info "  - $ex"; done <<EOF
$EXCLUDED
EOF
info "excluded, it is the authority: $VOCAB_REL"
if [ -n "$STALE" ]; then
  fail "stale exclusion(s): the file no longer exists, so the exemption hides nothing real: $STALE"
else
  ok "every declared exclusion points at a file that exists"
fi

# --- 5. use regions ---------------------------------------------------------
section "vocabulary:use regions"
USES="$TMPD/uses.tsv"; : >"$USES"
N_REGIONS=0
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  awk -v F="$rel" '
    /<!--[ \t]*\/vocabulary:use[ \t]*-->/ {
      if (!inside) { print "ERR\t" F "\t" NR "\tclosing marker without an opening one" }
      inside=0; dims=""; next
    }
    /<!--[ \t]*vocabulary:use([ \t]|-->)/ {
      if (inside) { print "ERR\t" F "\t" NR "\tnested vocabulary:use region" }
      l=$0
      sub(/.*vocabulary:use[ \t]*/, "", l)
      sub(/[ \t]*-->.*/, "", l)
      gsub(/^[ \t]+|[ \t]+$/, "", l)
      dims=l; inside=1; openline=NR
      print "REGION\t" F "\t" NR "\t" dims
      next
    }
    inside {
      l=$0
      while (match(l, /`[^`]+`/)) {
        t=substr(l, RSTART+1, RLENGTH-2)
        gsub(/^[ \t]+|[ \t]+$/, "", t)
        print "TOK\t" F "\t" NR "\t" dims "\t" tolower(t)
        l=substr(l, RSTART+RLENGTH)
      }
    }
    END { if (inside) print "ERR\t" F "\t" openline "\tregion opened and never closed" }
  ' "$ROOT/$rel" >>"$USES"
done <"$SCAN"

# Structural errors first: an unbalanced region means the rest of the file was
# read under the wrong assumption.
STRUCT=$(awk -F'\t' '$1=="ERR" {printf "%s:%s (%s) ", $2, $3, $4}' "$USES")
if [ -n "$STRUCT" ]; then
  fail "malformed vocabulary:use region(s): $STRUCT"
else
  ok "every vocabulary:use region is opened and closed exactly once"
fi

N_REGIONS=$(awk -F'\t' '$1=="REGION"' "$USES" | grep -c . || true); N_REGIONS=${N_REGIONS:-0}

# Unknown dimension in a marker: the region cannot be validated against anything.
BADDIM=""
while IFS="$(printf '\t')" read -r kind f ln dims; do
  [ "$kind" = "REGION" ] || continue
  for d in $dims; do
    case " $DIMENSIONS " in
      *" $d "*) ;;
      *) BADDIM="$BADDIM$f:$ln[$d] " ;;
    esac
  done
done < <(awk -F'\t' '$1=="REGION"' "$USES")
if [ -n "$BADDIM" ]; then
  fail "vocabulary:use region(s) naming a dimension that does not exist: $BADDIM"
else
  ok "every use region names known dimension(s)"
fi

# Every backticked token inside a region must be declared for one of the region's
# dimensions. A token that is itself a DIMENSION NAME is the field label
# (`status`, `confidence`) and is ignored: it names the slot, not a value.
#
# ONE awk pass, not a bash loop per token. The first version of this gate spawned
# a process per token and took 68 seconds on this repository; a gate slow enough
# to be annoying is a gate somebody removes from CI.
TOKRES="$TMPD/tokres.txt"
awk -F'\t' -v dims_all=" $DIMENSIONS " '
  FILENAME==ARGV[1] { decl[$1 SUBSEP $2]=1; anydim[$2]=1; next }
  $1!="TOK" { next }
  {
    tok=$5
    if (index(dims_all, " " tok " ") > 0) next          # field label, not a value
    n_tok++
    split($4, ds, /[ \t]+/)
    for (i in ds) if (ds[i] != "" && ((ds[i] SUBSEP tok) in decl)) { ok=1; break }
    if (!ok) {
      if (tok in anydim) printf "WRONGDIM\t%s\t%s\t%s\t%s\n", $2, $3, $4, tok
      else               printf "UNDECL\t%s\t%s\t%s\t%s\n", $2, $3, $4, tok
      bad++
    }
    ok=0
  }
  END { printf "COUNT\t%d\t%d\n", n_tok+0, bad+0 }
' "$DECL" "$USES" >"$TOKRES"

while IFS="$(printf '\t')" read -r kind f ln dims tok; do
  case "$kind" in
    WRONGDIM) fail "$f:$ln uses '$tok' inside a [$dims] region: the term exists, but in another dimension" ;;
    UNDECL)   fail "$f:$ln uses '$tok', which $VOCAB_REL does not declare" ;;
  esac
done <"$TOKRES"

N_TOK=$(awk -F'\t' '$1=="COUNT" {print $2}' "$TOKRES")
BADTOK=$(awk -F'\t' '$1=="COUNT" {print $3}' "$TOKRES")
if [ "${BADTOK:-1}" -eq 0 ]; then
  ok "the $N_TOK term(s) used across $N_REGIONS region(s) are all declared for their dimension"
fi

# --- 6. rejected terms ------------------------------------------------------
section "rejected terms"
if [ "$N_REJ" -eq 0 ]; then
  info "the vocabulary rejects no term: nothing to look for"
else
  # Markup pass: a rejected term counts only when written as a verdict is
  # written here - inside backticks or in bold. Trailing punctuation is stripped
  # so `not verified.` is caught, and the comparison is whole-token, never a
  # substring, so `verified` never matches inside `not verified`.
  MARK="$TMPD/markup.tsv"; : >"$MARK"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    awk -v F="$rel" '
      {
        l=$0
        while (match(l, /`[^`]+`/)) {
          t=substr(l, RSTART+1, RLENGTH-2); l=substr(l, RSTART+RLENGTH)
          gsub(/^[ \t]+|[ \t.,;:]+$/, "", t); print F "\t" NR "\t" tolower(t)
        }
        l=$0
        while (match(l, /\*\*[^*]+\*\*/)) {
          t=substr(l, RSTART+2, RLENGTH-4); l=substr(l, RSTART+RLENGTH)
          gsub(/^[ \t]+|[ \t.,;:]+$/, "", t); print F "\t" NR "\t" tolower(t)
        }
      }
    ' "$ROOT/$rel" >>"$MARK"
  done <"$SCAN"

  # One awk pass over the token stream, with the rejected terms in an array.
  # Whole-token equality, never a substring: `verified` cannot match inside
  # `not verified`, and `unverifiable` is not `unverified`.
  HITS=0
  while IFS="$(printf '\t')" read -r f ln tok; do
    [ -n "$f" ] || continue
    fail "$f:$ln writes '$tok' as a verdict; $VOCAB_REL rejects it (see its replacement table)"
    HITS=$((HITS + 1))
  done < <(awk -F'\t' '
    FILENAME==ARGV[1] { rej[$0]=1; next }
    ($3 in rej) { print $1 "\t" $2 "\t" $3 }
  ' "$REJ" "$MARK")
  N_MARK=$(grep -c . "$MARK" 2>/dev/null || true); N_MARK=${N_MARK:-0}
  [ "$HITS" -eq 0 ] && ok "none of the $N_REJ rejected term(s) appears as markup in the $N_MARK token(s) scanned"

  # Prose pass, restricted twice over: only the four normalised files, and only
  # rejected terms that cannot collide with ordinary English. Word boundaries
  # mean `unverifiable` is not `unverified`.
  PHITS=0
  N_PROSE=$(grep -c . "$PROSE_REJ" 2>/dev/null || true); N_PROSE=${N_PROSE:-0}
  if [ "$N_PROSE" -gt 0 ]; then
    while IFS= read -r rterm; do
      [ -n "$rterm" ] || continue
      while IFS= read -r cf; do
        [ -n "$cf" ] || continue
        [ -f "$ROOT/$cf" ] || continue
        while IFS= read -r hit; do
          [ -n "$hit" ] || continue
          fail "$cf:${hit%%:*} says '$rterm' in prose; in a file that defines the vocabulary, that is the drift"
          PHITS=$((PHITS + 1))
        done < <(grep -niE "(^|[^[:alnum:]_])${rterm}([^[:alnum:]_]|\$)" "$ROOT/$cf" 2>/dev/null)
      done <<EOF
$CANONICAL
EOF
    done <"$PROSE_REJ"
  fi
  [ "$PHITS" -eq 0 ] && ok "no rejected term appears in the prose of the normalised files"
fi

# --- 7. the normalisation must stay in place --------------------------------
section "the four normalised files"
while IFS= read -r cf; do
  [ -n "$cf" ] || continue
  if [ ! -f "$ROOT/$cf" ]; then
    unmeasurable "$cf does not exist: it is one of the files this gate has to check"
  fi
  if awk -F'\t' -v f="$cf" '$1=="REGION" && $2==f {n++} END {exit !(n>0)}' "$USES"; then
    ok "$cf carries at least one vocabulary:use region"
  else
    fail "$cf has no vocabulary:use region: the normalisation was undone or moved"
  fi
  if grep -q 'vocabulary\.md' "$ROOT/$cf"; then
    ok "$cf points the reader at vocabulary.md"
  else
    fail "$cf does not reference vocabulary.md: its terms would be orphaned"
  fi
done <<EOF
$CANONICAL
EOF

# --- summary ---------------------------------------------------------------
section "summary"
printf '  checked: %d check(s) — %d declared term(s), %d rejected, %d use region(s),\n' \
  "$N_CHECKED" "$N_DECL" "$N_REJ" "$N_REGIONS"
printf '           over %d file(s) of agents/ and skills/\n' "$N_SCAN"
printf '  NOT checked (out of scope by design):\n'
printf '    - real audit reports: no machine-readable finding is emitted yet (backlog #7);\n'
printf '    - the cross-dimension invariants declared in vocabulary.md;\n'
printf '    - GitHub issue labels (severity/*, status/*): a separate namespace, mapped\n'
printf '      in the alias table of vocabulary.md and not edited from here;\n'
printf '    - single common words in free prose: deliberately never matched outside a\n'
printf '      region, because `Secure` in web-api.md is a cookie attribute.\n'

if [ "$FAILURES" -gt 0 ]; then
  printf '\ngate-verdict-vocabulary: rc=1 — %d MEASURED failure(s)\n' "$FAILURES" >&2
  exit 1
fi
printf '\ngate-verdict-vocabulary: rc=0 — measured and conforming\n'
exit 0
