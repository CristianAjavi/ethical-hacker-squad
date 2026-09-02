#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-crash-is-not-a-red.sh — a gate that fell over may not report a failure.
#
# WHY IT EXISTS
#   This repository's exit contract has three values on purpose: 0 measured and
#   clean, 1 measured and FAILS, 2 COULD NOT MEASURE and never a pass. python
#   exits 1 on an unhandled exception. So a wrapper whose rc mapping reads
#
#       case "$rc" in
#         0) gate_ok "..." ;;
#         1) : ;;                      # <- a crash lands here
#         *) rc="$GATE_UNMEASURABLE" ;;
#       esac
#
#   prints a confident red about a tree its core never opened. The two states
#   the contract exists to separate were merged by the one arm nobody looked at.
#
#   MEASURED 2026-09-01: `raise RuntimeError` prepended to each python core, one
#   gate at a time, reading the verdict. ELEVEN of the thirteen python-backed
#   gates said "1 (measured, FAILS)". Only gate-governance-contract.sh and
#   gate-bench-index.sh survived, and by a different route: both run a fixture
#   battery first, and a crash fails the battery, which is already rc 2.
#
#   The fix is `gate_core_rc` in lib/common.sh, which tells them apart by the
#   only thing that separates them: A REAL FAILURE NAMES ITS FINDINGS. Silence
#   at rc 1 is a crash. This gate is what keeps the twelfth wrapper, written
#   next month, from reintroducing the same arm.
#
# WHAT IT MEASURES
#   Every gate in `run-all.sh --list` that invokes python3 AND maps `case "$rc"`
#   must route the 1 arm through `gate_core_rc`. Two ways to get it wrong are
#   named apart: an arm that swallows rc 1 silently, and an arm that assigns
#   a verdict without consulting the finding count.
#
# WHAT IT DOES NOT MEASURE
#   Whether the core is right, whether its findings are real, or whether a gate
#   with no python core has the same hole in some other language. It reads the
#   ONE shape that has already failed eleven times in this tree.
#
# EXIT CODES: 0 measured fine · 1 measured FAILS · 2 could not measure.
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

GATES_DIR="$HERE"
INVENTORY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --gates-dir) GATES_DIR="${2:-}"; shift 2 ;;
    --inventory) INVENTORY="${2:-}"; shift 2 ;;
    --quiet)     QUIET=1; shift ;;
    -h|--help)   sed -n '2,40p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done
QUIET="${QUIET:-0}"

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t gatecrash)"
trap 'rm -rf "$TMP"' EXIT

# audit <gates-dir> <inventory-or-empty> <out> -> 0 | 1 | 2
# Both inputs are PARAMETERS. The self-test below runs this same function over
# throwaway directories, so nothing here may read a global.
audit() {
  local dir="$1" inv_file="$2" out="$3"
  local inv="$TMP/inv.$$" g checked=0 backed=0
  : > "$out"

  if [ -z "$dir" ] || [ ! -d "$dir" ]; then
    printf 'UNMEAS|the gates directory does not exist: %s\n' "$dir" >> "$out"; return 2
  fi
  if [ -n "$inv_file" ]; then
    [ -r "$inv_file" ] || { printf 'UNMEAS|the inventory is unreadable: %s\n' "$inv_file" >> "$out"; return 2; }
    sed -e 's/^· //' -e 's/ .*$//' "$inv_file" | grep -E '^gate-.*\.sh$' | LC_ALL=C sort -u > "$inv"
  else
    [ -x "$dir/run-all.sh" ] || { printf 'UNMEAS|no runner in %s and no --inventory given\n' "$dir" >> "$out"; return 2; }
    "$dir/run-all.sh" --list 2>/dev/null | sed -e 's/^· //' -e 's/ .*$//' \
      | grep -E '^gate-.*\.sh$' | LC_ALL=C sort -u > "$inv"
  fi
  [ -s "$inv" ] || { printf 'UNMEAS|the inventory named no gate, so nothing was inspected\n' >> "$out"; return 2; }

  while IFS= read -r g; do
    [ -n "$g" ] || continue
    [ -f "$dir/$g" ] || { printf 'UNMEAS|%s is in the inventory and not on disk\n' "$g" >> "$out"; continue; }
    grep -q 'python3' "$dir/$g" || continue
    grep -qE '^case "\$rc" in' "$dir/$g" || continue
    checked=$((checked + 1))
    if grep -q 'gate_core_rc' "$dir/$g"; then
      backed=$((backed + 1)); continue
    fi
    if grep -qE '^\s+1\)\s*:\s*;;' "$dir/$g"; then
      printf 'BLIND|%s|its rc mapping swallows 1 with `1) : ;;`, so an unhandled exception in its core is announced as a measured failure\n' "$g" >> "$out"
    else
      printf 'BLIND|%s|it maps `case "$rc"` over a python core without gate_core_rc, so nothing separates a crash from a red\n' "$g" >> "$out"
    fi
  done < "$inv"

  printf 'STAT|inspected|%d\n' "$checked" >> "$out"
  printf 'STAT|guarded|%d\n'   "$backed"  >> "$out"
  rm -f "$inv"

  grep -q '^UNMEAS|' "$out" && return 2
  # A gate that inspected nothing has not passed; it has not run. This arm is
  # reachable: point --gates-dir at a tree of gates that never call python.
  if [ "$checked" -eq 0 ]; then
    printf 'UNMEAS|not one gate in the inventory runs a python core behind a `case "$rc"` mapping, so this gate compared nothing; either the wrappers changed shape or this check stopped recognising them\n' >> "$out"
    return 2
  fi
  grep -q '^BLIND|' "$out" && return 1
  return 0
}

