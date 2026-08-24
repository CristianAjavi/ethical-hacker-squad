#!/usr/bin/env bash
# scripts/gh/battery-detects.sh
#
# Asks of every self-test battery the one question the batteries do not ask of
# themselves: DOES IT DETECT ANYTHING?
#
# WHY IT EXISTS
#   gate-negative-proof.sh requires every gate to carry a negative proof, and
#   says out loud that whether the proof is any GOOD is a person's judgement.
#   That gap is not theoretical. Measured on this repository, with the simplest
#   universal mutation there is - replace the gate with `exit 0` - fourteen of
#   fifteen batteries went red and one stayed green: its three cases all
#   asserted rc=0, which a gate that returns 0 unconditionally satisfies. It
#   would have detected the defect it was written for and not that the gate had
#   stopped looking, which is strictly worse.
#
#   Three batteries in one session passed a thing that proved nothing, two of
#   them written the same day by the person adding the rule. A hand-written
#   mutant bank only ever proves what its author thought to break; this is the
#   instrument that does not share the author's blind spot.
#
# THE MUTATION, and why this one
#   `exit 0` is the weakest possible gate: it measures nothing and approves
#   everything. Any battery worth the name must notice. A battery that survives
#   it is not testing its gate, whatever else it does. Stronger mutations
#   (flip a threshold, drop a rule) find more, and they need a per-gate
#   catalogue; this one needs nothing and applies to all of them.
#
# THE CONTROL, which is not optional
#   Each battery is run TWICE: unmutated, where it must be green, and mutated,
#   where it must not. Without the first run a battery that is red for an
#   unrelated reason - a missing tool, a broken fixture - would be scored as
#   "detects", and this gate would hand out credit for a failure it did not
#   cause.
#
# SCOPE
#   Gates with a sibling <gate>.selftest.sh. A gate whose self-test is INLINE
#   cannot be measured this way - replacing the gate removes the test with it -
#   and those are named in the output rather than quietly left out.
#
# WHY IT LIVES IN scripts/gh/ AND NOT IN scripts/gates/
#   run-all.sh discovers by position and not by extension, so a file here would
#   be a gate running in every `gates` job and inside the release verify job.
#   This one runs every battery TWICE - once as a control, once mutated - and
#   that costs minutes, not seconds. Paying it on every pull request, including
#   the ones that touch no gate at all, is how a check gets switched off.
#   It runs in its own workflow, filtered to the paths that can make its answer
#   change: scripts/gates/**.
#
# Exit codes: 0 = every battery detects | 1 = one does not | 2 = could not measure.
#
# Usage:
#   scripts/gh/battery-detects.sh
#   scripts/gh/battery-detects.sh --only gate-tree-delta.sh
#   scripts/gh/battery-detects.sh --list

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/../gates/lib/common.sh"

ROOT="$(cd "${EHS_REPO_ROOT:-$(gate_root)}" && pwd -P)"
ONLY=""
LIST_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY="${2:-}"; shift 2 ;;
    --list) LIST_ONLY=1; shift ;;
    -h|--help) sed -n '2,48p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

gate_header "battery-detects (does the proof prove anything?)"
gate_scope "every gate with a sibling <gate>.selftest.sh: the battery must be GREEN on the gate and RED on a gate replaced by \`exit 0\`"
gate_out_of_scope "gates whose self-test is inline - replacing the gate removes the test with it, so they are named and not measured; and how MUCH a battery detects, which no single mutation can answer"

command -v git >/dev/null 2>&1 || { gate_warn "git is missing: I cannot make a throwaway copy"; gate_verdict 2; exit 2; }
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || { gate_warn "$ROOT is not a git work tree"; gate_verdict 2; exit 2; }

BATTERIES=""
INLINE=""
for st in "$ROOT"/scripts/gates/*.selftest.sh; do
  [ -e "$st" ] || continue
  b="$(basename "$st")"
  [ -z "$ONLY" ] || [ "${b%.selftest.sh}.sh" = "$ONLY" ] || continue
  [ -f "$ROOT/scripts/gates/${b%.selftest.sh}.sh" ] && BATTERIES="$BATTERIES $b"
done
for g in "$ROOT"/scripts/gates/gate-*.sh; do
  case "$g" in *.selftest.sh) continue ;; esac
  b="$(basename "$g")"
  [ -f "$ROOT/scripts/gates/${b%.sh}.selftest.sh" ] && continue
  grep -qE '\$\{GATE_SELFTEST[:}]' "$g" 2>/dev/null && INLINE="$INLINE $b"
done

[ -n "$BATTERIES" ] || { gate_warn "no sibling battery found to measure"; gate_verdict 2; exit 2; }

if [ -n "$INLINE" ]; then
  for b in $INLINE; do gate_info "not measurable this way (inline self-test): $b"; done
fi
if [ "$LIST_ONLY" -eq 1 ]; then
  for b in $BATTERIES; do gate_log "  $b"; done
  exit 0
fi

WT="$(mktemp -d "${TMPDIR:-/tmp}/ehs-battery-detects-XXXXXX")"
cleanup() { git -C "$ROOT" worktree remove --force "$WT/tree" >/dev/null 2>&1 || true; rm -rf "$WT"; }
trap cleanup EXIT
git -C "$ROOT" worktree add --detach "$WT/tree" HEAD >/dev/null 2>&1 || {
  gate_warn "I could not create a throwaway worktree: nothing is mutated in place, so there is nothing to measure"
  gate_verdict 2; exit 2; }

n_ok=0; n_hollow=0; n_unmeas=0
for b in $BATTERIES; do
  gate="${b%.selftest.sh}.sh"
  st="$WT/tree/scripts/gates/$b"
  gt="$WT/tree/scripts/gates/$gate"

  control=0; ( cd "$WT/tree" && bash "$st" </dev/null >/dev/null 2>&1 ) || control=$?
  if [ "$control" -ne 0 ]; then
    gate_warn "$b is not green on its own gate (rc=$control): I cannot tell a battery that detects from one that is simply broken"
    n_unmeas=$((n_unmeas + 1))
    continue
  fi

  cp "$gt" "$WT/orig" 2>/dev/null || { gate_warn "$gate could not be read"; n_unmeas=$((n_unmeas+1)); continue; }
  printf '#!/usr/bin/env bash\n# mutant: measures nothing, approves everything\nexit 0\n' > "$gt"
  chmod +x "$gt"
  mutated=0; ( cd "$WT/tree" && bash "$st" </dev/null >/dev/null 2>&1 ) || mutated=$?
  cp "$WT/orig" "$gt"; chmod +x "$gt"

  if [ "$mutated" -ne 0 ]; then
    gate_info "$b detects a hollow $gate (rc=$mutated)"
    n_ok=$((n_ok + 1))
  else
    gate_fail "$b is GREEN against a $gate replaced by \`exit 0\`: it passes a gate that measures nothing, so it is not testing that gate"
    n_hollow=$((n_hollow + 1))
  fi
done

gate_info "batteries measured: $((n_ok + n_hollow)) · detect: $n_ok · hollow: $n_hollow · could not measure: $n_unmeas"
if [ "$n_hollow" -gt 0 ]; then gate_verdict 1; exit 1; fi
if [ "$n_unmeas" -gt 0 ]; then gate_verdict 2; exit 2; fi
gate_ok "every sibling battery goes red when its gate stops measuring"
gate_verdict 0
exit 0
