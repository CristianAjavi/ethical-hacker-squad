#!/usr/bin/env bash
# Self-test for gate-bench-integrity.sh: each case rots the answer key in one
# specific way and asserts the exit code and the reason.
#
# The rotting happens in ONE work tree that is put back between cases, not in a
# fresh copy per case: the copy cost 0.63 s and the restore costs 0.10 s, and
# twenty-three copies were two thirds of this battery. scripts/gates/lib/
# fixture-tree.sh holds the machinery and the reasoning; what matters here is
# that a shared tree is only safe while something PROVES it came back clean, so
# every case ends with a fingerprint of the whole tree against the pristine one
# and a case that cannot prove it is a harness failure, never a pass.
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-bench-integrity.sh"
if [ -n "${EHS_REPO_ROOT:-}" ]; then SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then :
else SRC="$(cd "$HERE/../.." && pwd)"; fi
command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-bench-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# shellcheck source=scripts/gates/lib/fixture-tree.sh
. "$HERE/lib/fixture-tree.sh" || { echo "UNMEASURABLE lib/fixture-tree.sh is missing"; exit 2; }
fixture_init "$SRC" "$TMP" || exit 2

case_run() {
  local name="$1" want="$2" needle="$3" mutation="$4" work="$FIXTURE_WORK"
  if [ -n "$mutation" ] && ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
    printf 'HARNESS  %-36s the mutation itself failed\n' "$name"; fail=$((fail+1))
    fixture_reset >/dev/null 2>&1 || true
    return
  fi
  local out rc
  out="$(EHS_REPO_ROOT="$work" bash "$GATE" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || grep -q -- "$needle" <<<"$out"; }; then
    printf 'ok       %-36s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-36s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -5; fail=$((fail+1))
  fi
  # The tree the next case is about to receive is only trustworthy if this one
  # gave it back intact, so the proof runs here and not at the end of the file.
  local why
  if ! why="$(fixture_reset)"; then
    printf 'HARNESS  %-36s %s\n' "$name" "$why"; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-bench-integrity.sh (source: $SRC) ==="
echo "    one work tree, restored by $FIXTURE_RESTORE, fingerprinted with $FIXTURE_HASH"

case_run control-untouched-bench 0 "still describes the cases" ""

case_run case-renamed-a-symbol 1 "does not appear there" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"bench/cases/cli-packer/packer.py"
p.write_text(p.read_text().replace("def write_token(","def persist_token("))'

case_run case-file-deleted 1 "does not exist in" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"bench/cases/express-invoices/lib/render.js").unlink()'

case_run key-expects-a-dead-procedure 1 "not a procedure in the corpus" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"bench/ground-truth.json"
d=json.loads(p.read_text()); d["planted"][0]["procedure"]="WEB-99"
p.write_text(json.dumps(d,indent=2))'

case_run decoy-cites-a-dead-rule 1 "triage.md does not declare it" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"bench/ground-truth.json"
d=json.loads(p.read_text()); d["decoys"][0]["ruled_out_by"]=["FP-77"]
p.write_text(json.dumps(d,indent=2))'

case_run case-without-decoys 1 "measures the model" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"bench/ground-truth.json"
d=json.loads(p.read_text())
d["decoys"]=[x for x in d["decoys"] if x["case"]!="cli-packer"]
p.write_text(json.dumps(d,indent=2))'

case_run duplicate-ids 1 "duplicate id" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"bench/ground-truth.json"
d=json.loads(p.read_text()); d["planted"][1]["id"]=d["planted"][0]["id"]
p.write_text(json.dumps(d,indent=2))'

case_run case-labels-its-own-answers 1 "hands the run to the auditor" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"bench/cases/cli-packer/packer.py"
p.write_text(p.read_text().replace("    # Signs a staged bundle","    # Planted: argument injection here\n    # Signs a staged bundle",1))'

case_run span-does-not-contain-its-symbol 1 "is not in that span" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"bench/ground-truth.json"
d=json.loads(p.read_text())
for it in d["planted"]:
    if it["id"]=="P-38": it["lines"]=[13,13]
p.write_text(json.dumps(d,indent=2))'

case_run planted-and-decoy-overlap 1 "a detection and a false positive at the same time" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"bench/ground-truth.json"
d=json.loads(p.read_text())
for it in d["decoys"]:
    if it["id"]=="D-33": it["lines"]=[6,13]
p.write_text(json.dumps(d,indent=2))'

case_run coverage-claim-too-wide 1 "a coverage claim wider than the cases" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"bench/README.md"
p.write_text(p.read_text().replace("the bench exercises `web-api`","the bench exercises `mobile`, `web-api`",1))'

