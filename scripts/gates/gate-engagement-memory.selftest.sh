#!/usr/bin/env bash
# Self-test for gate-engagement-memory.sh. Each case breaks exactly one thing on a
# throwaway copy and asserts the exit code AND the reason. The needle has to name
# something only that fixture can produce: a correct rc for the wrong reason has
# cost this repository four times now, and a battery that stops measuring looks
# exactly like a clean run.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-engagement-memory.sh"
if [ -n "${EHS_REPO_ROOT:-}" ]; then SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then :
else SRC="$(cd "$HERE/../.." && pwd)"; fi

command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-memory-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
V="skills/ethical-hacker-squad/references/vocabulary.md"
S="skills/ethical-hacker-squad/references/findings.schema.json"
D="skills/ethical-hacker-squad/references/findings-artifact.md"
G="scripts/gates/fixtures/findings"

case_run() {
  local name="$1" want="$2" needle="$3" mutation="$4" work="$TMP/$1"
  rm -rf "$work"; mkdir -p "$work"
  (cd "$SRC" && tar --exclude .git --exclude __pycache__ -cf - .) | (cd "$work" && tar -xf -)
  if [ -n "$mutation" ] && ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
    printf 'HARNESS  %-46s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
  fi
  local out rc
  out="$(EHS_REPO_ROOT="$work" bash "$GATE" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -qF -- "$needle"; }; then
    printf 'ok       %-46s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-46s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -6; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-engagement-memory.sh (source: $SRC) ==="

# The control. Without it a battery that stopped measuring reads as a clean run.
case_run control-untouched-tree 0 "the memory contract holds" ""

# --- the vocabulary this gate reasons about --------------------------------
case_run baseline-state-dimension-deleted 2 'declares no region for `baseline_state`' '
import os,pathlib,re
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$V"'"
s=p.read_text()
n=re.subn(r"<!-- vocabulary:declare baseline_state -->.*?<!-- /vocabulary:declare -->","",s,flags=re.S)
assert n[1]==1
p.write_text(n[0])'

case_run the-unmeasured-term-retired 2 "no longer declares 'unmeasured'" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$V"'"
s=p.read_text()
assert s.count("| `unmeasured` |")==1
p.write_text(s.replace("| `unmeasured` |","| `unknown` |",1))'

case_run the-not-measured-disposition-retired 2 "no longer declares 'not measured'" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$V"'"
s=p.read_text()
assert s.count("| `not measured` |")==1
p.write_text(s.replace("| `not measured` |","| `pending` |",1))'

case_run a-declared-term-no-fixture-ever-writes 1 "no fixture ever writes 'abandoned'" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$V"'"
s=p.read_text()
a="<!-- /vocabulary:declare -->"
i=s.index("| `unmeasured` |"); j=s.index("\n",i)+1
p.write_text(s[:j]+"| `abandoned` | Nobody writes this. | Against everything: it is decoration. |\n"+s[j:])'

# --- the decision the whole design rests on --------------------------------
# A key built on a line number moves when a comment is inserted above the defect,
# and then every rebase reports the whole tree as new findings.
case_run a-key-that-may-be-built-on-a-line 1 "is the one input this algorithm exists to exclude" '
import json,os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$S"'"
d=json.loads(p.read_text())
e=d["properties"]["findings"]["items"]["properties"]["fingerprint"]["properties"]["inputs"]["items"]["enum"]
e.append("location.line")
p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+"\n")'

# The constraint the roadmap item was written with: a carried-over entry is the
# only record of a defect that LEFT the live list, so it is the only place the
# audit trail can end. Drop the requirement and the store can say a defect was
# fixed without saying what found it - and every other gate stays green.
case_run carried-over-stops-naming-its-procedure 1 "no longer requires \`procedure\`" '
import json,os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$S"'"
d=json.loads(p.read_text())
r=d["properties"]["carried_over"]["items"]["required"]
assert "procedure" in r
r.remove("procedure")
p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+"\n")'

case_run the-algorithm-renamed 1 "is no longer \`ehs.fp/v1\`" '
import json,os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$S"'"
d=json.loads(p.read_text())
a=d["properties"]["findings"]["items"]["properties"]["fingerprint"]["properties"]["algorithm"]
a["const"]="ehs.fp/v2"
p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+"\n")'

