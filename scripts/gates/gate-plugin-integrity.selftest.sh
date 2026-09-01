#!/usr/bin/env bash
# Self-test for gate-plugin-integrity.sh, on throwaway served trees built here.
#
# This is the gate that decides what a user's plugin cache is allowed to
# contain: frontmatter shape, link resolution, symlinks, extensions, the execute
# bit, and the size budget that bounds the blast radius of the corpus. It ran on
# every commit and had never been observed failing, which is the definition of a
# control nobody knows works.
#
# The tree budgets are exercised through the gate's own documented knobs
# (EHS_MAX_TREE_BYTES, EHS_MAX_TREE_FILES) rather than by generating half a
# megabyte of fixture: the rule under test is the comparison, not the constant.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-plugin-integrity.sh"
[ -f "$GATE" ] || { echo "UNMEASURABLE $GATE is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-plugin-integrity-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# build_tree <dir> — the smallest served tree this gate accepts
build_tree() {
  local d="$1"
  mkdir -p "$d/skills/mypack/references" "$d/agents"
  cat > "$d/skills/mypack/SKILL.md" <<'MD'
---
name: mypack
description: A throwaway skill used only by this self-test, with a description long enough to be a real one.
---

# mypack

See [the reference](references/notes.md).
MD
  printf '# notes\n' > "$d/skills/mypack/references/notes.md"
  cat > "$d/agents/a.md" <<'MD'
---
name: a
description: A throwaway agent used only by this self-test.
---

agent
MD
}

# run_case <name> <expected rc> <needle> <mutation> [env assignments...]
run_case() {
  local name="$1" want="$2" needle="$3" mutate="$4"; shift 4
  local d="$TMP/$name"; rm -rf "$d"; mkdir -p "$d"
  build_tree "$d"
  "$mutate" "$d"
  local out rc=0
  out="$(env EHS_REPO_ROOT="$d" EHS_SERVED_ROOTS="skills agents" "$@" bash "$GATE" 2>&1)" || rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -qi -- "$needle"; }; then
    printf 'ok       %-36s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-36s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | grep -iE 'fail|unmeas' | head -4; fail=$((fail+1))
  fi
}

# A notice that always fires is noise, so it needs both proofs: that it speaks,
# and that it stays quiet. run_case can only assert a string is PRESENT, so this
# sibling asserts it is absent. Same harness, inverted grep.
run_case_absent() {
  local name="$1" want="$2" needle="$3" mutate="$4"; shift 4
  local d="$TMP/$name"; rm -rf "$d"; mkdir -p "$d"
  build_tree "$d"
  "$mutate" "$d"
  local out rc=0
  out="$(env EHS_REPO_ROOT="$d" EHS_SERVED_ROOTS="skills agents" "$@" bash "$GATE" 2>&1)" || rc=$?
  if [ "$rc" -eq "$want" ] && ! printf '%s' "$out" | grep -qi -- "$needle"; then
    printf 'ok       %-36s rc=%s (no "%s")\n' "$name" "$rc" "$needle"; pass=$((pass+1))
  else
    printf 'FAILED   %-36s rc=%s (wanted %s and no "%s")\n' "$name" "$rc" "$want" "$needle"
    fail=$((fail+1))
  fi
}

m_none()          { :; }
m_empty_skill()   { : > "$1/skills/mypack/SKILL.md"; }
m_no_frontmatter(){ printf '# mypack\n' > "$1/skills/mypack/SKILL.md"; }
m_unterminated()  { printf -- '---\nname: mypack\ndescription: x\n\n# body\n' > "$1/skills/mypack/SKILL.md"; }
# `allowed-tools` is THE key this gate exists to refuse: the squad is audit-only,
# and a skill that grants itself Bash is no longer audit-only. The gate's own
# comment says a `grep '^allowed-tools:'` was demonstrated evadable, because
# `"allowed-tools": Bash(*)` and `allowed-tools : Bash(*)` are the same key to
# any YAML parser and neither starts with the literal. All three spellings are
# tested here, so that claim is measured and not just written down.
insert_fm_line()  { local d="$1" line="$2"
                    awk -v ins="$line" 'NR==1{print; print ins; next} {print}' \
                      "$d/skills/mypack/SKILL.md" > "$d/s.tmp" && mv "$d/s.tmp" "$d/skills/mypack/SKILL.md"; }
