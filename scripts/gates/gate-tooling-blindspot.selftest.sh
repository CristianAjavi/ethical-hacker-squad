#!/usr/bin/env bash
# Self-test for gate-tooling-blindspot.sh.
#
# A gate nobody has seen fail is not a proved gate. Every case here copies the
# repository to a throwaway directory, breaks exactly ONE thing the gate claims
# to watch, and asserts both the exit code and the reason:
#
#   1 = the gate MEASURED a blind spot
#   2 = the gate COULD NOT MEASURE (its premise or its corpus is gone)
#   0 = measured and conforming
#
# The first case is the control: the untouched repository must pass. Without it,
# a battery that stopped measuring would look like a battery that found nothing.
#
# Half of these cases push the OTHER way, and they are the ones that matter for
# a gate this young: a check that accuses prose which is already correct is
# worse than no check, because the cheapest way to silence it is to break the
# prose. `must-not-accuse-*` are those cases. They failed first — the gate
# accused INF-08, INF-20 and INF-24 for greping source with the defaults on
# while a sibling invocation pointed straight at the dotted file — and they are
# why the unit of judgement is the procedure and not the command.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

if [ -n "${EHS_REPO_ROOT:-}" ]; then
  SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then
  :
else
  SRC="$(cd "$HERE/../.." && pwd)"
fi

command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-tooling-blindspot-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
K="skills/ethical-hacker-squad/references/knowledge"

# case <name> <expected rc> <expected substring> <python mutation>
case_run() {
  local name="$1" want="$2" needle="$3" mutation="$4"
  local work="$TMP/$name"
  rm -rf "$work"; mkdir -p "$work"
  (cd "$SRC" && tar --exclude .git --exclude __pycache__ -cf - .) | (cd "$work" && tar -xf -)
  if [ -n "$mutation" ]; then
    if ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
      printf 'HARNESS  %-36s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
    fi
  fi
  # The gate under test is the COPY, not the installed one: both the gate and
  # its core resolve their siblings from their own directory, so a mutant aimed
  # at scripts/gates would otherwise land on a file nobody executes and the
  # case would read as a gate failure instead of as a rotten mutant.
  local out rc
  out="$(EHS_REPO_ROOT="$work" bash "$work/scripts/gates/gate-tooling-blindspot.sh" 2>&1)"; rc=$?
  # A here-string, never a pipe into a subshell: the question is whether the
  # reason is ABSENT, and a grep that could not read its input answers neither.
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || grep -q -- "$needle" <<< "$out"; }; then
    printf 'ok       %-36s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-36s rc=%s (wanted %s%s)\n' "$name" "$rc" "$want" \
      "$([ -n "$needle" ] && printf ' and %s' "$needle")"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -6
    fail=$((fail+1))
  fi
}

# A synthetic pack file is how the must-not-accuse cases state their premise in
# one place instead of borrowing a real procedure that may be rewritten later.
synth() {
  printf 'import os,pathlib\np=pathlib.Path(os.environ["EHS_WORK"])/"%s/zz-selftest.md"\np.write_text(%s)\n' "$K" "$1"
}

echo "=== self-test: gate-tooling-blindspot.sh (source: $SRC) ==="

case_run control-untouched-corpus 0 "can actually reach it" ""

# --- the gate must go red -------------------------------------------------
# One per assert in scripts/gates/lib/tooling_blindspot.py.

# 1. the blind spot itself: a procedure sent at `.env` with the defaults on.
case_run bare-invocation-at-hidden-path 1 "ZZ-01" "$(synth '"""### ZZ-01 Synthetic\n\n**Where to look**\n- a committed `.env` at the repository root\n\n**Tooling**: `rg -n \"SECRET|TOKEN\" src/`\n"""')"

# 2. a hidden path inside the search PATTERN is a string being looked FOR, not a
#    place being looked in. Before path_arguments() existed this exonerated
#    AI-25, the worst offender in the corpus, and the gate went quiet on it.
case_run pattern-is-not-a-path 1 "ZZ-02" "$(synth '"""### ZZ-02 Synthetic\n\n**Where to look**\n- the agent settings under `.cursor/rules/**`\n\n**Tooling**: `rg -n \"~/.cursor/rules|allowed[_-]?tools\" src/`\n"""')"

