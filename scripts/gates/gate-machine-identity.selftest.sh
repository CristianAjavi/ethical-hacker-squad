#!/usr/bin/env bash
# Self-test for gate-machine-identity.sh.
#
# A gate that hunts a string is the easiest kind to write green by accident: the
# string is not there, so it passes, and it would pass just as happily with the
# sweep disconnected. Every case below therefore breaks exactly one thing and
# requires the gate to notice, and case 15 runs the gate against THIS repository
# rather than a fixture — the fixture proves the logic, the real tree proves the
# logic is pointed at something.
#
# The fixture is a throwaway git work tree, because the sweep is defined as
# "what git tracks" and a directory that is not a work tree is exactly one of
# the states the gate must answer 2 to.
#
# NOTE ON THIS FILE'S OWN TEXT: the payloads are built by concatenation
# ("/Users" "/attacker") so that this file does not itself contain the shapes it
# plants. A battery that carried them would need an inventory entry of its own,
# and the first thing anyone would do with that entry is grow it.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-machine-identity.sh"
ENGINE="$HERE/lib/machine_identity.py"
COMMON="$HERE/lib/common.sh"
DATA_REL="scripts/gates/data/machine-identity.json"

for f in "$GATE" "$ENGINE" "$COMMON"; do
  [ -f "$f" ] || { echo "UNMEASURABLE $f is missing"; exit 2; }
done
command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
command -v git >/dev/null 2>&1 || { echo "UNMEASURABLE git is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-machid-XXXXXX")" || { echo "UNMEASURABLE mktemp"; exit 2; }
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
# Payloads assembled so this file carries none of them literally.
P_HOME="/Users""/attacker"
P_SCRATCH="/private/""tmp/claude-999"

