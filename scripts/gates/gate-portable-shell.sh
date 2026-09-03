#!/usr/bin/env bash
# scripts/gates/gate-portable-shell.sh
#
# No shell script under scripts/ may depend on a BSD-only or GNU-only spelling
# unless it offers the other platform's spelling as a fallback, or says in
# writing why it does not.
#
# WHY IT EXISTS
#   Measured on CI 2026-09-02. gate-lockfile-coherence.selftest.sh reported
#   16 passed, 0 failed on the author's Mac and 11 passed, 5 failed on the
#   Linux runner, same file, same commit. All five broken cases used `sed -i ''`
#   - BSD syntax that GNU sed reads as an empty script, so the mutation never
#   applied. Nothing about the logic was wrong. The green Mac simply could not
#   see it, and this repository has no Linux to check against: docker is not
#   installed on the development machine, so CI was the only instrument that
#   could answer, and it answers after the push.
#
#   `grep -rln "sed -i ''" scripts/` returned exactly one file that day: the one
#   just written. The repository was portable by habit, not by control. This is
#   the control.
#
# WHAT IT DOES NOT DECIDE
#   Whether the divergent line is REACHABLE. This is lexical: a BSD-only
#   invocation on a branch that never runs on Linux is still reported, because
#   deciding otherwise means interpreting the shell. It also does not decide the
#   catalogue - that is written in data/portable-shell-catalogue.json, whose
#   out_of_scope block names the divergences that are NOT checked. What is not
#   in that file passes in silence, and the gate prints that block on every run
#   so the silence is at least stated out loud.
#
# Exit codes: 0 = measured and fine | 1 = measured and fails | 2 = could not measure.
#
# Usage:
#   scripts/gates/gate-portable-shell.sh
#   scripts/gates/gate-portable-shell.sh --root DIR
#   scripts/gates/gate-portable-shell.sh --catalogue FILE
#   scripts/gates/gate-portable-shell.sh --self-test

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

CORE="$SELF_DIR/lib/portable_shell.py"
ROOT="$(cd "${EHS_REPO_ROOT:-$(gate_root)}" && pwd -P)"
CATALOGUE=""
ONLY_SELFTEST=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --catalogue) CATALOGUE="${2:-}"; shift 2 ;;
    --self-test) ONLY_SELFTEST=1; shift ;;
    -h|--help) sed -n '2,36p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

if [ "$ONLY_SELFTEST" -eq 1 ]; then
  exec bash "$SELF_DIR/gate-portable-shell.selftest.sh"
fi

command -v python3 >/dev/null 2>&1 || {
  gate_warn "python3 is missing: the catalogue cannot be applied"
  exit "$GATE_UNMEASURABLE"
}
[ -f "$CORE" ] || { gate_warn "the core is missing: $CORE"; exit "$GATE_UNMEASURABLE"; }

echo "=== gate-portable-shell (root: $ROOT) ==="

# PYTHONSAFEPATH: the helper is invoked BY PATH, so its own directory leads on
# sys.path rather than a working directory that may belong to a tree under audit.
if [ -n "$CATALOGUE" ]; then
  out="$(PYTHONSAFEPATH=1 python3 "$CORE" "$ROOT" "$CATALOGUE" 2>&1)"; rc=$?
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
  0) gate_ok   "every divergent invocation has a fallback or a written exemption" ;;
  1) gate_fail "$findings line(s) depend on one platform's spelling with no way out written down" ;;
  *) gate_warn "the portability of scripts/ could NOT be measured" ;;
esac
exit "$rc"
