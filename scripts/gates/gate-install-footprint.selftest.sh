#!/usr/bin/env bash
# Self-test for gate-install-footprint.sh. Each case seeds one tiny git repository
# carrying exactly one shape, hands the core a policy written for that shape, and
# asserts the exit code AND the reason - plus a control on the untouched
# repository and ten cases that must report could-not-measure.
#
# THE FIXTURES ARE SEEDED, NEVER COPIED. Thirteen batteries in this repository tar
# the whole tree per case and move 258 MB of node_modules to make a point about
# one file. This gate reads the git index and a few bytes per file, so a case here
# is `git init` in a temporary directory with two files in it - and the one case
# that needs 2001 of them writes them with a shell builtin in under a second.
#
# AND NOTHING SEEDED HERE MAY EXIST INSIDE THE REPOSITORY. The gate under test
# reads the tracked tree; a fixture written into `docs/` or `scripts/` would be
# read as a defect of the repository itself, and the gate would spend its first
# red accusing its own battery. That is exactly how the previous gate in this
# family went wrong. Every fixture lives under `mktemp -d`, including the NUL
# bytes, which are produced from /dev/zero so that this file itself stays text.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-install-footprint.sh"
if [ -n "${EHS_REPO_ROOT:-}" ]; then SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then :
else SRC="$(cd "$HERE/../.." && pwd)"; fi
command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
command -v git >/dev/null 2>&1 || { echo "UNMEASURABLE git is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-footprint-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# newrepo <case> - an empty git repository for this case, and nothing else.
newrepo() { mkdir -p "$TMP/$1" && git -C "$TMP/$1" init -q >/dev/null 2>&1; }

# put <case> <relative path> [line...] - one text file, directories included.
put() {
  local dir="$TMP/$1" rel="$2"; shift 2
  mkdir -p "$dir/$(dirname "$rel")"
  printf '%s\n' "$@" > "$dir/$rel"
}

# stage <case> - add everything, ignoring any global excludesFile the developer
# happens to have, because a case that silently staged nothing would report a
# blind zero and read as a measurement.
stage() { git -C "$TMP/$1" add -A -f . >/dev/null 2>&1; }

# policy <name> <json on one line>
policy() { printf '%s\n' "$2" > "$TMP/$1.json"; }

# case_run <name> <expected rc> <needle> [extra gate args...]
#
# The needle is not decoration. A case that asserts only the code cannot tell a
# gate that failed for its reason from one that failed for any other, and this
# repository has already shipped a case that passed by the wrong path.
case_run() {
  local name="$1" want="$2" needle="$3"; shift 3
  local out rc
  out="$(bash "$GATE" --root "$TMP/$name" "$@" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -qF -- "$needle"; }; then
    printf 'ok       %-46s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-46s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -8; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-install-footprint.sh (source: $SRC) ==="

# Two roots is all the shape any of these cases needs: one that forbids the
# execute bit and binaries, and one that allows both.
BASE='{"declared":2,"policies":[{"id":"docs","prefix":"docs/","why":"prose a person reads and nothing executes","extensions":["md"],"executable":false,"binary":false,"exemptions":[]},{"id":"bin","prefix":"bin/","why":"the scripts a user is meant to run","extensions":["sh"],"executable":true,"binary":true,"exemptions":[]}]}'
policy base "$BASE"

# --- the control: the real repository, unmutated -------------------------------
#
# This is the case that decides whether the gate is usable at all. A battery whose
# fixtures leak into the tree turns the gate red on correct files, and a gate whose
# first red accuses the compliant is a gate somebody switches off. Its green is
# load-bearing and it runs first.
out="$(bash "$GATE" --root "$SRC" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  printf 'ok       %-46s rc=0\n' control-the-real-repository; pass=$((pass+1))
else
  printf 'FAILED   %-46s rc=%s (wanted 0)\n' control-the-real-repository "$rc"
  printf '%s\n' "$out" | sed 's/^/         /' | tail -10; fail=$((fail+1))
fi

# --- a tree that is fully declared --------------------------------------------

newrepo clean-tree-covered-to-the-last-file
put clean-tree-covered-to-the-last-file docs/a.md '# a'
put clean-tree-covered-to-the-last-file bin/run.sh '#!/bin/sh' 'true'
chmod +x "$TMP/clean-tree-covered-to-the-last-file/bin/run.sh"
stage clean-tree-covered-to-the-last-file
case_run clean-tree-covered-to-the-last-file 0 "cobertura: 2/2 (100.0%)" --policy "$TMP/base.json"

# --- the failure this gate was built for: nobody declared it -------------------

newrepo a-file-no-policy-claims
put a-file-no-policy-claims docs/a.md '# a'
put a-file-no-policy-claims stray.txt 'who put this here'
stage a-file-no-policy-claims
case_run a-file-no-policy-claims 1 "FINDING  stray.txt" --policy "$TMP/base.json"

# A whole root appearing from nowhere is the shape that actually happens: a
# directory gets added in a pull request, travels to every installed user, and no
# control in the repository has an opinion about it because none of them was
# written to enumerate roots.
newrepo a-root-that-appeared-from-nowhere
put a-root-that-appeared-from-nowhere docs/a.md '# a'
put a-root-that-appeared-from-nowhere telemetry/collect.md '# new root'
stage a-root-that-appeared-from-nowhere
case_run a-root-that-appeared-from-nowhere 1 "FINDING  telemetry/collect.md" --policy "$TMP/base.json"

# --- the three per-file rules, one case each ----------------------------------

newrepo an-extension-outside-the-list
put an-extension-outside-the-list docs/a.md '# a'
put an-extension-outside-the-list docs/notes.txt 'plain text where only md is declared'
stage an-extension-outside-the-list
case_run an-extension-outside-the-list 1 "extension \"txt\" is not one this root declares" --policy "$TMP/base.json"

newrepo an-execute-bit-where-none-is-declared
put an-execute-bit-where-none-is-declared docs/a.md '# a'
chmod +x "$TMP/an-execute-bit-where-none-is-declared/docs/a.md"
stage an-execute-bit-where-none-is-declared
case_run an-execute-bit-where-none-is-declared 1 "the execute bit is set" --policy "$TMP/base.json"

# The NUL bytes come from /dev/zero on purpose: writing them as a literal would
# put a NUL inside this file, which lives under scripts/ and is read by the gate.
newrepo a-binary-where-only-text-is-declared
put a-binary-where-only-text-is-declared docs/a.md '# a'
{ printf 'ELF'; head -c 4 /dev/zero; printf 'tail\n'; } > "$TMP/a-binary-where-only-text-is-declared/docs/blob.md"
stage a-binary-where-only-text-is-declared
case_run a-binary-where-only-text-is-declared 1 "it contains a NUL byte" --policy "$TMP/base.json"

# --- what the gate reads: the git OBJECT, never the work tree ------------------
#
# The mode used to be read from the index and the bytes from `<root>/<path>`, so
# two questions were answered about two different files. Both holes below were
# reproduced on a clone of this repository, and both passed with rc=0.

# A tracked symlink is mode 120000. Its extension is declared, its execute bit is
# not set, and the old NUL check followed the link and answered about the TARGET
# - so the verdict on one commit depended on what sat outside the repository that
# day. What travels here is a pointer, and it resolves on the reader's disk.
newrepo a-tracked-symlink-inside-the-repo
put a-tracked-symlink-inside-the-repo docs/a.md '# a'
ln -s a.md "$TMP/a-tracked-symlink-inside-the-repo/docs/link.md"
stage a-tracked-symlink-inside-the-repo
case_run a-tracked-symlink-inside-the-repo 1 "docs/link.md  policy 'docs': mode 120000 is a symlink" --policy "$TMP/base.json"

# The one that was measured: a link out of the repository altogether.
newrepo a-tracked-symlink-out-of-the-repo
put a-tracked-symlink-out-of-the-repo docs/a.md '# a'
ln -s /etc/passwd "$TMP/a-tracked-symlink-out-of-the-repo/docs/referencia.md"
stage a-tracked-symlink-out-of-the-repo
case_run a-tracked-symlink-out-of-the-repo 1 "docs/referencia.md  policy 'docs': mode 120000 is a symlink" --policy "$TMP/base.json"

# A dangling link has no target to open at all. The exit code IS the assertion
# here: 1 is a verdict, and the 2 that a crash on its way to one would produce
# fails this case.
newrepo a-symlink-whose-target-is-not-there
put a-symlink-whose-target-is-not-there docs/a.md '# a'
ln -s ./nowhere.md "$TMP/a-symlink-whose-target-is-not-there/docs/dangling.md"
stage a-symlink-whose-target-is-not-there
case_run a-symlink-whose-target-is-not-there 1 "docs/dangling.md  policy 'docs': mode 120000 is a symlink" --policy "$TMP/base.json"

# A gitlink brings an entire tree from a repository this one does not control.
# Seeded with update-index rather than a real submodule, and AFTER staging: there
# is no such directory on disk - which is the point - so a later `git add -A`
# would stage its deletion instead.
newrepo a-gitlink-that-drags-in-another-tree
put a-gitlink-that-drags-in-another-tree docs/a.md '# a'
stage a-gitlink-that-drags-in-another-tree
git -C "$TMP/a-gitlink-that-drags-in-another-tree" update-index --add \
  --cacheinfo 160000,0000000000000000000000000000000000000001,vendor/pinned >/dev/null 2>&1
policy withvendor '{"declared":3,"policies":[{"id":"docs","prefix":"docs/","why":"prose a person reads and nothing executes","extensions":["md"],"executable":false,"binary":false,"exemptions":[]},{"id":"bin","prefix":"bin/","why":"the scripts a user is meant to run","extensions":["sh"],"executable":true,"binary":true,"exemptions":[]},{"id":"vendor","prefix":"vendor/","why":"third-party material this repository vendors in and ships exactly as it stands","extensions":["md",""],"executable":false,"binary":false,"exemptions":[]}]}'
case_run a-gitlink-that-drags-in-another-tree 1 "vendor/pinned  policy 'vendor': mode 160000 is a gitlink" --policy "$TMP/withvendor.json"

# The index carries NUL bytes and the work tree carries plain text over them,
# uncommitted. The old reader opened the work tree and passed; the clone that
# reaches the stranger carries the NULs, and now so does the verdict.
newrepo a-nul-blob-under-clean-looking-text
put a-nul-blob-under-clean-looking-text docs/a.md '# a'
{ printf 'ELF'; head -c 4 /dev/zero; printf 'tail\n'; } > "$TMP/a-nul-blob-under-clean-looking-text/docs/blob.md"
stage a-nul-blob-under-clean-looking-text
printf 'nothing to see here, only text\n' > "$TMP/a-nul-blob-under-clean-looking-text/docs/blob.md"
case_run a-nul-blob-under-clean-looking-text 1 "docs/blob.md  policy 'docs': it contains a NUL byte" --policy "$TMP/base.json"

# --- which policy claims a file, and how the coverage figure is printed --------
#
# Three shapes that every other case in this battery is blind to. Measured with a
# bank of 15 mutants against the 17 cases that came before: these were the three
# that survived, and one case each is what kills them.

# A prefix WITHOUT a trailing slash matches by equality, not by prefix. No other
# case here has a policy for a loose file, so swapping that equality for a
# `startswith` passed all seventeen - while handing `LICENSE-APACHE` to the
# policy somebody wrote about `LICENSE`, which is the exact example named in the
# comment on `policy_for`.
newrepo a-loose-prefix-matches-by-equality
put a-loose-prefix-matches-by-equality LICENSE 'MIT, the licence this repository ships under'
put a-loose-prefix-matches-by-equality LICENSE-APACHE 'a second licence nobody wrote a policy about'
stage a-loose-prefix-matches-by-equality
policy loose '{"declared":1,"policies":[{"id":"root-license","prefix":"LICENSE","why":"the licence text at the root of the work tree: one loose file with no extension","extensions":[""],"executable":false,"binary":false,"exemptions":[]}]}'
case_run a-loose-prefix-matches-by-equality 1 "FINDING  LICENSE-APACHE" --policy "$TMP/loose.json"

# The LONGEST matching prefix wins, not the first one in the file. Inert today,
# because no two shipped policies overlap, and letal the day somebody writes a
# stricter rule for a subdirectory: a first-match reader keeps applying the loose
# parent and the stricter child never fires once. The loose parent is listed
# first here on purpose - that is the order in which the mutant is wrong.
newrepo the-longest-prefix-wins-not-the-first
put the-longest-prefix-wins-not-the-first bench/tool.py 'the loose parent declares py, and this file is fine'
put the-longest-prefix-wins-not-the-first bench/cases/x.py 'only the stricter child has an opinion about this one'
stage the-longest-prefix-wins-not-the-first
policy nested '{"declared":2,"policies":[{"id":"bench","prefix":"bench/","why":"the evaluation corpus, where a Python fixture is the normal state and not a surprise","extensions":["py","md"],"executable":true,"binary":true,"exemptions":[]},{"id":"bench-cases","prefix":"bench/cases/","why":"the case material a run reads, which is prose and carries no code at all","extensions":["md"],"executable":false,"binary":false,"exemptions":[]}]}'
case_run the-longest-prefix-wins-not-the-first 1 "FINDING  bench/cases/x.py  policy 'bench-cases'" --policy "$TMP/nested.json"

# Coverage must not round a lost file up to a round 100.0. Under about 2000 files
# `%.1f` cannot reach 100.0 with one file missing, so the guard that forces 99.9
# is invisible to every other case here and a mutant deleting it survived all of
# them. This case asserts the PRINTED LINE, not the exit code: the exit code is 1
# either way, and the lie is in the figure.
newrepo coverage-must-not-round-a-lost-file-up
mkdir -p "$TMP/coverage-must-not-round-a-lost-file-up/docs"
i=1
while [ "$i" -le 2000 ]; do
  printf '# %s\n' "$i" > "$TMP/coverage-must-not-round-a-lost-file-up/docs/f$i.md"
  i=$((i + 1))
done
put coverage-must-not-round-a-lost-file-up stray.txt 'the one file nobody declared'
stage coverage-must-not-round-a-lost-file-up
case_run coverage-must-not-round-a-lost-file-up 1 "cobertura: 2000/2001 (99.9%)" --policy "$TMP/base.json"

# --- the written exemption, and its teeth -------------------------------------

GOOD_WHY='a declared fixture whose ELF magic number is the only thing that proves the detector sees it'

# docs_policy_with <name> <exemption object> - the base policy, with one exemption
# spliced into the docs root. Built by concatenation rather than by handing printf
# a format string it did not write: a `%` inside a fixture would otherwise be read
# as a conversion and the policy would come out different from what the case says.
docs_policy_with() {
  printf '%s\n' '{"declared":2,"policies":[{"id":"docs","prefix":"docs/","why":"prose a person reads and nothing executes","extensions":["md"],"executable":false,"binary":false,"exemptions":['"$2"']},{"id":"bin","prefix":"bin/","why":"the scripts a user is meant to run","extensions":["sh"],"executable":true,"binary":true,"exemptions":[]}]}' > "$TMP/$1.json"
}

newrepo an-exemption-that-says-why
put an-exemption-that-says-why docs/a.md '# a'
{ printf 'ELF'; head -c 4 /dev/zero; printf 'tail\n'; } > "$TMP/an-exemption-that-says-why/docs/blob.md"
stage an-exemption-that-says-why
docs_policy_with ex-good "{\"path\":\"docs/blob.md\",\"why\":\"$GOOD_WHY\"}"
case_run an-exemption-that-says-why 0 "exempted in writing: docs/blob.md" --policy "$TMP/ex-good.json"

# An exemption with no reason is itself a finding. Withdrawing a check and writing
# down what replaces it are the same edit; this is the half that otherwise never
# happens, and it is invisible because the file it silences goes quiet.
newrepo an-exemption-that-says-nothing
put an-exemption-that-says-nothing docs/a.md '# a'
{ printf 'ELF'; head -c 4 /dev/zero; printf 'tail\n'; } > "$TMP/an-exemption-that-says-nothing/docs/blob.md"
stage an-exemption-that-says-nothing
docs_policy_with ex-mute '{"path":"docs/blob.md","why":"legacy"}'
case_run an-exemption-that-says-nothing 1 "with no reason written down" --policy "$TMP/ex-mute.json"

# A dead exemption is worse than no exemption: it reads as a guarded decision and
# guards nothing. Two ways to be dead - the path is not there at all, or the file
# is there and breaks no rule - and both are findings.
newrepo an-exemption-pointing-at-nothing
put an-exemption-pointing-at-nothing docs/a.md '# a'
stage an-exemption-pointing-at-nothing
docs_policy_with ex-dead "{\"path\":\"docs/gone.md\",\"why\":\"$GOOD_WHY\"}"
case_run an-exemption-pointing-at-nothing 1 "exempts docs/gone.md" --policy "$TMP/ex-dead.json"

newrepo an-exemption-that-protects-nothing
put an-exemption-that-protects-nothing docs/a.md '# a'
stage an-exemption-that-protects-nothing
docs_policy_with ex-idle "{\"path\":\"docs/a.md\",\"why\":\"$GOOD_WHY\"}"
case_run an-exemption-that-protects-nothing 1 "breaks no rule" --policy "$TMP/ex-idle.json"

# --- the count that keeps a withdrawal from being silent ----------------------

newrepo declared-disagrees-with-the-count
put declared-disagrees-with-the-count docs/a.md '# a'
stage declared-disagrees-with-the-count
policy miscounted '{"declared":3,"policies":[{"id":"docs","prefix":"docs/","why":"prose a person reads and nothing executes","extensions":["md"],"executable":false,"binary":false,"exemptions":[]}]}'
case_run declared-disagrees-with-the-count 1 "leaves no trace that anything was withdrawn" --policy "$TMP/miscounted.json"

# --- could not measure --------------------------------------------------------

# A catch-all makes the coverage number meaningless: with one policy matching
# everything, no file can ever be undeclared again and the gate reports 100 %
# forever. It is refused outright rather than obeyed.
newrepo a-catch-all-prefix
put a-catch-all-prefix docs/a.md '# a'
stage a-catch-all-prefix
policy catchall '{"declared":1,"policies":[{"id":"everything","prefix":"","why":"whatever turns up","extensions":["md"],"executable":true,"binary":true,"exemptions":[]}]}'
case_run a-catch-all-prefix 2 "catch-all prefix" --policy "$TMP/catchall.json"

newrepo two-policies-share-an-id
put two-policies-share-an-id docs/a.md '# a'
stage two-policies-share-an-id
policy twins '{"declared":2,"policies":[{"id":"docs","prefix":"docs/","why":"prose a person reads","extensions":["md"],"executable":false,"binary":false,"exemptions":[]},{"id":"docs","prefix":"other/","why":"a second policy wearing the same name","extensions":["md"],"executable":true,"binary":true,"exemptions":[]}]}'
case_run two-policies-share-an-id 2 "share the id" --policy "$TMP/twins.json"

newrepo the-policy-file-is-not-there
put the-policy-file-is-not-there docs/a.md '# a'
stage the-policy-file-is-not-there
case_run the-policy-file-is-not-there 2 "No such file" --policy "$TMP/no-such-policy.json"

newrepo a-policy-that-does-not-parse
put a-policy-that-does-not-parse docs/a.md '# a'
stage a-policy-that-does-not-parse
policy unparseable '{"declared":1,"policies":[{"id":"docs",'
case_run a-policy-that-does-not-parse 2 "Expecting" --policy "$TMP/unparseable.json"

# A repository with nothing staged answers zero, and a zero from an instrument
# that did not measure is not an absence. Without this case, a gate pointed at the
# wrong directory would report a flawless 0/0 and read as a pass.
newrepo git-ls-files-reports-zero-files
case_run git-ls-files-reports-zero-files 2 "blind zero" --policy "$TMP/base.json"

# --- a policy key that is there, and is not what the reader assumed ------------
#
# PRESENT is not CORRECT, and the loader used to check only the first. Every
# policy below passes the presence check and every one silently changes what the
# gate measures - measured against a control of three expected findings:
#
#   extensions as the string "md"      -> 2 findings, because `"d" in "md"` is
#                                         true: a string is a list of its letters
#   extensions as the string "mdpycd"  -> 1 finding, two extensions simply lost
#   executable as the string "false"   -> 2 findings: a non-empty string is TRUE,
#                                         so the execute-bit rule stopped firing
#                                         while the policy still read as if it
#                                         forbade one
#   why empty, or null                 -> accepted, on a gate that demands 20
#                                         useful characters to waive one check on
#                                         one file
#
# All five are could-not-measure now, naming the policy and the key.
newrepo extensions-given-as-a-bare-string
put extensions-given-as-a-bare-string docs/a.md '# a'
stage extensions-given-as-a-bare-string
policy ext-str '{"declared":1,"policies":[{"id":"docs","prefix":"docs/","why":"prose a person reads and nothing executes","extensions":"md","executable":false,"binary":false,"exemptions":[]}]}'
case_run extensions-given-as-a-bare-string 2 "policy 'docs' declares extensions as a value of type str ('md')" --policy "$TMP/ext-str.json"

newrepo extensions-as-a-run-of-letters
put extensions-as-a-run-of-letters docs/a.md '# a'
stage extensions-as-a-run-of-letters
policy ext-run '{"declared":1,"policies":[{"id":"docs","prefix":"docs/","why":"prose a person reads and nothing executes","extensions":"mdpycd","executable":false,"binary":false,"exemptions":[]}]}'
case_run extensions-as-a-run-of-letters 2 "policy 'docs' declares extensions as a value of type str ('mdpycd')" --policy "$TMP/ext-run.json"

newrepo executable-given-as-the-string-false
put executable-given-as-the-string-false docs/a.md '# a'
stage executable-given-as-the-string-false
policy exec-str '{"declared":1,"policies":[{"id":"docs","prefix":"docs/","why":"prose a person reads and nothing executes","extensions":["md"],"executable":"false","binary":false,"exemptions":[]}]}'
case_run executable-given-as-the-string-false 2 "policy 'docs' declares executable as a value of type str ('false')" --policy "$TMP/exec-str.json"

# The sentence saying what a root IS is the whole of "claimed by a written
# policy". A root was allowed to skip it while one file could not be waived
# without twenty useful characters.
newrepo a-policy-whose-why-is-empty
put a-policy-whose-why-is-empty docs/a.md '# a'
stage a-policy-whose-why-is-empty
policy why-empty '{"declared":1,"policies":[{"id":"docs","prefix":"docs/","why":"","extensions":["md"],"executable":false,"binary":false,"exemptions":[]}]}'
case_run a-policy-whose-why-is-empty 2 "policy 'docs' says why in 0 useful character(s)" --policy "$TMP/why-empty.json"

newrepo a-policy-whose-why-is-null
put a-policy-whose-why-is-null docs/a.md '# a'
stage a-policy-whose-why-is-null
policy why-null '{"declared":1,"policies":[{"id":"docs","prefix":"docs/","why":null,"extensions":["md"],"executable":false,"binary":false,"exemptions":[]}]}'
case_run a-policy-whose-why-is-null 2 "policy 'docs' declares why as a value of type NoneType" --policy "$TMP/why-null.json"

# An exemption is the one place where a check is withdrawn on purpose, so its own
# shape is checked before it is honoured. Neither of these two turned a single
# case red when the check was first written, which is how a validation branch
# ends up shipped and never exercised.
newrepo an-exemption-with-no-path-at-all
put an-exemption-with-no-path-at-all docs/a.md '# a'
stage an-exemption-with-no-path-at-all
policy ex-nopath '{"declared":1,"policies":[{"id":"docs","prefix":"docs/","why":"prose a person reads and nothing executes","extensions":["md"],"executable":false,"binary":false,"exemptions":[{"why":"a reason with nothing at all attached to it"}]}]}'
case_run an-exemption-with-no-path-at-all 2 "policy 'docs' carries an exemption (#0) with no path" --policy "$TMP/ex-nopath.json"

newrepo an-exemption-whose-path-is-not-a-string
put an-exemption-whose-path-is-not-a-string docs/a.md '# a'
stage an-exemption-whose-path-is-not-a-string
policy ex-numpath '{"declared":1,"policies":[{"id":"docs","prefix":"docs/","why":"prose a person reads and nothing executes","extensions":["md"],"executable":false,"binary":false,"exemptions":[{"path":7,"why":"a path that is a number matches no tracked file and protects nothing"}]}]}'
case_run an-exemption-whose-path-is-not-a-string 2 "policy 'docs' declares exemptions[0].path as a value of type int (7)" --policy "$TMP/ex-numpath.json"

echo "gate-install-footprint: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
exit 0