# --- self-test: three throwaway gate directories, one per verdict.
self_test() {
  local ok=1 d out rc
  out="$TMP/st.out"
  # The fixture bodies are ASSEMBLED, never spelled out. This gate inspects every
  # gate in the inventory, and it is a gate: written literally, its own fixtures
  # would make it match its own rule and then satisfy it, and it would pass on
  # the presence of its test data rather than on anything true. Split here, it
  # correctly falls out of its own scope - it has no python core.
  local PY3="pyt""hon3" GUARD="gate_""core_rc"
  mk() {  # <dir> <name> <1-arm>
    mkdir -p "$1"
    { printf '#!/usr/bin/env bash\n'
      printf 'out="$(%s -c pass)"; rc=$?\n' "$PY3"
      printf 'case "$rc" in\n  0) : ;;\n'
      printf '%s' "$3"
      printf '  *) rc=2 ;;\nesac\n'
    } > "$1/$2"
    printf '%s\n' "$2" >> "$1/inventory.txt"
  }

  d="$TMP/good"; mk "$d/gates" gate-a.sh "  1) $GUARD 1; rc=\"\$GATE_RC\" ;;
"
  rc=0; audit "$d/gates" "$d/gates/inventory.txt" "$out" || rc=$?
  [ "$rc" -eq 0 ] || { gate_warn "POSITIVE self-test failed: a guarded wrapper should pass and gave $rc"; sed 's/^/        /' "$out"; ok=0; }

  d="$TMP/bad"; mk "$d/gates" gate-b.sh '  1) : ;;
'
  rc=0; audit "$d/gates" "$d/gates/inventory.txt" "$out" || rc=$?
  { [ "$rc" -eq 1 ] && grep -q '^BLIND|gate-b.sh|its rc mapping swallows' "$out"; } \
    || { gate_warn "NEGATIVE self-test failed: `1) : ;;` should FAIL (1) and gave $rc"; sed 's/^/        /' "$out"; ok=0; }

  # the other way to get it wrong: an arm that decides without the finding count
  d="$TMP/bad2"; mk "$d/gates" gate-c.sh '  1) rc=1 ;;
'
  rc=0; audit "$d/gates" "$d/gates/inventory.txt" "$out" || rc=$?
  { [ "$rc" -eq 1 ] && grep -q '^BLIND|gate-c.sh|it maps' "$out"; } \
    || { gate_warn "NEGATIVE self-test failed: an unguarded mapping should FAIL (1) and gave $rc"; sed 's/^/        /' "$out"; ok=0; }

  # could-not-measure: a gate directory whose gates never touch python
  d="$TMP/unmeas"; mkdir -p "$d/gates"
  printf '#!/usr/bin/env bash\necho nothing to run here\n' > "$d/gates/gate-d.sh"
  printf 'gate-d.sh\n' > "$d/gates/inventory.txt"
  rc=0; audit "$d/gates" "$d/gates/inventory.txt" "$out" || rc=$?
  { [ "$rc" -eq 2 ] && grep -q 'compared nothing' "$out"; } \
    || { gate_warn "self-test failed: a directory with no python core should be UNMEASURABLE (2) and gave $rc"; sed 's/^/        /' "$out"; ok=0; }

  # could-not-measure: a directory that is not there, and an unreadable inventory
  rc=0; audit "$TMP/nope" "" "$out" || rc=$?
  [ "$rc" -eq 2 ] || { gate_warn "self-test failed: a missing gates directory should be 2 and gave $rc"; ok=0; }
  rc=0; audit "$TMP/good/gates" "$TMP/nope/inventory.txt" "$out" || rc=$?
  [ "$rc" -eq 2 ] || { gate_warn "self-test failed: an unreadable inventory should be 2 and gave $rc"; ok=0; }

  [ "$ok" -eq 1 ] && return 0
  return 2
}

gate_header "crash-is-not-a-red (a gate that fell over may not report a failure)"
gate_scope "every gate that runs a python core behind a \`case \"\$rc\"\` mapping routes the 1 arm through \`gate_core_rc\`, so an unhandled exception is COULD NOT MEASURE and not a red"
gate_out_of_scope "whether the core is right, whether its findings are real, and whether a gate with no python core has the same hole in another language"

if [ "${GATE_SELFTEST:-1}" != "0" ]; then
  if ! self_test; then
    gate_warn "the gate does not pass its own self-test; any result over the repository would be indefensible"
    gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
  fi
  gate_info "self-test passed: guarded, both unguarded shapes, and three could-not-measure arms"
fi

OUT="$TMP/audit.out"
rc=0; audit "$GATES_DIR" "$INVENTORY" "$OUT" || rc=$?
while IFS='|' read -r kind a b; do
  case "$kind" in
    BLIND)  gate_fail "$a $b" ;;
    UNMEAS) gate_warn "$a" ;;
    STAT)   [ "$QUIET" = 1 ] || gate_info "$a: $b" ;;
  esac
done < "$OUT"

# This gate matches its own rule - its docstring and its detection line both
# carry the word - and it obeys it rather than excusing itself. `audit` returns
# 1 only after writing BLIND lines, which reach gate_fail above; if it ever
# returned 1 having emitted nothing, that would be the crash-shaped bug this
# gate is named after, and 2 is the honest verdict for it.
case "$rc" in
  0) gate_ok "every gate with a python core tells a crash apart from a failure" ;;
  1) gate_core_rc 1; rc="$GATE_RC" ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac
gate_verdict "$rc"
exit "$rc"
