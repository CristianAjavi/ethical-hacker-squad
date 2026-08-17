#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-agent-tools.sh — the audit-only posture, measured instead of asserted.
#
# WHY IT EXISTS
#   docs/gate-requirements.md G1 has always said that an auditor agent must not
#   list `Edit`, `Write` or `NotebookEdit`. Measured on 2026-08-16: no script
#   under scripts/gates/ mentioned those three names. The single most-cited
#   safety invariant of this repository was specified and enforced by nothing at
#   review time. A specified-and-unimplemented safety control is worse than an
#   absent one, because the specification reads like a guarantee.
#
#   The second half of this gate is the uncomfortable half. Removing `Edit` and
#   `Write` from an auditor does NOT make it read-only: every auditor keeps
#   `Bash`, and `printf > file` is a write. `Bash` cannot be taken away — the
#   auditors need a shell to measure anything. What can be required is that the
#   restriction the auditor must obey is written in the agent's own body, where
#   the model actually reads it, and not only in a README nobody loads at run
#   time. So: no write TOOL, and an explicit shell-write PROHIBITION in the
#   contract itself.
#
# WHAT IT MEASURES
#   1. The spec is still the spec. docs/gate-requirements.md carries the anchored
#      G1 region this gate implements, and that region still names the three
#      write tools and the shell restriction. Gate and contract cannot drift
#      apart silently: deleting the requirement fails the gate that enforces it.
#   2. Every agent declares a `tools` list. An agent WITHOUT a `tools:` key
#      inherits every tool the main thread has, `Write` included. Silence is the
#      most dangerous declaration in the file and it is treated as one.
#   3. Role, derived from a DECLARED WRITE AUTHORITY, never from a file name.
#      An agent is treated as write-authorised only if its own text contains one
#      of the accepted declarations below. Everything else — new file, renamed
#      file, file that forgot to declare — defaults to auditor, the strict
#      branch. Renaming ehs-remediator.md cannot blind this gate; at worst the
#      remediator falls into the strict branch and the gate goes RED, which is
#      the correct direction for a safety check to fail in.
#   4. At most EHS_MAX_WRITE_AGENTS (default 1) agents may declare write
#      authority. Without the cap, "derive the role from the declaration" would
#      mean any agent could grant itself `Write` by adding a sentence.
#   5. Auditors list no write tool. Write-authorised agents must actually list
#      one, or harden mode is broken and nobody would notice until an engagement.
#   6. Every agent carrying `Bash` carries the scope block that matches its role:
#        auditor  — an explicit prohibition on writing through the shell;
#        writer   — writes bounded to what the leader authorised, plus the list
#                   of operations it may not perform without authorisation.
#   7. The claim surface. README.md, CHANGELOG.md and CONTRIBUTING.md may not
#      sell this control as complete: a sentence that says auditors ship without
#      `Edit`/`Write` must carry, within its window, the caveat that `Bash`
#      remains and the tree is checked afterwards. Absolutes ("cannot write",
#      "guarantees") fail outright. The repository is allowed to describe the
#      control; it is not allowed to oversell it.
#
# WHAT IT DOES *NOT* MEASURE — read this before quoting the gate as a guarantee
#   - It reads declarations, not behaviour. The harness is what actually denies a
#     tool at run time; this gate only proves the declaration says what the
#     contract requires.
#   - It cannot prove an auditor obeyed the prohibition it declares. Only
#     `git status --porcelain` after an `audit` run can, and that is a runtime
#     check, not a review-time one.
#   - It cannot classify a third-party MCP tool (`mcp__server__whatever`) as
#     read or write from its name. If one ever appears in an agent's `tools`,
#     this gate exits 2 rather than guessing in the permissive direction.
#
# EXIT CODES (repo contract: an rc=0 never means "I did not check it")
#   0 = I MEASURED and it conforms
#   1 = I MEASURED and it FAILS
#   2 = I COULD NOT MEASURE (missing agents/, unreadable agent, unterminated
#       frontmatter, unclassifiable tool, missing spec or claim file). Never a
#       pass.
#
# ENVIRONMENT VARIABLES
#   EHS_REPO_ROOT         repo root (otherwise: git, otherwise the script's ancestor)
#   EHS_MAX_WRITE_AGENTS  how many agents may declare write authority (default 1)
# ---------------------------------------------------------------------------
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FAILURES=0
N_CHECKED=0

