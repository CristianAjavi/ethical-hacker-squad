#!/usr/bin/env bash
# scripts/gates/gate-coverage-sweep.selftest.sh
#
# Proves the coverage sweep in the negative, on a toy repository whose answers
# are known by construction.
#
# The sweep exists to find batteries that are green for the wrong reason, so a
# sweep that is itself green for the wrong reason would be the joke writing
# itself. Every case here builds a library where the truth is decided in advance
# - this rule has a case, this one does not - and checks the sweep says so.
#
# Three of these cases are not hypothetical. They are the ways the three
# scratch-directory versions of this sweep were wrong:
#
#   * a library whose battery could not be found was SKIPPED IN SILENCE, so
#     "24 survivors" was a statement about ten of sixteen libraries and nothing
#     said which ten (`unresolvable-library-is-declared-not-skipped`);
#   * a multi-line `findings.append(` replaced by its first line only left a
#     SyntaxError, and the battery died of the parser - scored as coverage
#     nobody had (`multi-line-report-is-replaced-whole`);
#   * survivors were recorded by LINE NUMBER, so every acceptance rotted the
#     next time anybody edited above it (`anchor-survives-an-edit-above-it`).
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SELF_DIR/lib/coverage_sweep.py"
PY="${EHS_PYTHON:-python3}"
GATE="$SELF_DIR/gate-coverage-sweep.sh"

pass=0; fail=0
LAB="$(mktemp -d "${TMPDIR:-/tmp}/ehs-sweep-selftest.XXXXXX")"
cleanup() { [ -n "${LAB:-}" ] && [ -d "$LAB" ] && /bin/rm -rf "$LAB"; }
trap cleanup EXIT INT TERM

# --------------------------------------------------------------------------- #
# The toy repository
# --------------------------------------------------------------------------- #
reset() {
  /bin/rm -rf "$LAB/repo"
  mkdir -p "$LAB/repo/scripts/gates/lib"
}

# toy.py: three report sites, of which the battery below covers exactly one.
# The third opens a call that closes three lines later, on purpose.
write_toy() {
  local fn="${1:-check}"
  cat > "$LAB/repo/scripts/gates/lib/toy.py" <<EOF
def $fn(text):
    findings = []
    info = []
    info.append("looked at %d characters" % len(text))
    if "alpha" in text:
        findings.append("alpha is present")
    if "beta" in text:
        findings.append("beta is present")
    if "gamma" in text:
        findings.append(
            "gamma is present, and this call closes "
            "three lines after it opens"
        )
    return findings
EOF
}

# The battery. It exercises alpha and nothing else, which is the whole point:
# beta and gamma are rules with no case, and the sweep has to say so.
write_battery() {
  cat > "$LAB/repo/scripts/gates/gate-toy.selftest.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
seen="$("${EHS_PYTHON:-python3}" -c 'import sys; sys.path.insert(0, "scripts/gates/lib"); import toy; print(toy.check("alpha"))' 2>&1)"
case "$seen" in
  *alpha*) echo "PASS  alpha-is-reported" ;;
  *)       echo "FAILED  alpha-is-reported"; exit 1 ;;
esac
exit 0
EOF
  chmod +x "$LAB/repo/scripts/gates/gate-toy.selftest.sh"
}

lab() { reset; write_toy; write_battery; }

sweep() { "$PY" "$ENGINE" --root "$LAB/repo" --jobs 2 "$@" 2>&1; }

# run_case <name> <want_rc> <needle-or-> <absent-or-> ; reads the output on stdin
# A needle starting with `re:` is an extended regular expression; anything else
# is a fixed string. The distinction is not decoration: an anchor needle written
# as a fixed string matches INSIDE a longer anchor - `check#1` is a substring of
# `check#10` and of `check#12` - and the negative control caught two cases here
# passing on exactly that, including the one asserting a multi-line report is
# replaced whole.
look() {
  case "$2" in
    re:*) printf '%s' "$1" | grep -qE -- "${2#re:}" ;;
    *)    printf '%s' "$1" | grep -qF -- "$2" ;;
  esac
}

