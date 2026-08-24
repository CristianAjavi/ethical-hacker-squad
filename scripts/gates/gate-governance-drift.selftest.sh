#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Proves gate-governance-drift.sh in the negative.
#
# The gate is a thin wrapper: everything it knows it learns from
# scripts/gh/apply-governance.sh, whose own comparator is already proven field
# by field in scripts/gh/tests/. What is NOT proven there, and is proven here,
# is that the wrapper does not launder its delegate's verdict - that a 2 stays
# a 2, that a 1 stays a 1, and that the two ways of having no measurement at
# all (no gh, no comparator) are 2 and not a silent 0.
#
# Every case is expected to FAIL the gate except the baseline. A case that
# stops failing means the wrapper has gone blind to it.
#
# EXIT CODES: 0 every case behaved / 1 a case did not / 2 could not run
# ---------------------------------------------------------------------------
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GATE="$HERE/gate-governance-drift.sh"
[ -x "$GATE" ] || { echo "  COULD NOT MEASURE: $GATE is not executable (rc 2)"; exit 2; }

LAB="$(mktemp -d)"; trap 'rm -rf "$LAB"' EXIT
mkdir -p "$LAB/bin"

# A gh double. `auth status` succeeds; every api call fails, which is what makes
# the gate add --skip-stable, and the comparator is a stub anyway.
cat > "$LAB/bin/gh" <<'SH'
#!/bin/sh
case "$1" in
  auth) exit 0 ;;
  *) exit 1 ;;
esac
SH
chmod +x "$LAB/bin/gh"

# A comparator double whose exit code is dictated by the case.
mk_comparator() {
  cat > "$LAB/comparator.sh" <<SH
#!/bin/sh
echo "== Branch protection: main"
echo "$2"
exit $1
SH
  chmod +x "$LAB/comparator.sh"
}

fails=0
run_case() {  # name expected_rc  (env already set by caller)
  local name="$1" want="$2"; shift 2
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ]; then
    printf '  [self-test OK]   %-46s rc=%s\n' "$name" "$rc"
  else
    printf '  [self-test FAIL] %-46s rc=%s, expected %s\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/      /'
    fails=$((fails + 1))
  fi
}

# 1. Baseline: the comparator says the live state matches. The gate must agree,
#    otherwise rc 0 is unreachable and the gate has stopped being a measurement.
mk_comparator 0 "   OK         everything matches"
run_case "clean live state -> the gate passes" 0 \
  env PATH="$LAB/bin:$PATH" EHS_GOVERNANCE_SCRIPT="$LAB/comparator.sh" "$GATE"

# 2. Drift must survive the wrapper as drift, not be rounded to a pass.
mk_comparator 1 "   DRIFT      main: the real protection does NOT match the declared one"
run_case "measured drift -> rc 1" 1 \
  env PATH="$LAB/bin:$PATH" EHS_GOVERNANCE_SCRIPT="$LAB/comparator.sh" "$GATE"

# 3. The comparator's own 'I could not measure' must not become a pass. This is
#    the case that matters: an unread branch protection reads exactly like an
#    unprotected one, and only the exit code tells them apart.
mk_comparator 2 "   UNMEASURED no admin permission on the protection endpoint"
run_case "comparator could not measure -> rc 2" 2 \
  env PATH="$LAB/bin:$PATH" EHS_GOVERNANCE_SCRIPT="$LAB/comparator.sh" "$GATE"

# 4. No comparator at all. A missing delegate is no measurement, never a pass.
run_case "comparator missing -> rc 2" 2 \
  env PATH="$LAB/bin:$PATH" EHS_GOVERNANCE_SCRIPT="$LAB/nope.sh" "$GATE"

# 5. No gh at all. The live state cannot be read, so there is nothing to pass.
#    An empty PATH is not the way to say that - it removes bash and sed too, and
#    the gate then dies at 127, which is a broken harness reporting a pass-shaped
#    failure. So the PATH is real minus gh: every binary the gate uses, and only
#    those.
mkdir -p "$LAB/nogh"
for b in bash sed; do
  src="$(command -v "$b" 2>/dev/null)" || { echo "  COULD NOT MEASURE: $b not on PATH (rc 2)"; exit 2; }
  ln -sf "$src" "$LAB/nogh/$b"
done
mk_comparator 0 "   OK         everything matches"
run_case "gh absent -> rc 2" 2 \
  env PATH="$LAB/nogh" EHS_GOVERNANCE_SCRIPT="$LAB/comparator.sh" "$GATE"

# 6. gh present but unauthenticated. Every GET would 401, and a 401 on the
#    protection endpoint is indistinguishable from an unprotected branch.
cat > "$LAB/bin/gh" <<'SH'
#!/bin/sh
exit 1
SH
chmod +x "$LAB/bin/gh"
run_case "gh not authenticated -> rc 2" 2 \
  env PATH="$LAB/bin:$PATH" EHS_GOVERNANCE_SCRIPT="$LAB/comparator.sh" "$GATE"

if [ "$fails" -ne 0 ]; then
  echo "gate-governance-drift.selftest: $fails case(s) did not behave (rc 1)"; exit 1
fi
echo "gate-governance-drift.selftest: 6 cases, all behaved (rc 0)"
