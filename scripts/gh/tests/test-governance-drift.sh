#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# NEGATIVE TEST of the branch-protection comparator.
#
# governance.json declares a dozen protection fields. The question is whether
# the comparator LOOKS at all of them, or whether there are declared fields that
# nobody compares: a field declared and not compared produces an rc=0 that means
# "I did not review it", which is exactly what this doctrine forbids.
#
# Method: a double of the GitHub API is raised that answers exactly the desired
# state (baseline -> rc 0), and then ONE field at a time is deviated, requiring
# rc 1. If a field is deviated and the script still says rc 0, that field is
# declared but unwatched.
#
# Original finding of this suite: block_creations and allow_fork_syncing were
# declared in the JSON, were sent in the PUT, and were never compared.
#
# EXIT CODES:  0 everything watched / 1 there is a blind field / 2 could not run
# ---------------------------------------------------------------------------
set -uo pipefail
SP="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SP/../../.." && pwd)"
command -v jq >/dev/null 2>&1 || { echo "  COULD NOT MEASURE: jq is missing (rc 2)"; exit 2; }
command -v awk >/dev/null 2>&1 || { echo "  COULD NOT MEASURE: awk is missing (rc 2)"; exit 2; }

LAB="$(mktemp -d)"; trap 'rm -rf "$LAB"' EXIT
mkdir -p "$LAB/bin" "$LAB/repo/scripts/gh" "$LAB/repo/.github/workflows" "$LAB/repo/scripts/gates"
cp "$ROOT/scripts/gh/apply-governance.sh" "$LAB/repo/scripts/gh/"
cp "$ROOT/scripts/gh/governance.json"     "$LAB/repo/scripts/gh/"
# The label taxonomy is no longer declared in governance.json: apply-governance.sh
# delegates it to labels.sh and folds in its rc. Without this copy the delegate is
# missing and EVERY probe comes back rc=2, which would hide whether the protection
# fields are watched at all.
cp "$ROOT/scripts/gh/labels.sh"           "$LAB/repo/scripts/gh/"
# release.yml is the promotion workflow (promote-stable.yml was removed in the
# integration: two workflows were promoting to stable on the same cron).
# apply-governance.sh reads it to check that the workflow and governance.json
# talk about the same branches, labels and contexts.
cp "$ROOT/.github/workflows/release.yml" "$LAB/repo/.github/workflows/"
cp "$ROOT/.github/workflows/ci.yml"      "$LAB/repo/.github/workflows/"
printf '#!/usr/bin/env bash\nexit 0\n' >"$LAB/repo/scripts/gates/dummy.sh"
# Same reason as labels.sh above: apply-governance.sh delegates the two-list
# contract inside governance.json to gate-governance-contract.sh and folds in its
# rc. Without these copies the delegate is missing, every probe comes back rc=2
# (an unmeasured result outranks a drift, by design) and this file would stop
# measuring whether the protection fields are watched at all.
mkdir -p "$LAB/repo/scripts/gates/lib"
cp "$ROOT/scripts/gates/gate-governance-contract.sh" "$LAB/repo/scripts/gates/"
cp "$ROOT/scripts/gates/lib/governance_contract.py"  "$LAB/repo/scripts/gates/lib/"
cp "$ROOT/scripts/gates/lib/common.sh"               "$LAB/repo/scripts/gates/lib/"
cp -R "$ROOT/scripts/gates/fixtures/governance"      "$LAB/repo/scripts/gates/fixtures-tmp" 2>/dev/null || true
mkdir -p "$LAB/repo/scripts/gates/fixtures"
[ -d "$LAB/repo/scripts/gates/fixtures-tmp" ] && mv "$LAB/repo/scripts/gates/fixtures-tmp" "$LAB/repo/scripts/gates/fixtures/governance"
STATE="$LAB/repo/scripts/gh/governance.json"

# --- API double: returns the DESIRED state as if it were the real one --------
cat >"$LAB/bin/gh" <<EOF
#!/usr/bin/env bash
STATE="$STATE"
TAXONOMY="$LAB/repo/scripts/gh/labels.sh"
PROT_OVERRIDE="\${PROT_OVERRIDE:-}"
EOF
cat >>"$LAB/bin/gh" <<'EOF'
path=""; jqf=""
while [ $# -gt 0 ]; do
  case "$1" in
    api) ;;
    --jq) jqf="$2"; shift ;;
    --paginate|--method) [ "$1" = "--method" ] && shift ;;
    -*) ;;
    *) [ -z "$path" ] && path="$1" ;;
  esac
  shift
