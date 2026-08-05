#!/usr/bin/env bash
# scripts/gates/gate-workflow-hardening.sh
#
# The repo's OWN GitHub Actions hardening gate. It depends on no zizmor, no
# actionlint, no network and no package: only POSIX awk. It is the gate that
# keeps measuring when the rest of the toolchain is unavailable.
#
# It verifies, over .github/workflows/*.yml:
#   1. That no workflow uses `pull_request_target` (nor any trigger outside of:
#      schedule, workflow_dispatch, push, pull_request).
#   2. That the workflow declares `permissions: {}`, that EVERY job declares
#      its own `permissions:` block and that none grants them IN BULK
#      (`write-all`/`read-all`): the rule is "minimum", not "declared".
#   3. That every third-party action is pinned to a 40-character SHA, with a
#      comment that is a recognizable VERSION (`# v7.0.1`), which is what
#      Dependabot needs in order to update the pin.
#   4. That no workflow reachable by third parties (`pull_request`, which also
#      arrives from forks) reads the `secrets` context - in any of its three
#      forms: `secrets.X`, `secrets['X']` and `toJSON(secrets)` - nor uses
#      `secrets: inherit`.
#
# Exit codes: 0 = measured and fine | 1 = measured and fails | 2 = could not measure.
#
# Usage:
#   scripts/gates/gate-workflow-hardening.sh              # audits the repo
#   scripts/gates/gate-workflow-hardening.sh --dir DIR    # audits another directory
#   scripts/gates/gate-workflow-hardening.sh --self-test  # only the self-test
#
# Environment variables:
#   GATE_SELFTEST=0   skips the self-test over the fixtures (not recommended)

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

AWK_PROG="$SELF_DIR/lib/workflow-hardening.awk"
FIXTURES="$SELF_DIR/fixtures/hardening"
ROOT="$(gate_root)"
TARGET_DIR="$ROOT/.github/workflows"
ONLY_SELFTEST=0
SELFTEST_SKIPPED=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) TARGET_DIR="${2:-}"; shift 2 ;;
    --self-test) ONLY_SELFTEST=1; shift ;;
    -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

TMPDIR_GATE="$(mktemp -d 2>/dev/null || mktemp -d -t gatehard)"
trap 'rm -rf "$TMPDIR_GATE"' EXIT

# ---------------------------------------------------------------------------
# scan_dir <dir> <output-file>
#   0 = scanned with no findings | 1 = FAIL findings | 2 = unmeasurable
# ---------------------------------------------------------------------------
scan_dir() {
  local dir="$1" out="$2"
  : > "$out"

  if [ -z "$dir" ] || [ ! -d "$dir" ]; then
    printf 'UNMEAS|%s|0|input|the directory does not exist\n' "$dir" >> "$out"
    return "$GATE_UNMEASURABLE"
  fi

  local list="$TMPDIR_GATE/list.$$"
  find "$dir" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null \
    | LC_ALL=C sort > "$list"

  local n
  n="$(wc -l < "$list" | tr -d ' ')"
  if [ "$n" -eq 0 ]; then
    printf 'UNMEAS|%s|0|input|there are no .yml/.yaml files to audit\n' "$dir" >> "$out"
    return "$GATE_UNMEASURABLE"
  fi

  local f awk_rc=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if ! awk -v FILE="$f" -f "$AWK_PROG" "$f" >> "$out" 2>"$TMPDIR_GATE/awk.err"; then
      awk_rc=1
      printf 'UNMEAS|%s|0|tool|awk could not process the file: %s\n' \
        "$f" "$(tr '\n' ' ' < "$TMPDIR_GATE/awk.err")" >> "$out"
    fi
  done < "$list"

  local nfail nunmeas
  nfail="$(grep -c '^FAIL|' "$out" 2>/dev/null || true)"
  nunmeas="$(grep -c '^UNMEAS|' "$out" 2>/dev/null || true)"
  nfail="${nfail:-0}"; nunmeas="${nunmeas:-0}"

  # A MEASURED failure outranks a "could not measure": it is more actionable
  # and both break the build the same way. The unmeasurables are always
  # printed, never swallowed.
  if [ "$nfail" -gt 0 ]; then return "$GATE_FAIL"; fi
  if [ "$nunmeas" -gt 0 ] || [ "$awk_rc" -ne 0 ]; then return "$GATE_UNMEASURABLE"; fi
  return "$GATE_OK"
}

print_findings() {
  local out="$1" kind="$2" prefix="$3"
  grep "^$kind|" "$out" 2>/dev/null | while IFS='|' read -r _k file line rule msg; do
    printf '%s %s:%s [%s] %s\n' "$prefix" "$file" "$line" "$rule" "$msg"
  done
}