judge() {
  local name="$1" want="$2" needle="$3" absent="$4" rc="$5" out="$6" why=""
  [ "$rc" = "$want" ] || why="rc $rc, expected $want"
  if [ -z "$why" ] && [ "$needle" != "-" ]; then
    look "$out" "$needle" || why="never said '$needle'"
  fi
  if [ -z "$why" ] && [ "$absent" != "-" ]; then
    look "$out" "$absent" && why="said '$absent', which it must not"
  fi
  if [ -z "$why" ]; then
    echo "PASS  $name"; pass=$((pass + 1))
  else
    echo "FAILED  $name: $why"; fail=$((fail + 1))
    printf '%s\n' "$out" | sed -e 's/^/        | /' | head -20
  fi
}

# --------------------------------------------------------------------------- #
[ -r "$ENGINE" ] || { echo "HARNESS  engine-is-readable: $ENGINE missing"; exit 2; }
command -v "$PY" >/dev/null 2>&1 || { echo "HARNESS  python-on-path: no $PY"; exit 2; }

# 1. The population, and the informational receiver that is not part of it.
lab
out="$(sweep --only toy.py)"; rc=$?
judge "informational-appends-are-not-report-sites" 1 "3 report site(s)" "4 report site(s)" "$rc" "$out"

# 2. A rule with a case dies; the two without one survive and are named.
judge "rule-with-no-case-is-reported" 1 "re:toy\.py::check#1([^0-9]|$)" - "$rc" "$out"
judge "rule-with-a-case-dies-by-that-case" 1 "dies by: alpha-is-reported" - "$rc" "$out"
judge "rule-with-a-case-is-not-among-the-survivors" 1 "2 report site(s) can be silenced" - "$rc" "$out"

# 3. The multi-line call is replaced whole. If only its first line were replaced
#    the file would not parse, the battery would die of SyntaxError, and gamma
#    would be scored as covered - a mutant killed by the parser, counted as
#    coverage the battery does not have.
judge "multi-line-report-is-replaced-whole" 1 "re:check#2[^0-9].*SURVIVES" - "$rc" "$out"

# 4. Accepted survivors are not failures.
acc="$LAB/accepted.json"
cat > "$acc" <<'EOF'
{"accepted": [
  {"anchor": "toy.py::check#1", "why": "on purpose, for the self-test"},
  {"anchor": "toy.py::check#2", "why": "on purpose, for the self-test"}
]}
EOF
out="$(sweep --only toy.py --accepted "$acc")"; rc=$?
judge "accepted-survivor-is-not-a-failure" 0 "every surviving report site is accounted for" - "$rc" "$out"

# 5. An acceptance whose site no longer exists is a failure, not a silence. The
#    reason was written for a rule that has moved or gone, and nobody would ever
#    find out from a green run.
cat > "$acc" <<'EOF'
{"accepted": [
  {"anchor": "toy.py::check#1", "why": "on purpose"},
  {"anchor": "toy.py::check#2", "why": "on purpose"},
  {"anchor": "toy.py::check#9", "why": "a rule that does not exist"}
]}
EOF
out="$(sweep --only toy.py --accepted "$acc")"; rc=$?
judge "stale-acceptance-is-a-failure" 1 "re:toy\.py::check#9([^0-9]|$)" - "$rc" "$out"

# 6. Renaming the function moves the anchor, and that is correct: the acceptance
#    was granted to a rule that no longer answers to that name.
reset; write_toy inspect; write_battery
sed -i.bak 's/toy\.check(/toy.inspect(/' "$LAB/repo/scripts/gates/gate-toy.selftest.sh"
cat > "$acc" <<'EOF'
{"accepted": [{"anchor": "toy.py::check#1", "why": "granted under the old name"}]}
EOF
out="$(sweep --only toy.py --accepted "$acc")"; rc=$?
judge "renaming-the-function-invalidates-the-acceptance" 1 "re:toy\.py::check#1([^0-9]|$)" - "$rc" "$out"
judge "renamed-function-reports-under-its-new-name" 1 "re:toy\.py::inspect#1([^0-9]|$)" - "$rc" "$out"

# 7. An edit ABOVE a report site does not move its anchor. Line numbers would.
lab
"$PY" - "$LAB/repo/scripts/gates/lib/toy.py" <<'EOF'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
p.write_text("# a comment nobody thought about\n# and a second line of it\n" + p.read_text())
EOF
out="$(sweep --only toy.py)"; rc=$?
judge "anchor-survives-an-edit-above-it" 1 "re:toy\.py::check#1([^0-9]|$)" - "$rc" "$out"

