#!/usr/bin/env bash
# Self-test for gate-competitive-backlog.sh. Each case breaks exactly one thing
# on a throwaway copy and asserts the exit code and the reason. The first case is
# the control: without it, a battery that stopped measuring looks like a clean
# run. Three cases are NEGATIVE controls - a citation that is not a claim, a
# past-tense motive, an open row with no gate - because the first draft of B4
# flagged the sentence that explains why an item was written, which is how every
# gate header in this repository opens.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${EHS_REPO_ROOT:-}" ]; then SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then :
else SRC="$(cd "$HERE/../.." && pwd)"; fi

command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-backlog-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
DOC="docs/competitive-analysis.md"

case_run() {
  # $5, when set to `crash-expected`, turns off the traceback guard below. Only
  # the case whose subject IS the crash may set it.
  local name="$1" want="$2" needle="$3" mutation="$4" crash="${5:-}" work="$TMP/$1"
  rm -rf "$work"; mkdir -p "$work"
  (cd "$SRC" && tar --exclude .git --exclude __pycache__ --exclude node_modules -cf - .) \
    | (cd "$work" && tar -xf -)
  if [ -n "$mutation" ] && ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
    printf 'HARNESS  %-46s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
  fi
  local out rc
  out="$(EHS_REPO_ROOT="$work" bash "$work/scripts/gates/gate-competitive-backlog.sh" 2>&1)"; rc=$?
  if [ "$rc" -ne "$want" ]; then
    printf 'FAILED   %-46s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | head -8
    fail=$((fail+1)); return
  fi
  if [ "$crash" != crash-expected ] && printf '%s' "$out" | grep -q "Traceback (most recent call last)"; then
    # A traceback prints the offending SOURCE LINE, so a needle can match the
    # text of a message that was never emitted. Two could-not-measure cases
    # passed that way before this guard existed: right exit code, right words,
    # and the arm they were testing had crashed rather than fired.
    printf 'FAILED   %-46s rc=%s but the core crashed; nothing was measured\n' "$name" "$rc"
    printf '%s\n' "$out" | grep -A2 Traceback | sed 's/^/         /' | head -6
    fail=$((fail+1)); return
  fi
  if [ -n "$needle" ] && ! printf '%s' "$out" | grep -qF "$needle"; then
    printf 'FAILED   %-46s rc=%s but never says: %s\n' "$name" "$rc" "$needle"
    fail=$((fail+1)); return
  fi
  printf 'ok       %-46s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
}

py_doc() {  # helper: emit python that rewrites the backlog doc
  printf '%s' "
import os,re,pathlib
p=pathlib.Path(os.environ['EHS_WORK'])/'$DOC'
t=p.read_text()
$1
p.write_text(t)"
}

echo "=== self-test: gate-competitive-backlog.sh (source: $SRC) ==="

case_run control-untouched-repo 0 "nothing in the repository calls a shipped item missing" ""

# --- B1: a status nobody defined
case_run status-nobody-defined 1 "is not one of shipped/partial/open" "$(py_doc "t=t.replace('| 8 | open |','| 8 | pending |',1)")"

# --- B2: the claim and the directory disagree
case_run shipped-row-names-no-gate 1 "names no gate file" "$(py_doc "t=t.replace('\`gate-triage-rules.sh\`','the triage gate',1)")"
case_run shipped-row-names-a-gate-that-is-gone 1 "which the runner does not have" "$(py_doc "t=t.replace('\`gate-triage-rules.sh\`','\`gate-triage-rules-v2.sh\`',1)")"

# --- B3: built and never crossed off
case_run open-row-already-kept-by-a-gate 1 "sends the next reader to build it twice" "$(py_doc "t=t.replace('Gate fails a \`critical\`/\`high\` finding that cites no calibration rule','Gate fails a \`critical\`/\`high\` finding that cites no calibration rule — \`gate-agent-tools.sh\`',1)")"

# --- B4: the tooth.
# The two fixtures below assemble their citation from pieces instead of spelling
# it out. B4 walks the whole tree, and this self-test is part of the tree: a line
# here that cites a shipped item and calls it missing, in those words, is a
# finding against the real repository - and on the first run it was: the control
# case went red on its own harness, twice, the second time on the comment
# explaining the first. Excluding self-tests from the walk would have been the easy fix and
# the wrong one; a stale reason parked in a self-test is still a stale reason.
case_run a-shipped-item-called-missing 1 "cites backlog #7 beside" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/gate-secret-scan.sh"
# assembled, never written whole: see the note above case a-shipped-item-called-missing
tag="back"+"log #7"
p.write_text(p.read_text()+"\n# The findings artifact of "+tag+" is not implemented.\n")'

