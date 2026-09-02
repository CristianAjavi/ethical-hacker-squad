#!/usr/bin/env bash
# Self-test for gate-scope-contract.sh. Each case breaks one thing on a
# throwaway copy of the tree — a fixture, a sidecar, the schema, the doc, or the
# measurement core — and asserts BOTH the exit code and the reason given.
#
# The exit code alone is not enough. A gate that returns 1 because it crashed
# and a gate that returns 1 because it found something look identical from the
# outside, which is how eleven gates in this repo once reported a crash as a
# measured failure. Every case here names the sentence it expects.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-scope-contract.sh"
if [ -n "${EHS_REPO_ROOT:-}" ]; then SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then :
else SRC="$(cd "$HERE/../.." && pwd)"; fi
command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
[ -f "$GATE" ] || { echo "UNMEASURABLE the gate under test is missing: $GATE"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-scope-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
F="scripts/gates/fixtures/scope"
R="skills/ethical-hacker-squad/references"
GOOD="$F/good/01-both-directions-clean.json"

# $1 name  $2 wanted rc  $3 needle  $4 python mutation  $5 "lab" to run the
# copied gate instead of this one (only the crash case needs that: the shipped
# gate resolves its core beside itself, so a mutated core is invisible to it).
case_run() {
  local name="$1" want="$2" needle="$3" mutation="$4" which="${5:-}" work="$TMP/$1"
  rm -rf "$work"; mkdir -p "$work"
  (cd "$SRC" && tar --exclude .git --exclude __pycache__ -cf - .) | (cd "$work" && tar -xf -)
  if [ -n "$mutation" ] && ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
    printf 'HARNESS  %-42s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
  fi
  local runner="$GATE"
  [ "$which" = "lab" ] && runner="$work/scripts/gates/gate-scope-contract.sh"
  local out rc
  out="$(EHS_REPO_ROOT="$work" bash "$runner" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -qF -- "$needle"; }; then
    printf 'ok       %-42s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-42s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -6; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-scope-contract.sh (source: $SRC) ==="

case_run control-untouched-fixtures 0 "in both directions" ""

# ---- direction 1: nothing touched may sit outside the authorisation ---------
case_run a-finding-outside-the-authorisation 1 "matches no authorised target" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$GOOD"'"
d=json.loads(p.read_text()); d["findings"][0]["location"]["path"]="scripts/deploy.sh"
p.write_text(json.dumps(d,indent=2))'

case_run a-finding-inside-an-exclusion 1 "which the scope excludes" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$GOOD"'"
d=json.loads(p.read_text()); d["findings"][0]["location"]["path"]="infra/terraform/main.tf"
p.write_text(json.dumps(d,indent=2))'

case_run the-coverage-list-walked-out-of-scope 1 "matches no authorised target" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$GOOD"'"
d=json.loads(p.read_text()); d["engagement"]["coverage"]["read"].append("vendor/x.py")
p.write_text(json.dumps(d,indent=2))'

# A `*` that quietly crossed a separator would authorise a whole subtree nobody
# named, and an exclusion written the same way would cover more than it says.
case_run a-single-star-must-not-cross-a-separator 1 "matches no authorised target" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$GOOD"'"
d=json.loads(p.read_text()); s=d["engagement"]["scope"]
s["authorized"][0]["target"]="routes/*"; s["examined"][0]["target"]="routes/*"
d["findings"][0]["location"]["path"]="routes/v2/invoices.py"
d["engagement"]["coverage"]={"inventoried":[],"read":[],"not_read":[]}
p.write_text(json.dumps(d,indent=2))'

# ---- direction 2: nothing authorised may go unaccounted for ----------------
case_run an-authorised-target-nobody-accounted-for 1 "does not account for it" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$GOOD"'"
d=json.loads(p.read_text()); d["engagement"]["scope"]["examined"].pop()
p.write_text(json.dumps(d,indent=2))'

case_run not-examined-without-its-reason 1 "does not say why" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$GOOD"'"
d=json.loads(p.read_text())
d["engagement"]["scope"]["examined"][1]={"target":"lib/**","outcome":"not-examined"}
p.write_text(json.dumps(d,indent=2))'

case_run examined-something-nobody-authorised 1 "nobody authorised it" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$GOOD"'"
d=json.loads(p.read_text())
d["engagement"]["scope"]["examined"].append({"target":"infra/terraform/**","outcome":"examined"})
p.write_text(json.dumps(d,indent=2))'

# A run that reports nothing is where a silent gap hides best, so direction 2
# has to keep working with the findings list emptied out.
case_run no-findings-does-not-excuse-direction-two 1 "does not account for it" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$GOOD"'"
d=json.loads(p.read_text()); d["findings"]=[]
d["engagement"]["coverage"]={"inventoried":[],"read":[],"not_read":[]}
d["engagement"]["scope"]["examined"].pop()
p.write_text(json.dumps(d,indent=2))'

# ---- the fixtures have to keep earning their place -------------------------
case_run a-bad-fixture-that-no-longer-fails 1 "proves nothing" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$F"'/bad/01-a-finding-outside-the-authorisation.json"
d=json.loads(p.read_text()); d["findings"][0]["location"]["path"]="routes/invoices.py"
p.write_text(json.dumps(d,indent=2))'

case_run a-bad-fixture-without-its-sidecar 1 "no .expected sidecar" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"'"$F"'/bad/02-touched-what-the-scope-excludes.expected").unlink()'

case_run a-bad-fixture-red-for-the-wrong-reason 1 "for the wrong reason" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$F"'/bad/02-touched-what-the-scope-excludes.expected"
p.write_text("a defect this fixture does not have\n")'

# ---- could not measure: never a pass, never a clean scope ------------------
case_run a-scope-still-in-the-legacy-string 2 "unreconcilable" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$GOOD"'"
d=json.loads(p.read_text()); d["engagement"]["scope"]="/srv/example-api"
p.write_text(json.dumps(d,indent=2))'

case_run an-artifact-that-will-not-parse 2 "unreadable" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"'"$GOOD"'").write_text("{ not json")'

