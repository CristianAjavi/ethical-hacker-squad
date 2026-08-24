#!/usr/bin/env bash
# Regression battery for gate-negative-evidence.sh: the gate must give the SAME
# verdict about the same tree however that tree was reached.
#
# It did not. The repository scan walks $ROOT - `git rev-parse --show-toplevel`,
# always the PHYSICAL path - and excludes its own fixtures by the string prefix
# $SELF_DIR, which was built with a plain `pwd` and is therefore LOGICAL. Reach
# the checkout through a symlink and the two disagree: the exclusion matches
# nothing, the gate scans its own fixtures, and the fixture that is
# deliberately unmeasurable turns the whole gate into COULD NOT MEASURE.
#
# Measured on one commit, before the fix:
#   /var/folders/.../ehs-probe            rc=2
#   /private/var/folders/.../ehs-probe    rc=0
#
# On macOS both $TMPDIR and /tmp are symlinks, so this fired for any checkout
# under either - and by this repository's contract an rc=2 fails the build. It
# was found by a tool that runs the suite over a worktree in $TMPDIR, not by
# anybody reading the code.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd -P)"
GATE="$HERE/gate-negative-evidence.sh"
ROOT="$(cd "$HERE/../.." && pwd -P)"
[ -f "$GATE" ] || { echo "UNMEASURABLE $GATE is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-negev-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# The gate is invoked THROUGH the given path, not merely told about it with
# EHS_REPO_ROOT. That distinction is the whole test: $SELF_DIR is built from
# $BASH_SOURCE, so only reaching the script itself by a symlinked path makes it
# logical while git keeps answering physically. A first version of this file
# varied only EHS_REPO_ROOT, passed with the fix AND without it, and proved
# nothing - caught by reverting the fix and watching it stay green.
check() {  # <label> <path to a repo root>
  local label="$1" root="$2" rc=0
  ( cd "$root" && bash "$root/scripts/gates/gate-negative-evidence.sh" ) >"$TMP/out.txt" 2>&1 || rc=$?
  if [ "$rc" -eq 0 ]; then
    printf 'ok       %-46s rc=0\n' "$label"; pass=$((pass+1))
  else
    printf 'FAILED   %-46s rc=%s (wanted 0)\n' "$label" "$rc"
    grep -iE 'could not measure|unbalanced-region' "$TMP/out.txt" | sed 's/^/         /' | head -3
    fail=$((fail+1))
  fi
}

echo "=== self-test: gate-negative-evidence.sh reached by different paths ==="

# The control: the physical path, which always worked.
check "the repository by its physical path" "$ROOT"

# The regression: the same tree behind a symlink. This is the case that failed.
ln -s "$ROOT" "$TMP/link"
check "the same tree through a symlink" "$TMP/link"

# And a symlinked path with a trailing component, the shape $TMPDIR produces.
mkdir -p "$TMP/nest"
ln -s "$ROOT" "$TMP/nest/repo"
check "a symlink one directory down" "$TMP/nest/repo"

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED. The verdict depends on how the tree was reached."; exit 1; }
echo "Result: OK. The same tree gets the same verdict by every path to it."
exit 0
