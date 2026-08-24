#!/usr/bin/env bash
# Self-test for gate-bench-blinding.sh. Each case breaks exactly one thing on a
# throwaway copy and asserts the exit code and the reason. The first case is the
# control, and the last group is the one that matters: the two leaks this gate
# was written from were caught by eye, so each is reproduced as a mutant here.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-bench-blinding.sh"
if [ -n "${EHS_REPO_ROOT:-}" ]; then SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then :
else SRC="$(cd "$HERE/../.." && pwd)"; fi

command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-blind-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
B="bench/runs/2026-08-22-third-competitor/verify/claims.json"

case_run() {
  local name="$1" want="$2" needle="$3" mutation="$4" work="$TMP/$1"
  rm -rf "$work"; mkdir -p "$work"
  (cd "$SRC" && tar --exclude .git --exclude __pycache__ -cf - .) | (cd "$work" && tar -xf -)
  local before after
  before="$(cd "$work" && find bench -type f -exec shasum {} + | shasum)"
  if [ -n "$mutation" ] && ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
    printf 'HARNESS  %-38s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
  fi
  after="$(cd "$work" && find bench -type f -exec shasum {} + | shasum)"
  if [ -n "$mutation" ] && [ "$before" = "$after" ]; then
    printf 'HARNESS  %-38s the mutation was a no-op\n' "$name"; fail=$((fail+1)); return
  fi
  local out rc
  out="$(EHS_REPO_ROOT="$work" bash "$GATE" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf 'ok       %-38s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-38s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -5; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-bench-blinding.sh (source: $SRC) ==="

case_run control-untouched-repo 0 "one location style" ""

# --- the two leaks this gate was written from, reproduced
case_run one-arm-prefixes-its-paths 1 "mixes 2 location styles" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$B"'"
d=json.loads(p.read_text())
for c in d["claims"][:8]: c["file"]="target/"+c["file"]
p.write_text(json.dumps(d,indent=1))'

case_run one-arm-folds-the-line-into-path 1 "mixes 2 location styles" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$B"'"
d=json.loads(p.read_text())
for c in d["claims"][:8]: c["file"]=c["file"]+":"+str(c.get("line") or 1)
p.write_text(json.dumps(d,indent=1))'

# --- the coarser leaks
case_run absolute-path-in-a-location 1 "absolute path" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$B"'"
d=json.loads(p.read_text())
for c in d["claims"]: c["file"]="/home/lab/run/"+c["file"]
p.write_text(json.dumps(d,indent=1))'

case_run arm-word-anywhere-in-the-batch 1 "names the arm" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$B"'"
d=json.loads(p.read_text())
d["claims"][0]["impact"] = d["claims"][0].get("impact","") + " (found while following the mantis pipeline)"
p.write_text(json.dumps(d,indent=1))'

# --- prose may legitimately name an attacker path; that is the finding, not a leak
case_run attacker-path-in-prose-is-not-a-leak 0 "one location style" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$B"'"
d=json.loads(p.read_text())
d["claims"][0]["evidence"] = "the handler writes to /tmp/exfil-payload and /Users/victim/.ssh/id_rsa"
p.write_text(json.dumps(d,indent=1))'

# --- could-not-measure, not a pass
case_run batch-will-not-parse 2 "will not parse" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"'"$B"'").write_text("{not json")'

case_run batch-has-no-claims-list 2 "read nothing" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$B"'"
p.write_text(json.dumps({"rows":[]},indent=1))'

case_run provenance-will-not-parse 2 "could not be classified" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"bench/runs/2026-08-22-third-competitor/keys/provenance.json").write_text("{nope")'

echo "--- $pass passed, $fail failed ---"
[ "$fail" -eq 0 ] || exit 1
exit 0
