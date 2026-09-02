#!/usr/bin/env bash
# Self-test for gate-severity-calibration.sh. Each case breaks exactly one thing
# on a throwaway copy and asserts the exit code AND the reason. The needle has to
# name something only that fixture can produce: a correct rc for the wrong reason
# has cost this repository three times, and a battery that stops measuring looks
# exactly like a clean run.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-severity-calibration.sh"
if [ -n "${EHS_REPO_ROOT:-}" ]; then SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then :
else SRC="$(cd "$HERE/../.." && pwd)"; fi

command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-sevcal-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
R="skills/ethical-hacker-squad/references/triage.md"
V="skills/ethical-hacker-squad/references/vocabulary.md"
G="scripts/gates/fixtures/findings"

case_run() {
  local name="$1" want="$2" needle="$3" mutation="$4" work="$TMP/$1"
  rm -rf "$work"; mkdir -p "$work"
  (cd "$SRC" && tar --exclude .git --exclude __pycache__ -cf - .) | (cd "$work" && tar -xf -)
  if [ -n "$mutation" ] && ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
    printf 'HARNESS  %-42s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
  fi
  local out rc
  out="$(EHS_REPO_ROOT="$work" bash "$GATE" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -qF -- "$needle"; }; then
    printf 'ok       %-42s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-42s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -6; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-severity-calibration.sh (source: $SRC) ==="

# The control. Without it a battery that stopped measuring reads as a clean run.
case_run control-untouched-tree 0 "every ceiling is a term vocabulary.md declares" ""

# --- the ceilings ----------------------------------------------------------
case_run ceiling-raised-to-the-top-of-the-order 1 '`SEV-02` names the ceiling `critical`, the top of the order' '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'"
s=p.read_text()
i=s.index("| `SEV-02` |"); j=s.index("\n",i)
row=s[i:j].replace("| `high` |","| `critical` |",1)
assert "`critical`" in row
p.write_text(s[:i]+row+s[j:])'

case_run ceiling-that-is-not-a-severity-term 1 '`SEV-05` names the ceiling `severe`, which vocabulary.md does not declare' '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'"
s=p.read_text()
i=s.index("| `SEV-05` |"); j=s.index("\n",i)
row=s[i:j].replace("| `medium` |","| `severe` |",1)
assert "`severe`" in row
p.write_text(s[:i]+row+s[j:])'

# --- the catalogue's shape -------------------------------------------------
case_run caps-not-contiguous 1 'the caps region skips `SEV-05`' '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'"
s=p.read_text()
i=s.index("| `SEV-05` |"); j=s.index("\n",i)+1
p.write_text(s[:i]+s[j:])'

case_run a-cap-declared-twice 1 'the caps region declares `SEV-07` twice' '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'"
s=p.read_text()
i=s.index("| `SEV-07` |"); j=s.index("\n",i)+1
p.write_text(s[:j]+s[i:j]+s[j:])'

case_run a-tier-nobody-declared 1 '`SEV-01` declares the tier `sometimes`' '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'"
s=p.read_text()
i=s.index("| `SEV-01` |"); j=s.index("\n",i)
row=s[i:j].replace("| always |","| sometimes |",1)
assert "sometimes" in row
p.write_text(s[:i]+row+s[j:])'

case_run every-cap-turned-on-trigger 1 'no cap is declared `always`' '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'"
s=p.read_text()
a=s.index("<!-- severity:caps -->"); b=s.index("<!-- /severity:caps -->")
p.write_text(s[:a]+re.sub(r"\| always \|","| on trigger |",s[a:b])+s[b:])'

# --- the two counts that drift ---------------------------------------------
case_run the-title-count-drifted 1 'triage.md announces ten caps and declares nine' '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'"
s=p.read_text()
i=s.index("| `SEV-10` |"); j=s.index("\n",i)+1
p.write_text(s[:i]+s[j:])'

case_run the-vocabulary-range-drifted 1 'vocabulary.md points at `SEV-01`..`SEV-09` and triage.md declares `SEV-01`..`SEV-10`' '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$V"'"
s=p.read_text()
assert "`SEV-01`..`SEV-10`" in s
p.write_text(s.replace("`SEV-01`..`SEV-10`","`SEV-01`..`SEV-09`",1))'

# --- could not measure: the sources the gate reads from --------------------
case_run caps-region-gone 2 'has no <!-- severity:caps --> region to read' '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'"
s=p.read_text()
a=s.index("<!-- severity:caps -->"); b=s.index("<!-- /severity:caps -->")+len("<!-- /severity:caps -->")
p.write_text(s[:a]+s[b:])'

case_run caps-region-emptied 2 'declares a caps region with no rows in it' '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$R"'"
s=p.read_text()
a=s.index("<!-- severity:caps -->")+len("<!-- severity:caps -->")
b=s.index("<!-- /severity:caps -->")
p.write_text(s[:a]+"\n"+s[b:])'

case_run order-sentence-gone 2 'no longer states the order of the severity terms' '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$V"'"
s=p.read_text()
out=re.sub(r"^`critical`(\s*>\s*`[a-z]+`)+\..*$","(the order used to be stated here)",s,count=1,flags=re.M)
assert out!=s
p.write_text(out)'

case_run order-rewritten 2 'where this gate was built for critical > high > medium > low > informational' '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$V"'"
s=p.read_text()
out=re.sub(r"^`critical`\s*>\s*`high`\s*>\s*`medium`\s*>\s*`low`\s*>\s*`informational`",
           "`critical` > `high` > `low` > `medium` > `informational`",s,count=1,flags=re.M)
assert out!=s
p.write_text(out)'

# --- the two guards that can genuinely reach zero --------------------------
# Neither is "I checked nothing". Both are states someone can create, and both
# are the silent retirement of the control. The gate says 2, and 2 is not a pass.
case_run no-cap-comparison-was-performed 2 'not one ceiling was compared against a label in this run' '
import os,json,pathlib
for p in (pathlib.Path(os.environ["EHS_WORK"])/"'"$G"'").rglob("*.json"):
    d=json.loads(p.read_text())
    if not isinstance(d,dict): continue
    for f in d.get("findings") or []:
        for c in f.get("severity_calibration") or []:
            if c.get("answer") in ("HOLDS","UNKNOWN"):
                c["answer"]="NOT_APPLICABLE"
    p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+"\n")'

