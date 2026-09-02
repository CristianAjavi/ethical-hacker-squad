#!/usr/bin/env bash
# Self-test for gate-installer-safety.sh. Each case reintroduces one form of
# the defect on a throwaway copy of the tree and asserts BOTH the exit code and
# the sentence given.
#
# The gate measures behaviour, so the mutants edit the installer itself rather
# than any text about it. A gate that only grepped for `rmtree` would go green
# the moment somebody spelled the same deletion differently, and the mutant
# `deletion-spelled-differently` is here to prove this one does not.
#
# The positive-control mutant matters as much as the rest: an installer that
# refuses EVERYTHING would satisfy cases 1-3 and is not a fixed installer.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-installer-safety.sh"
if [ -n "${EHS_REPO_ROOT:-}" ]; then SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then :
else SRC="$(cd "$HERE/../.." && pwd)"; fi
command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
[ -f "$GATE" ] || { echo "UNMEASURABLE the gate under test is missing: $GATE"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-installer-XXXXXX")" || {
  echo "UNMEASURABLE mktemp -d failed"; exit 2; }
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
I="scripts/ehs.py"

# $1 name  $2 wanted rc  $3 needle  $4 python mutation
case_run() {
  local name="$1" want="$2" needle="$3" mutation="$4" work="$TMP/$1"
  rm -rf "$work"; mkdir -p "$work"
  (cd "$SRC" && tar --exclude .git --exclude __pycache__ -cf - .) | (cd "$work" && tar -xf -)
  if [ -n "$mutation" ] && ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
    printf 'HARNESS  %-40s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
  fi
  local out rc
  out="$(EHS_REPO_ROOT="$work" bash "$GATE" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -qF -- "$needle"; }; then
    printf 'ok       %-40s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-40s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -6; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-installer-safety.sh (source: $SRC) ==="

case_run control-untouched-installer 0 "refuses what it did not create" ""

# ---- the defect, in the exact form it shipped in ---------------------------
case_run the-rmtree-comes-back 1 "was DELETED by the installer" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$I"'"
s=p.read_text()
old="""        if not force:
            print(f"Refusing: {target} exists and was not created by this "
                  f"installer. Re-run with --force to move it aside.",
                  file=sys.stderr)
            return None
        backup = target.with_name(f"{target.name}.bak-{int(time.time())}")
        target.rename(backup)  # moved, never removed
        print(f"  moved {target} -> {backup}")"""
assert s.count(old)==1
p.write_text(s.replace(old,"        shutil.rmtree(target)"))'

# A grep for `rmtree` would miss this: same deletion, spelled by hand, in the
# same place. The gate watches the witness file, so spelling does not help.
case_run deletion-spelled-differently 1 "was DELETED by the installer" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$I"'"
s=p.read_text()
old="        if not force:"
assert s.count(old)==1
new="""        for _c in sorted(target.rglob("*"), reverse=True):
            _c.unlink() if not _c.is_dir() else _c.rmdir()
        target.rmdir()
        target.symlink_to(source, target_is_directory=True)
        return str(target)
        if not force:"""
p.write_text(s.replace(old,new))'

# ---- the guard rails, one at a time ----------------------------------------
case_run force-is-on-by-default 1 "moved aside without --force" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$I"'"
s=p.read_text()
old="        if not force:"
assert s.count(old)==1
p.write_text(s.replace(old,"        if False:"))'

case_run the-symlinked-parent-is-followed 1 "landed in" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$I"'"
s=p.read_text()
old="    if parent.is_symlink():"
assert s.count(old)==1
p.write_text(s.replace(old,"    if False:"))'

# A refusal that does not reach the exit code is the same lie the deletion told:
# "Successfully" printed over rc=0 while a target was left untouched.
case_run the-refusal-never-reaches-the-rc 1 "still exited 0" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$I"'"
s=p.read_text()
old="""    if refused:
        print(f"\\n{refused} target(s) refused; nothing there was deleted.",
              file=sys.stderr)
        return 1
    return 0"""
assert s.count(old)==1
p.write_text(s.replace(old,"    return 0"))'

# ---- the positive control, which is what stops the gate being satisfiable
#      by an installer that simply refuses everything ------------------------
case_run an-installer-that-does-nothing 1 "the gate above would pass on an installer that does nothing" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$I"'"
s=p.read_text()
old="    parent.mkdir(parents=True, exist_ok=True)"
assert s.count(old)==1
p.write_text(s.replace(old,"    return None\n    parent.mkdir(parents=True, exist_ok=True)"))'

# ---- could not measure: never a pass ---------------------------------------
case_run the-installer-is-gone 2 "the installer is missing" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"'"$I"'").unlink()'

case_run the-installer-will-not-run 1 "" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$I"'"
p.write_text("import sys\nsys.exit(3)\n")'

printf '\n%s: %d passed, %d failed\n' "gate-installer-safety" "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
