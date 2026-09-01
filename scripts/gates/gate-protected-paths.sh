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
#   AND THE CONTROL HAD THE HOLE IT WAS BUILT TO CLOSE. Until 2026-09-01 it
#   decided whether the editor was an automation FROM THE BRANCH PREFIX, and the
#   branch is named by whoever is editing. In PR #72 an agent raised
#   `MAX_TREE_BYTES` from 655,360 to 786,432 B inside `scripts/gates/**` - this
#   file's own example of an automation editing its limits - and this gate passed
#   it green, because the branch was `loop/...` and the prefix list says `bot/`.
#   A longer prefix list does not fix that; any list of chosen names has the same
#   hole. What fixes it is reading a self-declaration in ONE direction:
#
#       an admission INCRIMINATES, a denial EXCULPATES NOTHING.
#
# WHAT IT MEASURES
#   Whether the change under test carries any mark of automation - the branch
#   prefix, kept but demoted to one signal among others, plus the marks the
#   agent's own harness writes into the commit range: a `Claude-Session:`
#   trailer, an `@anthropic.com` or `[bot]` identity - and whether its diff
#   touches a protected path. It also checks that the fenced list in
#   docs/gate-requirements.md still says exactly what
#   scripts/gates/data/protected-paths.json enforces, so the rule and its
#   documentation cannot drift.
#
#   An UNATTRIBUTED change touching a protected path is allowed and PRINTED,
#   never silently waved through: the maintainer reviews it, and can only review
#   what the run tells them is there. It is not called a human change, because
#   nothing available when this gate runs proves that one was.
#
#   That listing is now ORDERED rather than flat: the paths that carry weight
#   first, negative-proof material folded into one counted line. Measured over
#   the 28 merged changes that tripped this gate, 38 of the 150 paths it named
#   were fixture inputs and on the worst change 2 real limits sat under 19 lines
#   of them. Folding is a display decision, held to that by seven battery cases:
#   a FINDING names every path and so does an override. Nothing left `paths`.
#
#   If the commit range CANNOT be read and a protected path was touched, half the
#   classifier did not run and the verdict is 2, not 0.
#
#   THE WAY OUT is a LABEL on the pull request, `override/g7-reviewed`, passed in
#   by the workflow. A label is not in the diff, not in the branch and not in a
#   commit, so granting one is a separate act on GitHub, visible in the pull-
#   request timeline rather than in the change it waves through; and the run
#   prints, in capitals,
#   every limit that moved with consent. In a single-maintainer repository this
#   is as far as the separation goes and the docstring of the core says so: the
#   maintainer and the maintainer's agent commit with the same account, so no
#   signal here proves a person. What the gate guarantees is that the class never
#   passes UNNOTICED, which is the property that was actually missing.
#
# WHAT IT DOES NOT MEASURE
#   Whether the change is a good one. It asks who is changing the limits, not
#   whether they should. And it cannot prove a PERSON made a change: a
#   pull-request approval does not exist yet when CI runs, and every other signal
#   at gate time is written by the editor.
#
# Usage:
#   scripts/gates/gate-protected-paths.sh [--branch NAME] [--changed-files FILE]
#                                         [--base REF] [--authorship FILE]
#                                         [--override LABEL] [--diff FILE]
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
AUTHORSHIP=""
OVERRIDE="${EHS_G7_OVERRIDE:--}"
DIFF=""

while [ $# -gt 0 ]; do
  case "$1" in
    --branch)        BRANCH="${2:-}"; shift 2 ;;
    --changed-files) CHANGED="${2:-}"; shift 2 ;;
    --base)          BASE="${2:-}"; shift 2 ;;
    --authorship)    AUTHORSHIP="${2:-}"; shift 2 ;;
    --override)      OVERRIDE="${2:--}"; shift 2 ;;
    --diff)          DIFF="${2:-}"; shift 2 ;;
    -h|--help)       sed -n '2,53p' "$0"; exit 0 ;;
    *)               shift ;;
  esac
done

gate_header "protected-paths (an automation may not edit its own limits)"
gate_scope "every automation mark on the change under test - branch prefix and commit-range markers - against the protected list, and that list against its documentation"
gate_out_of_scope "whether the change is a good one, and whether a PERSON made it: an absent mark is not a human"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was checked"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$CORE" ]; then
  gate_warn "the measurement core is missing: $CORE"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