ok()      { printf '  [OK]   %s\n' "$*"; N_CHECKED=$((N_CHECKED + 1)); }
fail()    { printf '  [FAIL] %s\n' "$*" >&2; N_CHECKED=$((N_CHECKED + 1)); FAILURES=$((FAILURES + 1)); }
info()    { printf '         %s\n' "$*"; }
section() { printf '\n== %s\n' "$*"; }

unmeasurable() {
  printf '\n[COULD NOT MEASURE] %s\n' "$*" >&2
  printf 'gate-agent-tools: rc=2 (not a pass; it is absence of measurement)\n' >&2
  exit 2
}

# --- 0. tools --------------------------------------------------------------
section "tools"
for tool in awk grep sed sort mktemp find; do
  command -v "$tool" >/dev/null 2>&1 || unmeasurable "the tool '$tool' is missing"
done
ok "POSIX utilities available"

TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t ehsagenttools)" \
  || unmeasurable "I could not create a temporary directory"
cleanup() { [ -n "${TMPD:-}" ] && command rm -rf "$TMPD" 2>/dev/null; }
trap cleanup EXIT

# --- 1. root ---------------------------------------------------------------
section "root"
if [ -n "${EHS_REPO_ROOT:-}" ]; then
  ROOT="$EHS_REPO_ROOT"
elif ROOT=$(git -C "$SELF_DIR" rev-parse --show-toplevel 2>/dev/null); then
  :
else
  ROOT="$(cd "$SELF_DIR/../.." && pwd)"
fi
[ -d "$ROOT" ] || unmeasurable "root '$ROOT' does not exist"
info "root: $ROOT"

AGENTS_DIR="$ROOT/agents"
[ -d "$AGENTS_DIR" ] || unmeasurable \
  "there is no agents/ directory under '$ROOT': the tool posture of a squad with no agents cannot be certified"
ok "agents/ found"

MAX_WRITE_AGENTS="${EHS_MAX_WRITE_AGENTS:-1}"
case "$MAX_WRITE_AGENTS" in
  ''|*[!0-9]*) unmeasurable "EHS_MAX_WRITE_AGENTS='$MAX_WRITE_AGENTS' is not a number" ;;
esac

# ---------------------------------------------------------------------------
# CLASSIFICATION TABLES. Kept here, in the gate, and not in a file the agents
# could edit. `TodoWrite` is deliberately on the read side: it writes a task
# list, never the working tree — and it is exactly the kind of name a substring
# match on "Write" would flag. Entries are compared whole, after stripping any
# `Tool(scope:*)` suffix, so `NotebookEdit` is never mistaken for `Edit`.
# ---------------------------------------------------------------------------
WRITE_TOOLS='Edit MultiEdit Write NotebookEdit'
SHELL_TOOLS='Bash'
READ_TOOLS='Read Grep Glob Task Agent WebFetch WebSearch NotebookRead TodoWrite TodoRead BashOutput KillBash KillShell SlashCommand ExitPlanMode AskUserQuestion Skill ListMcpResources ReadMcpResource'

in_list() { # in_list <needle> <space separated list>
  local needle="$1" item
  for item in $2; do [ "$needle" = "$item" ] && return 0; done
  return 1
}

# ---------------------------------------------------------------------------
# DECLARED WRITE AUTHORITY — the closed list of accepted declarations.
#
# The machine-readable marker is the form new agents should use; the prose forms
# are the ones already in the tree, kept so the gate measures the repository as
# it is rather than as it would be convenient. A line that also carries a
# negation (not / never / no) is NOT a declaration: "you do not write to the
# working tree" must never be read as write authority.
# ---------------------------------------------------------------------------
WRITE_AUTHORITY_PATTERNS='<!--[[:space:]]*role:[[:space:]]*write-authoris(ed|ing)|<!--[[:space:]]*role:[[:space:]]*write-authoriz(ed|ing)
you are the only (member|agent)[^.]{0,60}that writes to the working tree
the only (member|agent)[^.]{0,60}(authorised|authorized) to write to the working tree'
NEGATION_RE='(^|[^[:alnum:]_])(not|never|no|none|cannot)([^[:alnum:]_]|$)'

