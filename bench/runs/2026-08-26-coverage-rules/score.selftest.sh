#!/usr/bin/env bash
# Self-test for this round's scorer, on synthetic reports built from the key.
# A scorer that cannot tell a perfect run from a decoy-only one is a number
# generator, and this one decides a published verdict.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
S="$HERE/score.py"
KEY="${EHS_COV_KEY:-/private/tmp/claude-501/-Users-cristianajavi/9d781ed3-bcf0-48ee-982b-aa1d8b6fbd34/scratchpad/corpus-v2-key.json}"
command -v python3 >/dev/null || { echo "UNMEASURABLE python3 missing"; exit 2; }
[ -f "$S" ]   || { echo "UNMEASURABLE scorer missing"; exit 2; }
[ -f "$KEY" ] || { echo "UNMEASURABLE the corpus key is not on this machine: $KEY"; exit 2; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ pass=$((pass+1)); echo "  PASS  $1"; }
bad(){ fail=$((fail+1)); echo "  FAIL  $1"; }

EHS_KEY="$KEY" EHS_OUT="$TMP" python3 - <<'PY'
import json, os
k=json.load(open(os.environ["EHS_KEY"])); T=os.environ["EHS_OUT"]
def w(name, items, prov=True):
    f=[{"title":i["id"],"class":"c","severity":"high","evidence":"e","impact":"i","recommendation":"r",
        "status":"confirmed",
        "location":{"path":f"{i['case']}/{i['path']}","symbol":i["symbol"],"line":i["line"]}} for i in items]
    d={"findings":f}
    if prov: d["provenance"]={"arm":name}
    json.dump(d, open(f"{T}/{name}.adapted.json","w"))
# ours = perfect, mantis = half, plus a decoy-only third arm is not needed
w("ours", k["planted"]); w("mantis", k["planted"][:len(k["planted"])//2])
for i in (2,3,4):
    w(f"ours{i}" if False else "ours", k["planted"])
PY
# four runs per arm, same content
for a in ours mantis; do for i in 1 2 3 4; do cp "$TMP/$a.adapted.json" "$TMP/$a-$i.adapted.json"; done; rm "$TMP/$a.adapted.json"; done

out="$(python3 "$S" --reports "$TMP" --key "$KEY" 2>&1)"
echo "$out" | grep -q 'ours .*recall 100.0%' && ok "a report naming every planted defect scores 100%" || bad "perfect artifact did not score 100%: $(echo "$out"|grep ours|head -1)"
echo "$out" | grep -q 'MECHANISM' && ok "the mechanism test runs" || bad "no mechanism line"
echo "$out" | grep -qE 'VERDICT: (SUPPORTED|NOT SUPPORTED)' && ok "a verdict is printed" || bad "no verdict"

# decoy-only: recall must collapse, decoys must be counted
EHS_KEY="$KEY" EHS_OUT="$TMP" python3 - <<'PY'
import json, os
k=json.load(open(os.environ["EHS_KEY"])); T=os.environ["EHS_OUT"]
f=[{"title":i["id"],"status":"confirmed","location":{"path":f"{i['case']}/{i['path']}","symbol":i["symbol"],"line":i["line"]}} for i in k["decoys"]]
for i in (1,2,3,4):
    json.dump({"provenance":{"arm":"mantis"},"findings":f}, open(f"{T}/mantis-{i}.adapted.json","w"))
PY
out="$(python3 "$S" --reports "$TMP" --key "$KEY" 2>&1)"
dec="$(echo "$out" | grep '^mantis' | grep -oE 'decoys +[0-9.]+' | grep -oE '[0-9.]+')"
awk -v d="$dec" 'BEGIN{exit !(d>20)}' && ok "a decoy-only arm has its decoys counted ($dec)" || bad "decoys not counted: $dec"
echo "$out" | grep -q 'VERDICT: SUPPORTED' && ok "perfect vs decoy-only is SUPPORTED (decoys not worse)" || bad "expected SUPPORTED here: $(echo "$out"|grep VERDICT)"

# fewer than three valid runs -> 2
rm "$TMP"/ours-2.adapted.json "$TMP"/ours-3.adapted.json
python3 "$S" --reports "$TMP" --key "$KEY" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "an arm below the floor of three valid runs gives rc 2" || bad "expected rc 2, got $rc"

echo; echo "$pass PASS / $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
