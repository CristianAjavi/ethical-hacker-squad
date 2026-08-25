#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-triage-stage.sh — the per-stage triage eval, and the answer staying out
# of the question.
#
# WHY IT EXISTS
#   This repository measures end to end: a round asks whether the squad found
#   the defect, never whether one stage of it did its job. A neighbouring
#   product measures per stage, which is finer, and the honest response to a
#   finer instrument is to build one rather than to explain it away.
#
#   bench/stages/triage/ is that instrument for the triage stage, and it is
#   built around the one property a per-stage eval usually lacks: THE KEY IS
#   AUDITABLE BY MACHINE. The third column of every row - what follows for the
#   finding - is not an opinion anybody signed. It is forced from the answer by
#   the consequences table in references/triage.md, so this gate re-derives it
#   from that file and fails the case when the key and the table disagree.
#
#   The second half is the leak. Reading the same neighbouring product's eval
#   data, one case states the defect and the fix in the same sentence, so what
#   it scores is whether a model applies a fix it was handed. That is cheap to
#   do by accident and impossible to see by eye at scale, so it is checked here:
#   no presented field may carry the rule id, the answer token or the
#   consequence terms its own key declares, and none may prescribe the remedy.
#
# ITS RELATIONSHIP WITH gate-bench-integrity.sh, MEASURED RATHER THAN ASSUMED
#   There is prior art in this repository and a reader should not have to find
#   it by archaeology. Commit b8bce3d wired a leak check after both bench cases
#   shipped with `# Planted:` and `# Decoy:` comments on every construct, and it
#   is a FIXED VOCABULARY of four terms:
#
#       LEAK = re.compile(r"\bplanted\b|\bdecoy\b|ground.truth|answer key", re.I)
#
#   The two do not overlap, and that was measured in both directions rather than
#   argued:
#
#     - that vocabulary against the leak this gate was written from - the
#       neighbouring product`s `Fix by using parameterized query: ...` - returns
#       NO MATCH. A fixed list cannot anticipate a leak nobody has seen yet,
#       which is why this gate is RELATIVE TO THE KEY: each case is checked
#       against what ITS OWN key declares.
#     - this gate`s key-relative and remedy families against `# Planted:` return
#       no match either. A label naming the answer sheet is not a rule id, an
#       answer token, a consequence term or an imperative, so the fixed
#       vocabulary catches something these cannot.
#
#   Neither contains the other, so the fixed vocabulary stays where it is and is
#   BORROWED rather than copied: its scope is bench/ground-truth.json and does
#   not reach bench/stages/, so this gate applies the same pattern here, declared
#   once in the data file, with a guard that reports 2 if the literal stops
#   appearing in its owner. One rule, one place, two consumers, and drift is
#   loud.
#
# WHAT IT MEASURES
#   The derivation is still the one the rules file states; the key still seals
#   this cases.json by digest; every row cites a declared rule, a declared
#   answer and the derived consequence; a HOLDS or an UNKNOWN names the artifact
#   it rests on; every rule, answer and consequence is covered, with FP-04 and
#   FP-08 asked in the direction where a model over-affirms; and no case hands
#   over its own answer.
#
# WHAT IT DOES NOT MEASURE
#   Whether a case is well chosen, whether the rule named is the one a reviewer
#   would name, and whether any model answers correctly. IT DOES NOT RUN THE
#   EVAL: it reads files and calls no model. A green here says the instrument is
#   intact, not that anything scored. The leak scan is mechanical in both
#   families and is not a clearance - it catches a token and an imperative
#   construction, and a case that gives the answer away in a paraphrase passes
#   it and needs a reader.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, missing core, an unreadable or unparseable input, or a
# consequences table whose shape no longer supports the derivation).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/triage_stage.py"

gate_header "triage-stage (a key a machine can audit, and the answer kept out of the question)"
gate_scope "bench/stages/triage: the seal, every key row against the consequences table in references/triage.md, the reason behind a HOLDS or an UNKNOWN, rule/answer/consequence coverage, and the leak scan over every presented field"
gate_out_of_scope "whether a case is well chosen and whether the rule named is the one a reviewer would name; this gate runs no model and scores no answer, and the leak scan catches tokens and imperative constructions rather than paraphrase"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was measured"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$CORE" ]; then
  gate_warn "the measurement core is missing: $CORE"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

out="$(PYTHONSAFEPATH=1 python3 "$CORE" "$ROOT" 2>&1)"; rc=$?
while IFS= read -r line; do
  case "$line" in
    FINDING\ *)    gate_fail "${line#FINDING }" ;;
    UNMEASURED\ *) gate_warn "${line#UNMEASURED }" ;;
    *)             [ -n "$line" ] && gate_info "$line" ;;
  esac
done <<< "$out"

case "$rc" in
  0) gate_ok "every consequence in the key is the one the table forces, the seal matches, coverage holds, and no case carries its own answer" ;;
  1) : ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac
gate_verdict "$rc"
exit "$rc"