say_pass() { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
say_fail() { fail=$((fail+1)); printf 'FAIL  %s -- %s\n' "$1" "$2"; }

# build_fixture <dir> — a minimal work tree the gate can be pointed at.
build_fixture() {
  local d="$1"
  mkdir -p "$d/scripts/gates/lib" "$d/scripts/gates/data" "$d/bench/runs/r1"
  cp "$GATE" "$d/scripts/gates/gate-machine-identity.sh"
  cp "$ENGINE" "$d/scripts/gates/lib/machine_identity.py"
  cp "$COMMON" "$d/scripts/gates/lib/common.sh"
  printf 'clean prose, no machine anywhere\n' > "$d/README.md"
  printf 'a recorded prompt that names %s/session/work\n' "$P_SCRATCH" > "$d/bench/runs/r1/prompt.txt"
  # The fixture's pattern list is READ from the real data file, never copied
  # here. Two reasons, and the second one is why this is not merely tidy: a copy
  # is a second spelling of the rule, and the rule is that there is one; and one
  # of the five shapes, the temporary-folder root, matches its own source text,
  # so a battery that spelled it out would be a versioned file naming a machine
  # path — this gate would fail on its own proof, and did, before this line.
  python3 -c 'import json,sys
src, dst, rel = sys.argv[1], sys.argv[2], sys.argv[3]
pats = json.load(open(src, encoding="utf-8"))["patterns"]
json.dump({"self_exemption": rel, "patterns": pats,
           "frozen": {"bench/runs/r1/prompt.txt": 1},
           "totals": {"files": 1, "occurrences": 1}},
          open(dst, "w", encoding="utf-8"), indent=2)' \
    "$HERE/data/machine-identity.json" "$d/$DATA_REL" "$DATA_REL" || return 1
  git -C "$d" init -q 2>/dev/null
  git -C "$d" add -A 2>/dev/null
  git -C "$d" -c user.email=t@e -c user.name=t commit -qm f 2>/dev/null
}

# run_fixture <dir> [args...] -> prints rc
run_fixture() {
  local d="$1"; shift
  local rc=0
  ( cd "$d" && bash scripts/gates/gate-machine-identity.sh "$@" ) >"$TMP/out.$$" 2>&1 || rc=$?
  printf '%s' "$rc"
}

# expect <case> <wanted rc> <dir> [args...]
expect() {
  local name="$1" want="$2" d="$3"; shift 3
  local got; got="$(run_fixture "$d" "$@")"
  if [ "$got" = "$want" ]; then say_pass "$name (rc=$got)"
  else say_fail "$name" "wanted rc=$want, got rc=$got: $(tail -3 "$TMP/out.$$" | tr '\n' ' ')"; fi
}

fresh() { local d="$TMP/$1"; rm -rf "$d"; build_fixture "$d"; printf '%s' "$d"; }

# --- 1. the fixture as built is clean ------------------------------------
D="$(fresh c1)"
expect "the untouched fixture measures clean" 0 "$D"

# --- 2. a brand-new file with a machine path -----------------------------
D="$(fresh c2)"
printf 'notes from %s/x\n' "$P_SCRATCH" > "$D/notes.md"
git -C "$D" add -A >/dev/null 2>&1
expect "a new file with a machine path is caught" 1 "$D"

# --- 3. the same payload in a file git does NOT track --------------------
D="$(fresh c3)"
printf 'notes from %s/x\n' "$P_SCRATCH" > "$D/untracked.md"
expect "an untracked file is out of scope and stays green" 0 "$D"

# --- 4. an inventoried file that grows -----------------------------------
D="$(fresh c4)"
printf 'and a second one at %s/y\n' "$P_SCRATCH" >> "$D/bench/runs/r1/prompt.txt"
git -C "$D" add -A >/dev/null 2>&1
expect "an inventoried file that grows is caught" 1 "$D"

# --- 5. one file pays its debt, another takes it up ----------------------
D="$(fresh c5)"
printf 'clean now\n' > "$D/bench/runs/r1/prompt.txt"
printf 'moved to %s/z\n' "$P_SCRATCH" > "$D/elsewhere.md"
git -C "$D" add -A >/dev/null 2>&1
expect "a deletion here cannot pay for an addition there" 1 "$D"

# --- 6. a debt already paid, inventory not updated -----------------------
D="$(fresh c6)"
printf 'clean now\n' > "$D/bench/runs/r1/prompt.txt"
git -C "$D" add -A >/dev/null 2>&1
expect "an inventory that overstates the debt is caught" 1 "$D"

# --- 7. --update turns the ratchet down ----------------------------------
D="$(fresh c7)"
printf 'clean now\n' > "$D/bench/runs/r1/prompt.txt"
git -C "$D" add -A >/dev/null 2>&1
if [ "$(run_fixture "$D" --update)" = "0" ] && [ "$(run_fixture "$D")" = "0" ] &&
   ! grep -q 'prompt.txt' "$D/$DATA_REL"; then
  say_pass "--update removes a paid entry and the tree then measures clean"
else
  say_fail "--update removes a paid entry" "the entry survived or the rerun was not clean"
fi

# --- 8. --update refuses to grow the inventory ---------------------------
D="$(fresh c8)"
printf 'brand new debt at %s/q\n' "$P_SCRATCH" > "$D/new.md"
git -C "$D" add -A >/dev/null 2>&1
expect "--update refuses to enlarge the inventory" 2 "$D" --update

# --- 9. the exempt data file is exempt ONLY where it lives ---------------
D="$(fresh c9)"
cp "$D/$DATA_REL" "$D/scripts/gates/data/machine-identity.copy.json"
git -C "$D" add -A >/dev/null 2>&1
expect "the exemption is by name: the same bytes next door go red" 1 "$D"

# --- 10. the ledger contradicting its own total --------------------------
D="$(fresh c10)"
python3 - "$D/$DATA_REL" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["totals"]["occurrences"]=99
json.dump(d,open(p,"w"),indent=2)
PY
git -C "$D" add -A >/dev/null 2>&1
expect "a ledger that cannot add up its own rows is caught" 1 "$D"

# --- 11. missing data file -> 2 ------------------------------------------
D="$(fresh c11)"; rm -f "$D/$DATA_REL"
expect "a missing inventory is UNMEASURABLE, never a pass" 2 "$D"

# --- 12. unparsable data file -> 2 ---------------------------------------
D="$(fresh c12)"; printf '{ not json\n' > "$D/$DATA_REL"
expect "an unparsable inventory is UNMEASURABLE" 2 "$D"

# --- 13. data file with no patterns -> 2 ---------------------------------
D="$(fresh c13)"
printf '{"self_exemption":"x","patterns":[],"frozen":{},"totals":{"files":0,"occurrences":0}}\n' > "$D/$DATA_REL"
expect "an inventory declaring no shapes is UNMEASURABLE" 2 "$D"

# --- 14. not a work tree -> 2 --------------------------------------------
D="$(fresh c14)"; rm -rf "$D/.git"
expect "a directory that is not a work tree is UNMEASURABLE" 2 "$D"

# --- 15. the one-definition check against external_crosscheck.py ---------
# The consumer file necessarily contains one of the shapes (its own pattern
# list), so each of these cases also gives it an allowance; otherwise the case
# would measure the sweep instead of the reconciliation.
D="$(fresh c15a)"
python3 - "$D" <<'PY'
import json,re,sys
root=sys.argv[1]; dp=root+"/scripts/gates/data/machine-identity.json"
d=json.load(open(dp)); pats=d["patterns"]
body="MACHINE_PATHS = [\n"+"".join('    re.compile(r"%s"),\n'%p for p in pats)+"]\n"
text="import re\n"+body
open(root+"/scripts/gates/lib/external_crosscheck.py","w").write(text)
n=sum(len(re.compile(p).findall(text)) for p in pats)
d["frozen"]["scripts/gates/lib/external_crosscheck.py"]=n
d["totals"]={"files":len(d["frozen"]),"occurrences":sum(d["frozen"].values())}
json.dump(d,open(dp,"w"),indent=2)
PY
git -C "$D" add -A >/dev/null 2>&1
expect "an identical second list is reconciled, not duplicated" 0 "$D"

D="$(fresh c15b)"
printf 'import re\nMACHINE_PATHS = [\n    re.compile(r"/nope/"),\n]\n' \
  > "$D/scripts/gates/lib/external_crosscheck.py"
git -C "$D" add -A >/dev/null 2>&1
expect "a second list that spells the rule differently is caught" 1 "$D"

D="$(fresh c15c)"
printf 'import re\n# no list here at all\n' > "$D/scripts/gates/lib/external_crosscheck.py"
git -C "$D" add -A >/dev/null 2>&1
expect "a consumer present with no list to reconcile is caught" 1 "$D"

# --- 16. the shapes are read from data, not baked into the engine --------
# If the engine carried its own copy, emptying the declared list would change
# nothing and this case would come back green.
D="$(fresh c16)"
python3 - "$D/$DATA_REL" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p))
d["patterns"]=["ZZZ-not-a-path-shape"]; d["frozen"]={}; d["totals"]={"files":0,"occurrences":0}
json.dump(d,open(p,"w"),indent=2)
PY
git -C "$D" add -A >/dev/null 2>&1
expect "with the shapes replaced the sweep finds nothing: it reads them from data" 0 "$D"

