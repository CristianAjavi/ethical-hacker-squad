#!/usr/bin/env bash
# Self-test for gate-licence-hygiene.sh. Each case breaks exactly one thing on a
# throwaway copy and asserts the exit code AND the reason, including a control on
# the untouched repository and two cases that must report could-not-measure.
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-licence-hygiene.sh"
if [ -n "${EHS_REPO_ROOT:-}" ]; then SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then :
else SRC="$(cd "$HERE/../.." && pwd)"; fi
command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-licence-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

case_run() {
  local name="$1" want="$2" needle="$3" mutation="$4" work="$TMP/$1"
  rm -rf "$work"; mkdir -p "$work"
  (cd "$SRC" && tar --exclude .git --exclude __pycache__ -cf - .) | (cd "$work" && tar -xf -)
  if [ -n "$mutation" ] && ! EHS_WORK="$work" python3 -c "$mutation" >/dev/null 2>&1; then
    printf 'HARNESS  %-40s the mutation itself failed\n' "$name"; fail=$((fail+1)); return
  fi
  local out rc
  out="$(EHS_REPO_ROOT="$work" bash "$GATE" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf 'ok       %-40s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-40s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -5; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-licence-hygiene.sh (source: $SRC) ==="

case_run control-untouched-repo 0 "no attributed verbatim span" ""

case_run long-quotation-attributed 1 "quotation next to the name of an external source" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"skills/ethical-hacker-squad/references/knowledge/web-api.md"
p.write_text(p.read_text()+chr(10)+
  "Per OWASP, \"verify that the application does not output error messages or stack "
  "traces containing sensitive data that could assist an attacker\" is the requirement."+chr(10))'

case_run quotation-inside-the-exempt-region 0 "licence:quoted-terms" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"docs/coverage/mapa-microsoft.md"
p.write_text(p.read_text().replace("<!-- licence:quoted-terms -->",
  "<!-- licence:quoted-terms -->"+chr(10)+
  "Per OWASP, \"verify that the application does not output error messages or stack "
  "traces containing sensitive data that could assist an attacker\" is the requirement.",1))'

case_run owner-cited-without-attribution 1 "NOTICE.md does not name it" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"scripts/meter/standards-families.json"
d=json.loads(p.read_text())
d["families"].append({"family":"BSI-C5","owner":"BSI","extract":"BSI\\\\s+C5"})
p.write_text(json.dumps(d,indent=2))'

case_run allowlisted-source-without-a-licence 1 "cannot be reused safely" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"docs/sources-allowlist.json"
d=json.loads(p.read_text())
d["sources"][0].pop("license",None)
p.write_text(json.dumps(d,indent=2))'

case_run denylisted-phrase-in-the-corpus 1 "on the verbatim denylist" '
import os,json,hashlib,re,pathlib
w=os.environ["EHS_WORK"]
# take consecutive words that really are in the corpus, hash them the way the
# gate does, and put only the hash on the list. The window comes from the list
# itself: a literal here would have to be re-typed the day the window moves.
p=pathlib.Path(w)/"scripts/gates/data/verbatim-denylist.json"
d=json.loads(p.read_text()); n=d["ngram"]
text=(pathlib.Path(w)/"skills/ethical-hacker-squad/references/knowledge/web-api.md").read_text()
words=re.sub(r"[^a-z0-9 ]+"," ",text.lower()).split()
h=hashlib.sha256(" ".join(words[40:40+n]).encode()).hexdigest()[:16]
d["phrases"].append({"hash":h,"source":"a fixture, not a real source"})
p.write_text(json.dumps(d,indent=2))'

# --- the window: one number, three places that used to write it down --------
# This case is the discriminator. It moves the DECLARED window and plants a hash
# of that width. A sweep with the number written into it computes the old width,
# matches nothing, and reports a clean run - rc 0, which is the failure. Only a
# sweep that reads the declaration finds the phrase.
case_run denylist-ngram-drives-the-sweep 1 "on the verbatim denylist" '
import os,json,hashlib,re,pathlib
w=os.environ["EHS_WORK"]
p=pathlib.Path(w)/"scripts/gates/data/verbatim-denylist.json"
d=json.loads(p.read_text())
n=d["ngram"]-2
assert n>=3, "the declared window is too small to move and still be distinctive"
assert n!=d["ngram"]
text=(pathlib.Path(w)/"skills/ethical-hacker-squad/references/knowledge/web-api.md").read_text()
words=re.sub(r"[^a-z0-9 ]+"," ",text.lower()).split()
h=hashlib.sha256(" ".join(words[40:40+n]).encode()).hexdigest()[:16]
d["ngram"]=n
d["phrases"].append({"hash":h,"source":"a fixture, not a real source"})
p.write_text(json.dumps(d,indent=2))'

# and the other half of the mechanism: the tool that MAKES the hashes going back
# to a window of its own. Nothing it produces would ever match again.
case_run producer-cuts-a-window-of-its-own 1 "invisible to this sweep" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"scripts/licence/add-verbatim-phrase.py"
t=p.read_text()
i=t.index("def main(")
# shadows the real one: at module level the last definition is the one that runs
p.write_text(t[:i]+"def window_size(*a, **k):"+chr(10)+"    return 5"+chr(10)*3+t[i:])'

case_run families-file-unreadable 2 "" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"scripts/meter/standards-families.json").write_text("{")'

case_run denylist-unparseable 2 "" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/data/verbatim-denylist.json").write_text("nope")'

case_run notice-gone 2 "" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"NOTICE.md").unlink()'

case_run ngram-not-declared 2 "does not declare" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/data/verbatim-denylist.json"
d=json.loads(p.read_text()); assert d.pop("ngram",None)
p.write_text(json.dumps(d,indent=2))'

case_run producer-gone 2 "is not there" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"scripts/licence/add-verbatim-phrase.py").unlink()'

echo
echo "Summary: $pass ok, $fail failures"
if [ "$fail" -eq 0 ]; then
  echo "Result: OK. The gate fails on a pasted span, on an owner nobody attributed and on"
  echo "        a source with no licence, and reports could-not-measure when a source of"
  echo "        truth is gone."
  exit 0
fi
exit 1
