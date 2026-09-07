#!/usr/bin/env bash
# scripts/coverage-sweep.mutants.selftest.sh
#
# Runs the mutation bank over the coverage sweep's own refusals. The bank lives
# in coverage-sweep.mutants.py, which carries the whole argument; this file is what makes
# run-batteries.sh pick it up, because a bank nobody runs measures nothing.
#
# It is deliberately NOT under scripts/gates/. run-all.sh discovers a gate by
# walking that directory and taking whatever is not documentation, data,
# fixtures or lib/ - so a bank left there IS a gate, and contract-inventory and
# negative-proof both said so. Nor under scripts/gates/lib/: every .py there is
# a subject of the sweep, and this bank's `.append` calls are plumbing that
# would be read as report sites and reported as holes.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
exec "${EHS_PYTHON:-python3}" -u scripts/coverage-sweep.mutants.py "$@"
