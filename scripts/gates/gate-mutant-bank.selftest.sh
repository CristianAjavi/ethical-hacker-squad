#!/usr/bin/env bash
# Self-test for gate-mutant-bank.sh.
#
# The gate under test measures batteries, so testing it against the repository's
# real batteries would take minutes and would change its answer every time a
# battery changed. Instead each case builds a THREE-RULE TOY REPOSITORY - one
# rule a case covers, one another case covers, one nothing covers - and points
# the gate at it with a bank written for that case. The toy is small enough that
# what each case measures is visible in the case itself.
#
# The five verdict branches are all exercised, and three of them are the ones a
# naive runner gets wrong: a mutant caught by SOME case but not by the case that
# claims the rule is a finding, a mutant the bank says cannot be caught but which
# IS caught is a finding in the other direction, and a bank entry whose anchor
# has moved is a 2 rather than a 1 - the gate lost track of the rule, it did not
# measure it.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-mutant-bank.sh"
command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
[ -f "$GATE" ] || { echo "UNMEASURABLE gate-mutant-bank.sh is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-mutbank-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# --- the toy repository -----------------------------------------------------
# Three rules. `case-a` covers rule A, `case-b` covers rule B, and NOTHING
# covers rule C - which is the shape the real finding takes, so the toy has to
# be able to reproduce it.
mkrepo() {
  local root="$1" broken="${2:-}"
  mkdir -p "$root/toy"
  cat > "$root/toy/rule.py" <<'PY'
def check(value):
    problems = []
    if value == "a":
        problems.append("rule A fired")
    if value == "b":
        problems.append("rule B fired")
    if value == "c":
        problems.append("rule C fired")
    return problems
PY
  cat > "$root/toy/battery.sh" <<'SH'
#!/usr/bin/env bash
# Two cases for three rules. Rule C has no case, on purpose.
ROOT="${EHS_REPO_ROOT:?}"
bad=0
for pair in a:case-a b:case-b; do
  v="${pair%%:*}"; n="${pair##*:}"
  if python3 -c "
import sys
sys.path.insert(0, '$ROOT/toy')
import rule
sys.exit(0 if rule.check('$v') else 1)"; then
    printf 'ok       %s\n' "$n"
  else
    printf 'FAILED   %s\n' "$n"; bad=1
  fi
done
[ -f "$ROOT/toy/ALWAYS_RED" ] && { printf 'FAILED   %s\n' "case-always-red"; bad=1; }
exit "$bad"
SH
  chmod +x "$root/toy/battery.sh"
  [ -n "$broken" ] && : > "$root/toy/ALWAYS_RED"
  return 0
}

# bank <file> <json-body>
bank() { printf '%s\n' "$2" > "$1"; }

# case_run <name> <want-rc> <needle> <bank-json> [broken]
case_run() {
  local name="$1" want="$2" needle="$3" body="$4" broken="${5:-}"
  local work="$TMP/$name"
  rm -rf "$work"; mkdir -p "$work"
  mkrepo "$work" "$broken" || { printf 'HARNESS  %-44s toy repo failed\n' "$name"; fail=$((fail+1)); return; }
  local bfile="$TMP/$name.bank.json"
  if [ "$body" = "__NOFILE__" ]; then bfile="$TMP/$name.absent.json"; rm -f "$bfile"
  else bank "$bfile" "$body"; fi
  local out rc
  out="$(EHS_REPO_ROOT="$work" EHS_MUTANT_BANK="$bfile" bash "$GATE" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf 'ok       %-44s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-44s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -6; fail=$((fail+1))
  fi
}

A_FIND='        problems.append("rule A fired")'
A_REPL='        pass'
C_FIND='        problems.append("rule C fired")'

# one(id, find, replace, expect, by) -> a one-entry bank, as JSON.
# Written by json.dumps and not by printf: the anchors below carry double quotes,
# and the first draft of this helper pasted them straight into a JSON string. The
# result was a bank that would not parse, so nine cases reported "could not
# measure" for a reason that had nothing to do with the gate under test.
one() {
  python3 -c 'import json,sys
print(json.dumps({"declared": 1, "mutants": [{
    "id": sys.argv[1], "target": "toy/rule.py", "battery": "toy/battery.sh",
    "find": sys.argv[2], "replace": sys.argv[3], "breaks": "toy",
    "expect": sys.argv[4], "by": sys.argv[5], "why": "toy"}]}))' "$1" "$2" "$3" "$4" "$5"
}

echo "=== self-test: gate-mutant-bank.sh ==="

# --- the three verdicts a correct runner has to tell apart -------------------
case_run mutant-caught-by-the-case-that-claims-it 0 "" \
  "$(one toy/a "$A_FIND" "$A_REPL" caught case-a)"

case_run mutant-caught-but-not-by-the-case-named 1 "which is the case that claims" \
  "$(one toy/a "$A_FIND" "$A_REPL" caught case-b)"

case_run mutant-nothing-catches-and-the-bank-expected-a-catch 1 "SURVIVED" \
  "$(one toy/c "$C_FIND" "$A_REPL" caught case-c)"

# --- accepted survivors, and the direction that keeps them honest ------------
case_run bank-records-the-survivor-and-it-still-survives 0 "" \
  "$(one toy/c "$C_FIND" "$A_REPL" survives '')"

case_run bank-says-uncatchable-but-a-case-catches-it 1 "the bank is stale" \
  "$(one toy/a "$A_FIND" "$A_REPL" survives '')"

# --- a lost anchor is COULD NOT MEASURE, never a pass and never a fail -------
case_run anchor-no-longer-in-the-file 2 "anchor appears 0 times" \
  "$(one toy/gone '        problems.append("rule Z fired")' "$A_REPL" caught case-a)"

case_run anchor-appears-more-than-once 2 "expected exactly 1" \
  "$(one toy/twice '    problems' 'x' caught case-a)"

case_run replacement-identical-to-the-anchor 2 "identical to the anchor" \
  "$(one toy/same "$A_FIND" "$A_FIND" caught case-a)"

case_run target-file-is-not-there 2 "target missing" \
  '{"declared":1,"mutants":[{"id":"toy/nofile","target":"toy/absent.py","battery":"toy/battery.sh","find":"x","replace":"y","breaks":"t","expect":"caught","by":"case-a"}]}'

case_run battery-does-not-exist 2 "battery" \
  '{"declared":1,"mutants":[{"id":"toy/nobat","target":"toy/rule.py","battery":"toy/absent.sh","find":"    problems = []","replace":"    problems = list()","breaks":"t","expect":"caught","by":"case-a"}]}'

# --- the battery was already red, so nothing below it measured anything ------
case_run battery-red-before-any-mutation 2 "on an unmutated tree" \
  "$(one toy/a "$A_FIND" "$A_REPL" caught case-a)" broken

# --- the bank as an artifact -------------------------------------------------
case_run declared-count-disagrees-with-the-entries 1 "declares" \
  '{"declared":4,"mutants":[{"id":"toy/a","target":"toy/rule.py","battery":"toy/battery.sh","find":"x","replace":"y","breaks":"t","expect":"caught","by":"case-a"}]}'

case_run bank-will-not-parse 2 "will not parse" '{ not json'

case_run bank-is-empty 2 "empty" '{"declared":0,"mutants":[]}'

case_run there-is-no-bank 2 "no bank at" "__NOFILE__"

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. The gate tells a catch from a catch-by-the-wrong-case from a"
echo "        survival, refuses to score a lost anchor as either, and fails when"
echo "        an accepted survivor stops surviving."
exit 0
