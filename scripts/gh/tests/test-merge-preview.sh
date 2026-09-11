#!/usr/bin/env bash
# Tests scripts/gh/merge-preview.sh on throwaway repositories built here.
#
# The tool exists because "green on a branch" and "green on the merge" are two
# different measurements and CI only ever runs the first. Case
# `combination-fails-though-each-branch-is-green` is TODAY'S REAL DEFECT in
# miniature: one branch adds a check that reads a file, another renames that
# file, each is green alone, and the merge is not.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

SP="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SP/../../.." && pwd)"
TOOL_REL="scripts/gh/merge-preview.sh"
[ -f "$ROOT/$TOOL_REL" ] || { echo "  COULD NOT MEASURE: $TOOL_REL is missing (rc 2)"; exit 2; }
command -v git >/dev/null 2>&1 || { echo "  COULD NOT MEASURE: git is missing (rc 2)"; exit 2; }

LAB="$(mktemp -d)"; trap 'rm -rf "$LAB"' EXIT
pass=0; fail=0; unmeasured=0
G() { git -C "$1" -c user.email=t@e -c user.name=t "${@:2}"; }

# A repository with the two things merge-preview runs: a gate runner and a
# battery. Both are stubs - what is under test is the COMBINATION logic, not
# anybody's gates.
build_repo() {
  local d="$1"
  mkdir -p "$d/scripts/gates" "$d/scripts/gh/tests" "$d/data"
  cp "$ROOT/$TOOL_REL" "$d/scripts/gh/merge-preview.sh"
  cat > "$d/scripts/gates/run-all.sh" <<'RA'
#!/usr/bin/env bash
# Stub runner. It prints the summary line the plain mode greps for AND the
# per-name GATE SUMMARY block that --chain reads, because a harness that speaks
# a different language than the real runner tests the harness, not the tool:
# the first draft of this stub printed only the count line, --chain found no
# names at all, and every chain case came back "could not measure" on trees
# where nothing was wrong.
#
# It speaks --only for the same reason. The real runner takes a glob matched
# against the file NAME and narrows the run to it - measured on this repository
# on 2026-09-11: 1.8 s for one gate against 4m08s for the pass - and the
# confirmation step depends on that narrowing being real. A stub that ignored
# --only would have re-run every gate, and a confirmation that re-measures the
# whole POINT instead of the one control it doubts would have passed every case
# here while costing a full suite per transition in the field.
#
# Discovery is RECURSIVE and reports the BASENAME, like the real one. That is
# not decoration either: it is how two gates in different directories come to
# report under a single name, which is the case where a second measurement
# cannot say which of them moved.
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY="${2:-}"; shift 2 ;;
    --skip) shift 2 ;;
    *) shift ;;
  esac
done
worst=0; lines=""; n=0
while IFS= read -r g; do
  [ -n "$g" ] || continue
  b="$(basename "$g")"
  if [ -n "$ONLY" ]; then
    case "$b" in $ONLY) : ;; *) continue ;; esac
  fi
  n=$((n + 1))
  rc=0; bash "$g" >/dev/null 2>&1 || rc=$?
  case "$rc" in
    0) lines="$lines
OK   $b - measured, no findings" ;;
    2) lines="$lines
UNMEASURABLE $b - COULD NOT MEASURE"; [ "$worst" -eq 1 ] || worst=2 ;;
    *) lines="$lines
FAIL  $b - measured, FAILS"; worst=1 ;;
  esac
done < <(find scripts/gates -type f \( -name '*.selftest.sh' -o -name 'gate-*.sh' \) | LC_ALL=C sort)
echo "===== GATE SUMMARY ====="
echo "discovered: $n | run: $n | green: 1 | FAIL: 0 | UNMEASURABLE: 0"
printf '%s\n' "$lines" | sed '/^$/d'
exit "$worst"
RA
  chmod +x "$d/scripts/gates/run-all.sh"
  printf 'the file the battery reads\n' > "$d/data/needed.txt"
  cat > "$d/scripts/gates/stub.selftest.sh" <<'ST'
#!/usr/bin/env bash
# A battery that depends on a file living outside its own branch.
[ -f data/needed.txt ] || { echo "the file this battery reads is gone"; exit 1; }
exit 0
ST
  chmod +x "$d/scripts/gates/stub.selftest.sh"
  git -C "$d" init -q -b main
  G "$d" add -A; G "$d" commit -qm base
}

