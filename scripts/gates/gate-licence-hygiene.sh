#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-licence-hygiene.sh — G5, anti-verbatim.
#
# WHY IT EXISTS
#   The repository is MIT and most of what it cites is not: OWASP is CC BY-SA,
#   the CIS Controls are non-commercial with no derivatives, several vendor
#   guides are proprietary. `NOTICE.md` and the loading map both stated that no
#   third-party text is copied and that this is "enforced in CI" - and nothing
#   enforced it. A claim of enforcement with no gate behind it is the same
#   failure this corpus teaches auditors to report as `UNKNOWN`.
#
# WHAT IT MEASURES
#   1. a quoted span longer than fifteen words near the name of an external
#      owner, anywhere under skills/ or docs/;
#   2. an n-gram denylist stored as hashes, so the list forbidding a phrase is
#      not itself a copy of it - its size is printed on every run;
#   3. every identifier-family OWNER the corpus cites has a NOTICE.md section;
#   4. every allowlisted source records id, name, url, licence and reuse.
#
# WHAT IT DOES NOT MEASURE
#   Paraphrase. It catches pasting - a control description, a checklist, a
#   clause - and a green here is not a plagiarism clearance. It says so on
#   every run rather than letting a green imply it.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, a data file that will not parse).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"
ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/licence_hygiene.py"

gate_header "licence-hygiene (no third-party text travels under our MIT)"
gate_scope "quoted spans near an attributed source under skills/ and docs/, the phrase denylist, NOTICE.md against the identifier owners cited, and the source allowlist"
gate_out_of_scope "paraphrase: this gate catches pasting, not derivation"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was checked, which is not the same as nothing being there"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$CORE" ]; then
  gate_warn "the measurement core is missing: $CORE"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

out="$(python3 "$CORE" "$ROOT" 2>&1)"; rc=$?
while IFS= read -r line; do
  case "$line" in
    FINDING\ *)      gate_fail "${line#FINDING }" ;;
    UNMEASURED\ *)   gate_warn "${line#UNMEASURED }" ;;
    NOT\ MEASURED*)  gate_out_of_scope "${line#NOT MEASURED: }" ;;
    *)               gate_info "$line" ;;
  esac
done <<< "$out"

case "$rc" in
  0) gate_ok "no attributed verbatim span, every cited owner attributed, every allowlisted source licensed" ;;
  1) : ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac
gate_verdict "$rc"
exit "$rc"
