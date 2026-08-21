#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Self-test for gate-agent-tools.sh — the battery that proves the gate fails.
#
# A safety gate nobody has watched fail is a rumour. This builds a throwaway
# copy of the tree per case, breaks exactly one thing in it, and asserts BOTH
# the exit code and the sentence the gate is supposed to say. Asserting only the
# code would let a gate pass this battery for the wrong reason - failing on a
# fixture because of an unrelated defect looks identical to failing on the
# defect the fixture carries.
#
# Nothing here touches the real tree: every case runs with EHS_REPO_ROOT
# pointing at its own copy.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = could not run.
#
# ENVIRONMENT
#   EHS_REPO_ROOT          the tree to copy the base from (default: this repo)
#   EHS_SELFTEST_WORKDIR   where the cases are built. When set, the cases are
#                          KEPT after the run, as evidence. Default: mktemp -d,
#                          removed on exit.
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$HERE/gate-agent-tools.sh"
FIX="$HERE/fixtures/agent-tools"

[ -x "$GATE" ] || { printf 'COULD NOT MEASURE: %s is not executable.\n' "$GATE" >&2; exit 2; }
[ -d "$FIX" ]  || { printf 'COULD NOT MEASURE: fixtures missing at %s.\n' "$FIX" >&2; exit 2; }

if [ -n "${EHS_REPO_ROOT:-}" ]; then
  SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then
  :
else
  SRC="$(cd "$HERE/../.." && pwd)"
fi
for need in agents docs/gate-requirements.md README.md CHANGELOG.md CONTRIBUTING.md; do
  [ -e "$SRC/$need" ] || { printf 'COULD NOT MEASURE: %s has no %s.\n' "$SRC" "$need" >&2; exit 2; }
done

if [ -n "${EHS_SELFTEST_WORKDIR:-}" ]; then
  W="$EHS_SELFTEST_WORKDIR"; KEEP=1
  mkdir -p "$W" || { printf 'COULD NOT MEASURE: cannot create %s.\n' "$W" >&2; exit 2; }
else
  W="$(mktemp -d)" || { printf 'COULD NOT MEASURE: no temporary directory.\n' >&2; exit 2; }; KEEP=0
fi
cleanup() { [ "$KEEP" = "1" ] || command rm -rf "$W" 2>/dev/null; }
trap cleanup EXIT

printf 'Self-test for gate-agent-tools.sh\n=================================\n'
printf 'source tree : %s\n' "$SRC"
printf 'cases in    : %s%s\n\n' "$W" "$( [ "$KEEP" = 1 ] && printf ' (kept as evidence)' )"

# mkcase <name> -> prints the case root, a copy of the parts the gate reads
mkcase() {
  local c="$W/$1"
  [ -d "$c" ] && command rm -rf "$c"
  mkdir -p "$c/docs" || return 1
  cp -R "$SRC/agents" "$c/agents" || return 1
  cp "$SRC/docs/gate-requirements.md" "$c/docs/" || return 1
  cp "$SRC/README.md" "$SRC/CHANGELOG.md" "$SRC/CONTRIBUTING.md" "$c/" || return 1
  printf '%s\n' "$c"
}

pass=0; fail=0
# check <name> <expected rc> <expected substring or -> <case root> [VAR=VAL ...]
check() {
  local name="$1" want="$2" needle="$3" root="$4"; shift 4
  local out rc
  out="$(env EHS_REPO_ROOT="$root" "$@" bash "$GATE" 2>&1)"; rc=$?
  if [ "$rc" -ne "$want" ]; then
    printf '  FAIL  %-46s rc=%s (expected %s)\n' "$name" "$rc" "$want"; fail=$((fail+1))
    printf '%s\n' "$out" | grep -E '\[FAIL\]|COULD NOT MEASURE' | sed 's/^/        | /' | head -6
    return
  fi
  if [ "$needle" != "-" ] && ! printf '%s' "$out" | grep -qF "$needle"; then
    printf '  FAIL  %-46s rc=%s but never said: %s\n' "$name" "$rc" "$needle"; fail=$((fail+1))
    printf '%s\n' "$out" | grep -E '\[FAIL\]|COULD NOT MEASURE' | sed 's/^/        | /' | head -6
    return
  fi
  printf '  ok    %-46s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  if [ "$needle" != "-" ]; then
    printf '%s\n' "$out" | grep -F "$needle" | head -1 | sed 's/^ *//; s/^/          > /'
  fi
}