# 3. half a pair is not the pair: `-H` still honours .gitignore, `-I` still
#    skips hidden files. Either alone leaves a documented blind spot.
case_run half-the-flag-pair 1 "ZZ-03" "$(synth '"""### ZZ-03 Synthetic\n\n**Where to look**\n- the manifests under `.claude-plugin/`\n\n**Tooling**: `fd -I -t f manifest.json <target>`\n"""')"

# 4. the flags stripped from a procedure this iteration corrected: the fix must
#    stay fixed, and the assert is derived from the file, never pinned blind.
case_run corrected-procedure-regressed 1 "AI-28" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'/ai-safety-agent-runtime.md"
t=p.read_text()
needle="`rg -n -uu --hidden \"allowed[_-]?tools"
assert needle in t, "AI-28 no longer carries the corrected invocation: this mutant cannot bite"
p.write_text(t.replace(needle,"`rg -n \"allowed[_-]?tools",1))'

# --- the gate must say COULD NOT MEASURE ----------------------------------

# 5. the premise: tooling.md stops declaring the rule. A gate whose mandate is
#    gone must not report a clean corpus - it has stopped measuring.
case_run premise-no-longer-declared 2 "no longer declares" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"skills/ethical-hacker-squad/references/tooling.md"
t=p.read_text()
assert "-uu --hidden" in t, "tooling.md already lacks the rule: this mutant cannot bite"
p.write_text(t.replace("-uu --hidden","--smart-case"))'

case_run corpus-gone 2 "corpus is missing" '
import os,shutil,pathlib
shutil.rmtree(pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'")'

# 6. a red with no finding on it is the interpreter dying, not a measurement.
case_run core-crashes 2 "it crashed" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/lib/tooling_blindspot.py"
p.write_text("import sys\nsys.stderr.write(chr(10))\nsys.exit(1)\n")'

# --- the gate must NOT accuse ---------------------------------------------
# These are the calibration. Each one is prose that is already right.

# 7. a second invocation pointed straight at the dotted path IS the documented
#    way round the default: INF-20 and INF-24 do exactly this and are correct.
case_run must-not-accuse-explicit-path 0 "can actually reach it" "$(synth '"""### ZZ-04 Synthetic\n\n**Where to look**\n- the workflows under `.github/workflows/`\n\n**Tooling**: `rg -n \"run:\" src/` for the callers, then `rg -n \"pull_request_target\" .github/workflows/` for the trigger.\n"""')"

# 8. `-g \x27!.git\x27` EXCLUDES a hidden path. It neither exposes the procedure
#    nor covers it, and reading it as exposure falsely accused AI-20.
case_run must-not-accuse-excluded-path 0 "can actually reach it" "$(synth '"""### ZZ-05 Synthetic\n\n**Tooling**: `rg -n --pcre2 \x27[\\\\x{200B}-\\\\x{200D}]\x27 -g \x27!.git\x27`\n"""')"

# 9. a dotted token glued to a word is an attribute, not a directory. Treating
#    every dot as a hidden path would accuse most of the corpus.
case_run must-not-accuse-dotted-attribute 0 "can actually reach it" "$(synth '"""### ZZ-06 Synthetic\n\n**Tooling**: `rg -n \"os.environ|parent.parent|filepath.Join\" src/`\n"""')"

# 10. a procedure that never sends the auditor anywhere hidden wanted the
#     filtered view, and the defaults are the right call for it.
case_run must-not-accuse-plain-source-sweep 0 "can actually reach it" "$(synth '"""### ZZ-07 Synthetic\n\n**Tooling**: `rg -n \"eval\\\\(|exec\\\\(\" src/`\n"""')"

echo
echo "Summary: $pass ok, $fail failures"
if [ "$fail" -gt 0 ]; then
  echo "Result: FAILED. A case did not behave as the doctrine demands."
  exit 1
fi
echo "Result: OK. The gate goes red on a documented blind spot, says COULD NOT"
echo "        MEASURE when its premise is gone, and stays quiet on prose that is"
echo "        already right."
exit 0
