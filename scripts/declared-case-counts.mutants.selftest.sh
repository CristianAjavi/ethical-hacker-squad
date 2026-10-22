#!/usr/bin/env bash
# scripts/declared-case-counts.mutants.selftest.sh
#
# Runs the mutation bank over gate-declared-case-counts, the tally ledger it
# reads, and the runner that writes it. The bank lives in
# declared-case-counts.mutants.py and carries the whole argument; this file is
# what makes run-batteries.sh pick it up, because a bank nobody runs measures
# nothing. It spent two iterations in a scratchpad being rewritten; the second
# time a tool is needed it belongs in the repository, wired to the runner.
#
# It is deliberately NOT under scripts/gates/. run-all.sh discovers a gate by
# walking that directory and taking whatever is not documentation, data,
# fixtures or lib/ - so a bank left there IS a gate, and contract-inventory and
# negative-proof both say so.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
exec "${EHS_PYTHON:-python3}" -u scripts/declared-case-counts.mutants.py "$@"