# --- CONTROL: an untouched copy must be green ------------------------------
printf '\n-- control\n'
C="$(mkcase control)" || { printf 'COULD NOT MEASURE: cannot build a case.\n' >&2; exit 2; }
check "untouched copy of the tree" 0 "no failures" "$C"

# --- rc=1: the tool list ---------------------------------------------------
printf '\n-- rc=1  the tool list\n'
C="$(mkcase auditor-with-write)"; cp "$FIX/bad/01-auditor-with-write.md" "$C/agents/"
check "auditor listing Write" 1 "is an auditor and lists write tool(s): Write" "$C"

C="$(mkcase auditor-notebookedit)"; cp "$FIX/bad/06-auditor-notebookedit.md" "$C/agents/"
check "auditor listing NotebookEdit" 1 "lists write tool(s): NotebookEdit" "$C"

C="$(mkcase no-tools-key)"; cp "$FIX/bad/03-no-tools-key.md" "$C/agents/"
check "agent with no tools key (inherits all)" 1 "declares no \`tools:\` key" "$C"

C="$(mkcase empty-tools)"; cp "$FIX/bad/09-empty-tools.md" "$C/agents/"
check "agent with an empty tools list" 1 "has an empty \`tools:\` list" "$C"

C="$(mkcase wildcard-tools)"; cp "$FIX/bad/07-wildcard-tools.md" "$C/agents/"
check "wildcard tool list" 1 "an unbounded list includes every write tool" "$C"

C="$(mkcase no-frontmatter)"
printf 'You are an agent with no frontmatter at all.\n' > "$C/agents/ehs-fixture-no-frontmatter.md"
check "agent file with no frontmatter" 1 "has no YAML frontmatter" "$C"

# --- rc=1: role derivation -------------------------------------------------
printf '\n-- rc=1  role derivation\n'
C="$(mkcase second-writer)"; cp "$FIX/bad/04-second-write-authority.md" "$C/agents/"
check "a second agent declaring write authority" 1 "at most 1 may" "$C"

C="$(mkcase negated-authority)"; cp "$FIX/bad/08-negated-write-authority.md" "$C/agents/"
check "negated declaration must not grant authority" 1 "is an auditor and lists write tool(s): Write" "$C"

C="$(mkcase writer-no-write-tool)"; cp "$FIX/bad/05-writer-without-write-tool.md" "$C/agents/"
check "write authority without a write tool" 1 "lists no write tool" "$C" EHS_MAX_WRITE_AGENTS=2

# The two cases the whole design rests on. A gate that recognised the remediator
# by its file name would pass the first and fail nothing in the second.
C="$(mkcase remediator-renamed)"; mv "$C/agents/ehs-remediator.md" "$C/agents/ehs-patcher.md"
check "renaming the remediator does not blind the gate" 0 "no failures" "$C"

C="$(mkcase authority-sentence-lost)"
# The declaration rewritten in good faith, `Edit`/`Write` still in the list: the
# agent falls back into the strict branch and the gate goes red. That is the
# direction a safety check must fail in when its input drifts.
sed -e 's/You are the only member of the squad that writes to the working tree, and you write only what the leader authorized./You are the squad member responsible for patches./' \
  "$SRC/agents/ehs-remediator.md" > "$C/agents/ehs-remediator.md"
check "write-authority prose drift fails closed" 1 "is an auditor and lists write tool(s)" "$C"

# --- rc=1: the shell half --------------------------------------------------
printf '\n-- rc=1  the shell half\n'
C="$(mkcase bash-no-scope)"; cp "$FIX/bad/02-auditor-bash-no-scope.md" "$C/agents/"
check "auditor with Bash and no scope block" 1 "never forbids writing through it" "$C"

C="$(mkcase writer-bash-no-bounds)"
# The real remediator, stripped of the two sentences that bound its writes.
sed -e 's/, and you write only what the leader authorized//' \
    -e 's/^3\. Confirm the exact file paths you own.*$/3. Proceed./' \
    -e 's/^## What you must not do without explicit authorization$/## Notes/' \
    -e 's/without explicit authorization/at your discretion/g' \
    "$SRC/agents/ehs-remediator.md" > "$C/agents/ehs-remediator.md"
