#!/usr/bin/env bash
# Self-test for gate-issue-closure.sh. A gate that has never been seen failing is not
# a gate: here it is tested IN THE NEGATIVE (rc=1) and in "could not measure" (rc=2),
# not only in the green path.
#
# It is offline: it touches neither the network nor GitHub. Everything comes in via
# --body-file, --changed-files and --labels-file.
#
# Exit codes: 0 = every case passes | 1 = some case fails | 2 = could not measure.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-issue-closure.sh"
REPO="owner/repo"

[ -x "$GATE" ] || { printf 'COULD NOT MEASURE: %s is not executable.\n' "$GATE" >&2; exit 2; }

T="$(mktemp -d)" || { printf 'COULD NOT MEASURE: no temporary directory.\n' >&2; exit 2; }
trap 'rm -rf "$T"' EXIT

cat > "$T/labels.txt" <<'EOF'
10 type/false-positive
10 origin/human
11 type/false-negative
12 type/bug
12 status/needs-triage
99 type/false-positive
EOF

printf 'scripts/gates/gate-issue-closure.sh\n' > "$T/files.gate"
printf 'tests/fixtures/pickle-worker.yml\n'    > "$T/files.case"
# The three remedies that contract G8 of docs/gate-requirements.md accepts.
printf 'skills/ethical-hacker-squad/references/knowledge/web-api.md\n' > "$T/files.corpus"
# Prose: explaining the mistake in the skill is not a check. G8 rejects it on purpose.
printf 'README.md\nskills/ethical-hacker-squad/SKILL.md\n' > "$T/files.norel"
: > "$T/files.empty"

pass=0; fail=0
check() { # $1 name  $2 expected rc  $3.. command
  local name="$1" want="$2"; shift 2
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ]; then
    printf '  ok    %-58s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf '  FAIL  %-58s rc=%s (expected %s)\n' "$name" "$rc" "$want"; fail=$((fail+1))
    printf '%s\n' "$out" | sed 's/^/        | /'
  fi
}

printf 'Self-test for gate-issue-closure.sh\n===================================\n'

# --- rc=1: I MEASURED and it FAILS -----------------------------------------
printf 'Fixes #10\n' > "$T/b1"
check "false positive with no watched regression" 1 \
  "$GATE" --repo "$REPO" --body-file "$T/b1" --labels-file "$T/labels.txt" --changed-files "$T/files.norel"

check "false positive touching no file at all" 1 \
  "$GATE" --repo "$REPO" --body-file "$T/b1" --labels-file "$T/labels.txt" --changed-files "$T/files.empty"

printf 'Resolves #11\n' > "$T/b2"
check "false negative with no watched regression" 1 \
  "$GATE" --repo "$REPO" --body-file "$T/b2" --labels-file "$T/labels.txt" --changed-files "$T/files.norel"

printf 'Closing this. Fixes https://github.com/owner/repo/issues/10\n' > "$T/b3"
check "form 'keyword + URL' also counts as a closure" 1 \
  "$GATE" --repo "$REPO" --body-file "$T/b3" --labels-file "$T/labels.txt" --changed-files "$T/files.norel"

printf 'Standalone change with no issue.\n' > "$T/b4"
check "--require-link with no closure declared" 1 \
  "$GATE" --repo "$REPO" --body-file "$T/b4" --labels-file "$T/labels.txt" --changed-files "$T/files.gate" --require-link

# Deleting the gate that catches you is not watching the regression. This used to pass
# GREEN because `git diff --name-only` lists deletions just like additions.
check "closing a false positive by DELETING the gate" 1 \
  "$GATE" --repo "$REPO" --body-file "$T/b1" --labels-file "$T/labels.txt" \
          --changed-files "$T/files.gate" --deleted-files "$T/files.gate"

printf 'scripts/gates/gate-issue-closure.sh\ntests/cases/old.md\n' > "$T/files.mixed"
printf 'tests/cases/old.md\n' > "$T/files.delcase"
check "deletes a case but modifies the gate: still counts" 0 \
  "$GATE" --repo "$REPO" --body-file "$T/b1" --labels-file "$T/labels.txt" \
          --changed-files "$T/files.mixed" --deleted-files "$T/files.delcase"