# ---------------------------------------------------------------------------
# SELF-TEST: the gate measures itself before measuring the repo.
# Each fixture declares `# gate-expect: <rule>` in its header (or `none`).
# If the self-test does not add up, the gate cannot assert anything -> rc 2.
# ---------------------------------------------------------------------------
self_test() {
  local ok=1 f out expect rule_found

  if [ ! -d "$FIXTURES" ]; then
    gate_warn "self-test: I cannot find the fixtures in $FIXTURES"
    return "$GATE_UNMEASURABLE"
  fi

  out="$TMPDIR_GATE/selftest.out"

  # --- cases that MUST fail, with the exact rule they must trigger ---
  for f in "$FIXTURES"/bad/*.yml; do
    [ -e "$f" ] || { gate_warn "self-test: there are no negative fixtures"; return "$GATE_UNMEASURABLE"; }
    : > "$out"
    awk -v FILE="$f" -f "$AWK_PROG" "$f" > "$out" 2>/dev/null
    expect="$(sed -n 's/^#[ ]*gate-expect:[ ]*//p' "$f" | head -1)"
    if [ -z "$expect" ]; then
      gate_warn "self-test: fixture $(basename "$f") does not declare '# gate-expect:'"
      ok=0
      continue
    fi
    rule_found="$(grep -c "^FAIL|[^|]*|[0-9]*|$expect|" "$out" 2>/dev/null || true)"
    if [ "${rule_found:-0}" -lt 1 ]; then
      gate_warn "NEGATIVE self-test failed: $(basename "$f") should trigger '$expect' and it did not"
      ok=0
    fi
  done

  # --- cases that MUST come out clean ---
  for f in "$FIXTURES"/good/*.yml; do
    [ -e "$f" ] || { gate_warn "self-test: there are no positive fixtures"; return "$GATE_UNMEASURABLE"; }
    : > "$out"
    awk -v FILE="$f" -f "$AWK_PROG" "$f" > "$out" 2>/dev/null
    if grep -q '^FAIL|' "$out" || grep -q '^UNMEAS|' "$out"; then
      gate_warn "POSITIVE self-test failed: $(basename "$f") should come out clean:"
      print_findings "$out" FAIL   "        "
      print_findings "$out" UNMEAS "        "
      ok=0
    fi
  done

  # --- cases that MUST come out as UNMEASURABLE (never as a pass) ---
  for f in "$FIXTURES"/unmeasurable/*.yml; do
    [ -e "$f" ] || continue
    : > "$out"
    awk -v FILE="$f" -f "$AWK_PROG" "$f" > "$out" 2>/dev/null
    if ! grep -q '^UNMEAS|' "$out"; then
      gate_warn "self-test failed: $(basename "$f") should come out UNMEASURABLE and it came out silent"
      ok=0
    fi
  done

  [ "$ok" -eq 1 ] && return "$GATE_OK"
  return "$GATE_UNMEASURABLE"
}

# ---------------------------------------------------------------------------
main() {
  gate_header "workflow-hardening (awk, no external dependencies)"
  gate_scope   "allowed triggers; permissions {} at the root and minimum (not in bulk) per job; pin to a 40-char SHA + version comment; reads of the secrets context (forms .X, ['X'] and toJSON) in workflows reachable from forks"
  gate_out_of_scope "template injection in \`run:\`, shellcheck, YAML/cron syntax, impersonated or known-vulnerable actions - gate-actions-lint.sh (zizmor + actionlint) takes care of that"

  if [ ! -f "$AWK_PROG" ]; then
    gate_warn "the scanner $AWK_PROG is missing"
    gate_verdict 2
    return "$GATE_UNMEASURABLE"
  fi
  if ! command -v awk >/dev/null 2>&1; then
    gate_warn "there is no awk in PATH"
    gate_verdict 2
    return "$GATE_UNMEASURABLE"
  fi

  if [ "${GATE_SELFTEST:-1}" != "0" ]; then
    self_test
    local st=$?
    if [ "$st" -ne 0 ]; then
      gate_warn "the gate does NOT pass its own self-test; any result over the repo would be indefensible"
      gate_verdict 2
      return "$GATE_UNMEASURABLE"
    fi
    gate_info "self-test passed (negative, positive and unmeasurable fixtures in $FIXTURES)"
  else
    # Skipping the self-test can never produce a green: if the gate has not
    # measured itself, its "all correct" is not defensible. The shortcut is
    # allowed for debugging, but the verdict is capped at 2.
    gate_warn "self-test SKIPPED via GATE_SELFTEST=0: the verdict cannot be 0"
    SELFTEST_SKIPPED=1
  fi

  if [ "$ONLY_SELFTEST" -eq 1 ]; then
    if [ "$SELFTEST_SKIPPED" -eq 1 ]; then
      gate_warn "--self-test with GATE_SELFTEST=0: no test was run"
      gate_verdict 2
      return "$GATE_UNMEASURABLE"
    fi
    gate_ok "self-test passed; the repo was not audited (--self-test)"
    gate_verdict 0
    return "$GATE_OK"
  fi

  local out="$TMPDIR_GATE/repo.out" rc
  scan_dir "$TARGET_DIR" "$out"; rc=$?

  local nf
  nf="$(find "$TARGET_DIR" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | wc -l | tr -d ' ')"
  gate_info "audited directory: ${TARGET_DIR#"$ROOT"/} (${nf:-0} file(s))"
  awk -F'|' '$1=="STAT"{s[$2]+=$3} END{for (k in s) printf "· total %s: %d\n", k, s[k]}' "$out" | LC_ALL=C sort

  if [ "$rc" -eq 0 ] && [ "$SELFTEST_SKIPPED" -eq 1 ]; then
    gate_warn "the ${nf} workflow(s) triggered no findings, but the self-test was skipped: I cannot sign this result"
    rc="$GATE_UNMEASURABLE"
  fi

  if [ "$rc" -eq 0 ]; then
    gate_ok "the ${nf} workflow(s) satisfy the hard rules"
  else
    print_findings "$out" FAIL   "  FAIL        "
    print_findings "$out" UNMEAS "  UNMEASURABLE"
  fi

  gate_verdict "$rc"
  return "$rc"
}

main
exit $?
