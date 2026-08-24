#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Proves verify-target-checkout.py in the negative.
#
# The failure it exists to prevent is real and cost a published round: targets
# cloned at the default branch, which is AFTER the fix, so both arms audited
# code the defects had been removed from and 0/3 was reported as detection.
#
# Every case below must FAIL the check except the baseline. A case that stops
# failing means the check has gone blind to that way of getting it wrong.
#
# EXIT CODES: 0 every case behaved / 1 a case did not / 2 could not run
# ---------------------------------------------------------------------------
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/verify-target-checkout.py"
[ -r "$CHECK" ] || { echo "  COULD NOT MEASURE: $CHECK missing (rc 2)"; exit 2; }
command -v git >/dev/null 2>&1 || { echo "  COULD NOT MEASURE: git missing (rc 2)"; exit 2; }

LAB="$(mktemp -d)"; trap 'rm -rf "$LAB"' EXIT
fails=0

# A tiny repository with two commits: the defect, then the fix.
mk_repo() {
  local d="$LAB/$1"; mkdir -p "$d/pkg"
  git -C "$d" init -q 2>/dev/null || git init -q "$d"
  git -C "$d" config user.email t@t; git -C "$d" config user.name t
  printf 'func f() { make([]int, n) }\n' > "$d/pkg/dec.go"
  git -C "$d" add -A; git -C "$d" commit -qm defect
  PARENT="$(git -C "$d" rev-parse HEAD)"
  printf 'const maxGap = 10000\nfunc f() { if n > maxGap { return }; make([]int, n) }\n' > "$d/pkg/dec.go"
  git -C "$d" add -A; git -C "$d" commit -qm fix
  FIXED="$(git -C "$d" rev-parse HEAD)"
}

mk_cases() {  # $1 out, $2 parent
  cat > "$1" <<JSON
{"cases":[{"advisory":"GHSA-test","repository":"https://github.com/x/repo",
  "parent":"$2","fix_files":["pkg/dec.go"],"fix_markers":["maxGap"]}]}
JSON
}

run_case() {  # name want
  local name="$1" want="$2"; shift 2
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ]; then
    printf '  [self-test OK]   %-44s rc=%s\n' "$name" "$rc"
  else
    printf '  [self-test FAIL] %-44s rc=%s, expected %s\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/      /'; fails=$((fails+1))
  fi
}

mkdir -p "$LAB/co"; mk_repo co/repo
mk_cases "$LAB/cases.json" "$PARENT"

# 1. Baseline: checked out AT the pre-fix parent. Must pass, or the check is
#    unsatisfiable and therefore useless.
git -C "$LAB/co/repo" checkout -q "$PARENT"
run_case "checkout at the pre-fix parent -> passes" 0 python3 "$CHECK" "$LAB/cases.json" "$LAB/co"

# 2. The exact mistake that cost a round: checked out at the fix.
git -C "$LAB/co/repo" checkout -q "$FIXED"
run_case "checkout at the FIX -> fails" 1 python3 "$CHECK" "$LAB/cases.json" "$LAB/co"

# 3. Right commit, but the case forgot to record a parent. Nothing to verify
#    against is not the same as verified.
mk_cases "$LAB/noparent.json" ""
git -C "$LAB/co/repo" checkout -q "$PARENT"
run_case "case records no parent -> fails" 1 python3 "$CHECK" "$LAB/noparent.json" "$LAB/co"

# 4. No checkout at all is COULD NOT MEASURE, never a pass.
run_case "no checkout -> could not measure" 2 python3 "$CHECK" "$LAB/cases.json" "$LAB/absent"

# 5. No case file is COULD NOT MEASURE too.
run_case "no case file -> could not measure" 2 python3 "$CHECK" "$LAB/nope.json" "$LAB/co"

[ "$fails" -ne 0 ] && { echo "verify-target-checkout.selftest: $fails case(s) misbehaved (rc 1)"; exit 1; }
echo "verify-target-checkout.selftest: 5 cases, all behaved (rc 0)"
