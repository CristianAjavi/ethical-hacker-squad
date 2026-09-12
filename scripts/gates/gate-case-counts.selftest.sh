#!/usr/bin/env bash
# Self-test for gate-case-counts.sh, on throwaway trees built here: the gate
# RUNS the battery a marker names, so the only way to exercise it is to hand it
# batteries whose output is known by construction.
#
# WHAT IS PROVED, and why each case exists
#   * One case per SPELLING of a battery total that this tree actually prints -
#     five of them, three families - each agreeing, and one per spelling with
#     the cited figure off by one. A recogniser that matched four of five would
#     otherwise report the fifth as unmeasurable and nobody would notice which.
#   * A SIXTH, unknown shape, and an output carrying TWO different totals: both
#     exit 2. That is the rule that stops an output this gate cannot read from
#     turning into a green.
#   * A marker naming a file that is not there, and a marker with no figure
#     before it on its line: exit 2, not a pass.
#   * The RATCHET, in both directions: one unmarked citation over the declared
#     ceiling fails; at or under it passes AND the unmarked line is printed.
#   * Two citations and one marker on ONE line, because a per-line "does this
#     line have a marker" test would let the unmarked one hide behind the
#     marked one.
#   * The invocation rule: a name that is not `*.selftest.sh` is run with
#     --self-test, proved by a battery that prints its total only then.
#   * The gate refusing a marker that points at THIS battery: it would run the
#     battery that runs it.
#   * A CONTROL over the real repository. It asserts what stays true across the
#     migration of the citations rather than a fixed exit code: the gate can
#     always MEASURE this tree (0 or 1, never 2) and no marked citation
#     disagrees with its battery. An expectation that flips the day the markers
#     land is an expectation that gets edited rather than believed.
#     COST: this case runs every battery the docs cite. With no markers in the
#     tree it is instant; with all of them it is ~200 s, measured 2026-09-11.
#   * A CONTROL over the mutants themselves: a copy of the gate must behave
#     exactly like the gate in place. It did not, and nobody could see it:
#     the copies ran with no shared library and printed nothing at all.
#   * SEVEN MUTANTS, each with its prediction written above it before it ran.
#     Six are judged on the exit code. The seventh cannot be: it makes the gate
#     MISREAD a figure without changing how many citations are unmarked, so it
#     is judged on the text, against an honest run of the same tree.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
#
# shellcheck disable=SC2016
# Every single-quoted printf format in this file is a LITERAL: the backticks and
# the ${1:-} inside them are the text of the throwaway document or battery being
# written, not expansions of this script. Double-quoting them, which is what
# SC2016 suggests, would make the shell RUN the backticks.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-case-counts.sh"
ROOT_REAL="$(cd "$HERE/../.." && pwd)"
command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
[ -f "$GATE" ] || { echo "UNMEASURABLE $GATE is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-case-counts-XXXXXX")" || { echo "UNMEASURABLE no temp dir"; exit 2; }
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# Every mutant below is a COPY of the gate, and the gate sources its shared
# library from beside itself. Copied alone into $TMP the copy found no library:
# measured on one fixture, the gate in place printed 8 lines and rc 1, and the
# copy printed NOTHING at all - 9 `command not found` lines on stderr - and rc 1.
# The exit code survives because it comes out of the python block, which is why
# the rc-judged mutants still discriminated; a mutant judged on TEXT would have
# been blind every time, and this battery would have reported that blindness as
# a surviving mutant. The library goes beside the copies, and the control case
# `a-copy-of-the-gate-behaves-the-same` holds it down.
ln -s "$HERE/lib" "$TMP/lib" || {
  echo "UNMEASURABLE the gate's library cannot be put beside its copies"; exit 2; }

# --- helpers ---------------------------------------------------------------

# new_tree <name> -> prints the directory
new_tree() {
  local d="$TMP/$1"; rm -rf "$d"; mkdir -p "$d/docs" "$d/b"; printf '%s\n' "$d"
}

