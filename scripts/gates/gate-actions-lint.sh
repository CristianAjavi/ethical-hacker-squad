#!/usr/bin/env bash
# scripts/gates/gate-actions-lint.sh
#
# Static analysis gate for GitHub Actions, using the two tools validated for
# this repo: zizmor (security) and actionlint (correctness). They are
# complementary, not redundant:
#   - zizmor covers the hard rules of the threat model: dangerous-triggers,
#     template-injection, excessive-permissions, unpinned-uses, artipacked...
#     and it also audits .github/dependabot.yml.
#   - actionlint validates syntax, expressions, cron, runner labels, the format
#     of `uses:`, and runs shellcheck over every `run:`. Its list of untrusted
#     contexts (github.event.issue.title, comment.body, ...) is the canonical
#     enumeration that GitHub's own documentation does not publish.
#
# Exit codes: 0 = measured and fine | 1 = measured and fails | 2 = could not measure.
#
# Code mapping MEASURED empirically (zizmor 1.29.0, actionlint 1.7.12):
#   zizmor     0 -> 0 | 11,12,13,14 (informational/low/medium/high) -> 1
#              3 (no input was collected) -> 2 | 1 (error) -> 2
#   actionlint 0 -> 0 | 1 -> 1 | 3 (could not read) -> 2
#
# FORBIDDEN in this file, by construction:
#   - `--format=sarif`: it returns 0 even when there are high findings (verified).
#   - piping the tool into `tail`/`head`: it destroys the exit code. That is why
#     all output goes to a file by redirection, and is read afterwards.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"
# shellcheck source=scripts/gates/lib/bootstrap-actions-lint.sh
. "$SELF_DIR/lib/bootstrap-actions-lint.sh"

# EHS_REPO_ROOT like every other gate: without it this gate could not be pointed
# at a throwaway tree, which is why it had no self-test and why its stray-workflow
# check went unexercised.
ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
WF_DIR="$ROOT/.github/workflows"

TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t gatelint)"
trap 'rm -rf "$TMPD"' EXIT

RC_FINAL=0
# escalate(rc): a FAIL (1) outranks an UNMEASURABLE (2); 0 degrades nothing.
escalate() {
  case "$1" in
    1) RC_FINAL=1 ;;
    2) [ "$RC_FINAL" -eq 1 ] || RC_FINAL=2 ;;
  esac
}

dump() { # dump <file> <prefix>
  [ -s "$1" ] || return 0
  while IFS= read -r l; do printf '%s%s\n' "$2" "$l"; done < "$1"
}

gate_header "actions-lint (zizmor + actionlint)"
gate_scope "every workflow, composite action and .github/dependabot.yml in the repo"
gate_out_of_scope "business logic of the scripts; the permissions/triggers contract is also verified by gate-workflow-hardening.sh without depending on these tools"

if [ ! -d "$WF_DIR" ]; then
  gate_warn "$WF_DIR does not exist: there are no workflows to analyse (and that is not a pass)"
  gate_verdict 2
  exit "$GATE_UNMEASURABLE"
fi

# ---------------------------------------------------------------------------
# A workflow outside the audited directory - checked with no tool at all, so it
# still runs when the linters cannot be bootstrapped.
# Scoped to THIS repository's own workflows, not the whole tree. bench/cases/
# ships workflows written to be insecure - that is what the evaluation bench
# is - and auditing them here would mean the gate reports the bench's planted
# defects as our own. The scoping is not a hole: the check below fails if a
# workflow appears anywhere outside the audited directory and outside the
# bench, which is the only way this exclusion could hide a real one.
stray="$(find "$ROOT" -path "$ROOT/.git" -prune -o -path '*/.github/workflows/*' -type f \
          \( -name '*.yml' -o -name '*.yaml' \) -print 2>/dev/null \
          | grep -v "^$ROOT/.github/workflows/" | grep -v "^$ROOT/bench/cases/" || true)"
