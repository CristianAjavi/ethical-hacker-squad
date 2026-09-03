#!/usr/bin/env bash
# Self-test for gate-portable-shell.sh. Each case seeds one tiny tree carrying
# exactly one shape and asserts the exit code AND the reason, including a control
# on the untouched repository and five cases that must report could-not-measure.
#
# The fixtures are seeded, not copied. Thirteen batteries in this repository tar
# the whole tree per case and move 258 MB of node_modules to make a point about
# one file; this gate reads shell text and needs nothing else, so a case here is
# a directory with one script in it.
#
# NOTE ON THIS FILE'S OWN LINES. A battery that proves a gate refuses `sed -i ''`
# has to contain `sed -i ''`, and it lives under scripts/, so the gate reads it
# too. The fixture lines therefore carry the written exemption the gate itself
# offers - which means the production run also exercises the exemption path, and
# prints these lines back as honoured. That is the intended shape: an escape
# hatch nobody ever takes is an escape hatch nobody has tested.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-portable-shell.sh"
if [ -n "${EHS_REPO_ROOT:-}" ]; then SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then :
else SRC="$(cd "$HERE/../.." && pwd)"; fi
command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-portable-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# seed <case> <line>... - a tree whose scripts/ holds one file with those lines.
seed() {
  local name="$1"; shift
  local dir="$TMP/$name/scripts"
  mkdir -p "$dir" || return 1
  { printf '%s\n' '#!/usr/bin/env bash'; printf '%s\n' "$@"; } > "$dir/probe.sh"
}

# case_run <name> <expected rc> <needle> [extra gate args...]
#
# The needle is not decoration. A case that asserts only the code cannot tell a
# gate that failed for its reason from one that failed for any other, and this
# repository has already shipped a case that passed by the wrong path.
case_run() {
  local name="$1" want="$2" needle="$3"; shift 3
  local root="$TMP/$name" out rc
  [ -d "$root" ] || root="$TMP/$name"
  out="$(bash "$GATE" --root "$root" "$@" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf 'ok       %-46s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-46s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -6; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-portable-shell.sh (source: $SRC) ==="

# The control is the whole repository, unmutated. It is the case that decides
# whether this gate is usable at all: measured before the catalogue was written,
# a version with no fallback exoneration reported 18 findings here, every one of
# them a CORRECT line. A gate whose first red accuses the compliant gets turned
# off, so this case runs first and its green is load-bearing.
out="$(bash "$GATE" --root "$SRC" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  printf 'ok       %-46s rc=0\n' control-the-real-repository; pass=$((pass+1))
else
  printf 'FAILED   %-46s rc=%s (wanted 0)\n' control-the-real-repository "$rc"
  printf '%s\n' "$out" | sed 's/^/         /' | tail -8; fail=$((fail+1))
fi

# --- the divergences, alone, with nothing to save them ------------------------

seed bsd-sed-with-no-way-out \
  "sed -i '' -e 's/a/b/' f.txt"  # portable-shell: allow sed-i-empty - fixture for the negative proof
case_run bsd-sed-with-no-way-out 1 "sed-i-empty"

seed gnu-sed-with-no-way-out \
  "sed -i -e 's/a/b/' f.txt"  # portable-shell: allow sed-i-bare - fixture for the negative proof
case_run gnu-sed-with-no-way-out 1 "sed-i-bare"

seed mktemp-t-with-no-way-out \
  'd="$(mktemp -d -t ehsprobe)"'  # portable-shell: allow mktemp-t - fixture for the negative proof
case_run mktemp-t-with-no-way-out 1 "mktemp-t"

seed date-bsd-with-no-way-out \
  'ago="$(date -u -v-1d +%Y-%m-%d)"'  # portable-shell: allow date-bsd - fixture for the negative proof
case_run date-bsd-with-no-way-out 1 "date-bsd"

seed stat-c-with-no-way-out \
  'n="$(stat -c %s f.txt)"'  # portable-shell: allow stat-c - fixture for the negative proof
case_run stat-c-with-no-way-out 1 "stat-c"

seed grep-P-with-no-way-out \
  'grep -P "\\d+" f.txt'  # portable-shell: allow grep-P - fixture for the negative proof
case_run grep-P-with-no-way-out 1 "grep-P"

# echo-e carries no counterpart in the catalogue, so no `||` can exonerate it and
# the written exemption is the only way out. Without a case here, the whole class
# of rules with `"counterpart": null` would ship untested.
seed echo-e-has-no-counterpart-at-all \
  'echo -e "a\\tb"'  # portable-shell: allow echo-e - fixture for the negative proof
case_run echo-e-has-no-counterpart-at-all 1 "echo-e"

# --- the fallback idiom, which must NOT be a finding --------------------------

seed mktemp-the-fallback-this-repo-writes \
  'd="$(mktemp -d 2>/dev/null || mktemp -d -t ehsprobe)"'  # portable-shell: allow mktemp-t - fixture: this is the SHAPE under test
case_run mktemp-the-fallback-this-repo-writes 0 "no BSD-only or GNU-only"

seed sed-both-spellings-with-or \
  "sed -i '' -e 's/a/b/' f.txt 2>/dev/null || sed -i -e 's/a/b/' f.txt"  # portable-shell: allow sed-i-empty,sed-i-bare - fixture: the pair
case_run sed-both-spellings-with-or 0 "no BSD-only or GNU-only"

# The one real fallback in this repository is split across two physical lines by
# a trailing backslash, with the BSD half on the first and the GNU half on the
# second. Read physically, each half is a lone platform-specific call and BOTH
# get flagged; read logically, the pair is correct. This case is the only thing
# standing between the continuation joiner and a silent regression.
seed date-fallback-split-by-a-backslash \
  'ago() { date -u -v-"$1"d +%Y-%m-%d 2>/dev/null \' \
  '  || date -u -d "$1 days ago" +%Y-%m-%d; }'  # portable-shell: allow date-bsd,date-gnu - fixture: the split pair