# battery <dir> <relative name under b/> <line>...  — a battery whose output is
# exactly the lines given. Written through a quoted heredoc so a line carrying
# backticks, quotes or parentheses reaches the file untouched.
battery() {
  local dir="$1" name="$2"; shift 2
  local f="$dir/b/$name"
  mkdir -p "$(dirname "$f")"
  { printf '#!/usr/bin/env bash\n'; printf "cat <<'BODYEOF'\n"; printf '%s\n' "$@"; printf 'BODYEOF\n'; } > "$f"
  chmod +x "$f"
}

# data <dir> <ceiling> — the scope declaration the gate is pointed at
data() {
  printf '{"docs":["docs/d.md"],"unmarked_ceiling":%s}\n' "$2" > "$1/data.json"
}

# check <name> <dir> <want rc> <needle> [gate] — runs the gate and judges it
check() {
  local name="$1" dir="$2" want="$3" needle="$4" gate="${5:-$GATE}"
  local out rc
  out="$(bash "$gate" --root "$dir" --data "$dir/data.json" --timeout "${CASE_TIMEOUT:-60}" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf 'ok       %-46s rc=%s\n' "$name" "$rc"; pass=$((pass+1)); return 0
  fi
  printf 'FAILED   %-46s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
  printf '%s\n' "$out" | sed 's/^/         /' | tail -8
  fail=$((fail+1)); return 1
}

echo "=== self-test: gate-case-counts.sh (real root: $ROOT_REAL) ==="

# --- the five spellings, agreeing and off by one ---------------------------
# label | the exact line the battery prints | the total it means
FORMATS=(
  'pass-slash-fail|  10 PASS / 0 FAIL|10'
  'dashed-passed-failed|--- 9 passed, 0 failed ---|9'
  'bare-passed-failed|29 passed, 0 failed|29'
  'summary-ok-failure-s|Summary: 23 ok, 0 failure(s)|23'
  'summary-ok-failures|Summary: 23 ok, 0 failures|23'
)

# scen_format <dir> <printed line> <cited figure>
scen_format() {
  local dir="$1" line="$2" cited="$3"
  battery "$dir" one.selftest.sh "$line"
  printf '| a row | `x` + self-test (%s cases) <!-- cases: b/one.selftest.sh --> |\n' "$cited" > "$dir/docs/d.md"
  data "$dir" 0
}

for spec in "${FORMATS[@]}"; do
  IFS='|' read -r label line total <<<"$spec"
  d="$(new_tree "fmt-$label")";      scen_format "$d" "$line" "$total"           ; check "format-$label-agrees"  "$d" 0 "cites $total and runs $total"
  d="$(new_tree "off-$label")";      scen_format "$d" "$line" "$((total + 1))"   ; check "format-$label-off-by-one" "$d" 1 "is cited as $((total + 1)) cases and runs $total"
done

# --- an output shape the gate does not know --------------------------------
scen_unknown() {
  local dir="$1"
  battery "$dir" odd.selftest.sh 'TOTAL: 7 green, 0 red'
  printf '| a row | `x` + self-test (7 cases) <!-- cases: b/odd.selftest.sh --> |\n' > "$dir/docs/d.md"
  data "$dir" 0
}
d="$(new_tree unknown-format)"; scen_unknown "$d"
check unknown-summary-shape-is-unmeasurable "$d" 2 "no summary line I recognise"

# --- two different totals in one output ------------------------------------
d="$(new_tree two-totals)"
battery "$d" both.selftest.sh '  4 PASS / 0 FAIL' 'Summary: 5 ok, 0 failures'
printf '| a row | `x` + self-test (4 cases) <!-- cases: b/both.selftest.sh --> |\n' > "$d/docs/d.md"
data "$d" 0
check two-different-totals-is-unmeasurable "$d" 2 "different totals"

# The same total printed twice is NOT two totals: an over-strict rule here would
# make every battery that echoes its own summary unmeasurable.
d="$(new_tree same-total-twice)"
battery "$d" twice.selftest.sh 'Summary: 5 ok, 0 failures' 'Summary: 5 ok, 0 failures'
printf '| a row | `x` + self-test (5 cases) <!-- cases: b/twice.selftest.sh --> |\n' > "$d/docs/d.md"
data "$d" 0
check same-total-printed-twice-is-one-total "$d" 0 "cites 5 and runs 5"

