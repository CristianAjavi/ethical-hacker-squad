#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-deferral-lane.sh — a control declared to run SOMEWHERE ELSE must have a
# somewhere else, and it must still be there.
#
# WHY IT EXISTS
#   This repository is careful about the difference between a control that is
#   silenced and one that runs on another path: run-all.sh prints
#   "NOT RUN HERE (declared, not silenced)" with the name and the reason, and
#   ci.yml defers `gate-actions-lint.sh` out of the `gates` job with --skip
#   because a second job runs it with --only. Both are the right design, and
#   both rest on a fact that NOTHING in this repository measured: that the other
#   path exists.
#
#   Measured on origin/main before this gate: the deferral declarations name
#   four controls and the workflows name three of them; the `--skip` in
#   ci.yml's `gates` job is paired with an `--only` in `workflow-hardening`, and
#   the only thing keeping that pair honest is that nobody has edited either
#   line. Delete the second job, rename the gate, or narrow the --only glob, and
#   every runner goes on printing "declared, not silenced" about a lane that no
#   longer runs anything. A deferred control with no lane is not deferred, it is
#   gone - and it is gone with an alibi, which is worse than gone, because the
#   output still reads like coverage.
#
# WHAT IT MEASURES  (three questions, no network, no git)
#   1. DECLARED, THEREFORE RUN SOMEWHERE. Every control this repository declares
#      it is not running here - the `*_SCOPED` lists in scripts/gates/run-all.sh,
#      every name in scripts/gates/data/slow-scoped.txt when that file exists,
#      and every control a workflow removes with `--skip` - must be named by
#      some OTHER non-comment line in .github/workflows/**, or matched there by
#      an `--only` glob. A `--skip` is never a lane: two workflows skipping the
#      same control is not the same as one running it.
#   2. THE PATTERN RESOLVES. Every `--only` and `--skip` glob in a workflow must
#      match at least one control that exists in scripts/gates/. A glob that
#      matches nothing is a lane that runs nothing, and it reads identically to
#      one that works.
#   3. THE EXEMPTIONS ARE HONEST. A control whose lane is deliberately outside
#      CI must be named in scripts/gates/data/deferred-lanes.json with a written
#      reason, and it is printed by name on every run. The list is checked in
#      the OTHER direction too: an entry for a control that no longer exists, is
#      no longer deferred, or has acquired a real lane is a failure - an
#      exemption nobody can be caught by is how a hole becomes permanent.
#
# WHAT IT CANNOT SEE  (stated, because an unstated limit reads as coverage)
#   A lane is recognised by NAME. A job that re-runs the deferred control
#   without naming it - `run-all.sh --pr-context` with no --only, say - is a
#   real lane this gate will not credit, and the failure it produces says so;
#   the fix is to name the control in the step or to declare it in the JSON.
#   That error is loud and it errs towards accusing a lane that exists, never
#   towards passing one that does not. A control named only inside a trailing
#   `#` comment on an otherwise live line would be credited; full-line comments
#   are stripped and a case in the self-test proves it.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure - no python3, no runner, no workflows, a declaration shape this gate
# does not recognise, or a data file that will not parse. An unmeasured lane is
# not a lane that exists.
# ---------------------------------------------------------------------------
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"

gate_header "deferral lane (a control declared to run elsewhere has an elsewhere)"
gate_scope "every control deferred by name, against the workflows that are supposed to run it"
gate_out_of_scope "whether the lane PASSES - that is the lane's own job, and its own CI check"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was checked"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

rc=0
python3 "$SELF_DIR/lib/deferral_lane.py" "$ROOT" || rc=$?

gate_verdict "$rc"
exit "$rc"
