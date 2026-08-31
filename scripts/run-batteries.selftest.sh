#!/usr/bin/env bash
# Self-test for run-batteries.sh.
#
# A runner that reports green is making a claim about batteries it never ran, so
# every case here is about the ways that claim goes wrong quietly: a battery that
# fails, one that cannot measure, none at all, a fixture stub padding the count,
# and a battery that eats the list it is being read from. The last one is the
# reason this runner reads over FD 3 and launches with </dev/null, and the mutant
# at the end proves that is load-bearing rather than folklore.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SUBJECT="$HERE/run-batteries.sh"
[ -f "$SUBJECT" ] || { echo "UNMEASURABLE the subject is missing: $SUBJECT"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-runner-XXXXXX")" || { echo "UNMEASURABLE no tmpdir"; exit 2; }
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  PASS  $1"; }
bad() { fail=$((fail+1)); echo "  FAIL  $1"; }

# battery <dir> <name> <exit-code> — a battery that does nothing but exit
battery() {
  mkdir -p "$1"
  printf '#!/usr/bin/env bash\nexit %s\n' "$3" > "$1/$2.selftest.sh"
  chmod +x "$1/$2.selftest.sh"
}

run() { bash "$SUBJECT" "$1" >"$TMP/out" 2>&1; }

echo "== the ordinary verdicts =="

battery "$TMP/green/a" one 0
battery "$TMP/green/b" two 0
run "$TMP/green"; rc=$?
[ "$rc" -eq 0 ] && ok "every battery behaving gives rc 0" || bad "expected rc 0, got $rc"
grep -q 'batteries run: 2' "$TMP/out" && ok "the count is reported" || bad "no count reported"

battery "$TMP/red" ok  0
battery "$TMP/red" bad 1
run "$TMP/red"; rc=$?
[ "$rc" -eq 1 ] && ok "a battery that fails gives rc 1" || bad "expected rc 1, got $rc"
grep -q 'did not behave.*bad.selftest.sh' "$TMP/out" \
  && ok "the failing battery is named, not just counted" || bad "the failure is anonymous"

echo "== could not measure outranks both green and red =="

battery "$TMP/unmeas" ok   0
battery "$TMP/unmeas" cant 2
run "$TMP/unmeas"; rc=$?
[ "$rc" -eq 2 ] && ok "a battery reporting 2 gives rc 2, never 0" || bad "expected rc 2, got $rc"

battery "$TMP/both" bad  1
battery "$TMP/both" cant 2
run "$TMP/both"; rc=$?
[ "$rc" -eq 2 ] && ok "2 outranks 1 when both happen" || bad "expected rc 2 when both, got $rc"

mkdir -p "$TMP/none" && : > "$TMP/none/README.md"
run "$TMP/none"; rc=$?
[ "$rc" -eq 2 ] && ok "finding no battery is rc 2, not a silent green" || bad "expected rc 2, got $rc"

run "$TMP/absent-root"; rc=$?
[ "$rc" -eq 2 ] && ok "an absent root is rc 2" || bad "expected rc 2 for an absent root, got $rc"

echo "== a fixture stub is not a battery =="

battery "$TMP/pruned" real 0
battery "$TMP/pruned/fixtures/some/tree" stub 1
run "$TMP/pruned"; rc=$?
[ "$rc" -eq 0 ] && ok "a failing stub under fixtures/ does not fail the run" \
                || bad "fixtures/ was not pruned: rc $rc"
grep -q 'batteries run: 1' "$TMP/out" \
  && ok "the stub does not pad the count either" || bad "the stub was counted"

echo "== a battery that reads stdin must not swallow the list =="

mkdir -p "$TMP/greedy"
printf '#!/usr/bin/env bash\ncat >/dev/null\nexit 0\n' > "$TMP/greedy/a-greedy.selftest.sh"
battery "$TMP/greedy" b-after 0
battery "$TMP/greedy" c-after 0
chmod +x "$TMP/greedy"/*.selftest.sh
run "$TMP/greedy"; rc=$?
[ "$rc" -eq 0 ] && ok "the greedy battery itself passes" || bad "greedy fixture rc $rc"
grep -q 'batteries run: 3' "$TMP/out" \
  && ok "all three ran — the greedy one did not eat the list" \
  || bad "the list was truncated: $(grep -o 'batteries run: [0-9]*' "$TMP/out")"

echo "== mutant: prove the protection is doing the work =="

# Take away FD 3 and </dev/null, leaving the loop reading its list from stdin -
# the shape the rule had when it lived inline in a CI step. The greedy battery
# must now eat the rest of the list and the count must drop. If it does not, the
# case above is decoration and proves nothing.
sed -e 's#while IFS= read -r t <&3; do#while IFS= read -r t; do#' \
    -e 's#done 3< "$LIST"#done < "$LIST"#' \
    -e 's# </dev/null##' "$SUBJECT" > "$TMP/mutant.sh"
if cmp -s "$SUBJECT" "$TMP/mutant.sh"; then
  bad "the mutant did not apply: this battery would pass without measuring anything"
else
  bash "$TMP/mutant.sh" "$TMP/greedy" >"$TMP/mout" 2>&1
  if grep -q 'batteries run: 3' "$TMP/mout"; then
    bad "the mutant ALSO runs all three: the FD-3 and </dev/null are not what protects"
  else
    ok "the mutant truncates the list ($(grep -o 'batteries run: [0-9]*' "$TMP/mout" || echo 'none')) — the protection is load-bearing"
  fi
fi

echo "== --list names them without running them =="

battery "$TMP/listing" only 1
bash "$SUBJECT" --list "$TMP/listing" >"$TMP/out" 2>&1; rc=$?
[ "$rc" -eq 0 ] && grep -q 'only.selftest.sh' "$TMP/out" \
  && ok "--list prints the battery and does not run it" \
  || bad "--list misbehaved: rc $rc"

echo
echo "$pass PASS / $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
exit 0