# 8. A library whose battery cannot be resolved is DECLARED and forces 2. This
#    is the defect that made the scratch versions' denominator a fiction.
lab
echo "def f():" > "$LAB/repo/scripts/gates/lib/orphan.py"
printf '    problems = []\n    problems.append("x")\n    return problems\n' >> "$LAB/repo/scripts/gates/lib/orphan.py"
out="$(sweep)"; rc=$?
judge "unresolvable-library-is-declared-not-skipped" 2 "NOT MEASURED  orphan.py" - "$rc" "$out"
judge "unresolvable-library-names-why" 2 "no gate names this module" - "$rc" "$out"

# 9. A gate that exists but offers no --self-test is not a battery either.
lab
printf '#!/usr/bin/env bash\nexit 0\n' > "$LAB/repo/scripts/gates/gate-orphan.sh"
chmod +x "$LAB/repo/scripts/gates/gate-orphan.sh"
printf 'def f():\n    problems = []\n    problems.append("x")\n    return problems\n' > "$LAB/repo/scripts/gates/lib/orphan.py"
out="$(sweep)"; rc=$?
judge "gate-without-self-test-is-not-a-battery" 2 "accepts no --self-test" - "$rc" "$out"

# 10. A gate WITH --self-test is a battery, resolved without a .selftest.sh file.
lab
cat > "$LAB/repo/scripts/gates/gate-inline.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
[ "${1:-}" = "--self-test" ] || exit 0
seen="$("${EHS_PYTHON:-python3}" -c 'import sys; sys.path.insert(0, "scripts/gates/lib"); import inline; print(inline.check("delta"))' 2>&1)"
case "$seen" in
  *delta*) echo "PASS  delta-is-reported"; exit 0 ;;
  *)       echo "FAILED  delta-is-reported"; exit 1 ;;
esac
EOF
chmod +x "$LAB/repo/scripts/gates/gate-inline.sh"
printf 'def check(t):\n    findings = []\n    if "delta" in t:\n        findings.append("delta is present")\n    return findings\n' \
  > "$LAB/repo/scripts/gates/lib/inline.py"
out="$(sweep --only inline.py)"; rc=$?
judge "inline-self-test-counts-as-a-battery" 0 "inline self-test of gate-inline.sh" "NOT MEASURED" "$rc" "$out"

# 11. A FIXTURE - a module with no gate of its own, named by exactly one gate -
#     is covered by that gate's battery rather than declared unmeasurable.
printf 'ROWS = [1, 2]\n\n\ndef rows():\n    out = []\n    out.append(1)\n    return out\n' \
  > "$LAB/repo/scripts/gates/lib/inline_fixture.py"
printf '# uses inline_fixture\n' >> "$LAB/repo/scripts/gates/gate-inline.sh"
out="$(sweep --only inline_fixture.py)"; rc=$?
judge "fixture-is-covered-by-the-gate-that-names-it" 1 "fixture of gate-inline.sh" "NOT MEASURED" "$rc" "$out"

# 12. A battery already red says nothing about a mutant. Refuse before spending
#     an hour producing verdicts that mean nothing.
lab
printf '#!/usr/bin/env bash\necho "FAILED  broken-before-anybody-mutated-anything"\nexit 1\n' \
  > "$LAB/repo/scripts/gates/gate-toy.selftest.sh"
chmod +x "$LAB/repo/scripts/gates/gate-toy.selftest.sh"
out="$(sweep --only toy.py)"; rc=$?
judge "red-baseline-refuses-instead-of-reporting" 2 "already rc 1 with nothing mutated" - "$rc" "$out"

# 13. A selection that matches nothing measured nothing. It is not a clean sweep.
lab
out="$(sweep --only nosuchlibrary.py)"; rc=$?
judge "empty-selection-is-unmeasurable-not-clean" 2 "no gate library matched" - "$rc" "$out"