# --- a marker pointing at nothing ------------------------------------------
d="$(new_tree missing-battery)"
printf '| a row | `x` + self-test (5 cases) <!-- cases: b/absent.selftest.sh --> |\n' > "$d/docs/d.md"
data "$d" 0
check marker-names-a-file-that-is-gone "$d" 2 "no such file on disk"

# --- a marker with no figure before it on its line -------------------------
d="$(new_tree no-figure)"
battery "$d" one.selftest.sh 'Summary: 5 ok, 0 failures'
printf 'A sentence with no number at all. <!-- cases: b/one.selftest.sh -->\n' > "$d/docs/d.md"
data "$d" 0
check marker-with-no-figure-is-unmeasurable "$d" 2 "no figure before it"

# --- a figure in a TABLE CELL, with no "N cases" wording anywhere ------------
# `docs/gate-requirements.md` has a column headed `Cases now` holding bare
# integers. They match no citation pattern, so the ratchet never saw them and
# one of them was measured false. The marker takes the LAST INTEGER before it,
# which a table cell satisfies — these two cases are what proves that claim
# rather than asserting it, in both directions.
scen_cell() {   # $1 dir, $2 the integer the cell states
  local dir="$1" n="$2"
  battery "$dir" cell.selftest.sh 'Summary: 12 ok, 0 failures'
  printf '| `gate-x.sh` | what goes wrong | %s <!-- cases: b/cell.selftest.sh --> |\n' \
    "$n" > "$dir/docs/d.md"
  data "$dir" 0
}
d="$(new_tree cell-agrees)"; scen_cell "$d" 12
check a-bare-integer-in-a-table-cell-agrees    "$d" 0 "cites 12 and runs 12"
d="$(new_tree cell-off)";    scen_cell "$d" 11
check a-bare-integer-in-a-table-cell-off-by-one "$d" 1 "is cited as 11 cases and runs 12"

# --- A SKIPPED CASE IS STILL A CASE ------------------------------------------
# The bug CI found and this Mac could not: gate-reproduction.selftest.sh has 33
# cases, one of which needs sandbox-exec. On macOS 33 run. On ubuntu that one
# prints a skip with its reason and the battery prints `32 passed`, so a gate
# comparing against `passed` alone called a TRUE citation false there and true
# here. Everything below is measured on a synthetic battery, so it proves the
# same thing on either machine — which is the whole point.

# One case per skip spelling the tree actually emits, each counted.
SKIPS=(
  'leading-word|skip     the sandbox denies the network'
  'indented|  skip  unreadable agent   (running as root: chmod 000 would not deny)'
  'shouted|  SKIP  T09 could not build a python3-free PATH on this machine'
)
for entry in "${SKIPS[@]}"; do
  label="${entry%%|*}"; line="${entry#*|}"
  d="$(new_tree "skip-$label")"
  battery "$d" s.selftest.sh "$line" '--- 31 passed, 0 failed ---'
  printf 'Proved in the negative by 32 cases <!-- cases: b/s.selftest.sh -->.\n' > "$d/docs/d.md"
  data "$d" 0
  check "skip-spelling-$label-counts" "$d" 0 "runs 32 = 31 run + 1 skipped"
done

# The arithmetic has to be ON SCREEN. `cites 31 and runs 32` with no breakdown
# reads like a bug in the gate rather than a skip in the battery.
scen_two_skips() {
  local dir="$1" cited="$2"
  battery "$dir" s.selftest.sh \
    'skip     the sandbox denies the network   {"skip": "not macOS"}' \
    '  SKIP  T09 could not build a python3-free PATH' \
    '--- 31 passed, 0 failed ---'
  printf 'Proved in the negative by %s cases <!-- cases: b/s.selftest.sh -->.\n' \
    "$cited" > "$dir/docs/d.md"
  data "$dir" 0
}
d="$(new_tree skip-total-agrees)";  scen_two_skips "$d" 33
check a-skipped-case-counts-toward-the-total "$d" 0 "cites 33 and runs 33 = 31 run + 2 skipped"

