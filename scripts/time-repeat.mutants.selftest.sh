#!/usr/bin/env bash
# scripts/time-repeat.mutants.selftest.sh
#
# Runs the mutation bank over the timing instrument's own rules. The bank lives
# in time-repeat.mutants.py, which carries the whole argument; this file is what
# makes run-batteries.sh pick it up, because a bank nobody runs measures nothing.
#
# It is deliberately NOT under scripts/gates/, for the same reason its sibling
# coverage-sweep.mutants.selftest.sh is not: run-all.sh discovers a gate by
# walking that directory and taking whatever is not documentation, data,
# fixtures or lib/, so a bank left there IS a gate, and contract-inventory and
# negative-proof would both say so.
#
# It costs 174 s measured - one whole battery per mutant, twenty of them, plus
# the baseline - against a suite whose own wall clock disagrees with itself by
# 174 s over identical code on this machine. That is not an argument for it
# being free; it is the reason the cost is declared here as work rather than
# defended with a stopwatch reading this box cannot produce.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
exec "${EHS_PYTHON:-python3}" -u scripts/time-repeat.mutants.py "$@"
