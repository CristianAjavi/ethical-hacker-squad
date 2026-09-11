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
pass=0; fail=0
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
worst=0; lines=""
for g in scripts/gates/*.selftest.sh scripts/gates/gate-*.sh; do
  [ -e "$g" ] || continue
  rc=0; bash "$g" >/dev/null 2>&1 || rc=$?
  case "$rc" in
    0) lines="$lines
OK   $(basename "$g") - measured, no findings" ;;
    2) lines="$lines
UNMEASURABLE $(basename "$g") - COULD NOT MEASURE"; [ "$worst" -eq 1 ] || worst=2 ;;
    *) lines="$lines
FAIL  $(basename "$g") - measured, FAILS"; worst=1 ;;
  esac
done
echo "===== GATE SUMMARY ====="
echo "discovered: 1 | run: 1 | green: 1 | FAIL: 0 | UNMEASURABLE: 0"
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
# MUTANTS. Each prediction is written here BEFORE the mutant is run: if a
# mutant survives, the case above it is decoration.
# ---------------------------------------------------------------------------
echo
echo "== mutants (each one must turn a case above RED)"

mutate() {  # <label> <sed-expr> <case-dir> <args...> ; prints rc of the tool
  local label="$1" expr="$2" dd="$3"; shift 3
  local m="$LAB/mut"; rm -rf "$m"; cp -R "$dd" "$m"
  sed -i.bak "$expr" "$m/scripts/gh/merge-preview.sh" && rm -f "$m/scripts/gh/merge-preview.sh.bak"
  ( cd "$m" && bash "$m/scripts/gh/merge-preview.sh" --base main "$@" >"$LAB/out.txt" 2>&1 ); echo $?
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

echo
echo "  $pass PASS / $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
exit 0
