#!/usr/bin/env bash
# scripts/gates/gate-discovery-controls.sh
#
# The sweep that asks whether the competitor list is still the field has to be
# able to see.
#
# WHY IT EXISTS
#   `competitive-discovery.sh` exits 0 when every candidate its queries returned
#   is named in `docs/competitive-baseline.json`. Measured on 2026-09-10: the
#   five text queries it had returned 39 distinct repositories, and not one of
#   them was `trailofbits/skills` (7,033 stars, a security firm's own Claude Code
#   skills for vulnerability detection and audit workflows) or
#   `cloudflare/security-audit-skill` (3,267 stars, MIT, a multi-phase audit
#   skill). `gh search repos` ranks on name and description, so a product owned
#   by an organisation and named `skills` is unreachable by every phrasing of
#   this lane. The previous run had exited 0. The sentence it printed was true
#   about the candidates it saw and false about the field.
#
#   The repair in the script is `discovery.controls`: known positives, already
#   resolved in the same file, that the sweep must return, and rc 2 when one
#   comes back missing. This gate is what stops that repair from being emptied
#   out later without anyone noticing - a control block that is deleted, or
#   pointed at something the file has never resolved, or wired to a query that
#   no longer exists, turns the check back into an instrument that cannot tell
#   an empty lane from a blind sweep, and nothing else would go red.
#
# WHAT IT MEASURES
#   Offline, from the baseline alone:
#     C1  at least one control is declared      - a probe with no controls is blind
#     C2  every control is already resolved in `products` or `declined`
#                                               - an unresolved name is a candidate,
#                                                 not a control
#     C3  every control names a `found_by` that matches a declared query
#                                               - a control wired to nothing cannot
#                                                 tell you which query to repair
#     C4  no control is this repository itself  - the sweep skips self by design,
#                                                 so such a control can never be seen
#     C5  no control is declared twice          - a duplicate inflates the count
#                                                 the run prints
#     C6  max_candidates >= sweeps x per_query  - if the cap can bite before the
#                                                 queries are exhausted, the run
#                                                 stops early and the controls it
#                                                 never reached read as missing
#
# WHAT IT DOES NOT MEASURE
#   Whether any query actually returns any control today - that needs the network
#   and it is `competitive-discovery.sh`'s own rc 2, measured against live search
#   results. Nor whether a control is a good choice, nor anything about a
#   competitor's quality. A green here says the probe is wired; it does not say
#   the sweep can see.
#
# Exit codes: 0 = measured and fine | 1 = measured and fails | 2 = could not measure.
#
# Usage:
#   scripts/gates/gate-discovery-controls.sh
#   scripts/gates/gate-discovery-controls.sh --baseline path/to/competitive-baseline.json
#
# Environment variables:
#   EHS_COMPETITIVE_BASELINE   path to the baseline, overriding the default
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
BASELINE="${EHS_COMPETITIVE_BASELINE:-$ROOT/docs/competitive-baseline.json}"

while [ $# -gt 0 ]; do
  case "$1" in
    --baseline) BASELINE="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

gate_header "discovery-controls (the sweep that asks if the list is still the field can see)"
gate_scope "the controls, the queries they name and the cap, in $(basename "$BASELINE")"
gate_out_of_scope "whether a live search returns them - that is competitive-discovery.sh's own rc 2"

command -v jq >/dev/null 2>&1 || { gate_warn "jq is not installed"; gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"; }
[ -r "$BASELINE" ] || { gate_warn "cannot read $BASELINE"; gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"; }
jq -e . "$BASELINE" >/dev/null 2>&1 || { gate_warn "$BASELINE is not valid JSON"; gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"; }
jq -e '.discovery' "$BASELINE" >/dev/null 2>&1 || { gate_warn "$BASELINE declares no discovery block, so there is no sweep to check"; gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"; }

rc=0

# C1 -------------------------------------------------------------------------
n_controls="$(jq -r '[.discovery.controls[]?] | length' "$BASELINE")"
if [ "$n_controls" -eq 0 ]; then
  gate_fail "no control is declared: the sweep cannot tell an empty lane from a blind instrument"
  gate_log "        Add discovery.controls: products already resolved in this file that the"
  gate_log "        queries must return. A zero from a blind instrument is not a zero."
  rc=1
else
  gate_info "$n_controls control(s) declared"
fi

resolved="$(jq -r '[(.products[]?.repo), (.declined[]?.repo)] | .[] | ascii_downcase' "$BASELINE" | sort -u)"
self_repo="$(jq -r '.discovery.self // "" | ascii_downcase' "$BASELINE")"
queries="$( { jq -r '.discovery.queries[]?' "$BASELINE"; \
              jq -r '.discovery.topic_queries[]? | "\(.term) +topic:\(.topic)"' "$BASELINE"; } )"

seen_controls=""
while IFS=$'\t' read -r repo found_by; do
  [ -n "$repo" ] || continue
  low="$(printf '%s' "$repo" | tr 'A-Z' 'a-z')"

  # C2
  if ! printf '%s\n' "$resolved" | grep -Fxq -- "$low"; then
    gate_fail "control $repo is not named in products or declined: that is an unresolved candidate, not a control"
    rc=1
  fi

  # C3
  if [ -z "$found_by" ] || [ "$found_by" = "null" ]; then
    gate_fail "control $repo declares no found_by: nothing says which query to repair when it goes missing"
    rc=1
  elif ! printf '%s\n' "$queries" | grep -Fxq -- "$found_by"; then
    gate_fail "control $repo names found_by '$found_by', which is not one of the declared queries"
    rc=1
  fi

  # C4
  if [ -n "$self_repo" ] && [ "$low" = "$self_repo" ]; then
    gate_fail "control $repo is this repository: the sweep skips self, so this control can never be seen"
    rc=1
  fi

  # C5
  case " $seen_controls " in
    *" $low "*) gate_fail "control $repo is declared twice: a duplicate inflates the count the run prints"; rc=1 ;;
    *) seen_controls="$seen_controls $low" ;;
  esac
done < <(jq -r '.discovery.controls[]? | "\(.repo)\t\(.found_by // "")"' "$BASELINE")

# C6 -------------------------------------------------------------------------
n_text="$(jq -r '[.discovery.queries[]?] | length' "$BASELINE")"
n_topic="$(jq -r '[.discovery.topic_queries[]?] | length' "$BASELINE")"
per_query="$(jq -r '.discovery.per_query // 8' "$BASELINE")"
cap="$(jq -r '.discovery.max_candidates // 30' "$BASELINE")"
reach=$(( (n_text + n_topic) * per_query ))
if [ "$cap" -lt "$reach" ]; then
  gate_fail "the cap is $cap and $((n_text + n_topic)) sweeps x $per_query per query can return $reach: the run can stop before the queries are exhausted"
  gate_log "        A capped run exits 2 without having reached every control, so a missing"
  gate_log "        control and an unfinished sweep become the same event. Raise max_candidates"
  gate_log "        to at least $reach, which is the arithmetic written in this file."
  rc=1
else
  gate_info "cap $cap >= $((n_text + n_topic)) sweeps x $per_query = $reach, so the cap cannot bite first"
fi

case "$rc" in
  0) gate_ok "every control is resolved, wired to a declared query, and reachable before the cap"
     gate_verdict "$GATE_OK"; exit "$GATE_OK" ;;
  *) gate_verdict "$GATE_FAIL"; exit "$GATE_FAIL" ;;
esac
