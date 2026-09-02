#!/usr/bin/env bash
# Proof that a self-test run from OUTSIDE the repository stops instead of copying
# whatever tree it happens to land next to.
#
# The incident, 2026-09-01: gate-protected-paths.selftest.sh was copied out of the
# repository to mutate one case. `git rev-parse` failed in the scratch directory,
# the blind fallback resolved two levels up to a temp tree holding another
# session's node_modules, and every one of 33 cases tarred a fresh copy of it. A
# 228 GB disk went to 100% full and the machine stopped being able to run
# anything. Measured afterwards: 18 of the 23 batteries carried that fallback.
#
# It also lied about what it was. With no gate to run, the battery printed
# `FAILED control-untouched-repo rc=127 (wanted 0)` and returned 1 - a CASE
# verdict for a harness that never measured anything. So this battery asserts
# THREE things per case, not one: the exit code is 2, the reason names the root,
# and NOTHING was created inside the impostor tree.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/selftest-root.sh" 2>/dev/null || {
  echo "UNMEASURABLE the root guard is missing at $HERE/lib/selftest-root.sh"; exit 2; }
SRC="$(ehs_selftest_root --here "$HERE")" || exit 2

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-stroot-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

ok()   { pass=$((pass+1)); printf 'ok       %-52s %s\n' "$1" "$2"; }
bad()  { fail=$((fail+1)); printf 'FAILED   %-52s %s\n' "$1" "$2"; }
unm()  { echo "UNMEASURABLE $1"; exit 2; }

# An impostor: a small tree that is NOT this repository and must never be copied.
# It is deliberately tiny. Reproducing the incident at full size would refill the
# disk; what has to be reproduced is the RESOLUTION, not the volume.
make_impostor() {  # <dir>
  local d="$1"
  mkdir -p "$d/scripts/gates/lib"
  echo "I am not the repository. Copying me is the bug." > "$d/DO-NOT-COPY.txt"
  # A self-test sits two levels down, so $HERE/../.. lands on $d.
  printf '%s\n' "$d"
}

# git must NOT resolve inside the impostor, or the case would pass for the wrong
# reason: the guard would never reach the fallback it exists to catch.
assert_git_blind() {  # <dir>
  if git -C "$1/scripts/gates" rev-parse --show-toplevel >/dev/null 2>&1; then
    unm "the impostor at $1 sits inside a git repository, so the fallback under
              test is never reached. Set TMPDIR outside any checkout."
  fi
}

# entries created inside the impostor, excluding what make_impostor put there
strays() {  # <dir>
  find "$1" -mindepth 1 \
    ! -path "$1/DO-NOT-COPY.txt" \
    ! -path "$1/scripts" ! -path "$1/scripts/gates" ! -path "$1/scripts/gates/lib" \
    ! -path "$1/scripts/gates/*.selftest.sh" ! -path "$1/scripts/gates/lib/selftest-root.sh" \
    2>/dev/null | wc -l | tr -d ' '
}

# A battery may stop for a reason of its OWN before the shared guard is reached -
# gate-agent-tools checks its gate is executable first, and that check also fires
# on a loose copy. That is a correct refusal, so it counts as a pass, but it is
# counted SEPARATELY and capped: what must never grow is the number of batteries
# whose loose run is stopped by something other than the guard this file exists
# to measure. What is never accepted from anybody is a silent stop: rc 2 with no
# could-not-measure wording is a failure whichever guard produced it.
own_guard=0; own_guard_names=""
run_loose() {  # <battery> <with-helper: yes|no> <needle>
  local bat="$1" helper="$2" needle="$3"
  local label="${bat%.selftest.sh}/${helper}-helper"
  local d="$TMP/$(echo "$label" | tr '/' '_')"
  make_impostor "$d" >/dev/null
  assert_git_blind "$d"
  cp "$SRC/scripts/gates/$bat" "$d/scripts/gates/"
  [ "$helper" = yes ] && cp "$SRC/scripts/gates/lib/selftest-root.sh" "$d/scripts/gates/lib/"

  local out rc=0
  out="$(cd "$d/scripts/gates" && env -u EHS_REPO_ROOT bash "./$bat" 2>&1)" || rc=$?

  local n; n="$(strays "$d")"
  if [ "$rc" -ne 2 ]; then
    bad "$label" "rc=$rc (wanted 2) — a run that could not measure looked like one that did"
    printf '         %s\n' "$(printf '%s' "$out" | head -2)"
  elif ! printf '%s' "$out" | grep -qE 'UNMEASURABLE|COULD NOT MEASURE'; then
    bad "$label" "rc=2 but never says it could not measure"
    printf '         %s\n' "$(printf '%s' "$out" | head -2)"
  elif [ "$n" -ne 0 ]; then
    bad "$label" "stopped at rc=2 but created $n entries inside the impostor"
  elif ! printf '%s' "$out" | grep -q "$needle"; then
    own_guard=$((own_guard+1)); own_guard_names="$own_guard_names ${bat%.selftest.sh}"
    ok "$label" "rc=2, nothing copied (stopped by its own guard first)"
  else
    ok "$label" "rc=2, nothing copied"
  fi
}

