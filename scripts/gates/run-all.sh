#!/usr/bin/env bash
# scripts/gates/run-all.sh
#
# Runs the repo gates and aggregates their results respecting the doctrine:
#
#   0 = every gate measured and none failed
#   1 = at least one gate MEASURED and FAILED
#   2 = no measured failure, but at least one gate COULD NOT MEASURE
#
# A gate that could not measure does NOT count as a pass: it is reported
# separately and the run does not return 0. Any code other than 0/1/2 is treated
# as 2 (a gate that does not honour the contract cannot offer guarantees).
#
# ---------------------------------------------------------------------------
# THREE INVARIANTS THAT ARE NOT COSMETIC (each one plugs a MEASURED false green)
#
# 1. RECURSIVE DISCOVERY, NOT FILTERED BY EXTENSION.
#    A discoverer that only looks at 'gate-*.sh' one level deep makes invisible
#    any gate written in Python or node, and any gate placed in a subdirectory.
#    Measured during adversarial verification: a .py gate that FAILS next to a
#    green .sh gave rc=0, and a gate in scripts/gates/supply-chain/ gave rc=0.
#    Here everything that looks executable is discovered, and whatever cannot be
#    launched is declared UNMEASURABLE, never ignored.
#
# 2. ACCOUNTING discovered == (run + declared out of context).
#    It is the net that catches any future way for the loop to be cut short. The
#    list travels over FD 3 and every gate is launched with </dev/null: with the
#    list on stdin, the first gate that reads stdin (cat, read, jq without a
#    file, xargs) swallows the rest and the loop ends early, declaring green what
#    it never ran.
#
# 3. NO GATE IS SKIPPED SILENTLY. Gates that need PR context are declared one by
#    one in PR_SCOPED. A new gate that is neither in that list nor runnable in
#    any context makes run-all return 2: you cannot add a gate and have nobody
#    run it without finding out.
# ---------------------------------------------------------------------------
#
# Usage:
#   scripts/gates/run-all.sh                       # gates with no PR context
#   scripts/gates/run-all.sh --pr-context          # plus the ones that require a PR
#   scripts/gates/run-all.sh --only 'gate-actions-lint.sh'
#   scripts/gates/run-all.sh --skip 'gate-actions-lint.sh'
#   scripts/gates/run-all.sh --list
#
# --only/--skip take glob patterns (matched against the file name) and can be
# repeated. If GITHUB_STEP_SUMMARY is defined, a Markdown summary is written.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

# ---------------------------------------------------------------------------
# Gates that can ONLY measure with a pull request in front of them (they need
# the PR body or the diff against the base branch). Outside that context they
# would return 2 forever and leave the `push` CI permanently red, which is the
# fastest route to somebody switching the whole CI off.
#
# This is not an exemption list: these gates DO run, in their own workflow
# (.github/workflows/issue-closure-gate.yml) and right here with --pr-context.
# What the list prevents is a `push` to main declaring them UNMEASURABLE.
# ---------------------------------------------------------------------------
PR_SCOPED='gate-issue-closure.sh gate-protected-paths.sh'

# Files that live in scripts/gates/ and are NOT gates: they are the self-test of
# a gate (the gate checking itself). They run separately, with --selftests.
SELFTEST_PATTERN='*.selftest.sh'

ONLY=""
SKIP=""
LIST_ONLY=0
PR_CONTEXT=0
SELFTESTS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY="${ONLY}${2:-}"$'\n'; shift 2 ;;
    --skip) SKIP="${SKIP}${2:-}"$'\n'; shift 2 ;;
    --list) LIST_ONLY=1; shift ;;
    --pr-context) PR_CONTEXT=1; shift ;;
    --selftests) SELFTESTS=1; shift ;;
    -h|--help) sed -n '2,47p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

