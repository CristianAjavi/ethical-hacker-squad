#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-handover-contract.sh — the deliverable exists; nothing said where it is.
#
# WHY IT EXISTS
#   Measured 2026-09-01. references/report.md specifies the report in 180 lines:
#   which sections are mandatory, which vocabulary each verdict must use, which
#   rule kills which claim. Every one of those lines is about the FILE. Not one
#   of them said the leader must tell the user where the file landed, or what it
#   said, once the run is over.
#
#   The symptom is not hypothetical. A user who had run this squad several times
#   reported he could not tell whether it had ever delivered anything - "nunca
#   entiendo como entrega los resultados o pareciera que nunca los da". The
#   artifact was being produced. The handover was not, because nothing in the
#   corpus asked for one.
#
#   Nothing in this repository could have caught that, and the reason is worth
#   recording: every existing control looks AT the deliverable
#   (gate-report-contract.sh, gate-findings-artifact.sh, both of which correctly
#   answer 2 when the deliverable is missing). Both are invoked with an explicit
#   --deliverable <path>. An engagement that produced NOTHING never reaches
#   either of them - a gate that fires only when someone remembered to point it
#   at a directory protects the case that already went right.
#
#   So this gate does not look at a deliverable at all. It looks at whether the
#   instruction to hand one over is WIRED: present in SKILL.md step 9, pointing
#   at a specification, and that specification complete.
#
# WHAT IT MEASURES
#   1. reachable    SKILL.md step 9 names report.md, findings.json, "absolute
#                   path" and references/report.md. Step 9 is the last thing the
#                   leader reads; a delivery rule anywhere else is a rule that
#                   fires after the decision it was meant to change.
#   2. specified    references/report.md carries a balanced handover section.
#   3. complete     every field in data/handover-contract.json has its marker in
#                   report.md, AND every marker in report.md is declared in the
#                   data file. Both directions: a field added to the prose and
#                   never declared is as invisible as a declaration whose marker
#                   was deleted.
#   4. not decor    each field carries a body of at least min_bytes. A marker
#                   over an empty line satisfies a naive check and instructs
#                   nobody.
#   5. the branch   the no-deliverable field still forbids printing counts. That
#                   prohibition IS the field; without it the section reads as
#                   "mention it", and the failure it exists to stop is a fluent
#                   summary of findings that live only in a chat transcript.
#   6. wired        every validator named in the data file exists, is executable,
#                   and answers 2 - not 0 - when pointed at a deliverable that is
#                   not there. The validators field tells the leader to print
#                   those exit codes; if a named script were missing or answered
#                   0 on nothing, the field would instruct them to print a number
#                   that does not mean what the block says it means.
#
# WHAT IT DOES NOT MEASURE, and will not pretend to
#   Whether the leader ACTUALLY prints the block at run time. No static check
#   can make a model obey an instruction; it can only prove the instruction is
#   there, is reachable, and is complete enough to obey. Whether it is obeyed is
#   a bench/ question, and this gate says so rather than implying otherwise.
#
#   It also does not check SKILL.md's size. That is gate-budget-ledger.sh's knob
#   (EHS_MAX_SKILL_MD_BYTES) and duplicating it here would give the repo two
#   places to change one number.
#
# EXIT CODES
#   0 measured and wired · 1 measured and broken · 2 could not measure
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"

ROOT="$(gate_root)"
GATES_DIR="$HERE"
DATA="$HERE/data/handover-contract.json"

ONLY_SELFTEST=0
[ "${1:-}" = "--self-test" ] && ONLY_SELFTEST=1

