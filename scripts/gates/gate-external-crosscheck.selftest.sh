#!/usr/bin/env bash
# Self-test for gate-external-crosscheck.sh.
#
# A gate that pins a published number is worth exactly what its instrument is
# worth, and nobody has seen this instrument fail until this file runs. Every
# case below breaks, ON A THROWAWAY COPY of the tree, exactly one thing the gate
# claims to watch, and asserts BOTH the exit code the doctrine demands AND a
# phrase from the rule that owns it. The phrase is not decoration: a mutant that
# turns the gate red for some other reason has not proved the rule that was
# supposed to catch it, and this repository has shipped a gate whose mutants
# were all killed by the wrong case before.
#
#   1 = the gate MEASURED a defect    (a number moved, a file was edited,
#                                      provenance lost a field, the adapter
#                                      went blind)
#   2 = the gate COULD NOT MEASURE    (its adapter, its records or its scorer
#                                      are missing or unreadable)
#   0 = measured and conforming       (controls, including a false-positive one)
#
# P1 is not decoration either: it writes a note full of the shapes the
# machine-path rule hunts - a quoted `/tmp/report.csv`, a `~/.cache` - as
# ordinary prose, because a rule that fires on a legitimate file gets switched
# off within a week.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = could not measure.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE_NAME=gate-external-crosscheck.sh

if [ -n "${EHS_REPO_ROOT:-}" ]; then
  SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then
  :
else
  SRC="$(cd "$HERE/../.." && pwd)"
fi

REC=bench/external/ultrasec-2026-09-11
ADAPTER=scripts/bench/adapt-external.py

