#!/usr/bin/env bash
# Battery for bench/tools/nextjs_matcher_gap.py.
#
# The check exists because of one measured miss - S-26, missed by both arms in
# eight runs of 2026-08-27-artifact-contract. A check that only fires on the case
# it was built from proves nothing, so the cases below are mostly about what it
# must NOT do: it must clear the matcher every Next.js app ships, it must clear a
# bypassed handler that authenticates for itself, and it must say COULD NOT
# MEASURE rather than 0 whenever it cannot read what reaches the middleware.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
TOOL="$ROOT/bench/tools/nextjs_matcher_gap.py"
CASES="$ROOT/bench/cases"
command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
[ -f "$TOOL" ] || { echo "UNMEASURABLE the tool is missing at $TOOL"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-nmg-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

run_case() {
  local name="$1" target="$2" want="$3" needle="$4"
  local out rc
  out="$(python3 "$TOOL" --target "$target" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf 'ok       %-44s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-44s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -5; fail=$((fail+1))
  fi
}

echo "=== battery: nextjs_matcher_gap.py ==="

# The defect it was built for.
run_case "S-26 shape: matcher excludes api"          "$CASES/notes-matcher"       1 "UNGUARDED  app/api/share"
# The control that decides whether it is usable at all.
run_case "standard matcher: static only, must clear" "$CASES/notes-matcher-fixed" 0 "reached    app/api/share"
# A bypassed handler that checks for itself is not the defect.
run_case "bypassed but self-checking is credited"    "$CASES/notes-matcher"       1 "self-check app/api/notes"

# --- what it must refuse to answer ---------------------------------------------
mk() { mkdir -p "$TMP/$1/app/api/x"; cp "$CASES/notes-matcher/app/api/share/route.ts" "$TMP/$1/app/api/x/route.ts"; }

mk no-middleware
run_case "no middleware at all -> COULD NOT MEASURE"  "$TMP/no-middleware"        2 "no middleware file"

mk no-config
printf 'export function middleware(){}\n' > "$TMP/no-config/middleware.ts"
run_case "middleware without config -> COULD NOT MEASURE" "$TMP/no-config"        2 "exports no"

mk no-matcher
printf 'export function middleware(){}\nexport const config = { runtime: "edge" };\n' > "$TMP/no-matcher/middleware.ts"
run_case "config without matcher -> COULD NOT MEASURE" "$TMP/no-matcher"          2 "no \`matcher\`"

mk unreadable
printf 'export function middleware(){}\nexport const config = { matcher: ["/[a-z]{2}/:path*"] };\n' > "$TMP/unreadable/middleware.ts"
run_case "grammar it cannot read -> not a pass"       "$TMP/unreadable"           2 "UNPARSED"

mk empty-matcher
printf 'export function middleware(){}\nexport const config = { matcher: [] };\n' > "$TMP/empty-matcher/middleware.ts"
run_case "empty matcher -> COULD NOT MEASURE"         "$TMP/empty-matcher"        2 "matcher is empty"

# --- the mutant: without the lookahead reading, the defect must be MISSED -------
# A battery that passes with and without the mechanism is hollow. If removing the
# negative-lookahead handling still produces the red, something else produced it.
mutant="$TMP/mutant.py"
python3 - "$TOOL" "$mutant" <<'PY'
import sys, pathlib
src, dst = sys.argv[1], sys.argv[2]
t = pathlib.Path(src).read_text()
a = 'for group in LOOKAHEAD.findall(pattern):'
assert a in t, "the mechanism moved; this mutant no longer removes it"
pathlib.Path(dst).write_text(t.replace(a, 'for group in []:', 1))
PY
out="$(python3 "$mutant" --target "$CASES/notes-matcher" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  printf 'ok       %-44s rc=0 (blind to the defect, as it must be)\n' "mutant without lookahead handling"; pass=$((pass+1))
else
  printf 'FAILED   %-44s rc=%s (wanted 0)\n' "mutant without lookahead handling" "$rc"
  printf '%s\n' "$out" | sed 's/^/         /' | tail -4; fail=$((fail+1))
fi

echo
echo "Summary: $pass ok, $fail failures"
[ "$fail" -gt 0 ] && { echo "Result: FAILED."; exit 1; }
echo "Result: OK. It catches S-26, clears the idiom everybody ships, and refuses to answer what it cannot read."
exit 0