case_run the-algorithm-stops-saying-how-it-joins 1 "stops being specified stops being reproducible" '
import json,os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$S"'"
d=json.loads(p.read_text())
a=d["properties"]["findings"]["items"]["properties"]["fingerprint"]["properties"]["algorithm"]
assert "U+001F" in a["description"]
a["description"]=a["description"].replace("U+001F","a separator")
p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+"\n")'

# --- the numbering of the rules --------------------------------------------
case_run an-invariant-retired-leaving-a-gap 1 "which is not 1.." '
import os,pathlib,re
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$D"'"
s=p.read_text()
assert s.count("\n25. **")==1
p.write_text(s.replace("\n25. **","\n30. **",1))'

# --- the corpus that exercises it ------------------------------------------
# Each of these reaches zero through a state someone can actually create, and each
# such state retires a control while every other gate stays green. That is not
# "I checked nothing": it is a control withdrawn in silence, so it exits 2.
case_run every-v2-fixture-deleted 2 "not one fixture declares" '
import json,os,pathlib
r=pathlib.Path(os.environ["EHS_WORK"])/"'"$G"'"
n=0
for p in r.rglob("*.json"):
    try: d=json.loads(p.read_text())
    except Exception: continue
    if isinstance(d,dict) and isinstance(d.get("engagement"),dict) and "baseline" in d["engagement"]:
        p.unlink(); n+=1
        s=p.with_suffix(".expected")
        if s.exists(): s.unlink()
assert n>0'

case_run no-fixture-continues-a-baseline 2 "the whole matching half of the contract was never exercised" '
import json,os,pathlib
r=pathlib.Path(os.environ["EHS_WORK"])/"'"$G"'"
n=0
for p in r.rglob("*.json"):
    try: d=json.loads(p.read_text())
    except Exception: continue
    if not isinstance(d,dict): continue
    for f in d.get("findings") or []:
        if isinstance(f,dict) and f.pop("lineage",None) is not None: n+=1
    p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+"\n")
assert n>0'

case_run the-colliding-pair-pulled-apart 2 "\`ordinal\` was never asked to break a tie" '
import json,os,pathlib
r=pathlib.Path(os.environ["EHS_WORK"])/"'"$G"'"
n=0
for p in r.rglob("*.json"):
    try: d=json.loads(p.read_text())
    except Exception: continue
    if not isinstance(d,dict): continue
    for f in d.get("findings") or []:
        if isinstance(f,dict) and f.get("id")=="F-003" and f.pop("fingerprint",None) is not None: n+=1
    p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+"\n")
assert n>0'

case_run the-carried-over-list-emptied 2 "vanished in silence" '
import json,os,pathlib
r=pathlib.Path(os.environ["EHS_WORK"])/"'"$G"'"
n=0
for p in r.rglob("*.json"):
    try: d=json.loads(p.read_text())
    except Exception: continue
    if isinstance(d,dict) and d.get("carried_over"):
        d["carried_over"]=[]; n+=1
        p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+"\n")
assert n>0'

case_run a-fingerprint-that-stops-reproducing 1 "do not reproduce from the fields their \`inputs\` name" '
import json,os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$G"'"/"good/02-carrying-its-memory.json"
d=json.loads(p.read_text())
f=[x for x in d["findings"] if x["id"]=="F-002"][0]
f["fingerprint"]["value"]="sha256:"+"0"*64
p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+"\n")'

# The trap this battery walked into once already, in the severity gate: case_run
# invokes $HERE/gate-*.sh - the SOURCE tree's wrapper - against a copied root, so
# `$HERE/lib/...` resolves to the REAL core and deleting the copy's core proves
# nothing. This case has to run the COPY's own wrapper.
core_missing() {
  local work="$TMP/core-missing"
  rm -rf "$work"; mkdir -p "$work"
  (cd "$SRC" && tar --exclude .git --exclude __pycache__ -cf - .) | (cd "$work" && tar -xf -)
  rm -f "$work/scripts/gates/lib/engagement_memory.py"
  local out rc
  out="$(EHS_REPO_ROOT="$work" bash "$work/scripts/gates/gate-engagement-memory.sh" 2>&1)"; rc=$?
  if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -qF -- "the measurement core is missing"; then
    printf 'ok       %-46s rc=%s\n' "core-missing" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-46s rc=%s (wanted 2)\n' "core-missing" "$rc"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -6; fail=$((fail+1))
  fi
}
core_missing

echo "--- $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
