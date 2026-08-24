#!/usr/bin/env bash
# Self-test for gate-plugin-version.sh, on throwaway plugins built here.
#
# This gate guards a SILENT failure: Claude Code resolves a plugin's version
# from plugin.json first, and "if the resolved version matches what a user
# already has, /plugin update and auto-update skip the plugin". A frozen
# `version` on main therefore means commits are merged for months and NO
# installed user receives them - no error, no warning, nothing arrives.
#
# A gate against a silent failure that nobody has ever seen fail is worth
# exactly as much as no gate. Hence this file.
#
# The `claude` CLI is optional here: when it is absent the gate SKIPs the
# official validator, and every case below still lands on its verdict for its
# own reason. That is why the fixture is nonetheless built to pass
# `claude plugin validate --strict` - description, author and frontmatter
# included - so a green here means the same thing on a laptop and on a runner.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-plugin-version.sh"
for t in git jq; do
  command -v "$t" >/dev/null 2>&1 || { echo "UNMEASURABLE $t is missing"; exit 2; }
done
[ -f "$GATE" ] || { echo "UNMEASURABLE $GATE is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-plugin-version-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
G() { git -C "$1" -c user.email=t@e -c user.name=t "${@:2}"; }

write_plugin_json() {  # <dir> <version-or-empty>
  if [ -n "$2" ]; then
    cat > "$1/.claude-plugin/plugin.json" <<JSON
{ "name": "ethical-hacker-squad",
  "description": "A throwaway plugin used only by this self-test.",
  "author": { "name": "self-test" },
  "version": "$2" }
JSON
  else
    cat > "$1/.claude-plugin/plugin.json" <<'JSON'
{ "name": "ethical-hacker-squad",
  "description": "A throwaway plugin used only by this self-test.",
  "author": { "name": "self-test" } }
JSON
  fi
}

# build_repo <dir> <version-or-empty> — an installable plugin on `main`
build_repo() {
  local d="$1" v="$2"
  mkdir -p "$d/.claude-plugin" "$d/skills/pack" "$d/agents"
  write_plugin_json "$d" "$v"
  cat > "$d/.claude-plugin/marketplace.json" <<'JSON'
{ "name": "selftest-marketplace",
  "description": "A throwaway marketplace used only by this self-test.",
  "owner": { "name": "self-test" },
  "plugins": [ { "name": "ethical-hacker-squad",
                 "description": "A throwaway plugin used only by this self-test.",
                 "author": { "name": "self-test" },
                 "source": "./" } ] }
JSON
  printf -- '---\nname: pack\ndescription: A throwaway skill used only by this self-test.\n---\n\n# pack\n' \
    > "$d/skills/pack/SKILL.md"
  printf -- '---\nname: a\ndescription: A throwaway agent used only by this self-test.\n---\n\nagent\n' \
    > "$d/agents/a.md"
  git -C "$d" init -q -b main
  G "$d" add -A; G "$d" commit -qm base
}

# run_case <name> <expected rc> <needle> <channel> <mutation> <base version>
run_case() {
  local name="$1" want="$2" needle="$3" channel="$4" mutate="$5" basev="${6-}"
  local d="$TMP/$name"; rm -rf "$d"; mkdir -p "$d"
  build_repo "$d" "$basev"
  G "$d" checkout -q -b feat/change
  "$mutate" "$d"
  G "$d" add -A; G "$d" commit -qm change --allow-empty
  local out rc=0
  out="$(EHS_REPO_ROOT="$d" EHS_BASE_REF=main EHS_CHANNEL="$channel" bash "$GATE" 2>&1)" || rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -qi -- "$needle"; }; then
    printf 'ok       %-38s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-38s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -12; fail=$((fail+1))
  fi
}

m_served()        { printf 'more\n' >> "$1/skills/pack/SKILL.md"; }
m_readme()        { printf 'docs\n' >> "$1/README.md"; }
m_add_version()   { m_served "$1"; write_plugin_json "$1" "1.0.1"; }
m_market_version(){ jq '.plugins[0].version = "9.9.9"' "$1/.claude-plugin/marketplace.json" > "$1/m.tmp" \
                    && mv "$1/m.tmp" "$1/.claude-plugin/marketplace.json"; }
m_dupe_entry()    { jq '.plugins += [.plugins[0]]' "$1/.claude-plugin/marketplace.json" > "$1/m.tmp" \
                    && mv "$1/m.tmp" "$1/.claude-plugin/marketplace.json"; }
