#!/usr/bin/env bash
# Battery for gate-errexit-rc-capture.sh.
#
# Two halves, and the second is the one that matters.
#
#   PART A - the cases. Every fixture in scripts/gates/fixtures/errexit-rc/ plus
#     the exit-code contract of the wrapper over throwaway trees: 0 over a clean
#     workflow, 1 over one carrying the defect, 2 over a tree with no workflows.
#
#   PART B - the MUTANTS. Part A passing proves the checker agrees with the
#     fixtures; it does not prove the fixtures could ever disagree with a broken
#     checker. So each mutant below breaks one specific piece of the detector on
#     a COPY of it - never on the file in the tree - and Part A must go red. A
#     mutant that survives means that piece is not measured by anything, and this
#     battery fails, because a bank whose cases cannot catch a sabotage is not a
#     bank.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-errexit-rc-capture.sh"
CORE="$HERE/lib/errexit_rc_capture.py"
FIX="$HERE/fixtures/errexit-rc"

command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE there is no python3"; exit 2; }
[ -f "$CORE" ] || { echo "UNMEASURABLE the checker is missing: $CORE"; exit 2; }
[ -d "$FIX" ]  || { echo "UNMEASURABLE the fixtures are missing: $FIX"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-errexit-rc-XXXXXX")" || { echo "UNMEASURABLE no temp dir"; exit 2; }
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
say_ok()   { printf 'ok       %-44s %s\n' "$1" "${2:-}"; pass=$((pass+1)); }
say_bad()  { printf 'FAILED   %-44s %s\n' "$1" "${2:-}"; fail=$((fail+1)); }

# ---------------------------------------------------------------------------
# A tree with no workflows directory, and a tree whose workflow has no `run:`.
# Both exist so the UNMEASURABLE side of the contract is exercised, not assumed.
# ---------------------------------------------------------------------------
mkdir -p "$TMP/norun/.github/workflows"
printf 'name: nothing\non:\n  workflow_dispatch:\npermissions: {}\njobs:\n  a:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v5\n' \
  > "$TMP/norun/.github/workflows/x.yml"
mkdir -p "$TMP/notree"

# run_cases <core> -> prints one line per case: "<name> <OK|BAD>"
# Every case is evaluated against the core passed in, which is how the mutants
# are measured with exactly the battery that measures the real thing.
run_cases() {
  local core="$1" f expect rc out name
  local results=""

  # the embedded control: two strings that must come out red, three clean
  out="$(PYTHONSAFEPATH=1 python3 "$core" --self-check 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && results="$results control:OK" || results="$results control:BAD"

  for f in "$FIX"/bad/*.yml; do
    name="bad/$(basename "$f")"
    expect="$(sed -n 's/^# gate-expect:[[:space:]]*//p' "$f" | head -1)"
    out="$(PYTHONSAFEPATH=1 python3 "$core" --root "$FIX" "$f" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q "^FAIL|[^|]*|[0-9]*|${expect}|"; then
      results="$results $name:OK"
    else
      results="$results $name:BAD"
    fi
  done

  for f in "$FIX"/good/*.yml; do
    name="good/$(basename "$f")"
    out="$(PYTHONSAFEPATH=1 python3 "$core" --root "$FIX" "$f" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ] && ! printf '%s\n' "$out" | grep -q '^FAIL|'; then
      results="$results $name:OK"
    else
      results="$results $name:BAD"
    fi
  done

  for f in "$FIX"/unmeasurable/*.yml; do
    name="unmeas/$(basename "$f")"
    PYTHONSAFEPATH=1 python3 "$core" --root "$FIX" "$f" >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 2 ] && results="$results $name:OK" || results="$results $name:BAD"
  done

  # a workflow directory the extractor parses without finding a single `run:`
  # block is the extractor gone blind, not a clean tree
  PYTHONSAFEPATH=1 python3 "$core" --root "$TMP/norun" "$TMP/norun/.github/workflows" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 2 ] && results="$results blindness-guard:OK" || results="$results blindness-guard:BAD"

  printf '%s\n' "${results# }"
}

echo "=== PART A: the cases, against the checker in the tree ==="
BASELINE="$(run_cases "$CORE")"
n_cases=0
for item in $BASELINE; do
  n_cases=$((n_cases + 1))
  case "$item" in
    *:OK)  say_ok  "${item%:OK}" ;;
    *:BAD) say_bad "${item%:BAD}" "the checker disagreed with this case" ;;
  esac
done
echo "         $n_cases cases"

echo
echo "=== the wrapper's exit-code contract, over throwaway trees ==="
# 1 over a tree carrying the defect
mkdir -p "$TMP/red/.github/workflows"
cp "$FIX/bad/01-trailing-semicolon.yml" "$TMP/red/.github/workflows/ab.yml"
EHS_REPO_ROOT="$TMP/red" bash "$GATE" >"$TMP/red.out" 2>&1; rc=$?
if [ "$rc" -eq 1 ] && grep -q 'is never reached' "$TMP/red.out"; then
  say_ok wrapper-red-over-the-defect "rc=1"
else
  say_bad wrapper-red-over-the-defect "rc=$rc (wanted 1)"; sed 's/^/         /' "$TMP/red.out" | tail -5
fi
# 0 over a clean tree
mkdir -p "$TMP/green/.github/workflows"
cp "$FIX/good/01-or-capture.yml" "$TMP/green/.github/workflows/ok.yml"
EHS_REPO_ROOT="$TMP/green" bash "$GATE" >"$TMP/green.out" 2>&1; rc=$?
if [ "$rc" -eq 0 ]; then say_ok wrapper-green-over-a-clean-tree "rc=0"
else say_bad wrapper-green-over-a-clean-tree "rc=$rc (wanted 0)"; sed 's/^/         /' "$TMP/green.out" | tail -5; fi
# 2 with no workflows at all
EHS_REPO_ROOT="$TMP/notree" bash "$GATE" >"$TMP/none.out" 2>&1; rc=$?
if [ "$rc" -eq 2 ]; then say_ok wrapper-unmeasurable-without-workflows "rc=2"
else say_bad wrapper-unmeasurable-without-workflows "rc=$rc (wanted 2)"; fi
# 2 when the self-test is skipped: a gate that has not measured itself may not sign
EHS_REPO_ROOT="$TMP/green" GATE_SELFTEST=0 bash "$GATE" >"$TMP/nost.out" 2>&1; rc=$?
if [ "$rc" -eq 2 ]; then say_ok wrapper-caps-verdict-without-selftest "rc=2"
else say_bad wrapper-caps-verdict-without-selftest "rc=$rc (wanted 2)"; fi

# ---------------------------------------------------------------------------
echo
echo "=== PART B: mutants. Each one breaks a piece of the detector on a COPY."
echo "    A mutant that Part A does not notice means nothing measures that piece."
# mutate <name> <sed-expression> <expected-occurrences> <grep-pattern>
#
# The occurrence count is not decoration. A sabotage that lands on FEWER sites
# than intended leaves the piece half-working, the cases stay green, and the
# mutant is recorded as caught when what was caught is something else. The
# pattern is passed in literally rather than derived from the sed expression:
# deriving it is how a control ends up measuring its own parser.
mutate() {
  local name="$1" expr="$2" want="$3" pat="$4" got mutated after
  mutated="$TMP/mutant.py"
  got="$(grep -c -F -e "$pat" "$CORE" 2>/dev/null || true)"
  sed "$expr" "$CORE" > "$mutated"
  if cmp -s "$CORE" "$mutated"; then
    say_bad "mutant:$name" "the sabotage did not apply - the pattern no longer matches the checker"
    return
  fi
  if [ -n "$want" ] && [ "$got" != "$want" ]; then
    say_bad "mutant:$name" "expected to touch $want site(s) and the pattern matched $got"
    return
  fi
  after="$(run_cases "$mutated")"
  if [ "$after" = "$BASELINE" ]; then
    say_bad "mutant:$name" "SURVIVED - every case behaved exactly as with the real checker"
  else
    local broke=""
    for item in $after; do
      case "$item" in *:BAD) broke="$broke ${item%:BAD}" ;; esac
    done
    say_ok "mutant:$name" "caught by:${broke:- (case set changed)}"
  fi
}

# 1. the sanctioned form stops being recognised -> the compliant files go red
mutate or-form-unrecognised 's/sep == "||"/sep == "@@"/g' 2 'sep == "||"'
# 2. errexit is assumed OFF by default -> every real defect passes
mutate errexit-assumed-off 's/return True, "bash"/return False, "bash"/g' 2 'return True, "bash"'
# 3. the capture pattern is blinded -> the detector sees nothing anywhere
# shellcheck disable=SC2016  # a sed expression: single quotes are the point
mutate capture-pattern-blinded 's/=\\\$\\?(?!/=\\$\\$(?!/' 1 '=\$\?(?!'
# 4. the errexit test is short-circuited -> everything is declared safe
mutate errexit-test-short-circuited 's/elif not errexit_on:/elif True:/' 1 'elif not errexit_on:'
# 5. quote awareness removed -> a separator inside a string splits the command
mutate quote-awareness-removed 's/        if sq or dq:/        if False:/' 1 '        if sq or dq:'
# 6. `set +e` stops registering -> the bracketed form goes red
mutate set-plus-e-ignored 's/                state = False/                state = True/' 1 '                state = False'
# 7. continuation joining removed -> a capture on a `\` line loses its `||`
mutate continuation-join-removed 's/^        cont = stripped.endswith/        cont = False and stripped.endswith/' 1 '        cont = stripped.endswith'
# 8. the blindness guard removed -> a tree it cannot parse reports clean
mutate blindness-guard-removed 's/if stats\["run_blocks"\] == 0 and not/if False and not/' 1 'if stats["run_blocks"] == 0 and not'

echo
echo "Summary: $pass ok, $fail failures"
if [ "$fail" -gt 0 ]; then echo "Result: FAILED."; exit 1; fi
echo "Result: OK. The cases hold, and every sabotage of the detector was caught by them."
exit 0