d="$(new_tree skip-total-ignored)"; scen_two_skips "$d" 31
check counting-only-what-ran-would-read-31 "$d" 1 "is cited as 31 cases and runs 33 = 31 run + 2 skipped"

# ...and the half almost nobody writes: the comparator must still KNOW how to go
# red once skips are in play. A gate that starts passing everything the moment a
# skip appears has not been fixed, it has been blinded.
d="$(new_tree skip-still-red)";     scen_two_skips "$d" 40
check a-skip-does-not-blind-the-comparator "$d" 1 "is cited as 40 cases and runs 33 = 31 run + 2 skipped"

# A failing case is a case too — the figure is the SIZE of the battery.
d="$(new_tree failures-count)"
battery "$d" f.selftest.sh 'Summary: 5 ok, 2 failures'
printf 'Proved in the negative by 7 cases <!-- cases: b/f.selftest.sh -->.\n' > "$d/docs/d.md"
data "$d" 0
check a-failing-case-is-still-a-case "$d" 0 "cites 7 and runs 7"

# The two skip-shaped lines that are NOT a battery case: gate-plugin-integrity.sh
# and gate-plugin-version.sh print both while a battery runs them. No battery
# surfaces them today (measured: zero in 23 logs), and if one ever does this gate
# says so rather than quietly returning a smaller total.
d="$(new_tree skip-bracketed)"
battery "$d" s.selftest.sh "  [SKIP] not a git repo: using find instead of 'git ls-files'" 'Summary: 5 ok, 0 failures'
printf 'Proved in the negative by 5 cases <!-- cases: b/s.selftest.sh -->.\n' > "$d/docs/d.md"
data "$d" 0
check a-bracketed-skip-is-a-shape-i-cannot-read "$d" 2 "shape I cannot read"

d="$(new_tree skip-footer)"
battery "$d" s.selftest.sh '  skipped in this run: 2' 'Summary: 5 ok, 0 failures'
printf 'Proved in the negative by 5 cases <!-- cases: b/s.selftest.sh -->.\n' > "$d/docs/d.md"
data "$d" 0
check a-skip-count-footer-is-a-shape-i-cannot-read "$d" 2 "lies DOWNWARD"

# CONTROL against over-matching: gate-reproduction.selftest.sh has a case NAMED
# "a gate that skipped its self-test cannot sign". It is a pass, not a skip, and
# it must not be counted as one.
d="$(new_tree skip-in-a-case-name)"
battery "$d" s.selftest.sh 'ok       a gate that skipped its self-test cannot sign  rc=2' 'Summary: 5 ok, 0 failures'
printf 'Proved in the negative by 5 cases <!-- cases: b/s.selftest.sh -->.\n' > "$d/docs/d.md"
data "$d" 0
check the-word-skipped-inside-a-case-name-is-not-a-skip "$d" 0 "cites 5 and runs 5"

# --- the ratchet, in both directions ---------------------------------------
scen_ratchet() {   # one unmarked citation, ceiling 0
  local dir="$1"
  printf 'Proved in the negative by 12 cases, including a control.\n' > "$dir/docs/d.md"
  data "$dir" 0
}
d="$(new_tree ratchet-over)"; scen_ratchet "$d"
check unmarked-citation-over-the-ceiling "$d" 1 "carry no marker and the declared ceiling"

d="$(new_tree ratchet-at)"
printf 'Proved in the negative by 12 cases, including a control.\n' > "$d/docs/d.md"
data "$d" 1
check unmarked-citation-at-the-ceiling-passes "$d" 0 "unmarked  docs/d.md:1"