# The same repository, but driven by THIS repository's REAL gate runner instead
# of the stub above. A stub can be taught to answer anything; a label that only
# a stub can produce is a label nobody will ever see in the field. run-all.sh
# needs exactly three things to run outside its own tree - lib/common.sh, the
# declared slow-scoped list, and at least one gate - so a faithful harness costs
# three cp and about half a second.
build_real_repo() {
  local d="$1"
  mkdir -p "$d/scripts/gates/lib" "$d/scripts/gates/data" "$d/scripts/gh" "$d/data"
  cp "$ROOT/$TOOL_REL" "$d/scripts/gh/merge-preview.sh"
  cp "$ROOT/scripts/gates/run-all.sh" "$d/scripts/gates/run-all.sh"
  cp "$ROOT/scripts/gates/lib/common.sh" "$d/scripts/gates/lib/common.sh"
  cp "$ROOT/scripts/gates/data/slow-scoped.txt" "$d/scripts/gates/data/slow-scoped.txt"
  chmod +x "$d/scripts/gates/run-all.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$d/scripts/gates/stub.selftest.sh"
  chmod +x "$d/scripts/gates/stub.selftest.sh"
  git -C "$d" init -q -b main
  G "$d" add -A; G "$d" commit -qm base
}

run_tool() {  # <repo> <args...>  -> prints rc
  local d="$1"; shift
  ( cd "$d" && bash "$d/scripts/gh/merge-preview.sh" --base main "$@" >"$LAB/out.txt" 2>&1 ); echo $?
}

res() {  # <label> <got> <want> [needle]
  local label="$1" got="$2" want="$3" needle="${4:-}"
  if [ "$got" = "$want" ] && { [ -z "$needle" ] || grep -qi -- "$needle" "$LAB/out.txt"; }; then
    printf '  PASS  %-52s rc=%s\n' "$label" "$got"; pass=$((pass+1))
  else
    printf '  FAIL  %-52s rc=%s (expected %s)\n' "$label" "$got" "$want"
    sed 's/^/        | /' "$LAB/out.txt" | tail -12; fail=$((fail+1))
  fi
}

echo "== merge-preview.sh on throwaway repositories"

# 1. two branches that merge cleanly and leave a green tree
d="$LAB/clean"; build_repo "$d"
G "$d" checkout -q -b feat/a; printf 'a\n' >> "$d/data/needed.txt"; G "$d" add -A; G "$d" commit -qm a
G "$d" checkout -q main; G "$d" checkout -q -b feat/b; printf 'b\n' > "$d/other.txt"; G "$d" add -A; G "$d" commit -qm b
G "$d" checkout -q main
res "clean combination -> rc 0" "$(run_tool "$d" feat/a feat/b)" 0 "the combination is green"

# 2. TODAY'S DEFECT: each branch green alone, the combination not
d="$LAB/combo"; build_repo "$d"
G "$d" checkout -q -b feat/reader
cat > "$d/scripts/gates/stub.selftest.sh" <<'ST'
#!/usr/bin/env bash
[ -f data/needed.txt ] || { echo "the file this battery reads is gone"; exit 1; }
exit 0
ST
G "$d" add -A; G "$d" commit -qm reader
G "$d" checkout -q main; G "$d" checkout -q -b feat/renamer
G "$d" mv data/needed.txt data/renamed.txt; G "$d" commit -qm renamer
G "$d" checkout -q main
res "each branch green, the combination FAILS -> rc 1" "$(run_tool "$d" feat/reader feat/renamer)" 1 "no single branch would have said so"

# 3. a conflict is reported and NEVER auto-resolved
d="$LAB/conflict"; build_repo "$d"
G "$d" checkout -q -b feat/x; printf 'x\n' > "$d/data/needed.txt"; G "$d" add -A; G "$d" commit -qm x
G "$d" checkout -q main; G "$d" checkout -q -b feat/y; printf 'y\n' > "$d/data/needed.txt"; G "$d" add -A; G "$d" commit -qm y
G "$d" checkout -q main
res "a conflict -> rc 2, reported not resolved" "$(run_tool "$d" feat/x feat/y)" 2 "never auto-resolved"

# 3b. --union: two branches each APPENDING a row to the same table. Keeping both
#     sides is the only resolution anybody would have written by hand, and
#     without it the branch is skipped and measures nothing - which is how the
#     first version of this tool would have missed the defect it was built for.
d="$LAB/union"; build_repo "$d"
printf 'row one\n' > "$d/table.md"; G "$d" add -A; G "$d" commit -qm table
G "$d" checkout -q -b feat/row2; printf 'row two\n' >> "$d/table.md"; G "$d" add -A; G "$d" commit -qm row2
G "$d" checkout -q main; G "$d" checkout -q -b feat/row3; printf 'row three\n' >> "$d/table.md"; G "$d" add -A; G "$d" commit -qm row3
G "$d" checkout -q main
res "append-only conflict, no --union -> rc 2" "$(run_tool "$d" feat/row2 feat/row3)" 2 "CONFLICT"
res "the same, with --union -> rc 0" "$(run_tool "$d" --union feat/row2 feat/row3)" 0 "union"
# The disclosure is not decoration. A union verdict that does not say which files
# it invented a resolution for reads as a verdict about the tree you will ship,
# and it is not one - that misreading already happened once, on this repository.
res "and it says which files it resolved for you" \
    "$(grep -c 'RESOLVED BY UNION' "$LAB/out.txt")" 1
