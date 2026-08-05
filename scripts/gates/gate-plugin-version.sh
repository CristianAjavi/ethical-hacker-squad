#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-plugin-version.sh — CRITICAL gate for plugin distribution.
#
# WHAT PROBLEM IT PREVENTS
#   Claude Code resolves a plugin version in this order:
#     1) `version` in .claude-plugin/plugin.json
#     2) `version` in the marketplace entry
#     3) the SHA of the source commit
#   and "if the resolved version matches what a user already has, /plugin update
#   and auto-update skip the plugin".
#   Consequence: if plugin.json pins a frozen `version`, commits can be merged
#   for months and NO installed user receives them. The failure is SILENT: no
#   error, no warning, simply nothing arrives.
#   Source: https://code.claude.com/docs/en/plugin-marketplaces#version-resolution-and-release-channels
#
# CHANNEL DESIGN THIS GATE ENFORCES
#   - channel `latest`  (main branch)   -> plugin.json OMITS `version`.
#                                          Every commit = a new version by SHA.
#   - channel `stable`  (stable branch) -> plugin.json DECLARES explicit semver.
#   - the marketplace entry NEVER declares `version` (plugin.json wins silently;
#     declaring it in both places only creates drift).
#
#   While main still declares `version` (the repo's transition state), the gate
#   does not let the silent failure through: it requires every commit that
#   touches user-served paths to bump that version.
#
# EXIT CODES (repo contract: an rc=0 never means "I did not check it")
#   0 = I MEASURED and it is fine
#   1 = I MEASURED and it FAILS
#   2 = I COULD NOT MEASURE (missing tool, missing input, missing base ref)
#
# ENVIRONMENT VARIABLES
#   EHS_CHANNEL            latest|stable  (by default derived from the branch)
#   EHS_BASE_REF           base ref for the diff (default GITHUB_BASE_REF,
#                          then origin/main, then main)
#   EHS_REQUIRE_CLAUDE_CLI 1 => if the `claude` binary is missing, rc=2 instead of SKIP
#   EHS_REPO_ROOT          repo root (default: git rev-parse, then cwd)
# ---------------------------------------------------------------------------
set -uo pipefail

SEMVER_RE='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'

# Paths whose content is copied into the user cache on install/update.
# A change here DOES change what the user runs => it forces a new version.
USER_SERVED_PATHS=(
  "skills/"
  "agents/"
  "commands/"
  "hooks/"
  ".claude-plugin/"
)

FAILURES=0
CHECKED=()
SKIPPED=()

ok()      { printf '  [OK]   %s\n' "$*"; CHECKED+=("$*"); }
fail()    { printf '  [FAIL] %s\n' "$*" >&2; CHECKED+=("$*"); FAILURES=$((FAILURES + 1)); }
skip()    { printf '  [SKIP] %s\n' "$*"; SKIPPED+=("$*"); }
info()    { printf '         %s\n' "$*"; }
section() { printf '\n== %s\n' "$*"; }

# Immediate rc=2: it could not be measured. Never degrades to 0.
unmeasurable() {
  printf '\n[COULD NOT MEASURE] %s\n' "$*" >&2
  printf 'gate-plugin-version: rc=2 (not a pass; it is absence of measurement)\n' >&2
  exit 2
}

# --- 0. tools --------------------------------------------------------------
section "tools"
for tool in jq git; do
  command -v "$tool" >/dev/null 2>&1 || unmeasurable "the tool '$tool' is missing"
done
ok "jq and git available"

# --- 1. repo root ----------------------------------------------------------
if [[ -n "${EHS_REPO_ROOT:-}" ]]; then
  ROOT="$EHS_REPO_ROOT"
elif ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
  :
else
  ROOT="$PWD"
fi
[[ -d "$ROOT/.claude-plugin" ]] || unmeasurable \
  "I cannot find .claude-plugin/ under '$ROOT' (wrong cwd? this is not the plugin repo)"

PLUGIN_JSON="$ROOT/.claude-plugin/plugin.json"
MARKET_JSON="$ROOT/.claude-plugin/marketplace.json"
info "root: $ROOT"

