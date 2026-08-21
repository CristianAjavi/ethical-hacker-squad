#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-protected-paths.sh — G7, the limits an automation may not edit.
#
# WHY IT EXISTS
#   docs/gate-requirements.md has specified G7 since the beginning and nothing
#   implemented it. The list it protects is the list that says what this system
#   may do and what it may read: the skill entry point, the plugin manifest, the
#   agents, the workflows, CODEOWNERS, the source allowlist, the gates, the
#   licence and the notice. An automation that can edit its own limits has none.
#
# WHAT IT MEASURES
#   Whether the branch under test is an automated one (a name starting with a
#   declared prefix, `bot/` today) and whether its diff touches a protected path.
#   It also checks that the fenced list in docs/gate-requirements.md still says
#   exactly what scripts/gates/data/protected-paths.json enforces, so the rule
#   and its documentation cannot drift.
#
#   A HUMAN branch touching a protected path is allowed and PRINTED, never
#   silently waved through: the maintainer reviews it, and can only review what
#   the run tells them is there.
#
# WHAT IT DOES NOT MEASURE
#   Whether the change is a good one. It asks who is changing the limits, not
#   whether they should.
#
# Usage:
#   scripts/gates/gate-protected-paths.sh [--branch NAME] [--changed-files FILE]
#                                         [--base REF]
#   Environment: GITHUB_HEAD_REF, GITHUB_BASE_REF, CHANGED_FILES_FILE, BASE_REF.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, no branch, no file list, an unusable data file).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"
ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/protected_paths.py"

BRANCH="${GITHUB_HEAD_REF:-}"
CHANGED="${CHANGED_FILES_FILE:-}"
BASE="${BASE_REF:-${GITHUB_BASE_REF:-}}"

while [ $# -gt 0 ]; do
  case "$1" in
    --branch)        BRANCH="${2:-}"; shift 2 ;;
    --changed-files) CHANGED="${2:-}"; shift 2 ;;
    --base)          BASE="${2:-}"; shift 2 ;;
    -h|--help)       sed -n '2,33p' "$0"; exit 0 ;;
    *)               shift ;;
  esac
done

gate_header "protected-paths (an automation may not edit its own limits)"
gate_scope "the branch under test against the protected list, and that list against its documentation"
gate_out_of_scope "whether the change is a good one: this asks who is changing the limits"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was checked"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$CORE" ]; then
  gate_warn "the measurement core is missing: $CORE"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

if [ -z "$BRANCH" ]; then
  BRANCH="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)" || BRANCH=""
fi
[ -n "$BRANCH" ] || BRANCH="-"

TMP=""
if [ -z "$CHANGED" ]; then
  [ -n "$BASE" ] || BASE="$(git -C "$ROOT" rev-parse --verify -q origin/main >/dev/null 2>&1 && echo origin/main || echo main)"
  TMP="$(mktemp "${TMPDIR:-/tmp}/ehs-protected-XXXXXX")"
  if git -C "$ROOT" diff --name-only "$BASE"...HEAD > "$TMP" 2>/dev/null; then
    CHANGED="$TMP"
  else
    rm -f "$TMP"
    gate_warn "no changed-file list: pass --changed-files, or run where '$BASE' can be resolved. A protected-path check with no diff has not run."
    gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
  fi
fi

out="$(python3 "$CORE" "$ROOT" "$BRANCH" "$CHANGED" 2>&1)"; rc=$?
[ -n "$TMP" ] && rm -f "$TMP"
while IFS= read -r line; do
  case "$line" in
    FINDING\ *)      gate_fail "${line#FINDING }" ;;
    UNMEASURED\ *)   gate_warn "${line#UNMEASURED }" ;;
    NOT\ MEASURED*)  gate_out_of_scope "${line#NOT MEASURED: }" ;;
    *)               gate_info "$line" ;;
  esac
done <<< "$out"

case "$rc" in
  0) gate_ok "the limits are documented as enforced, and no automated branch touched them" ;;
  1) : ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac
gate_verdict "$rc"
exit "$rc"
