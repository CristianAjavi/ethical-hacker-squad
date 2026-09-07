#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Wrapper so run-batteries.sh runs the mutant bank of gate-checks-ran.sh.
#
# The bank itself is scripts/checks-ran.mutants.py. Neither file lives under
# scripts/gates/: run-all.sh treats anything matching gate-*.sh there as a gate,
# and this is not a gate but a proof about one.
#
# EXIT CODES: 0 every mutant was caught / 1 one survived / 2 could not run
# ---------------------------------------------------------------------------
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE/.." || { echo "  COULD NOT MEASURE: no repository root (rc 2)"; exit 2; }
exec "${EHS_PYTHON:-python3}" -u scripts/checks-ran.mutants.py "$@"
