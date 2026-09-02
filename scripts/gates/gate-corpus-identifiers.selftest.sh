#!/usr/bin/env bash
# Self-test for gate-corpus-identifiers.sh. Each case breaks exactly one thing on
# a throwaway copy and asserts the exit code and the reason. The first case is
# the control: without it, a battery that stopped measuring looks like a clean
# run. The last group is the one that matters - a gate whose bounds drifted away
# from the document that declares them must say "I could not measure", never 0.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-corpus-identifiers.sh"
. "$HERE/lib/selftest-root.sh" 2>/dev/null || {
  echo "UNMEASURABLE the root guard is missing at $HERE/lib/selftest-root.sh"; exit 2; }
SRC="$(ehs_selftest_root --here "$HERE")" || exit 2

command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-ids-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
K="skills/ethical-hacker-squad/references/knowledge"
T="skills/ethical-hacker-squad/references/traceability.md"

case_run() {
  local name="$1" want="$2" needle="$3" mutation="$4" work="$TMP/$1"
  rm -rf "$work"; mkdir -p "$work"
  (cd "$SRC" && tar --exclude .git --exclude __pycache__ -cf - .) | (cd "$work" && tar -xf -)
  local before after
  before="$(cd "$work" && find skills -type f -exec shasum {} + | shasum)"
  if [ -n "$mutation" ] && ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
    printf 'HARNESS  %-38s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
  fi
  # A mutation that changed nothing produces a green that proves nothing, and it
  # looks exactly like a mutant the gate survived. One of these was a no-op for a
  # while - backticks inside a double-quoted expansion are command substitution,
  # and the shell ate the identifiers before python ever saw them.
  after="$(cd "$work" && find skills -type f -exec shasum {} + | shasum)"
  if [ -n "$mutation" ] && [ "$before" = "$after" ]; then
    printf 'HARNESS  %-38s the mutation was a no-op: nothing under skills/ changed\n' "$name"
    fail=$((fail+1)); return
  fi
  local out rc
  out="$(EHS_REPO_ROOT="$work" bash "$GATE" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf 'ok       %-38s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-38s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -6; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-corpus-identifiers.sh (source: $SRC) ==="

case_run control-untouched-repo 0 "every bounded identifier" ""

# --- A1: one id, two procedures
case_run duplicate-procedure-id 1 "is declared 2 times" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'/web-api.md"
p.write_text(p.read_text()+"\n### WEB-01 A second procedure wearing an id that is already taken\n\nBody.\n")'

# --- A2: a procedure lost in a merge
case_run hole-in-a-packs-numbering 1 "skips" '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'/privacy-abuse.md"
t=p.read_text()
i=t.index("### PRV-07"); j=t.index("### PRV-08")
p.write_text(t[:i]+t[j:])'

# --- A3: the fabrications that read as real
case_run invented-owasp-top-10-rank 1 "rank outside A01..A10" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'/web-api.md"
p.write_text(p.read_text().replace("A01:2025","A11:2025",1))'

case_run stale-owasp-top-10-year 1 "year is not the declared 2025" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'/web-api.md"
p.write_text(p.read_text().replace("A01:2025","A01:2021",1))'

case_run invented-asvs-chapter 1 "chapter outside V1..V17" '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'/web-api.md"
p.write_text(re.sub(r"ASVS 5\.0 V\d{1,2}","ASVS 5.0 V23",p.read_text(),count=1))'

case_run invented-cicd-sec-rank 1 "outside CICD-SEC-1..CICD-SEC-10" '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'/infra-cloud-cicd-platforms.md"
p.write_text(re.sub(r"CICD-SEC-\d{1,2}","CICD-SEC-14",p.read_text(),count=1))'

case_run invented-wstg-category 1 "not one of the 12 declared" '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'/web-api-clientside-logic.md"
p.write_text(re.sub(r"WSTG-[A-Z]{4}-","WSTG-XSSX-",p.read_text(),count=1))'

case_run masvs-level-on-a-control 1 "testing profiles, never a level" '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'/mobile.md"
p.write_text(re.sub(r"(MASVS-[A-Z]+-\d+)",r"\1-L2",p.read_text(),count=1))'

# --- the gate must not enforce a bound the document no longer states
case_run bound-drifted-from-the-document 2 "authority" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$T"'"
p.write_text(p.read_text().replace("chapters `V1`..`V17`","chapters `V1`..`V21`",1))'

case_run scheme-no-longer-declared 2 "no longer declares its scheme" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$T"'"
import re
t=p.read_text()
n=re.sub(r"(\| OWASP Top 10 CI/CD Security Risks \|[^\n]*?\|)[^|\n]*CICD-SEC[^|\n]*(\|)",r"\1 the ten CI/CD risks \2",t,count=1)
assert n!=t, "mutation was a no-op"
p.write_text(n)'

case_run standards-row-removed 2 "has no row for" '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$T"'"
t=p.read_text()
n=re.sub(r"^\| OWASP ASVS \|[^\n]*\n","",t,count=1,flags=re.M)
assert n!=t, "mutation was a no-op"
p.write_text(n)'

case_run traceability-unreadable 2 "could not be read" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"'"$T"'").unlink()'

# --- a battery that stops reaching the corpus must not report a pass
case_run corpus-shape-changed-no-headings 2 "checking nothing" '
import os,re,pathlib,glob
d=pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'"
for f in d.glob("*.md"):
    f.write_text(re.sub(r"^### ","#### ",f.read_text(),flags=re.M))
s=pathlib.Path(os.environ["EHS_WORK"])/"skills/ethical-hacker-squad/SKILL.md"
s.write_text(re.sub(r"^### ","#### ",s.read_text(),flags=re.M))
for f in (pathlib.Path(os.environ["EHS_WORK"])/"skills/ethical-hacker-squad/references").glob("*.md"):
    f.write_text(re.sub(r"^### ","#### ",f.read_text(),flags=re.M))'

echo "--- $pass passed, $fail failed ---"
[ "$fail" -eq 0 ] || exit 1
exit 0
