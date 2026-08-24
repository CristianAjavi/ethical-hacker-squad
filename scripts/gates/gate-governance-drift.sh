#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-governance-drift.sh - does the LIVE repository match the governance this
# repository declares for itself?
#
# WHY THIS EXISTS, and it is not a hypothetical.
#   scripts/gh/governance.json declares the desired state with a _why block for
#   every choice, scripts/gh/apply-governance.sh compares it against the real
#   thing, and scripts/gh/tests/ proves the comparator watches every declared
#   field. All of that was built and NONE of it was ever run against the live
#   repository by anything. On 2026-08-21 the measurement was finally taken by
#   hand and `main` had no protection at all - no required check, no required
#   pull request, force pushes and branch deletion both allowed - on a public
#   repository whose subject is security. Ten declared items had drifted and
#   nothing had said so, because nothing was looking.
#
#   The comparator was never the gap. The gap was that a comparator nobody runs
#   is indistinguishable from a comparator that passes.
#
# WHAT IT MEASURES
#   Everything apply-governance.sh measures in dry-run: branch protection on
#   main (and on stable once that branch exists), repository settings, topics,
#   label taxonomy, vulnerability alerts, secret scanning, and the coherence
#   between promotion.required_contexts and the job names in ci.yml. It mutates
#   nothing: --apply is never passed from here.
#
# EXIT CODES
#   0  measured, the live state matches what this repo declares
#   1  measured, it does not match - the drift is listed
#   2  COULD NOT MEASURE, which is never a pass
#
# WHERE IT RUNS
#   Locally, and only there for now. Reading branch protection needs the
#   `administration` scope, and the GITHUB_TOKEN handed to a workflow cannot be
#   granted it - the permission simply does not exist for workflow tokens. So
#   scripts/gates/run-all.sh defers this gate by name with the reason
#   `needs-live-repo` rather than letting it report 2 forever and turn CI red.
#   To run it in CI, a fine-grained PAT with Administration:read is required;
#   that is a decision for the repository owner, and until it is taken this
#   limitation is written here instead of being hidden.
# ---------------------------------------------------------------------------
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$HERE/.." && pwd)"
GOV="${EHS_GOVERNANCE_SCRIPT:-$ROOT/gh/apply-governance.sh}"

say() { printf '%s\n' "$*"; }

command -v gh >/dev/null 2>&1 || {
  say "COULD NOT MEASURE: the gh CLI is not installed, so the live state cannot be read (rc 2)"; exit 2; }
[ -r "$GOV" ] || {
  say "COULD NOT MEASURE: $GOV is missing, and it is the comparator this gate delegates to (rc 2)"; exit 2; }
gh auth status >/dev/null 2>&1 || {
  say "COULD NOT MEASURE: gh is not authenticated, so every GET would 401 and read as 'no protection' (rc 2)"; exit 2; }

# The stable branch is created by the first promotion and does not exist before
# it. Its absence is a fact about the release schedule, not drift, and counting
# it as unmeasurable would make rc 0 unreachable for as long as the channel is
# unpublished - a threshold no real state can meet is a threshold that has
# stopped measuring. So it is skipped ONLY while it genuinely does not exist,
# and the moment it exists it is measured like everything else.
REPO="$(sed -n 's/.*"repo"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$ROOT/gh/governance.json" | head -1)"
ARGS=()
if [ -n "$REPO" ] && ! gh api "repos/$REPO/branches/stable" >/dev/null 2>&1; then
  ARGS+=(--skip-stable)
  say "note: branch 'stable' does not exist yet, so its protection is not counted as unmeasured"
fi

OUT="$("$GOV" "${ARGS[@]+"${ARGS[@]}"}" 2>&1)"; rc=$?
printf '%s\n' "$OUT" | sed -n '/^== /p;/DRIFT/p;/UNMEASURED/p;/^   failures/p'

case "$rc" in
  0) say "gate-governance-drift: rc=0 - the live repository matches scripts/gh/governance.json"; exit 0 ;;
  1) say "gate-governance-drift: rc=1 - MEASURED drift. scripts/gh/apply-governance.sh --apply is the fix, and it is the owner's call because it changes the live repository."; exit 1 ;;
  *) say "gate-governance-drift: rc=2 - COULD NOT MEASURE part of the governance (see UNMEASURED above). This does not count as a pass."; exit 2 ;;
esac