# --- a figure written with a thousands separator ---------------------------
# This document's own corpus figure is `2,740 cases`. An expression anchored at
# a word boundary reads that as `740 cases`, because a comma is a word
# boundary: the gate then quotes back a number the document does not contain,
# and quotes it SMALLER than the truth. The COUNT of unmarked citations is one
# either way, so the case asserts the TEXT.
d="$(new_tree thousands-separator)"
printf 'The corpus is v1.2 (Java), 2,740 cases, fetched and never vendored.\n' > "$d/docs/d.md"
data "$d" 1
check a-citation-with-a-separator-is-one-number "$d" 0 '`2,740 cases`'

# and the same figure bound to a battery: the marker is measured against 2740,
# not against 740, or a separator would make a citation uncheckable for good.
d="$(new_tree separator-marked)"
battery "$d" big.selftest.sh 'Summary: 2740 ok, 0 failures'
printf 'Proved by 2,740 cases <!-- cases: b/big.selftest.sh -->.\n' > "$d/docs/d.md"
data "$d" 0
check a-marked-citation-with-a-separator "$d" 0 "cites 2740 and runs 2740"

# --- two citations, one marker, one line -----------------------------------
d="$(new_tree two-citations-one-marker)"
battery "$d" one.selftest.sh 'Summary: 5 ok, 0 failures'
printf 'Both proved: 5 cases <!-- cases: b/one.selftest.sh --> for the gate, 6 cases for the scorer.\n' > "$d/docs/d.md"
data "$d" 0
check the-unmarked-citation-beside-a-marked-one "$d" 1 "unmarked  docs/d.md:1"

# --- the invocation rule ----------------------------------------------------
d="$(new_tree inline-self-test)"
{ printf '#!/usr/bin/env bash\n'
  printf '[ "${1:-}" = "--self-test" ] || { echo "the repo was audited, no self-test asked for"; exit 0; }\n'
  printf 'echo "Summary: 4 ok, 0 failures"\n'; } > "$d/b/gate-fake.sh"
chmod +x "$d/b/gate-fake.sh"
printf '| a row | `gate-fake.sh` + inline self-test (4 cases) <!-- cases: b/gate-fake.sh --> |\n' > "$d/docs/d.md"
data "$d" 0
check a-gate-name-is-run-with---self-test "$d" 0 "cites 4 and runs 4"

# --- the gate refuses to run its own battery --------------------------------
d="$(new_tree self-reference)"
mkdir -p "$d/scripts/gates"
{ printf '#!/usr/bin/env bash\n'; printf 'echo "Summary: 5 ok, 0 failures"\n'; } > "$d/scripts/gates/gate-case-counts.selftest.sh"
chmod +x "$d/scripts/gates/gate-case-counts.selftest.sh"
printf '| a row | (5 cases) <!-- cases: scripts/gates/gate-case-counts.selftest.sh --> |\n' > "$d/docs/d.md"
data "$d" 0
check a-marker-pointing-at-this-battery-is-refused "$d" 2 "recurses"

# --- each battery is run once, however many citations point at it -----------
d="$(new_tree memoised)"
battery "$d" one.selftest.sh 'Summary: 5 ok, 0 failures'
{ printf '| a | (5 cases) <!-- cases: b/one.selftest.sh --> |\n'
  printf '| b | (5 cases) <!-- cases: b/one.selftest.sh --> |\n'; } > "$d/docs/d.md"
data "$d" 0
check two-citations-one-battery-one-run "$d" 0 "measured by running 1 distinct"

# --- a battery that never finishes ------------------------------------------
d="$(new_tree slow)"
{ printf '#!/usr/bin/env bash\n'; printf 'sleep 30\n'; printf 'echo "Summary: 5 ok, 0 failures"\n'; } > "$d/b/slow.selftest.sh"
chmod +x "$d/b/slow.selftest.sh"
printf '| a row | (5 cases) <!-- cases: b/slow.selftest.sh --> |\n' > "$d/docs/d.md"
data "$d" 0
CASE_TIMEOUT=2 check a-battery-that-does-not-finish-is-unmeasurable "$d" 2 "did not finish within"

# --- the scope itself, when it is not there ---------------------------------
d="$(new_tree doc-gone)"
data "$d" 0
check a-declared-document-that-is-gone "$d" 2 "declared in the scope and is not on disk"

