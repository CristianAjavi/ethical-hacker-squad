#!/usr/bin/env bash
# scripts/gh/tests/gh.selftest.sh
#
# Discovery entry point for this battery, and nothing else.
#
# WHY IT EXISTS. `.github/workflows/ci.yml` proves the batteries in the negative
# by DISCOVERING them - "a self-test battery that only ever runs on a
# maintainer's laptop is not a monitored one", says the comment there, about two
# batteries that were in exactly that position. This one was the third: the
# suites under scripts/gh/tests/ matched no discovery rule and ran nowhere.
#
# The convention that gets discovered is `*.selftest.sh` under scripts/. This
# file is that name, so the battery is covered by the rule instead of by a line
# in a workflow that someone has to remember to edit.
#
# Exit codes are the runner's, unchanged: 0 measured and green, 1 measured and
# failing, 2 something could not measure.
set -uo pipefail
exec "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/run-all.sh" "$@"