case_run coverage-claim-unmarked 1 "not inside a" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"bench/README.md"
p.write_text(p.read_text().replace("<!-- bench:packs -->","",1))'

case_run coverage-silence-drifts 1 "says the score is silent about" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"bench/README.md"
p.write_text(p.read_text().replace("silent about `mobile` and `remediation`","silent about `remediation`",1))'

case_run comparison-silent-on-outside-information 1 "settles whether sources outside the target" '
import os,pathlib,re
# Strip every trace of the outside-information policy from a round that compares
# arms. That silence is what every round before 2026-08-21 evening carried while
# its recall numbers were being read as if they measured review alone.
w=pathlib.Path(os.environ["EHS_WORK"])/"bench/runs/2026-08-21-weaker-model"
r=w/"README.md"
r.write_text(re.sub(r"Outside information|external-sources|OUTSIDE INFORMATION", "REDACTED", r.read_text()))
for f in (w/"prompts").iterdir():
    if f.is_file():
        f.write_text(re.sub(r"external-sources|OUTSIDE INFORMATION|Outside information",
                            "REDACTED", f.read_text()))'

case_run comparison-states-the-policy 0 "still describes the cases" '
import os,pathlib
# The satisfiable route, proven separately: a round that states the policy in a
# prompt file passes. Without this case the rule could tighten until nothing
# real could meet it and the suite would never notice.
w=pathlib.Path(os.environ["EHS_WORK"])/"bench/runs/2026-08-21-weaker-model"
(w/"prompts"/"outside.txt").write_text("OUTSIDE INFORMATION. Only the files under the target path may be used.")'

case_run comparison-without-its-prompts 1 "neither a prompts/ directory nor the disclosure" '
import os,pathlib,shutil
# The round that DOES archive its prompts, stripped of both escape hatches: no
# prompts/ directory and no line telling the reader they were not kept. That is
# the state every earlier round was in, unnoticed, while its numbers were being
# read as comparable across sittings.
w=pathlib.Path(os.environ["EHS_WORK"])/"bench/runs/2026-08-21-unaided-pass"
shutil.rmtree(w/"prompts")
r=w/"README.md"
r.write_text(r.read_text().replace("run prompts for this round were not kept","PROMPTS WERE KEPT"))'

case_run comparison-discloses-instead 0 "still describes the cases" '
import os,pathlib,shutil
# Same round, prompts gone, but it SAYS so. A number nobody can reproduce is not
# thereby wrong; the rule is that the reader has to be told, not that every old
# round has to be re-run. If this case ever fails, the gate has stopped being
# satisfiable by the nine rounds whose prompts are genuinely gone.
w=pathlib.Path(os.environ["EHS_WORK"])/"bench/runs/2026-08-21-unaided-pass"
shutil.rmtree(w/"prompts")
r=w/"README.md"
t=r.read_text()
r.write_text(t.replace("# Run 2026-08-21", "> The run prompts for this round were not kept.\n\n# Run 2026-08-21",1))'

case_run patch-no-longer-applies 1 "no longer applies" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"bench/cases/cli-packer/packer.py"
p.write_text(p.read_text().replace("        tf.extractall(dest)","        tf.extractall(dest)  # moved",1))'

case_run patch-claims-an-unplanted-defect 1 "not a planted defect" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"bench/patch-truth.json"
d=json.loads(p.read_text()); d["patches"][0]["claims_to_fix"]="P-99"
p.write_text(json.dumps(d,indent=2))'

case_run patch-expects-an-undeclared-verdict 1 "vocabulary.md does not declare" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"bench/patch-truth.json"
d=json.loads(p.read_text()); d["patches"][0]["expected"]="looks fine"
p.write_text(json.dumps(d,indent=2))'

case_run every-patch-is-a-correct-fix 1 "measures agreement, not judgement" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"bench/patch-truth.json"
d=json.loads(p.read_text())
for x in d["patches"]:
    x["expected"]="verified"
p.write_text(json.dumps(d,indent=2))'

case_run key-gone 2 "" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"bench/ground-truth.json").unlink()'

case_run key-unparseable 2 "" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"bench/ground-truth.json").write_text("{ not json")'

# ---------------------------------------------------------------------------
# FOUR CASES THAT HOLD THE REUSED TREE. They live in the library and not here
# because nine batteries have this shape, and a control written nine times is
# nine places for one of them to fall behind unnoticed.
fixture_controls "$SRC"

echo
echo "Summary: $pass passed, $fail failed"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. The gate notices when the key stops describing the cases."
exit 0