matches_any() { # matches_any <name> <newline-separated-list>
  local name="$1" list="$2" pat
  [ -n "$list" ] || return 1
  while IFS= read -r pat <&4; do
    [ -n "$pat" ] || continue
    # shellcheck disable=SC2254
    case "$name" in $pat) return 0 ;; esac
  done 4<<EOF
$list
EOF
  return 1
}

in_list() { # in_list <name> <space-separated-list>
  local name="$1" item
  for item in $2; do
    [ "$name" = "$item" ] && return 0
  done
  return 1
}

GATES_DIR="$SELF_DIR"
if [ ! -d "$GATES_DIR" ]; then
  gate_warn "$GATES_DIR does not exist: there is nothing to measure"
  exit "$GATE_UNMEASURABLE"
fi

TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t runall)" || {
  gate_warn "I could not create a temporary directory"; exit "$GATE_UNMEASURABLE"; }
trap 'rm -rf "$TMPD"' EXIT
RESULTS="$TMPD/results"
LIST="$TMPD/list"
: > "$RESULTS"

# ---------------------------------------------------------------------------
# DISCOVERY. Recursive, not filtered by extension. Only the paths that are
# declaredly non-executable are excluded (documentation, data, fixtures and the
# shared library), and it is done so that a new file of an unknown type does NOT
# slip by unnoticed: it lands in the list and, if it cannot be launched, the
# verdict is 2.
# ---------------------------------------------------------------------------
find "$GATES_DIR" -type f \
  ! -name '.*' ! -name '*.md' ! -name '*.txt' \
  ! -name '*.json' ! -name '*.yml' ! -name '*.yaml' ! -name '*.awk' \
  ! -name 'run-all.sh' \
  ! -path "$GATES_DIR/lib/*" ! -path "$GATES_DIR/fixtures/*" \
  | LC_ALL=C sort > "$LIST"

n_found=0; n_total=0; n_ok=0; n_fail=0; n_unmeas=0; n_deferred=0; n_run=0
DEFERRED=""

while IFS= read -r g <&3; do
  [ -n "$g" ] || continue
  name="$(basename "$g")"
  n_found=$((n_found + 1))

  # Self-tests: they are not gates. Only with --selftests.
  # shellcheck disable=SC2254
  case "$name" in
    $SELFTEST_PATTERN)
      if [ "$SELFTESTS" -eq 0 ]; then
        n_deferred=$((n_deferred + 1))
        DEFERRED="$DEFERRED $name(self-test)"
        continue
      fi
      ;;
  esac

  if [ -n "$ONLY" ] && ! matches_any "$name" "$ONLY"; then
    n_deferred=$((n_deferred + 1)); DEFERRED="$DEFERRED $name(--only)"; continue
  fi
  if matches_any "$name" "$SKIP"; then
    n_deferred=$((n_deferred + 1)); DEFERRED="$DEFERRED $name(--skip)"
    gate_info "skipped by --skip: $name"
    continue
  fi

  # Gates that require PR context.
  if in_list "$name" "$PR_SCOPED" && [ "$PR_CONTEXT" -eq 0 ]; then
    n_deferred=$((n_deferred + 1))
    DEFERRED="$DEFERRED $name(needs-PR)"
    gate_info "$name needs PR context: it does not run here, issue-closure-gate.yml runs it"
    continue
  fi

  n_total=$((n_total + 1))
  if [ "$LIST_ONLY" -eq 1 ]; then printf '%s\n' "$name"; n_run=$((n_run + 1)); continue; fi

  # Can it be launched? A file that looks like a gate and cannot be executed is
  # UNMEASURABLE, never a pass by omission.
  case "$name" in
    *.sh) : ;;
    *)
      if [ ! -x "$g" ]; then
        gate_warn "$name is neither *.sh nor has the execute bit: I do not know how to launch it"
        printf '2|%s|I do not know how to run it\n' "$name" >> "$RESULTS"
        n_unmeas=$((n_unmeas + 1)); n_run=$((n_run + 1))
        continue
      fi
      ;;
  esac

  rc=0
  case "$name" in
    *.sh) bash "$g" </dev/null || rc=$? ;;
    *)    "$g" </dev/null || rc=$? ;;
  esac
  n_run=$((n_run + 1))
  case "$rc" in
    0) n_ok=$((n_ok + 1));      printf '0|%s|measured, no findings\n' "$name" >> "$RESULTS" ;;
    1) n_fail=$((n_fail + 1));  printf '1|%s|measured, FAILS\n' "$name" >> "$RESULTS" ;;
    2) n_unmeas=$((n_unmeas + 1)); printf '2|%s|COULD NOT MEASURE\n' "$name" >> "$RESULTS" ;;
    *) n_unmeas=$((n_unmeas + 1)); printf '2|%s|unexpected code %s, treated as COULD NOT MEASURE\n' "$name" "$rc" >> "$RESULTS" ;;
  esac
