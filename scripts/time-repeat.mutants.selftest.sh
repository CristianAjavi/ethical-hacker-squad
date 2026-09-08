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
# One whole battery per mutant, twenty of them, plus the baseline. Those 21 runs
# used to go one after another and made this the slowest battery in the suite;
# they now run EHS_TIMING_JOBS at a time, 4 by default, because each works on its
# own copy of the tree and reads nothing the others write. The cost is declared
# here as work rather than defended with a stopwatch reading this box cannot
# produce: its own wall clock disagrees with itself by 174 s over identical code.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
exec "${EHS_PYTHON:-python3}" -u scripts/time-repeat.mutants.py "$@"
