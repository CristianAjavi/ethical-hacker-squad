#!/usr/bin/env bash
# Self-test for gate-actions-lint.sh, which had none — and that absence is how
# its stray-workflow check shipped as a false green: it printed FAIL, bumped a
# variable nothing read, and the gate exited 0. A blinded audit of this
# repository found it; this battery is what stops it coming back.
#
# The linters themselves are not exercised here (they need a bootstrap and a
# network fetch). What is exercised is the part that needs no tool: the check
# that no workflow lives outside the audited directory, and the exit codes.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-actions-lint.sh"
if [ -n "${EHS_REPO_ROOT:-}" ]; then SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then :
else SRC="$(cd "$HERE/../.." && pwd)"; fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-actions-lint-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# A tree with the minimum this gate needs: its own workflows directory.
build() {  # build <dir>
  mkdir -p "$1/.github/workflows"
  cat > "$1/.github/workflows/ci.yml" <<'YML'
name: ci
on:
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - run: echo ok
YML
}

check() {  # check <name> <expected substring> <expect-nonzero:yes|no> <dir>
  local name="$1" needle="$2" nonzero="$3" dir="$4" out rc
  out="$(EHS_REPO_ROOT="$dir" bash "$GATE" 2>&1)"; rc=$?
  local ok=0
  printf '%s' "$out" | grep -q -- "$needle" || ok=1
  if [ "$nonzero" = yes ] && [ "$rc" -eq 0 ]; then ok=1; fi
  if [ "$nonzero" = no ] && [ "$rc" -eq 1 ]; then ok=1; fi
  if [ "$ok" -eq 0 ]; then
    printf 'ok       %-34s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-34s rc=%s (wanted %s)\n' "$name" "$rc" "$needle"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -4; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-actions-lint.sh ==="

# 1. a workflow outside the audited directory must FAIL the gate, not just print
d="$TMP/stray"; build "$d"; mkdir -p "$d/tools/.github/workflows"
cp "$d/.github/workflows/ci.yml" "$d/tools/.github/workflows/stray.yml"
check stray-workflow-fails-the-gate "outside the audited directory" yes "$d"

# 2. the same workflow under bench/cases is the declared exception
d="$TMP/bench"; build "$d"; mkdir -p "$d/bench/cases/x/.github/workflows"
cp "$d/.github/workflows/ci.yml" "$d/bench/cases/x/.github/workflows/case.yml"
check bench-case-workflow-is-allowed "actions-lint" no "$d"

# 3. no workflows directory at all is could-not-measure, never a pass
d="$TMP/empty"; mkdir -p "$d"
out="$(EHS_REPO_ROOT="$d" bash "$GATE" 2>&1)"; rc=$?
if [ "$rc" -eq 2 ]; then printf 'ok       %-34s rc=2\n' no-workflows-is-unmeasurable; pass=$((pass+1))
else printf 'FAILED   %-34s rc=%s (wanted 2)\n' no-workflows-is-unmeasurable "$rc"; fail=$((fail+1)); fi

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. The tool-free half of this gate fails when it must fail."
exit 0
