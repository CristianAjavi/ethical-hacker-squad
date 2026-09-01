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

# The commit range and the label are the two signals a branch does not choose,
# so they are the two the harness has to be able to INJECT. The work tree is a
# tar copy with no `.git`, which means git cannot supply them here and every
# case states its own - which is the point: a battery that reads the same signal
# the gate reads from the same place is testing nothing.
#
# case <name> <branch> <files> <expected rc> <needle> <mutation> [<commits>] [<label>]
case_run() {
  local name="$1" branch="$2" files="$3" want="$4" needle="$5" mutation="$6" work="$TMP/$1"
  local commits="${7-}" label="${8--}"
  rm -rf "$work"; mkdir -p "$work"
  (cd "$SRC" && tar --exclude .git --exclude __pycache__ -cf - .) | (cd "$work" && tar -xf -)
  if [ -n "$mutation" ] && ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
    printf 'HARNESS  %-40s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
  fi
  local list="$work/.changed"
  printf '%s\n' "$files" > "$list"
  local out rc args
  args=(--changed-files "$list" --override "$label")
  # `NONE` means "do not pass one at all"; the default `-` means "read and empty",
  # and the gate has to tell those two apart or a blind run reads as a clean one.
  if [ "$commits" = "NONE" ]; then args+=(--authorship -)
  else
    printf '%s\n' "$commits" > "$work/.commits"
    args+=(--authorship "$work/.commits")
  fi
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

case_run unattributed-may-touch-them-and-is-listed feat/whatever \
  'scripts/gates/gate-secret-scan.sh' 0 "UNATTRIBUTED" "" 'deadbee\tAna Ruiz <ana@example.org>\tAna Ruiz <ana@example.org>\t'

# --------------------------------------------------------------------------
# The hole this gate had until 2026-09-01, and the three cases that close it.
# PR #72 raised MAX_TREE_BYTES inside scripts/gates/** on a branch the agent had
# named `loop/...`, and the gate passed it green. Case one is that exact diff.
# --------------------------------------------------------------------------
case_run agent-trailer-on-a-branch-named-anything loop/inference-endpoint \
  'scripts/gates/gate-plugin-integrity.sh' 1 "carries a \`Claude-Session:\` trailer" "" \
  'cafe123\tAna Ruiz <ana@example.org>\tAna Ruiz <ana@example.org>\tClaude-Session: https://claude.ai/code/session_x'

case_run bot-identity-on-a-branch-named-anything feature/deps-bump \
  '.github/workflows/ci.yml' 1 "names \`\[bot\]\` as an author or committer" "" \
  'f00d456\tdependabot[bot] <49699333+dependabot[bot]@users.noreply.github.com>\tGitHub <noreply@github.com>\t'

# The mark can only incriminate. A branch called `bot/` still fails with a
# perfectly human commit range, because an admission is evidence and a denial
# is not - and if this case ever goes green the asymmetry has been lost.
case_run admission-still-counts-with-a-clean-range bot/knowledge-loop \
  'scripts/gates/gate-secret-scan.sh' 1 "reserves for automation" "" 'deadbee\tAna Ruiz <ana@example.org>\tAna Ruiz <ana@example.org>\t'

# --------------------------------------------------------------------------
# Blindness is not innocence. With the range unreadable AND a protected path in
# the diff, half the classifier did not run: 2, never 0.
# --------------------------------------------------------------------------
case_run range-unreadable-and-a-limit-moved feat/whatever \
  'scripts/gates/gate-secret-scan.sh' 2 "cannot say by what" "" 'NONE'

# ...and it is only blindness where it matters. A diff that moves no limit does
# not need the range at all, and a gate that went amber on every such run would
# be a gate people learn to skip.
case_run range-unreadable-but-no-limit-moved feat/whatever \
  'README.md' 0 "no protected path" "" 'NONE'

# --------------------------------------------------------------------------
# The way out, in both directions. It has to work, and it has to be impossible
# to mistake for a pass.
# --------------------------------------------------------------------------
case_run override-label-lets-a-marked-change-through loop/x \
  'scripts/gates/gate-secret-scan.sh' 0 "MOVED BY AN AUTOMATION, WITH CONSENT" "" \
  'cafe123\tAna Ruiz <ana@example.org>\tAna Ruiz <ana@example.org>\tClaude-Session: https://claude.ai/code/session_x' 'override/g7-reviewed'

case_run override-label-does-not-silence-drift loop/x \
  'README.md' 1 "the documented G7 list and" \
  '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"docs/gate-requirements.md"
p.write_text(p.read_text().replace("NOTICE.md\n```","```",1))' \
  'cafe123\tAna Ruiz <ana@example.org>\tAna Ruiz <ana@example.org>\tClaude-Session: https://claude.ai/code/session_x' 'override/g7-reviewed'

case_run override-standing-on-nothing-is-called-out feat/whatever \
  'scripts/gates/gate-secret-scan.sh' 0 "nothing needed it" "" \
  'deadbee\tAna Ruiz <ana@example.org>\tAna Ruiz <ana@example.org>\t' 'override/g7-reviewed'

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
  echo "Result: OK. A change carrying ANY mark of automation - a reserved branch prefix, an"
  echo "        agent trailer, a bot identity - cannot move the limits whatever the branch is"
  echo "        called; an unattributed one can and is listed, and is never called human. A"
  echo "        maintainer label lets a marked change through loudly and does not silence"
  echo "        drift. A missing branch, file list or commit range is could-not-measure."
  exit 0
fi
exit 1
