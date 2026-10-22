#!/usr/bin/env bash
# scripts/verify.sh
#
# Run locally what the `gates` job of .github/workflows/ci.yml runs, in its
# order, under its exit-code doctrine.
#
# WHY IT EXISTS
#   The gates job runs TWO runners. `scripts/gates/run-all.sh` walks the gates;
#   `scripts/run-batteries.sh` walks every `*.selftest.sh` in the tree. Nothing
#   local ran both, and docs/gate-requirements.md said "run everything locally
#   with run-all.sh" - which is one of the two.
#
#   On 2026-09-02 that produced exactly the failure it predicts: a pull request
#   body claiming "full suite: 34 run, 34 green" while CI went red in the same
#   job, on a battery, over eighteen cases the gates runner never touches.
#   Thirty-four was the count of one runner. There was no local command that
#   would have disagreed, so the claim was not careless - it was unverifiable.
#
#   This file is that command. `gate-verify-mirror.sh` compares it against the
#   workflow in both directions, so it cannot quietly stop being a mirror.
#
# Exit codes, same doctrine as every gate in this repository:
#   0 = everything measured and green
#   1 = something measured and failed
#   2 = something could not be measured (outranks 1; never a pass)
#
# Usage:
#   scripts/verify.sh          # run the steps
#   scripts/verify.sh --list   # print the commands, run nothing

set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# The commands, verbatim as the workflow spells them. `gate-verify-mirror.sh`
# reads this list out of `--list` and the workflow's `run:` steps out of the
# YAML, then compares the two SETS - a step here that CI does not run is as much
# a defect as a step CI runs that is missing here. Keep the strings identical to
# the workflow's, including quoting: the comparison is textual on purpose,
# because a paraphrase is how a mirror stops being one.
STEPS=(
  "./scripts/gates/run-all.sh --list"
  "./scripts/gates/run-all.sh --skip 'gate-actions-lint.sh'"
  "./scripts/run-batteries.sh"
)

if [ "${1:-}" = "--list" ]; then
  printf '%s\n' "${STEPS[@]}"
  exit 0
fi
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,29p' "${BASH_SOURCE[0]}"
  exit 0
fi
if [ $# -gt 0 ]; then
  printf 'verify.sh: unknown argument: %s\n' "$1" >&2
  exit 2
fi

cd "$ROOT" || exit 2

worst=0
declare -a results=()

for step in "${STEPS[@]}"; do
  printf '\n=== %s\n' "$step"
  # The strings are this file's own literals, not input.
  eval "$step"
  rc=$?
  results+=("$rc|$step")
  # 2 outranks 1 outranks 0: a step that could not measure must not be buried
  # under a step that failed, and neither may be buried under a green one.
  if [ "$rc" -eq 2 ]; then worst=2
  elif [ "$rc" -eq 1 ] && [ "$worst" -ne 2 ]; then worst=1
  elif [ "$rc" -gt 2 ]; then worst=2; fi
done

printf '\n=====================================================================\n'
for r in "${results[@]}"; do
  rc="${r%%|*}"; step="${r#*|}"
  case "$rc" in
    0) label="green" ;;
    1) label="FAILED" ;;
    2) label="COULD NOT MEASURE" ;;
    *) label="rc=$rc, read as COULD NOT MEASURE" ;;
  esac
  printf '  %-19s %s\n' "$label" "$step"
done

case "$worst" in
  0) printf '\nVERDICT   : 0 - every step in the CI gates job ran here and was green.\n' ;;
  1) printf '\nVERDICT   : 1 - a step measured a failure. CI will report the same.\n' ;;
  *) printf '\nVERDICT   : 2 - a step could not be measured. This is not a pass.\n' ;;
esac
exit "$worst"