done 3< "$LIST"

if [ "$n_found" -eq 0 ]; then
  gate_warn "no gate was discovered in $GATES_DIR. Zero gates = zero verification."
  gate_verdict 2
  exit "$GATE_UNMEASURABLE"
fi

[ "$LIST_ONLY" -eq 1 ] && exit 0

if [ "$n_total" -eq 0 ]; then
  gate_warn "no gate was run (are the --only/--skip filters too strict?)"
  gate_verdict 2
  exit "$GATE_UNMEASURABLE"
fi

# ACCOUNTING. If the loop were cut short, this catches it: the gates run have to
# be exactly the ones selected.
if [ "$n_run" -ne "$n_total" ]; then
  gate_warn "I selected $n_total gates but only ran $n_run: the loop was cut short"
  gate_verdict 2
  exit "$GATE_UNMEASURABLE"
fi

FINAL=0
[ "$n_unmeas" -gt 0 ] && FINAL=2
[ "$n_fail" -gt 0 ] && FINAL=1

printf '\n===== GATE SUMMARY =====\n'
printf 'discovered: %d | run: %d | green: %d | FAIL: %d | UNMEASURABLE: %d\n' \
  "$n_found" "$n_total" "$n_ok" "$n_fail" "$n_unmeas"
while IFS='|' read -r rc name msg; do
  case "$rc" in
    0) gate_ok   "$name — $msg" ;;
    1) gate_fail "$name — $msg" ;;
    *) gate_warn "$name — $msg" ;;
  esac
done < "$RESULTS"

if [ "$n_deferred" -gt 0 ]; then
  printf '\nNOT RUN HERE (declared, not silenced):%s\n' "$DEFERRED"
fi
if [ "$n_unmeas" -gt 0 ]; then
  printf '\nAn UNMEASURABLE gate is not a green gate: it means that check was never\n'
  printf 'performed. It is reported separately and the run does NOT return 0.\n'
fi

# Summary for the GitHub Actions tab, when running in CI.
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    printf '## Gates\n\n'
    printf '| Result | Gate | Detail |\n|---|---|---|\n'
    while IFS='|' read -r rc name msg; do
      case "$rc" in
        0) printf '| OK 0 measured | `%s` | %s |\n' "$name" "$msg" ;;
        1) printf '| FAIL 1 measured | `%s` | %s |\n' "$name" "$msg" ;;
        *) printf '| UNMEASURABLE 2 | `%s` | %s |\n' "$name" "$msg" ;;
      esac
    done < "$RESULTS"
    printf '\n**discovered %d · run %d · green %d · fail %d · unmeasurable %d**\n' \
      "$n_found" "$n_total" "$n_ok" "$n_fail" "$n_unmeas"
    if [ "$n_deferred" -gt 0 ]; then
      printf '\nNot run here (declared):%s\n' "$DEFERRED"
    fi
    printf '\n> An UNMEASURABLE gate is not approved: that check never happened.\n'
  } >> "$GITHUB_STEP_SUMMARY"
fi

gate_verdict "$FINAL"
exit "$FINAL"
