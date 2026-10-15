#!/usr/bin/env bash
# scripts/ehs.selftest.sh — Self-test for scripts/ehs CLI tool.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EHS="$HERE/ehs"

pass=0
fail=0

check() {
  local name="$1" cmd="$2" want_rc="$3" needle="$4"
  local out rc=0
  out=$(eval "$cmd" 2>&1) || rc=$?
  local ok=0

  if [ "$rc" -ne "$want_rc" ]; then
    ok=1
  fi
  if [ -n "$needle" ] && ! echo "$out" | grep -q "$needle"; then
    ok=1
  fi

  if [ "$ok" -eq 0 ]; then
    printf 'ok       %-38s rc=%s\n' "$name" "$rc"
    pass=$((pass + 1))
  else
    printf 'FAILED   %-38s rc=%s (wanted rc=%s, needle=%s)\n' "$name" "$rc" "$want_rc" "$needle"
    printf '%s\n' "$out" | sed 's/^/         /' | head -n 5
    fail=$((fail + 1))
  fi
}

echo "=== self-test: scripts/ehs CLI ==="

check "stats-command-reports-total" "$EHS stats" 0 "TOTAL"
check "list-command-returns-0" "$EHS list" 0 "WEB-01"
check "list-filter-by-pack" "$EHS list ai-safety" 0 "AI-01"
check "show-valid-procedure" "$EHS show AI-08" 0 "Where to look"
check "show-invalid-procedure" "$EHS show FAKE-99" 1 "not found"
check "search-finds-mcp" "$EHS search mcp" 0 "AI-08"
check "search-empty-returns-0" "$EHS search xyznonexistentquery123" 0 "No procedures found"

# sarif: the conforming fixture has four findings, one of them a duplicate.
FX="$HERE/gates/fixtures/findings"
check "sarif-maps-a-conforming-artifact" "$EHS sarif $FX/good/01-conforming.json" 0 '"version": "2.1.0"'
check "sarif-drops-the-duplicate" "$EHS sarif $FX/good/01-conforming.json | grep -c '\"ruleId\"'" 0 "^3$"
check "sarif-carries-a-github-severity" "$EHS sarif $FX/good/01-conforming.json" 0 '"security-severity": "8.0"'
check "sarif-refuses-an-unredacted-secret" "$EHS sarif $FX/bad/08-secret-in-the-evidence.json" 1 "unredacted secret"
check "sarif-refuses-what-is-not-json" "$EHS sarif $HERE/ehs.selftest.sh" 2 "cannot read"

# The SARIF 2.1.0 rules the first version broke, and the fields GitHub reads.
TMPD="$(mktemp -d "${TMPDIR:-/tmp}/ehs-selftest-XXXXXX")"; trap 'rm -rf "$TMPD"' EXIT
PY='import json,sys; r=json.load(sys.stdin)["runs"][0]'
check "sarif-review-carries-level-none" \
  "$EHS sarif $FX/good/01-conforming.json | python3 -c '$PY; nf=[x for x in r[\"results\"] if x[\"kind\"]!=\"fail\"]; print(len(nf), all(x[\"level\"]==\"none\" for x in nf))'" 0 "^1 True$"
check "sarif-tags-the-cwe-for-github" "$EHS sarif $FX/good/01-conforming.json" 0 '"external/cwe/cwe-639"'
check "sarif-every-rule-carries-help" \
  "$EHS sarif $FX/good/01-conforming.json | python3 -c '$PY; print(all(x[\"help\"][\"text\"] for x in r[\"tool\"][\"driver\"][\"rules\"]))'" 0 "^True$"
check "sarif-declares-its-category" "$EHS sarif $FX/good/01-conforming.json" 0 '"id": "ethical-hacker-squad/"'
check "sarif-category-is-configurable" "$EHS sarif $FX/good/01-conforming.json --category ehs/web" 0 '"id": "ehs/web/"'

# The fingerprint must survive the code moving: same finding, every line +40.
python3 -c 'import json,sys; d=json.load(open(sys.argv[1]))
for f in d["findings"]:
    if f.get("location",{}).get("line"): f["location"]["line"] += 40
json.dump(d, open(sys.argv[2], "w"))' "$FX/good/01-conforming.json" "$TMPD/moved.json"
FP='import json,sys; print(sorted(x["partialFingerprints"]["ehsFinding/v2"] for x in json.load(sys.stdin)["runs"][0]["results"]))'
check "sarif-fingerprint-ignores-the-line" \
  "[ \"\$($EHS sarif $FX/good/01-conforming.json | python3 -c '$FP')\" = \"\$($EHS sarif $TMPD/moved.json | python3 -c '$FP')\" ] && echo same" 0 "^same$"

# A finding no procedure covers gets a rule per weakness class, not one bucket.
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); d["findings"][0]["procedure"]="ad-hoc"
json.dump(d, open(sys.argv[2], "w"))' "$FX/good/01-conforming.json" "$TMPD/adhoc.json"
check "sarif-ad-hoc-rule-per-cwe" "$EHS sarif $TMPD/adhoc.json" 0 '"ruleId": "ad-hoc/CWE-639"'