res "and names the file on that very line" \
    "$(grep -c 'RESOLVED BY UNION.*table\.md' "$LAB/out.txt")" 1
# Without --union there is nothing to disclose, and it must not cry wolf.
res "no --union, no disclosure" \
    "$(run_tool "$d" feat/row2 >/dev/null; grep -c 'RESOLVED BY UNION' "$LAB/out.txt")" 0

# 3c. --union on a file with a SHAPE. Two branches each add a key to the same
#     JSON object; keeping both sides leaves a file that does not parse. The
#     tool used to print `merged` for it and then measure the tree, and the
#     gates that read that file failed - a defect manufactured by the
#     resolution, attributed to whichever branch happened to be in the list.
d="$LAB/unionjson"; build_repo "$d"
printf '{\n  "a": 1\n}\n' > "$d/shape.json"; G "$d" add -A; G "$d" commit -qm shape
G "$d" checkout -q -b feat/j2; printf '{\n  "a": 1,\n  "b": 2\n}\n' > "$d/shape.json"
G "$d" add -A; G "$d" commit -qm j2
G "$d" checkout -q main; G "$d" checkout -q -b feat/j3; printf '{\n  "a": 1,\n  "c": 3\n}\n' > "$d/shape.json"
G "$d" add -A; G "$d" commit -qm j3
G "$d" checkout -q main
res "a JSON both sides edited, no --union -> rc 2" "$(run_tool "$d" feat/j2 feat/j3)" 2 "CONFLICT"
res "the same WITH --union -> still rc 2" "$(run_tool "$d" --union feat/j2 feat/j3)" 2 "no longer parses as JSON"
res "and it does not claim to have resolved it" \
    "$(grep -c 'RESOLVED BY UNION.*shape\.json' "$LAB/out.txt")" 0

# 4. a ref that does not exist is not silently skipped
d="$LAB/ghost"; build_repo "$d"
res "a branch that does not exist -> rc 2" "$(run_tool "$d" feat/nowhere)" 2 "does not exist"

# 5. --list prints the plan and measures nothing
d="$LAB/list"; build_repo "$d"
G "$d" checkout -q -b feat/a; G "$d" commit -q --allow-empty -m a; G "$d" checkout -q main
res "--list -> rc 0 and no measurement" "$(run_tool "$d" --list feat/a)" 0 "SKIPPED"

# 6. the skip is DECLARED, never silent
grep -q 'gate-tree-delta' "$LAB/out.txt" \
  && { printf '  PASS  %-52s\n' "the skipped gate is named in the output"; pass=$((pass+1)); } \
  || { printf '  FAIL  %-52s\n' "the skipped gate is NOT named in the output"; fail=$((fail+1)); }

# 7. a combination that leaves NO battery in the tree. `bat_worst` is a worst-of
#    over an empty set, so it stayed 0 and the verdict never moved: a merge that
#    deletes every battery came back green. scripts/run-batteries.sh refuses this
#    same shape and this tool did not.
d="$LAB/nobattery"; build_repo "$d"
G "$d" checkout -q -b feat/drop
G "$d" rm -q scripts/gates/stub.selftest.sh
G "$d" commit -qm "drop the only battery"
G "$d" checkout -q main
res "the merged tree has no battery -> rc 2" "$(run_tool "$d" feat/drop)" 2 "no self-test battery"
# ---------------------------------------------------------------------------
# --chain: the point of it is ATTRIBUTION. A combination that fails is a fact
# nobody can act on; the branch that made it fail is an instruction.
# ---------------------------------------------------------------------------
echo
echo "== --chain: every point measured, every regression attributed"

# C1. a chain where nothing changes verdict
d="$LAB/chain-clean"; build_repo "$d"
G "$d" checkout -q -b chain/a; printf 'a\n' > "$d/a.txt"; G "$d" add -A; G "$d" commit -qm a
G "$d" checkout -q main; G "$d" checkout -q -b chain/b; printf 'b\n' > "$d/b.txt"; G "$d" add -A; G "$d" commit -qm b
G "$d" checkout -q main
res "chain, nothing changes verdict -> rc 0" "$(run_tool "$d" --chain chain/a chain/b)" 0 "holds what the base held"

