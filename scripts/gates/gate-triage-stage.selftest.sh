#!/usr/bin/env bash
# Self-test for gate-triage-stage.sh.
#
# Each case breaks exactly ONE thing on a throwaway copy of the inputs and
# asserts both the exit code and the reason. Three things make it a bank of
# mutants rather than a list of assertions:
#
#   - the harness refuses a mutation that changed nothing, so a case cannot pass
#     by mutating a file the gate never reads;
#   - a mutation that touches cases.json RE-SEALS the key, so every mutant tests
#     the check it is named for instead of collapsing into the seal check;
#   - two cases mutate the inputs in ways that must NOT fire. A battery where
#     every case goes red is a battery that cannot tell a control from a rule
#     that fails on everything.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-triage-stage.sh"
. "$HERE/lib/selftest-root.sh" 2>/dev/null || {
  echo "UNMEASURABLE the root guard is missing at $HERE/lib/selftest-root.sh"; exit 2; }
SRC="$(ehs_selftest_root --here "$HERE")" || exit 2

command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-tstage-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# Only what the core reads. Copying the whole tree would work and would make
# every case slower for nothing.
INPUTS="scripts/gates/data/triage-stage.json
scripts/gates/gate-bench-integrity.sh
skills/ethical-hacker-squad/references/triage.md
skills/ethical-hacker-squad/references/vocabulary.md
bench/stages/triage"

# Helpers every mutation gets. Note for anyone adding a case: the mutation runs
# inside single quotes in this file, so it may not contain an apostrophe.
PRE='
import os, json, pathlib, hashlib, re
W = pathlib.Path(os.environ["EHS_WORK"])
CP = W / "bench/stages/triage/cases.json"
KP = W / "bench/stages/triage/keys/triage-key.json"
TP = W / "skills/ethical-hacker-squad/references/triage.md"
def lc(): return json.loads(CP.read_text())
def lk(): return json.loads(KP.read_text())
def sk(k): KP.write_text(json.dumps(k, indent=1, ensure_ascii=False) + "\n")
def sc(c, reseal=True):
    t = json.dumps(c, indent=1, ensure_ascii=False) + "\n"
    CP.write_text(t)
    if reseal:
        k = lk()
        k["seals"]["cases.json"] = "sha256:" + hashlib.sha256(t.encode("utf-8")).hexdigest()
        sk(k)
def krow(k, cid): return [a for a in k["answers"] if a["case"] == cid][0]
def ccase(c, cid): return [x for x in c["cases"] if x["case"] == cid][0]
'

