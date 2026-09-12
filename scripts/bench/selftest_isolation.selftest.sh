#!/usr/bin/env bash
# Self-test for selftest_isolation.py's verdict().
#
# WHY IT EXISTS
#   The isolation probe answers one question - does the sandbox deny the network
#   - by running the same socket probe twice and comparing. Its caller,
#   scripts/gates/gate-reproduction.selftest.sh, prints FAIL unless the pair
#   reads (unsandboxed opened it, sandboxed did not).
#
#   Two different worlds produce (False, False). One is a sandbox that leaks
#   nothing on a machine with no network of its own; the other is nothing wrong
#   at all. Calling either a failure of the sandbox is a red pointed at the one
#   component that is behaving, and this repository has a name for it: a NOT
#   MEASURED dressed up as a measurement.
#
#   The decision is now a pure function of two observations, which is what makes
#   it testable HERE: these cases need no network and no sandbox, so the machine
#   that cannot answer the real question can still prove the module knows it
#   cannot. The end-to-end path - the module actually run on a machine with a
#   sandbox and no network - is NOT measured by this battery and is not claimed:
#   the socket either opens or it does not, and neither this file nor its
#   author can take the network away from a runner to find out.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MOD="$HERE/selftest_isolation.py"
pass=0; fail=0

die() { printf '\n[COULD NOT MEASURE] %s\n' "$*" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || die "python3 is missing"
[ -f "$MOD" ] || die "selftest_isolation.py is missing beside this battery"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-isolation-XXXXXX")" || die "no temporary directory"
LAST_MUT=""
trap 'rm -rf "$TMP"' EXIT

# The driver loads the module BY PATH, so a mutated copy can be asked the same
# question as the shipped one. It calls verdict() only: importing the module
# must not open a socket, and if it ever does, every case below hangs and says
# so rather than passing.
cat > "$TMP/ask.py" <<'PY'
import importlib.util
import json
import sys

spec = importlib.util.spec_from_file_location("iso_under_test", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
if not hasattr(mod, "verdict"):
    sys.stderr.write("the module has no verdict()\n")
    raise SystemExit(3)
print(json.dumps(mod.verdict(json.loads(sys.argv[2]), json.loads(sys.argv[3])), sort_keys=True))
PY

obs() { # obs <reproduces: true|false> <evidence> [unmeasurable]
  printf '{"reproduces": %s, "evidence": "%s", "unmeasurable": "%s"}' "$1" "$2" "${3:-}"
}

# ask <module> <sub-observation> <seat-observation> -> the JSON it would print
ask() {
  python3 "$TMP/ask.py" "$1" "$2" "$3" 2>"$TMP/err.txt"
}

# case <label> <module> <sub> <seat> <substring that must be in the answer>
check() {
  local label="$1" mod="$2" sub="$3" seat="$4" want="$5" got rc=0
  got="$(ask "$mod" "$sub" "$seat")" || rc=$?
  if [ "$rc" -ne 0 ]; then
    printf 'FAILED   %-46s driver rc=%s %s\n' "$label" "$rc" "$(head -1 "$TMP/err.txt")"
    fail=$((fail + 1)); return
  fi
  case "$got" in
    *"$want"*) printf 'ok       %-46s %s\n' "$label" "$got"; pass=$((pass + 1)) ;;
    *)         printf 'FAILED   %-46s wanted %s | got %s\n' "$label" "$want" "$got"
               fail=$((fail + 1)) ;;
  esac
}

# --- 1. the three answers ---------------------------------------------------
check "the sandbox denied what the control opened" "$MOD" \
  "$(obs true 'the socket opened')" "$(obs false ConnectionRefusedError)" \
  '"seatbelt": false'

# The one real failure: the control opened it AND the sandbox opened it too.
# `"seatbelt": true` is what makes the caller print FAIL, and that must survive.
check "the sandbox let the socket through" "$MOD" \
  "$(obs true 'the socket opened')" "$(obs true 'the socket opened')" \
  '"seatbelt": true'

# The case this battery exists for.
check "no network: a skip, not a red" "$MOD" \
  "$(obs false OSError)" "$(obs false OSError)" \
  '"skip"'

# and it must carry the control's own evidence, or the reader is told a story
# without the fact: `skip` with no cause is the same silence as a pass.
check "the skip names the control's evidence" "$MOD" \
  "$(obs false gaierror)" "$(obs false gaierror)" \
  'gaierror'

# --- 2. an observation that is not an answer --------------------------------
check "an unmeasurable child is a skip" "$MOD" \
  "$(obs false '' 'the child did not return an observation')" "$(obs false '')" \
  'no observation'

