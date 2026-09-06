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
# Gates whose input comes from OUTSIDE this checkout: they need a tool run that
# needs the network and a repository token. They do not run here, and they are
# named in the deferred list with the workflow that does run them - a gate that
# is quietly absent is indistinguishable from a gate that passed.
EXTERNAL_SCOPED='gate-scorecard-threshold.sh'
# Gates that measure the LIVE repository through the GitHub API rather than this
# checkout. Reading branch protection needs the `administration` scope, and the
# GITHUB_TOKEN a workflow receives cannot be granted it - that permission does
# not exist for workflow tokens. Run here they would report 2 forever, which is
# the fastest route to somebody switching the suite off, so they are deferred BY
# NAME with the reason, the same treatment the PR-scoped gates get. They do run:
# locally, against an authenticated gh. Putting them in CI needs a fine-grained
# PAT with Administration:read, and that is the owner's decision, written down
# here rather than left as a silent hole.
LIVE_SCOPED='gate-governance-drift.sh'

# Files that live in scripts/gates/ and are NOT gates: they are the self-test of
# a gate (the gate checking itself). They run separately, with --selftests.
SELFTEST_PATTERN='*.selftest.sh'

# ---------------------------------------------------------------------------
# WHAT EACH GATE COSTS.
# A verdict without a cost cannot tell a suite that got slower from one that did
# not. `gate-mutant-bank.sh` arrived and took the local suite from about 27 s to
# 157.8 s - 83% of the whole run - and nothing here said so, because this runner
# had never reported a cost. It does now, and it declares its own resolution
# rather than inventing one: EPOCHREALTIME is a bash 5 variable, macOS ships bash
# 3.2, and there the best clock available is the SECONDS builtin, which counts
# whole seconds. A gate that finished inside one of those seconds prints `<1s`.
# It does NOT print 0.0s - that would be this runner claiming a precision it did
# not have, which is the exact failure it exists to catch in the gates it runs.
if [ -n "${EPOCHREALTIME:-}" ]; then CLOCK=ms; else CLOCK=s; fi
T_TOTAL=0

now_ms() {
  if [ "$CLOCK" = ms ]; then
    local t="${EPOCHREALTIME}"
    t="${t//[!0-9]/}"
    printf '%s' "${t:0:13}"
  else
    printf '%s000' "$SECONDS"
  fi
}

# Milliseconds to something a person reads. Under the fallback clock anything
# that measured zero is reported as under a second, never as zero.
fmt_ms() {
  if [ "$1" -eq 0 ] && [ "$CLOCK" = s ]; then printf '<1s'; return; fi
  printf '%d.%ds' "$(( $1 / 1000 ))" "$(( ($1 % 1000) / 100 ))"
}

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

  # Gates that read the live repository through the API.
  if in_list "$name" "$LIVE_SCOPED" && [ -z "${EHS_LIVE_REPO:-}" ]; then
    n_deferred=$((n_deferred + 1))
    DEFERRED="$DEFERRED $name(needs-live-repo)"
    gate_info "$name reads the live repository, not this checkout: set EHS_LIVE_REPO=1 with an authenticated gh to run it"
    continue
  fi

  # Gates whose input is produced by a tool run outside this checkout.
  if in_list "$name" "$EXTERNAL_SCOPED" && [ -z "${SCORECARD_RESULTS:-}" ]; then
    n_deferred=$((n_deferred + 1))
    DEFERRED="$DEFERRED $name(needs-external-results)"
    gate_info "$name needs results this checkout does not contain: it does not run here, scorecard.yml runs it"
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
        printf '2|%s|0|I do not know how to run it\n' "$name" >> "$RESULTS"
        n_unmeas=$((n_unmeas + 1)); n_run=$((n_run + 1))
        continue
      fi
      ;;
  esac

  rc=0
  t_ini=$(now_ms)
  case "$name" in
    *.sh) bash "$g" </dev/null || rc=$? ;;
    *)    "$g" </dev/null || rc=$? ;;
  esac
  t_ms=$(( $(now_ms) - t_ini ))
  [ "$t_ms" -lt 0 ] && t_ms=0
  T_TOTAL=$((T_TOTAL + t_ms))
  n_run=$((n_run + 1))
  case "$rc" in
    0) n_ok=$((n_ok + 1));      printf '0|%s|%s|measured, no findings\n' "$name" "$t_ms" >> "$RESULTS" ;;
    1) n_fail=$((n_fail + 1));  printf '1|%s|%s|measured, FAILS\n' "$name" "$t_ms" >> "$RESULTS" ;;
    2) n_unmeas=$((n_unmeas + 1)); printf '2|%s|%s|COULD NOT MEASURE\n' "$name" "$t_ms" >> "$RESULTS" ;;
    *) n_unmeas=$((n_unmeas + 1)); printf '2|%s|%s|unexpected code %s, treated as COULD NOT MEASURE\n' "$name" "$t_ms" "$rc" >> "$RESULTS" ;;
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
while IFS='|' read -r rc name ms msg; do
  case "$rc" in
    0) gate_ok   "$name — $msg ($(fmt_ms "$ms"))" ;;
    1) gate_fail "$name — $msg ($(fmt_ms "$ms"))" ;;
    *) gate_warn "$name — $msg ($(fmt_ms "$ms"))" ;;
  esac
