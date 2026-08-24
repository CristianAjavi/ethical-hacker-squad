#!/usr/bin/env bash
# scripts/gates/gate-promotion-safepath.sh
#
# The check that closes issue #15: the promotion invariant needs a check, not
# only a mitigation.
#
# WHY IT EXISTS
#   The release `verify` job runs MAIN's gates with the CANDIDATE tree as the
#   working directory. `python3 -c`, a heredoc on stdin and `python3 -` all put
#   the working directory first on `sys.path`, so a `yaml.py` or `json.py` in
#   the candidate would be imported by the gates judging it - and the sentence
#   the promotion model rests on, WHO JUDGES IS ALWAYS MAIN, would no longer be
#   true. `PYTHONSAFEPATH: '1'` is the mitigation. A mitigation nothing watches
#   is a comment: this gate fails if it is removed, or if a future step
#   reintroduces the shape somewhere else.
#
# WHAT IT MEASURES, over .github/workflows/*.yml
#   Every step whose `run:` invokes python while its effective working directory
#   is not the workspace root - a step `working-directory:`, a job-level
#   `defaults: run: working-directory:`, or a `cd` inside the same `run:` block.
#   Each of those must have PYTHONSAFEPATH in scope at the step, the job or the
#   workflow `env:`.
#
# Exit codes: 0 = measured and fine | 1 = measured and fails | 2 = could not measure.
#
# Usage:
#   scripts/gates/gate-promotion-safepath.sh              # audits the repo
#   scripts/gates/gate-promotion-safepath.sh --dir DIR    # audits another directory
#   scripts/gates/gate-promotion-safepath.sh --self-test  # only the self-test
#
# Environment variables:
#   GATE_SELFTEST=0   skips the self-test over the fixtures; the verdict is then
#                     capped at 2, because a gate that has not measured itself
#                     cannot sign a green.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

AWK_PROG="$SELF_DIR/lib/promotion-safepath.awk"
FIXTURES="$SELF_DIR/fixtures/safepath"
ROOT="$(gate_root)"
TARGET_DIR="$ROOT/.github/workflows"
ONLY_SELFTEST=0
SELFTEST_SKIPPED=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) TARGET_DIR="${2:-}"; shift 2 ;;
    --self-test) ONLY_SELFTEST=1; shift ;;
    -h|--help) sed -n '2,34p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

TMPDIR_GATE="$(mktemp -d 2>/dev/null || mktemp -d -t gatesafepath)"
trap 'rm -rf "$TMPDIR_GATE"' EXIT

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
# SELF-TEST: the gate measures itself before measuring the repo. Each negative
# fixture declares `# gate-expect: <rule>` in its header.
# ---------------------------------------------------------------------------
self_test() {
  local ok=1 f out expect rule_found

  if [ ! -d "$FIXTURES" ]; then
    gate_warn "self-test: I cannot find the fixtures in $FIXTURES"
    return "$GATE_UNMEASURABLE"
  fi

  out="$TMPDIR_GATE/selftest.out"

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
  gate_header "promotion-safepath (who judges is always main)"
  gate_scope   "every workflow step that runs python outside the workspace root - step \`working-directory:\`, job \`defaults.run.working-directory:\`, or a \`cd\` in the same \`run:\` - must have PYTHONSAFEPATH in scope at the step, the job or the workflow"
  gate_out_of_scope "python reached indirectly (make, npm, a shell script, an action's own code), PYTHONPATH manipulation, and \`sys.path\` edits inside a script - none of those are visible to a lexical scan of the workflow"

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
    gate_ok "every two-tree job and every python step outside the workspace root declares PYTHONSAFEPATH"
  else
    print_findings "$out" FAIL   "  FAIL        "
    print_findings "$out" UNMEAS "  UNMEASURABLE"
  fi

  gate_verdict "$rc"
  return "$rc"
}

main
exit $?