# --- 17. a binary file is reported unread, never silently passed ---------
D="$(fresh c17)"
printf 'x%s/bin\0\0binary\n' "$P_SCRATCH" > "$D/blob.bin"
git -C "$D" add -A >/dev/null 2>&1
# The assertion is on the NUMBER, not on the sentence. An earlier version of
# this case grepped for the phrase "binary or undecodable and not read", which
# the gate prints on every run whatever the count is: it passed identically with
# the binary branch of the engine removed, and a mutation bank caught it. A case
# that reads a line the instrument always emits is measuring the instrument's
# vocabulary, not its answer.
rc17="$(run_fixture "$D")"
unread17="$(sed -n 's/^read *: .*; \([0-9][0-9]*\) binary or undecodable.*/\1/p' "$TMP/out.$$")"
# Exactly one: the fixture plants exactly one binary and every other file in it
# is text, so 1 is the only honest answer. "-ge 1" would also have been satisfied
# by a tree that happened to carry a second binary for some other reason.
if [ "$rc17" = "0" ] && [ "${unread17:-0}" = "1" ]; then
  say_pass "the binary carrying the shape is the one file counted as unread, not as clean"
else
  say_fail "the binary is the one file counted as unread" "rc=$rc17, unread=${unread17:-unparsed}, expected 1"
fi

# --- 18. THE REAL REPOSITORY, not a fixture ------------------------------
# The fixtures prove the logic. This proves the logic is aimed at the tree that
# ships, which is the case iteration 7 found was missing everywhere else.
real_rc=0
bash "$GATE" >"$TMP/real.out" 2>&1 || real_rc=$?
if [ "$real_rc" = "0" ]; then
  say_pass "the real repository measures clean (green is reachable, not theoretical)"
