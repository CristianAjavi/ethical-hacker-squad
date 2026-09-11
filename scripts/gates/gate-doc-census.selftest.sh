#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-doc-census.selftest.sh — proof that gate-doc-census.sh can go red, and
# that each of its three answers is reachable.
#
# Every case is a MUTANT: a copy of this tree with one thing changed, and the
# verdict the gate must return. A gate whose self-test only shows it saying `ok`
# has proved nothing — the failure mode this repository keeps meeting is a green
# that comes from an instrument that cannot see, not from a healthy tree.
#
# EXIT CODES
#   0 = every mutant got the verdict it must get
#   1 = at least one did not (the gate is blind, or over-eager)
#   2 = I could not build the fixtures, so nothing was measured
# ---------------------------------------------------------------------------
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/../.." && pwd)"
GATE="scripts/gates/gate-doc-census.sh"
LIB="scripts/gates/lib/doc_census.py"

pass=0; fail=0

die() { printf '\n[COULD NOT MEASURE] %s\n' "$*" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || die "python3 is missing"
[ -f "$ROOT/$GATE" ] || die "$GATE is missing"
[ -f "$ROOT/docs/gate-requirements.md" ] || die "docs/gate-requirements.md is missing"

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t ehscensus)" || die "no temporary directory"
cleanup() { [ -n "${TMP:-}" ] && command rm -rf "$TMP" 2>/dev/null; }
trap cleanup EXIT

# A fixture is the real thing with one mutation: the gates directory and the
# document it polices, nothing else. Copying the real run-all.sh is deliberate —
# a fixture with a hand-written runner would measure a runner nobody ships.
build() { # build <dir>
  local d="$1"
  mkdir -p "$d/scripts" "$d/docs" || return 1
  cp -R "$ROOT/scripts/gates" "$d/scripts/gates" || return 1
  cp "$ROOT/docs/gate-requirements.md" "$d/docs/gate-requirements.md" || return 1
}

# A fixture that declares a cost lane must declare it EXACTLY ONCE. The tree
# under test may already declare one - the branch that introduced the lane does -
# and appending a second is a genuine could-not-measure, so five cases below were
# measuring the fixture instead of the gate: on the combined tree they answered
# 1 and 2 where they must answer 2 and 1. Any existing declaration is removed
# first, and the count is asserted afterwards rather than assumed beforehand.
cost_lane() { # cost_lane <dir> [line...]  -> declare the lane, fill its file
  local d="$1"; shift
  python3 - "$d/scripts/gates/run-all.sh" "$d/scripts/gates/data/slow-scoped.txt" "$@" <<'PY'
import os, re, sys
runall, lanefile, names = sys.argv[1], sys.argv[2], sys.argv[3:]
t = open(runall).read()
t = re.sub(r"(?m)^SLOW_SCOPED(?:_FILE)?=.*\n", "", t)
t = t.replace("PR_SCOPED='", 'SLOW_SCOPED_FILE="$SELF_DIR/data/slow-scoped.txt"\nPR_SCOPED=\'', 1)
n = len(re.findall(r"(?m)^SLOW_SCOPED(?:_FILE)?=", t))
assert n == 1, "the fixture declares the cost lane %d times, not once" % n
open(runall, "w").write(t)
os.makedirs(os.path.dirname(lanefile), exist_ok=True)
if names:
    open(lanefile, "w").write("\n".join(names) + "\n")
PY
}

check() { # check <label> <expected rc> <dir> [gate to run: default the fixture's own copy]
  # one `local` per line: bash expands every word of a `local` BEFORE running it,
  # so a default written as "${4:-$dir/...}" on the same line reads $dir unset.
  local label="$1" want="$2" dir="$3" rc=0
  local gate="${4:-$dir/$GATE}"
  ( cd "$dir" && EHS_REPO_ROOT="$dir" bash "$gate" ) >"$TMP/out.txt" 2>&1 || rc=$?
  if [ "$rc" -eq "$want" ]; then
    printf 'ok       %-48s rc=%s\n' "$label" "$rc"; pass=$((pass + 1))
  else
    printf 'FAIL     %-48s rc=%s (expected %s)\n' "$label" "$rc" "$want"
    sed 's/^/        | /' "$TMP/out.txt" | tail -8; fail=$((fail + 1))
  fi
}