case_run() {
  local name="$1" want="$2" needle="$3" mutation="$4" work="$TMP/$1"
  mkdir -p "$work"
  local p
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    mkdir -p "$work/$(dirname "$p")"
    cp -R "$SRC/$p" "$work/$p"
  done <<< "$INPUTS"

  local before after
  before="$(cd "$work" && find . -type f -exec shasum {} + | LC_ALL=C sort | shasum)"
  if [ -n "$mutation" ] && ! EHS_WORK="$work" python3 -c "$PRE$mutation" >/dev/null 2>&1; then
    printf 'HARNESS  %-42s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
  fi
  after="$(cd "$work" && find . -type f -exec shasum {} + | LC_ALL=C sort | shasum)"
  if [ -n "$mutation" ] && [ "$before" = "$after" ]; then
    printf 'HARNESS  %-42s the mutation was a no-op: this case proves nothing\n' "$name"
    fail=$((fail+1)); return
  fi

  local out rc
  out="$(EHS_REPO_ROOT="$work" bash "$GATE" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf 'ok       %-42s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-42s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -6; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-triage-stage.sh (source: $SRC) ==="

# --- the control ----------------------------------------------------------
case_run control-untouched-inputs 0 "no case carries its own answer" ""

# --- the heart of it: the key may not disagree with the table --------------
case_run consequence-contradicts-the-table 1 "TS-11: the key declares the consequence" '
k = lk(); krow(k, "TS-11")["consequence"] = "ruled-out"; sk(k)'

case_run holds-override-flipped-to-default 1 "TS-15: the key declares the consequence" '
k = lk(); krow(k, "TS-15")["consequence"] = "ruled-out"; sk(k)'

case_run holds-default-flipped-to-override 1 "TS-12: the key declares the consequence" '
k = lk(); krow(k, "TS-12")["consequence"] = "informational"; sk(k)'

# --- the key must still describe THIS cases.json ---------------------------
case_run cases-edited-and-key-not-resealed 1 "the cases were edited and the key was not" '
c = lc(); ccase(c, "TS-01")["finding"]["title"] = "Something else entirely"; sc(c, reseal=False)'

# --- the leak, family one: tokens the key declares -------------------------
case_run rule-id-inside-the-statement 1 "contains the rule id FP-08" '
c = lc(); x = ccase(c, "TS-11")
x["exculpation_offered"] += " (reviewer noted this is an FP-08 situation)"; sc(c)'

case_run answer-token-inside-the-statement 1 "contains the answer token UNKNOWN" '
c = lc(); x = ccase(c, "TS-06")
x["finding"]["detail"] += " Triage note: the state of the flag is UNKNOWN to us."; sc(c)'

case_run underscored-token-inside-the-statement 1 "contains the answer token NOT_APPLICABLE" '
c = lc(); x = ccase(c, "TS-10")
x["exculpation_offered"] += " The reviewer marked it not_applicable."; sc(c)'

case_run consequence-term-inside-the-statement 1 "its own key declares" '
c = lc(); x = ccase(c, "TS-04")
x["finding"]["detail"] += " At best this can be recorded as probable."; sc(c)'

case_run consequence-term-inside-an-artifact 1 "its own key declares" '
c = lc(); x = ccase(c, "TS-15")
x["artifact"][0]["content"] += "\n// severity here is informational at most\n"; sc(c)'

# --- the leak, family two: the remedy stated in the question ---------------
# Verbatim in shape from the neighbouring product`s patch dataset, which is
# where this half of the gate comes from.
case_run remedy-prescribed-in-the-statement 1 "prescribes the remedy" '
c = lc(); x = ccase(c, "TS-01")
x["finding"]["detail"] += " Fix by using a parameterized query with a bound parameter."; sc(c)'

case_run remedy-prescribed-inside-an-artifact 1 "prescribes the remedy" '
c = lc(); x = ccase(c, "TS-03")
x["artifact"][0]["content"] += "\n# TODO: should use a tensor loader\n"; sc(c)'

# --- the leak, family three: the vocabulary borrowed from its owner --------
# The defect commit b8bce3d fixed, in a directory that gate does not read.
case_run case-labels-its-own-answer 1 "labels its own answer" '
c = lc(); x = ccase(c, "TS-03")
x["artifact"][0]["content"] += "\n# Planted: the pickle branch is the one that matters\n"; sc(c)'

# One rule, one place. If its owner changes the literal, this gate stops
# enforcing a rule that is no longer theirs.
case_run borrowed-vocabulary-drifted 2 "have drifted" '
p = W / "scripts/gates/gate-bench-integrity.sh"
p.write_text(p.read_text().replace(chr(92) + "bplanted" + chr(92) + "b|", ""))'

# --- coverage: a rule or a direction the eval stops asking -----------------
case_run rule-nobody-asks-any-more 1 "no case asks FP-06" '
c = lc(); k = lk()
c["cases"] = [x for x in c["cases"] if x["case"] != "TS-09"]
k["answers"] = [a for a in k["answers"] if a["case"] != "TS-09"]
sk(k); sc(c)'

# The mutant that matters most: the row stays LEGAL, only the direction is
# lost. Nothing but the coverage rule can catch this one.
case_run over-affirm-direction-quietly-dropped 1 "the direction a model over-affirms" '
k = lk(); r = krow(k, "TS-11"); r["answer"] = "DOES_NOT_HOLD"; r["consequence"] = "survives"; sk(k)'

case_run answer-vocabulary-not-exercised 1 "an answer the eval never reaches" '
k = lk(); r = krow(k, "TS-10"); r["answer"] = "DOES_NOT_HOLD"; r["consequence"] = "survives"; sk(k)'

# --- the reason behind a HOLDS or an UNKNOWN ------------------------------
case_run reason-names-no-artifact 1 "must name the artifact it rests on" '
k = lk(); krow(k, "TS-12")["why"] = "It looked fine to me on the day."; sk(k)'

case_run reason-missing-entirely 1 "an answer with no reason is a guess" '
k = lk(); krow(k, "TS-08")["why"] = ""; sk(k)'

# --- rows that are not rows -----------------------------------------------
case_run answer-outside-the-vocabulary 1 "outside the closed vocabulary" '
k = lk(); krow(k, "TS-02")["answer"] = "PROBABLY_FINE"; sk(k)'

case_run rule-that-does-not-exist 1 "does not declare" '
k = lk(); krow(k, "TS-02")["rule"] = "FP-42"; sk(k)'

case_run case-with-no-key-row 1 "cases with no key row" '
k = lk(); k["answers"] = [a for a in k["answers"] if a["case"] != "TS-01"]; sk(k)'

# --- could not measure: never a pass --------------------------------------
case_run cases-will-not-parse 2 "does not parse" '
CP.write_text("{not json")'

case_run key-will-not-parse 2 "does not parse" '
KP.write_text("{nope")'

case_run key-seals-nothing 2 "seals nothing" '
k = lk(); k["seals"] = {}; sk(k)'

case_run presented-fields-not-declared 2 "which fields reach the reader" '
c = lc(); del c["presented_fields"]; sc(c)'

# The gate refuses to guess when the basis of its derivation moved.
case_run consequences-table-rewritten 2 "is not the one the file states" '
t = TP.read_text()
TP.write_text(t.replace("`probable` is its ceiling", "and that is the end of it"))'

case_run two-rules-claim-the-same-override 2 "an ambiguity, not a derivation" '
t = TP.read_text()
TP.write_text(t.replace("a placeholder such as", "the finding **moves**, or a placeholder such as"))'

case_run rules-region-removed 2 "no <!-- triage:rules --> region" '
t = TP.read_text()
TP.write_text(t.replace("<!-- triage:rules -->", "").replace("<!-- /triage:rules -->", ""))'

# --- and the two that must NOT fire ---------------------------------------
# Without these the battery cannot tell a control from a rule that fails on
# everything, and the two decisions below would be accidents rather than
# choices.
case_run lowercase-unknown-in-prose-is-not-a-leak 0 "no case carries its own answer" '
c = lc(); x = ccase(c, "TS-04")
x["finding"]["detail"] += " The resolved version is unknown to the reviewer."; sc(c)'

case_run the-bare-word-fix-is-not-a-remedy 0 "no case carries its own answer" '
c = lc(); x = ccase(c, "TS-07")
x["finding"]["detail"] += " A similar packaging bug was fixed in the previous release."; sc(c)'

echo "--- $pass passed, $fail failed ---"
[ "$fail" -eq 0 ] || exit 1
exit 0