# Auditor + Bash: the prohibition must tie the SHELL to NOT WRITING, and it must
# be ADDRESSED TO THE AGENT. Two restrictions, both learned from a fixture:
#   - "leave the tree as you found it" is not accepted: it never names the
#     instrument, so it does not tell the model that `Bash` is included;
#   - the second person is required, because the first version of these patterns
#     accepted a sentence that merely *described* the restriction in the third
#     person. Measured: the fixture bad/02, whose whole point is that it carries
#     no contract, passed on its own closing remark ("Nothing in this file tells
#     the model that the shell may not be used to modify the audited tree").
#     Prose about a rule is not a rule. An agent contract says "you".
AUDITOR_SCOPE_PATTERNS='you (must not|may not|will never|never|do not|cannot|are not to)[^.]{0,60}(write|writes|writing|modify|modifies|create|creates)[^.]{0,60}(through|via|using|with)[^.]{0,25}.?(bash|shell)
(bash|shell)[^.]{0,80}you (must not|may not|will never|never|cannot|are not to)[^.]{0,30}(write|writes|writing|modify|modifies)'

# Write-authorised + Bash: writes bounded to what the leader authorised (a), and
# an explicit list of operations forbidden without authorisation (b). Both.
WRITER_SCOPE_BOUND_PATTERNS='writes? only what the leader (authorised|authorized)
only[^.]{0,40}(files|paths)[^.]{0,40}(the leader|authoris|authoriz)
confirm the exact file paths you own'
WRITER_SCOPE_AUTHZ_PATTERNS='without (explicit )?(authorisation|authorization)
requires? explicit (authorisation|authorization)'

# matches_any_pattern <file> <newline-separated ERE list> [outvar-for-line]
# Prints the first matching "line:text" on stdout when it matches.
matches_any_pattern() {
  local file="$1" patterns="$2" pat hit
  while IFS= read -r pat; do
    [ -n "$pat" ] || continue
    hit="$(grep -niE "$pat" "$file" 2>/dev/null | head -1)"
    if [ -n "$hit" ]; then printf '%s\n' "$hit"; return 0; fi
  done <<EOF
$patterns
EOF
  return 1
}

# Same, but a line carrying a negation does not count as a declaration.
matches_any_pattern_affirmative() {
  local file="$1" patterns="$2" pat line
  while IFS= read -r pat; do
    [ -n "$pat" ] || continue
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      if printf '%s\n' "$line" | grep -qiE "$NEGATION_RE"; then continue; fi
      printf '%s\n' "$line"; return 0
    done <<EOF2
$(grep -niE "$pat" "$file" 2>/dev/null)
EOF2
  done <<EOF
$patterns
EOF
  return 1
}

# --- 2. the spec this gate implements --------------------------------------
# A gate whose contract can be deleted without the gate noticing is a gate that
# will one day enforce a rule nobody agreed to, or stop enforcing one everybody
# still believes in. The anchored region is the handshake.
section "the contract in docs/gate-requirements.md"
SPEC_REL="docs/gate-requirements.md"
SPEC="$ROOT/$SPEC_REL"
if [ ! -f "$SPEC" ]; then
  unmeasurable "$SPEC_REL does not exist: I cannot check the tree against a contract that is not there"
fi
[ -r "$SPEC" ] || unmeasurable "$SPEC_REL is not readable"

SPEC_REGION="$TMPD/spec-region.txt"
awk '
  /<!--[[:space:]]*gate:agent-tools[[:space:]]+spec-begin[[:space:]]*-->/ { inr=1; next }
  /<!--[[:space:]]*gate:agent-tools[[:space:]]+spec-end[[:space:]]*-->/   { inr=0; next }
  inr { print }
' "$SPEC" > "$SPEC_REGION"

if [ ! -s "$SPEC_REGION" ]; then
  fail "$SPEC_REL carries no <!-- gate:agent-tools spec-begin/-end --> region: this gate is enforcing a rule the contract no longer states"
else
  ok "$SPEC_REL declares the region this gate implements"
  SPEC_MISSING=""
  for token in 'Edit' 'Write' 'NotebookEdit' 'Bash' 'scope'; do
    grep -qiE "(^|[^[:alnum:]_])${token}([^[:alnum:]_]|\$)" "$SPEC_REGION" \
      || SPEC_MISSING="$SPEC_MISSING[$token] "
  done
  if [ -n "$SPEC_MISSING" ]; then
    fail "the G1 region of $SPEC_REL no longer names: $SPEC_MISSING- gate and contract disagree, which is itself the bug"
  else
    ok "the G1 region still names the three write tools, the shell and the scope requirement"
  fi
