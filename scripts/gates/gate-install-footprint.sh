#!/usr/bin/env bash
# scripts/gates/gate-install-footprint.sh
#
# Every tracked file that gets installed on a user's machine must be claimed by
# a written policy that says what that root is, which extensions belong in it,
# and whether an execute bit or a binary is expected there.
#
# WHY IT EXISTS
#   A plugin installed from a marketplace lands in
#   `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`, and measured on
#   a real cache on this machine that directory is the whole work tree minus
#   `.git` - an unrelated plugin left 390 files there, `.github/` and `.mcp.json`
#   included. Nothing prunes on the way.
#
#   Measured on this repository: 1205 tracked files travel.
#   `gate-plugin-integrity.sh` section 4 looks at 41 of them - it walks
#   `EHS_SERVED_ROOTS`, which defaults to `skills agents commands hooks`, and
#   only the first two exist. 1164 files, 96.6 %, reached a stranger's disk with
#   nothing reading them. This is the control for the other 96.6 %.
#
#   The number this gate prints first is COVERAGE, not a count of bad files. The
#   failure mode it is built for is *a file nobody declared*, not *a file on a
#   blocklist*: a blocklist only catches what somebody already thought of, and
#   the whole point is the thing nobody thought of.
#
# WHAT IT DOES NOT DECIDE
#   Whether a declared file is SAFE. A policy says `bench/` may hold `.py`; it
#   says nothing about what that Python does, and the fixtures under `bench/` are
#   hostile on purpose and pass. It also cannot see an UNTRACKED file, because it
#   reads the git index - which is the same set a clone copies, but only for as
#   long as the cache really is a clone. Neither does it verify that the install
#   still copies everything; that was measured once, on one cache, on one day.
#
#   And it does not extend one root's rule to the next. `skills/` is Markdown
#   that never runs; `scripts/` is 99 executables on purpose and `bench/` is 5
#   more. One rule for the whole tree would have reported 105 correct files as
#   defects, and a gate whose first red accuses the compliant gets switched off.
#
# Exit codes: 0 = measured and fine | 1 = measured and fails | 2 = could not measure.
#
# Usage:
#   scripts/gates/gate-install-footprint.sh
#   scripts/gates/gate-install-footprint.sh --root DIR
#   scripts/gates/gate-install-footprint.sh --policy FILE
#   scripts/gates/gate-install-footprint.sh --self-test

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

CORE="$SELF_DIR/lib/install_footprint.py"
ROOT="$(cd "${EHS_REPO_ROOT:-$(gate_root)}" && pwd -P)"
POLICY=""
ONLY_SELFTEST=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --policy) POLICY="${2:-}"; shift 2 ;;
    --self-test) ONLY_SELFTEST=1; shift ;;
    -h|--help) sed -n '2,45p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

if [ "$ONLY_SELFTEST" -eq 1 ]; then
  exec bash "$SELF_DIR/gate-install-footprint.selftest.sh"
fi

command -v python3 >/dev/null 2>&1 || {
  gate_warn "python3 is missing: the install footprint cannot be measured"
  exit "$GATE_UNMEASURABLE"
}
command -v git >/dev/null 2>&1 || {
  gate_warn "git is missing: there is no way to list what is tracked"
  exit "$GATE_UNMEASURABLE"
}
[ -f "$CORE" ] || { gate_warn "the core is missing: $CORE"; exit "$GATE_UNMEASURABLE"; }

echo "=== gate-install-footprint (root: $ROOT) ==="

# PYTHONSAFEPATH: the helper is invoked BY PATH, so its own directory leads on
# sys.path rather than a working directory that may belong to a tree under audit.
if [ -n "$POLICY" ]; then
  out="$(PYTHONSAFEPATH=1 python3 "$CORE" "$ROOT" "$POLICY" 2>&1)"; rc=$?
else
  out="$(PYTHONSAFEPATH=1 python3 "$CORE" "$ROOT" 2>&1)"; rc=$?
fi
printf '%s\n' "$out"

findings=$(printf '%s\n' "$out" | grep -c '^FINDING' || true)

# python3 exits 1 both when it reports a measured failure and when it dies on
# its way to one. Told apart the only way they can be: a real verdict names at
# least one finding, and a rc=1 that named none is a crash wearing a verdict's
# exit code. Eleven gates in this repository once reported a crash as a measured
# failure; this is that lesson, wired.
if [ "$rc" -eq 1 ] && [ "$findings" -eq 0 ]; then
  gate_warn "the core exited 1 and named no finding: that is a crash, not a verdict"
  rc="$GATE_UNMEASURABLE"
fi

case "$rc" in
  0) gate_ok   "every installed file is claimed by a policy that says what it is" ;;
  1) gate_fail "$findings file(s) or exemption(s) travel with nobody accounting for them" ;;
  *) gate_warn "the install footprint could NOT be measured" ;;
esac
exit "$rc"