# C2. THE CASE THIS MODE EXISTS FOR. Two branches, each green on its own, and
#     the SECOND one is the one that breaks the first one's battery. The plain
#     mode would say "the combination fails". Only this one says WHICH.
d="$LAB/chain-blame"; build_repo "$d"
G "$d" checkout -q -b chain/reader
cat > "$d/scripts/gates/stub.selftest.sh" <<'ST'
#!/usr/bin/env bash
[ -f data/needed.txt ] || { echo "the file this battery reads is gone"; exit 1; }
exit 0
ST
G "$d" add -A; G "$d" commit -qm reader
G "$d" checkout -q main; G "$d" checkout -q -b chain/renamer
G "$d" mv data/needed.txt data/renamed.txt; G "$d" commit -qm renamer
G "$d" checkout -q main
res "chain, the second branch breaks it -> rc 1" "$(run_tool "$d" --chain chain/reader chain/renamer)" 1 "BREAKS something"
# Attribution is the deliverable. A verdict that does not name the branch and
# the gate leaves the reader exactly where the plain mode left them.
res "  and the failing branch is named as its own point" \
    "$(grep -c 'point 2: + chain/renamer' "$LAB/out.txt")" 1
res "  and the gate is named, BY NAME, under it" \
    "$(awk '/point 2: \+ chain\/renamer/{s=1} s && /BROKE .*OK->FAIL .*stub\.selftest\.sh/{n++} END{print n+0}' "$LAB/out.txt")" 1
# And it must NOT blame the innocent branch.
res "  and point 1 reports no change" \
    "$(awk '/point 1: \+ chain\/reader/{s=1} /point 2:/{s=0} s && /no gate or battery changed verdict/{n++} END{print n+0}' "$LAB/out.txt")" 1

# C3. a conflict STOPS the chain: every later point would measure a tree that is
#     not the chain, and a regression attributed to the wrong branch is worse
#     than one not attributed at all.
d="$LAB/chain-conflict"; build_repo "$d"
G "$d" checkout -q -b chain/x; printf 'x\n' > "$d/data/needed.txt"; G "$d" add -A; G "$d" commit -qm x
G "$d" checkout -q main; G "$d" checkout -q -b chain/y; printf 'y\n' > "$d/data/needed.txt"; G "$d" add -A; G "$d" commit -qm y
G "$d" checkout -q main; G "$d" checkout -q -b chain/z; printf 'z\n' > "$d/z.txt"; G "$d" add -A; G "$d" commit -qm z
G "$d" checkout -q main
res "chain, a conflict -> rc 2" "$(run_tool "$d" --chain chain/x chain/y chain/z)" 2 "COULD NOT MEASURE the whole chain"
res "  the conflict is reported with its hunk count and lines" \
    "$(grep -c 'needed.txt .* hunk(s) at line(s)' "$LAB/out.txt")" 1
res "  and the branch after it is NOT MEASURED, by name" \
    "$(grep -c 'chain/z : NOT MEASURED' "$LAB/out.txt")" 1

# C4. a base that is ALREADY red. Nothing above it may be blamed for that, and
#     the run has to say so out loud - otherwise the first branch in the chain
#     wears a defect it did not write.
d="$LAB/chain-redbase"; build_repo "$d"
rm -f "$d/data/needed.txt"; G "$d" add -A; G "$d" commit -qm "base is red on purpose"
G "$d" checkout -q -b chain/innocent; printf 'i\n' > "$d/i.txt"; G "$d" add -A; G "$d" commit -qm i
G "$d" checkout -q main
res "chain over a base that is already red -> rc 0" "$(run_tool "$d" --chain chain/innocent)" 0 "the BASE was not all-green"
res "  and nothing is attributed to the branch" \
    "$(grep -c 'BROKE' "$LAB/out.txt")" 0

# C5. a gate that stops being MEASURABLE is the transition that reads most like
#     a pass: nothing prints a FAIL. It cannot leave the verdict at 0.
d="$LAB/chain-unmeas"; build_repo "$d"
G "$d" checkout -q -b chain/blinder
cat > "$d/scripts/gates/stub.selftest.sh" <<'ST'
#!/usr/bin/env bash
echo "I cannot measure this any more"
exit 2
ST
G "$d" add -A; G "$d" commit -qm blinder
G "$d" checkout -q main
res "a gate that goes OK -> UNMEASURABLE -> rc 2, not 0" "$(run_tool "$d" --chain chain/blinder)" 2 "COULD NOT MEASURE the whole chain"

# C6. a gate that VANISHES from the run altogether. Nothing fails; the defence
#     is simply gone.
d="$LAB/chain-vanish"; build_repo "$d"
G "$d" checkout -q -b chain/deleter; G "$d" rm -q "scripts/gates/stub.selftest.sh"; G "$d" commit -qm deleter
G "$d" checkout -q main
res "a gate that VANISHES -> rc 2, not 0" "$(run_tool "$d" --chain chain/deleter)" 2 "COULD NOT MEASURE the whole chain"