else
  say_fail "the real repository measures clean" "rc=$real_rc: $(grep -m3 '^FAIL' "$TMP/real.out" | tr '\n' ' ')"
fi

# --- 19..23. the forward declaration for files on open branches ----------
# declare_expected <dir> <path> <n> <branch> [--drop-why]
declare_expected() {
  python3 - "$1" "$2" "$3" "$4" "${5:-keep}" <<'PY'
import json,sys
root,rel,n,branch,mode=sys.argv[1:6]
dp=root+"/scripts/gates/data/machine-identity.json"
d=json.load(open(dp))
spec={"occurrences":int(n),"branch":branch,"why":"a fixture reason"}
if mode=="--drop-why": del spec["why"]
d.setdefault("expected_on_merge",{})[rel]=spec
json.dump(d,open(dp,"w"),indent=2)
PY
}

# 19. declared, not present yet: not an error, and not silently green either
D="$(fresh c19)"
git -C "$D" branch other >/dev/null 2>&1
declare_expected "$D" "not/here/yet.py" 1 "other"
git -C "$D" add -A >/dev/null 2>&1
rc19="$(run_fixture "$D")"
if [ "$rc19" = "1" ] && grep -q 'does not have it' "$TMP/out.$$"; then
  say_pass "a declaration naming a branch that lacks the file is caught"
else
  say_fail "a false declaration is caught" "rc=$rc19"
fi

# 20. declared against a ref this checkout does not have -> reported, not passed
D="$(fresh c20)"
declare_expected "$D" "not/here/yet.py" 1 "origin/loop/a-ref-we-do-not-have"
git -C "$D" add -A >/dev/null 2>&1
rc20="$(run_fixture "$D")"
if [ "$rc20" = "0" ] && grep -q 'not verifiable\|a ref this checkout does not have' "$TMP/out.$$"; then
  say_pass "an unverifiable declaration is printed as unchecked, not as checked"
else
  say_fail "an unverifiable declaration is printed" "rc=$rc20"
fi

# 21. declared and present, within its allowance -> green, and said so
D="$(fresh c21)"
git -C "$D" branch other >/dev/null 2>&1
printf 'arrived from a branch: %s/w\n' "$P_SCRATCH" > "$D/arrived.md"
git -C "$D" add -A >/dev/null 2>&1
git -C "$D" -c user.email=t@e -c user.name=t commit -qm a >/dev/null 2>&1
git -C "$D" branch -f other HEAD >/dev/null 2>&1
declare_expected "$D" "arrived.md" 1 "other"
git -C "$D" add -A >/dev/null 2>&1
expect "a declared file that arrives within its allowance is green" 0 "$D"

# 22. the same file declared and present, but over its allowance
D="$(fresh c22)"
git -C "$D" branch other >/dev/null 2>&1
printf 'one %s/w and two %s/v\n' "$P_SCRATCH" "$P_SCRATCH" > "$D/arrived.md"
git -C "$D" add -A >/dev/null 2>&1
git -C "$D" -c user.email=t@e -c user.name=t commit -qm a >/dev/null 2>&1
git -C "$D" branch -f other HEAD >/dev/null 2>&1
declare_expected "$D" "arrived.md" 1 "other"
git -C "$D" add -A >/dev/null 2>&1
expect "a declared file over its declared allowance is caught" 1 "$D"

# 23. a declaration missing its reason
D="$(fresh c23)"
git -C "$D" branch other >/dev/null 2>&1
declare_expected "$D" "bench/runs/r1/prompt.txt" 1 "other" --drop-why
git -C "$D" add -A >/dev/null 2>&1
rc23="$(run_fixture "$D")"
if [ "$rc23" = "1" ]; then
  say_pass "a declaration with no written reason, and one listed twice, are caught"
else
  say_fail "a declaration with no reason is caught" "rc=$rc23"
fi

# The house grammar for a battery total: this file used to spell it
# `cases: N | ok: M | FAILED: K`, a shape no other battery emits and
# gate-case-counts.sh cannot read, so the figure this battery answers could not
# be bound to it - the same correction gate-pack-routing.selftest.sh took in
# iteration 4, recorded in scripts/gates/data/case-counts.json.
printf '\nSummary: %s ok, %s failures\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
