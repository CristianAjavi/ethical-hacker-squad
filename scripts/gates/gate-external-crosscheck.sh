#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-external-crosscheck.sh - the number an OUTSIDE tool scored on this bench
# still reproduces from the raw output that tool emitted.
#
# WHY IT EXISTS
#   bench/ground-truth.json has been scored against this project's own runs and
#   against nothing else. Eighteen blinded measurements compare this corpus to
#   rivals on rubrics; not one of them ever took a third-party scanner's RAW
#   output and crossed it against the answer key by file and line. The plumbing
#   was the only thing missing - score.py has matched by path and span all
#   along - and plumbing that exists once and is never re-run is a screenshot.
#
#   So the raw output of a pinned external tool is committed under
#   bench/external/<tool>-<date>/, with the numbers it scored, and this gate
#   re-derives those numbers on every run. A silent change in the adapter, in
#   the answer key, or in the raw files moves one of them and turns this red.
#
# WHAT IT MEASURES
#   1. Every raw file still adapts and still scores to the SAME recorded
#      numbers: raw in, emitted, unmapped, detected ids, decoys reported,
#      unlabelled and recall, arm by arm.
#   2. The gate counts the raw records ITSELF, without the adapter, and compares.
#      An adapter that drops a finding quietly reports a smaller number at both
#      ends, and every check derived from it agrees with the smaller number.
#   3. The raw files still hash to what provenance recorded, so an edit that
#      does not happen to move a score is caught too.
#   4. Provenance is complete: tool, repository, a 40-hex pinned commit, the
#      version the tool reports, the command, the scan roots, the date, the
#      runner OS, and what was NOT exercised. A scan root that has been renamed
#      or deleted is a measured FAILURE of the record and exits 1 naming the
#      root that moved - never a 2, which is what an earlier version of this
#      gate did by handing the moved root to the adapter and inheriting its
#      refusal. A plain directory rename is the commonest way this record goes
#      stale, and answering it with "could not measure" loses a verdict the
#      gate already had.
#   5. No committed file under bench/external/**/ carries an absolute path of
#      the machine that produced it.
#   6. The adapter can still say ONE - a SARIF document in, one finding out -
#      still refuses to say ZERO blind (an unrecognised shape, and a bare empty
#      array, must both come back as 2), and still NAMES a finding whose path is
#      not in this checkout instead of dropping it. All three run here, not only
#      in the battery, because a gate pinning a number is worth exactly what the
#      instrument behind it is worth - and the silent drop is the one failure
#      that moves no number, so the probe reads the adapter's text too.
#
# WHAT IT DOES NOT MEASURE, and will not pretend to
#   * SEMANTIC agreement. File-and-line agreement is LOCATION agreement. A
#     foreign tool that lands on the correct line for the wrong reason counts as
#     a hit here, and one that describes the right defect at the wrong line
#     counts as a miss. This limit is the price of a scorer that no one has to
#     adjudicate, and it is declared rather than hidden.
#   * Whether the external tool is any good. The recorded run exercised its
#     deterministic engine only: its orchestration of third-party scanners could
#     not run (none is installed here) and its adversarial AI verification was
#     not run (it needs a model). The numbers are its engine pre-verification,
#     which cuts both ways - candidates its verifier would discard are counted
#     here as decoys reported. provenance.json says so in full.
#   * Whether the recorded number is FAIR. Nothing here judges the number
#     against a threshold. This gate keeps it honest; what it is worth is a
#     reader's call, which is the whole reason the raw output is committed.
#   * Anything about a tool nobody recorded. A format the adapter has never
#     seen comes back as 2 from the adapter and 2 from here - never a clean zero.
#
# EXIT CODES (repo contract): 0 measured fine | 1 measured FAILS | 2 could not
# measure (no python3, missing adapter or scorer, a record that will not parse).
#
# Usage:
#   scripts/gates/gate-external-crosscheck.sh
#   scripts/gates/gate-external-crosscheck.sh --root DIR
#
# Cost: about one second. It is not deferred and needs no lane of its own.
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/external_crosscheck.py"

while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,72p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

gate_header "external-crosscheck (an outside tool against this bench, by file and line)"
gate_scope "every recorded run under bench/external/**: its raw output re-adapted and re-scored against bench/ground-truth.json, its checksums, its provenance, and the adapter answering 2 rather than 0 to a shape it does not know"
gate_out_of_scope "whether a location hit is a SEMANTIC hit, whether the external tool is any good, and whether the recorded number is a fair reading of it"

command -v python3 >/dev/null 2>&1 || {
  gate_warn "python3 is not installed"; gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"; }
[ -f "$CORE" ] || {
  gate_warn "the checker $CORE is missing"; gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"; }
[ -d "$ROOT" ] || {
  gate_warn "$ROOT is not a directory"; gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"; }

# `|| rc=$?`, never `cmd; rc=$?` behind a redirect and never a pipe into head:
# under `set -e` in CI the first dies mute and the second reports the rc of the
# last stage of the pipe. This repository has been burned by both.
rc=0
out="$(PYTHONSAFEPATH=1 python3 "$CORE" --root "$ROOT" 2>&1)" || rc=$?

printf '%s\n' "$out"

case "$rc" in
  0) gate_ok "the recorded external numbers still reproduce from the raw output" ;;
  1) gate_fail "a recorded external number, checksum or provenance field no longer holds" ;;
  *) rc="$GATE_UNMEASURABLE"; gate_warn "the cross-check could not be performed" ;;
esac
gate_verdict "$rc"
exit "$rc"
