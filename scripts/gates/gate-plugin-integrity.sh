#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-plugin-integrity.sh — integrity of the content served to the user.
#
# WHY IT EXISTS
#   Everything that lands in skills/ is copied into EVERY user's plugin cache on
#   their next session start, with no human action. A PR from the knowledge loop
#   (bot/knowledge-*) that modifies that tree is, by construction, a channel for
#   indirect prompt injection towards every installation.
#   This gate does not judge the CONTENT (that is not deterministic): it bounds
#   the FORM, which is - frontmatter, links, file types and size.
#
# WHAT IT MEASURES
#   1. Frontmatter of each SKILL.md: delimiters, allowed keys, name matching the
#      directory, non-empty description.
#   2. That no SKILL.md grants itself tools through the frontmatter.
#   3. That every internal relative link in the repo resolves to a real file.
#   4. Size and shape budget of the tree served to the user.
#
# EXIT CODES (repo contract: an rc=0 never means "I did not check it")
#   0 = I MEASURED and it is fine
#   1 = I MEASURED and it FAILS
#   2 = I COULD NOT MEASURE (missing tool or missing input)
#
# ENVIRONMENT VARIABLES
#   EHS_REPO_ROOT                 repo root
#   EHS_SERVED_ROOTS              roots copied into the user cache
#                                 (default: "skills agents commands hooks";
#                                 the ones that do not exist are declared
#                                 absent, not silently approved)
#   EHS_ALLOW_TOOLS_FRONTMATTER=1 allows 'allowed-tools' in the frontmatter
#                                 (an explicit human decision, not the bot's)
#   EHS_MAX_SKILL_MD_BYTES        default 12288
#   EHS_MAX_REF_BYTES             default 32768
#   EHS_MAX_TREE_BYTES            default 524288 (see RE-BASELINED note below)
#   EHS_MAX_TREE_FILES            default 64
# ---------------------------------------------------------------------------
set -uo pipefail

# --- SIZE BUDGET: thresholds and why these numbers -------------------------
#
# SKILL.md (12 KiB ~= 3,000 tokens)
#   SKILL.md is loaded whole into context EVERY time the skill fires; its cost is
#   neither optional nor amortisable. The current file weighs ~8.7 KiB, so 12 KiB
#   leaves ~40% headroom to grow without the threshold getting in the way, and it
#   stops the real degradation pattern: a skill that fattens commit after commit
#   until the model stops reading it carefully. If a change needs more than
#   12 KiB, the correct answer is to move that text to references/ (loaded on
#   demand), not to raise the threshold.
#
# Each file under references/ (32 KiB ~= 8,000 tokens)
#   They are loaded one by one and on demand, so they tolerate more. 32 KiB is
#   still a single-pass read; beyond that the file should be split so the model
#   does not have to swallow irrelevant material.
#
# Whole tree served to the user (512 KiB) and file count (64)
#   This is the SECURITY threshold, not the ergonomics one: it bounds the blast
#   radius of the knowledge loop, turning "a bot PR drops 3 MB of text scraped
#   from the internet into what gets installed for everyone" into a CI failure
#   rather than a release. The thresholds are deliberately generous: if one is
#   genuinely hit, that is a signal deserving human review, not an automatic
#   adjustment.
#
#   RE-BASELINED 2026-08. The previous value (256 KiB) was justified against
#   "the current corpus at ~17 KiB" - a placeholder written before the knowledge
#   corpus existed. The real corpus is ~350 KiB, so the old number was measuring
#   a repository that never shipped. It was raised, not because the tree failed
#   the check, but because the stated rationale no longer described reality.
#   Splitting files cannot fix a total-size budget by construction: the five
#   oversized packs were split, and the tree grew by 16 KiB of new headers. Only
#   deleting corpus could satisfy 256 KiB, which is not a security improvement.
#   512 KiB keeps the property that matters - a bulk dump is still an order of
#   magnitude away - while the per-file 32 KiB budget remains the binding
#   control on what any single agent must read.
#
#   RE-BASELINED AGAIN 2026-08-21, to 640 KiB. Three landed procedures, a new
#   pack (local-app) and the triage rules took the tree past 512 KiB. The
#   previous note says a hit "deserves human review, not an automatic
#   adjustment", and this is that review written down: the growth is corpus
#   this repository decided to add, item by item, each one visible in the
#   changelog. Raising the cap is only defensible because the weakness below is
#   now closed - the binding control on "too much at once" moved to the delta
#   guard, which does not go slack as the corpus grows.
#
#   KNOWN WEAKNESS, CLOSED 2026-08-21: an absolute cap is a poor instrument for
#   "a bot added too much at once", because it loosens as the corpus grows and
#   eventually only deleting knowledge satisfies it. The control that keeps its
#   meaning is a DELTA guard - no single change may grow the served tree by more
#   than N bytes - and it now exists as gate-tree-delta.sh: 16 KiB for a bot/
#   branch, 64 KiB for a human one. This cap stays as the outer bound.
MAX_SKILL_MD_BYTES="${EHS_MAX_SKILL_MD_BYTES:-12288}"
MAX_REF_BYTES="${EHS_MAX_REF_BYTES:-32768}"
MAX_TREE_BYTES="${EHS_MAX_TREE_BYTES:-655360}"
MAX_TREE_FILES="${EHS_MAX_TREE_FILES:-64}"

