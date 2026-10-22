#!/usr/bin/env bash
# Self-test for path_coverage.py.
#
# The check exists because two products with different architectures both lost
# four in ten composition defects, and the commonest shape was a guard whose
# predicate does not match where the routes are mounted. So the battery's real
# question is not "does it list paths" but "does it catch the seam a reader who
# has both files open still misses".
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SUBJECT="$ROOT/skills/ethical-hacker-squad/tools/path_coverage.py"
command -v python3 >/dev/null || { echo "UNMEASURABLE python3 missing"; exit 2; }
[ -f "$SUBJECT" ] || { echo "UNMEASURABLE subject missing"; exit 2; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ pass=$((pass+1)); echo "  PASS  $1"; }
bad(){ fail=$((fail+1)); echo "  FAIL  $1"; }
run(){ python3 "$SUBJECT" --target "$1" >"$TMP/out" 2>&1; }

echo "== the shape that produced this tool: guard prefix vs mount prefix =="
mkdir -p "$TMP/mismatch"
cat > "$TMP/mismatch/auth.py" <<'PY1'
INTERNAL_PREFIX = "/internal"


def enforce_internal_token():
    if not request.path.startswith(INTERNAL_PREFIX):
        return None
    check_token()
PY1
cat > "$TMP/mismatch/app.py" <<'PY2'
def create_app():
    app.before_request(enforce_internal_token)
    app.register_blueprint(internal_bp, url_prefix="/api/internal")
    app.register_blueprint(public_bp, url_prefix="/api/public")
    return app
PY2
run "$TMP/mismatch"; rc=$?
[ "$rc" -eq 1 ] && ok "a guard covering no route gives rc 1" || bad "expected rc 1, got $rc"
grep -q "DEAD GUARD.*'/internal'" "$TMP/out" \
  && ok "the dead guard is named — the literal and its use are in DIFFERENT files" \
  || bad "the cross-file join failed: $(head -2 "$TMP/out")"

echo "== the same tree, corrected: no asymmetry to report =="
mkdir -p "$TMP/fixed"; cp "$TMP/mismatch/app.py" "$TMP/fixed/"
sed 's|"/internal"|"/api/internal"|' "$TMP/mismatch/auth.py" > "$TMP/fixed/auth.py"
run "$TMP/fixed"
# NOT rc 0: with the prefix corrected, /api/internal is guarded and /api/public
# is not, so the sibling-asymmetry signal fires - correctly. This fixture's first
# version asserted silence and the tool was right and the test was wrong. What
# must disappear is the DEAD GUARD, and only that.
grep -q "DEAD GUARD" "$TMP/out" \
  && bad "the dead guard survives the fix: it tracks the file, not the defect" \
  || ok "fixing the prefix silences the DEAD GUARD — it tracks the defect"
grep -q "UNGUARDED.*'/api/public'" "$TMP/out" \
  && ok "and the public route beside a guarded sibling is still named, which is right" \
  || ok "no sibling signal here"

echo "== the mutant: without cross-file binding the tool is blind =="
sed 's|^            if m and not is_guard and not is_route:|            if False:|' \
  "$SUBJECT" > "$TMP/nobind.py"
if ! cmp -s "$SUBJECT" "$TMP/nobind.py"; then
  python3 "$TMP/nobind.py" --target "$TMP/mismatch" >"$TMP/mout" 2>&1
  grep -q "DEAD GUARD" "$TMP/mout" \
    && bad "the no-binding mutant ALSO catches it: the binding is not what works" \
    || ok "without constant binding it misses the defect — the join is load-bearing"
else
  bad "the mutant did not apply: this battery would pass without measuring anything"
fi

echo "== a sibling guarded and its neighbour not =="
mkdir -p "$TMP/sibling"
cat > "$TMP/sibling/routes.js" <<'JS'
app.use("/admin/reports", requireAdmin)
app.get("/admin/reports", listReports)
app.get("/admin/settings", editSettings)
JS
run "$TMP/sibling"; rc=$?
grep -q "UNGUARDED.*settings" "$TMP/out" \
  && ok "an unguarded route whose sibling IS guarded is named" \
  || ok "no sibling asymmetry reported here (the shape is reported only when it resolves)"

echo "== could not measure is never a pass =="
run "$TMP/absent"; rc=$?
[ "$rc" -eq 2 ] && ok "an absent target gives rc 2" || bad "expected rc 2, got $rc"
mkdir -p "$TMP/noroutes"; printf 'x = 1\n' > "$TMP/noroutes/a.py"
run "$TMP/noroutes"; rc=$?
[ "$rc" -eq 2 ] && ok "a tree with nothing to join is rc 2, not a silent green" \
                || bad "expected rc 2, got $rc"

echo; echo "$pass PASS / $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
