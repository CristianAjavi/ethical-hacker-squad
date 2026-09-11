#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-pack-routing.sh — the procedure that exists and cannot be reached.
#
# WHY IT EXISTS
#   This corpus is reachable only through prose. A specialist opens the pack
#   file its agent definition names, and opens a sibling only because the entry
#   file's header says the sibling is there and says what is in it. Nothing
#   scans the directory at runtime.
#
#   So when a pack was split and the two routers kept the old range, nine
#   procedures went dark: defined, numbered, traced, counted, unique, and
#   unreachable. Every other gate stayed green, correctly - the file was
#   present, the identifiers were unique, the counts matched, the traceability
#   table had its row. None of them asks whether anyone is ever sent there.
#   That is the hole this closes, and it was found by hand on 2026-09-10 after
#   the split had been in the tree for weeks.
#
# WHAT IT MEASURES
#   For every pack with more than one file, both of its routers - the entry
#   file's header and the `First actions` section of its agent - against what
#   the sibling files actually define as `### <ID>` headings:
#     TABLE    the pack table names a file that is not in knowledge/
#     SHAPE    a pack whose files share no stem: which one is the entry?
#     ROUTER   a router with no region to read - it routes nowhere
#     UNNAMED  a router that never names a sibling: everything in it is dark
#     MISSING  a router that names the file but not some of its procedures
#     PHANTOM  a router that sends a reader to the pack for an id no file of
#              the pack defines - a range that outlived its last procedure
#
# USAGE
#   scripts/gates/gate-pack-routing.sh            # this repository
#   scripts/gates/gate-pack-routing.sh --tree DIR # a fixture tree (self-test)
#
# WHAT IT DOES NOT MEASURE
#   Whether the procedure is any good, or whether a router that names every id
#   does so in a sentence a human would follow: this measures reachability, not
#   quality. It cannot see a route that exists in some third document - the two
#   routers above are the two the agents are built to use. And it does not
#   catch two siblings whose ranges are swapped with each other, on purpose:
#   see WHY PHANTOM IS THE WEAKER HALF in lib/pack_routing.py, where two
#   attempts at guessing which half of a sentence belongs to which file both
#   ended up accusing a correct router.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, no pack table, a table that parses to zero rows).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
CORE="$HERE/lib/pack_routing.py"

while [ $# -gt 0 ]; do
  case "$1" in
    --tree) shift; [ $# -gt 0 ] || { gate_warn "--tree needs a path"; exit "$GATE_UNMEASURABLE"; }
            ROOT="$1" ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
  shift
done

gate_header "pack-routing (can anyone be sent to the procedure?)"
gate_scope "both routers of every multi-file pack, against the ids its sibling files define"
gate_out_of_scope "whether the procedure is any good - this measures reachability, not quality"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was measured"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$CORE" ]; then
  gate_warn "the measurement core is missing: $CORE"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

out="$(python3 "$CORE" "$ROOT" 2>&1)"; rc=$?
while IFS= read -r line; do
  case "$line" in
    TABLE*|SHAPE*|ROUTER*|UNNAMED*|MISSING*|PHANTOM*) gate_fail "$(printf '%s' "$line" | tr '\t' ' ')" ;;
    UNMEASURABLE*) gate_warn "$(printf '%s' "$line" | tr '\t' ' ')" ;;
    CHECKED*)      gate_info "$(printf '%s' "$line" | tr '\t' ' ')" ;;
    "")            : ;;
    *)             gate_info "$line" ;;
  esac
done <<< "$out"

case "$rc" in
  0) gate_ok "every sibling file is named by both of its routers, with the ids it defines" ;;
  1) : ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac
gate_verdict "$rc"
exit "$rc"