m_tools_plain()   { insert_fm_line "$1" 'allowed-tools: Bash(*)'; }
m_tools_quoted()  { insert_fm_line "$1" '"allowed-tools": Bash(*)'; }
m_tools_spaced()  { insert_fm_line "$1" 'allowed-tools : Bash(*)'; }
m_name_mismatch() { sed -i.bak 's/^name: mypack$/name: otherpack/' "$1/skills/mypack/SKILL.md"; rm -f "$1/skills/mypack/SKILL.md.bak"; }
m_no_desc()       { sed -i.bak '/^description:/d' "$1/skills/mypack/SKILL.md"; rm -f "$1/skills/mypack/SKILL.md.bak"; }
m_broken_link()   { rm -f "$1/skills/mypack/references/notes.md"; }
m_symlink()       { ln -s /etc/hosts "$1/skills/mypack/references/link.md"; }
m_bad_extension() { printf 'x\n' > "$1/skills/mypack/references/notes.txt.exe"; }
m_exec_bit()      { chmod +x "$1/skills/mypack/references/notes.md"; }
m_fat_skill()     { { head -20 "$1/skills/mypack/SKILL.md"; head -c 13000 /dev/zero | tr '\0' 'a'; } > "$1/s.tmp"
                    mv "$1/s.tmp" "$1/skills/mypack/SKILL.md"; }
m_fat_reference() { head -c 40000 /dev/zero | tr '\0' 'b' > "$1/skills/mypack/references/notes.md"; }
m_no_skill_md()   { rm -f "$1/skills/mypack/SKILL.md"; }
m_no_md_at_all()  { rm -rf "$1/skills" "$1/agents"; mkdir -p "$1/skills" "$1/agents"; }

echo "=== self-test: gate-plugin-integrity.sh ==="
echo "-- the shape of what a user loads"
run_case clean-tree-passes           0 ""                          m_none
run_case skill-md-empty              1 "empty"                     m_empty_skill
run_case frontmatter-absent          1 "does not start"            m_no_frontmatter
run_case frontmatter-unterminated    1 "never closes"              m_unterminated
run_case allowed-tools-plain         1 "not permitted"             m_tools_plain
run_case allowed-tools-quoted        1 "not permitted"             m_tools_quoted
run_case allowed-tools-spaced        1 "not permitted"             m_tools_spaced
run_case allowed-tools-permitted     0 "explicit human decision"   m_tools_plain EHS_ALLOW_TOOLS_FRONTMATTER=1
run_case name-does-not-match-dir     1 "does not match the direct" m_name_mismatch
run_case description-missing         1 "missing or empty"          m_no_desc

echo "-- what the tree is allowed to contain"
run_case relative-link-is-broken     1 "relative link"             m_broken_link
run_case symlink-in-served-tree      1 "symlink"                   m_symlink
run_case extension-not-permitted     1 "non-permitted extension"   m_bad_extension
run_case execute-bit-set             1 "execute bit"               m_exec_bit

echo "-- the size budget"
run_case skill-md-over-budget        1 "loaded whole"              m_fat_skill
run_case reference-over-budget       1 "split the file"            m_fat_reference
run_case tree-over-byte-budget       1 "blast-radius"              m_none EHS_MAX_TREE_BYTES=10
run_case tree-over-file-budget       1 "files >"                   m_none EHS_MAX_TREE_FILES=1
# The cap fails only once it is too late; the notice is what a contributor can
# act on. Both halves proved: it speaks under one reference file of headroom,
# and it says nothing when there is room. Neither changes the verdict.
run_case tree-headroom-notice        0 "of headroom left"          m_none EHS_MAX_TREE_BYTES=1000000 EHS_MAX_REF_BYTES=999999
run_case_absent tree-headroom-quiet  0 "of headroom left"          m_none EHS_MAX_TREE_BYTES=1000000

echo "-- could not measure (never a pass)"
run_case no-skill-md-anywhere        2 "nothing to validate"       m_no_skill_md
run_case no-markdown-at-all          2 ""                          m_no_md_at_all

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. The gate rejects a malformed skill, a tree that points outside"
echo "        itself, and a corpus over budget, and it reports could-not-measure"
echo "        instead of approving an incomplete tree."
exit 0
