#!/usr/bin/env bash
# Self-test for log_escaper.py.
#
# The check exists because six independent auditors read the same file and
# called the defective line the safe one. So passing this battery is not about
# finding log calls: it is about behaving DIFFERENTLY from an idiom recogniser.
# Two of the cases below are mutants of the check itself, and they are the
# point. A battery that both the real check and a `%s`-trusting stub pass would
# prove nothing at all.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SUBJECT="$ROOT/skills/ethical-hacker-squad/tools/log_escaper.py"
CASE="$ROOT/bench/cases/intake-portal/app/audit.py"

command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
[ -f "$SUBJECT" ] || { echo "UNMEASURABLE the subject is missing: $SUBJECT"; exit 2; }
[ -f "$CASE" ]    || { echo "UNMEASURABLE the three-way case is missing: $CASE"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-escaper-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
pass=0; fail=0

ok()   { pass=$((pass+1)); echo "  PASS  $1"; }
bad()  { fail=$((fail+1)); echo "  FAIL  $1"; }

# run <script> <target> -> writes $TMP/out, returns the exit code
run() { python3 "$1" --target "$2" >"$TMP/out" 2>&1; }

echo "== the case that caused the miss: all three lines, sorted correctly =="

run "$SUBJECT" "$CASE"; rc=$?
[ "$rc" -eq 1 ] && ok "an uncleared argument gives rc 1" \
                || bad "expected rc 1 on the planted case, got $rc"

# P-52: the deferred `%s` line every auditor called the example of doing it right.
grep -q 'UNCLEARED.*record_submission' "$TMP/out" \
  && ok "P-52 flagged — the line six readers called safe" \
  || bad "P-52 NOT flagged: the check reproduces the human miss"

# P-51: the concatenated neighbour. Every arm found this one; so must we.
grep -q 'UNCLEARED.*record_rejection' "$TMP/out" \
  && ok "P-51 flagged — the concatenated neighbour" \
  || bad "P-51 NOT flagged"

# The benign twin. Flagging everything is not detection, it is noise.
grep -q 'cleared   .*record_export' "$TMP/out" \
  && ok "the json.dumps twin is cleared, not flagged" \
  || bad "the benign control was flagged: the check cannot separate"

# The report has to name what it credited, or a reviewer cannot argue with it.
grep -q 'record_export.*dumps' "$TMP/out" \
  && ok "the credited escaper is named in the report" \
  || bad "a cleared line does not say what cleared it"

echo "== proved in the negative: nothing to flag must not invent something =="

mkdir -p "$TMP/clean"
cat > "$TMP/clean/safe.py" <<'CLEAN_EOF'
import json
import logging

logger = logging.getLogger(__name__)


def record(event):
    logger.info("event %s", json.dumps(event))


def announce():
    logger.warning("service started")
CLEAN_EOF

run "$SUBJECT" "$TMP/clean"; rc=$?
[ "$rc" -eq 0 ] && ok "a fully cleared tree gives rc 0" \
                || bad "expected rc 0 on the clean fixture, got $rc"
grep -q 'UNCLEARED' "$TMP/out" \
  && bad "the clean fixture produced a flag" \
  || ok "no flag invented on the clean fixture"

echo "== could not measure is never a pass =="

run "$SUBJECT" "$TMP/does-not-exist"; rc=$?
[ "$rc" -eq 2 ] && ok "an absent target gives rc 2, not rc 0" \
                || bad "expected rc 2 for an absent target, got $rc"

mkdir -p "$TMP/empty" && : > "$TMP/empty/README.md"
run "$SUBJECT" "$TMP/empty"; rc=$?
[ "$rc" -eq 2 ] && ok "a tree with no Python gives rc 2" \
                || bad "expected rc 2 for a tree with no Python, got $rc"

mkdir -p "$TMP/broken" && printf 'def (\n' > "$TMP/broken/bad.py"
run "$SUBJECT" "$TMP/broken"; rc=$?
[ "$rc" -eq 2 ] && ok "a tree where nothing parses gives rc 2, not a silent green" \
                || bad "expected rc 2 when nothing parsed, got $rc"

echo "== a call is not an escaper just because its arguments are literals =="

# This is the shape of CVE-2024-27097. CKAN's reset endpoint binds `id` from
# request.form.get("user") - a call whose only argument is a literal - and
# formats it into a log line. An earlier version of this check credited such a
# call and reported BOTH keyed sites as cleared: a false negative on a published
# advisory, in the one class this file exists for.
mkdir -p "$TMP/ckanshape"
cat > "$TMP/ckanshape/reset.py" <<'CKAN_EOF'
import logging

log = logging.getLogger(__name__)


def post(request):
    id = request.form.get("user")
    log.info('Password reset requested for user "{}"'.format(id))
CKAN_EOF

run "$SUBJECT" "$TMP/ckanshape"; rc=$?
[ "$rc" -eq 1 ] && ok "a value bound from a non-escaper call is uncleared"                 || bad "expected rc 1 on the CVE-2024-27097 shape, got $rc"
grep -q 'UNCLEARED.*reset.py' "$TMP/out"   && ok "the published-advisory shape is flagged"   || bad "the advisory shape reads as safe: the false negative is back"

echo "== mutants: the battery must fail without the thing that makes it useful =="

# MUTANT 1 — the idiom recogniser. This is the check the six auditors WERE,
# and the whole reason #53 was opened: it trusts a log call that defers its
# formatting, exactly as pylint W1203 teaches. If the real check and this stub
# agree on the case, the real check bought nothing.
sed 's|^        for i, arg in enumerate(node.args):|        if len(node.args) > 1:\n            continue\n        for i, arg in enumerate(node.args):|' \
  "$SUBJECT" > "$TMP/idiom.py"
if ! cmp -s "$SUBJECT" "$TMP/idiom.py"; then
  run "$TMP/idiom.py" "$CASE"
  grep -q 'UNCLEARED.*record_submission' "$TMP/out" \
    && bad "the idiom recogniser ALSO flags P-52: this battery cannot tell them apart" \
    || ok "the idiom recogniser misses P-52 — the real check is doing the work"
else
  bad "MUTANT 1 did not apply: the battery would pass without measuring anything"
fi

# MUTANT 2 — clearing is load-bearing. Take `dumps` out of the credited set and
# the benign twin must turn red. If it stays green, the clear verdict is being
# reached by some other route and the report's credit line is a decoration.
sed 's|^    "dumps", |    |' "$SUBJECT" > "$TMP/nodumps.py"
if ! cmp -s "$SUBJECT" "$TMP/nodumps.py"; then
  run "$TMP/nodumps.py" "$CASE"
  grep -q 'UNCLEARED.*record_export' "$TMP/out" \
    && ok "removing dumps from ESCAPERS turns the twin red — the clear is earned" \
    || bad "the twin stays cleared without dumps: something else is clearing it"
else
  bad "MUTANT 2 did not apply: the battery would pass without measuring anything"
fi

# MUTANT 3 — the clever exception, restored. Credit a non-escaper call whose
# arguments are all literals, which is what the code said until CKAN proved it
# wrong. The battery asserts that version MISSES the advisory shape. Without
# this, the case above would be a line nobody could break on purpose.
sed 's|^        return False, f"{name}(\.\.\.)"|        return all(cleared(a, bindings)[0] for a in node.args) and bool(node.args), f"{name}(...)"|' \
  "$SUBJECT" > "$TMP/literalargs.py"
if ! cmp -s "$SUBJECT" "$TMP/literalargs.py"; then
  run "$TMP/literalargs.py" "$TMP/ckanshape"
  grep -q 'UNCLEARED.*reset.py' "$TMP/out" \
    && bad "the restored exception ALSO flags it: this battery cannot tell them apart" \
    || ok "the restored exception misses the advisory — removing it is what fixed this"
else
  bad "MUTANT 3 did not apply: the battery would pass without measuring anything"
fi

# --- the fix must clear, and the flag must be needed -------------------------
# CKAN fixed CVE-2024-27097 by wrapping the value in its own repr_untrusted().
# A check that flags the code that FIXED an advisory is a false positive on a
# fix, which is the worst kind for a worklist. Verified against upstream before
# crediting: ckan/common.py repr_untrusted() is repr() truncated to 200 chars.
mkdir -p "$TMP/fixed"
cat > "$TMP/fixed/reset.py" <<'PYEOF'
import logging
log = logging.getLogger(__name__)

def repr_untrusted(danger):
    r = repr(danger)
    return r[:200]

def post(id):
    log.info('Password reset requested for user %s', repr_untrusted(id))

def house(v):
    return v.replace('\n', ' ')

def other(id):
    log.info('user %s', house(id))
PYEOF

run "$SUBJECT" "$TMP/fixed"
grep -q "cleared.*repr_untrusted" "$TMP/out" \
  && ok "CKAN's own fix clears, and the credited name is printed" \
  || bad "the code that fixed CVE-2024-27097 is still flagged"

grep -q "UNCLEARED.*house" "$TMP/out" \
  && ok "a house helper this check has never heard of stays UNCLEARED by default" \
  || bad "an unknown helper was credited without anyone naming it"

run_flag() { python3 "$1" --target "$2" --escaper house > "$TMP/out" 2>&1; RC=$?; }
run_flag "$SUBJECT" "$TMP/fixed"
grep -q "cleared.*house" "$TMP/out" \
  && ok "--escaper credits a declared helper, and prints what it credited" \
  || bad "--escaper did not credit the name it was given"

# MUTANT 4 — repr_untrusted removed from ESCAPERS. The battery must go red, or
# the entry above is a line nobody could break on purpose.
sed 's|^    "repr_untrusted",|    "definitely_not_an_escaper_name",|' "$SUBJECT" > "$TMP/norepr.py"
if ! cmp -s "$SUBJECT" "$TMP/norepr.py"; then
  run "$TMP/norepr.py" "$TMP/fixed"
  grep -q "cleared.*repr_untrusted" "$TMP/out" \
    && bad "it clears WITHOUT the entry: this case measures nothing" \
    || ok "without the entry the fixed code is flagged again — the entry is load-bearing"
else
  bad "MUTANT 4 did not apply: the battery would pass without measuring anything"
fi

# MUTANT 5 — --escaper widened to credit any name that merely LOOKS like an
# escaper. That is the over-crediting that once cleared both keyed sites of a
# published advisory, so the battery holds the door shut on it.
sed 's|^    for name in args.escaper:|    for name in args.escaper + ["house", "scrub", "clean"]:|' "$SUBJECT" > "$TMP/widened.py"
if ! cmp -s "$SUBJECT" "$TMP/widened.py"; then
  run "$TMP/widened.py" "$TMP/fixed"
  grep -q "UNCLEARED.*house" "$TMP/out" \
    && bad "the widened version behaves identically: this case measures nothing" \
    || ok "the widened version credits a name nobody declared — which is why it is refused"
else
  bad "MUTANT 5 did not apply: the battery would pass without measuring anything"
fi

echo
echo "$pass PASS / $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
exit 0
