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
#   * THREE MUTANTS, each with its prediction written above it before it ran.
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

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. The gate reads all five spellings of a battery total, refuses the shapes"
echo "        it does not know instead of passing them, counts the citations nobody marked"
echo "        against a declared ceiling, and will not run the battery that runs it."
exit 0
