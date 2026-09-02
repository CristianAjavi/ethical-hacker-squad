#!/usr/bin/env bash
# Self-test for gate-lockfile-coherence.sh.
#
# The first case that matters is `the-third-copy-comes-back`: it rebuilds the
# exact shape this gate exists to stop - a workflow env var restating a version
# the lock already pins - and it does so with the CORRECT value, because the
# defect is the copy, not the disagreement. On 2026-09-02 the copy and the lock
# had already drifted apart on Dependabot PR #81, which was open, MERGEABLE and
# 23 of 23 checks green.
#
# Every case builds a MINIMAL root - two json files and one workflow - instead
# of copying the repository. That is not only faster: the tree carries a 258 MB
# node_modules that is gitignored and absent in CI, so a self-test that copied
# it would be measuring a tree CI never sees.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-lockfile-coherence.sh"
command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
[ -f "$GATE" ] || { echo "UNMEASURABLE the gate under test is missing: $GATE"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-lockcoh-XXXXXX")" || {
  echo "UNMEASURABLE mktemp -d failed"; exit 2; }
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# seed_root <dir> — a coherent minimal repository: one pinned devDependency,
# a lock that agrees with it, and a workflow carrying no version at all.
seed_root() {
  local d="$1"
  mkdir -p "$d/tooling/claude-cli" "$d/.github/workflows" "$d/scripts/gates/lib"
  cat > "$d/tooling/claude-cli/package.json" <<'JSON'
{
  "name": "ehs-claude-cli",
  "private": true,
  "devDependencies": { "@anthropic-ai/claude-code": "2.1.221" }
}
JSON
  cat > "$d/tooling/claude-cli/package-lock.json" <<'JSON'
{
  "name": "ehs-claude-cli",
  "lockfileVersion": 3,
  "packages": {
    "": { "name": "ehs-claude-cli", "devDependencies": { "@anthropic-ai/claude-code": "2.1.221" } },
    "node_modules/@anthropic-ai/claude-code": { "version": "2.1.221", "dev": true }
  }
}
JSON
  cat > "$d/.github/workflows/release.yml" <<'YAML'
name: Release
on:
  workflow_dispatch:
env:
  PLUGIN_NAME: 'ethical-hacker-squad'
jobs:
  noop:
    runs-on: ubuntu-latest
    steps:
      - run: 'true'
YAML
  cp "$HERE/lib/lockfile_coherence.py" "$d/scripts/gates/lib/"
}

# add_env_line <VAR> <value> — append one env var to the seeded workflow.
#
# This used to be `sed -i ''`, which is BSD/macOS syntax: on GNU sed the empty
# string is read as the script and the mutation dies. Measured on CI 2026-09-02:
# five cases came back `HARNESS ... the mutation itself failed` while the same
# file was 16/16 on the author's Mac. python3 is already a hard requirement of
# this battery, so there is no portability question left to answer.
add_env_line() {
  python3 - "$1" "$2" <<'PY'
import pathlib, sys
var, value = sys.argv[1], sys.argv[2]
p = pathlib.Path(".github/workflows/release.yml")
s = p.read_text(encoding="utf-8")
needle = "  PLUGIN_NAME: 'ethical-hacker-squad'\n"
if needle not in s:
    raise SystemExit("the seeded workflow does not carry the anchor line")
p.write_text(s.replace(needle, needle + "  %s: '%s'\n" % (var, value), 1), encoding="utf-8")
PY
}

# $1 name  $2 wanted rc  $3 needle  $4 shell mutation on $work  $5 "lab" to run the copy
case_run() {
  local name="$1" want="$2" needle="$3" mutation="$4" which="${5:-}" work="$TMP/$1"
  rm -rf "$work"; seed_root "$work"
  if [ -n "$mutation" ]; then
    if ! ( cd "$work" && eval "$mutation" ) >/dev/null 2>&1; then
      printf 'HARNESS  %-40s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
    fi
  fi
  local runner="$GATE"
  if [ "$which" = "lab" ]; then
    cp "$GATE" "$work/scripts/gates/"
    cp "$HERE/lib/common.sh" "$work/scripts/gates/lib/"
    runner="$work/scripts/gates/gate-lockfile-coherence.sh"
  fi
  local out rc
  out="$(EHS_REPO_ROOT="$work" bash "$runner" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -qF -- "$needle"; }; then
    printf 'ok       %-40s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-40s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -6; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-lockfile-coherence.sh ==="

case_run control-coherent-root 0 "tell one story" ""

# ---- the shape this gate exists to stop ------------------------------------
# With the RIGHT value, on purpose. The defect is the second copy, not the
# disagreement: the disagreement is only what it turns into later.
case_run the-third-copy-comes-back 1 "second place to say the same version" \
  "add_env_line CLAUDE_CODE_VERSION 2.1.221"

case_run the-third-copy-comes-back-wrong 1 "second place to say the same version" \
  "add_env_line CLAUDE_CODE_VERSION 2.1.246"

# A rename was a way out of the rule until `names_a_package` looked for the
# package's bare name inside the stem as well as the other way round.
#
# The value is deliberately NOT one the lock carries. The first version of this
# case used 2.1.221, and it passed under the naive one-way match too - the
# value check was catching it, so the case measured the value path and claimed
# to measure the name path. With 9.9.9 only the name can fire.
case_run the-copy-renamed-around-the-rule 1 "second place to say the same version" \
  "add_env_line ANTHROPIC_AI_CLAUDE_CODE_VERSION 9.9.9"

# A name that gives nothing away. Caught by value instead, and the message says
# so rather than pretending the name resolved.
case_run the-copy-under-a-name-that-hides-it 1 "matched by value" \
  "add_env_line CLI_VERSION 2.1.221"

# ---- the manifest and the lock, both ways ----------------------------------
case_run lock-not-regenerated 1 "records 2.1.221" \
  "python3 -c \"
import json,pathlib
p=pathlib.Path('tooling/claude-cli/package.json'); d=json.loads(p.read_text())
d['devDependencies']['@anthropic-ai/claude-code']='2.1.246'
p.write_text(json.dumps(d))\""

case_run a-dependency-nobody-declared 1 "no longer" \
  "python3 -c \"
import json,pathlib
p=pathlib.Path('tooling/claude-cli/package.json'); d=json.loads(p.read_text())
d['devDependencies']={'left-pad':'1.0.0'}
p.write_text(json.dumps(d))\""

case_run the-resolved-version-differs 1 "the lock resolves" \
  "python3 -c \"
import json,pathlib
p=pathlib.Path('tooling/claude-cli/package-lock.json'); d=json.loads(p.read_text())
d['packages']['node_modules/@anthropic-ai/claude-code']['version']='2.1.246'
p.write_text(json.dumps(d))\""

case_run no-tree-entry-for-the-pin 1 "would install nothing" \
  "python3 -c \"
import json,pathlib
p=pathlib.Path('tooling/claude-cli/package-lock.json'); d=json.loads(p.read_text())
del d['packages']['node_modules/@anthropic-ai/claude-code']
p.write_text(json.dumps(d))\""

# ---- could not measure: never a pass ---------------------------------------
# A range is honestly out of reach without a semver resolver, and saying so is
# the difference between this gate and one that guesses.
case_run a-range-instead-of-a-pin 2 "needs a semver resolver" \
  "python3 -c \"
import json,pathlib
for f in ('package.json','package-lock.json'):
    p=pathlib.Path('tooling/claude-cli/'+f); s=p.read_text()
    p.write_text(s.replace('\\\"2.1.221\\\"','\\\"^2.1.221\\\"',1))\""

case_run the-lock-is-gone 2 "missing" "rm tooling/claude-cli/package-lock.json"

case_run the-lock-will-not-parse 2 "will not parse" \
  "printf '{ not json' > tooling/claude-cli/package-lock.json"

case_run the-lock-has-no-root-entry 2 "no root" \
  "python3 -c \"
import json,pathlib
p=pathlib.Path('tooling/claude-cli/package-lock.json'); d=json.loads(p.read_text())
del d['packages']['']
p.write_text(json.dumps(d))\""

case_run package-json-declares-nothing 2 "would mean the file went empty" \
  "printf '{\"name\":\"x\"}' > tooling/claude-cli/package.json"

# Without a workflow the third-copy check has nothing to look at, and a green
# would be the blind zero this repository keeps catching in itself.
case_run no-workflow-to-look-at 2 "a zero here would be blind" \
  "rm .github/workflows/release.yml"

case_run the-core-crashes 2 "that is a crash, not a verdict" \
  "printf 'import sys\nsys.exit(1)\n' > scripts/gates/lib/lockfile_coherence.py" lab

printf '\n%s: %d passed, %d failed\n' "gate-lockfile-coherence" "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