done < "$RESULTS"

# WHERE THE TIME WENT. Only the gates worth acting on: a list of 35 costs is a
# table nobody reads, and the question this answers is which gate to look at.
# The threshold is a tenth of the run, so a suite with no dominant gate prints
# the total and stops rather than manufacturing a culprit out of the largest of
# thirty-five equals.
# A total of zero is not a reason to say nothing. Under the one-second clock a
# whole fast suite measures zero, and that is exactly when an instrument
# guarded by a threshold goes quiet on the runs a person reads most. `<1s`
# already exists to report a small number honestly; use it.
if [ "$n_run" -gt 0 ]; then
  printf '\ncost: %s across %d gate(s)' "$(fmt_ms "$T_TOTAL")" "$n_run"
  DOM=""
  while IFS='|' read -r rc name ms msg; do
    [ "${ms:-0}" -gt 0 ] || continue
    [ "$T_TOTAL" -gt 0 ] || continue
    if [ $(( ms * 10 )) -ge "$T_TOTAL" ]; then
      DOM="$DOM
  $(printf '%6s  %2d%%  %s' "$(fmt_ms "$ms")" "$(( ms * 100 / T_TOTAL ))" "$name")"
    fi
  done < "$RESULTS"
  if [ -n "$DOM" ]; then
    printf ', and a tenth or more of it is in:%s\n' "$DOM"
  else
    printf ', none of them a tenth of the run on its own\n'
  fi
fi

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
    printf '| Result | Gate | Detail | Cost |\n|---|---|---|---|\n'
    while IFS='|' read -r rc name ms msg; do
      case "$rc" in
        0) printf '| OK 0 measured | `%s` | %s | %s |\n' "$name" "$msg" "$(fmt_ms "$ms")" ;;
        1) printf '| FAIL 1 measured | `%s` | %s | %s |\n' "$name" "$msg" "$(fmt_ms "$ms")" ;;
        *) printf '| UNMEASURABLE 2 | `%s` | %s | %s |\n' "$name" "$msg" "$(fmt_ms "$ms")" ;;
      esac
    done < "$RESULTS"
    printf '\n**discovered %d · run %d · green %d · fail %d · unmeasurable %d · %s**\n' \
      "$n_found" "$n_total" "$n_ok" "$n_fail" "$n_unmeas" "$(fmt_ms "$T_TOTAL")"
    if [ "$n_deferred" -gt 0 ]; then
      printf '\nNot run here (declared):%s\n' "$DEFERRED"
    fi
    printf '\n> An UNMEASURABLE gate is not approved: that check never happened.\n'
  } >> "$GITHUB_STEP_SUMMARY"
fi

gate_verdict "$FINAL"
exit "$FINAL"
