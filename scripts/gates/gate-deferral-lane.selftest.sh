#!/usr/bin/env bash
# Self-test for gate-deferral-lane.sh. Every case builds a small throwaway tree
# with its own runner, controls and workflows, breaks exactly one thing, and
# asserts the exit code AND the reason. A gate about declarations can only be
# exercised by writing declarations, so the fixtures are trees, not this repo -
# and the instrument under test is this repository's gate, pointed at them.
#
# The bank carries the two halves a control needs: cases that must go RED (a
# lane deleted, a lane that is only a comment, a --skip standing in for a lane,
# a glob that resolves to nothing, an exemption that outlived its reason) and
# cases that must report COULD NOT MEASURE rather than pass (a declaration shape
# the gate does not recognise, no workflows at all, a data file that will not
# parse, a declaration file that cannot be read).
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-deferral-lane.sh"
command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
[ -f "$GATE" ] || { echo "UNMEASURABLE the gate under test is not at $GATE"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-deferral-lane-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0; skipped=0

# build_tree <dir> — a tree with: two deferred controls, both with a lane.
#   gate-alpha.sh   deferred by the runner's PR_SCOPED, named by a workflow step
#   gate-beta.sh    removed from one job with --skip, run by another with --only
#   gate-gamma.sh   a control nothing defers
build_tree() {
  local d="$1"
  mkdir -p "$d/scripts/gates/data" "$d/.github/workflows"
  for g in alpha beta gamma; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$d/scripts/gates/gate-$g.sh"
  done
  cat > "$d/scripts/gates/run-all.sh" <<'RUNNER'
#!/usr/bin/env bash
PR_SCOPED='gate-alpha.sh'
printf 'NOT RUN HERE (declared, not silenced):%s\n' "$DEFERRED"
RUNNER
  cat > "$d/.github/workflows/ci.yml" <<'WF'
name: CI
jobs:
  gates:
    steps:
      # gate-alpha.sh is named in this comment and that must not count
      - name: the fast controls
        run: ./scripts/gates/run-all.sh --skip 'gate-beta.sh'
  pr:
    steps:
      - name: the ones that need a pull request
        run: ./scripts/gates/gate-alpha.sh --branch x
  slow:
    steps:
      - name: the expensive one
        run: ./scripts/gates/run-all.sh --only 'gate-beta.sh'
WF
  printf '{\n  "no_ci_lane": {}\n}\n' > "$d/scripts/gates/data/deferred-lanes.json"
}

# case_run <name> <want rc> <needle> <python mutation over EHS_WORK>
case_run() {
  local name="$1" want="$2" needle="$3" mutation="$4"
  local work="$TMP/$name"
  rm -rf "$work"; mkdir -p "$work"
  build_tree "$work"
  if [ -n "$mutation" ] && ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
    printf 'HARNESS  %-36s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
  fi
  local out rc=0
  out="$(EHS_REPO_ROOT="$work" bash "$GATE" 2>&1)" || rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf 'ok       %-36s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-36s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -6; fail=$((fail+1))
  fi
}

PY_WF='
import os, pathlib
p = pathlib.Path(os.environ["EHS_WORK"]) / ".github/workflows/ci.yml"
t = p.read_text()
'

echo "=== self-test: gate-deferral-lane.sh ==="

# ---------------------------------------------------------------- the control
case_run control-every-lane-present 0 "have a lane that names them" ""

# ------------------------------------------------------------- must go RED
case_run lane-job-deleted 1 "no workflow line names it" "$PY_WF"'
p.write_text(t.replace("        run: ./scripts/gates/run-all.sh --only \x27gate-beta.sh\x27\n", ""))'

case_run only-glob-matches-nothing 1 "matches no control" "$PY_WF"'
p.write_text(t.replace("--only \x27gate-beta.sh\x27", "--only \x27gate-delta.sh\x27"))'

case_run lane-only-inside-a-comment 1 "no workflow line names it" "$PY_WF"'
p.write_text(t.replace("        run: ./scripts/gates/gate-alpha.sh --branch x",
                       "      # run: ./scripts/gates/gate-alpha.sh --branch x"))'

case_run a-skip-is-not-a-lane 1 "no workflow line names it" "$PY_WF"'
p.write_text(t.replace("--only \x27gate-beta.sh\x27", "--skip \x27gate-beta.sh\x27"))'

case_run scoped-name-with-no-lane 1 "no workflow line names it" '
import os, pathlib
p = pathlib.Path(os.environ["EHS_WORK"]) / "scripts/gates/run-all.sh"
p.write_text(p.read_text().replace("PR_SCOPED=\x27gate-alpha.sh\x27",
                                   "PR_SCOPED=\x27gate-alpha.sh gate-gamma.sh\x27"))'

case_run slow-scoped-name-with-no-lane 1 "no workflow line names it" '
import os, pathlib
d = pathlib.Path(os.environ["EHS_WORK"]) / "scripts/gates/data"
(d / "slow-scoped.txt").write_text("# costs too much for the push path\ngate-gamma.sh\n")'

case_run exemption-for-an-absent-control 1 "outlived the thing it excused" '
import os, json, pathlib
p = pathlib.Path(os.environ["EHS_WORK"]) / "scripts/gates/data/deferred-lanes.json"
p.write_text(json.dumps({"no_ci_lane": {"gate-zulu.sh": {"reason": "gone", "runs": "nowhere"}}}))'

case_run exemption-nothing-defers 1 "nothing defers any more" '
import os, json, pathlib
p = pathlib.Path(os.environ["EHS_WORK"]) / "scripts/gates/data/deferred-lanes.json"
p.write_text(json.dumps({"no_ci_lane": {"gate-gamma.sh": {"reason": "it used to be deferred", "runs": "locally"}}}))'

case_run exemption-that-now-has-a-lane 1 "remove the exemption" '
import os, json, pathlib
w = pathlib.Path(os.environ["EHS_WORK"])
r = w / "scripts/gates/run-all.sh"
r.write_text(r.read_text().replace("PR_SCOPED=\x27gate-alpha.sh\x27",
                                   "PR_SCOPED=\x27gate-alpha.sh gate-beta.sh\x27"))
p = w / "scripts/gates/data/deferred-lanes.json"
p.write_text(json.dumps({"no_ci_lane": {"gate-beta.sh": {"reason": "needs a token CI has not got", "runs": "locally"}}}))'

case_run exemption-with-no-reason 1 "with no reason written" '
import os, json, pathlib
w = pathlib.Path(os.environ["EHS_WORK"])
wf = w / ".github/workflows/ci.yml"
wf.write_text(wf.read_text().replace("        run: ./scripts/gates/gate-alpha.sh --branch x", "        run: true"))
p = w / "scripts/gates/data/deferred-lanes.json"
p.write_text(json.dumps({"no_ci_lane": {"gate-alpha.sh": {"reason": "   ", "runs": "somewhere"}}}))'

# ------------------------------------------- must report COULD NOT MEASURE
case_run runner-shape-not-recognised 2 "declaration shape changed" '
import os, pathlib
p = pathlib.Path(os.environ["EHS_WORK"]) / "scripts/gates/run-all.sh"
p.write_text(p.read_text().replace("PR_SCOPED=\x27gate-alpha.sh\x27",
                                   "PR_SCOPED=( gate-alpha.sh )"))'

case_run no-workflows-at-all 2 "there is no" '
import os, shutil, pathlib
shutil.rmtree(pathlib.Path(os.environ["EHS_WORK"]) / ".github/workflows")'

case_run lanes-file-will-not-parse 2 "does not parse" '
import os, pathlib
p = pathlib.Path(os.environ["EHS_WORK"]) / "scripts/gates/data/deferred-lanes.json"
p.write_text("{ this is not json")'

case_run lanes-file-wrong-shape 2 "expected shape" '
import os, json, pathlib
p = pathlib.Path(os.environ["EHS_WORK"]) / "scripts/gates/data/deferred-lanes.json"
p.write_text(json.dumps({"no_ci_lane": ["gate-gamma.sh"]}))'

case_run runner-is-gone 2 "is not there" '
import os, pathlib
(pathlib.Path(os.environ["EHS_WORK"]) / "scripts/gates/run-all.sh").unlink()'

# A declaration file that exists and cannot be read is the case where "absent"
# and "cannot look" get confused. root can read anything, so on root this is
# NOT MEASURED rather than a pass - a case that cannot run is not a case that
# passed.
work="$TMP/slow-scoped-unreadable"; rm -rf "$work"; mkdir -p "$work"; build_tree "$work"
printf 'gate-gamma.sh\n' > "$work/scripts/gates/data/slow-scoped.txt"
chmod 000 "$work/scripts/gates/data/slow-scoped.txt" 2>/dev/null || true
if [ -r "$work/scripts/gates/data/slow-scoped.txt" ]; then
  printf 'NOT MEASURED %-32s the file is still readable after chmod 000 (root?)\n' slow-scoped-unreadable
  skipped=$((skipped+1))
else
  rc=0; out="$(EHS_REPO_ROOT="$work" bash "$GATE" 2>&1)" || rc=$?
  if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q "cannot be read"; then
    printf 'ok       %-36s rc=2\n' slow-scoped-unreadable; pass=$((pass+1))
  else
    printf 'FAILED   %-36s rc=%s (wanted 2)\n' slow-scoped-unreadable "$rc"; fail=$((fail+1))
  fi
fi
chmod 644 "$work/scripts/gates/data/slow-scoped.txt" 2>/dev/null || true

# ------------------------------------------------- and one more that must PASS
# The lane found through an --only GLOB rather than the literal name: this is
# the shape ci.yml uses for the expensive controls, and a gate that only knew
# literal names would report a hole where there is a job.
case_run lane-through-an-only-glob 0 "have a lane that names them" '
import os, pathlib
w = pathlib.Path(os.environ["EHS_WORK"])
(w / "scripts/gates/data/slow-scoped.txt").write_text("gate-gamma.sh\n")
wf = w / ".github/workflows/ci.yml"
wf.write_text(wf.read_text().replace("--only \x27gate-beta.sh\x27", "--only \x27gate-*\x27"))'

echo
echo "Summary: $pass ok, $fail failures, $skipped not measured"
if [ "$fail" -gt 0 ]; then
  echo "Result: FAILED."
  exit 1
fi
echo "Result: OK. The gate fails when a declared lane is deleted, when the only mention"
echo "        is a comment, when a --skip stands in for a lane, when a glob resolves to"
echo "        nothing and when an exemption outlives its reason; and it reports"
echo "        could-not-measure instead of passing when it cannot read the declarations."
exit 0