# 14. A library with no report site at all cannot be swept, and an empty plan is
#     not a pass either.
reset
printf 'VALUE = 1\n' > "$LAB/repo/scripts/gates/lib/quiet.py"
printf '#!/usr/bin/env bash\nexit 0\n' > "$LAB/repo/scripts/gates/gate-quiet.selftest.sh"
chmod +x "$LAB/repo/scripts/gates/gate-quiet.selftest.sh"
out="$(sweep --only quiet.py)"; rc=$?
judge "no-report-site-is-unmeasurable-not-clean" 2 "no report site could be swept" - "$rc" "$out"

# 15. The gate wrapper refuses a worker count that is not one. `--only` with a
#     name that matches nothing keeps the case terminable: without it, a broken
#     guard would sweep the whole repository for three quarters of an hour
#     instead of failing, and the needle is what separates the guard's refusal
#     from the engine's.
out="$(EHS_SWEEP_JOBS=nought bash "$GATE" --only nosuchlibrary.py 2>&1)"; rc=$?
judge "gate-refuses-a-non-numeric-worker-count" 2 "not a job count" - "$rc" "$out"
out="$(EHS_SWEEP_JOBS=0 bash "$GATE" --only nosuchlibrary.py 2>&1)"; rc=$?
judge "gate-refuses-zero-workers" 2 "a sweep with no workers measures nothing" - "$rc" "$out"

# 16. The gate wrapper refuses an interpreter that is not there. An absent tool
#     is COULD NOT MEASURE and never a pass.
out="$(EHS_PYTHON=python-that-is-not-installed bash "$GATE" --only nosuchlibrary.py 2>&1)"; rc=$?
judge "gate-refuses-a-missing-interpreter" 2 "nothing was measured" - "$rc" "$out"

# --------------------------------------------------------------------------- #
# The sharded run. In CI the sweep is one job per library, because one library
# carries 44% of the whole cost. Sharding buys wall clock and opens exactly one
# hole - a library nobody put in the matrix - so the cases below are mostly about
# that hole rather than about the arithmetic.
# --------------------------------------------------------------------------- #

# 17. The matrix is generated from the tree. A hand-written list goes stale the
#     day somebody adds a library, and the sweep would then skip it in silence.
lab
printf 'def check(t):\n    findings = []\n    if "delta" in t:\n        findings.append("delta")\n    return findings\n' \
  > "$LAB/repo/scripts/gates/lib/second.py"
printf '#!/usr/bin/env bash\nexit 0\n' > "$LAB/repo/scripts/gates/gate-second.selftest.sh"
chmod +x "$LAB/repo/scripts/gates/gate-second.selftest.sh"
printf 'VALUE = 1\n' > "$LAB/repo/scripts/gates/lib/quiet.py"
printf '#!/usr/bin/env bash\nexit 0\n' > "$LAB/repo/scripts/gates/gate-quiet.selftest.sh"
chmod +x "$LAB/repo/scripts/gates/gate-quiet.selftest.sh"
out="$("$PY" "$ENGINE" --root "$LAB/repo" --list-libraries 2>&1)"; rc=$?
judge "matrix-lists-the-libraries-with-report-sites" 0 "second.py" - "$rc" "$out"
judge "matrix-omits-a-library-with-no-report-site" 0 "toy.py" "quiet.py" "$rc" "$out"

# 18. A library the resolver cannot place must not reach the matrix as if it were
#     fine. Listing is the first step of the run and refuses like every other.
printf 'def f():\n    problems = []\n    problems.append("x")\n    return problems\n' \
  > "$LAB/repo/scripts/gates/lib/orphan.py"
out="$("$PY" "$ENGINE" --root "$LAB/repo" --list-libraries 2>&1)"; rc=$?
judge "matrix-refuses-an-unresolvable-library" 2 "no gate names this module" - "$rc" "$out"
/bin/rm -f "$LAB/repo/scripts/gates/lib/orphan.py"