check "write-authorised agent with unbounded writes" 1 "is missing:" "$C"

# --- rc=1: the contract and the claim surface ------------------------------
printf '\n-- rc=1  contract and claims\n'
C="$(mkcase spec-region-deleted)"
awk '/gate:agent-tools spec-begin/{skip=1} !skip{print} /gate:agent-tools spec-end/{skip=0}' \
  "$SRC/docs/gate-requirements.md" > "$C/docs/gate-requirements.md"
check "G1 region deleted from the contract" 1 "carries no <!-- gate:agent-tools" "$C"

C="$(mkcase spec-region-gutted)"
sed -e 's/`NotebookEdit`/that other one/g' -e 's/NotebookEdit//g' \
  "$SRC/docs/gate-requirements.md" > "$C/docs/gate-requirements.md"
check "contract stops naming a forbidden tool" 1 "no longer names: [NotebookEdit]" "$C"

C="$(mkcase claim-absolute)"
printf '\nThe auditor agents cannot write to your repository.\n' >> "$C/README.md"
check "README selling the control as absolute" 1 "states the control as absolute" "$C"

C="$(mkcase claim-unqualified)"
printf '\nEvery auditor ships without `Edit` and `Write`.\n' >> "$C/CHANGELOG.md"
check "claim with no caveat in its window" 1 "without the caveat" "$C"

# --- rc=2: I COULD NOT MEASURE ---------------------------------------------
printf '\n-- rc=2  could not measure\n'
C="$(mkcase no-agents-dir)"; mv "$C/agents" "$C/agents-moved-away"
check "no agents/ directory" 2 "there is no agents/ directory" "$C"

C="$(mkcase empty-agents-dir)"; mv "$C/agents" "$C/agents-moved-away"; mkdir -p "$C/agents"
check "agents/ with no .md inside" 2 "contains no .md file" "$C"

C="$(mkcase unclassifiable-tool)"; cp "$FIX/unmeasurable/01-unclassifiable-tool.md" "$C/agents/"
check "third-party MCP tool in a tool list" 2 "which I cannot classify" "$C"

C="$(mkcase unterminated-frontmatter)"; cp "$FIX/unmeasurable/02-unterminated-frontmatter.md" "$C/agents/"
check "frontmatter never closed" 2 "never closes it" "$C"

C="$(mkcase no-spec)"; mv "$C/docs/gate-requirements.md" "$C/docs/gate-requirements.md.moved"
check "contract file missing" 2 "does not exist: I cannot check the tree" "$C"

C="$(mkcase no-readme)"; mv "$C/README.md" "$C/README.md.moved"
check "claim file missing" 2 "I cannot check what the repository claims" "$C"

if [ "$(id -u)" != "0" ]; then
  C="$(mkcase unreadable-agent)"; chmod 000 "$C/agents/ehs-verifier.md"
  check "an agent that cannot be opened" 2 "is not readable" "$C"
  chmod 644 "$C/agents/ehs-verifier.md" 2>/dev/null
else
  printf '  skip  %-46s (running as root: chmod 000 would not deny)\n' "unreadable agent"
fi

# --- FALSE-POSITIVE CONTROLS: the gate must stay quiet ---------------------
printf '\n-- rc=0  false-positive controls\n'
C="$(mkcase good-block-list)"; cp "$FIX/good/01-auditor-block-list.md" "$C/agents/"
check "block list, Bash(git:*), TodoWrite, NotebookRead" 0 "no failures" "$C"

C="$(mkcase good-no-shell)"; cp "$FIX/good/02-auditor-no-shell.md" "$C/agents/"
check "auditor with no shell needs no scope block" 0 "no failures" "$C"

C="$(mkcase good-marker)"; cp "$FIX/good/03-marker-write-authority.md" "$C/agents/"
check "machine-readable write-authority marker" 0 "no failures" "$C" EHS_MAX_WRITE_AGENTS=2

# --- FINAL CONTROL ---------------------------------------------------------
printf '\n-- final control\n'
C="$(mkcase final-control)"
check "an untouched copy is still green at the end" 0 "no failures" "$C"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