# --- 1. the control -------------------------------------------------------
# Two halves, because they are two different claims.
#
# The tree as it SHIPS may answer 0 - the sentence is current - or 1 - the tree
# moved and nobody has re-emitted the sentence, which is the normal state of a
# tree that merges several branches and is exactly what this gate is for. What
# it may never answer here is 2: a census that cannot measure makes every case
# below meaningless, and that is the answer this battery must not swallow.
# Demanding 0 made this battery red on every combined tree, where the sentence
# is stale by construction - a control that fails on the healthy case.
D="$TMP/control"; build "$D" || die "could not build the control fixture"
rc=0; ( cd "$D" && EHS_REPO_ROOT="$D" bash "$D/$GATE" ) >"$TMP/out.txt" 2>&1 || rc=$?
if [ "$rc" = "0" ] || [ "$rc" = "1" ]; then
  printf 'ok       %-48s rc=%s\n' "the shipped tree can be measured" "$rc"; pass=$((pass + 1))
else
  printf 'FAIL     %-48s rc=%s (wanted 0 or 1)\n' "the shipped tree can be measured" "$rc"
  sed 's/^/        | /' "$TMP/out.txt" | tail -8; fail=$((fail + 1))
fi
# and the hermetic half: once the sentence is emitted, the same tree is green.
( cd "$D" && EHS_REPO_ROOT="$D" python3 "$D/$LIB" --root "$D" --write ) >"$TMP/w0.txt" 2>&1 \
  || die "--write answered rc=$? on the control fixture"
check "and once its sentence is emitted, it agrees" 0 "$D"

# --- 2. the tree moves and the document does not ----------------------------
D="$TMP/extra-gate"; build "$D" || die "fixture"
printf '#!/usr/bin/env bash\nexit 0\n' >"$D/scripts/gates/gate-zz-fixture.sh"
chmod +x "$D/scripts/gates/gate-zz-fixture.sh"
check "a gate nobody counted" 1 "$D"

D="$TMP/gone-selftest"; build "$D" || die "fixture"
rm -f "$D/scripts/gates/gate-tree-delta.selftest.sh"
check "a self-test battery that disappeared" 1 "$D"

D="$TMP/lane-moved"; build "$D" || die "fixture"
python3 - "$D/scripts/gates/run-all.sh" <<'PY'
import re, sys
p = sys.argv[1]
t = open(p).read()
t = re.sub(r"(?m)^EXTERNAL_SCOPED='[^']*'", "EXTERNAL_SCOPED=''", t)
open(p, "w").write(t)
PY
check "a lane emptied under the document's feet" 1 "$D"

# --- 3. the document moves and the tree does not ----------------------------
D="$TMP/edited-figure"; build "$D" || die "fixture"
python3 - "$D/docs/gate-requirements.md" <<'PY'
import sys
p = sys.argv[1]
t = open(p).read()
assert "execute on every push and pull request" in t
i = t.index("execute on every push")
t = t[: i - 3] + "17 " + t[i:]
open(p, "w").write(t)
PY
check "a figure typed over by hand" 1 "$D"

D="$TMP/prose-back"; build "$D" || die "fixture"
python3 - "$D/docs/gate-requirements.md" <<'PY'
import re, sys
p = sys.argv[1]
t = open(p).read()
t = re.sub(r"39 gate scripts", "Thirty-nine gate scripts", t)
open(p, "w").write(t)
PY
check "a figure written back out as a word" 1 "$D"

# --- 4. the answers that must NOT be a pass ---------------------------------
D="$TMP/no-begin"; build "$D" || die "fixture"
python3 - "$D/docs/gate-requirements.md" <<'PY'
import re, sys
p = sys.argv[1]
t = open(p).read()
t = re.sub(r"<!-- census:begin[^>]*-->\n", "", t)
open(p, "w").write(t)
PY
check "the opening marker removed" 2 "$D"

D="$TMP/no-end"; build "$D" || die "fixture"
python3 - "$D/docs/gate-requirements.md" <<'PY'
import sys
p = sys.argv[1]
t = open(p).read()
open(p, "w").write(t.replace("<!-- census:end -->\n", ""))
PY
check "the closing marker removed" 2 "$D"

D="$TMP/no-doc"; build "$D" || die "fixture"
rm -f "$D/docs/gate-requirements.md"
check "the document itself gone" 2 "$D"

D="$TMP/no-runall"; build "$D" || die "fixture"
rm -f "$D/scripts/gates/run-all.sh"
check "no runner to declare the lanes" 2 "$D"

