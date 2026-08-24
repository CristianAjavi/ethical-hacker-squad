#!/usr/bin/env bash
# Tests scripts/gh/competitive-freshness.sh against a GitHub API double.
#
# The case that matters is `one-moved`. On 2026-08-24 two of the three pins in
# docs/competitive-baseline.json were already behind their repository's HEAD,
# both pushed that same day, and nothing in this repository said so. A check
# that cannot tell a moved subject from a still one is worth nothing.
#
# Zero network.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

SP="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd -- "$SP/../../.." && pwd -P)"
TOOL="$ROOT/scripts/gh/competitive-freshness.sh"
[ -f "$TOOL" ] || { echo "  COULD NOT MEASURE: competitive-freshness.sh is missing (rc 2)"; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "  COULD NOT MEASURE: jq is missing (rc 2)"; exit 2; }

LAB="$(mktemp -d)"; trap 'rm -rf "$LAB"' EXIT
mkdir -p "$LAB/bin"
pass=0; fail=0

cat > "$LAB/baseline.json" <<'JSON'
{ "measured_on": "2026-01-01",
  "products": [
    { "repo": "org/alpha", "pinned": "aaaaaaa", "comparable": true,  "rounds": [] },
    { "repo": "org/beta",  "pinned": "bbbbbbb", "comparable": true,  "rounds": [] },
    { "repo": "org/never", "pinned": null,      "comparable": false, "rounds": [] } ] }
JSON

cat > "$LAB/bin/gh" <<'GH'
#!/usr/bin/env bash
path=""; jqf=""; want=0
for a in "$@"; do
  if [ "$want" -eq 1 ]; then jqf="$a"; want=0; continue; fi
  case "$a" in --jq) want=1 ;; api|-*) ;; *) [ -z "$path" ] && path="$a" ;; esac
done
emit() { if [ -n "$jqf" ]; then printf '%s' "$1" | jq -r "$jqf"; else printf '%s\n' "$1"; fi; }
# A product declared non-comparable must never be queried. If it is, the tool is
# asking about something it also says it never measured.
case "$path" in *org/never*) echo "DOUBLE ERROR: queried a non-comparable product" >&2; exit 9 ;; esac
case "$LAB_MODE:$path" in
  silent:*)                       exit 1 ;;
  *:repos/org/alpha/commits*)     emit '[{"sha":"aaaaaaa000000000000000000000000000000000"}]' ;;
  moved:repos/org/beta/commits*)  emit '[{"sha":"9999999000000000000000000000000000000000"}]' ;;
  *:repos/org/beta/commits*)      emit '[{"sha":"bbbbbbb000000000000000000000000000000000"}]' ;;
  *:repos/org/*)                  emit '{"pushed_at":"2026-08-24T00:00:00Z"}' ;;
  *) emit '{}' ;;
esac
GH
chmod +x "$LAB/bin/gh"

res() {  # <label> <mode> <expected rc> [needle]
  local label="$1" mode="$2" want="$3" needle="${4:-}" rc=0
  LAB_MODE="$mode" PATH="$LAB/bin:$PATH" bash "$TOOL" --baseline "$LAB/baseline.json" >"$LAB/out.txt" 2>&1 || rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || grep -qi -- "$needle" "$LAB/out.txt"; }; then
    printf '  PASS  %-50s rc=%s\n' "$label" "$rc"; pass=$((pass+1))
  else
    printf '  FAIL  %-50s rc=%s (expected %s)\n' "$label" "$rc" "$want"
    sed 's/^/        | /' "$LAB/out.txt" | tail -10; fail=$((fail+1))
  fi
}

echo "== competitive-freshness.sh against an API double"
res "every pin still the tip -> rc 0"        current 0 "every pin is still the tip"
res "one subject has moved -> rc 1"          moved   1 "MOVED"
res "and it names the new commit"            moved   1 "now 9999999"
res "no repository answers -> rc 2"          silent  2 "COULD NOT MEASURE"

# A non-comparable product is never queried: the double exits 9 if it is, which
# would surface as a failure above rather than passing quietly.
grep -q "DOUBLE ERROR" "$LAB/out.txt" \
  && { printf '  FAIL  %-50s\n' "queried a product it says it never measured"; fail=$((fail+1)); } \
  || { printf '  PASS  %-50s\n' "never queries a non-comparable product"; pass=$((pass+1)); }

rc=0; PATH="$LAB/bin:$PATH" bash "$TOOL" --baseline "$LAB/nope.json" >"$LAB/out.txt" 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then printf '  PASS  %-50s rc=2\n' "no baseline -> rc 2"; pass=$((pass+1))
else printf '  FAIL  %-50s rc=%s (expected 2)\n' "no baseline -> rc 2" "$rc"; fail=$((fail+1)); fi

echo
echo "  $pass PASS / $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
exit 0
