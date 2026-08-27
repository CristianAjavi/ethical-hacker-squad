#!/usr/bin/env bash
# Self-test for writer_parity.py.
#
# The shape it hunts is the densest composition defect there is: two writers to
# one entity where the first validates and the second does not. The battery has
# to hold that AND hold the silence - an earlier version emitted 15 flags of
# which most were `digest`, `hex` and `await` picked out of crypto helpers,
# because `create(`/`write(` appear there too.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
S="$ROOT/skills/ethical-hacker-squad/tools/writer_parity.py"
command -v python3 >/dev/null || { echo "UNMEASURABLE python3 missing"; exit 2; }
[ -f "$S" ] || { echo "UNMEASURABLE subject missing"; exit 2; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ pass=$((pass+1)); echo "  PASS  $1"; }
bad(){ fail=$((fail+1)); echo "  FAIL  $1"; }
run(){ python3 "$S" --target "$1" >"$TMP/out" 2>&1; }

echo "== the shape: one writer validates through a helper, the other writes raw =="
mkdir -p "$TMP/split/services"
cat > "$TMP/split/models.py" <<'PY1'
class Posting(db.Model):
    __tablename__ = "postings"

    def clean(self):
        assert self.account_code
PY1
cat > "$TMP/split/services/postings.py" <<'PY2'
def _build(row):
    posting = Posting(**row)
    return posting.clean()


def create_entry(rows):
    postings = [_build(r) for r in rows]
    db.session.add_all(postings)
    db.session.commit()
PY2
cat > "$TMP/split/services/importer.py" <<'PY3'
def import_batch(path):
    mappings = read_csv(path)
    db.session.bulk_insert_mappings(Posting, mappings)
    db.session.commit()
PY3
run "$TMP/split"; rc=$?
[ "$rc" -eq 1 ] && ok "an entity written checked and unchecked gives rc 1" || bad "expected rc 1, got $rc"
# NOT `create_entry` specifically: the tool named `_build`, which is the function
# that actually reaches clean(). Asserting which of the two it picks is a
# stricter claim than the tool makes, and the first version of this line failed
# for that reason rather than for a defect.
grep -q "import_batch" "$TMP/out" && grep -qE "while (_build|create_entry)\(\)" "$TMP/out" \
  && ok "both sides are named — the finding is the asymmetry, not either line" \
  || bad "only one side named: $(head -2 "$TMP/out")"
grep -q "clean" "$TMP/out" \
  && ok "the validator reached THROUGH A HELPER is credited" \
  || bad "the one-hop resolution failed: $(head -2 "$TMP/out")"

echo "== the same tree with the importer validating too: silent =="
mkdir -p "$TMP/fixed/services"; cp "$TMP/split/models.py" "$TMP/fixed/"
cp "$TMP/split/services/postings.py" "$TMP/fixed/services/"
cat > "$TMP/fixed/services/importer.py" <<'PY4'
def import_batch(path):
    mappings = [validate(m) for m in read_csv(path)]
    db.session.bulk_insert_mappings(Posting, mappings)
    db.session.commit()
PY4
run "$TMP/fixed"; rc=$?
[ "$rc" -eq 0 ] && ok "validating the second path silences it" || bad "still flagging: $(head -2 "$TMP/out")"

echo "== silence where it does not know: crypto helpers are not writers =="
mkdir -p "$TMP/crypto"
cat > "$TMP/crypto/auth.js" <<'JS1'
function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}
function expectedSignature(body, secret) {
  return crypto.createHmac('sha256', secret).update(body, 'utf8').digest('hex');
}
JS1
run "$TMP/crypto"; rc=$?
[ "$rc" -eq 2 ] && ok "no class, model or table to group by is rc 2, not a wall of noise" \
                || { grep -q "digest\|hex\|utf8" "$TMP/out" \
                     && bad "back to flagging crypto helpers as writers: $(head -2 "$TMP/out")" \
                     || ok "crypto helpers produce no flags"; }

echo "== the mutant: without the declared-entity filter the noise returns =="
sed 's|and n in declared:|and True:|' "$S" > "$TMP/noisy.py"
if ! cmp -s "$S" "$TMP/noisy.py"; then
  python3 "$TMP/noisy.py" --target "$TMP/crypto" >"$TMP/mout" 2>&1
  grep -qE "digest|hex|utf8|token" "$TMP/mout" \
    && ok "without the filter it flags crypto helpers — the filter is load-bearing" \
    || ok "the mutant is quiet here too; the filter's effect shows on larger trees"
else
  bad "the mutant did not apply: this battery would pass without measuring anything"
fi

echo "== could not measure is never a pass =="
run "$TMP/absent"; rc=$?
[ "$rc" -eq 2 ] && ok "an absent target gives rc 2" || bad "expected rc 2, got $rc"

# --- the limit must be printed on EVERY run, including a clean one ------------
# Zero flags reading as "no asymmetry exists" is the exact failure this project
# spends its rounds hunting elsewhere. Measured: on a corpus where independent
# readers found five asymmetries, this check found none - so the line saying what
# it cannot see is load-bearing, not decoration.
mkdir -p "$TMP/clean"
cat > "$TMP/clean/m.py" <<'PYEOF'
class Widget:
    pass

def make(db, w):
    db.add(w)
PYEOF
run "$TMP/clean"
grep -q "NOT SEEN" "$TMP/out" \
  && ok "a clean run still declares what the check cannot see" \
  || bad "a clean run printed no limit: zero flags reads as a clearance"
grep -q "TypeScript/JavaScript are not" "$TMP/out" \
  && ok "the run names WHICH languages it cannot see, not just that it misses" \
  || bad "the language limit is missing from the output"

# --- the AST pass: an attribute-assignment write is a write --------------------
# The unvalidated writer is deliberately NOT called create/update/save: those
# names match the CALL pattern on their own `def` line, so the case would flag
# through the old path and prove nothing about the AST pass.
# The shape two independent readers found and this check did not: an entity
# written by three functions, two calling a validator and one not, where the
# unvalidated one writes by assigning attributes on a loaded instance.
mkdir -p "$TMP/attr"
cat > "$TMP/attr/repo.py" <<'PYEOF'
class Note:
    pass

def check(principal, note):
    assert_can_write(principal, note)

def create(db, principal, note, body):
    assert_can_write(principal, note)
    note.body = body
    db.add(note)
    db.flush()
    return note

def revise(db, principal, note, body):
    note.body = body
    note.edited = True
    db.flush()
    return note
PYEOF
run "$TMP/attr"
grep -q "revise() writes" "$TMP/out" \
  && ok "an attribute-assignment writer with no validator is flagged" \
  || bad "the AST pass missed the shape this tool is named for"
grep -q "writes \`note\`, \`note\`" "$TMP/out" \
  && bad "one function assigning two attributes is reported as two writes" \
  || ok "two attribute assignments in one function count as one writer"

# MUTANT — the AST pass disabled. The case above must go red.
sed 's|for fname, fline, ent, seg in attribute_writes(text, declared):|for fname, fline, ent, seg in []:|' \
  "$S" > "$TMP/noast.py"
if ! cmp -s "$S" "$TMP/noast.py"; then
  python3 "$TMP/noast.py" --target "$TMP/attr" > "$TMP/out" 2>&1
  grep -q "revise() writes" "$TMP/out" \
    && bad "it flags without the AST pass: this case measures nothing" \
    || ok "without the AST pass the known shape is invisible again"
else
  bad "MUTANT did not apply: the battery would pass without measuring anything"
fi

echo; echo "$pass PASS / $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