# ---------------------------------------------------------------------------
# CONFIRMATION: a transition is measured a SECOND time before a branch is named.
#
# Why these exist. On 2026-09-11 two --chain runs over the same four branches
# both reported gate-budget-ledger.sh going OK->UNMEASURABLE at point 4, and
# five independent gates over that very tree - the gate alone, the gate with
# EHS_BASE_REF set, run-all.sh --only, the gate inside a LINKED worktree, and
# the whole suite at 65 run / 65 green / 0 FAIL / 0 UNMEASURABLE - all came back
# 0. The transition was the machine being saturated. A 2 born of load is
# indistinguishable from a 2 born of the merge, and the report was one printf
# away from reaching the author of a branch that had done nothing.
#
# The two halves have to be measured SEPARATELY, because a confirmation that
# swallowed every transition and one that confirmed every transition both leave
# a battery that only tests one of them green.
# ---------------------------------------------------------------------------
echo
echo "== confirmation: measured twice before anybody is named"

# N1. The break REPRODUCES. The line stays BROKE, the chain stays rc 1, and
#     nothing about the attribution changes. Without this case a confirmation
#     that dropped EVERY transition would pass N2 and look finished.
d="$LAB/chain-confirm"; build_repo "$d"
CALLS="$LAB/witness.calls"; : > "$CALLS"
cat > "$d/scripts/gates/witness.selftest.sh" <<ST
#!/usr/bin/env bash
# Always green. Its only job is to record that the runner ran it, so the COST of
# the confirmation can be measured instead of assumed.
echo x >> "$CALLS"
exit 0
ST
chmod +x "$d/scripts/gates/witness.selftest.sh"
G "$d" add -A; G "$d" commit -qm witness
G "$d" checkout -q -b chain/renamer
G "$d" mv data/needed.txt data/renamed.txt; G "$d" commit -qm renamer
G "$d" checkout -q main
res "the break REPRODUCES -> still BROKE, chain rc 1" "$(run_tool "$d" --chain chain/renamer)" 1 "BREAKS something"
res "  and it says it re-measured and confirmed it" \
    "$(grep -c '1 confirmed, 0 did not' "$LAB/out.txt")" 1
# COST. point 0 and point 1 each run the witness once. A THIRD call would mean
# the confirmation re-measured the whole POINT instead of the one control it
# doubts - on this repository that is 4m08s per transition instead of 1.8 s.
res "  and the confirmation measured ONE control, not the suite" \
    "$(grep -c . "$CALLS")" 2

# N2. The break does NOT reproduce: the very defect above, in miniature. It must
#     not be attributed to the branch, it must not put the chain at 1 or at 2,
#     and it must not be swallowed either - the third of those is the one that
#     looks like success.
d="$LAB/chain-flaky"; build_repo "$d"
G "$d" checkout -q -b chain/flaky
cat > "$d/scripts/gates/stub.selftest.sh" <<'ST'
#!/usr/bin/env bash
# Fails the FIRST time it runs in a given tree and passes afterwards: a gate
# that lost a race, not a gate a merge broke.
c=".flaky.count"
n=$(( $(cat "$c" 2>/dev/null || echo 0) + 1 ))
printf '%s\n' "$n" > "$c"
[ "$n" -eq 1 ] && { echo "first run says broken"; exit 1; }
exit 0
ST
G "$d" add -A; G "$d" commit -qm flaky
G "$d" checkout -q main
res "a break that does NOT reproduce -> rc 0, neither 1 nor 2" "$(run_tool "$d" --chain chain/flaky)" 0 "UNCONFIRMED"
# The two buckets match '^BROKE ...'. That the new label starts with another
# word and so falls in neither is MEASURED here, not read off the source.
res "  and no branch is accused of breaking anything" \
    "$(grep -c '^ *BROKE ' "$LAB/out.txt")" 0
res "  and the verdict names it: an unreproduced transition is not swallowed" \
    "$(grep -c 'NOT CONFIRMED by a second measurement' "$LAB/out.txt")" 1
res "  and the control is named inside that report" \
    "$(awk '/NOT CONFIRMED by a second/{s=1} s && /stub\.selftest\.sh/{n++} END{print n+0}' "$LAB/out.txt")" 1