fi

# --- 3. agent inventory and frontmatter ------------------------------------
section "agents"
AGENTS_LIST="$TMPD/agents.txt"
find "$AGENTS_DIR" -type f -name '*.md' 2>/dev/null | LC_ALL=C sort > "$AGENTS_LIST"
N_AGENTS="$(wc -l < "$AGENTS_LIST" | tr -d ' ')"
[ "$N_AGENTS" -gt 0 ] || unmeasurable "agents/ contains no .md file: there is nothing to measure"
info "$N_AGENTS agent definition(s) found"

FACTS="$TMPD/facts.tsv"   # rel <TAB> role <TAB> hasbash <TAB> writetools <TAB> ntools
: > "$FACTS"

while IFS= read -r AF; do
  REL="${AF#"$ROOT"/}"
  [ -r "$AF" ] || unmeasurable "$REL is not readable: I cannot certify the tool posture of an agent I cannot open"

  KV="$TMPD/kv.txt"
  awk '
    function flush() {
      if (nofm) { print "FM\t0"; return }
      print "FM\t1"
      print "FMCLOSED\t" (closed ? 1 : 0)
      print "TOOLSDECL\t" toolsdecl
      print "TOOLS\t" tools
      print "DESC\t" desc
      print "BODYSTART\t" bodystart
    }
    NR == 1 {
      if ($0 !~ /^---[[:space:]]*$/) { nofm = 1; exit }
      state = 1; next
    }
    state == 1 && /^---[[:space:]]*$/ { state = 2; closed = 1; bodystart = NR + 1; next }
    state == 1 {
      line = $0
      if (line ~ /^tools:/) {
        v = line; sub(/^tools:[[:space:]]*/, "", v)
        toolsdecl = 1
        if (v ~ /^[[:space:]]*$/) { inblock = 1 } else { tools = v; inblock = 0 }
        next
      }
      if (line ~ /^description:/) {
        v = line; sub(/^description:[[:space:]]*/, "", v); desc = v; inblock = 0; next
      }
      if (inblock == 1) {
        if (line ~ /^[[:space:]]+-[[:space:]]*/) {
          v = line; sub(/^[[:space:]]*-[[:space:]]*/, "", v)
          tools = (tools == "" ? v : tools ", " v)
          next
        }
        if (line ~ /^[^[:space:]]/) { inblock = 0 }
      }
      next
    }
    END { flush() }
  ' "$AF" > "$KV"

  get() { awk -F'\t' -v k="$1" '$1 == k { sub(/^[^\t]*\t/, ""); print; exit }' "$KV"; }

  HAS_FM="$(get FM)"
  if [ "$HAS_FM" != "1" ]; then
    fail "$REL has no YAML frontmatter: it declares no tool list, so it inherits every tool of the main thread, \`Write\` included"
    printf '%s\t%s\t%s\t%s\t%s\n' "$REL" "auditor" "unknown" "INHERITS-ALL" "0" >> "$FACTS"
    continue
  fi
  if [ "$(get FMCLOSED)" != "1" ]; then
    unmeasurable "$REL opens frontmatter and never closes it: I cannot tell its declaration from its body"
  fi

  TOOLS_RAW="$(get TOOLS)"
  DESC="$(get DESC)"
  BODYSTART="$(get BODYSTART)"

  # The agent's own text = description + body. The body is what the model reads
  # at run time; the description is part of the same contract.
  TEXT="$TMPD/text.txt"
  { printf '%s\n' "$DESC"; awk -v s="$BODYSTART" 'NR >= s' "$AF"; } > "$TEXT"

  # -- role ----------------------------------------------------------------
  ROLE="auditor"
  ROLE_EVIDENCE=""
  if ROLE_EVIDENCE="$(matches_any_pattern_affirmative "$TEXT" "$WRITE_AUTHORITY_PATTERNS")"; then
    ROLE="write-authorised"
  fi

  # -- tools ---------------------------------------------------------------
  if [ "$(get TOOLSDECL)" != "1" ]; then
    fail "$REL declares no \`tools:\` key: an agent with no tool list inherits every tool, \`Write\` and \`Edit\` included. Silence is not a restriction"
    printf '%s\t%s\t%s\t%s\t%s\n' "$REL" "$ROLE" "unknown" "INHERITS-ALL" "0" >> "$FACTS"
    continue
  fi

  HAS_BASH="no"; WRITE_FOUND=""; N_TOOLS=0
  # `set -f` is load-bearing, not hygiene: `tools: *` is a real declaration, and
  # word-splitting it unquoted made the shell expand the glob against the
  # working directory. Measured: the gate reported "I cannot classify the tool
  # 'CHANGELOG.md'" (rc=2) instead of "unbounded list" (rc=1) - the wildcard,
  # the most permissive declaration a file can carry, escaped through a shell
  # feature. The battery caught it; without globbing off it comes straight back.
  set -f
  OLDIFS="$IFS"; IFS=','
  for RAWTOOL in $TOOLS_RAW; do
    IFS="$OLDIFS"
    ENTRY="$(printf '%s' "$RAWTOOL" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^["'"'"']//' -e 's/["'"'"']$//')"
    [ -n "$ENTRY" ] || { IFS=','; continue; }
    N_TOOLS=$((N_TOOLS + 1))
    BASE="$(printf '%s' "$ENTRY" | sed -e 's/(.*$//' -e 's/[[:space:]]*$//')"
    case "$ENTRY" in
      '*'|'all'|'All'|'ALL')
        fail "$REL lists '$ENTRY' as a tool: an unbounded list includes every write tool"
        WRITE_FOUND="$WRITE_FOUND$ENTRY "
        HAS_BASH="yes"
        IFS=','; continue ;;
    esac
    if in_list "$BASE" "$WRITE_TOOLS"; then
      WRITE_FOUND="$WRITE_FOUND$BASE "
    elif in_list "$BASE" "$SHELL_TOOLS"; then
      HAS_BASH="yes"
    elif in_list "$BASE" "$READ_TOOLS"; then
      :
    else
      unmeasurable "$REL lists the tool '$ENTRY', which I cannot classify as read or write (third-party or unknown tool). I will not guess in the permissive direction"
    fi
    IFS=','
  done
  IFS="$OLDIFS"

  [ "$N_TOOLS" -gt 0 ] || fail "$REL has an empty \`tools:\` list"

  WRITE_FOUND="$(printf '%s' "$WRITE_FOUND" | sed -e 's/[[:space:]]*$//')"
  printf '%s\t%s\t%s\t%s\t%s\n' "$REL" "$ROLE" "$HAS_BASH" "${WRITE_FOUND:--}" "$N_TOOLS" >> "$FACTS"

  if [ "$ROLE" = "write-authorised" ]; then
    info "$REL — role: write-authorised (declared at line ${ROLE_EVIDENCE%%:*} of description+body)"
  else
    info "$REL — role: auditor (no write-authority declaration; the strict branch is the default)"
  fi