# 19. Two shards, one verdict. A shard must NOT judge itself: measured alone
#     against the whole acceptance file, every shard fails over the other
#     shards' entries.
"$PY" "$ENGINE" --root "$LAB/repo" --only toy.py --jobs 2 --json "$LAB/s1.json" >/dev/null 2>&1
"$PY" "$ENGINE" --root "$LAB/repo" --only second.py --jobs 2 --json "$LAB/s2.json" >/dev/null 2>&1
cat > "$acc" <<'EOF'
{"accepted": [
  {"anchor": "toy.py::check#1", "kind": "open", "why": "no case"},
  {"anchor": "toy.py::check#2", "kind": "open", "why": "no case"},
  {"anchor": "second.py::check#0", "kind": "accepted", "why": "deliberate"}
]}
EOF
out="$("$PY" "$ENGINE" --root "$LAB/repo" --accepted "$acc" --verdict-from "$LAB/s1.json" "$LAB/s2.json" 2>&1)"; rc=$?
judge "two-shards-reach-one-verdict" 0 "every surviving report site is accounted for" - "$rc" "$out"
judge "the-verdict-counts-open-holes-apart-from-deliberate-ones" 0 "2 open hole(s)" - "$rc" "$out"

# 20. THE HOLE SHARDING OPENS. A library in the tree and in no shard is the same
#     silent skip that made the earlier versions' denominator a fiction, walking
#     back in through the workflow instead of through the resolver.
out="$("$PY" "$ENGINE" --root "$LAB/repo" --accepted "$acc" --verdict-from "$LAB/s1.json" 2>&1)"; rc=$?
judge "a-library-in-no-shard-is-refused-not-ignored" 2 "in no shard" - "$rc" "$out"
judge "the-missing-shard-is-named-by-its-anchors" 2 "re:second\.py::check#0([^0-9]|$)" - "$rc" "$out"

# 21. Two shards carrying the same anchor would double-count it.
out="$("$PY" "$ENGINE" --root "$LAB/repo" --accepted "$acc" --verdict-from "$LAB/s1.json" "$LAB/s1.json" "$LAB/s2.json" 2>&1)"; rc=$?
judge "overlapping-shards-are-refused" 2 "appears in two shards" - "$rc" "$out"

# 22. An unreadable or empty shard is COULD NOT MEASURE. A shard that produced
#     nothing renders exactly like a shard with nothing to report.
: > "$LAB/empty.json"
out="$("$PY" "$ENGINE" --root "$LAB/repo" --accepted "$acc" --verdict-from "$LAB/empty.json" 2>&1)"; rc=$?
judge "an-unreadable-shard-is-unmeasurable" 2 "is unreadable" - "$rc" "$out"
echo '[]' > "$LAB/empty.json"
out="$("$PY" "$ENGINE" --root "$LAB/repo" --accepted "$acc" --verdict-from "$LAB/empty.json" 2>&1)"; rc=$?
judge "an-empty-shard-is-not-a-clean-one" 2 "carries no result" - "$rc" "$out"

# 32. The workflow reads exit codes it can actually reach. GitHub runs every
#     `run:` block with `bash -e`, and `set -uo pipefail` does not turn that off.
#     The first run of this workflow died of exactly that: with pipefail, the
#     sweep's rc 1 - a rule survived, which the verdict job exists to judge -
#     killed the step before the line that reads PIPESTATUS. Eight shards red in
#     fifteen seconds, for a reason with nothing to do with coverage. Locally the
#     step does not exist and the gate is deferred, so nothing here could have
#     seen it; this case is the thing that sees it now.
WF="$SELF_DIR/../../.github/workflows/coverage-sweep.yml"
if [ ! -f "$WF" ]; then
  judge "workflow-reads-an-exit-code-it-can-reach" 0 - - 2 "no workflow at $WF"
else
  bad=""
  for n in $(grep -n 'PIPESTATUS' "$WF" | grep -v ':[[:space:]]*#' | cut -d: -f1); do
    st="$(awk -v n="$n" 'NR<n && /^ *set /{l=$0} END{print l}' "$WF")"
    case "$st" in *"+e"*) ;; *) bad="$bad $n" ;; esac
  done
  if [ -n "$bad" ]; then
    judge "workflow-reads-an-exit-code-it-can-reach" 0 - - 1 \
      "line(s)$bad read PIPESTATUS under an inherited -e: the step dies before deciding"
  else
    judge "workflow-reads-an-exit-code-it-can-reach" 0 - - 0 "every PIPESTATUS read is under +e"
  fi
fi

# --------------------------------------------------------------------------- #
echo
echo "$pass PASS / $fail FAILED"
[ "$fail" -eq 0 ] || exit 1
exit 0