# N3. The control cannot be measured a second time. Two gates with the same
#     BASENAME in different directories report under ONE name (the runner
#     discovers recursively and reports basename), so the second measurement
#     comes back with two different verdicts under that name and cannot say
#     which of them moved. "I could not check" is not "no": that is a 2.
d="$LAB/chain-twin"; build_repo "$d"
printf '#!/usr/bin/env bash\nexit 0\n' > "$d/scripts/gates/gate-dup.sh"
chmod +x "$d/scripts/gates/gate-dup.sh"
G "$d" add -A; G "$d" commit -qm dup
G "$d" checkout -q -b chain/twin
mkdir -p "$d/scripts/gates/sub"
printf '#!/usr/bin/env bash\nexit 1\n' > "$d/scripts/gates/sub/gate-dup.sh"
chmod +x "$d/scripts/gates/sub/gate-dup.sh"
G "$d" add -A; G "$d" commit -qm twin
G "$d" checkout -q main
res "a confirmation nobody can measure -> rc 2, never a discard" "$(run_tool "$d" --chain chain/twin)" 2 "UNCONFIRMABLE"
res "  and the verdict names the control it could not confirm" \
    "$(awk '/NOT CONFIRMED by a second/{s=1} s && /gate-dup\.sh/{n++} END{print n+0}' "$LAB/out.txt")" 1

# N4. The OTHER instrument. measure_point has two of them - the runner for
#     scripts/gates/, and a direct launch for every battery outside it - and a
#     confirmation that re-measured a battery through the runner would be two
#     instruments answering one question. Nothing above this line ever exercises
#     the second route: without this case that half of the confirmation ships
#     never having run once.
d="$LAB/chain-outside"; build_repo "$d"
mkdir -p "$d/scripts/other"
printf '#!/usr/bin/env bash\nexit 0\n' > "$d/scripts/other/outside.selftest.sh"
chmod +x "$d/scripts/other/outside.selftest.sh"
G "$d" add -A; G "$d" commit -qm outside
G "$d" checkout -q -b chain/flaky-battery
cat > "$d/scripts/other/outside.selftest.sh" <<'ST'
#!/usr/bin/env bash
c=".flaky-batt.count"
n=$(( $(cat "$c" 2>/dev/null || echo 0) + 1 ))
printf '%s\n' "$n" > "$c"
[ "$n" -eq 1 ] && { echo "first run says broken"; exit 1; }
exit 0
ST
G "$d" add -A; G "$d" commit -qm flaky-battery
G "$d" checkout -q main
res "a BATTERY that does not reproduce -> rc 0, by its own instrument" \
    "$(run_tool "$d" --chain chain/flaky-battery)" 0 "UNCONFIRMED"
res "  and the battery is named by its path, not by a basename" \
    "$(awk '/NOT CONFIRMED by a second/{s=1} s && /scripts\/other\/outside\.selftest\.sh/{n++} END{print n+0}' "$LAB/out.txt")" 1

# N5. THE BOUNDARY, and the one the first draft of this got wrong. "It did not
#     reproduce" has to mean "it came back to where it was", not "the second
#     measurement disagreed with the first". A gate that FAILS once and then
#     cannot measure at all has disagreed with itself and is STILL red both
#     times: dismissing it would retire a regression because two reds failed to
#     match. Measured on the first implementation of this file: rc 0 and an
#     UNCONFIRMED line. It must be a 2.
d="$LAB/chain-mixed"; build_repo "$d"
G "$d" checkout -q -b chain/mixed
cat > "$d/scripts/gates/stub.selftest.sh" <<'ST'
#!/usr/bin/env bash
# FAILS the first time and cannot measure the second: red twice, differently.
c=".mixed.count"
n=$(( $(cat "$c" 2>/dev/null || echo 0) + 1 ))
printf '%s\n' "$n" > "$c"
[ "$n" -eq 1 ] && { echo "measured, FAILS"; exit 1; }
echo "I cannot measure this any more"; exit 2
ST
G "$d" add -A; G "$d" commit -qm mixed
G "$d" checkout -q main
res "red twice but differently -> NOT dismissed, rc 2" "$(run_tool "$d" --chain chain/mixed)" 2 "COULD NOT MEASURE the whole chain"
res "  and it is still an accusation, carrying the SECOND reading" \
    "$(grep -c 'BROKE .*OK->UNMEASURABLE .*stub\.selftest\.sh' "$LAB/out.txt")" 1
res "  and it is NOT filed as a transition that did not reproduce" \
    "$(grep -c '^ *UNCONFIRMED ' "$LAB/out.txt")" 0

# R1. REACHABILITY. Everything above runs against a stub runner, and a label
#     that only a stub can produce is a label nobody will ever see. This case
#     drives the same tool over THIS repository's REAL scripts/gates/run-all.sh
#     - its real argument parsing, its real --only narrowing, its real GATE
#     SUMMARY, em dash and all - with a gate that loses a race exactly once.
#     If the real runner ever stops answering --only the way this reads it, this
#     is the case that goes red.
if [ -f "$ROOT/scripts/gates/run-all.sh" ] \
   && [ -f "$ROOT/scripts/gates/lib/common.sh" ] \
   && [ -f "$ROOT/scripts/gates/data/slow-scoped.txt" ]; then
  d="$LAB/chain-real"; build_real_repo "$d"
  G "$d" checkout -q -b chain/flaky-real
  cat > "$d/scripts/gates/stub.selftest.sh" <<'ST'