# Keys tolerated in the SKILL.md frontmatter. Everything else is rejected: an
# unknown key in a file distributed to third parties is unaudited material with
# potentially executable semantics.
ALLOWED_FM_KEYS="name description license metadata"
# Extensions tolerated inside skills/. Text only: the tree served to the user has
# no reason to contain anything executable or binary.
ALLOWED_EXTENSIONS="md"

FAILURES=0
N_CHECKED=0
SKIPPED=()

ok()      { printf '  [OK]   %s\n' "$*"; N_CHECKED=$((N_CHECKED + 1)); }
fail()    { printf '  [FAIL] %s\n' "$*" >&2; N_CHECKED=$((N_CHECKED + 1)); FAILURES=$((FAILURES + 1)); }
skip()    { printf '  [SKIP] %s\n' "$*"; SKIPPED+=("$*"); }
info()    { printf '         %s\n' "$*"; }
section() { printf '\n== %s\n' "$*"; }

unmeasurable() {
  printf '\n[COULD NOT MEASURE] %s\n' "$*" >&2
  printf 'gate-plugin-integrity: rc=2 (not a pass; it is absence of measurement)\n' >&2
  exit 2
}

fsize() { wc -c <"$1" | tr -d ' '; }

# --- 0. tools --------------------------------------------------------------
section "tools"
for tool in grep sed awk find wc sort mktemp; do
  command -v "$tool" >/dev/null 2>&1 || unmeasurable "the tool '$tool' is missing"
done
ok "POSIX utilities available"

# Unpredictable temporary file: /tmp/something.$PID is a guessable name and this
# script runs on the same runner as untrusted content.
LINKS_TMP=$(mktemp "${TMPDIR:-/tmp}/ehs-links.XXXXXX") \
  || unmeasurable "I could not create a temporary file"
cleanup() { [[ -n "${LINKS_TMP:-}" ]] && command rm -f "$LINKS_TMP" 2>/dev/null; }
trap cleanup EXIT

# --- 1. root ---------------------------------------------------------------
if [[ -n "${EHS_REPO_ROOT:-}" ]]; then
  ROOT="$EHS_REPO_ROOT"
elif ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
  :
else
  ROOT="$PWD"
fi
[[ -d "$ROOT/skills" ]] || unmeasurable \
  "I cannot find skills/ under '$ROOT' (wrong cwd? this is not the plugin repo)"
