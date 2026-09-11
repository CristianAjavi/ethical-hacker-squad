#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Tests scripts/gh/protection-check.sh against a GitHub API double.
#
# WHY THIS FILE WAS REWRITTEN
#   It used to fabricate its own state.json declaring exactly the seven fields
#   the tool happened to read. Subject and judge came out of the same hand, so
#   the battery could not see what the tool did not look at, and its green was
#   eternal by construction: `dismiss_stale_reviews: true` was declared in
#   governance.json, shipped in the PUT, watched by nobody, and this suite
#   passed anyway.
#
#   Now the two sides come from two places that cannot agree by accident:
#     SUBJECT - fixtures/protection/*.json, captured live from the repository
#               with `gh api repos/.../branches/main/protection`. The whole
#               object, every key the API returns, including the ones the tool
#               is not supposed to compare. That is the point: a fixture that
#               only carries the compared fields cannot prove anything about
#               the uncompared ones.
#     JUDGE   - scripts/gh/governance.json, the real contract, read as it is.
#               Not a copy, not a reduction. `stable` is removed for the cases
#               about `main` because that branch does not exist yet and its rc 2
#               would mask every other verdict; it gets its own case below.
#
#   Consequence worth knowing before it surprises somebody: if governance.json
#   changes, the BASELINE case goes red until the fixture is captured again.
#   That is correct. The red says "the declared contract and the last observed
#   reality no longer agree", which is either drift to fix or a fixture to
#   refresh - and both need a human to look.
#
# FIXTURE PROVENANCE
#   main-protection.json  GET repos/CristianAjavi/ethical-hacker-squad/branches/
#                         main/protection, 2026-09-10, unmodified, only
#                         reindented and key-sorted by `jq -S`. Reviewed field
#                         by field: it carries no token, no credential and no
#                         URL with credentials in it - every `url` is a public
#                         api.github.com endpoint.
#   main-branch.json      GET repos/.../branches/main, same date, reduced to its
#                         four protection-bearing keys (name, protected,
#                         protection, protection_url). What was dropped is the
#                         `commit` and `_links` subtrees: commit metadata, a PGP
#                         signature and the maintainer's personal e-mail address,
#                         none of which is branch-protection policy. The
#                         reduction is declared here rather than done quietly,
#                         and it is still WIDER than what the tool reads (the
#                         tool reads only `.protected`).
#
# WHAT EACH CASE BUYS
#   Every field added to the comparison has a mutant here: flip that one field
#   in the fixture, the gate must go rc 1 and name it. A field with an assertion
#   and no mutant that dies is not watched, it is decorated.
#   Three cases cover the fail-closed side, which is the half that keeps the
#   table honest: an unknown key, a missing contract field, and proof that the
#   ruled-out keys really are ruled out and not just unnoticed.
#
# Zero network: `gh` is replaced by a script that answers from those fixtures.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
# ---------------------------------------------------------------------------
set -uo pipefail

SP="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd -- "$SP/../../.." && pwd -P)"
TOOL="$ROOT/scripts/gh/protection-check.sh"
FIX="$SP/fixtures/protection"
GOV="$ROOT/scripts/gh/governance.json"
[ -f "$TOOL" ] || { echo "  COULD NOT MEASURE: protection-check.sh is missing (rc 2)"; exit 2; }
[ -r "$GOV"  ] || { echo "  COULD NOT MEASURE: governance.json is missing (rc 2)"; exit 2; }
for f in main-protection.json main-branch.json; do
  [ -r "$FIX/$f" ] || { echo "  COULD NOT MEASURE: fixture $f is missing (rc 2)"; exit 2; }
done
command -v jq >/dev/null 2>&1 || { echo "  COULD NOT MEASURE: jq is missing (rc 2)"; exit 2; }

LAB="$(mktemp -d)"; trap 'rm -rf "$LAB"' EXIT
mkdir -p "$LAB/bin"
pass=0; fail=0; harness=0

# The contract, as it really is. `stable` is declared and does not exist; it is
# split off so the cases about main are not all rc 2.
jq '.branches |= {main: .main}' "$GOV" >"$LAB/state-main.json" || { echo "  COULD NOT MEASURE: cannot derive the main-only state (rc 2)"; exit 2; }
cp "$GOV" "$LAB/state-full.json"