m_no_name()       { jq 'del(.name)' "$1/.claude-plugin/plugin.json" > "$1/p.tmp" \
                    && mv "$1/p.tmp" "$1/.claude-plugin/plugin.json"; }
m_broken_json()   { printf '{"name": \n' > "$1/.claude-plugin/plugin.json"; }
m_no_manifest()   { rm -f "$1/.claude-plugin/plugin.json"; }
m_bad_semver()    { m_served "$1"; write_plugin_json "$1" "1.0"; }
m_drop_version()  { m_served "$1"; write_plugin_json "$1" ""; }
m_nothing()       { :; }

echo "=== self-test: gate-plugin-version.sh ==="
echo "-- channel latest: plugin.json must OMIT version, so every commit resolves by SHA"
run_case latest-omits-version-served-change  0 "OMITS"                     latest m_served       ""
run_case latest-declares-version             1 "OMITTED"                   latest m_add_version  ""
run_case latest-nothing-served-changed       0 "no bump"                   latest m_readme       ""

echo "-- channel stable: plugin.json must DECLARE semver, or it resolves by SHA like latest"
run_case stable-declares-semver              0 "stable declares"           stable m_served       "1.0.0"
run_case stable-without-version              1 "does NOT declare"          stable m_drop_version "1.0.0"
run_case stable-version-not-semver           1 ""                          stable m_bad_semver   "1.0.0"

echo "-- manifests"
run_case marketplace-declares-version        1 "marketplace.json declares" latest m_market_version ""
run_case duplicate-marketplace-entry         1 ""                          latest m_dupe_entry     ""
run_case plugin-json-without-name            1 "name"                      latest m_no_name        ""
run_case plugin-json-not-json                1 "JSON"                      latest m_broken_json    ""
run_case plugin-json-missing                 1 "missing"                   latest m_no_manifest    ""

echo "-- could not measure (never a pass)"
# There is exactly ONE path to the base-ref lookup: channel `latest` WITH a
# version declared - the transition state, where the bump rule still applies.
# On stable there is no diff to compute and on a versionless latest there is
# nothing to bump, so neither can reach it. Two earlier drafts of this file
# asserted rc 2 from those two dead ends and were wrong about the gate, not the
# other way round.
d="$TMP/no-base"; mkdir -p "$d"; build_repo "$d" "1.0.0"
G "$d" checkout -q -b feat/change; m_served "$d"; G "$d" add -A; G "$d" commit -qm change
rc=0; out="$(EHS_REPO_ROOT="$d" EHS_CHANNEL=latest EHS_BASE_REF=origin/does-not-exist bash "$GATE" 2>&1)" || rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -qi "cannot resolve a base ref"; then
  printf 'ok       %-38s rc=2\n' base-ref-unreachable; pass=$((pass+1))
else printf 'FAILED   %-38s rc=%s (wanted 2)\n' base-ref-unreachable "$rc"
     printf '%s\n' "$out" | sed 's/^/         /' | tail -8; fail=$((fail+1)); fi

# The same question asked of a tree that is not a git work tree at all.
d="$TMP/not-git"; mkdir -p "$d/.claude-plugin" "$d/skills/pack" "$d/agents"
write_plugin_json "$d" "1.0.0"
cat > "$d/.claude-plugin/marketplace.json" <<'JSON'
{ "name": "selftest-marketplace",
  "description": "A throwaway marketplace used only by this self-test.",
  "owner": { "name": "self-test" },
  "plugins": [ { "name": "ethical-hacker-squad",
                 "description": "A throwaway plugin used only by this self-test.",
                 "author": { "name": "self-test" },
                 "source": "./" } ] }
JSON
printf -- '---\nname: pack\ndescription: A throwaway skill used only by this self-test.\n---\n\n# pack\n' > "$d/skills/pack/SKILL.md"
printf -- '---\nname: a\ndescription: A throwaway agent used only by this self-test.\n---\n\nagent\n' > "$d/agents/a.md"
rc=0; out="$(EHS_REPO_ROOT="$d" EHS_CHANNEL=latest bash "$GATE" 2>&1)" || rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -qi "cannot resolve a base ref"; then
  printf 'ok       %-38s rc=2\n' not-a-git-worktree; pass=$((pass+1))
else printf 'FAILED   %-38s rc=%s (wanted 2)\n' not-a-git-worktree "$rc"
     printf '%s\n' "$out" | sed 's/^/         /' | tail -8; fail=$((fail+1)); fi

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. The gate keeps latest resolving by SHA, keeps stable on explicit"
echo "        semver, refuses a double version declaration, and reports"
echo "        could-not-measure instead of guessing."
exit 0
