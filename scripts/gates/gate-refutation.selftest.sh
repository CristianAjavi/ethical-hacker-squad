#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-refutation.selftest.sh - proves gate-refutation.sh can fail.
#
# Every mutant here is a way a refutation case stops being evidence while the
# file still reads like a file full of evidence: an edit that changes nothing,
# a rejection for the wrong reason, a case that drifted off its fixture, a
# fixture that was never clean, a floor that was lowered, two cases for one
# rule, a case file that is gone. The gate has to say so in each one.
#
# The first case is the positive control: the repository's own declared cases,
# unmodified, must pass. A bank of red mutants over a rule that is red anyway
# proves nothing.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$HERE/../.." && pwd -P)"
GATE="$HERE/gate-refutation.sh"
CASES="$ROOT/scripts/gates/data/refutation-cases.json"

command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is not on PATH"; exit 2; }
[ -f "$GATE" ]  || { echo "UNMEASURABLE the gate is missing"; exit 2; }
[ -f "$CASES" ] || { echo "UNMEASURABLE the declared cases are missing"; exit 2; }

WORK="$(mktemp -d)" || { echo "UNMEASURABLE cannot create a working directory"; exit 2; }
trap 'rm -rf "$WORK"' EXIT

ok=0; bad=0

# variant <name> <mutation> -> path to a mutated copy of the declared case file
variant() {
  python3 "$HERE/lib/refutation_selftest_fixture.py" "$CASES" "$WORK" "$1" "$2"
}

# expect <rc> <label> <case-file>
expect() {
  local want="$1" label="$2" file="$3" got
  "$GATE" --root "$ROOT" --cases "$file" >"$WORK/out.txt" 2>&1; got=$?
  if [ "$got" -eq "$want" ]; then
    printf 'ok       %-46s rc=%d\n' "$label" "$got"; ok=$((ok + 1))
  else
    printf 'FAIL     %-46s rc=%d (wanted %d)\n' "$label" "$got" "$want"; bad=$((bad + 1))
    sed -n '1,12p' "$WORK/out.txt"
  fi
}

expect 0 "the declared cases, untouched"        "$CASES"
expect 1 "an edit that changes nothing"         "$(variant no-op-edit "$WORK")"
expect 1 "rejected for the wrong reason"        "$(variant wrong-needle "$WORK")"
expect 1 "an edit that no longer matches"       "$(variant drifted-anchor "$WORK")"
expect 1 "an edit that matches twice"           "$(variant ambiguous-anchor "$WORK")"
expect 1 "a fixture that was never clean"       "$(variant dirty-fixture "$WORK")"
expect 1 "a fixture outside any good/ directory" "$(variant not-under-good "$WORK")"
expect 1 "one case fewer than the floor"        "$(variant below-floor "$WORK")"
expect 1 "two cases for the same rule"          "$(variant duplicate-needle "$WORK")"
expect 2 "a case file that is gone"             "$WORK/there-is-no-such-file.json"
expect 2 "a case file that does not parse"      "$(variant unparseable "$WORK")"
expect 2 "a validator that is gone"             "$(variant missing-validator "$WORK")"

printf '\nSummary: %d ok, %d failures\n' "$ok" "$bad"
[ "$bad" -eq 0 ] || exit 1
exit 0