done < "$AGENTS_LIST"

# --- 4. how many agents may write ------------------------------------------
section "write authority"
N_WRITERS="$(awk -F'\t' '$2 == "write-authorised"' "$FACTS" | wc -l | tr -d ' ')"
if [ "$N_WRITERS" -gt "$MAX_WRITE_AGENTS" ]; then
  fail "$N_WRITERS agents declare write authority; at most $MAX_WRITE_AGENTS may. Deriving the role from a declaration only works while the declaration is scarce:"
  awk -F'\t' '$2 == "write-authorised" { printf "         - %s\n", $1 }' "$FACTS" >&2
else
  ok "$N_WRITERS of $N_AGENTS agent(s) declare write authority (cap: $MAX_WRITE_AGENTS)"
fi

# --- 5. G1 core: auditors carry no write tool ------------------------------
section "write tools per role"
while IFS="$(printf '\t')" read -r REL ROLE HAS_BASH WRITE_FOUND N_TOOLS; do
  [ -n "$REL" ] || continue
  if [ "$ROLE" = "auditor" ]; then
    if [ "$WRITE_FOUND" = "-" ]; then
      ok "$REL lists no write tool"
    elif [ "$WRITE_FOUND" = "INHERITS-ALL" ]; then
      : # already reported as a failure when parsing
    else
      fail "$REL is an auditor and lists write tool(s): $WRITE_FOUND — G1 forbids \`Edit\`, \`Write\` and \`NotebookEdit\` on any agent that does not declare write authority"
    fi
  else
    if [ "$WRITE_FOUND" = "-" ]; then
      fail "$REL declares write authority but lists no write tool: harden mode would have no remediator and the run would fail silently at engagement time"
    else
      ok "$REL declares write authority and lists: $WRITE_FOUND"
    fi
  fi
