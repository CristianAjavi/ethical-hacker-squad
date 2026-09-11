#!/usr/bin/env bash
# Tests scripts/gh/competitive-freshness.sh against a GitHub API double.
#
# The case that matters is `one-moved`. On 2026-08-24 two of the three pins in
# docs/competitive-baseline.json were already behind their repository's HEAD,
# both pushed that same day, and nothing in this repository said so. A check
# that cannot tell a moved subject from a still one is worth nothing.
#
# Added 2026-09-10, the acknowledgement cases. A check that goes red the day
# somebody else pushes, and that no reader can ever turn green, is the #83 shape
# - it shouts on every run, blocks nothing, and gets skipped. So the tool now
# reads `reviewed_head`/`reviewed_at` and distinguishes THREE things where it
# used to see one:
#
#   moved and unread            -> 1   nobody has looked
#   moved, read, ack current    -> 0   with the note saying so
#   moved PAST the ack          -> 1   the reading is spent
#
# Every one of those is asserted on its EXIT CODE and on the sentence it prints,
# because the sentence is the difference between the three and an rc alone would
# let two of them collapse into each other. The half-written acknowledgement is
# asserted too: a reviewed_head matching HEAD with no date is the one shape that
# could have become a false green, and it answers 2.
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

# The base fixture: no acknowledgement anywhere. Every verdict written before
# reviewed_head existed is measured against THIS file, unchanged, so the four
# original cases still say what they said.
cat > "$LAB/baseline.json" <<'JSON'
{ "measured_on": "2026-01-01",
  "products": [
    { "repo": "org/alpha", "pinned": "aaaaaaa", "comparable": true,  "rounds": [] },
    { "repo": "org/beta",  "pinned": "bbbbbbb", "comparable": true,  "rounds": [] },
    { "repo": "org/never", "pinned": null,      "comparable": false, "rounds": [] } ] }
JSON

# Same file with an acknowledgement on beta, written by hand. `ack` builds the
# variants from one place so a variant differs from the baseline in exactly the
# field it is named after, and nothing else.
ack() {  # <file> <reviewed_head json> <reviewed_at json>
  cat > "$LAB/$1" <<JSON
{ "measured_on": "2026-01-01",
  "products": [
    { "repo": "org/alpha", "pinned": "aaaaaaa", "comparable": true,  "rounds": [] },
    { "repo": "org/beta",  "pinned": "bbbbbbb", "comparable": true,  "rounds": [],
      "reviewed_head": $2, "reviewed_at": $3 },
    { "repo": "org/never", "pinned": null,      "comparable": false, "rounds": [] } ] }
JSON
}
ack ack-current.json  '"9999999"' '"2026-09-10"'   # reads the commit that is HEAD in mode `moved`
ack ack-spent.json    '"7777777"' '"2026-09-10"'   # read a commit the subject has since moved past
ack ack-nodate.json   '"9999999"' 'null'           # the shape that could become a false green
ack ack-nohead.json   'null'      '"2026-09-10"'   # a date acknowledging no commit
ack ack-badsha.json   '"looked"'  '"2026-09-10"'   # not a commit
ack ack-baddate.json  '"9999999"' '"yesterday"'    # not an ISO date

