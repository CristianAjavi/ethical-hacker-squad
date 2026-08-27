#!/usr/bin/env bash
# Self-test for gate-reference-reachable.sh, on throwaway trees.
#
# The gate's value is catching a rule nobody is pointed at, so the cases are the
# ways a file can be unreachable: never cited, cited only by another orphan, and
# reachable only through a chain that has to be walked to be seen.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-reference-reachable.sh"
[ -f "$GATE" ] || { echo "UNMEASURABLE gate missing"; exit 2; }
command -v python3 >/dev/null || { echo "UNMEASURABLE python3 missing"; exit 2; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ pass=$((pass+1)); echo "  PASS  $1"; }
bad(){ fail=$((fail+1)); echo "  FAIL  $1"; }

mk() { # mk <name>; then callers write files
  mkdir -p "$TMP/$1/agents" "$TMP/$1/refs"; echo "$TMP/$1"
}
# Every tree gets a SKILL.md: the second section reads the leader workflow from
# it, and a tree without one is UNMEASURABLE rather than a silent pass. Cases
# that care about the workflow overwrite it.
mkskill() { mkdir -p "$(dirname "$1")"; printf '## Leader workflow\n\n### 1. Do the thing\n' > "$1"; }
run() {
  [ -f "$1/SKILL.md" ] || mkskill "$1/SKILL.md"
  EHS_AGENTS_DIR="$1/agents" EHS_REFS_DIR="$1/refs" EHS_SKILL_MD="$1/SKILL.md" bash "$GATE" >"$TMP/out" 2>&1
}

echo "== everything cited directly =="
d="$(mk direct)"
printf 'see references/a.md and references/b.md\n' > "$d/agents/one.md"
printf '# a\n' > "$d/refs/a.md"; printf '# b\n' > "$d/refs/b.md"
run "$d"; rc=$?
[ "$rc" -eq 0 ] && ok "all references cited gives rc 0" || bad "expected rc 0, got $rc"

echo "== a reference nobody points at =="
d="$(mk orphan)"
printf 'see references/a.md\n' > "$d/agents/one.md"
printf '# a\n' > "$d/refs/a.md"; printf '# lonely\n' > "$d/refs/lonely.md"
run "$d"; rc=$?
[ "$rc" -eq 1 ] && ok "an uncited reference gives rc 1" || bad "expected rc 1, got $rc"
grep -q 'references/lonely.md' "$TMP/out" && ok "the orphan is named" || bad "the orphan is anonymous"

echo "== reachable only through a chain — the gate must WALK, not just grep the agents =="
d="$(mk chain)"
printf 'see references/a.md\n' > "$d/agents/one.md"
printf 'now read references/b.md\n' > "$d/refs/a.md"
printf 'and then references/c.md\n' > "$d/refs/b.md"
printf '# c\n' > "$d/refs/c.md"
run "$d"; rc=$?
[ "$rc" -eq 0 ] && ok "a three-deep citation chain is reachable" || bad "the gate does not walk the graph: rc $rc"

echo "== cited only by an orphan is still an orphan =="
d="$(mk island)"
printf 'see references/a.md\n' > "$d/agents/one.md"
printf '# a\n' > "$d/refs/a.md"
printf 'see references/y.md\n' > "$d/refs/x.md"    # x is uncited
printf '# y\n' > "$d/refs/y.md"
run "$d"; rc=$?
[ "$rc" -eq 1 ] && ok "an island of two mutually-citing orphans still fails" || bad "expected rc 1, got $rc"
grep -q 'references/x.md' "$TMP/out" && grep -q 'references/y.md' "$TMP/out" \
  && ok "both island members are named" || bad "the island was not fully named"

echo "== non-markdown references count too (the artifact contract is .json) =="
d="$(mk json)"
printf 'see references/a.md\n' > "$d/agents/one.md"
printf '# a\n' > "$d/refs/a.md"; printf '{}\n' > "$d/refs/findings.schema.json"
run "$d"; rc=$?
[ "$rc" -eq 1 ] && grep -q 'findings.schema.json' "$TMP/out" \
  && ok "an uncited .json contract is caught, not only .md" || bad "the .json orphan was missed: rc $rc"

echo "== could not measure is never a pass =="
run "$TMP/absent"; rc=$?
[ "$rc" -eq 2 ] && ok "absent directories give rc 2" || bad "expected rc 2, got $rc"
d="$(mk emptyrefs)"; printf 'x\n' > "$d/agents/one.md"
run "$d"; rc=$?
[ "$rc" -eq 2 ] && ok "no references at all is rc 2, not a silent green" || bad "expected rc 2, got $rc"

echo "== a rule the leader names and the executor never sees =="
d="$(mk unseenrule)"
printf 'see references/a.md\n' > "$d/agents/one.md"; printf '# a\n' > "$d/refs/a.md"
printf '## Leader workflow\n\n### 8. Attack the list\n\nEvery finding goes to VER-09.\n' > "$d/SKILL.md"
run "$d"; rc=$?
[ "$rc" -eq 1 ] && grep -q 'VER-09' "$TMP/out" \
  && ok "a workflow rule no agent cites is caught — the VER-09 shape" \
  || bad "the unseen rule was missed: rc $rc"

echo "== the same rule, cited by the role that must follow it =="
d="$(mk seenrule)"
printf 'see references/a.md and apply VER-09 last\n' > "$d/agents/one.md"; printf '# a\n' > "$d/refs/a.md"
printf '## Leader workflow\n\n### 8. Attack the list\n\nEvery finding goes to VER-09.\n' > "$d/SKILL.md"
run "$d"; rc=$?
[ "$rc" -eq 0 ] && ok "citing it from the role clears it — the fix is the citation" \
  || bad "expected rc 0 once the role cites it, got $rc"

echo "== no SKILL.md at all is not a silent green =="
d="$(mk noskill)"
printf 'see references/a.md\n' > "$d/agents/one.md"; printf '# a\n' > "$d/refs/a.md"
EHS_AGENTS_DIR="$d/agents" EHS_REFS_DIR="$d/refs" EHS_SKILL_MD="$d/nothing-here.md" bash "$GATE" >"$TMP/out" 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "an absent SKILL.md is rc 2, not a pass" || bad "expected rc 2, got $rc"

echo; echo "$pass PASS / $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
