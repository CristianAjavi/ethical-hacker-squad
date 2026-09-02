#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-lockfile-coherence.sh — one place says which CLI version we install.
#
# WHY IT EXISTS
#   `.github/workflows/release.yml` carried `CLAUDE_CODE_VERSION`, a copy of the
#   version already pinned in tooling/claude-cli/package-lock.json. It installed
#   nothing: the install is `npm ci`, out of that same lock, and the env var
#   existed only to be compared against it. The comparison lived in release.yml,
#   which runs on `schedule` and `workflow_dispatch` and never on a pull
#   request - so the copy could drift for as long as nobody cut a release.
#
#   Measured 2026-09-02: Dependabot PR #81 was open, MERGEABLE and 23 of 23
#   checks green, with the lock already moved to 2.1.246 and the env still at
#   2.1.221. The check that would have caught it could not run.
#
#   The env var was deleted. This gate is what stops it coming back, and it runs
#   where the old check could not: on every pull request.
#
# WHAT IT MEASURES
#   1. package.json and the lock's own copy of the manifest agree, both ways -
#      nothing declared and unlocked, nothing locked and undeclared
#   2. for an exact pin, the version the lock resolves is that version
#   3. no workflow declares a `*_VERSION` env var naming a package the lock
#      already pins: a second place to say it is a second place for it to be
#      wrong
#
# WHAT IT DOES NOT MEASURE
#   Whether the pinned version is a GOOD one - current, unrevoked, free of
#   advisories. That is Dependabot's job and the alert surface's, not a
#   coherence check's. It also cannot resolve a range: `^2.1.0` returns 2.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, a manifest that will not parse, a missing lock).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/lockfile_coherence.py"

gate_header "lockfile-coherence (one place says which CLI version we install)"
gate_scope "package.json against its lock in both directions, the resolved version behind an exact pin, and any workflow env var that would become a second copy"
gate_out_of_scope "whether the pinned version is a good one, and any dependency pinned by range rather than exactly"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was measured"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$CORE" ]; then
  gate_warn "the measurement core is missing: $CORE"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

out="$(python3 "$CORE" "$ROOT" 2>&1)"; rc=$?
findings=0
while IFS= read -r line; do
  case "$line" in
    FINDING\ *)    gate_fail "${line#FINDING }"; findings=$((findings + 1)) ;;
    UNMEASURED\ *) gate_warn "${line#UNMEASURED }" ;;
    *)             gate_info "$line" ;;
  esac
done <<< "$out"

# python3 exits 1 when it reports a measured failure AND when it dies on its
# way there. The discriminator is the output: a verdict that named nothing is
# a crash, and a crash is never a measurement.
if [ "$rc" -eq 1 ] && [ "$findings" -eq 0 ]; then
  gate_warn "the core exited 1 and named no finding: that is a crash, not a verdict"
  rc="$GATE_UNMEASURABLE"
fi

case "$rc" in
  0) gate_ok "the manifest, the lock and the workflows tell one story" ;;
  1) : ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac
gate_verdict "$rc"
exit "$rc"