info "root: $ROOT"

# --- 2. frontmatter of each SKILL.md ---------------------------------------
section "SKILL.md frontmatter"
# PORTABILITY NOTE: no `mapfile` - macOS ships bash 3.2 and does not have it.
SKILL_FILES=()
while IFS= read -r _f; do SKILL_FILES+=("$_f"); done < <(find "$ROOT/skills" -type f -name 'SKILL.md' | sort)
if ((${#SKILL_FILES[@]} == 0)); then
  unmeasurable "there is no SKILL.md under skills/ - nothing to validate (incomplete tree)"
fi

for sf in "${SKILL_FILES[@]}"; do
  rel="${sf#"$ROOT"/}"
  dirname_of_skill=$(basename "$(dirname "$sf")")

  if [[ ! -s "$sf" ]]; then
    fail "$rel is empty"
    continue
  fi

  first_line=$(head -n 1 "$sf")
  if [[ "$first_line" != "---" ]]; then
    fail "$rel does not start with the '---' delimiter (frontmatter absent or corrupt)"
    continue
  fi

  # Closing delimiter line (first '---' from line 2 onwards).
  close_line=$(awk 'NR>1 && $0=="---" {print NR; exit}' "$sf")
  if [[ -z "$close_line" ]]; then
    fail "$rel opens a frontmatter but never closes it with '---'"
    continue
  fi
  ok "$rel: frontmatter delimited (lines 1..$close_line)"

  fm=$(sed -n "2,$((close_line - 1))p" "$sf")

  # --- top-level key extraction, STRICT and fail-closed --------------------
  # A `grep '^key:'` is EVADABLE and it was demonstrated: `"allowed-tools": Bash(*)`
  # and `allowed-tools : Bash(*)` are both the `allowed-tools` key for any YAML
  # parser (MEASURED with PyYAML) and neither starts with `allowed-tools:`, so
  # the allowlist let them through with rc=0.
  # Here an optional quote and spaces before the colon are accepted, and on top
  # of that every top-level line that does NOT match the `key:` shape is declared
  # a FAILURE: what the gate cannot interpret is not approved.
  RE_KEY_DQ='^"([A-Za-z_][A-Za-z0-9_.-]*)"[[:space:]]*:'
  RE_KEY_SQ="^'([A-Za-z_][A-Za-z0-9_.-]*)'[[:space:]]*:"
  RE_KEY_PL='^([A-Za-z_][A-Za-z0-9_.-]*)[[:space:]]*:'

  fm_keys_raw=""
  fm_unparsed=""
  while IFS= read -r ln; do
    [[ -n "${ln//[[:space:]]/}" ]] || continue          # blank line
    case "$ln" in
      [[:space:]]*) continue ;;                         # indented continuation
      '-'*)         continue ;;                         # sequence item
      '#'*)         continue ;;                         # comment
    esac
    if   [[ "$ln" =~ $RE_KEY_DQ ]]; then fm_keys_raw+="${BASH_REMATCH[1]}"$'\n'
    elif [[ "$ln" =~ $RE_KEY_SQ ]]; then fm_keys_raw+="${BASH_REMATCH[1]}"$'\n'
    elif [[ "$ln" =~ $RE_KEY_PL ]]; then fm_keys_raw+="${BASH_REMATCH[1]}"$'\n'
    else fm_unparsed+="$ln"$'\n'
    fi
  done <<<"$fm"

  if [[ -n "$fm_unparsed" ]]; then
    fail "$rel: top-level frontmatter line(s) this gate cannot interpret (rejected by default)"
    while IFS= read -r u; do [[ -n "$u" ]] && info "| $u"; done <<<"$fm_unparsed"
  fi

  fm_keys=$(printf '%s' "$fm_keys_raw" | sort -u)

  bad_keys=""
  while IFS= read -r k; do
    [[ -n "$k" ]] || continue
    case " $ALLOWED_FM_KEYS " in
      *" $k "*) ;;
      *)
        if [[ "$k" == "allowed-tools" && "${EHS_ALLOW_TOOLS_FRONTMATTER:-0}" == "1" ]]; then
          skip "$rel declares 'allowed-tools' and EHS_ALLOW_TOOLS_FRONTMATTER=1 permits it (explicit human decision)"
        else
          bad_keys+="$k "
        fi
        ;;
    esac
  done <<<"$fm_keys"

  if [[ -n "$bad_keys" ]]; then
    fail "$rel: frontmatter key(s) not permitted: $bad_keys"
    info "permitted: $ALLOWED_FM_KEYS"
    [[ "$bad_keys" == *"allowed-tools"* ]] && \
      info "'allowed-tools' grants tools to the skill: it cannot come in through an automated PR. Export EHS_ALLOW_TOOLS_FRONTMATTER=1 only after human review."
  elif [[ -z "$fm_unparsed" ]]; then
    ok "$rel: only permitted keys in the frontmatter"
  fi

  # The value is also read tolerating the quoted / spaced form, so we do not
  # produce a false 'name missing' when the key exists but is written that way.
  fm_value() { # $1=key
    printf '%s\n' "$fm" \
      | sed -nE "s/^[\"']?$1[\"']?[[:space:]]*:[[:space:]]*//p" \
      | head -n 1 | sed 's/[[:space:]]*$//'
  }
  fm_name=$(fm_value name | tr -d '"'"'")
  fm_desc=$(fm_value description)

  if [[ -z "$fm_name" ]]; then
    fail "$rel: 'name' missing from the frontmatter (mandatory field)"
  elif [[ ! "$fm_name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    fail "$rel: name='$fm_name' does not match ^[a-z0-9]+(-[a-z0-9]+)*$"
  elif [[ "$fm_name" != "$dirname_of_skill" ]]; then
    fail "$rel: name='$fm_name' does not match the directory '$dirname_of_skill' (the skill would not resolve)"
  else
    ok "$rel: name='$fm_name' valid and matching its directory"
  fi

  if [[ -z "$fm_desc" ]]; then
    fail "$rel: 'description' missing or empty (without it the skill never fires)"
  elif [[ ${#fm_desc} -gt 1024 ]]; then
    fail "$rel: description of ${#fm_desc} characters (limit in this repo: 1024)"
  else
    ok "$rel: description present (${#fm_desc} characters)"
  fi
done

# --- 3. internal relative links ---------------------------------------------
section "internal relative links"
MD_FILES=()
if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  while IFS= read -r _f; do MD_FILES+=("$_f"); done < <(git -C "$ROOT" ls-files '*.md' | sed "s|^|$ROOT/|" | sort)
  info "set: .md files tracked by git"
else
  while IFS= read -r _f; do MD_FILES+=("$_f"); done < <(find "$ROOT" -type f -name '*.md' -not -path '*/.git/*' | sort)
  skip "not a git repo: using find instead of 'git ls-files' (may include unversioned .md)"
fi

if ((${#MD_FILES[@]} == 0)); then
  unmeasurable "I found no .md file to analyse"
fi

BROKEN=0
LINKS_SEEN=0
for md in "${MD_FILES[@]}"; do
  [[ -f "$md" ]] || continue
  mdrel="${md#"$ROOT"/}"
  mddir=$(dirname "$md")

  # Inline links ](target) + reference definitions [id]: target
  {
    grep -oE '\]\([^)]+\)' "$md" 2>/dev/null | sed -E 's/^\]\(//; s/\)$//'
    grep -oE '^\[[^]]+\]:[[:space:]]*[^[:space:]]+' "$md" 2>/dev/null | sed -E 's/^\[[^]]+\]:[[:space:]]*//'
  } | while IFS= read -r target; do
    [[ -n "$target" ]] || continue
    # strip title:  path.md "Title"
    target="${target%%[[:space:]]\"*}"
    target="${target%%[[:space:]]\'*}"
    # discard external links, anchors, templates
    case "$target" in
      http://*|https://*|mailto:*|tel:*|ftp://*|data:*|\#*|\<*|'$'*|'{'*|'%7B'*) continue ;;
    esac
    # strip anchor and query
    target="${target%%#*}"
    target="${target%%\?*}"
    [[ -n "$target" ]] || continue
    # decode the only realistic escape in repo paths
    target="${target//%20/ }"

    if [[ "$target" == /* ]]; then
      resolved="$ROOT$target"   # absolute = relative to the repo root
    else
      resolved="$mddir/$target"
    fi

    if [[ -e "$resolved" ]]; then
      printf 'OK\n'
    else
      printf 'BROKEN\t%s\t%s\n' "$mdrel" "$target"
    fi
  done
done >"$LINKS_TMP"

LINKS_SEEN=$(wc -l <"$LINKS_TMP" | tr -d ' ')
BROKEN=$(grep -c '^BROKEN' "$LINKS_TMP" 2>/dev/null || true)
BROKEN=${BROKEN:-0}
if (( BROKEN > 0 )); then
  fail "$BROKEN relative link(s) point to files that do not exist"
  grep '^BROKEN' "$LINKS_TMP" | awk -F'\t' '{printf "         | %s -> %s\n", $2, $3}' >&2
else
  ok "the $LINKS_SEEN internal relative link(s) resolve to existing files"
fi

# --- 4. shape of the tree served to the user -------------------------------
# EVERY root that Claude Code copies into the user cache is scanned, not just
# skills/. agents/ holds subagent instructions that are distributed the same way
# and that the knowledge loop can also touch; leaving them out of the scan was a
# blind spot (a symlink, a binary or a 3 MB file in agents/ went unseen). The
# FRONTMATTER rules for SKILL.md still apply only to skills/: an agent has a
# different schema (name, description, model, tools) and judging it with the
# skills allowlist would be a false failure.
SERVED_ROOTS_LIST="${EHS_SERVED_ROOTS:-skills agents commands hooks}"
SERVED_PRESENT=()
SERVED_ABSENT=()
for d in $SERVED_ROOTS_LIST; do
  if [[ -d "$ROOT/$d" ]]; then SERVED_PRESENT+=("$d"); else SERVED_ABSENT+=("$d"); fi
done
section "shape of the tree served to the user (${SERVED_PRESENT[*]})"
info "scanned roots: ${SERVED_PRESENT[*]}"
if ((${#SERVED_ABSENT[@]} > 0)); then
  info "roots absent from this tree (nothing to scan): ${SERVED_ABSENT[*]}"
fi

TREE_FILES=()
TREE_LINKS=()
for d in "${SERVED_PRESENT[@]}"; do
  while IFS= read -r _f; do [[ -n "$_f" ]] && TREE_FILES+=("$_f"); done < <(find "$ROOT/$d" -type f | sort)
  while IFS= read -r _f; do [[ -n "$_f" ]] && TREE_LINKS+=("$_f"); done < <(find "$ROOT/$d" -type l | sort)
done

if ((${#TREE_LINKS[@]} > 0)); then
  fail "${#TREE_LINKS[@]} symlink(s) in the served tree (they may point outside the distributed tree)"
  for l in "${TREE_LINKS[@]}"; do info "| ${l#"$ROOT"/}"; done
else
  ok "no symlinks in the served tree"
fi

bad_ext=""
exec_bits=""
for f in "${TREE_FILES[@]}"; do
  rel="${f#"$ROOT"/}"
  # The extension is taken from the NAME, not from the path: `${f##*.}` over the
  # full path returns garbage (or part of a directory) when the file has no dot
  # and some parent directory does.
  base="${f##*/}"
  if [[ "$base" == *.* ]]; then ext="${base##*.}"; else ext=""; fi
  case " $ALLOWED_EXTENSIONS " in
    *" $ext "*) ;;
    *) bad_ext+="$rel " ;;
  esac
  [[ -x "$f" ]] && exec_bits+="$rel "
done
if [[ -n "$bad_ext" ]]; then
  fail "file(s) with a non-permitted extension in the served tree (permitted: $ALLOWED_EXTENSIONS): $bad_ext"
else
  ok "every file in the served tree is .md (nothing executable or binary is distributed)"
fi
if [[ -n "$exec_bits" ]]; then
  fail "file(s) with the execute bit in the served tree: $exec_bits"
else
  ok "no file in the served tree has the execute bit"
fi

# --- 5. size budget --------------------------------------------------------
section "size budget"
for sf in "${SKILL_FILES[@]}"; do
  rel="${sf#"$ROOT"/}"
  sz=$(fsize "$sf")
  if (( sz > MAX_SKILL_MD_BYTES )); then
    fail "$rel weighs $sz B > $MAX_SKILL_MD_BYTES B (it is loaded whole on every trigger; move text to references/)"
  else
    ok "$rel: $sz B / $MAX_SKILL_MD_BYTES B"
  fi
done

REF_OVER=0
for f in "${TREE_FILES[@]}"; do
  [[ "$(basename "$f")" == "SKILL.md" ]] && continue
  sz=$(fsize "$f")
  if (( sz > MAX_REF_BYTES )); then
    fail "${f#"$ROOT"/} weighs $sz B > $MAX_REF_BYTES B (split the file)"
    REF_OVER=$((REF_OVER + 1))
  fi
done
(( REF_OVER == 0 )) && ok "no reference file exceeds $MAX_REF_BYTES B"

TREE_BYTES=0
for f in "${TREE_FILES[@]}"; do TREE_BYTES=$((TREE_BYTES + $(fsize "$f"))); done
if (( TREE_BYTES > MAX_TREE_BYTES )); then
  fail "the served tree (${SERVED_PRESENT[*]}) weighs $TREE_BYTES B > $MAX_TREE_BYTES B (blast-radius limit of the corpus)"
else
  ok "the served tree (${SERVED_PRESENT[*]}) weighs $TREE_BYTES B / $MAX_TREE_BYTES B"
fi
if (( ${#TREE_FILES[@]} > MAX_TREE_FILES )); then
  fail "the served tree has ${#TREE_FILES[@]} files > $MAX_TREE_FILES"
else
  ok "the served tree has ${#TREE_FILES[@]} file(s) / $MAX_TREE_FILES"
fi

# --- summary ---------------------------------------------------------------
section "summary"
printf '  checked: %d check(s) over %d SKILL.md, %d .md file(s) and %d file(s) of the served tree\n' \
  "$N_CHECKED" "${#SKILL_FILES[@]}" "${#MD_FILES[@]}" "${#TREE_FILES[@]}"
printf '  served roots scanned: %s\n' "${SERVED_PRESENT[*]}"
if ((${#SERVED_ABSENT[@]} > 0)); then
  printf '  served roots ABSENT (not scanned because they do not exist): %s\n' "${SERVED_ABSENT[*]}"
fi
printf '  NOT checked (out of scope by design): the semantic CONTENT of the .md files;\n'
printf '    this gate bounds form, links, types and size, it does not judge text.\n'
if ((${#SKIPPED[@]} > 0)); then
  printf '  skipped in this run: %d\n' "${#SKIPPED[@]}"
  for s in "${SKIPPED[@]}"; do printf '    - %s\n' "$s"; done
fi

if (( FAILURES > 0 )); then
  printf '\ngate-plugin-integrity: rc=1 — %d MEASURED failure(s)\n' "$FAILURES" >&2
  exit 1
fi
printf '\ngate-plugin-integrity: rc=0 — measured and correct\n'
exit 0