done
APP=$(jq -r '.actions_app_id' "$STATE")
# Real shape of the GET response: the booleans come nested in {enabled:...}
protection() {
  jq -c --argjson app "$APP" --arg b "$1" '
    .branches[$b].protection as $p
    | { allow_force_pushes:{enabled:($p.allow_force_pushes // false)},
        allow_deletions:{enabled:($p.allow_deletions // false)},
        required_linear_history:{enabled:($p.required_linear_history // false)},
        required_conversation_resolution:{enabled:($p.required_conversation_resolution // false)},
        lock_branch:{enabled:($p.lock_branch // false)},
        enforce_admins:{enabled:($p.enforce_admins // false)},
        block_creations:{enabled:($p.block_creations // false)},
        allow_fork_syncing:{enabled:($p.allow_fork_syncing // false)} }
      + (if $p.required_status_checks != null then
           {required_status_checks:{strict:$p.required_status_checks.strict,
             checks:[$p.required_status_checks.checks[] | {context:.context, app_id:$app}]}}
         else {} end)
      + (if $p.required_pull_request_reviews != null then
           {required_pull_request_reviews:$p.required_pull_request_reviews} else {} end)
  ' "$STATE"
}
case "$path" in
  user) out='{"login":"'"$(jq -r .expected_account "$STATE")"'"}' ;;
  repos/*/branches/*/protection)
    b=$(echo "$path" | awk -F/ '{print $5}'); out=$(protection "$b")
    [ -n "$PROT_OVERRIDE" ] && out=$(jq -c "$PROT_OVERRIDE" <<<"$out") ;;
  repos/*/branches/*) b=$(echo "$path" | awk -F/ '{print $5}'); out='{"name":"'"$b"'"}' ;;
  repos/*/topics) out=$(jq -c '{names: .topics}' "$STATE") ;;
  # The repo answers with exactly the taxonomy declared in labels.sh, so the
  # delegated 'labels.sh --check' sees no drift and the probes measure only the
  # protection fields. Reading it from labels.sh (not from a fixed list here)
  # keeps the double from going stale when the taxonomy changes.
  repos/*/labels*)
    out=$(grep -E '^[a-z]+/[a-z0-9-]+\|[0-9a-f]{6}\|' "$TAXONOMY" \
          | jq -R -s -c 'split("\n") | map(select(length > 0) | split("|")
                         | {name: .[0], color: .[1], description: .[2]})') ;;
  repos/*/vulnerability-alerts) exit 0 ;;
  repos/*/commits/*/check-runs)
    # DERIVED from governance.json, never hardcoded. A lab that knows about one
    # context reports every other one as "never observed", so the anti-lockout
    # safeguard fires as a false drift the day a second required check is
    # declared - which is exactly what happened when workflow-hardening was
    # added. LAB_HIDE_CONTEXT removes one on purpose, so that safeguard is
    # exercised deliberately instead of by accident.
    out=$(jq -c --argjson app "$APP" --arg hide "${LAB_HIDE_CONTEXT:-}" '
      ( [ .promotion.required_contexts[]? ]
        + [ .branches[.promotion.source_branch].protection.required_status_checks.checks[]?.context ] )
      | unique | map(select(. != $hide))
      | {check_runs: map({name: ., app: {id: $app}, status: "completed", conclusion: "success"})}' "$STATE") ;;
  repos/*commits*) out='[{"sha":"deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"}]' ;;
  repos/*)
    out=$(jq -c '.settings + {permissions:{admin:true}, owner:{type:"User"},
      security_and_analysis:{
        secret_scanning:{status:(if .secret_scanning.enabled then "enabled" else "disabled" end)},
        secret_scanning_push_protection:{status:(if .secret_scanning.push_protection then "enabled" else "disabled" end)}}}' "$STATE") ;;
  *) out='{}' ;;
esac
if [ -n "$jqf" ]; then printf '%s' "$out" | jq -r "$jqf"; else printf '%s\n' "$out"; fi
EOF
chmod +x "$LAB/bin/gh"

G="$LAB/repo/scripts/gh/apply-governance.sh"
PASS=0; FAIL=0
probe() { # name, override-jq, expected_rc
  local out rc
  out=$(PROT_OVERRIDE="$2" PATH="$LAB/bin:$PATH" "$G" --no-color 2>&1); rc=$?
  if [ "$rc" = "$3" ]; then printf '  PASS  %-56s rc=%s\n' "$1" "$rc"; PASS=$((PASS+1))
  else printf '  FAIL  %-56s rc=%s (expected %s)\n' "$1" "$rc" "$3"
       printf '        field declared and NOT watched: an rc=0 that measured nothing\n'; FAIL=$((FAIL+1)); fi
}

echo "== Baseline: rc=0 has to be reachable (otherwise it is dead code)"
probe "real state == desired state -> 0" "" 0

echo ""
echo "== Every declared field, deviated one at a time -> 1"
probe "allow_force_pushes=true (the channel could be rewritten)" '.allow_force_pushes.enabled = true' 1
probe "allow_deletions=true (the channel could be deleted)"       '.allow_deletions.enabled = true' 1
probe "enforce_admins=true (would leave rollback with no way out)" '.enforce_admins.enabled = true' 1
probe "required_linear_history=false"                             '.required_linear_history.enabled = false' 1
probe "required_conversation_resolution=false"                    '.required_conversation_resolution.enabled = false' 1
probe "lock_branch=true"                                          '.lock_branch.enabled = true' 1
probe "block_creations=true"                                      '.block_creations.enabled = true' 1
probe "allow_fork_syncing=true"                                   '.allow_fork_syncing.enabled = true' 1
probe "required check reportable by ANOTHER app (app_id 99999)"   '.required_status_checks.checks = [{context:"gates",app_id:99999}]' 1
probe "required check deleted from the real state"                '.required_status_checks.checks = []' 1
probe "strict changed"                                            '.required_status_checks.strict = true' 1
probe "the PR path stops being mandatory"                         'del(.required_pull_request_reviews)' 1
probe "required_approving_review_count raised to 1"               '.required_pull_request_reviews.required_approving_review_count = 1' 1
probe "require_code_owner_reviews enabled behind our back"        '.required_pull_request_reviews.require_code_owner_reviews = true' 1

echo ""
echo "  $PASS PASS / $FAIL FAIL"
[ "$FAIL" -eq 0 ] || exit 1