D="$TMP/scope-renamed"; build "$D" || die "fixture"
python3 - "$D/scripts/gates/run-all.sh" <<'PY'
import re, sys
p = sys.argv[1]
t = open(p).read()
t = re.sub(r"(?m)^PR_SCOPED=", "PR_SCOPED_LIST=", t, count=1)
open(p, "w").write(t)
PY
check "a scope declaration that no longer parses" 2 "$D"

D="$TMP/silent-list"; build "$D" || die "fixture"
printf '#!/usr/bin/env bash\nexit 0\n' >"$D/scripts/gates/run-all.sh"
check "a runner that lists nothing" 2 "$D"

D="$TMP/ghost-lane"; build "$D" || die "fixture"
python3 - "$D/scripts/gates/run-all.sh" <<'PY'
import re, sys
p = sys.argv[1]
t = open(p).read()
t = re.sub(r"(?m)^LIVE_SCOPED='([^']*)'", r"LIVE_SCOPED='\1 gate-ghost.sh'", t)
open(p, "w").write(t)
PY
check "a lane that defers a gate nobody has" 2 "$D"

D="$TMP/no-gates"; build "$D" || die "fixture"
rm -f "$D"/scripts/gates/gate-*.sh
# the fixture has no gates left, so the gate under test is run from THIS tree and
# pointed at the empty one: otherwise the mutant deletes its own instrument and the
# 127 that follows would be counted as a measurement.
check "a tree with no gates in it at all" 2 "$D" "$ROOT/$GATE"

# --- 4b. the lanes are DISCOVERED, so a fourth one cannot arrive unseen -----
# The document this gate polices was wrong in exactly this way once: it described
# three lanes where the runner had four. A census that also knows three names
# would not report a missing lane, it would report a WRONG number - the fourth
# lane's gates counted as running on every push. These cases are the proof that
# the lane list comes from the runner rather than from this module's memory.

D="$TMP/lane-in-a-file"; build "$D" || die "fixture"
cost_lane "$D" "# deferred for cost" gate-agent-roster.sh
# The disagreement is BUILT here, never borrowed from the base tree. Written as
# "the runner does not honour this lane" it measured a property of whatever
# run-all.sh happened to be copied in: on the tree that merges the branch which
# TAUGHT the runner the lane, the two agreed and the case went red over a tree
# where nothing was wrong. Asking the runner to run the cost lane instead makes
# it list a name the census defers - on a runner that honours the lane and on
# one that has never heard of it - and a census that disagrees with `--list`
# about one name is a 2.
export EHS_SLOW_GATES=1
check "a cost lane the runner does not defer" 2 "$D"
unset EHS_SLOW_GATES

# and the positive half: the names in that file are the ones the reader returns.
LANES="$(cd "$D" && python3 - 2>&1 <<'PY'
import os
import sys
sys.path.insert(0, "scripts/gates/lib")
import doc_census as d
gates = os.path.abspath("scripts/gates")
names = d.lanes(open("scripts/gates/run-all.sh").read(), gates)
print(" ".join(names.get("SLOW_SCOPED", ["(no such lane)"])) or "(the lane read empty)")
PY
)"
if [ "$LANES" = "gate-agent-roster.sh" ]; then
  printf 'ok       %-48s %s\n' "the file lane is read, by name" "$LANES"; pass=$((pass + 1))
else
  printf 'FAIL     %-48s %s\n' "the file lane is read, by name" "$LANES"; fail=$((fail + 1))
fi

# A cost lane defers the battery beside the gate - deferring only the gate moves
# the cost into --selftests instead of removing it - so a battery in a lane is
# not a lane pointing at nothing. Both halves are measured: the name that is
# there, and the name that is not.
D="$TMP/lane-with-a-battery"; build "$D" || die "fixture"
cost_lane "$D" gate-agent-tools.selftest.sh
# rc=1, not 2: the lane is legal and READ - a battery in a cost lane is not a
# lane pointing at nothing - and what is now wrong is the sentence, which the
# emitter can fix. Before the lanes were discovered this same tree answered 2.
check "a cost lane that defers a battery" 1 "$D"
( cd "$D" && EHS_REPO_ROOT="$D" python3 "$D/$LIB" --root "$D" --write ) >"$TMP/w2.txt" 2>&1 \
  || die "--write answered rc=$? on a tree carrying a cost lane"
check "and after --write, that tree is green" 0 "$D"
# BOTH halves. The first draft of the cost clause overwrote the line that names
# the live lane, and a check that only looked for the new clause called that
# green: a sentence can gain a lane and lose one in the same edit.
if grep -q 'deferred for cost by name in' "$D/docs/gate-requirements.md" \
   && grep -q 'measures the live repository' "$D/docs/gate-requirements.md"; then
  printf 'ok       %-48s %s\n' "the cost clause displaces no other lane" "both named"; pass=$((pass + 1))
