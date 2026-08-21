#!/usr/bin/env bash
# Self-test for score.py. A scorer that cannot tell a perfect run from a bad one
# is a number generator, so each case builds a synthetic findings artifact from
# the answer key and asserts what the scorer says about it.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SCORE="$HERE/score.py"
KEY="$ROOT/bench/ground-truth.json"
command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
[ -f "$KEY" ] || { echo "UNMEASURABLE the answer key is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-score-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# build <mode> <out> — synthesise an artifact from the key
build() {
  EHS_KEY="$KEY" EHS_MODE="$1" EHS_OUT="$2" python3 - <<'PY'
import json, os
key = json.loads(open(os.environ["EHS_KEY"]).read())
mode = os.environ["EHS_MODE"]
items = list(key["planted"])
if mode == "one-missed":
    items = items[:-1]
findings = []
for i, it in enumerate(items, 1):
    findings.append({
        "id": f"F-{i:03d}",
        "title": f"{it['class']} in {it['symbol']}",
        "procedure": it["procedure"],
        "status": "confirmed",
        "severity": "high",
        "confidence": "high",
        "location": {"path": f"bench/cases/{it['case']}/{it['path']}"},
        "evidence": f"Read at {it['symbol']}.",
        "impact": "impact",
        "recommendation": "fix",
        "traceability": ["CWE-20"],
        "triage": [{"rule": "FP-01", "answer": "DOES_NOT_HOLD"}],
    })
if mode == "decoy-reported":
    d = key["decoys"][0]
    findings.append({
        "id": "F-900",
        "title": f"looks like {d['looks_like']} in {d['symbol']}",
        "procedure": d["looks_like"],
        "status": "confirmed",
        "severity": "medium",
        "confidence": "medium",
        "location": {"path": f"bench/cases/{d['case']}/{d['path']}"},
        "evidence": f"Read at {d['symbol']}.",
        "impact": "impact",
        "recommendation": "fix",
        "traceability": ["CWE-20"],
        "triage": [{"rule": r, "answer": "DOES_NOT_HOLD"} for r in d["ruled_out_by"]],
    })
if mode == "near-miss":
    # points at the decoy that sits next to a planted defect
    findings = [f for f in findings if "write_token" not in f["title"]]
    findings.append({
        "id": "F-901",
        "title": "credential file in write_token_privately",
        "procedure": "LOC-08",
        "status": "confirmed",
        "severity": "low",
        "confidence": "medium",
        "location": {"path": "bench/cases/cli-packer/packer.py"},
        "evidence": "Read at write_token_privately.",
        "impact": "impact",
        "recommendation": "fix",
        "traceability": ["CWE-732"],
        "triage": [{"rule": "FP-06", "answer": "DOES_NOT_HOLD"}],
    })
open(os.environ["EHS_OUT"], "w").write(json.dumps(
    {"schema_version": "ehs.findings/v1",
     "engagement": {"scope": "bench", "mode": "audit", "language": "en", "generated_by": "selftest"},
     "findings": findings}, indent=2))
PY
}

expect() {  # <name> <mode> <needle> [extra args...]
  local name="$1" mode="$2" needle="$3"; shift 3
  local art="$TMP/$name.json"
  build "$mode" "$art"
  local out; out="$(python3 "$SCORE" --findings "$art" "$@" 2>&1)"
  if printf '%s' "$out" | grep -q -- "$needle"; then
    printf 'ok       %-28s %s\n' "$name" "$needle"; pass=$((pass+1))
  else
    printf 'FAILED   %-28s expected %s\n' "$name" "$needle"
    printf '%s\n' "$out" | sed 's/^/         /' | head -8; fail=$((fail+1))
  fi
}

echo "=== self-test: scripts/bench/score.py ==="
expect perfect-run        perfect        "recall 100%"
expect one-missed         one-missed     "recall 90%"
expect decoy-reported     decoy-reported "decoys reported 1"
expect near-miss-is-not-a-hit near-miss  "recall 90%"

# thresholds turn measuring into judging, and only when asked
build one-missed "$TMP/th.json"
python3 "$SCORE" --findings "$TMP/th.json" --min-recall 0.95 >/dev/null 2>&1
if [ $? -eq 1 ]; then printf 'ok       %-28s threshold fails a short run\n' threshold-enforced; pass=$((pass+1))
else printf 'FAILED   %-28s threshold did not fail\n' threshold-enforced; fail=$((fail+1)); fi

python3 "$SCORE" --findings "$TMP/does-not-exist.json" >/dev/null 2>&1
if [ $? -eq 2 ]; then printf 'ok       %-28s missing artifact is 2\n' unmeasurable-artifact; pass=$((pass+1))
else printf 'FAILED   %-28s missing artifact was not 2\n' unmeasurable-artifact; fail=$((fail+1)); fi

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. The scorer separates a perfect run, a short run, a decoy reported"
echo "        and a near miss, and refuses to score what it cannot read."
exit 0