# --- B4 negative controls. Both of these were, or would have been, false positives.
case_run past-tense-motive-is-not-a-finding 0 "nothing in the repository calls a shipped item missing" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/gate-secret-scan.sh"
p.write_text(p.read_text()+"\n# Four of five rivals emitted one and we did not - that is backlog #7.\n")'

case_run a-citation-that-is-not-a-claim 0 "nothing in the repository calls a shipped item missing" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/gate-secret-scan.sh"
p.write_text(p.read_text()+"\n# The schema this reads is specified by backlog #7.\n")'

case_run an-open-item-called-missing-is-correct 0 "nothing in the repository calls a shipped item missing" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/gate-secret-scan.sh"
tag="back"+"log #8"
p.write_text(p.read_text()+"\n# The severity catalogue of "+tag+" is not implemented.\n")'

# The exemption, both ways round. A case that only proves the marked line stays
# silent proves nothing on its own: the line might be silent for some other
# reason. The pair is the measurement - same line, marker on, marker off.
# The needle is the exemption LINE, not a count: the count is repo-wide, so a
# number here would go red the day someone marks a third line, which is a
# decaying figure and not a defect.
case_run marked-line-quoting-a-retired-reason 0 "which quote a retired reason on purpose" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"docs/knowledge-loop.md"
tag="back"+"log #7"
p.write_text(p.read_text()+"\n<!-- backlog:quoted -->\n> no finding is emitted yet ("+tag+")\n")'

case_run the-same-line-without-the-marker 1 "cites backlog #7 beside" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"docs/knowledge-loop.md"
tag="back"+"log #7"
p.write_text(p.read_text()+"\n> no finding is emitted yet ("+tag+")\n")'

# --- the could-not-measure arms: a battery that stops reaching its document
case_run status-column-removed 2 "no backlog table with a \`Status\` column" "$(py_doc "t=t.replace('| # | Status | Item |','| # | Item |',1)")"
case_run table-header-with-no-rows 2 "header and no rows" "$(py_doc "
i=t.index('| # | Status | Item |')
j=t.index('**Sequencing')
t=t[:i]+'| # | Status | Item |\n|---|---|---|\n\n'+t[j:]")"
# The numbers go, the word stays. Renaming "backlog" wholesale also renames this
# gate's own core and wrapper, and the run then stops for a missing file - rc 2
# on the wrong signal, which the needle caught and the exit code alone would not
# have. What this case has to break is the citations, and nothing else.
case_run nobody-cites-a-numbered-item 2 "stopped recognising them" '
import os,re,pathlib
root=pathlib.Path(os.environ["EHS_WORK"])
doc=(root/"docs/competitive-analysis.md").resolve()
pat=re.compile(r"backlog\s*(?:item\s*)?#?\s*(\d{1,2})\b",re.I)
for ext in ("*.sh","*.md","*.py","*.json","*.yml","*.yaml"):
    for f in root.rglob(ext):
        if ".git" in f.parts or f.resolve()==doc: continue
        try: t=f.read_text()
        except Exception: continue
        if pat.search(t): f.write_text(pat.sub("the backlog",t))'

# The last two could-not-measure arms. Every arm in this gate is exercised on
# purpose: four of them were dead code when this battery was first run - the core
# called a list as a function - and each one arrived at the wrapper as a
# confident red. An arm nobody fires is a safety net nobody has ever dropped.
case_run runner-lists-no-gate 2 "had nothing to check against" '
import os,pathlib,stat
p=pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/run-all.sh"
p.write_text("#!/usr/bin/env bash\n[ \"${1:-}\" = --list ] && exit 0\nexit 0\n")
p.chmod(p.stat().st_mode|stat.S_IXUSR)'

case_run the-document-cannot-be-read 2 "the document this gate" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"docs/competitive-analysis.md").unlink()'

# And the wrapper arm that made the four dead ones visible. python exits 1 on an
# unhandled exception, and 1 is also this contract's "measured, FAILS"; without
# this arm a core that cannot run at all ships a red verdict about a repository
# it never read.
case_run core-crashes-instead-of-measuring 2 "crashed rather than measured" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/lib/competitive_backlog.py"
# appended at the end it is never reached: sys.exit runs first
p.write_text(p.read_text().replace("def main(root, doc, inventory_text):",
  "def main(root, doc, inventory_text):\n    raise RuntimeError(\"the core is broken\")",1))' crash-expected

echo "--- $pass passed, $fail failed ---"
[ "$fail" -eq 0 ] || exit 1
exit 0