# --- 2. both JSON files exist and parse ------------------------------------
section "manifests"
for f in "$PLUGIN_JSON" "$MARKET_JSON"; do
  if [[ ! -f "$f" ]]; then
    fail "$(basename "$f") is missing from .claude-plugin/ (the plugin is not installable without it)"
    continue
  fi
  if jq -e . "$f" >/dev/null 2>&1; then
    ok "$(basename "$f") parses as valid JSON"
  else
    fail "$(basename "$f") does NOT parse as JSON: $(jq . "$f" 2>&1 | head -3 | tr '\n' ' ')"
  fi
done
# Without parseable JSON there is nothing else that can be measured reliably.
if (( FAILURES > 0 )); then
  printf '\ngate-plugin-version: rc=1 (broken manifests; the rest could not be evaluated)\n' >&2
  exit 1
fi

PLUGIN_NAME=$(jq -r '.name // empty' "$PLUGIN_JSON")
PLUGIN_VERSION=$(jq -r 'if has("version") then (.version|tostring) else "" end' "$PLUGIN_JSON")
HAS_VERSION=$(jq -r 'has("version")' "$PLUGIN_JSON")

if [[ -z "$PLUGIN_NAME" ]]; then
  fail "plugin.json does not declare 'name' (it is the ONLY mandatory field)"
else
  ok "plugin.json name='$PLUGIN_NAME'"
fi

# --- 3. the marketplace entry must NOT declare version ---------------------
section "double version declaration"
ENTRIES_WITH_VERSION=$(jq -r '[.plugins[]? | select(has("version")) | .name] | join(", ")' "$MARKET_JSON")
if [[ -n "$ENTRIES_WITH_VERSION" ]]; then
  fail "marketplace.json declares 'version' in: $ENTRIES_WITH_VERSION"
  info "plugin.json ALWAYS wins and the entry is ignored silently; declaring it in"
  info "both places only produces a stale manifest that masks the real version."
  info "Fix: delete 'version' from the marketplace entry."
else
  ok "no marketplace entry declares 'version' (plugin.json is the single source)"
fi

# --- 4. the marketplace entry describes THIS plugin ------------------------
LOCAL_ENTRY_NAMES=$(jq -r '[.plugins[]? | select((.source|type=="string") and (.source|test("^\\./|^\\.$"))) | .name] | join("\n")' "$MARKET_JSON")
if [[ -z "$LOCAL_ENTRY_NAMES" ]]; then
  skip "no marketplace entry uses the local source './' - there is no name cross-check to do"
elif grep -qxF "$PLUGIN_NAME" <<<"$LOCAL_ENTRY_NAMES"; then
  ok "the local './' entry is named the same as plugin.json ('$PLUGIN_NAME')"
else
  fail "the entry with source './' is named '$(tr '\n' ' ' <<<"$LOCAL_ENTRY_NAMES")' but plugin.json says '$PLUGIN_NAME'"
fi

# Duplicate names in the catalogue: the official validator already rejects this,
# but we measure it here so we do not depend on `claude` being installed.
DUPES=$(jq -r '[.plugins[]?.name] | group_by(.) | map(select(length>1) | .[0]) | join(", ")' "$MARKET_JSON")
if [[ -n "$DUPES" ]]; then
  fail "duplicate plugin names in marketplace.json: $DUPES"
else
  ok "no duplicate plugin names in the catalogue"
fi

# --- 5. channel ------------------------------------------------------------
section "channel"
CHANNEL="${EHS_CHANNEL:-}"
if [[ -z "$CHANNEL" ]]; then
  BRANCH="${GITHUB_REF_NAME:-}"
  [[ -n "$BRANCH" ]] || BRANCH=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [[ "$BRANCH" == "stable" ]]; then CHANNEL="stable"; else CHANNEL="latest"; fi
  info "channel derived from branch '${BRANCH:-<unknown>}'"
fi
case "$CHANNEL" in
  latest|stable) ok "channel = $CHANNEL" ;;
  *) unmeasurable "EHS_CHANNEL='$CHANNEL' is neither 'latest' nor 'stable'" ;;
esac

# --- 6. per-channel policy -------------------------------------------------
section "version policy for channel '$CHANNEL'"