d="$(new_tree data-unparseable)"
printf 'not json at all\n' > "$d/data.json"
printf 'x\n' > "$d/docs/d.md"
check an-unparseable-scope-declaration "$d" 2 "will not parse"

d="$(new_tree data-incomplete)"
printf '{"docs":["docs/d.md"]}\n' > "$d/data.json"
printf 'x\n' > "$d/docs/d.md"
check a-scope-declaration-with-no-ceiling "$d" 2 "I will not guess"

# --- CONTROL: the repository as it stands ------------------------------------
# Not a fixed exit code. Before the citations are marked the ratchet is over its
# ceiling and the verdict is 1; after they are marked it is 0. What must hold in
# BOTH states is that the gate can measure this tree and that no marked citation
# contradicts its battery.
out="$(bash "$GATE" 2>&1)"; rc=$?
if [ "$rc" -ne 2 ] && ! printf '%s' "$out" | grep -q 'is cited as'; then
  printf 'ok       %-46s rc=%s\n' "control-the-real-repository" "$rc"; pass=$((pass+1))
else
  printf 'FAILED   %-46s rc=%s (wanted 0 or 1 with no disagreement)\n' control-the-real-repository "$rc"
  printf '%s\n' "$out" | grep -E 'is cited as|UNMEASURABLE|COULD NOT' | sed 's/^/         /' | head -8
  fail=$((fail+1))
fi

# --- the control the mutants stand on ---------------------------------------
# If a copy of the gate behaves differently from the gate in place for reasons
# that have nothing to do with a mutation, a dead mutant says nothing about the
# mutation. Same exit code AND same stdout, or every mutant below is theatre.
d="$(new_tree copy-is-the-gate)"; scen_format "$d" '  10 PASS / 0 FAIL' 10
cp "$GATE" "$TMP/copy-control.sh"
out_here="$(bash "$GATE" --root "$d" --data "$d/data.json" --timeout 60 2>/dev/null)"
rc_here=$?
out_copy="$(bash "$TMP/copy-control.sh" --root "$d" --data "$d/data.json" --timeout 60 2>/dev/null)"
rc_copy=$?
if [ "$rc_here" = "$rc_copy" ] && [ "$out_here" = "$out_copy" ]; then
  printf 'ok       %-46s rc=%s, output identical\n' a-copy-of-the-gate-behaves-the-same "$rc_copy"
  pass=$((pass+1))
else
  printf 'FAILED   %-46s rc %s here vs %s copied, %s lines vs %s\n' \
    a-copy-of-the-gate-behaves-the-same "$rc_here" "$rc_copy" \
    "$(printf '%s' "$out_here" | wc -l | tr -d ' ')" \
    "$(printf '%s' "$out_copy" | wc -l | tr -d ' ')"
  printf '         every mutant below judges a copy that is not this gate.\n'
  fail=$((fail+1))
fi