# The secret list is shared with the validators. A Stripe key is assembled at
# run time so this file never carries one for the repository's own scan to find.
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); d["findings"][0]["evidence"]="key " + "sk_" + "live_" + "0"*24
json.dump(d, open(sys.argv[2], "w"))' "$FX/good/01-conforming.json" "$TMPD/stripe.json"
check "sarif-refuses-a-stripe-secret-key" "$EHS sarif $TMPD/stripe.json" 1 "stripe-secret-key"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); d["findings"][0]["location"]["path"]="/home/u/app/x.py"
json.dump(d, open(sys.argv[2], "w"))' "$FX/good/01-conforming.json" "$TMPD/abs.json"
check "sarif-refuses-an-absolute-path" "$EHS sarif $TMPD/abs.json" 2 "absolute path"

# prescan: every planted defect of the eval app gets a lead, no correct control does.
SEED="$TMPD/vibe-app"; mkdir -p "$SEED"
( cd "$SEED" && HOME="$TMPD" bash "$HERE/../evals/_fixtures/seed-vibe-app.sh" plain ) >/dev/null 2>&1
LEADS="$($EHS prescan "$SEED" --json 2>/dev/null)"
lead_has() { printf '%s' "$LEADS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(any(l['procedure']==sys.argv[1] and l['path']==sys.argv[2] for l in d['leads']))" "$1" "$2"; }
for pair in "WEB-29 supabase/migrations/0001_init.sql" "WEB-31 supabase/migrations/0001_init.sql" \
            "SUP-27 lib/supabase/admin.ts" "WEB-33 app/actions.ts" "WEB-34 middleware.ts" \
            "WEB-36 app/api/stripe/webhook/route.ts" "WEB-36 app/api/checkout/route.ts" \
            "WEB-35 app/api/cron/charge-trials/route.ts" "AI-19 app/api/chat/route.ts"; do
  set -- $pair
  check "prescan-leads-$1-${2##*/}" "lead_has $1 $2" 0 "^True$"
done
check "prescan-quiet-on-the-correct-route" \
  "printf '%s' \"\$LEADS\" | grep -c 'notes/\[id\]'" 1 "^0$"
check "prescan-quiet-on-the-checked-action" \
  "printf '%s' \"\$LEADS\" | grep -c 'createNote'" 1 "^0$"
check "prescan-refuses-what-is-not-a-dir" "$EHS prescan $HERE/ehs.selftest.sh" 2 "not a directory"

# compare: by fingerprint, so a moved line is not a new finding.
python3 -c 'import json,sys,copy; d=json.load(open(sys.argv[1])); a=copy.deepcopy(d)
a["findings"]=[f for f in a["findings"] if f.get("procedure")!="LOC-14"]
n=copy.deepcopy(a["findings"][0]); n["id"]="F-099"; n["severity"]="critical"
n["location"]={"path":"app/api/new.py","line":3,"component":"new"}; a["findings"].append(n)
json.dump(a,open(sys.argv[2],"w"))' "$FX/good/01-conforming.json" "$TMPD/after.json"
check "compare-names-new-and-gone" "$EHS compare $FX/good/01-conforming.json $TMPD/after.json" 0 "new: 1  gone: 1  persisting: 2"
check "compare-moved-lines-are-not-new" "$EHS compare $FX/good/01-conforming.json $TMPD/moved.json" 0 "new: 0  gone: 0"
check "compare-fails-on-a-new-critical" "$EHS compare $FX/good/01-conforming.json $TMPD/after.json --fail-on high" 1 "new: 1"
FPN="$($EHS compare $FX/good/01-conforming.json $TMPD/after.json --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["new"][0]["fingerprint"])')"
printf '[{"fingerprint":"%s","reason":"accepted, SEC-1","expires":"2099-01-01"}]' "$FPN" > "$TMPD/supp.json"
check "compare-honours-a-suppression" "$EHS compare $FX/good/01-conforming.json $TMPD/after.json --fail-on high --suppress $TMPD/supp.json" 0 "suppressed"
printf '[{"fingerprint":"%s","reason":"accepted, SEC-1","expires":"2000-01-01"}]' "$FPN" > "$TMPD/supp-old.json"
check "compare-an-expired-suppression-hides-nothing" "$EHS compare $FX/good/01-conforming.json $TMPD/after.json --fail-on high --suppress $TMPD/supp-old.json" 1 "expired on 2000-01-01"

# cost: one message written once per content block is counted once.
mkdir -p "$TMPD/projects/p/sid-1/subagents"
for i in 1 2; do printf '{"message":{"id":"m1","model":"model-a","usage":{"input_tokens":10,"cache_creation_input_tokens":100,"cache_read_input_tokens":1000,"output_tokens":5}}}\n'; done > "$TMPD/projects/p/sid-1.jsonl"
printf '{"message":{"id":"s1","model":"model-b","usage":{"input_tokens":1,"cache_creation_input_tokens":2,"cache_read_input_tokens":3,"output_tokens":4}}}\n' > "$TMPD/projects/p/sid-1/subagents/agent-x.jsonl"
printf '{"agentType":"ehs-web-api","description":"web audit"}' > "$TMPD/projects/p/sid-1/subagents/agent-x.meta.json"
check "cost-counts-each-message-once" \
  "$EHS cost --session sid-1 --projects-dir $TMPD/projects --json | python3 -c 'import json,sys; t=json.load(sys.stdin)[\"total\"]; print(t[\"input\"], t[\"cache_read\"], t[\"output\"], t[\"messages\"])'" 0 "^11 1003 9 2$"
check "cost-names-the-subagent" "$EHS cost --session sid-1 --projects-dir $TMPD/projects" 0 "ehs-web-api: web audit"
check "cost-without-a-transcript-is-rc-2" "$EHS cost --session nope --projects-dir $TMPD/projects" 2 "no transcript"

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. scripts/ehs CLI passes all tests."
exit 0