# --- the double ------------------------------------------------------------
# It serves two files the harness rewrites per case, and LAB_MODE picks the
# exceptional shapes a real token actually produces.
cat > "$LAB/bin/gh" <<'GH'
#!/usr/bin/env bash
# Honours --jq, because the tool under test uses it and a double that ignores it
# hands back a whole JSON object where the caller expects one field. That is not
# a smaller double, it is a different API.
path=""; jqf=""; want_jq=0
for a in "$@"; do
  if [ "$want_jq" -eq 1 ]; then jqf="$a"; want_jq=0; continue; fi
  case "$a" in
    --jq) want_jq=1 ;;
    api|-*) ;;
    *) [ -z "$path" ] && path="$a" ;;
  esac
done
emit() { if [ -n "$jqf" ]; then printf '%s' "$1" | jq -r "$jqf"; else printf '%s\n' "$1"; fi; }

# Only `main` exists in this repository. `stable` is declared and absent, which
# is the live truth and the reason the full-contract case is rc 2.
case "$path" in
  */branches/main|*/branches/main/*) ;;
  *) exit 1 ;;
esac

case "$LAB_MODE:$path" in
  absent:*) exit 1 ;;
  noprot:*/branches/main/protection)  exit 1 ;;
  shallow:*/branches/main/protection) exit 1 ;;
  # What a token that may not read this endpoint actually gets: an ERROR OBJECT
  # on stdout AND a non-zero exit. Parsed without checking either, every field
  # comes back at its default and the branch looks protected by nothing. This is
  # the case that made the tool report DRIFT against a healthy main.
  errbody:*/branches/main/protection)
    emit '{"message":"Resource not accessible by integration","status":"403"}'; exit 1 ;;
  *:*/branches/main/protection) emit "$(cat "$LAB_DIR/prot.json")" ;;
  noprot:*/branches/main) emit "$(jq -c '.protected = false' "$LAB_DIR/branch.json")" ;;
  *:*/branches/main) emit "$(cat "$LAB_DIR/branch.json")" ;;
  *) emit '{}' ;;
esac
GH
chmod +x "$LAB/bin/gh"

cp "$FIX/main-branch.json" "$LAB/branch.json"

run() {  # <mode> <state> -> writes $LAB/out.txt, echoes the rc
  local rc=0
  LAB_MODE="$1" LAB_DIR="$LAB" PATH="$LAB/bin:$PATH" \
    bash "$TOOL" --state "$2" >"$LAB/out.txt" 2>&1 || rc=$?
  printf '%s' "$rc"
}

score() {  # <label> <rc> <want> [needle]
  local label="$1" rc="$2" want="$3" needle="${4:-}"
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || grep -qF -- "$needle" "$LAB/out.txt"; }; then
    printf '  PASS  %-56s rc=%s\n' "$label" "$rc"; pass=$((pass+1))
  else
    printf '  FAIL  %-56s rc=%s (expected %s)\n' "$label" "$rc" "$want"
    [ -n "$needle" ] && printf '        looked for: %s\n' "$needle"
    sed 's/^/        | /' "$LAB/out.txt" | tail -10; fail=$((fail+1))
  fi
}

# Applies a jq mutation to the captured fixture and PROVES it changed something.
# A filter that matches nothing does not fail in jq, it returns the input
# untouched; the case would then be measuring the baseline under another name.
mutate() {  # <jq filter>
  jq -c "$1" "$FIX/main-protection.json" >"$LAB/prot.json" 2>/dev/null || return 1
  jq -c . "$FIX/main-protection.json" >"$LAB/base.json" || return 1
  cmp -s "$LAB/prot.json" "$LAB/base.json" && return 1
  return 0
}

mut() {  # <label> <jq filter> <want rc> [needle]
  if ! mutate "$2"; then
    printf '  HARNESS  %-53s the mutation changed nothing or jq failed\n' "$1"
    harness=$((harness+1)); return
  fi
  score "$1" "$(run normal "$LAB/state-main.json")" "$3" "${4:-}"
}

echo "== BASELINE: the live capture vs the real governance.json"
jq -c . "$FIX/main-protection.json" >"$LAB/prot.json"
score "the captured state matches the declared one -> rc 0" \
      "$(run normal "$LAB/state-main.json")" 0 "15 fields compared"