# --- MUTANTS ----------------------------------------------------------------
# Each prediction was written here BEFORE the mutant was run. A mutant that
# survives means this battery does not measure that branch, and the answer is a
# new case, not a quieter mutant.
#
#   A. the comparison always reports agreement
#        -> every off-by-one case goes green. Predicted red.
#   B. an output shape the gate cannot read is reported as OK instead of
#      unmeasurable
#        -> the unknown-shape case returns 0. Predicted red.
#   C. the ratchet is not applied
#        -> the unmarked-over-the-ceiling case returns 0. Predicted red.
#   D. skipped cases are dropped from the total (`distinct[0] + skipped` becomes
#      `distinct[0]`) — this is verbatim the bug CI found on ubuntu
#        -> the battery prints 31 passed + 2 skips and the document cites 33, so
#           the mutant compares 31 against 33 and returns 1 where the honest
#           gate returns 0. Predicted red.
#   E. a skip shape the gate cannot read is passed over instead of stopping the
#      measurement (`if puzzling:` becomes `if False:`)
#        -> the bracketed-skip case falls through to the summary line, compares
#           5 against 5 and returns 0 where the honest gate returns 2. Predicted
#           red. This is the one that matters most: its failure mode is a total
#           that is quietly too SMALL, which reads as a clean pass.
#
# The mutant is a COPY. The original is never edited: a harness that mutates the
# file it is measuring leaves the mutation behind when it dies.
mutant() {   # mutant <name> <python re.sub body> <tree dir> <honest rc>
  local name="$1" prog="$2" dir="$3" honest="$4"
  local mut="$TMP/mutant-$name.sh"
  cp "$GATE" "$mut"
  if ! EHS_MUTANT="$mut" python3 -c "$prog"; then
    printf 'HARNESS  %-46s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
  fi
  if cmp -s "$GATE" "$mut"; then
    printf 'HARNESS  %-46s the mutation was a no-op: the copy is identical\n' "$name"
    fail=$((fail+1)); return
  fi
  local out rc
  out="$(bash "$mut" --root "$dir" --data "$dir/data.json" --timeout 60 2>&1)"; rc=$?
  if [ "$rc" -ne "$honest" ]; then
    printf 'ok       %-46s killed (rc=%s, honest gate says %s)\n' "$name" "$rc" "$honest"; pass=$((pass+1))
  else
    printf 'FAILED   %-46s SURVIVED: still rc=%s\n' "$name" "$rc"
    printf '         a surviving mutant means this battery does not measure that branch.\n'
    fail=$((fail+1))
  fi
}

# The same, for a mutation the EXIT CODE cannot see. Mutant F below makes the
# gate misread a figure without changing how many citations are unmarked, so an
# rc-judged mutant would survive by construction and be counted as coverage. It
# is judged on what the gate PRINTS, and the honest gate is run first on the
# same tree: if the honest gate prints the needle too, the mutant proves nothing
# and that is a harness failure, not a pass.
# OLD and NEW travel in the environment rather than inside a -c program, because
# the text being substituted is a regular expression and quoting it twice is how
# a mutation silently becomes a no-op.
mutant_says() {  # mutant_says <name> <tree dir> <needle>; EHS_OLD/EHS_NEW in env
  local name="$1" dir="$2" needle="$3"
  local mut="$TMP/mutant-$name.sh" out honest rc
  cp "$GATE" "$mut"
  EHS_MUTANT="$mut" python3 - <<'PY'
import os
import pathlib
p = pathlib.Path(os.environ["EHS_MUTANT"])
t = p.read_text()
old, new = os.environ["EHS_OLD"], os.environ["EHS_NEW"]
assert t.count(old) == 1, "the text to mutate appears %d time(s), not once" % t.count(old)
p.write_text(t.replace(old, new))
PY
  rc=$?
  if [ "$rc" -ne 0 ] || cmp -s "$GATE" "$mut"; then
    printf 'HARNESS  %-46s the mutation did not apply\n' "$name"; fail=$((fail+1)); return
  fi
  honest="$(bash "$GATE" --root "$dir" --data "$dir/data.json" --timeout 60 2>&1)"
  if printf '%s' "$honest" | grep -q -- "$needle"; then
    printf 'HARNESS  %-46s the honest gate prints it too: this proves nothing\n' "$name"
    fail=$((fail+1)); return
  fi
  out="$(bash "$mut" --root "$dir" --data "$dir/data.json" --timeout 60 2>&1)"
  if printf '%s' "$out" | grep -q -- "$needle"; then
    printf 'ok       %-46s killed (it prints %s)\n' "$name" "$needle"; pass=$((pass+1))
  else
    printf 'FAILED   %-46s SURVIVED: it never printed %s\n' "$name" "$needle"
    printf '         a surviving mutant means this battery does not measure that branch.\n'
    fail=$((fail+1))
  fi
}

