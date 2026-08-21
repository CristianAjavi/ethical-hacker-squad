#!/usr/bin/env bash
# Self-test for gate-secret-scan.sh. Each case plants one thing on a throwaway
# copy and asserts the exit code and the reason. The tokens below are synthetic
# and inert: format-shaped strings that were never issued by anyone, and every one
# of them is ASSEMBLED at runtime rather than written here - a secret scanner that
# has to skip its own test file is a scanner with a blind spot.
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-secret-scan.sh"
if [ -n "${EHS_REPO_ROOT:-}" ]; then SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then :
else SRC="$(cd "$HERE/../.." && pwd)"; fi
command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-secrets-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

case_run() {
  local name="$1" want="$2" needle="$3" mutation="$4" work="$TMP/$1"
  rm -rf "$work"; mkdir -p "$work"
  (cd "$SRC" && tar --exclude .git --exclude __pycache__ -cf - .) | (cd "$work" && tar -xf -)
  if [ -n "$mutation" ] && ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
    printf 'HARNESS  %-38s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
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

echo "=== self-test: gate-secret-scan.sh (source: $SRC) ==="

case_run control-untouched-repo 0 "no credential in the tree" ""

case_run aws-key-in-the-tree 1 "aws-access-key-id" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"docs/notes.md").write_text(
  "deploy with AKI" + "A" + "Q7ABCDEFGH" + "IJKLMN" + "\n")'

case_run private-key-block 1 "private-key-block" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"deploy.key").write_text(
  "-" * 5 + "BEGIN OPENSSH PRIVATE " + "KEY" + "-" * 5 + "\nnot a real key\n")'

case_run inert-marker-is-not-a-finding 0 "no credential in the tree" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"docs/example.md").write_text(
  "STRIPE_KEY=sk" + "_test_" + "0" * 24 + "  # example value\n")'

case_run secret-in-the-bench-nobody-planted 1 "the exclusion would be hiding" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"bench/cases/express-invoices/lib/keys.js"
p.write_text("const token = \"acme_live_" + "b" * 30 + "\";\n")'

case_run bench-key-unreadable 2 "" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"bench/ground-truth.json").write_text("{ not json")'

case_run tree-gone 2 "" '
import os,shutil,pathlib
shutil.rmtree(pathlib.Path(os.environ["EHS_WORK"]))'

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. The gate finds published formats, ignores inert markers, refuses to let"
echo "        the bench exclusion hide an undeclared secret, and reports what it did not scan."
exit 0
