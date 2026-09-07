#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-declared-case-counts.sh — the case counts the documentation promises,
# read off the self-tests that actually run.
#
# WHY IT EXISTS
#   Every row of docs/gate-requirements.md that carries a self-test reads
#   `gate-X.sh` + self-test (N cases). Nothing ever compared that N to
#   anything. Measured on 2026-09-07, before this gate existed:
#
#     gate-coverage-sweep    said 31, ran 47   cases added over four commits,
#                                              the row never touched
#     gate-triage-stage      said 32, ran 31   wrong the day it was written
#                                              (dc441f0); the battery has not
#                                              changed since a95347f (#39)
#     gate-portable-shell    said 22, ran 25   caught by hand the same week
#
#   Two of twelve wrong, and four more that could not be compared to anything
#   because their self-test never says how many cases it ran. A number in a
#   document that nothing checks is a claim, and this particular claim had
#   already been wrong three times.
#
# WHAT IT MEASURES
#   For every `self-test (N cases)` row: run that gate's self-test, read the
#   `N passed, M failed` line it prints, and compare N+M against the row. A
#   battery that can skip a case prints a third number and it counts too: CI
#   found gate-reproduction running 33 cases on macOS and 32 on Linux, because
#   one case needs sandbox-exec and its skip branch counted toward neither.
#   Three invocation conventions live in this repository and the gate finds
#   each rather than assuming one: a sibling `<gate>.selftest.sh`, a
#   `--self-test` flag on the gate, or a self-test that runs inline on a
#   normal run.
#
# WHAT IT DOES NOT MEASURE
#   Whether the cases are any good, whether N is the RIGHT number of cases for
#   that gate, or whether a green case measures its rule - that is what the
#   mutant banks are for. This decides one thing: whether the document tells
#   the truth about how many there are.
#
#   It also does not see a gate with no `self-test (N cases)` row at all. A
#   gate whose row omits the count is invisible here, and gate-negative-proof
#   is the one that refuses a gate with no battery.
#
# COST
#   It runs twelve self-tests, eight at a time. Measured on this ten-core box:
#   67.1 s sequential, 39.7 s at eight threads, and the floor is one battery
#   (gate-reproduction, 33.4 s) that no amount of threads divides.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, missing core, unreadable document, a self-test that
# prints no count, or a self-test that came back red).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/declared_case_counts.py"

gate_header "declared-case-counts (the number the document promises, run)"
gate_scope "every 'self-test (N cases)' row of docs/gate-requirements.md, compared against the count its self-test prints when it runs"
gate_out_of_scope "whether the cases are good, whether N is the right number, and any gate whose row carries no case count at all"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was measured"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$CORE" ]; then
  gate_warn "the measurement core is missing: $CORE"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

out="$(python3 "$CORE" "$ROOT" ${EHS_DECLARED_COUNTS_DOC:+"$EHS_DECLARED_COUNTS_DOC"} 2>&1)"; rc=$?
findings=0
while IFS= read -r line; do
  case "$line" in
    FINDING\ *)    gate_fail "${line#FINDING }"; findings=$((findings + 1)) ;;
    UNMEASURED\ *) gate_warn "${line#UNMEASURED }" ;;
    UNMEASURABLE\ *) gate_warn "${line#UNMEASURABLE }" ;;
    *)             [ -n "$line" ] && gate_info "$line" ;;
  esac
done <<< "$out"

# A core that dies mid-run also exits 1. A verdict of "it FAILS" with nothing
# named is not a measurement, it is a crash wearing the exit code of one.
if [ "$rc" -eq 1 ] && [ "$findings" -eq 0 ]; then
  gate_warn "the core exited 1 and named no drifted row: that is a crash, not a verdict"
  rc="$GATE_UNMEASURABLE"
fi

case "$rc" in
  0) gate_ok "every declared case count matches the self-test that runs" ;;
  1) : ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac
gate_verdict "$rc"
exit "$rc"
