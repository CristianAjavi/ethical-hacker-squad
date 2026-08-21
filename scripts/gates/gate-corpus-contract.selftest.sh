#!/usr/bin/env bash
# Self-test for gate-corpus-contract.sh.
#
# A gate nobody has seen fail is not a proved gate. Every case here copies the
# repository to a throwaway directory, breaks exactly ONE thing the gate claims
# to watch, and asserts both the exit code and the reason:
#
#   1 = the gate MEASURED a defect
#   2 = the gate COULD NOT MEASURE (its inputs are gone)
#   0 = measured and conforming
#
# The first case is the control: the untouched repository must pass. Without it,
# a battery that stopped measuring would look like a battery that found nothing.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-corpus-contract.sh"

if [ -n "${EHS_REPO_ROOT:-}" ]; then
  SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then
  :
else
  SRC="$(cd "$HERE/../.." && pwd)"
fi

command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-corpus-contract-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
K="skills/ethical-hacker-squad/references/knowledge"

# case <name> <expected rc> <expected substring> <python mutation>
case_run() {
  local name="$1" want="$2" needle="$3" mutation="$4"
  local work="$TMP/$name"
  rm -rf "$work"; mkdir -p "$work"
  (cd "$SRC" && tar --exclude .git --exclude __pycache__ -cf - .) | (cd "$work" && tar -xf -)
  if [ -n "$mutation" ]; then
    if ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
      printf 'HARNESS  %-34s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
    fi
  fi
  local out rc
  out="$(EHS_REPO_ROOT="$work" bash "$GATE" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf 'ok       %-34s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-34s rc=%s (wanted %s%s)\n' "$name" "$rc" "$want" \
      "$([ -n "$needle" ] && printf ' and %s' "$needle")"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -6
    fail=$((fail+1))
  fi
}

echo "=== self-test: gate-corpus-contract.sh (source: $SRC) ==="

case_run control-untouched-repo 0 "every declared number" ""

case_run numbering-hole 1 "not contiguous" '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'/mobile.md"
p.write_text(p.read_text().replace("### MOB-07","### MOB-77",1))'

case_run declared-lines-drift 1 "corpus lines" '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"README.md"
p.write_text(re.sub(r"[\d,]+ lines of corpus","9,999 lines of corpus",p.read_text(),count=1))'

case_run declared-procedures-drift 1 "procedures; measured" '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"skills/ethical-hacker-squad/references/knowledge/README.md"
p.write_text(re.sub(r"\d+ numbered procedures","999 numbered procedures",p.read_text(),count=1))'

case_run declared-range-drift 1 "the highest that exists" '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"skills/ethical-hacker-squad/references/team.md"
p.write_text(p.read_text().replace("`AI-01`..`AI-28`","`AI-01`..`AI-40`",1))'

case_run pack-cost-header-drift 1 "header declares" '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'/web-api.md"
p.write_text(re.sub(r"\*\*Cost:\*\* ~\d+ lines","**Cost:** ~50 lines",p.read_text(),count=1))'

case_run file-in-no-pack 1 "no pack declares it" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'/orphan.md").write_text("# Orphan\n")'

case_run map-missing-a-file 1 "loading map does not list it" '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'/README.md"
lines=[l for l in p.read_text().splitlines() if not l.startswith("| `mobile-ios.md`")]
p.write_text("\n".join(lines)+"\n")'

case_run fabricated-identifier 1 "matches no known identifier family" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'/mobile.md"
p.write_text(p.read_text().replace("**Traceability**: `","**Traceability**: `OWASP-MOBILE-TOP-99` · `",1))'

case_run identifier-as-prose 1 "outside backticks" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'/privacy-abuse.md"
p.write_text(p.read_text().replace("`ASVS 5.0 V14`","ASVS 5.0 V14",1))'

case_run agent-absent-from-roster 1 "the roster does not list it" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"agents/ehs-ghost.md").write_text(
  "---\nname: ehs-ghost\ndescription: Ghost.\nmodel: inherit\ntools: Read\n---\n\nGhost.\n")'

case_run roster-points-at-nothing 1 "which is not a pack file" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"skills/ethical-hacker-squad/references/team.md"
p.write_text(p.read_text().replace("`knowledge/mobile-ios.md`","`knowledge/mobile-ios-old.md`",1))'

case_run routing-to-missing-section 1 "no such section" '
import os,re,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"skills/ethical-hacker-squad/references/coverage.md"
p.write_text(re.sub(r"`mobile\.md` §0-§6","`mobile.md` §0-§66",p.read_text(),count=1))'

case_run procedure-loses-a-field 1 "missing mandatory field" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'/web-api.md"
p.write_text(p.read_text().replace("**What rules it out (false positive)**","**Notes**",1))'

case_run traceability-without-an-identifier 1 "names no standard identifier" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'/web-api.md"
t=p.read_text()
i=t.index("**Traceability**"); j=t.index(chr(10),i)
p.write_text(t[:i]+"**Traceability**: standard appsec knowledge"+t[j:])'

case_run corpus-gone 2 "" '
import os,shutil,pathlib
shutil.rmtree(pathlib.Path(os.environ["EHS_WORK"])/"'"$K"'")'

case_run packs-json-unreadable 2 "" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"scripts/meter/packs.json").write_text("{ not json")'

echo
echo "Summary: $pass ok, $fail failures"
if [ "$fail" -gt 0 ]; then
  echo "Result: FAILED. A case did not behave as the doctrine demands."
  exit 1
fi
echo "Result: OK. The gate fails when it must fail, stays quiet on the untouched"
echo "        corpus, and distinguishes \"could not measure\" from \"nothing to report\"."
exit 0