case_run date-fallback-split-by-a-backslash 0 "no BSD-only or GNU-only"

# Both spellings present and no `||` between them: two independent calls, not a
# fallback. If the `||` test were ever dropped from the condition this case is
# the one that goes red, and nothing else would.
seed both-spellings-but-no-or \
  'stat -c %s f.txt; stat -f %z f.txt'  # portable-shell: allow stat-c,stat-f - fixture: two calls, not a fallback
case_run both-spellings-but-no-or 1 "stat-c"

# --- what must never count ----------------------------------------------------

# The exemption below sits on the LAST physical line of the seed on purpose: the
# gate joins backslash continuations before it reads anything, so the logical
# line this fixture lives on ends there and nowhere else. Putting the marker on
# the first line looks right and does nothing.
seed the-divergence-only-appears-in-a-comment \
  "# this used to be sed -i '' and that is why the gate exists" \
  'true'  # portable-shell: allow sed-i-empty - fixture: the divergence inside a comment
case_run the-divergence-only-appears-in-a-comment 0 "no BSD-only or GNU-only"

# --- the written exemption, and its teeth -------------------------------------

# The three cases below need fixtures whose own exemption is deliberately
# INSUFFICIENT - missing, or naming another rule - and a fixture like that,
# written inline, is indistinguishable from a real defect when the gate reads
# this file. Measured: it reported exactly that, and the control went red. The
# literal therefore lives in one variable that carries one sufficient exemption,
# and the case lines below hold no divergent spelling at all.
BSD_SED="sed -i '' -e 's/a/b/' f.txt"  # portable-shell: allow sed-i-empty - the fixture text the three exemption cases seed

seed an-exemption-that-says-why \
  "$BSD_SED # portable-shell: allow sed-i-empty - macOS-only helper, never runs on the runner"
case_run an-exemption-that-says-why 0 "exempted in writing"

# An exemption with no reason is itself a finding. Removing a check and writing
# down what replaces it are the same edit; this is the half that otherwise never
# happens.
seed an-exemption-that-says-nothing \
  "$BSD_SED # portable-shell: allow sed-i-empty"
case_run an-exemption-that-says-nothing 1 "half an edit"

# An allow for one rule must not cover another. Without this case a single
# exemption anywhere on a line would blanket every divergence on it.
seed an-exemption-for-a-different-rule \
  "$BSD_SED # portable-shell: allow mktemp-t - names a rule this line does not break"
case_run an-exemption-for-a-different-rule 1 "sed-i-empty"

# --- could not measure --------------------------------------------------------

mkdir -p "$TMP/no-scripts-directory/docs"
case_run no-scripts-directory 2 "no scripts/ directory"

mkdir -p "$TMP/scripts-with-no-shell-file/scripts"
printf 'not a shell script\n' > "$TMP/scripts-with-no-shell-file/scripts/README.md"
case_run scripts-with-no-shell-file 2 "blind zero"

# chmod 000 would not do it: CI runs as root and root reads it anyway, so the
# case would pass locally and quietly measure nothing on the runner. Bytes that
# are not UTF-8 fail for every user there is.
mkdir -p "$TMP/a-file-that-does-not-decode/scripts"
printf '#!/bin/sh\n\377\376 not utf-8\n' > "$TMP/a-file-that-does-not-decode/scripts/probe.sh"
case_run a-file-that-does-not-decode 2 "cannot read"

seed a-catalogue-that-does-not-compile 'true'
printf '%s\n' '{"rules":[{"id":"x","why":"y","pattern":"(unclosed"}]}' \
  > "$TMP/broken-catalogue.json"
case_run a-catalogue-that-does-not-compile 2 "does not compile" \
  --catalogue "$TMP/broken-catalogue.json"

seed a-catalogue-with-no-rules 'true'
printf '%s\n' '{"rules":[]}' > "$TMP/empty-catalogue.json"
case_run a-catalogue-with-no-rules 2 "names no rule" \
  --catalogue "$TMP/empty-catalogue.json"

seed a-catalogue-that-is-not-there 'true'
case_run a-catalogue-that-is-not-there 2 "cannot read the catalogue" \
  --catalogue "$TMP/no-such-catalogue.json"

echo "gate-portable-shell: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
exit 0