cannot() { printf 'COULD NOT MEASURE: %s\n' "$*" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || cannot "python3 is missing"
command -v awk >/dev/null 2>&1 || cannot "awk is missing"
[ -r "$HERE/$GATE_NAME" ] || cannot "$HERE/$GATE_NAME is not readable"
for f in "$ADAPTER" scripts/bench/score.py scripts/gates/lib/external_crosscheck.py \
         scripts/gates/lib/common.sh bench/ground-truth.json "$REC/provenance.json" \
         "$REC/scorecard.json"; do
  [ -r "$SRC/$f" ] || cannot "$f is not readable under $SRC"
done

T="$(mktemp -d)" || cannot "no temporary directory"
trap 'rm -rf "$T"' EXIT

# One pristine copy; every case is a copy of THAT copy, so a mutation can never
# leak into the next case or back into the repository. bench/runs is left out on
# purpose: eight megabytes this gate never reads, copied twenty times.
mkdir -p "$T/pristine/scripts/gates/lib" "$T/pristine/scripts/bench" "$T/pristine/bench"
cp -R "$SRC/bench/cases" "$SRC/bench/external" "$T/pristine/bench/" || cannot "bench could not be copied"
cp "$SRC/bench/ground-truth.json" "$T/pristine/bench/" || cannot "the answer key could not be copied"
cp -R "$SRC/scripts/bench/." "$T/pristine/scripts/bench/" || cannot "scripts/bench could not be copied"
cp "$SRC/scripts/gates/lib/common.sh" "$SRC/scripts/gates/lib/external_crosscheck.py" \
   "$T/pristine/scripts/gates/lib/" || cannot "the gate core could not be copied"
cp "$HERE/$GATE_NAME" "$T/pristine/scripts/gates/" || cannot "the gate could not be copied"

pass=0; fail=0

prep() {  # prep <case> -> echoes the case root
  local d="$T/$1"
  mkdir -p "$d"
  cp -R "$T/pristine/." "$d/"
  printf '%s' "$d"
}

check() { # check <case> <expected rc> <description> [phrase the output must carry]
  local d="$T/$1" want="$2" desc="$3" phrase="${4:-}" rc=0 out
  out=$(bash "$d/scripts/gates/$GATE_NAME" --root "$d" 2>&1) || rc=$?
  if [ "$rc" -ne "$want" ]; then
    printf '  FAIL  %-4s %-58s rc=%s (expected %s)\n' "$1" "$desc" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/        | /' | head -20
    fail=$((fail+1)); return
  fi
  if [ -n "$phrase" ] && ! printf '%s' "$out" | grep -qF -- "$phrase"; then
    # `grep -qF` on a here-string, never a substring test on a variable that may
    # be empty: "I did not see it" and "I could not look" must not read alike.
    printf '  FAIL  %-4s %-58s rc=%s but nothing said %s\n' "$1" "$desc" "$rc" "$phrase"
    printf '%s\n' "$out" | sed 's/^/        | /' | head -20
    fail=$((fail+1)); return
  fi
  printf '  ok    %-4s %-58s rc=%s\n' "$1" "$desc" "$rc"
  pass=$((pass+1))
}

# pyedit <file> <python statements; `d` is the parsed JSON document>
pyedit() {
  PYEDIT_FILE="$1" PYEDIT_CODE="$2" python3 - <<'PY'
import json, os
p = os.environ["PYEDIT_FILE"]
d = json.loads(open(p, encoding="utf-8").read())
exec(os.environ["PYEDIT_CODE"])
open(p, "w", encoding="utf-8").write(json.dumps(d, indent=2) + "\n")
PY
}

# insert_after <file> <marker substring> <line to insert>
insert_after() {
  awk -v marker="$2" -v line="$3" '{ print } index($0, marker) { print line }' "$1" > "$1.t" \
    && mv "$1.t" "$1"
}

printf 'Self-test for %s\n' "$GATE_NAME"
printf '==========================================\n'
printf 'tree under test: %s\n\n' "$SRC"

# --- rc=0: opening control -------------------------------------------------
d=$(prep C0); check C0 0 "CONTROL: untouched copy"

# --- rc=1: the committed evidence moved ------------------------------------
d=$(prep M1); pyedit "$d/$REC/raw/recall/cli-packer.findings.json" 'd[0]["title"] = "tampered"'
              check M1 1 "raw output edited (counts unchanged)" "has changed since it was recorded"

d=$(prep M2); pyedit "$d/$REC/scorecard.json" 'd["arms"]["recall"]["unlabelled"] = 12'
              check M2 1 "a recorded number changed" "recorded unlabelled=12"

d=$(prep M10); pyedit "$d/bench/ground-truth.json" \
                 'item = [x for x in d["planted"] if x["id"] == "P-01"][0]; item["lines"] = [900, 901]'
               check M10 1 "the answer key moved under the record" "recorded detected_ids="

d=$(prep M8); rm -f "$d/$REC/raw/recall/cli-packer.findings.json"
              check M8 1 "a committed raw file deleted" "listed but absent"

d=$(prep M9); printf '[]\n' > "$d/$REC/raw/recall/zzz-unlisted.findings.json"
              check M9 1 "a raw file added that provenance does not list" "present but unlisted"

# --- rc=1: provenance stops being provenance --------------------------------
d=$(prep M3); pyedit "$d/$REC/provenance.json" 'del d["version_as_the_tool_reports_it"]'
              check M3 1 "a provenance field deleted" "missing \`version_as_the_tool_reports_it\`"

d=$(prep M7); pyedit "$d/$REC/provenance.json" 'd["pinned_commit"] = "v1.48.4"'
              check M7 1 "the pin replaced by a tag that can move" "is not a 40-hex sha"

d=$(prep M11); pyedit "$d/$REC/provenance.json" 'd["date"] = "2026-09-12"'
               check M11 1 "provenance date and directory name disagree" "the directory is named"

d=$(prep M12); pyedit "$d/$REC/provenance.json" 'd["scan_roots"][0] = "bench/cases/nowhere"'
               check M12 1 "a scan root that does not exist" "is not a directory in this checkout"

# M13 is M12's twin and it is here because the first version of this gate got it
# wrong. M12 invents a root with no raw file beside it, so the arms are skipped
# before the adapter is ever started. M13 is what a person actually does: renames
# a case directory. The record still lists the old root AND still has its raw
# file, so the gate handed the adapter a root it was right to refuse, the
# adapter's 2 travelled up, and a defect this gate had already measured was
# published as "could not measure". A plain directory rename is the commonest way
# a record like this goes stale; 2 is the one answer it must not get.
d=$(prep M13); mv "$d/bench/cases/cli-packer" "$d/bench/cases/cli-packer-cli"
               check M13 1 "a case directory renamed, its raw output still present" \
                 "is not a directory in this checkout"

# --- rc=1: the artifact starts naming the machine that made it --------------
d=$(prep M5); pyedit "$d/$REC/scorecard.json" \
                'd["$note"] = "produced at /Users/someone/work/ethical-hacker-squad"'
              check M5 1 "an absolute machine path planted in an artifact" "an absolute path"

# --- rc=1: the ADAPTER goes blind (the gate must notice, not inherit it) ----
d=$(prep M4); insert_after "$d/$ADAPTER" 'Name the format, or refuse' '    return ULTRASEC'
              check M4 1 "the adapter guesses instead of refusing an unknown shape" "the contract is 2"

d=$(prep M17); insert_after "$d/$ADAPTER" 'def records_sarif(doc):' '    return'
               check M17 1 "the adapter reads a one-result SARIF as zero" \
                 "cannot be trusted when it produces a zero"

# M18 is the silent drop in its purest form: the record is still read and still
# counted in, and the one thing that disappears is the NOTE that it could not be
# placed. Every number the adapter prints stays consistent with every other, and
# the committed records do not move at all, because none of their findings is
# unplaceable. Only a probe that reads the TEXT catches it.
d=$(prep M18); insert_after "$d/$ADAPTER" 'if placed is None:' '                continue'
               check M18 1 "the adapter drops an unplaceable finding without naming it" \
                 "did not name the finding it could not place"

d=$(prep M6); insert_after "$d/$ADAPTER" 'items = doc if isinstance(doc, list)' '    items = items[1:]'
              check M6 1 "the adapter drops one finding per file, quietly" \
                "the adapter now reports"

# M6 above is caught because the adapter disagrees with a record made when it
# still counted correctly. M6b is the case that record cannot catch: the numbers
# were REGENERATED by the dropping adapter, so adapter and record agree with each
# other and only a count this gate makes ITSELF, from the raw files, disagrees.
# That is what the independent counter is for, and this is the only case that
# proves it. raw_findings_in and emitted are derived here, never typed, so the
# mutant does not go stale the day the raw output changes.
d=$(prep M6b); insert_after "$d/$ADAPTER" 'items = doc if isinstance(doc, list)' '    items = items[1:]'
               pyedit "$d/$REC/scorecard.json" '
import glob, json as J
base = os.path.dirname(os.environ["PYEDIT_FILE"])
for arm in d["arms"]:
    n = 0
    for f in sorted(glob.glob(os.path.join(base, "raw", arm, "*.findings.json"))):
        n += max(0, len(J.loads(open(f, encoding="utf-8").read())) - 1)
    d["arms"][arm]["raw_findings_in"] = n
    d["arms"][arm]["emitted"] = n
'
               check M6b 1 "the dropped count baked into the record as well" \
                 "this gate counts"

# --- rc=2: the gate cannot measure (never a pass) ---------------------------
d=$(prep U1); rm -f "$d/$ADAPTER"
              check U1 2 "the adapter is gone" "there is nothing to re-run"

d=$(prep U2); printf 'not json at all\n' > "$d/$REC/scorecard.json"
              check U2 2 "scorecard.json will not parse" "is not JSON"

d=$(prep U3); rm -rf "$d/$REC"
              check U3 2 "no external run recorded at all" "holds no recorded external-tool run"

d=$(prep U4); rm -f "$d/scripts/gates/lib/external_crosscheck.py"
              check U4 2 "the gate core is gone" "is missing"

d=$(prep U5); rm -f "$d/scripts/bench/score.py"
              check U5 2 "the scorer is gone" "there is nothing to re-run"

# --- rc=0: false-positive control and closing control -----------------------
d=$(prep P1); printf 'The case plants a predictable temporary file at /tmp/report.csv, and the\ntool caches its grammars under ~/.cache. Neither is a path of this machine.\n' \
                > "$d/$REC/NOTES.md"
              check P1 0 "FALSE-POSITIVE CONTROL: legitimate paths written as prose"

d=$(prep C1); check C1 0 "FINAL CONTROL: untouched copy again"

# The spelling of the line below matters and is not a preference.
# gate-case-counts.sh reads a battery's size off it to check the figure the
# documents quote, and it recognises three whole-line families;
# `Summary: N ok, M failure(s)` is one of them and is what twenty of this
# tree's twenty-one batteries print. The third field this line used to carry,
# `%d not measured`, broke that match, so the only way to MARK the citations
# that quote this battery would have been to pin them at "could not measure"
# for ever - and an unmarked citation is a figure nothing runs. The field was
# also dead: `unmeasured` was set to 0 at the top of this file and incremented
# nowhere, so the line advertised a distinction this battery cannot make. The
# distinction is real and it is asserted where it belongs, on the GATE, by the
# five rc=2 cases U1-U5, which are counted here as the passes they are.
printf '\nSummary: %d ok, %d failure(s)\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
printf 'Result: OK. The gate fails when a recorded number, a checksum, a provenance\n'
printf '        field or the adapter itself moves, stays quiet on a legitimate file,\n'
printf '        and tells "could not measure" apart from "nothing to report".\n'
exit 0