echo ""
echo "== One mutant per compared field: flip it in the capture -> rc 1 and NAME it"
mut "strict"             '.required_status_checks.strict = true'                          1 "strict: live=true declared=false"
mut "contexts"           '.required_status_checks.checks = [{context:"gates",app_id:15368}]' 1 "contexts: live="
mut "pr_required"        'del(.required_pull_request_reviews)'                             1 "pr_required: live=false declared=true"
mut "approvals"          '.required_pull_request_reviews.required_approving_review_count = 1' 1 "approvals: live=1 declared=0"
mut "code_owner_review"  '.required_pull_request_reviews.require_code_owner_reviews = true' 1 "code_owner_review: live=true declared=false"
mut "dismiss_stale"      '.required_pull_request_reviews.dismiss_stale_reviews = false'    1 "dismiss_stale: live=false declared=true"
mut "last_push_approval" '.required_pull_request_reviews.require_last_push_approval = true' 1 "last_push_approval: live=true declared=false"
mut "enforce_admins"     '.enforce_admins.enabled = true'                                  1 "enforce_admins: live=true declared=false"
mut "linear_history"     '.required_linear_history.enabled = false'                        1 "linear_history: live=false declared=true"
mut "force_pushes"       '.allow_force_pushes.enabled = true'                              1 "force_pushes: live=true declared=false"
mut "deletions"          '.allow_deletions.enabled = true'                                 1 "deletions: live=true declared=false"
mut "block_creations"    '.block_creations.enabled = true'                                 1 "block_creations: live=true declared=false"
mut "conversation_res"   '.required_conversation_resolution.enabled = false'               1 "conversation_res: live=false declared=true"
mut "lock_branch"        '.lock_branch.enabled = true'                                     1 "lock_branch: live=true declared=false"
mut "fork_syncing"       '.allow_fork_syncing.enabled = true'                              1 "fork_syncing: live=true declared=false"

echo ""
echo "== Fail closed: what the table has no ruling on is rc 2, not a pass"
mut "a NEW top-level key GitHub did not use to return"  '.required_deployments = {enabled:true}' 2 "no ruling on"
mut "a NEW key inside required_pull_request_reviews"    '.required_pull_request_reviews.dismissal_restrictions = {users:[]}' 2 "no ruling on"
mut "a contract field absent from the live block"       'del(.lock_branch)'                      2 "missing field(s) the contract compares: lock_branch"

echo ""
echo "== The ruled-out keys are ruled out on purpose, not by luck"
# If either of these produced a drift, the ruling in the header would be a lie:
# the tool would be comparing something it says it does not compare.
mut "required_signatures flipped -> still rc 0"  '.required_signatures.enabled = true'            0 "matches the declared"
mut "the deprecated contexts mirror emptied"     '.required_status_checks.contexts = []'          0 "matches the declared"

echo ""
echo "== The shapes a real token produces"
jq -c . "$FIX/main-protection.json" >"$LAB/prot.json"
score "NO protection at all -> rc 1"                    "$(run noprot  "$LAB/state-main.json")" 1 "is NOT protected at all"
# What a workflow token actually sees: the branch says it is protected and the
# block is unreadable without admin. Protected-at-all is confirmed; matching the
# declaration is not, and the tool must not round that up to a pass.
score "protected but the block is unreadable -> rc 2"   "$(run shallow "$LAB/state-main.json")" 2 "cannot read the protection block"
score "an error body is not an empty protection -> rc 2" "$(run errbody "$LAB/state-main.json")" 2 "cannot read the protection block"
score "the branch does not exist -> rc 2"               "$(run absent  "$LAB/state-main.json")" 2 "does not exist yet"
score "the full contract: stable is declared and absent -> rc 2" \
      "$(run normal "$LAB/state-full.json")" 2 "does not exist yet"

# gh absent is not a pass: without it nothing was read. The PATH keeps jq and
# the core utilities - emptying it entirely only proves that a script with no
# interpreter does not run, which is not the question.
mkdir -p "$LAB/nogh"
for t in jq sed awk grep; do
  p="$(command -v "$t" 2>/dev/null)" && ln -sf "$p" "$LAB/nogh/$t"
done
rc=0; PATH="$LAB/nogh:/usr/bin:/bin" bash "$TOOL" --state "$LAB/state-main.json" >"$LAB/out.txt" 2>&1 || rc=$?
score "gh missing -> rc 2" "$rc" 2

echo ""
if [ "$harness" -gt 0 ]; then
  echo "  $harness HARNESS FAULT(S): a mutation that changes nothing measures the baseline twice."
  echo "  $pass PASS / $fail FAIL"
  exit 2
fi
echo "  $pass PASS / $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
exit 0