if [ -n "$stray" ]; then
  gate_fail "workflow file(s) outside the audited directory and outside bench/cases:"
  printf '%s\n' "$stray" | while IFS= read -r f; do gate_log "        ${f#"$ROOT"/}"; done
  # escalate, not a private counter: this gate computes its verdict from
  # RC_FINAL, and the counter it used to increment was read by nothing. The
  # check printed FAIL and the gate exited 0 - a false green in the gate that
  # exists to stop false greens, found by a blinded audit of this repository.
  escalate 1
fi


# zizmor
# ---------------------------------------------------------------------------
ZOUT="$TMPD/zizmor.txt"
if ensure_zizmor; then
  ZARGS="--no-progress --color never --format plain"
  # Online audits (impostor-commit, known-vulnerable-actions, stale-action-refs)
  # only when there is a token AND they are requested explicitly. Never by
  # default: a job analysing a PR from a fork must not receive secrets.
  if [ "${ZIZMOR_ONLINE:-0}" = "1" ] && [ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]; then
    gate_info "zizmor: ONLINE audits enabled (ZIZMOR_ONLINE=1 and a token is present)"
  else
    ZARGS="$ZARGS --no-online-audits"
    gate_info "zizmor: online audits DISABLED - impostor-commit, known-vulnerable-actions and stale-action-refs were NOT checked (that runs in the supply-chain-audit workflow)"
  fi
  # shellcheck disable=SC2086
  "$ZIZMOR_BIN" $ZARGS "$ROOT/.github" > "$ZOUT" 2>&1
  zrc=$?
  case "$zrc" in
    0)  gate_ok "zizmor $ZIZMOR_VERSION: no findings" ;;
    11|12|13|14)
        gate_fail "zizmor $ZIZMOR_VERSION: findings (code $zrc)"
        dump "$ZOUT" "  "
        escalate 1 ;;
    3)  gate_warn "zizmor $ZIZMOR_VERSION: it collected no input (code 3)"
        dump "$ZOUT" "  "
        escalate 2 ;;
    *)  gate_warn "zizmor $ZIZMOR_VERSION: tool error (code $zrc)"
        dump "$ZOUT" "  "
        escalate 2 ;;
  esac
else
  gate_warn "zizmor NOT available: dangerous-triggers, template-injection, excessive-permissions, unpinned-uses and dependabot.yml were NOT audited"
  escalate 2
fi
printf '%s' "$BOOTSTRAP_NOTES" | sed 's/^/  · /'
BOOTSTRAP_NOTES=""

# ---------------------------------------------------------------------------
# actionlint
# ---------------------------------------------------------------------------
AOUT="$TMPD/actionlint.txt"
if ensure_actionlint; then
  if ! command -v shellcheck >/dev/null 2>&1; then
    gate_warn "shellcheck is NOT installed: actionlint will NOT analyse the contents of the \`run:\` blocks. The rest is measured, but this is NOT a complete pass."
    escalate 2
  fi
  ( cd "$ROOT" && "$ACTIONLINT_BIN" -no-color -oneline ) > "$AOUT" 2>&1
  arc=$?
  case "$arc" in
    0) gate_ok "actionlint $ACTIONLINT_VERSION: no problems" ;;
    1) gate_fail "actionlint $ACTIONLINT_VERSION: problems found (code 1)"
       dump "$AOUT" "  "
       escalate 1 ;;
    3) gate_warn "actionlint $ACTIONLINT_VERSION: it could not read the files (code 3)"
       dump "$AOUT" "  "
       escalate 2 ;;
    *) gate_warn "actionlint $ACTIONLINT_VERSION: unexpected code $arc"
       dump "$AOUT" "  "
       escalate 2 ;;
  esac
else
  gate_warn "actionlint NOT available: syntax, cron, runners and the expressions with untrusted contexts were NOT validated"
  escalate 2
fi
printf '%s' "$BOOTSTRAP_NOTES" | sed 's/^/  · /'

gate_verdict "$RC_FINAL"
exit "$RC_FINAL"