# measure <skill_md> <report_md> <gates_dir> <data_json>
# emits "rc|message" lines on stdout
measure() {
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import json, os, pathlib, re, subprocess, sys, tempfile

skill_md, report_md, gates_dir, data_json = (pathlib.Path(a) for a in sys.argv[1:5])

def out(rc, msg): print(f"{rc}|{msg}")

try:
    D = json.loads(data_json.read_text(encoding="utf-8"))
except Exception as e:
    out(2, f"{data_json.name} is missing or unusable: {e}")
    sys.exit(0)

for f in (skill_md, report_md):
    if not f.is_file():
        out(2, f"{f} is missing or unusable: I cannot certify a contract I cannot read")
        sys.exit(0)

skill = skill_md.read_text(encoding="utf-8")
report = report_md.read_text(encoding="utf-8")

# --- 1. reachable: step 9 of SKILL.md ------------------------------------
m = re.search(r"(?ms)^### 9\..*?(?=^## |\Z)", skill)
if not m:
    out(1, "SKILL.md has no '### 9.' step: the delivery instruction has no home")
    step9 = ""
else:
    step9 = m.group(0)
    out(0, f"step 9 found in SKILL.md ({len(step9.encode())} B)")

if step9:
    for item in D.get("step9_must_name", []):
        n = item["needle"]
        if n in step9:
            out(0, f"step 9 names '{n}'")
        else:
            out(1, f"step 9 does not name '{n}' - {item['why']}")

# --- 2. specified: the handover section exists and is balanced -----------
opens = re.findall(r"<!--\s*report:section id=handover\b[^>]*-->", report)
if len(opens) != 1:
    out(1, f"references/report.md declares the handover section {len(opens)} time(s), expected exactly 1")
    sys.exit(0)
start = report.index(opens[0])
close = report.find("<!-- /report:section -->", start)
if close < 0:
    out(1, "the handover section is opened and never closed: the marker pair is the gate's input")
    sys.exit(0)
block = report[start:close]
out(0, f"handover section present and closed ({len(block.encode())} B)")

# --- 3./4. complete, and not decoration ----------------------------------
FIELD_RE = re.compile(r"<!--\s*handover:field id=([a-z0-9-]+)\s*-->")
found = {}
hits = list(FIELD_RE.finditer(block))
for i, h in enumerate(hits):
    body_end = hits[i + 1].start() if i + 1 < len(hits) else len(block)
    found[h.group(1)] = block[h.end():body_end].strip()

declared = {f["id"]: f for f in D.get("fields", [])}

for fid, spec in declared.items():
    if fid not in found:
        out(1, f"field '{fid}' is declared in handover-contract.json and has no marker in report.md - {spec['why']}")
        continue
    n = len(found[fid].encode())
    if n < spec.get("min_bytes", 1):
        out(1, f"field '{fid}' carries {n} B of body, under its {spec['min_bytes']} B floor: a marker over nothing instructs nobody")
    else:
        out(0, f"field '{fid}': {n} B")

for fid in found:
    if fid not in declared:
        out(1, f"marker 'handover:field id={fid}' is in report.md and is declared nowhere: a field nothing enumerates is a field nothing can miss")

# --- 5. the no-deliverable branch keeps its prohibition ------------------
nd = found.get("no-deliverable", "")
if nd:
    for item in D.get("no_deliverable_must_forbid", []):
        if item["needle"] in nd:
            out(0, f"the no-deliverable branch still forbids: '{item['needle']}'")
        else:
            out(1, f"the no-deliverable branch no longer says '{item['needle']}' - {item['why']}")

# --- 6. wired: the named validators exist and answer 2 on nothing --------
ghost = pathlib.Path(tempfile.mkdtemp()) / "no-such-deliverable"
for v in D.get("validators", []):
    script = gates_dir / v["script"]
    if not script.is_file():
        out(1, f"the validators field names {v['script']} and it does not exist in {gates_dir}")
        continue
    if not os.access(script, os.X_OK):
        out(1, f"{v['script']} exists and is not executable: the block tells the leader to run it")
        continue
    env = dict(os.environ, GATE_SELFTEST="0")
    try:
        r = subprocess.run(["bash", str(script), "--deliverable", str(ghost)],
                           capture_output=True, timeout=120, env=env)
    except Exception as e:
        out(2, f"could not run {v['script']} against an absent deliverable: {e}")
        continue
    if r.returncode == 2:
        out(0, f"{v['script']} answers 2 on an absent deliverable")
    else:
        out(1, f"{v['script']} answers {r.returncode} on an absent deliverable, not 2 - {v['why']}")
PY
}

