#!/usr/bin/env bash
# Self-test for gate-bench-evidence.sh, on throwaway git repositories built here.
#
# The gate's whole value is catching a file git will never publish, so every case
# below builds a real repository with a real .gitignore: asserting against a
# hand-written list would test nothing about how git actually resolves ignores.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-bench-evidence.sh"
[ -f "$GATE" ] || { echo "UNMEASURABLE $GATE is missing"; exit 2; }
command -v git >/dev/null 2>&1 || { echo "UNMEASURABLE git is absent"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-bench-evidence-XXXXXX")" || { echo "UNMEASURABLE no tmpdir"; exit 2; }
cleanup() { chmod -R u+w "$TMP" 2>/dev/null; find "$TMP" -mindepth 1 -delete 2>/dev/null; rmdir "$TMP" 2>/dev/null; }
trap cleanup EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  PASS  $1"; }
bad() { fail=$((fail+1)); echo "  FAIL  $1"; }

# repo <name> <gitignore-body> — a work tree with a run directory in it
repo() {
  local d="$TMP/$1"
  mkdir -p "$d/bench/runs/some-round/runs"
  git -C "$d" init --quiet 2>/dev/null
  git -C "$d" config user.email t@example.com
  git -C "$d" config user.name t
  printf '%s\n' "$2" > "$d/.gitignore"
  printf '{}\n' > "$d/bench/runs/some-round/runs/run-1.json"
  printf '# round\n' > "$d/bench/runs/some-round/README.md"
  git -C "$d" add -A 2>/dev/null
  git -C "$d" commit --quiet -m init 2>/dev/null
  echo "$d"
}

run() { EHS_REPO_ROOT="$1" bash "$GATE" >"$TMP/out" 2>&1; }

echo "== nothing ignored =="
d="$(repo clean '*.log')"
run "$d"; rc=$?
[ "$rc" -eq 0 ] && ok "a run whose evidence is tracked gives rc 0" || bad "expected rc 0, got $rc"
grep -q 'tracked and reachable' "$TMP/out" && ok "it says how many files are reachable" || bad "no count"

echo "== the defect that produced this gate =="
d="$(repo ignored 'reports/')"
mkdir -p "$d/bench/runs/some-round/reports"
printf '{}\n' > "$d/bench/runs/some-round/reports/run-1.json"
run "$d"; rc=$?
[ "$rc" -eq 1 ] && ok "evidence in an ignored directory gives rc 1" || bad "expected rc 1, got $rc"
grep -q 'reports/run-1.json' "$TMP/out" \
  && ok "the unreachable file is named, not just counted" || bad "the file is anonymous"

echo "== an ignore that does not touch bench/runs is not the gate's business =="
d="$(repo elsewhere 'reports/')"
mkdir -p "$d/tmp-scratch/reports"
printf '{}\n' > "$d/tmp-scratch/reports/x.json"
run "$d"; rc=$?
[ "$rc" -eq 0 ] && ok "an ignored file outside bench/runs does not fail the gate" \
                || bad "the gate reaches outside its scope: rc $rc"

echo "== a file ignored by pattern rather than by directory =="
d="$(repo bypattern '*.local.json')"
printf '{}\n' > "$d/bench/runs/some-round/runs/draft.local.json"
run "$d"; rc=$?
[ "$rc" -eq 1 ] && ok "a pattern-ignored file is caught too, not only a directory" \
                || bad "only directory ignores are caught: rc $rc"

echo "== could not measure is never a pass =="
mkdir -p "$TMP/notarepo/bench/runs"
run "$TMP/notarepo"; rc=$?
[ "$rc" -eq 2 ] && ok "outside a work tree the answer is 2, not 0" || bad "expected rc 2, got $rc"

d="$(repo norundir '*.log')"
find "$d/bench" -mindepth 1 -delete 2>/dev/null
run "$d"; rc=$?
[ "$rc" -eq 2 ] && ok "no bench/runs at all is 2, not a silent green" || bad "expected rc 2, got $rc"

echo
echo "$pass PASS / $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
exit 0