case_run no-critical-or-high-finding-anywhere 2 'so the requirement that buys those labels was not exercised' '
import os,json,pathlib
for p in (pathlib.Path(os.environ["EHS_WORK"])/"'"$G"'").rglob("*.json"):
    d=json.loads(p.read_text())
    if not isinstance(d,dict): continue
    for f in d.get("findings") or []:
        if f.get("severity") in ("critical","high"): f["severity"]="medium"
    p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+"\n")'

# --- shared infrastructure --------------------------------------------------
# This one cannot go through case_run: that helper runs the gate from the SOURCE
# tree against a copied ROOT, so deleting the copy's core leaves the real one in
# place and the gate passes. Written the obvious way it was a case that could
# never fail. Here the COPY's gate is the one invoked, which is the only way to
# ask what a deployment missing its core does.
core_missing() {
  local work="$TMP/core-missing"
  rm -rf "$work"; mkdir -p "$work"
  (cd "$SRC" && tar --exclude .git --exclude __pycache__ -cf - .) | (cd "$work" && tar -xf -)
  rm -f "$work/scripts/gates/lib/severity_calibration.py"
  local out rc
  out="$(EHS_REPO_ROOT="$work" bash "$work/scripts/gates/gate-severity-calibration.sh" 2>&1)"; rc=$?
  if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -qF -- "the measurement core is missing"; then
    printf 'ok       %-42s rc=%s\n' "core-missing" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-42s rc=%s (wanted 2)\n' "core-missing" "$rc"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -6; fail=$((fail+1))
  fi
}
core_missing

echo "--- $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