selftest() {
  local p=0 f=0 tmp
  tmp="$(mktemp -d)"

  # seed <dir>: a synthetic pair of files, not a copy of the repo, so a mutation
  # cannot be satisfied by something else in the tree.
  seed() {
    local w="$1"
    mkdir -p "$w"
    cp "$DATA" "$w/handover-contract.json"
    cp "$ROOT/skills/ethical-hacker-squad/SKILL.md" "$w/SKILL.md"
    cp "$ROOT/skills/ethical-hacker-squad/references/report.md" "$w/report.md"
  }

  run_case() {
    local name="$1" want="$2" needle="$3" mut="$4" gates="${5:-$GATES_DIR}"
    local w="$tmp/$name"
    seed "$w"
    if [ -n "$mut" ] && ! EHS_WORK="$w" python3 -c "$mut" >/dev/null 2>&1; then
      printf '  HARNESS  %-48s the mutation itself failed\n' "$name"; f=$((f+1)); return
    fi
    local out rc
    out="$(measure "$w/SKILL.md" "$w/report.md" "$gates" "$w/handover-contract.json" 2>&1)"; rc=0
    printf '%s' "$out" | grep -q '^1|' && rc=1
    printf '%s' "$out" | grep -q '^2|' && rc=2
    if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
      printf '  PASS  %-50s rc=%s\n' "$name" "$rc"; p=$((p+1))
    else
      printf '  FAIL  %-50s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
      printf '%s\n' "$out" | sed 's/^/        /' | head -4; f=$((f+1))
    fi
  }

  echo "  == the repository as it stands =="
  run_case the-contract-is-wired 0 "handover section present" ""

  echo "  == step 9 stops pointing at the deliverable =="
  run_case step9-drops-findings-json 1 "does not name 'findings.json'" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"SKILL.md"
p.write_text(p.read_text().replace("`report.md` and `findings.json`","`report.md`",1))'

  run_case step9-drops-the-absolute-path 1 "does not name .absolute path" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"SKILL.md"
p.write_text(p.read_text().replace("**absolute path**","path",1))'

  run_case step9-stops-pointing-at-the-spec 1 "does not name 'references/report.md'" '
import os,pathlib,re
p=pathlib.Path(os.environ["EHS_WORK"])/"SKILL.md"
t=p.read_text()
i=t.index("### 9.")
head,tail=t[:i],t[i:]
p.write_text(head+tail.replace("`references/report.md`","the report specification",1))'

  run_case step9-deleted-entirely 1 "no .### 9" '
import os,pathlib,re
p=pathlib.Path(os.environ["EHS_WORK"])/"SKILL.md"
t=p.read_text()
p.write_text(re.sub(r"(?ms)^### 9\..*?(?=^## )","",t))'

  echo "  == the specification loses a field =="
  run_case a-declared-field-loses-its-marker 1 "has no marker in report.md" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"report.md"
p.write_text(p.read_text().replace("<!-- handover:field id=counts -->","",1))'

  run_case a-field-emptied-to-its-marker 1 "instructs nobody" '
import os,pathlib,re
p=pathlib.Path(os.environ["EHS_WORK"])/"report.md"
t=p.read_text()
i=t.index("<!-- handover:field id=validators -->")
j=t.index("<!-- handover:field id=not-measured -->")
p.write_text(t[:i]+"<!-- handover:field id=validators -->\n\n"+t[j:])'

  echo "  == the omission hole: prose grows, nothing enumerates it =="
  run_case a-marker-nobody-declared 1 "declared nowhere" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"report.md"
t=p.read_text()
i=t.index("<!-- /report:section -->",t.index("id=handover"))
p.write_text(t[:i]+"<!-- handover:field id=invented -->\nSomething someone added.\n\n"+t[i:])'

  echo "  == the branch that must not print a summary =="
  run_case no-deliverable-loses-its-prohibition 1 "no longer says" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"report.md"
p.write_text(p.read_text().replace("Do not print counts","Mention it",1))'

  echo "  == the whole section removed =="
  run_case handover-section-deleted 1 "declares the handover section 0 time" '
import os,pathlib,re
p=pathlib.Path(os.environ["EHS_WORK"])/"report.md"
t=p.read_text()
i=t.index("<!-- report:section id=handover")
p.write_text(t[:i])'

  run_case handover-section-opened-and-not-closed 1 "opened and never closed" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"report.md"
t=p.read_text()
i=t.index("<!-- report:section id=handover")
p.write_text(t[:i]+t[i:].replace("<!-- /report:section -->","",1))'

  echo "  == the validators the block tells the leader to run =="
  mkdir -p "$tmp/empty-gates"
  run_case a-named-validator-is-not-on-disk 1 "does not exist in" "" "$tmp/empty-gates"

  # a validator that exists and is not executable: the block tells the leader to RUN it
  mkdir -p "$tmp/unrunnable-gates"
  : > "$tmp/unrunnable-gates/gate-report-contract.sh"
  : > "$tmp/unrunnable-gates/gate-findings-artifact.sh"
  chmod 0644 "$tmp/unrunnable-gates/gate-report-contract.sh" "$tmp/unrunnable-gates/gate-findings-artifact.sh"
  run_case a-named-validator-is-not-executable 1 "is not executable" "" "$tmp/unrunnable-gates"

  # a validator that exists, runs, and answers 0 on a deliverable that is not there
  mkdir -p "$tmp/lying-gates"
  for s in gate-report-contract.sh gate-findings-artifact.sh; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/lying-gates/$s"
    chmod +x "$tmp/lying-gates/$s"
  done
  run_case a-named-validator-answers-0-on-nothing 1 "not 2" "" "$tmp/lying-gates"

  echo "  == could not measure =="
  run_case data-file-unparseable 2 "missing or unusable" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"handover-contract.json").write_text("{")'

  run_case report-md-missing 2 "missing or unusable" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"report.md").unlink()'

  command rm -rf "$tmp"
  echo "  $p PASS / $f FAIL"
  [ "$f" -eq 0 ] || return 1
  return 0
}

