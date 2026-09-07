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

# This file runs blind to any ledger its caller is using, and every case that
# wants one builds its own. Found the hard way: run under run-batteries.sh -
# which exports EHS_TALLY_LEDGER - the "no ledger written" case inherited it,
# passed anyway, and the toy battery it launched wrote a line into the REAL
# ledger. A case that is green because of what it inherited is green for the
# wrong reason, and the artefact it polluted belonged to someone else.
unset EHS_TALLY_LEDGER

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

# says <dir> <name> <exit-code> <line> — a battery that prints something first
says() {
  mkdir -p "$1"
  printf '#!/usr/bin/env bash\necho "%s"\nexit %s\n' "$4" "$3" > "$1/$2.selftest.sh"
  chmod +x "$1/$2.selftest.sh"
}

run() { bash "$SUBJECT" "$1" >"$TMP/out" 2>&1; }

# runl <dir> <ledger> — the same run, with a tally ledger to fill in
runl() { EHS_TALLY_LEDGER="$2" bash "$SUBJECT" "$1" >"$TMP/out" 2>&1; }

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

echo "== the tally ledger: what gets recorded, and what must not =="

# The gate that checks the case counts in docs/gate-requirements.md runs these
# same batteries. When this runner leaves its tallies behind, that gate reads
# them instead of running them again: measured 40.4 s -> 3.9 s, ranges apart.
# What it records is therefore load-bearing, and so is what it refuses to.

says "$TMP/led_ok" green 0 "5 passed, 0 failed"
runl "$TMP/led_ok" "$TMP/led_ok.txt"
if [ -s "$TMP/led_ok.txt" ] && grep -q '5 passed, 0 failed' "$TMP/led_ok.txt" \
   && [ "$(awk '{print length($1)}' "$TMP/led_ok.txt" | head -1)" = "64" ]; then
  ok "a green battery leaves one line: sha256, path, tally"
else
  bad "no usable ledger line: $(cat "$TMP/led_ok.txt" 2>&1 | head -1)"
fi

# A count read off a red battery is not a measurement. It must not reach the
# ledger at all, because on the other side a hit is trusted without a rerun.
says "$TMP/led_red" red 1 "3 passed, 1 failed"
runl "$TMP/led_red" "$TMP/led_red.txt"
[ ! -s "$TMP/led_red.txt" ] \
  && ok "a battery that came back red records nothing" \
  || bad "a red battery got into the ledger: $(head -1 "$TMP/led_red.txt")"

says "$TMP/led_mute" mute 0 "the battery ran and everything was fine"
runl "$TMP/led_mute" "$TMP/led_mute.txt"
[ ! -s "$TMP/led_mute.txt" ] \
  && ok "a battery that prints no tally records nothing" \
  || bad "a battery with no tally got in: $(head -1 "$TMP/led_mute.txt")"

# The default is off. A runner that wrote a ledger nobody asked for would be
# leaving a file in whatever directory it happened to be pointed at.
says "$TMP/led_off" green 0 "5 passed, 0 failed"
run "$TMP/led_off"
[ ! -e "$TMP/led_off.txt" ] \
  && ok "no EHS_TALLY_LEDGER, no ledger written" \
  || bad "a ledger appeared without being asked for"

# The key is the CONTENT. Change one byte of the battery and the old line can
# no longer answer for it - that is the whole staleness argument, measured.
says "$TMP/led_key" green 0 "5 passed, 0 failed"
runl "$TMP/led_key" "$TMP/led_key1.txt"
says "$TMP/led_key" green 0 "6 passed, 0 failed"
runl "$TMP/led_key" "$TMP/led_key2.txt"
k1="$(awk '{print $1}' "$TMP/led_key1.txt" | head -1)"
k2="$(awk '{print $1}' "$TMP/led_key2.txt" | head -1)"
if [ -n "$k1" ] && [ -n "$k2" ] && [ "$k1" != "$k2" ]; then
  ok "editing the battery changes the key, so an old line cannot answer for it"
else
  bad "the key did not move with the content: $k1 vs $k2"
fi

# The leak above, as a case: with a ledger in the ENVIRONMENT and none asked
# for, the runner must not write into it. Nothing else in this file would notice
# - the toy directory stays clean either way, and the line lands elsewhere.
says "$TMP/led_leak" green 0 "5 passed, 0 failed"
: > "$TMP/led_probe.txt"
EHS_TALLY_LEDGER="$TMP/led_probe.txt" bash "$SUBJECT" "$TMP/led_leak" >"$TMP/out" 2>&1
if [ -s "$TMP/led_probe.txt" ]; then
  ok "a ledger in the environment IS honoured, so the probe can tell silence apart"
else
  bad "the probe stayed empty: this case cannot tell a leak from a refusal"
fi

echo
echo "$pass PASS / $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
exit 0
