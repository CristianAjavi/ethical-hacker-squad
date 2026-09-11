#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-tooling-blindspot.sh — a procedure that searches a hidden path can see it.
#
# WHY IT EXISTS
#   references/tooling.md:19 already says it: `rg` honours `.gitignore` and
#   `.ignore` and skips hidden files, `fd` does the same, so a search that comes
#   back empty has searched a FILTERED view of the tree — "a false-negative
#   source, not a false-positive one, so nothing in the output warns you". It
#   then tells the auditor to run `rg -uu --hidden` before recording a negative.
#   Measured on 2026-09-10, on origin/main @ 6066048: 90 `rg`/`fd` invocations
#   across the knowledge corpus, 4 of them carrying any completeness flag, and
#   `grep -rlE 'no-ignore|--hidden|-uu' scripts/gates/` empty — not one of the
#   31 gates was reading that rule back. AI-25 sends the auditor at
#   `.claude-plugin` with the defaults on; AI-30 and LOC-07 at `.env`; AI-28 at
#   `.cursor`. Each of those returns zero hits on a tree where the file exists,
#   and zero hits is exactly what a clean audit looks like.
#
# WHAT IT MEASURES  (scripts/gates/lib/tooling_blindspot.py does the reading)
#   1. premise    tooling.md still declares the `-uu --hidden` rule. If the rule
#                 is gone this gate has lost its mandate and says COULD NOT
#                 MEASURE — it never passes on an empty premise.
#   2. blind spot for every `### XXX-NN` that sends the auditor at a path the
#                 defaults hide, at least ONE of its `rg`/`fd` invocations can
#                 reach it: by carrying the complete flag pair for its tool, or
#                 by naming that path as its own argument.
#
# CALIBRATION (why it is not stricter)
#   The unit of judgement is the PROCEDURE, not the command. A procedure that
#   greps source with the defaults on and then points a second, explicit
#   invocation at the dotted file is CORRECT, and a per-command rule accused
#   three of those (INF-08, INF-20, INF-24) before this was fixed. A hidden path
#   inside the search PATTERN does not count as reach — it is a string being
#   looked for, not a place being looked in — and `-g '!.git'` EXCLUDES a path,
#   so it neither exposes the procedure nor covers it.
#
# WHAT IT DOES NOT MEASURE
#   Whether the pattern is the right pattern, whether the procedure finds the
#   defect, and whether `rg`/`fd` behave as documented on the machine running
#   this — the core reads text, it runs neither tool. The hidden-path vocabulary
#   is a NAMED, FINITE list, not "anything with a dot": treating every dotted
#   token as a directory would accuse `os.environ` and most of the corpus.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure. A missing interpreter, a missing core or a red with no finding on it
# is a 2, never a 0.
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/tooling_blindspot.py"

gate_header "tooling-blindspot (procedures that search a path rg and fd hide by default)"
gate_scope "every rg/fd invocation in the knowledge corpus, against the completeness rule tooling.md states"
gate_out_of_scope "whether the pattern is right, whether the procedure finds the defect, and how rg and fd behave on this machine"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was measured"
  gate_verdict "$GATE_UNMEASURABLE"
  exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$CORE" ]; then
  gate_warn "the measurement core is missing: $CORE"
  gate_verdict "$GATE_UNMEASURABLE"
  exit "$GATE_UNMEASURABLE"
fi

out="$(python3 "$CORE" "$ROOT" 2>&1)"
rc=$?

findings=0
while IFS= read -r line; do
  case "$line" in
    FINDING\ *)    gate_fail "${line#FINDING }"; findings=$((findings + 1)) ;;
    UNMEASURED\ *) gate_warn "${line#UNMEASURED }" ;;
    *)             gate_info "$line" ;;
  esac
done <<< "$out"

case "$rc" in
  0) gate_ok "every procedure that searches a hidden or ignored path can actually reach it" ;;
  1)
    # A red with nothing on it is the interpreter dying, not a measurement:
    # python exits 1 on an uncaught error too, and that must never read as FAIL.
    if [ "$findings" -eq 0 ]; then
      gate_warn "the core exited 1 without emitting a finding: it crashed, nothing was measured"
      rc="$GATE_UNMEASURABLE"
    fi
    ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac

gate_verdict "$rc"
exit "$rc"