if [ "$ONLY_SELFTEST" -eq 1 ]; then
  selftest; exit $?
fi

gate_header "handover-contract (the deliverable exists; something has to say where)"
gate_scope "SKILL.md step 9, the handover section of references/report.md against scripts/gates/data/handover-contract.json, and the exit code each named validator gives on an absent deliverable"
gate_out_of_scope "whether the leader ACTUALLY prints the block at run time - no static check makes a model obey an instruction, only proves the instruction is there and complete; and SKILL.md's size, which is gate-budget-ledger.sh's knob"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was checked"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

SELFTEST_SKIPPED=0
if [ "${GATE_SELFTEST:-1}" = "0" ]; then
  SELFTEST_SKIPPED=1
  gate_warn "the self-test was skipped (GATE_SELFTEST=0): the verdict is capped at 2"
else
  echo "== self-test: this gate, proved in the negative =="
  if ! selftest; then
    gate_warn "the gate does NOT pass its own self-test; any result over the repo would be indefensible"
    gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
  fi
fi

echo "== the repository =="
RC=0
while IFS= read -r line; do
  code="${line%%|*}"; msg="${line#*|}"
  case "$code" in
    0) [ -n "$msg" ] && echo "· $msg" ;;
    1) gate_fail "$msg"; RC=1 ;;
    2) gate_warn "$msg"; RC=2 ;;
  esac
done < <(measure "$ROOT/skills/ethical-hacker-squad/SKILL.md" \
                 "$ROOT/skills/ethical-hacker-squad/references/report.md" \
                 "$GATES_DIR" "$DATA")

echo "NOT MEASURED: whether the leader prints the block when an engagement ends. This gate proves"
echo "              the instruction exists, is reachable in step 9, and is complete. Obedience is a"
echo "              bench/ measurement, and calling this gate's 0 'the handover works' would be the"
echo "              same substitution the block itself forbids."

if [ "$SELFTEST_SKIPPED" -eq 1 ] && [ "$RC" -eq 0 ]; then RC=2; fi
gate_verdict "$RC"; exit "$RC"
