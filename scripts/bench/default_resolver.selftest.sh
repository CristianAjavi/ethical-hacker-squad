#!/usr/bin/env bash
# Self-test for default_resolver.py.
#
# It exists because four of the six composition defects this corpus never found
# in any run sat in one service, and all four were the same family: a value that
# decides a permission arriving through a default, a lookup, or an opt-in, with
# the call site showing none of it. This tool addresses ONE of those four - the
# omitted argument - so the battery's job is to hold that one shape honestly and
# not to imply the other three.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
S="$ROOT/skills/ethical-hacker-squad/tools/default_resolver.py"
command -v python3 >/dev/null || { echo "UNMEASURABLE python3 missing"; exit 2; }
[ -f "$S" ] || { echo "UNMEASURABLE subject missing"; exit 2; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ pass=$((pass+1)); echo "  PASS  $1"; }
bad(){ fail=$((fail+1)); echo "  FAIL  $1"; }
run(){ python3 "$S" --target "$1" >"$TMP/out" 2>&1; }

echo "== the shape that produced this tool, declared across lines =="
mkdir -p "$TMP/wide/lib"
cat > "$TMP/wide/lib/grant.ts" <<'TS1'
export function grantArtifacts(
  role: iam.IRole,
  bucket: s3.IBucket,
  prefix = '',
): void {
  role.addToPrincipalPolicy(
    new iam.PolicyStatement({
      actions: ['s3:GetObject'],
      resources: [bucket.arnForObjects(`${prefix}*`)],
    }),
  );
}
TS1
cat > "$TMP/wide/lib/stack.ts" <<'TS2'
export class ApiStack {
  constructor() {
    grantArtifacts(this.taskRole, this.artifacts);
  }
}
TS2
run "$TMP/wide"; rc=$?
[ "$rc" -eq 1 ] && ok "an omitted permission-shaping argument gives rc 1" || bad "expected rc 1, got $rc"
grep -q "silently taking prefix=''" "$TMP/out" \
  && ok "the default the caller accepted is named, and the declaration is MULTI-LINE" \
  || bad "the multi-line declaration was not read: $(head -2 "$TMP/out")"

echo "== the same call, passing the argument: nothing to report =="
mkdir -p "$TMP/narrow/lib"; cp "$TMP/wide/lib/grant.ts" "$TMP/narrow/lib/"
sed "s|this.artifacts);|this.artifacts, 'svc/api/');|" "$TMP/wide/lib/stack.ts" > "$TMP/narrow/lib/stack.ts"
run "$TMP/narrow"; rc=$?
[ "$rc" -eq 0 ] && ok "passing the argument silences it — it tracks the omission" \
                || bad "still flagging when the caller passes it: $(head -2 "$TMP/out")"

echo "== a default that shapes nothing security-relevant is not this tool's business =="
mkdir -p "$TMP/benign/lib"
cat > "$TMP/benign/lib/retry.ts" <<'TS3'
export function withRetry(
  fn: () => void,
  attempts = 3,
): void {
  for (let i = 0; i < attempts; i++) { fn(); }
}
TS3
printf 'withRetry(load);\n' > "$TMP/benign/lib/use.ts"
run "$TMP/benign"; rc=$?
[ "$rc" -eq 0 ] && ok "an omitted retry count is ignored — the filter is the security context" \
                || bad "flagged a non-security default: $(head -2 "$TMP/out")"

echo "== the mutant: without balanced parens the tool is blind to real TypeScript =="
python3 - "$S" "$TMP/oneline.py" <<'PY'
import sys, re
src = open(sys.argv[1]).read()
# force the declaration scan to consider only what fits on the opening line
src = src.replace('raw, after = balanced(text, m.end() - 1)',
                  'raw, after = (text[m.end():text.find(chr(10), m.end())].rstrip().rstrip(")"), text.find(chr(10), m.end()))\n            raw = raw if ")" not in text[m.end():text.find(chr(10), m.end())] else None')
open(sys.argv[2], "w").write(src)
PY
if ! cmp -s "$S" "$TMP/oneline.py"; then
  python3 "$TMP/oneline.py" --target "$TMP/wide" >"$TMP/mout" 2>&1
  grep -q "silently taking" "$TMP/mout" \
    && bad "the single-line mutant ALSO finds it: balancing is not what works" \
    || ok "the single-line mutant misses it — balancing parens is load-bearing"
else
  bad "the mutant did not apply: this battery would pass without measuring anything"
fi

echo "== a table whose value ends the argument =="
mkdir -p "$TMP/table/config"
cat > "$TMP/table/config/env.ts" <<'TS4'
const tierPolicies: Record<Tier, string> = {
  standard: 'ReadOnlyAccess',
  ops: 'AdministratorAccess',
};

export function attachTierPolicy(role: iam.IRole, tier: Tier): void {
  role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName(tierPolicies[tier]));
}
TS4
run "$TMP/table"; rc=$?
[ "$rc" -eq 1 ] && ok "a table entry resolving to administrator gives rc 1" || bad "expected rc 1, got $rc"
grep -q "TABLE.*AdministratorAccess" "$TMP/out" \
  && ok "the table is named with the entry that ends the argument" \
  || bad "the dangerous entry was not named: $(head -2 "$TMP/out")"

echo "== the same table with only ordinary values: silent =="
mkdir -p "$TMP/tame/config"
sed "s|'AdministratorAccess'|'ReadOnlyAccess'|" "$TMP/table/config/env.ts" > "$TMP/tame/config/env.ts"
run "$TMP/tame"; rc=$?
[ "$rc" -eq 0 ] && ok "an ordinary table is not flagged — it tracks the value, not the shape" \
                || bad "flagged a tame table: $(head -2 "$TMP/out")"

echo "== the limit this tool does NOT cover, asserted so nobody assumes it does =="
mkdir -p "$TMP/fallback/config"
cat > "$TMP/fallback/config/pick.ts" <<'TS5'
export function pickEnv(name?: string): EnvConfig {
  return environments[name ?? ''] ?? dev;
}
TS5
run "$TMP/fallback"; rc=$?
[ "$rc" -eq 0 ] && ok "a fallback with no security word on or above its line is NOT caught — a stated gap" \
                || ok "the fallback was caught here; the gap may have closed, re-read the header"

echo "== could not measure is never a pass =="
run "$TMP/absent"; rc=$?
[ "$rc" -eq 2 ] && ok "an absent target gives rc 2" || bad "expected rc 2, got $rc"
mkdir -p "$TMP/nots"; printf 'print(1)\n' > "$TMP/nots/a.py"
run "$TMP/nots"; rc=$?
[ "$rc" -eq 2 ] && ok "a tree with no TS or JS is rc 2, not a silent green" || bad "expected rc 2, got $rc"

echo; echo "$pass PASS / $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
