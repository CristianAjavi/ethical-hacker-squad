#!/usr/bin/env bash
# Self-test for gate-bench-integrity.sh: each case rots the answer key in one
# specific way on a throwaway copy and asserts the exit code and the reason.
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

case_run() {
  local name="$1" want="$2" needle="$3" mutation="$4" work="$TMP/$1"
  rm -rf "$work"; mkdir -p "$work"
  (cd "$SRC" && tar --exclude .git --exclude __pycache__ -cf - .) | (cd "$work" && tar -xf -)
  if [ -n "$mutation" ] && ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
    printf 'HARNESS  %-36s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
  fi
  local out rc
  out="$(EHS_REPO_ROOT="$work" bash "$GATE" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf 'ok       %-36s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-36s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -5; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-bench-integrity.sh (source: $SRC) ==="

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

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. The gate notices when the key stops describing the cases."
exit 0