check "--deleted-files unreadable" 2 \
  "$GATE" --repo "$REPO" --body-file "$T/b1" --labels-file "$T/labels.txt" \
          --changed-files "$T/files.gate" --deleted-files "$T/does-not-exist.txt"

# --- rc=0: I MEASURED and it is fine ---------------------------------------
check "false positive + gate touched" 0 \
  "$GATE" --repo "$REPO" --body-file "$T/b1" --labels-file "$T/labels.txt" --changed-files "$T/files.gate"

check "false negative + gate fixture touched" 0 \
  "$GATE" --repo "$REPO" --body-file "$T/b2" --labels-file "$T/labels.txt" --changed-files "$T/files.case"

# G8 names the corpus case as the main remedy for a false negative. With the previous
# EVIDENCE_PATHS ("cases/*", which does not exist) this correct PR FAILED.
check "false negative + case added to the corpus" 0 \
  "$GATE" --repo "$REPO" --body-file "$T/b2" --labels-file "$T/labels.txt" --changed-files "$T/files.corpus"

printf 'Closes #12\n' > "$T/b5"
check "issue of type bug: no regression is required" 0 \
  "$GATE" --repo "$REPO" --body-file "$T/b5" --labels-file "$T/labels.txt" --changed-files "$T/files.norel"

check "PR that declares no closure" 0 \
  "$GATE" --repo "$REPO" --body-file "$T/b4" --labels-file "$T/labels.txt" --changed-files "$T/files.norel"

printf 'Fixes other/project#10\n' > "$T/b6"
check "closure in ANOTHER repository: not judged" 0 \
  "$GATE" --repo "$REPO" --body-file "$T/b6" --labels-file "$T/labels.txt" --changed-files "$T/files.norel"

printf 'Docs change.\n<!-- template example: Fixes #99 -->\nNothing else.\n' > "$T/b7"
check "reference inside an HTML comment: ignored" 0 \
  "$GATE" --repo "$REPO" --body-file "$T/b7" --labels-file "$T/labels.txt" --changed-files "$T/files.norel"

printf 'Talks about prefixes #10 and suffixes #10 without closing them.\n' > "$T/b8"
check "a word that merely CONTAINS 'fixes' does not count" 0 \
  "$GATE" --repo "$REPO" --body-file "$T/b8" --labels-file "$T/labels.txt" --changed-files "$T/files.norel"

# --- rc=2: COULD NOT MEASURE -----------------------------------------------
check "no PR body" 2 \
  env -u PR_BODY "$GATE" --repo "$REPO" --labels-file "$T/labels.txt" --changed-files "$T/files.gate"

check "label map unreadable" 2 \
  "$GATE" --repo "$REPO" --body-file "$T/b1" --labels-file "$T/does-not-exist.txt" --changed-files "$T/files.gate"

printf 'Fixes #4242\n' > "$T/b10"
check "issue absent from the label map (not 'no labels')" 2 \
  "$GATE" --repo "$REPO" --body-file "$T/b10" --labels-file "$T/labels.txt" --changed-files "$T/files.norel"

check "file list unreadable" 2 \
  "$GATE" --repo "$REPO" --body-file "$T/b1" --labels-file "$T/labels.txt" --changed-files "$T/does-not-exist.txt"

check "unknown option" 2 "$GATE" --whatever

# --- --emit-refs -----------------------------------------------------------
printf 'Fixes #10\ncloses #11\nresolved #10\n' > "$T/b9"
got="$("$GATE" --repo "$REPO" --body-file "$T/b9" --emit-refs 2>&1 | tr '\n' ' ' | sed 's/ *$//')"
if [ "$got" = "10 11" ]; then
  printf '  ok    %-58s "%s"\n' "--emit-refs deduplicates and sorts" "$got"; pass=$((pass+1))
else
  printf '  FAIL  %-58s "%s" (expected "10 11")\n' "--emit-refs deduplicates and sorts" "$got"; fail=$((fail+1))
fi

printf '\nSummary: %d ok, %d failures\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
printf 'Result: OK. The gate fails when it must fail and distinguishes "could not measure".\n'
exit 0