else
  printf 'FAIL     %-48s %s\n' "the cost clause displaces no other lane" \
    "cost=$(grep -c 'deferred for cost by name in' "$D/docs/gate-requirements.md") live=$(grep -c 'measures the live repository' "$D/docs/gate-requirements.md")"
  fail=$((fail + 1))
fi

D="$TMP/lane-with-a-ghost-battery"; build "$D" || die "fixture"
cost_lane "$D" gate-nobody.selftest.sh
check "a cost lane that defers a battery nobody has" 2 "$D"

D="$TMP/lane-unreadable"; build "$D" || die "fixture"
cost_lane "$D" gate-agent-roster.sh
chmod 000 "$D/scripts/gates/data/slow-scoped.txt"
if [ "$(id -u)" = "0" ]; then
  printf 'SKIPPED  %-48s %s\n' "a lane file that cannot be read" "running as root: no file is unreadable"
else
  check "a lane file that cannot be read" 2 "$D"
fi
chmod 644 "$D/scripts/gates/data/slow-scoped.txt" 2>/dev/null || true

D="$TMP/lane-unknown-shape"; build "$D" || die "fixture"
python3 - "$D/scripts/gates/run-all.sh" <<'PY'
import re, sys
p = sys.argv[1]
t = open(p).read()
t = re.sub(r"(?m)^SLOW_SCOPED(?:_FILE)?=.*\n", "", t)
t = t.replace("PR_SCOPED='", 'SLOW_SCOPED="gate-agent-roster.sh"\nPR_SCOPED=\'', 1)
n = len(re.findall(r"(?m)^SLOW_SCOPED(?:_FILE)?=", t))
assert n == 1, "the fixture declares the lane %d times, not once" % n
open(p, "w").write(t)
PY
check "a lane written in a shape nobody reads" 2 "$D"

D="$TMP/lane-unknown-name"; build "$D" || die "fixture"
python3 - "$D/scripts/gates/run-all.sh" <<'PY'
import sys
p = sys.argv[1]
t = open(p).read()
t = t.replace("PR_SCOPED='", "WEEKEND_SCOPED='gate-agent-roster.sh'\nPR_SCOPED='", 1)
open(p, "w").write(t)
PY
check "a lane this census has no name for" 2 "$D"

# --- 5. the emitter and the checker must agree ------------------------------
# Without this, --write could be writing something the gate would call wrong,
# and every green above would only prove the two were frozen together.
D="$TMP/rewrite"; build "$D" || die "fixture"
# The number is a DELTA, never a constant. Written as `40 gate scripts` this
# case asserted the size of the tree it was born in, so it goes red on any tree
# that grew - including the one that merges the open branches, where nothing is
# wrong. What it means to say is that the emitter counted ONE MORE, so it counts
# before and after and compares the two.
( cd "$D" && EHS_REPO_ROOT="$D" python3 "$D/$LIB" --root "$D" --write ) >"$TMP/w1.txt" 2>&1 \
  || die "--write answered rc=$? on a tree it must be able to write"
n0="$(grep -oE '[0-9]+ gate scripts' "$D/docs/gate-requirements.md" | head -1 | grep -oE '^[0-9]+')"
printf '#!/usr/bin/env bash\nexit 0\n' >"$D/scripts/gates/gate-zz-fixture.sh"
chmod +x "$D/scripts/gates/gate-zz-fixture.sh"
check "before --write, the extra gate is a failure" 1 "$D"
( cd "$D" && EHS_REPO_ROOT="$D" python3 "$D/$LIB" --root "$D" --write ) >"$TMP/w.txt" 2>&1 \
  || die "--write answered rc=$? on a tree it must be able to write"
check "after --write, the same tree is green" 0 "$D"
n1="$(grep -oE '[0-9]+ gate scripts' "$D/docs/gate-requirements.md" | head -1 | grep -oE '^[0-9]+')"
if [ -n "$n0" ] && [ -n "$n1" ] && [ "$n1" = "$((n0 + 1))" ]; then
  printf 'ok       %-48s %s\n' "--write counted the new gate" "$n0 -> $n1"; pass=$((pass + 1))
else
  printf 'FAIL     %-48s %s\n' "--write counted the new gate" \
    "before='${n0:-unreadable}' after='${n1:-unreadable}'"; fail=$((fail + 1))
fi

printf -- '--- %d passed, %d failed ---\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