case_run the-schema-loses-the-declaration 2 "does not exist" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'/findings.schema.json"
d=json.loads(p.read_text()); d.pop("$defs"); p.write_text(json.dumps(d,indent=2))'

case_run the-schema-will-not-parse 2 "schema is unreadable" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'/findings.schema.json").write_text("{ not json")'

case_run the-documented-contract-is-gone 2 "undocumented" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'/scope.md").unlink()'

case_run no-fixtures-and-no-artifact 2 "no fixtures under" '
import os,pathlib,shutil
shutil.rmtree(pathlib.Path(os.environ["EHS_WORK"])/"'"$F"'")'

# A core that falls over exits 1, the same 1 a measured failure uses. The gate
# has to tell them apart by whether anything was actually named.
case_run a-core-that-crashes-names-nothing 2 "crash, not a verdict" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/lib/scope_contract.py"
p.write_text("import sys\nraise SystemExit(1)\n")' lab

# ---- and the arguments, which are the other way in ------------------------
out="$(bash "$GATE" --deliverable 2>&1)"; rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -qF -- "needs a path"; then
  printf 'ok       %-42s rc=2\n' "deliverable-with-no-path"; pass=$((pass+1))
else
  printf 'FAILED   %-42s rc=%s (wanted 2)\n' "deliverable-with-no-path" "$rc"; fail=$((fail+1))
fi

out="$(bash "$GATE" --while-youre-at-it 2>&1)"; rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -qF -- "unknown argument"; then
  printf 'ok       %-42s rc=2\n' "an-argument-nobody-defined"; pass=$((pass+1))
else
  printf 'FAILED   %-42s rc=%s (wanted 2)\n' "an-argument-nobody-defined" "$rc"; fail=$((fail+1))
fi

echo "--- $pass passed, $fail failed ---"
[ "$fail" -eq 0 ] || exit 1
exit 0
