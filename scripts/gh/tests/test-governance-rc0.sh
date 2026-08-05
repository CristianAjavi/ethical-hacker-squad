#!/usr/bin/env bash
# Tests that the rc=0 of apply-governance.sh is REACHABLE and means something:
# with a simulated API that returns exactly the desired state -> rc 0; touching
# a single field -> rc 1. Without this, an rc=0 could be a dead rc=0.
set -uo pipefail
SP="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WT="$(cd -- "$SP/../../.." && pwd)"
LAB="$(mktemp -d)"; trap 'rm -rf "$LAB"' EXIT
mkdir -p "$LAB/bin"
cp -R "$WT" "$LAB/repo"
rm -rf "$LAB/repo/.git"
mkdir -p "$LAB/repo/scripts/gates"
printf '#!/usr/bin/env bash\nexit 0\n' >"$LAB/repo/scripts/gates/dummy.sh"
STATE="$LAB/repo/scripts/gh/governance.json"

# --- GitHub API double ------------------------------------------------------
cat >"$LAB/bin/gh" <<EOF
#!/usr/bin/env bash
STATE="$STATE"
TAXONOMY="$LAB/repo/scripts/gh/labels.sh"
OVERRIDE="\${GOV_OVERRIDE:-}"
EOF
cat >>"$LAB/bin/gh" <<'EOF'
# Builds the GET response matching the DESIRED state, so the comparator sees
# "everything matches". GOV_OVERRIDE allows breaking one field.
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

# Protection GET with the shape GitHub returns (nested enabled)
protection() {
  jq -c --argjson app "$APP" --arg b "$1" '
    .branches[$b].protection as $p
    | {
        allow_force_pushes:               {enabled: ($p.allow_force_pushes // false)},
        allow_deletions:                  {enabled: ($p.allow_deletions // false)},
        required_linear_history:          {enabled: ($p.required_linear_history // false)},
        required_conversation_resolution: {enabled: ($p.required_conversation_resolution // false)},
        lock_branch:                      {enabled: ($p.lock_branch // false)},
        enforce_admins:                   {enabled: ($p.enforce_admins // false)}
      }
      + (if $p.required_status_checks != null then
           {required_status_checks: {strict: $p.required_status_checks.strict,
             checks: [$p.required_status_checks.checks[] | {context: .context, app_id: $app}]}}
         else {} end)
      + (if $p.required_pull_request_reviews != null then
           {required_pull_request_reviews: $p.required_pull_request_reviews}
         else {} end)
  ' "$STATE"
}

case "$path" in
  user) out='{"login":"'"$(jq -r .expected_account "$STATE")"'"}' ;;
  repos/*/branches/*/protection)
    b=$(echo "$path" | awk -F/ '{print $5}'); out=$(protection "$b") ;;
  repos/*/branches/*) b=$(echo "$path" | awk -F/ '{print $5}'); out='{"name":"'"$b"'"}' ;;
  repos/*/topics) out=$(jq -c '{names: .topics}' "$STATE") ;;
  # governance.json no longer declares labels: the taxonomy lives in labels.sh and
  # apply-governance.sh delegates the check to it. The double answers with exactly
  # that taxonomy so the baseline can legitimately reach rc 0.
  repos/*/labels*)
    out=$(grep -E '^[a-z]+/[a-z0-9-]+\|[0-9a-f]{6}\|' "$TAXONOMY" \
          | jq -R -s -c 'split("\n") | map(select(length > 0) | split("|")
                         | {name: .[0], color: .[1], description: .[2]})') ;;
  repos/*/vulnerability-alerts) exit 0 ;;
  repos/*/commits/*/check-runs)
    out='[{"name":"gates","app":{"id":'"$APP"'},"status":"completed","conclusion":"success"}]'
    out='{"check_runs":'"$out"'}' ;;
  repos/*/commits*) out='[{"sha":"deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"}]' ;;
  repos/*)
    out=$(jq -c '.settings + {permissions:{admin:true}, owner:{type:"User"},
      security_and_analysis:{
        secret_scanning:{status: (if .secret_scanning.enabled then "enabled" else "disabled" end)},
        secret_scanning_push_protection:{status: (if .secret_scanning.push_protection then "enabled" else "disabled" end)}}}' "$STATE")
    if [ -n "$OVERRIDE" ]; then out=$(jq -c "$OVERRIDE" <<<"$out"); fi ;;
  *) out='{}' ;;
esac
if [ -n "$jqf" ]; then printf '%s' "$out" | jq -r "$jqf"; else printf '%s\n' "$out"; fi
EOF
chmod +x "$LAB/bin/gh"

PASS=0; FAIL=0
res() { if [ "$2" = "$3" ]; then printf '  PASS  %-50s rc=%s\n' "$1" "$2"; PASS=$((PASS+1));
        else printf '  FAIL  %-50s rc=%s (expected %s)\n' "$1" "$2" "$3"; FAIL=$((FAIL+1));
             printf '%s\n' "${4:-}" | sed 's/^/        | /' | tail -25; fi; }

echo "== apply-governance.sh against a simulated API"
OUT=$(PATH="$LAB/bin:$PATH" "$LAB/repo/scripts/gh/apply-governance.sh" --no-color 2>&1); RC=$?
res "real state == desired state -> rc 0" "$RC" 0 "$OUT"

OUT=$(GOV_OVERRIDE='.allow_auto_merge = false' PATH="$LAB/bin:$PATH" \
      "$LAB/repo/scripts/gh/apply-governance.sh" --no-color 2>&1); RC=$?
res "a single deviated setting -> rc 1 (drift)" "$RC" 1 "$OUT"
case "$OUT" in *"allow_auto_merge: actual=false desired=true"*) echo "        (it names the exact field that drifted)";;
  *) echo "        FAIL: it does not name the drifted field"; FAIL=$((FAIL+1));; esac
case "$OUT" in *"APPLIED"*) echo "        FAIL: it mutated in dry-run"; FAIL=$((FAIL+1));; *) echo "        (dry-run mutated nothing)";; esac

echo ""
echo "  $PASS PASS / $FAIL FAIL"
[ "$FAIL" -eq 0 ] || exit 1
