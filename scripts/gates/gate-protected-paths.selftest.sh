#!/usr/bin/env bash
# Self-test for gate-protected-paths.sh. Each case breaks exactly one thing on a
# throwaway copy and asserts the exit code AND the reason, including a control on
# the untouched repository and three cases that must report could-not-measure.
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-protected-paths.sh"
if [ -n "${EHS_REPO_ROOT:-}" ]; then SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then :
else SRC="$(cd "$HERE/../.." && pwd)"; fi
command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-protected-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# case <name> <branch> <files, one per line> <expected rc> <needle> <mutation>
case_run() {
  local name="$1" branch="$2" files="$3" want="$4" needle="$5" mutation="$6" work="$TMP/$1"
  rm -rf "$work"; mkdir -p "$work"
  (cd "$SRC" && tar --exclude .git --exclude __pycache__ -cf - .) | (cd "$work" && tar -xf -)
  if [ -n "$mutation" ] && ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
    printf 'HARNESS  %-40s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
  fi
  local list="$work/.changed"
  printf '%s\n' "$files" > "$list"
  local out rc args
  args=(--changed-files "$list")
  [ "$branch" = "NONE" ] || args+=(--branch "$branch")
  [ "$files" = "NOLIST" ] && args=(--branch "$branch" --changed-files "$work/.missing")
  # Hermetic on purpose. On a CI runner GITHUB_HEAD_REF and GITHUB_BASE_REF are
  # set, and the gate reads them as defaults - so a case meant to prove "I cannot
  # tell whose branch this is" silently got told, passed locally and failed on the
  # runner. A battery that inherits the environment is not proving what it claims.
  out="$(env -u GITHUB_HEAD_REF -u GITHUB_BASE_REF -u BASE_REF -u CHANGED_FILES_FILE \
        EHS_REPO_ROOT="$work" bash "$GATE" "${args[@]}" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf 'ok       %-40s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-40s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -5; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-protected-paths.sh (source: $SRC) ==="

case_run automation-touches-nothing-protected bot/knowledge-loop \
  'skills/ethical-hacker-squad/references/knowledge/web-api.md' 0 "no protected path" ""

case_run automation-edits-a-gate bot/knowledge-loop \
  'scripts/gates/gate-secret-scan.sh' 1 "an automation that can edit its own limits has none" ""

case_run automation-edits-the-manifest bot/refresh \
  '.claude-plugin/plugin.json' 1 "protected by \`.claude-plugin/\*\*\`" ""

case_run automation-edits-the-allowlist bot/refresh \
  'docs/sources-allowlist.json' 1 "docs/sources-allowlist.json" ""

case_run human-may-touch-them-and-is-listed feat/whatever \
  'scripts/gates/gate-secret-scan.sh' 0 "allowed and listed so the reviewer knows" ""

case_run documented-list-drifts-from-the-enforced-one bot/x \
  'README.md' 1 "the documented G7 list and" '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"docs/gate-requirements.md"
p.write_text(p.read_text().replace("NOTICE.md\n```","```",1))'

case_run enforced-list-grows-without-the-doc bot/x \
  'README.md' 1 "the documented G7 list and" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/data/protected-paths.json"
d=json.loads(p.read_text()); d["paths"].append("SECURITY.md"); p.write_text(json.dumps(d,indent=2))'

case_run branch-unknown NONE \
  'README.md' 2 "" '
import os,pathlib,shutil
# make the work tree not a repository, so the gate cannot fall back to git
shutil.rmtree(pathlib.Path(os.environ["EHS_WORK"])/".git", ignore_errors=True)'

case_run changed-file-list-missing bot/x NOLIST 2 "" ""

case_run data-file-unusable bot/x 'README.md' 2 "" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/data/protected-paths.json").write_text("{")'

echo
echo "Summary: $pass ok, $fail failures"
if [ "$fail" -eq 0 ]; then
  echo "Result: OK. An automated branch cannot touch the limits, a human branch can and is"
  echo "        listed, the rule and its documentation cannot drift, and a missing branch or"
  echo "        file list is could-not-measure rather than a pass."
  exit 0
fi
exit 1