# An acknowledgement on a product that never moved must change nothing: alpha is
# still its own tip in every mode, so the tool must never reach the ack logic.
cat > "$LAB/ack-on-still.json" <<'JSON'
{ "measured_on": "2026-01-01",
  "products": [
    { "repo": "org/alpha", "pinned": "aaaaaaa", "comparable": true, "rounds": [],
      "reviewed_head": "5555555", "reviewed_at": "2026-09-10" },
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
# asking about something it also says it never measured. The breach is written to
# a FILE, not to stderr: the tool redirects every gh stderr to /dev/null, so the
# stderr version of this check could never be seen by the assertion that read it.
case "$path" in *org/never*)
  printf '%s\n' "$path" >> "${LAB_PROBE:-/dev/null}"
  echo "DOUBLE ERROR: queried a non-comparable product" >&2; exit 9 ;;
esac
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

res() {  # <label> <mode> <expected rc> [needle] [baseline file]
  local label="$1" mode="$2" want="$3" needle="${4:-}" base="${5:-baseline.json}" rc=0
  LAB_MODE="$mode" LAB_PROBE="$LAB/probe.txt" PATH="$LAB/bin:$PATH" \
    bash "$TOOL" --baseline "$LAB/$base" >"$LAB/out.txt" 2>&1 || rc=$?
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

echo "== the acknowledgement: three states where there used to be one"
# MUTANT 1. Moved and nobody has looked. Red, and the line must say WHY it is
# red - an rc 1 alone cannot be told apart from mutant 3 below, and the two ask
# for different work from whoever reads it.
res "moved, unread -> rc 1"                  moved   1 "nobody has recorded reading this move" baseline.json
# MUTANT 2. The same subject, same HEAD, with the commit recorded as read. Green
# WITH the note. This is the case the old tool could not reach: it compared the
# pin against the tip and had nowhere to put "somebody read it".
res "moved, read, ack current -> rc 0"       moved   0 "changes no cell of the comparison" ack-current.json
res "and the green names the day it was read" moved  0 "read on 2026-09-10"                ack-current.json
res "and it does not call itself a measure"  moved   0 "NOT a re-measurement"               ack-current.json
# MUTANT 3. The acknowledgement that half exists. A reviewed_head equal to HEAD
# with no date would print the note and pass; it answers 2 instead, which never
# approves.
res "ack with no reviewed_at -> rc 2"        moved   2 "acknowledgement with no date"       ack-nodate.json
res "ack with no reviewed_head -> rc 2"      moved   2 "acknowledges no commit"             ack-nohead.json
res "reviewed_head that is not a commit -> 2" moved  2 "not a commit"                       ack-badsha.json
res "reviewed_at that is not a date -> rc 2" moved   2 "not an ISO date"                    ack-baddate.json

echo "== the acknowledgement expires on its own"
# The property that makes this not an exemption: the ack names a commit, so the
# subject moving again spends it with nobody deciding to.
res "moved past the ack -> rc 1"             moved   1 "MOVED PAST THE ACK"                 ack-spent.json
res "and it says the reading is spent"       moved   1 "the reading is spent"               ack-spent.json
res "and it names both commits"              moved   1 "acknowledged 7777777 on 2026-09-10" ack-spent.json
# And it may not widen: an ack sitting on a product that never moved must not be
# read at all, in either direction.
res "ack on a still subject is inert -> rc 0" current 0 "still the tip"                     ack-on-still.json

# A non-comparable product is never queried, across EVERY run above and not just
# the last one: the double appends to $LAB/probe.txt the moment it is asked about
# org/never, so the file existing at all is the breach.
if [ -s "$LAB/probe.txt" ]; then
  printf '  FAIL  %-50s\n' "queried a product it says it never measured"
  sed 's/^/        | /' "$LAB/probe.txt" | head -5; fail=$((fail+1))
else
  printf '  PASS  %-50s\n' "never queries a non-comparable product"; pass=$((pass+1))
fi

# measured_on is the date of the last real MEASUREMENT. An acknowledgement is
# not one, and the tool must not write the file at all - the way a photograph
# gets a false date is a script stamping today on it because somebody looked.
before="$(cksum < "$LAB/ack-current.json")"
rc=0; LAB_MODE=moved PATH="$LAB/bin:$PATH" bash "$TOOL" --baseline "$LAB/ack-current.json" >"$LAB/out.txt" 2>&1 || rc=$?
after="$(cksum < "$LAB/ack-current.json")"
if [ "$before" = "$after" ] && grep -q "2026-01-01" "$LAB/out.txt"; then
  printf '  PASS  %-50s\n' "an ack never rewrites measured_on"; pass=$((pass+1))
else
  printf '  FAIL  %-50s (baseline changed, or measured_on vanished)\n' "an ack never rewrites measured_on"; fail=$((fail+1))
fi

rc=0; PATH="$LAB/bin:$PATH" bash "$TOOL" --baseline "$LAB/nope.json" >"$LAB/out.txt" 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then printf '  PASS  %-50s rc=2\n' "no baseline -> rc 2"; pass=$((pass+1))
else printf '  FAIL  %-50s rc=%s (expected 2)\n' "no baseline -> rc 2" "$rc"; fail=$((fail+1)); fi

echo
echo "  $pass PASS / $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
exit 0