done < "$FACTS"

# --- 6. the honest half: Bash carriers declare their scope -----------------
# Every agent here keeps `Bash`, and `Bash` writes. The tool list is therefore
# only half a control; the other half is a restriction stated where the model
# reads it. An agent that carries a shell and does not carry its restriction has
# no audit-only posture at all, whatever its tool list says.
section "shell scope block"
while IFS="$(printf '\t')" read -r REL ROLE HAS_BASH WRITE_FOUND N_TOOLS; do
  [ -n "$REL" ] || continue
  if [ "$HAS_BASH" = "no" ]; then
    ok "$REL carries no shell: nothing to restrict"
    continue
  fi
  if [ "$HAS_BASH" = "unknown" ]; then
    fail "$REL — I could not determine whether it carries a shell (no tool list); its scope block cannot be checked either"
    continue
  fi

  AF="$ROOT/$REL"
  BODY="$TMPD/body.txt"
  awk 'f == 2 { print } /^---[[:space:]]*$/ { f++ }' "$AF" > "$BODY"

  if [ "$ROLE" = "auditor" ]; then
    if HIT="$(matches_any_pattern "$BODY" "$AUDITOR_SCOPE_PATTERNS")"; then
      ok "$REL carries \`Bash\` and prohibits writing through it (body line ${HIT%%:*})"
    else
      fail "$REL carries \`Bash\` and its body never forbids writing through it. Removing \`Edit\`/\`Write\` from an agent that keeps a shell is half a control; the other half must be written in the contract the model reads. Accepted formulation, e.g.: 'You have no \`Edit\` or \`Write\` tool, and you must not write through \`Bash\` either.'"
    fi
  else
    BOUND=""; AUTHZ=""
    BOUND="$(matches_any_pattern "$BODY" "$WRITER_SCOPE_BOUND_PATTERNS")" || BOUND=""
    AUTHZ="$(matches_any_pattern "$BODY" "$WRITER_SCOPE_AUTHZ_PATTERNS")" || AUTHZ=""
    if [ -n "$BOUND" ] && [ -n "$AUTHZ" ]; then
      ok "$REL is write-authorised and bounds its writes (line ${BOUND%%:*}) and names what needs authorisation (line ${AUTHZ%%:*})"
    else
      MISS=""
      [ -n "$BOUND" ] || MISS="$MISS[writes bounded to what the leader authorised] "
      [ -n "$AUTHZ" ] || MISS="$MISS[operations forbidden without explicit authorisation] "
      fail "$REL is write-authorised, carries \`Bash\`, and its body is missing: $MISS- an agent that may write needs a stated boundary more than an auditor does, not less"
    fi
  fi
done < "$FACTS"

# --- 7. the claim surface ---------------------------------------------------
# The repository must not sell this control as complete. Every sentence that
# describes the auditors' tool restriction has to carry the caveat in its own
# window: the shell survives, so the tree is verified afterwards rather than
# assumed clean.
section "what the repository claims about this control"
# The three files a reader meets before installing anything. SKILL.md also
# describes this control, and today it describes it correctly (it is the file
# that says the quiet part: "not a complete one - they keep `Bash`"). It is not
# in the enforced set only because it belongs to the skill corpus and is edited
# on a different cadence; add it here the day its owners want it watched.
CLAIM_FILES="${EHS_CLAIM_FILES:-README.md CHANGELOG.md CONTRIBUTING.md}"
# NOTE: every line is lower-cased before matching, so these patterns are
# lower-case on purpose. Written with capitals they match nothing — which is
# how this check first ran green over a README that did carry the claim.
ROLE_TOKEN_RE='(auditor|auditors|subagent|subagents|specialist|specialists|agent|agents)'
CLAIM_TOKEN_RE='(`edit`|`write`|`notebookedit`|`multiedit`|read-only)'
CAVEAT_RE='(bash|shell|incomplete|not a guarantee|not every|partial|still|confirm|verif|git status|assum)'
ABSOLUTE_RE='(cannot write|can not write|unable to write|impossible to write|no write path|fully prevent|prevents any write|guarantee[sd]? (that )?[^.]{0,40}(cannot|never) write)'