check "an unmeasurable SANDBOX is a skip too" "$MOD" \
  "$(obs true 'the socket opened')" "$(obs false '' 'the child crashed')" \
  '"skip"'

# --- 3. the contract with the caller ----------------------------------------
# gate-reproduction.selftest.sh greps the literal `"skip"` and then reads
# `subprocess` and `seatbelt` as booleans. A rename here is a silent FAIL there.
for key in subprocess seatbelt; do
  check "the caller's key \`$key\` survives" "$MOD" \
    "$(obs true 'the socket opened')" "$(obs false OSError)" "\"$key\""
done

# --- 4. the mutants: each rule is shown to be load-bearing -------------------
# A rule that no mutation can remove is a rule this battery has never been shown
# to notice. Each anchor is knocked out in a COPY; the shipped module is never
# touched, and the copy is asked the same question as above.
mutant() { # mutant <label> <anchor> <sub> <seat> <what must STOP being true>
  local label="$1" anchor="$2" sub="$3" seat="$4" gone="$5" got rc=0
  # ONE PATH PER MUTANT. python caches bytecode beside the file and invalidates
  # it by (mtime, size); every mutant here is the same size as the last (`= 1`
  # becomes `= 0`) and they are written in the same second, so a shared path
  # made the second import replay the FIRST mutant's bytecode - two mutants,
  # one measurement, and the source on disk showing the change that never ran.
  local mut="$TMP/mutant-$anchor.py"
  LAST_MUT="$mut"
  # the sibling goes with it: the module resolves `environments` next to its own
  # file, so a copy left alone in a temporary directory cannot even be imported
  # and the mutant would "fail" for a reason that has nothing to do with the rule.
  cp "$MOD" "$mut" && cp "$HERE/environments.py" "$HERE/_probe_child.py" "$TMP/" \
    || { printf 'FAILED   %-46s could not copy the module and its sibling\n' "$label"
         fail=$((fail + 1)); return; }
  if ! grep -q "^${anchor} = 1$" "$mut"; then
    printf 'FAILED   %-46s no anchor `%s` to knock out\n' "$label" "$anchor"
    fail=$((fail + 1)); return
  fi
  python3 - "$mut" "$anchor" <<'PY'
import re, sys
p, anchor = sys.argv[1], sys.argv[2]
t = open(p).read()
t, n = re.subn(r"(?m)^%s = 1$" % re.escape(anchor), "%s = 0" % anchor, t)
assert n == 1, "the anchor was substituted %d times, so the mutant proves nothing" % n
open(p, "w").write(t)
PY
  got="$(ask "$mut" "$sub" "$seat")" || rc=$?
  if [ "$rc" -ne 0 ]; then
    printf 'FAILED   %-46s mutant driver rc=%s %s\n' "$label" "$rc" \
      "$(head -1 "$TMP/err.txt")"; fail=$((fail + 1)); return
  fi
  case "$got" in
    *"$gone"*) printf 'FAILED   %-46s the rule was removed and nothing changed: %s\n' \
                 "$label" "$got"; fail=$((fail + 1)) ;;
    *)         printf 'ok       %-46s %s\n' "$label" "$got"; pass=$((pass + 1)) ;;
  esac
}

mutant "without SKIP_WHEN_NO_CONTROL, no network reds" SKIP_WHEN_NO_CONTROL \
  "$(obs false OSError)" "$(obs false OSError)" '"skip"'
# The scenario has to be one the OTHER rule does not already answer: with the
# control reading false, SKIP_WHEN_NO_CONTROL returns a skip on its own and the
# mutant proves nothing. Here the control opened the socket and the sandboxed
# run crashed, which without this rule is published as `seatbelt: false` - a
# sandbox credited with denying a socket it never got to see.
mutant "without SKIP_WHEN_UNMEASURABLE, a crash passes" SKIP_WHEN_UNMEASURABLE \
  "$(obs true 'the socket opened')" "$(obs false '' 'the child crashed')" '"skip"'

# and the shipped module is byte-for-byte what it was: a battery that leaves a
# mutant behind hands the next reader a green over code nobody wrote.
if [ -n "${LAST_MUT:-}" ] && [ -f "$LAST_MUT" ] && cmp -s "$MOD" "$LAST_MUT"; then
  printf 'FAILED   %-46s the last mutant is identical to the shipped module\n' \
    "the mutants were applied to a copy"
  fail=$((fail + 1))
else
  printf 'ok       %-46s the shipped module was never written to\n' \
    "the mutants were applied to a copy"
  pass=$((pass + 1))
fi

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. A machine with no network is answered with a skip that names"
echo "        its cause, and a sandbox that leaks is still a failure."
exit 0