# The literal-substitution twin of SUB. The text being replaced here is a
# regular expression; quoting one twice, once for the shell and once for
# re.sub, is how a mutation silently becomes a no-op, so it travels in the
# environment instead and the count is asserted.
SUBENV='
import os, pathlib
p = pathlib.Path(os.environ["EHS_MUTANT"])
t = p.read_text()
old, new = os.environ["EHS_OLD"], os.environ["EHS_NEW"]
assert t.count(old) == 1, "the text to mutate appears %d time(s), not once" % t.count(old)
p.write_text(t.replace(old, new))
'
SUB='
import os, re, pathlib
p = pathlib.Path(os.environ["EHS_MUTANT"])
t = p.read_text()
n = re.sub(OLD, NEW, t, count=1)
assert n != t, "mutation was a no-op"
p.write_text(n)
'
d="$(new_tree mutant-a)"; scen_format "$d" '  10 PASS / 0 FAIL' 11
mutant comparator-always-agrees \
  "OLD=r'agree = \(cited == total\)'; NEW='agree = True'; $SUB" "$d" 1

d="$(new_tree mutant-b)"; scen_unknown "$d"
mutant unknown-shape-reported-as-ok \
  "OLD=r'emit\(\"WARN\", \"%s:%d  %s\" % \(doc, lineno, result\[1\]\)\)\n                unmeasurable = True'; NEW='emit(\"OK\", \"%s:%d  %s\" % (doc, lineno, result[1]))'; $SUB" "$d" 2

d="$(new_tree mutant-c)"; scen_ratchet "$d"
mutant ratchet-not-applied \
  "OLD=r'if len\(unmarked_all\) > ceiling:'; NEW='if False:'; $SUB" "$d" 1

# D and E guard the skip arithmetic. D is the bug CI actually found, turned into
# a mutant so it cannot come back quietly.
d="$(new_tree mutant-d)"; scen_two_skips "$d" 33
mutant skipped-cases-not-counted \
  "OLD=r'distinct\[0\] \+ skipped, shown\[0\]'; NEW='distinct[0], shown[0]'; $SUB" "$d" 0

d="$(new_tree mutant-e)"
battery "$d" s.selftest.sh "  [SKIP] not a git repo: using find instead" 'Summary: 5 ok, 0 failures'
printf 'Proved in the negative by 5 cases <!-- cases: b/s.selftest.sh -->.\n' > "$d/docs/d.md"
data "$d" 0
mutant unreadable-skip-shape-passed-over \
  "OLD=r'if puzzling:'; NEW='if False:'; $SUB" "$d" 2

# F guards the READING of a figure, which no exit code can see: the gate counts
# one unmarked citation whether it read 2,740 or 740, so F is judged on the text.
d="$(new_tree mutant-f)"
printf 'The corpus is v1.2 (Java), 2,740 cases, fetched and never vendored.\n' > "$d/docs/d.md"
data "$d" 1
EHS_OLD='CITATION = re.compile(r"(?<![\d.,])(\d[\d,]*)\s+cases?\b")'
EHS_NEW='CITATION = re.compile(r"\b(\d+)\s+cases?\b")'
export EHS_OLD EHS_NEW
mutant_says citation-anchored-at-a-word-boundary "$d" '`740 cases`'
unset EHS_OLD EHS_NEW


# G is F's other half: the same misreading on the MARKED path, where the figure
# is compared instead of merely quoted, so this one the exit code can see.
d="$(new_tree mutant-g)"
battery "$d" big.selftest.sh 'Summary: 2740 ok, 0 failures'
printf 'Proved by 2,740 cases <!-- cases: b/big.selftest.sh -->.\n' > "$d/docs/d.md"
data "$d" 0
EHS_OLD='INTEGER = re.compile(r"(?<![\d.,])\d[\d,]*")'
EHS_NEW='INTEGER = re.compile(r"\d+")'
export EHS_OLD EHS_NEW
mutant marked-figure-read-from-the-tail "$SUBENV" "$d" 0
unset EHS_OLD EHS_NEW

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. The gate reads all five spellings of a battery total, counts a skipped"
echo "        case as a case so its verdict does not depend on the runner, refuses the"
echo "        shapes it does not know instead of passing them, counts the citations nobody"
echo "        marked against a declared ceiling, and will not run the battery that runs it."
exit 0