if [[ "$CHANNEL" == "stable" ]]; then
  # stable MUST carry explicit semver: that is what distinguishes this channel
  # from latest. If stable declared no version, it would resolve by SHA just like
  # latest and there would be no two distinguishable channels.
  if [[ "$HAS_VERSION" != "true" ]]; then
    fail "stable does NOT declare 'version' in plugin.json"
    info "without explicit semver, stable resolves by SHA just like latest and stops being a separate channel"
  elif [[ ! "$PLUGIN_VERSION" =~ $SEMVER_RE ]]; then
    fail "version='$PLUGIN_VERSION' is not valid semver"
  else
    ok "stable declares semver '$PLUGIN_VERSION'"
    # Re-publishing an already tagged version = a silently skipped update.
    TAG="${PLUGIN_NAME}--v${PLUGIN_VERSION}"
    if ! git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
      skip "not a git repo: I cannot check whether the tag '$TAG' already exists"
    elif git -C "$ROOT" rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1; then
      TAGGED_SHA=$(git -C "$ROOT" rev-list -n1 "refs/tags/$TAG")
      HEAD_SHA=$(git -C "$ROOT" rev-parse HEAD)
      if [[ "$TAGGED_SHA" == "$HEAD_SHA" ]]; then
        ok "the tag '$TAG' already points at this very commit (idempotent re-run)"
      else
        fail "the tag '$TAG' already exists pointing at $TAGGED_SHA, different from HEAD ($HEAD_SHA)"
        info "publishing new content with an already used version = users do NOT receive the update"
      fi
    else
      ok "the tag '$TAG' does not exist yet: the version is new"
    fi
  fi

else # latest
  if [[ "$HAS_VERSION" != "true" ]]; then
    ok "latest OMITS 'version': every commit resolves to a new version by its SHA"
    info "this is the target design; there is no bump to maintain and CI never writes to main"
  else
    # Transition state: main still declares a version. We do not accept it as
    # correct, but we do not let the silent failure through either: we require
    # the bump.
    fail "latest declares version='$PLUGIN_VERSION' - the design asks for it to be OMITTED on main"
    info "with a fixed version, no commit on main reaches installed users until somebody bumps it by hand"
    info "fix: delete the 'version' key from .claude-plugin/plugin.json on main"

    if [[ ! "$PLUGIN_VERSION" =~ $SEMVER_RE ]]; then
      fail "on top of that, version='$PLUGIN_VERSION' is not valid semver"
    fi

    # Bump rule, for as long as the version stays there.
    BASE_REF="${EHS_BASE_REF:-}"
    if [[ -z "$BASE_REF" && -n "${GITHUB_BASE_REF:-}" ]]; then BASE_REF="origin/${GITHUB_BASE_REF}"; fi
    if [[ -z "$BASE_REF" ]]; then
      for cand in origin/main main; do
        if git -C "$ROOT" rev-parse -q --verify "$cand" >/dev/null 2>&1; then BASE_REF="$cand"; break; fi
      done
    fi
    if [[ -z "$BASE_REF" ]] || ! git -C "$ROOT" rev-parse -q --verify "$BASE_REF" >/dev/null 2>&1; then
      unmeasurable "I cannot resolve a base ref for the diff (tried EHS_BASE_REF, GITHUB_BASE_REF, origin/main, main). Without a base I cannot check the bump rule."
    fi
    BASE_SHA=$(git -C "$ROOT" rev-parse "$BASE_REF")
    HEAD_SHA=$(git -C "$ROOT" rev-parse HEAD)
    info "base=$BASE_REF ($BASE_SHA)  head=$HEAD_SHA"

    if [[ "$BASE_SHA" == "$HEAD_SHA" ]]; then
      ok "HEAD == base: there are no changes that demand a bump"
    else
      CHANGED=$(git -C "$ROOT" diff --name-only "$BASE_SHA" "$HEAD_SHA" 2>/dev/null)
      if [[ -z "$CHANGED" ]]; then
        ok "empty diff against the base: there are no changes that demand a bump"
      else
        TOUCHED=""
        while IFS= read -r f; do
          [[ -n "$f" ]] || continue
          for p in "${USER_SERVED_PATHS[@]}"; do
            case "$f" in "$p"*) TOUCHED+="$f"$'\n'; break ;; esac
          done
        done <<<"$CHANGED"

        if [[ -z "$TOUCHED" ]]; then
          ok "no change touches user-served paths (${USER_SERVED_PATHS[*]}): no bump needed"
        else
          BASE_VERSION=$(git -C "$ROOT" show "$BASE_SHA:.claude-plugin/plugin.json" 2>/dev/null \
            | jq -r 'if has("version") then (.version|tostring) else "" end' 2>/dev/null)
          info "user-served changes: $(tr '\n' ' ' <<<"$TOUCHED")"
          if [[ "$BASE_VERSION" == "$PLUGIN_VERSION" ]]; then
            fail "user-served paths were touched but version is still '$PLUGIN_VERSION' (same as on the base)"
            info "SILENT DISTRIBUTION FAILURE: /plugin update will skip this plugin because the resolved version did not change"
          else
            ok "version changed from '${BASE_VERSION:-<absent>}' to '$PLUGIN_VERSION' together with the served changes"
          fi
        fi
      fi
    fi
  fi