#!/usr/bin/env bash
c=".flaky.count"
n=$(( $(cat "$c" 2>/dev/null || echo 0) + 1 ))
printf '%s\n' "$n" > "$c"
[ "$n" -eq 1 ] && { echo "first run says broken"; exit 1; }
exit 0
ST
  G "$d" add -A; G "$d" commit -qm flaky
  G "$d" checkout -q main
  res "REACHABLE through the REAL runner -> UNCONFIRMED, rc 0" \
      "$(run_tool "$d" --chain chain/flaky-real)" 0 "UNCONFIRMED"
  res "  and the real runner's verdict was read, not guessed" \
      "$(grep -c '1 did not' "$LAB/out.txt")" 1
else
  printf '  NOT MEASURED  %-52s\n' "the real runner is not in this checkout"
  unmeasured=$((unmeasured+2))
fi

# ---------------------------------------------------------------------------
# MUTANTS. Each prediction is written here BEFORE the mutant is run: if a
# mutant survives, the case above it is decoration.
# ---------------------------------------------------------------------------
echo
echo "== mutants (each one must turn a case above RED)"

mutate() {  # <label> <sed-expr> <case-dir> <args...> ; prints rc of the tool
  local label="$1" expr="$2" dd="$3"; shift 3
  local m="$LAB/mut"; rm -rf "$m"; cp -R "$dd" "$m"
  sed -i.bak "$expr" "$m/scripts/gh/merge-preview.sh" && rm -f "$m/scripts/gh/merge-preview.sh.bak"
  local r=0
  ( cd "$m" && bash "$m/scripts/gh/merge-preview.sh" --base main "$@" >"$LAB/out.txt" 2>&1 ) || r=$?
  # A mutant has to die of the DEFECT it introduces, not of incoherence. A
  # mutation that breaks the shell - an unbound variable, a syntax error - stops
  # the tool before it can decide anything, and the exit code it leaves behind
  # says nothing about the control being tested.
  #
  # This is measured history, not caution. M7's first form deleted TWO lines
  # with one pattern: the wiring AND the counter the report prints. The tool then
  # aborted on `n_unk: unbound variable` - on BOTH platforms - and the exit code
  # diverged, because bash 3.2 leaves the status of the last command that ran
  # (a printf, 0) while bash 5 exits 1. So this battery read a crash as "the
  # prediction came true" on macOS and as a red on ubuntu, and the mutant never
  # exercised the wiring it was written to remove. A green that depends on the
  # bash version is not a measurement.
  if grep -qE 'unbound variable|syntax error|command not found|: line [0-9]+: ' "$LAB/out.txt"; then
    printf '  mutant %s CRASHED the tool instead of changing its verdict: %s\n' \
      "$label" "$(grep -m1 -E 'unbound variable|syntax error|command not found|: line [0-9]+: ' "$LAB/out.txt" 2>/dev/null || true)" >&2
    printf 'MUTANT-CRASHED\n'; return 0
  fi
  echo "$r"
}

# M1. attribution reports nothing. PREDICTION: C2 stops being rc 1 and comes
#     back 0 - the combination fails and the run says it is fine.
res "M1 the comparison never names a transition -> C2 goes green" \
    "$(mutate M1 's/print "BROKE"/print "NOTHING"/' "$LAB/chain-blame" --chain chain/reader chain/renamer)" 0

# M2. a conflict no longer stops the chain. PREDICTION: chain/z is measured
#     against a tree that is not the chain, so its NOT MEASURED line disappears.
res "M2 a conflict no longer stops the chain -> the skipped branch is measured" \
    "$(mutate M2 's/STOPPED="$b"; RC=2/RC=2/' "$LAB/chain-conflict" --chain chain/x chain/y chain/z >/dev/null; grep -c 'chain/z : NOT MEASURED' "$LAB/out.txt")" 0

# M3. a gate that stopped being measurable stops counting. PREDICTION: C5 goes
#     from 2 to 0 - the defence is gone and the run reads as a pass.
res "M3 OK->UNMEASURABLE stops counting -> C5 goes green" \
    "$(mutate M3 's/CHAIN_UNMEAS=1/CHAIN_UNMEAS=0/' "$LAB/chain-unmeas" --chain chain/blinder)" 0

