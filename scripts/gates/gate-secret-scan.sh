#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-secret-scan.sh — G6, secrets in the tree.
#
# WHY IT EXISTS
#   docs/gate-requirements.md has specified G6 since the beginning and nothing
#   implemented it. The corpus tells auditors that an absent scanner is not a
#   clean repository; the same sentence applies to us.
#
# WHAT IT MEASURES
#   Distinctive formats, never entropy - the precision measurement recorded in
#   references/tooling.md is the reason. GitHub tokens are settled offline by
#   their CRC32 checksum, so a hit there is a fact rather than a guess.
#
#   Two scopes, and the second is what makes the first honest:
#     1. the working tree, minus bench/cases/, which ships planted secrets on
#        purpose - that is what an evaluation bench is;
#     2. bench/cases/ against the answer key: a secret-shaped string there must
#        be a defect the key declares, or the exclusion is hiding a real one.
#
# WHAT IT DOES NOT MEASURE
#   Git history. Rewriting a history is a different operation with a different
#   authorization conversation, and this gate says so on every run instead of
#   implying the repository is clean back to the first commit.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, unreadable tree, a bench whose key will not parse).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"
ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/secret_scan.py"

gate_header "secret-scan (distinctive formats, and the bench exclusion checked)"
gate_scope "the working tree by published secret formats, plus every secret-shaped string under bench/cases against the answer key"
gate_out_of_scope "git history, and any secret whose format is not published"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was scanned, which is not the same as nothing being there"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$CORE" ]; then
  gate_warn "the measurement core is missing: $CORE"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

out="$(python3 "$CORE" "$ROOT" 2>&1)"; rc=$?
while IFS= read -r line; do
  case "$line" in
    FINDING\ *)     gate_fail "${line#FINDING }" ;;
    UNMEASURED\ *)  gate_warn "${line#UNMEASURED }" ;;
    NOT\ SCANNED*)  gate_out_of_scope "${line#NOT SCANNED: }" ;;
    *)              gate_info "$line" ;;
  esac
done <<< "$out"

case "$rc" in
  0) gate_ok "no credential in the tree, and every secret-shaped string in the bench is a declared defect" ;;
  1) gate_core_rc 1; rc="$GATE_RC" ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac
gate_verdict "$rc"
exit "$rc"