if [ -z "$BRANCH" ]; then
  # `git rev-parse` run inside a directory that is not a repository walks UP and
  # answers about an ANCESTOR one. On a CI runner that turns "I do not know whose
  # branch this is" into a confident wrong answer - the self-test caught exactly
  # that. So the fallback only applies when $ROOT is itself the top level.
  top="$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null)" || top=""
  here="$(cd "$ROOT" 2>/dev/null && pwd -P)" || here=""
  if [ -n "$top" ] && [ -n "$here" ] && [ "$(cd "$top" 2>/dev/null && pwd -P)" = "$here" ]; then
    BRANCH="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)" || BRANCH=""
  fi
fi
[ -n "$BRANCH" ] || BRANCH="-"

[ -n "$BASE" ] || BASE="$(git -C "$ROOT" rev-parse --verify -q origin/main >/dev/null 2>&1 && echo origin/main || echo main)"

TMP=""
if [ -z "$CHANGED" ]; then
  TMP="$(mktemp "${TMPDIR:-/tmp}/ehs-protected-XXXXXX")"
  if git -C "$ROOT" diff --name-only "$BASE"...HEAD > "$TMP" 2>/dev/null; then
    CHANGED="$TMP"
  else
    rm -f "$TMP"
    gate_warn "no changed-file list: pass --changed-files, or run where '$BASE' can be resolved. A protected-path check with no diff has not run."
    gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
  fi
fi

# The commit range, one line per commit: sha, author, committer, trailers. This
# is the half the editor does not choose as a name. `-` when it cannot be read,
# and `-` is not the same answer as an empty range: the core treats the first as
# blindness and the second as a reading that found nothing.
ATMP=""
if [ -z "$AUTHORSHIP" ]; then
  ATMP="$(mktemp "${TMPDIR:-/tmp}/ehs-authorship-XXXXXX")"
  if git -C "$ROOT" log --no-merges \
        --format='%H%x09%an <%ae>%x09%cn <%ce>%x09%(trailers:unfold,separator=%x3B)' \
        "$BASE..HEAD" > "$ATMP" 2>/dev/null; then
    AUTHORSHIP="$ATMP"
  else
    rm -f "$ATMP"; ATMP=""; AUTHORSHIP="-"
  fi
fi

# The diff itself, not just the names. A content exemption asks WHAT changed in a
# protected file, and it can only be answered from here. `-` when it cannot be
# read: the core then applies no exemption at all, which is the safe direction.
DTMP=""
if [ -z "${DIFF:-}" ]; then
  DTMP="$(mktemp "${TMPDIR:-/tmp}/ehs-diff-XXXXXX")"
  if git -C "$ROOT" diff -U0 "$BASE"...HEAD > "$DTMP" 2>/dev/null; then
    DIFF="$DTMP"
  else
    rm -f "$DTMP"; DTMP=""; DIFF="-"
  fi
fi

out="$(python3 "$CORE" "$ROOT" "$BRANCH" "$CHANGED" "$AUTHORSHIP" "$OVERRIDE" "$DIFF" 2>&1)"; rc=$?
[ -n "$TMP" ] && rm -f "$TMP"
[ -n "$ATMP" ] && rm -f "$ATMP"
[ -n "$DTMP" ] && rm -f "$DTMP"
while IFS= read -r line; do
  case "$line" in
    FINDING\ *)      gate_fail "${line#FINDING }" ;;
    UNMEASURED\ *)   gate_warn "${line#UNMEASURED }" ;;
    NOT\ MEASURED*)  gate_out_of_scope "${line#NOT MEASURED: }" ;;
    OVERRIDDEN\ *)   gate_log ""; gate_log "$line" ;;
    EXEMPT\ *)       gate_log "EXEMPT ${line#EXEMPT }" ;;
    NOTE:\ *)        gate_log "NOTE: ${line#NOTE: }" ;;
    *)               gate_info "$line" ;;
  esac
done <<< "$out"

case "$rc" in
  0) if [ "$OVERRIDE" != "-" ] && printf '%s' "$out" | grep -q '^OVERRIDDEN '; then
       gate_ok "the limits are documented as enforced; an automation moved some of them and the maintainer's label says so on purpose"
     else
       gate_ok "the limits are documented as enforced, and nothing carrying a mark of automation touched them"
     fi ;;
  1) : ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac
gate_verdict "$rc"
exit "$rc"