fi

# --- 7. official validator (optional, with teeth if CI demands it) ---------
section "official Anthropic validator"
# MEASURED on 2.1.221: `claude plugin validate <dir>` with marketplace.json present
# validates ONLY the marketplace manifest and does NOT report the plugin version
# warning. To audit plugin.json you have to point at the FILE.
# ALSO MEASURED: it returns rc=1 both when it measured and failed and when the path
# does not exist => that is why this wrapper pre-checks and never delegates its exit
# code to the tool.
if ! command -v claude >/dev/null 2>&1; then
  if [[ "${EHS_REQUIRE_CLAUDE_CLI:-0}" == "1" ]]; then
    unmeasurable "EHS_REQUIRE_CLAUDE_CLI=1 but the 'claude' binary is not in PATH"
  fi
  skip "'claude' binary not available: validate was not run (set EHS_REQUIRE_CLAUDE_CLI=1 to demand it)"
else
  # On latest, the ONLY legitimate complaint from --strict is "No version
  # specified": that is intentional. Rather than giving up --strict (losing
  # coverage) or swallowing it whole (approving blindly), --strict is run and we
  # check that EVERY complaint is exactly that one. Any other warning still fails.
  EXPECTED_WARN='version: No version specified'

  validate_target() { # $1=path  $2=label
    local target="$1" label="$2" out rc n_warn n_expected
    out=$(claude plugin validate "$target" --strict 2>&1); rc=$?
    if (( rc == 0 )); then
      ok "claude plugin validate --strict over $label"
      return 0
    fi
    if [[ "$CHANNEL" == "latest" ]]; then
      n_warn=$(grep -c '❯ ' <<<"$out")
      n_expected=$(grep -c "❯ .*$EXPECTED_WARN" <<<"$out")
      if (( n_warn > 0 && n_warn == n_expected )) && ! grep -q 'Found .* error' <<<"$out"; then
        ok "claude plugin validate --strict over $label: the only complaint is the absence of 'version', which is intentional on latest ($n_warn warning(s), all expected)"
        return 0
      fi
    fi
    fail "claude plugin validate --strict failed over $label"
    sed 's/^/         | /' <<<"$out" >&2
    return 1
  }

  validate_target "$MARKET_JSON" "marketplace.json"
  validate_target "$PLUGIN_JSON" "plugin.json"
fi

# --- summary ---------------------------------------------------------------
section "summary"
printf '  checked: %d check(s)\n' "${#CHECKED[@]}"
if ((${#SKIPPED[@]} > 0)); then
  printf '  NOT checked: %d\n' "${#SKIPPED[@]}"
  for s in "${SKIPPED[@]}"; do printf '    - %s\n' "$s"; done
else
  printf '  NOT checked: 0\n'
fi

if (( FAILURES > 0 )); then
  printf '\ngate-plugin-version: rc=1 — %d MEASURED failure(s)\n' "$FAILURES" >&2
  exit 1
fi
printf '\ngate-plugin-version: rc=0 — measured and correct\n'
exit 0