# M4. the base is always declared all-green, so a red it was born with is never
#     disclosed. PREDICTION: C4 stops printing its exoneration, and the first
#     branch in the chain wears a defect it did not write. (The mutation is on
#     the FLAG, not on the sentence: mutating the sentence and then grepping for
#     the sentence would be the control reading itself.)
res "M4 the base is always called green -> C4 stops exonerating the branch" \
    "$(mutate M4 's/BASE_OK=0/BASE_OK=1/' "$LAB/chain-redbase" --chain chain/innocent >/dev/null; grep -c 'the BASE was not all-green' "$LAB/out.txt")" 0

# M5. The confirmation reuses the first measurement instead of taking a second
#     one - which is what "always agrees" actually looks like in code, and the
#     shape a tired hand would write to make the cases go quiet. PREDICTION: N2
#     goes from 0 to 1. The transition that never reproduced is printed BROKE,
#     reaches the failing bucket, and the reproach goes out to a branch that did
#     nothing. (Forcing the FLAG instead was tried first and is not a mutant:
#     with the arrow carrying the second reading, a forced agreement prints
#     BROKE OK->OK, which is a state the real code cannot reach and which falls
#     in no bucket - the mutant died of incoherence rather than of the defect.)
res "M5 the confirmation reuses the first measurement -> the wobble is blamed" \
    "$(mutate M5 's/conf="$(confirm_verdict "$name")"/conf="${move##*->}"/' "$LAB/chain-flaky" --chain chain/flaky)" 1

# M6. The confirmation NEVER agrees - which is what "swallow every transition"
#     looks like, and it is the failure mode a battery with only N2 in it would
#     have called green. PREDICTION: N1 goes from 1 to 0. A merge that really
#     does break a battery is reported as an instrument wobble and the chain
#     passes.
res "M6 the confirmation never agrees -> a real break is explained away" \
    "$(mutate M6 's/agrees=1/agrees=0/' "$LAB/chain-confirm" --chain chain/renamer)" 0

# M7. A confirmation nobody could measure stops counting. PREDICTION: N3 goes
#     from 2 to 0 - the accusation is neither confirmed nor denied, and the
#     chain passes anyway, which is the exact shape of every defect this file
#     was written against. (The mutation deletes the WIRING, not the label: a
#     mutant that renamed the label and a control that grepped for the label
#     would be the control reading itself. It also deletes the wiring and ONLY
#     the wiring: the first form of this pattern matched the counter line too,
#     which left the tool aborting on an unbound variable instead of deciding
#     anything - see the crash guard in mutate.)
res "M7 an unconfirmable transition stops counting -> N3 goes green" \
    "$(mutate M7 '/UNCONFIRMABLE . <<<"$out" && CHAIN_UNMEAS/d' "$LAB/chain-twin" --chain chain/twin)" 0

# M8. The confirmation stops narrowing the runner, so it re-measures the whole
#     POINT to settle one name. PREDICTION: every verdict above stays exactly
#     where it was - N1 is still rc 1 - and ONLY the witness count moves, from 2
#     to 3. That is the whole reason the cost is a measured control and not a
#     sentence in the header: on this repository the mutant costs 4m08s per
#     transition instead of 1.8 s and NOTHING else about the output changes.
res "M8 the confirmation stops narrowing -> it re-measures the whole point" \
    "$(: > "$CALLS"; mutate M8 's/--only/--ignored/' "$LAB/chain-confirm" --chain chain/renamer >/dev/null; grep -c . "$CALLS")" 3

# M9. A battery outside scripts/gates/ stops being routed to its own instrument
#     and is asked of the gate runner instead, which has never heard of it.
#     PREDICTION: N4 goes from 0 to 2 - the runner returns no line under that
#     name, the confirmation cannot get a verdict, and a transition that was
#     only ever a wobble is reported as one nobody could check.
res "M9 a battery re-measured by the wrong instrument -> N4 cannot confirm" \
    "$(mutate M9 's|\*/\*)|zzz)|' "$LAB/chain-outside" --chain chain/flaky-battery)" 2

# M10. The same "never accuses" mutation, aimed at N5. The boundary case has to
#      hold on its own rather than ride on N1's coverage, because it is the one
#      that says what "did not reproduce" MEANS. PREDICTION: N5 goes from 2 to
#      0 - a control that came back red twice, in two different ways, is filed
#      as an instrument wobble and the chain passes over it.
res "M10 never accuses -> the doubly-red control is filed as a wobble" \
    "$(mutate M10 's/agrees=1/agrees=0/' "$LAB/chain-mixed" --chain chain/mixed)" 0

echo
echo "  $pass PASS / $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
[ "$unmeasured" -eq 0 ] || {
  printf '  and %d case(s) COULD NOT BE MEASURED - that is a 2, not a pass\n' "$unmeasured"
  exit 2
}
exit 0
