#!/usr/bin/env bash
# Tests scripts/gh/protection-check.sh against a GitHub API double.
#
# The case that matters most is `no-protection-at-all`. That was the real state
# of `main` in this repository while every gate was green and the machinery
# manual said, in prose nothing executed, that the gates were advisory until
# someone ran apply-governance.sh by hand. A check that cannot tell that apart
# from a healthy branch would be worth nothing.
#
# Zero network: `gh` is replaced by a script that answers from fixtures.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

SP="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd -- "$SP/../../.." && pwd -P)"
TOOL="$ROOT/scripts/gh/protection-check.sh"
[ -f "$TOOL" ] || { echo "  COULD NOT MEASURE: protection-check.sh is missing (rc 2)"; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "  COULD NOT MEASURE: jq is missing (rc 2)"; exit 2; }

LAB="$(mktemp -d)"; trap 'rm -rf "$LAB"' EXIT
mkdir -p "$LAB/bin"
pass=0; fail=0

cat > "$LAB/state.json" <<'JSON'
{ "repo": "owner/repo",
  "actions_app_id": 15368,
  "branches": {
    "main": { "protection": {
      "required_status_checks": { "strict": false, "checks": [ { "context": "gates" } ] },
      "required_pull_request_reviews": { "required_approving_review_count": 0 },
      "required_linear_history": true,
      "allow_force_pushes": false,
      "allow_deletions": false,
      "required_conversation_resolution": true } } } }
JSON

# The double. LAB_MODE picks which repository it is pretending to be.
cat > "$LAB/bin/gh" <<'GH'
#!/usr/bin/env bash
path=""
for a in "$@"; do case "$a" in api|--jq|-*) ;; *) [ -z "$path" ] && path="$a" ;; esac; done
# `absent` first: a generic pattern placed above it would answer "the branch
# exists" before the absent case is ever reached, and the suite would score the
# does-not-exist case as a drift. It did, on the first run.
case "$LAB_MODE:$path" in
  absent:*) exit 1 ;;
  *:repos/*/branches/main) echo '{"name":"main"}' ;;
  noprot:repos/*/branches/main/protection) exit 1 ;;
  match:repos/*/branches/main/protection)
    echo '{"required_status_checks":{"strict":false,"checks":[{"context":"gates","app_id":15368}]},"required_pull_request_reviews":{},"required_linear_history":{"enabled":true},"allow_force_pushes":{"enabled":false},"allow_deletions":{"enabled":false},"required_conversation_resolution":{"enabled":true}}' ;;
  drift:repos/*/branches/main/protection)
    echo '{"required_status_checks":{"strict":false,"checks":[{"context":"gates","app_id":15368}]},"required_pull_request_reviews":{},"required_linear_history":{"enabled":true},"allow_force_pushes":{"enabled":true},"allow_deletions":{"enabled":false},"required_conversation_resolution":{"enabled":true}}' ;;
  unpinned:repos/*/branches/main/protection)
    echo '{"required_status_checks":{"strict":false,"checks":[{"context":"gates","app_id":99999}]},"required_pull_request_reviews":{},"required_linear_history":{"enabled":true},"allow_force_pushes":{"enabled":false},"allow_deletions":{"enabled":false},"required_conversation_resolution":{"enabled":true}}' ;;
  *) echo '{}' ;;
esac
GH
chmod +x "$LAB/bin/gh"

res() {  # <label> <mode> <expected rc> [needle]
  local label="$1" mode="$2" want="$3" needle="${4:-}" rc=0
  LAB_MODE="$mode" PATH="$LAB/bin:$PATH" bash "$TOOL" --state "$LAB/state.json" >"$LAB/out.txt" 2>&1 || rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || grep -qi -- "$needle" "$LAB/out.txt"; }; then
    printf '  PASS  %-48s rc=%s\n' "$label" "$rc"; pass=$((pass+1))
  else
    printf '  FAIL  %-48s rc=%s (expected %s)\n' "$label" "$rc" "$want"
    sed 's/^/        | /' "$LAB/out.txt" | tail -8; fail=$((fail+1))
  fi
}

echo "== protection-check.sh against an API double"
res "live matches declared -> rc 0"                match    0 "matches the declared"
res "a field drifted -> rc 1"                      drift    1 "force: live=true declared=false"
res "NO protection at all -> rc 1"                 noprot   1 "required by nothing"
res "the branch does not exist -> rc 2"            absent   2 "does not exist yet"
res "a check not pinned to the app -> rc 1"        unpinned 1 "contexts"

# gh absent is not a pass: without it nothing was read. The PATH keeps jq and
# the core utilities - emptying it entirely only proves that a script with no
# interpreter does not run, which is not the question.
mkdir -p "$LAB/nogh"
for t in jq sed awk grep; do
  p="$(command -v "$t" 2>/dev/null)" && ln -sf "$p" "$LAB/nogh/$t"
done
rc=0; PATH="$LAB/nogh:/usr/bin:/bin" bash "$TOOL" --state "$LAB/state.json" >"$LAB/out.txt" 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then printf '  PASS  %-48s rc=2\n' "gh missing -> rc 2"; pass=$((pass+1))
else printf '  FAIL  %-48s rc=%s (expected 2)\n' "gh missing -> rc 2" "$rc"; fail=$((fail+1)); fi

echo
echo "  $pass PASS / $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
exit 0
