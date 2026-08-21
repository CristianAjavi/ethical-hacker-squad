#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Test bench of the governance area. Everything is local and hermetic: the
# GitHub API and the 'gh' binary are replaced by doubles, and the git history is
# fabricated with backdated commits. It makes no network call at all unless you
# set GOV_TESTS_NETWORK=1.
#
# What it tests, and why these tests and not others: each case corresponds to a
# concrete way for the automatic promotion to publish something it should not.
#
# EXIT CODES
#   0 = I ran every suite and they pass
#   1 = I ran them and one FAILS
#   2 = I COULD NOT RUN some suite (python3/pyyaml/jq/git missing, or a suite
#       returned 2 because what it watches is not there to be measured)
# Precedence: 1 beats 2. A proven failure is stronger information than an
# unmeasured suite, and both are non-zero, so both stop the caller either way.
# What may never happen is that an rc=2 from a suite gets reported as 0.
# ---------------------------------------------------------------------------
set -uo pipefail
SP="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SP/../../.." && pwd)"

MISSING=""
for t in bash git jq python3; do
  command -v "$t" >/dev/null 2>&1 || MISSING="$MISSING $t"
done
python3 -c 'import yaml' 2>/dev/null || MISSING="$MISSING python3-pyyaml"
if [ -n "$MISSING" ]; then
  echo "I CANNOT RUN THE TESTS: missing$MISSING"
  echo "rc=2 means 'I did not check it', which is not the same as 'it is fine'."
  exit 2
fi

FAILED=""
UNMEASURED=""
suite() {
  # The title is saved BEFORE the shift. It used to be read after it, so every
  # red suite was reported as "- bash" or "- python3": the summary named the
  # interpreter instead of the suite that failed.
  title="$1"
  echo ""
  echo "###############################################################"
  echo "# $title"
  echo "###############################################################"
  shift
  rc=0
  "$@" || rc=$?
  if [ "$rc" -eq 0 ]; then
    return 0
  fi
  # A suite that returns 2 did not measure; folding it into "red" would hide the
  # difference between "it fails" and "there was nothing to check".
  if [ "$rc" -eq 2 ]; then
    UNMEASURED="$UNMEASURED
  - $title (rc=2)"
  else
    FAILED="$FAILED
  - $title (rc=$rc)"
  fi
}

suite "Workflow structure (triggers, permissions, SHAs, injection)" \
  python3 "$SP/validate-workflow.py" "$ROOT/.github/workflows/release.yml"
suite "NEGATIVE: the workflow validator rejects every malicious mutation" \
  python3 "$SP/test-workflow-mutations.py"
suite "Promotion decision logic" \
  bash "$SP/test-promote-decision.sh"
suite "Gates job + negative paths of apply-governance.sh" \
  bash "$SP/test-gates-and-governance.sh"
suite "NEGATIVE: the gates loop cannot skip any gate" \
  bash "$SP/test-gates-loop.sh"
suite "apply-governance.sh against a simulated API (rc=0 is reachable)" \
  bash "$SP/test-governance-rc0.sh"
suite "NEGATIVE: no declared protection field is left unwatched" \
  bash "$SP/test-governance-drift.sh"

echo ""
echo "==============================================================="
if [ -n "$UNMEASURED" ]; then
  echo "SUITES THAT COULD NOT MEASURE (rc=2, not the same as green):$UNMEASURED"
fi
if [ -n "$FAILED" ]; then
  echo "SUITES IN RED:$FAILED"
  exit 1
fi
if [ -n "$UNMEASURED" ]; then
  exit 2
fi
echo "ALL SUITES GREEN"
exit 0
