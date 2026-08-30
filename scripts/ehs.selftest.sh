#!/usr/bin/env bash
# scripts/ehs.selftest.sh — Self-test for scripts/ehs CLI tool.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EHS="$HERE/ehs"

pass=0
fail=0

check() {
  local name="$1" cmd="$2" want_rc="$3" needle="$4"
  local out rc=0
  out=$(eval "$cmd" 2>&1) || rc=$?
  local ok=0

  if [ "$rc" -ne "$want_rc" ]; then
    ok=1
  fi
  if [ -n "$needle" ] && ! echo "$out" | grep -q "$needle"; then
    ok=1
  fi

  if [ "$ok" -eq 0 ]; then
    printf 'ok       %-38s rc=%s\n' "$name" "$rc"
    pass=$((pass + 1))
  else
    printf 'FAILED   %-38s rc=%s (wanted rc=%s, needle=%s)\n' "$name" "$rc" "$want_rc" "$needle"
    printf '%s\n' "$out" | sed 's/^/         /' | head -n 5
    fail=$((fail + 1))
  fi
}

echo "=== self-test: scripts/ehs CLI ==="

check "stats-command-reports-total" "$EHS stats" 0 "TOTAL"
check "list-command-returns-0" "$EHS list" 0 "WEB-01"
check "list-filter-by-pack" "$EHS list ai-safety" 0 "AI-01"
check "show-valid-procedure" "$EHS show AI-08" 0 "Where to look"
check "show-invalid-procedure" "$EHS show FAKE-99" 1 "not found"
check "search-finds-mcp" "$EHS search mcp" 0 "AI-08"
check "search-empty-returns-0" "$EHS search xyznonexistentquery123" 0 "No procedures found"

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. scripts/ehs CLI passes all tests."
exit 0