for CF in $CLAIM_FILES; do
  CFP="$ROOT/$CF"
  if [ ! -f "$CFP" ]; then
    unmeasurable "$CF does not exist: I cannot check what the repository claims about a control it documents there"
  fi
  [ -r "$CFP" ] || unmeasurable "$CF is not readable"

  CLAIM_REPORT="$TMPD/claims.txt"
  awk -v role="$ROLE_TOKEN_RE" -v claim="$CLAIM_TOKEN_RE" -v caveat="$CAVEAT_RE" -v absolute="$ABSOLUTE_RE" '
    { line[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        lo = tolower(line[i])
        if (lo !~ role) continue
        isclaim  = (lo ~ claim)
        isabs    = (lo ~ absolute)
        if (!isclaim && !isabs) continue
        # window: the line itself, the one before and the two after
        w = ""
        for (j = (i - 1 < 1 ? 1 : i - 1); j <= (i + 2 > NR ? NR : i + 2); j++) w = w " " tolower(line[j])
        if (isabs)            { printf "ABSOLUTE\t%d\t%s\n", i, line[i]; continue }
        if (w !~ caveat)      { printf "UNQUALIFIED\t%d\t%s\n", i, line[i]; continue }
        printf "QUALIFIED\t%d\t%s\n", i, line[i]
      }
    }
  ' "$CFP" > "$CLAIM_REPORT"

  # An empty report is ambiguous on purpose-free reading: it can mean "every
  # claim carries its caveat" or "I matched nothing at all". The counts are
  # printed so nobody reads a vacuous pass as a verified one.
  N_QUAL="$(awk -F'\t' '$1 == "QUALIFIED"' "$CLAIM_REPORT" | wc -l | tr -d ' ')"
  N_BAD="$(awk -F'\t' '$1 != "QUALIFIED"' "$CLAIM_REPORT" | wc -l | tr -d ' ')"

  if [ "$N_BAD" -eq 0 ]; then
    if [ "$N_QUAL" -gt 0 ]; then
      ok "$CF — $N_QUAL statement(s) about the auditors' write restriction, all carrying the caveat"
      awk -F'\t' -v cf="$CF" '$1 == "QUALIFIED" { printf "         qualified at %s:%s\n", cf, $2 }' \
        "$CLAIM_REPORT"
    else
      ok "$CF makes no statement about the auditors' write restriction (nothing to qualify)"
    fi
  else
    while IFS="$(printf '\t')" read -r KIND LNO TXT; do
      [ -n "$KIND" ] || continue
      SNIP="$(printf '%s' "$TXT" | cut -c1-110)"
      case "$KIND" in
        ABSOLUTE)
          fail "$CF:$LNO states the control as absolute: \"$SNIP\" — the auditors keep \`Bash\`; no wording here may promise they cannot write" ;;
        UNQUALIFIED)
          fail "$CF:$LNO describes the tool restriction without the caveat that \`Bash\` remains and the tree is verified afterwards: \"$SNIP\"" ;;
      esac
    done < "$CLAIM_REPORT"
  fi
done

# --- 8. verdict -------------------------------------------------------------
section "summary"
info "agents measured      : $N_AGENTS"
info "write-authorised     : $N_WRITERS (cap $MAX_WRITE_AGENTS)"
info "shell carriers       : $(awk -F'\t' '$3 == "yes"' "$FACTS" | wc -l | tr -d ' ')"
info "checks run           : $N_CHECKED"
info "NOT measured here    : run-time behaviour, obedience to the declared restriction"
info "                       (that one is \`git status --porcelain\` after an audit run), and"
info "                       the write capability of any third-party MCP tool."

if [ "$FAILURES" -gt 0 ]; then
  printf '\ngate-agent-tools: rc=1 — %s failing check(s) of %s\n' "$FAILURES" "$N_CHECKED" >&2
  exit 1
fi
printf '\ngate-agent-tools: rc=0 — %s checks, no failures\n' "$N_CHECKED"
exit 0
