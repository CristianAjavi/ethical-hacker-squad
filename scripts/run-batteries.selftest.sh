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

# run <root>  - the runner as it ships: parallel wherever the machine allows it.
# runs <root> - the same runner pinned to its serial path.
#
# `env -u` rather than merely not setting the variable. If the caller exported
# EHS_BATTERY_JOBS=1 - and anything A/B-ing this change does exactly that - an
# inherited value would send every "parallel" case down the serial path, and
# they would all pass having tested nothing.
run()  { env -u EHS_BATTERY_JOBS bash "$SUBJECT" "$1" >"$TMP/out" 2>&1; }
runs() { EHS_BATTERY_JOBS=1 bash "$SUBJECT" "$1" >"$TMP/out" 2>&1; }

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

runs "$TMP/greedy"; rc=$?
[ "$rc" -eq 0 ] && grep -q 'batteries run: 3' "$TMP/out" \
  && ok "the serial path does not let it eat the list either" \
  || bad "serial path truncated: rc $rc, $(grep -o 'batteries run: [0-9]*' "$TMP/out")"

echo "== mutant: prove the protection is doing the work =="

# Take away FD 3 and </dev/null, leaving the loop reading its list from stdin -
# the shape the rule had when it lived inline in a CI step. The greedy battery
# must now eat the rest of the list and the count must drop. If it does not, the
# case above is decoration and proves nothing.
#
# Pinned to the serial path, because that is the path this protection belongs
# to: a battery launched with `&` gets its stdin from /dev/null whether or not
# anyone asks, so the same mutant applied to the parallel path would kill
# nothing and would say the protection is not load-bearing when the truth is
# that it is load-bearing exactly here. The parallel path is covered above by
# its own greedy case.
sed -e 's#while IFS= read -r t <&3; do#while IFS= read -r t; do#' \
    -e 's#done 3< "$LIST"#done < "$LIST"#' \
    -e 's# </dev/null##' "$SUBJECT" > "$TMP/mutant.sh"
if cmp -s "$SUBJECT" "$TMP/mutant.sh"; then
  bad "the mutant did not apply: this battery would pass without measuring anything"
else
  EHS_BATTERY_JOBS=1 bash "$TMP/mutant.sh" "$TMP/greedy" >"$TMP/mout" 2>&1
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

echo "== the parallel path says exactly what the serial path says =="

# One tree holding all three outcomes at once, so the comparison covers the
# vocabulary and the ordering and not just the exit code. The report is built by
# the parent in list order on both paths, so byte-equality is the right bar
# here: the only thing that legitimately differs is which worker finished first,
# and that must never reach the output.
battery "$TMP/mixed"     a-green 0
battery "$TMP/mixed"     b-red   1
battery "$TMP/mixed/sub" c-unmeas 2
battery "$TMP/mixed/sub" d-green 0

runs "$TMP/mixed"; ser_rc=$?; cp "$TMP/out" "$TMP/out.serial"
run  "$TMP/mixed"; par_rc=$?; cp "$TMP/out" "$TMP/out.parallel"

[ "$ser_rc" -eq "$par_rc" ] \
  && ok "both paths exit with the same code ($ser_rc)" \
  || bad "serial exited $ser_rc, parallel exited $par_rc"

if cmp -s "$TMP/out.serial" "$TMP/out.parallel"; then
  # A comparison that cannot fail has measured nothing. Change one battery's
  # verdict and require the very same comparison to see it, so a day when both
  # files come back empty does not read as agreement.
  battery "$TMP/mixed" b-red 0
  runs "$TMP/mixed" >/dev/null 2>&1; cp "$TMP/out" "$TMP/out.control"
  battery "$TMP/mixed" b-red 1
  if cmp -s "$TMP/out.serial" "$TMP/out.control"; then
    bad "the comparison does not see a flipped verdict: it proves nothing"
  else
    ok "the two paths print the same report, with a working control"
  fi
else
  bad "the reports differ: $(diff "$TMP/out.serial" "$TMP/out.parallel" | head -4 | tr '\n' ' ')"
fi

echo "== the parallel path really overlaps =="

# Without this, a JOBS that quietly resolved to 1 would leave every case above
# passing while the change did nothing at all. Six batteries of one second: the
# serial path cannot finish in under six, three workers should take about two,
# and the bar is set at a saving too large for scheduling noise to fake.
mkdir -p "$TMP/slow"
i=0
while [ "$i" -lt 6 ]; do
  i=$((i + 1))
  printf '#!/usr/bin/env bash\nsleep 1\nexit 0\n' > "$TMP/slow/s$i.selftest.sh"
done
chmod +x "$TMP/slow"/*.selftest.sh

SECONDS=0; runs "$TMP/slow"; ser_rc=$?; ser_s=$SECONDS
SECONDS=0; EHS_BATTERY_JOBS=3 bash "$SUBJECT" "$TMP/slow" >"$TMP/out" 2>&1; par_rc=$?; par_s=$SECONDS

if [ "$ser_rc" -ne 0 ] || [ "$par_rc" -ne 0 ]; then
  bad "UNMEASURED: the timing fixture did not come back green (serial $ser_rc, parallel $par_rc)"
elif [ "$ser_s" -lt 5 ]; then
  bad "UNMEASURED: the serial arm took ${ser_s}s, so the fixture is not doing the work"
elif [ "$par_s" -le $((ser_s - 2)) ]; then
  ok "three workers took ${par_s}s where one took ${ser_s}s"
else
  bad "no overlap: ${par_s}s with three workers against ${ser_s}s with one"
fi

echo "== a worker that dies without an exit code is COULD NOT MEASURE =="

# The slot file is how a worker reports back, so the interesting failure is the
# worker that never writes one: killed, out of memory, the machine gave out.
# Read as a zero that pads the green with a battery that never finished; read
# correctly it is the one outcome that must never be a pass.
mkdir -p "$TMP/dies"
printf '#!/usr/bin/env bash\nkill -9 $PPID\nsleep 5\n' > "$TMP/dies/gone.selftest.sh"
chmod +x "$TMP/dies/gone.selftest.sh"
EHS_BATTERY_JOBS=2 bash "$SUBJECT" "$TMP/dies" >"$TMP/out" 2>&1; rc=$?
[ "$rc" -eq 2 ] && grep -q 'could not measure' "$TMP/out" \
  && ok "a worker that dies without recording an exit code is rc 2" \
  || bad "expected rc 2 and a COULD NOT MEASURE, got rc $rc"

echo
echo "$pass PASS / $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
exit 0
