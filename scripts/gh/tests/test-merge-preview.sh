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
# stub runner: green, and it prints the line merge-preview greps for
echo "discovered: 1 | run: 1 | green: 1 | FAIL: 0 | UNMEASURABLE: 0"
exit 0
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

echo
echo "  $pass PASS / $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
exit 0