# --- the mutant: without the guard, does the impostor actually get copied? -----
# A battery that has never been red proves nothing. This restores the exact blind
# fallback the 18 files carried and asserts the loose run does NOT stop.
mutant_blind_fallback() {
  local d="$TMP/mutant"
  make_impostor "$d" >/dev/null
  assert_git_blind "$d"
  sed -e 's|^\. "\$HERE/lib/selftest-root.sh".*|SRC="$(cd "$HERE/../.." \&\& pwd)"|' \
      -e 's|^  echo "UNMEASURABLE the root guard is missing.*||' \
      -e 's|^SRC="\$(ehs_selftest_root .*|:|' \
      "$SRC/scripts/gates/gate-secret-scan.selftest.sh" > "$d/scripts/gates/m.selftest.sh"
  grep -q 'ehs_selftest_root' "$d/scripts/gates/m.selftest.sh" && \
    unm "the mutation did not remove the guard; the negative control is void"
  local rc=0
  ( cd "$d/scripts/gates" && env -u EHS_REPO_ROOT bash ./m.selftest.sh ) >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq 2 ]; then
    bad "mutant-without-the-guard" "still rc=2 — the guard is not what stops it"
  else
    ok "mutant-without-the-guard" "rc=$rc, so the guard is load-bearing"
  fi
}

echo "=== self-test: lib/selftest-root.sh (source: $SRC) ==="

# Positive control first: inside the repository the guard resolves and says yes.
r="$(ehs_selftest_root --here "$SRC/scripts/gates")" && [ "$r" = "$SRC" ] \
  && ok "control-inside-the-repository" "resolves to $SRC" \
  || bad "control-inside-the-repository" "got '${r:-}' wanted '$SRC'"

# Every battery that sources the guard, run loose. Discovered, never listed: a
# hardcoded list is a literal tracking a file set that changes on its own, and
# this repository has been bitten by exactly that before.
n_bat=0
for f in "$SRC"/scripts/gates/*.selftest.sh; do
  b="$(basename "$f")"
  grep -q 'ehs_selftest_root' "$f" || continue
  n_bat=$((n_bat+1))
  run_loose "$b" no  "root guard is missing"
  run_loose "$b" yes "does not look like this repository"
done
[ "$n_bat" -ge 18 ] || unm "only $n_bat batteries source the guard; 19 were wired
              (18 that had the blind fallback, plus this one). A battery that
              silently stopped sourcing it would not be caught by its own cases."

mutant_blind_fallback

# The cap. One battery (gate-agent-tools) refuses on its own check before the
# shared guard is reached, in both loose cases. More than that means batteries are
# stopping for reasons this file is not measuring, and the coverage it claims
# would be smaller than it looks.
if [ "$own_guard" -gt 2 ]; then
  bad "own-guard-cap" "$own_guard loose runs stopped before the shared guard (max 2):$own_guard_names"
fi

echo
echo "Summary: $pass ok, $fail failures ($n_bat batteries checked loose)"
if [ "$fail" -eq 0 ]; then
  echo "Result: OK. Every battery run from outside the repository stops at could-not-"
  echo "        measure, names the tree it refused, and copies nothing. Removing the"
  echo "        guard makes one of them proceed, which is what makes this measurable."
  exit 0
fi
exit 1
