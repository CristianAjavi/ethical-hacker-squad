#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-budget-ledger.sh — a budget may not move without the figure that moved it.
#
# WHY IT EXISTS
#   G7 asks WHO moved a limit. Nothing asked whether the number that moved still
#   agrees with the sentence that states it, and one of them did not.
#
#   Measured 2026-09-01 over the whole history: 15 budget constants moved, 13 of
#   them TIGHTER. Exactly two loosened, both the same knob - EHS_MAX_TREE_BYTES,
#   raised 524288 -> 655360 -> 786432. The discipline around those raises is
#   genuinely good: the third one is written up in the gate header with the
#   figure that forced it (653,513 B served against a 655,360 B cap - 1,847 bytes
#   of headroom). This gate does not exist because the discipline is missing. It
#   exists because NOTHING ENFORCES IT, and the practice already has one measured
#   failure: the same file's environment table still said `default 524288` while
#   `786432` was enforced - wrong since the second of the three re-baselines, and
#   read by anyone consulting the usage block instead of the rationale. One knob
#   of eleven had drifted, and it was the only one that had ever been raised.
#
#   The fix that raises a number makes the note that states it false, and no test
#   sees that. That is the class.
#
# WHAT IT MEASURES
#   1. classification  every `${EHS_*:-<number>}` a gate reads is named in
#                      scripts/gates/data/budget-ledger.json, as a `budget` or
#                      explicitly as `not_a_budget`. A knob nobody classified
#                      FAILS: a ledger listing only what someone remembered
#                      cannot see what nothing points at.
#   2. agreement       the ledger's `value` equals the value the gate enforces.
#                      So raising a budget is an edit to a file under
#                      scripts/gates/**, which G7 puts in front of a reviewer,
#                      with the justification sitting on the next line.
#   3. no drift        every comment in the source that states `default <N>` for
#                      that knob names the same number. This is check 3 because
#                      it is the one that was already red.
#   4. justification   every `budget` carries a non-empty `why` and `measured`.
#
# WHAT IT DOES NOT MEASURE, and will not pretend to
#   Whether a `measured` claim is TRUE. A gate cannot re-run the reasoning that
#   justified a number, and one that implied it could would be worse than this
#   one. It enforces that the claim exists, sits beside the number, and that the
#   number is the same everywhere the repository states it. It also cannot see
#   the DIRECTION of a change - it has no history at gate time - so it does not
#   claim to distinguish a raise from a tightening.
#
# Usage:
#   scripts/gates/gate-budget-ledger.sh [--gates-dir DIR] [--ledger FILE]
#   scripts/gates/gate-budget-ledger.sh --self-test
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, no gates directory, a missing or unusable ledger).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"
ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
GATES_DIR="$HERE"
LEDGER="$HERE/data/budget-ledger.json"
ONLY_SELFTEST=0

while [ $# -gt 0 ]; do
  case "$1" in
    --gates-dir) GATES_DIR="${2:-}"; shift 2 ;;
    --ledger)    LEDGER="${2:-}"; shift 2 ;;
    --self-test) ONLY_SELFTEST=1; shift ;;
    -h|--help)   sed -n '2,52p' "$0"; exit 0 ;;
    *)           shift ;;
  esac
done

measure() {
  python3 - "$1" "$2" <<'PY'
import json, re, sys, pathlib

gates = pathlib.Path(sys.argv[1])
ledger_path = pathlib.Path(sys.argv[2])
KNOB = re.compile(r'\$\{(EHS_[A-Z0-9_]+):-([0-9][0-9_]*)\}')
DOC = re.compile(r'default[:\s]+([0-9][0-9_]*)')

def out(rc, msg):
    print(f"{rc}|{msg}")

if not gates.is_dir():
    out(2, f"the gates directory does not exist: {gates}"); raise SystemExit
try:
    ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
    knobs = ledger["knobs"]
    if not isinstance(knobs, dict):
        raise ValueError("`knobs` is not an object")
except (OSError, ValueError, KeyError) as exc:
    out(2, f"the ledger is missing or unusable ({ledger_path}): {exc}"); raise SystemExit

# --- what the source actually enforces -------------------------------------
enforced = {}   # knob -> {value, file}
docs = {}       # knob -> [(file, line, value)]
for f in sorted(gates.rglob("*.sh")):
    rel = f.as_posix()
    if "/fixtures/" in rel or f.name.endswith(".selftest.sh"):
        continue
    try:
        txt = f.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        out(2, f"cannot read {rel}: {exc}"); raise SystemExit
    for m in KNOB.finditer(txt):
        enforced.setdefault(m.group(1), (m.group(2).replace("_", ""), rel))
    for knob in {m.group(1) for m in KNOB.finditer(txt)}:
        for i, line in enumerate(txt.splitlines(), 1):
            if line.lstrip().startswith("#") and knob in line:
                for d in DOC.findall(line):
                    docs.setdefault(knob, []).append((rel, i, d.replace("_", "")))

if not enforced:
    out(2, "no `${EHS_*:-<number>}` knob was found in any gate: this check read nothing, "
           "which is not the same as finding nothing wrong")
    raise SystemExit

fails = 0
budgets = 0
# 1. classification -- the omission hole, closed by enumerating the SOURCE
for knob, (val, rel) in sorted(enforced.items()):
    entry = knobs.get(knob)
    if entry is None:
        out(1, f"{knob} is read by {rel} and appears nowhere in {ledger_path.name}. A knob nobody "
               f"classified is not assumed to be harmless: name it as a `budget` with its figure, "
               f"or as `not_a_budget` with the reason")
        fails += 1
        continue
    kind = entry.get("kind")
    if kind not in ("budget", "not_a_budget"):
        out(1, f"{knob}: `kind` is {kind!r}, which is neither `budget` nor `not_a_budget`")
        fails += 1
        continue
    # 2. agreement
    if str(entry.get("value")) != val:
        out(1, f"{knob}: the ledger declares {entry.get('value')!r} and {rel} enforces {val}. "
               f"Moving a bound and leaving its declaration behind is how a budget loosens "
               f"without anyone deciding to loosen it - change both in the same edit and say why")
        fails += 1
    if kind == "budget":
        budgets += 1
        # 4. justification
        for field in ("why", "measured"):
            if not str(entry.get(field) or "").strip():
                out(1, f"{knob}: `{field}` is empty. A budget without one is a number nobody can "
                       f"argue with, and the next person to raise it will not know what it cost")
                fails += 1

# 3. no drift, in either direction
for knob, hits in sorted(docs.items()):
    if knob not in enforced:
        continue
    val = enforced[knob][0]
    for rel, line, d in hits:
        if d != val:
            out(1, f"{rel}:{line} states `default {d}` for {knob} and the code enforces {val}. "
                   f"The fix that raises a number makes the sentence that states it false, and "
                   f"until now nothing read that sentence")
            fails += 1

declared_only = sorted(set(knobs) - set(enforced))
if declared_only:
    out(1, f"the ledger names {len(declared_only)} knob(s) no gate reads any more "
           f"({', '.join(declared_only)}). A declaration outliving its knob is a rule nobody "
           f"can trip and a reader can still believe")
    fails += len(declared_only)

out(0, f"measured: {len(enforced)} knob(s) enforced in {gates.name}/, {budgets} of them budgets, "
       f"{sum(len(v) for v in docs.values())} stated default(s) cross-checked, {fails} finding(s)")
if fails:
    out("FAILS", "")
PY
}

selftest() {
  command -v python3 >/dev/null 2>&1 || { echo "  UNMEASURABLE python3 is missing"; return 2; }
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/ehs-budget-XXXXXX")"
  local p=0 f=0
  # case <name> <expected rc> <needle> <mutation>
  run_case() {
    # Split deliberately: bash creates every name in one `local` before assigning
    # any of them, so `w="$tmp/$name"` on the same line reads an unset local and
    # `set -u` kills the run. This cost one debugging cycle; it is written down
    # so it costs nobody a second.
    local name="$1" want="$2" needle="$3" mut="$4"
    local w="$tmp/$name"
    command rm -rf "$w"; mkdir -p "$w"
    (cd "$GATES_DIR" && tar -cf - . 2>/dev/null) | (cd "$w" && tar -xf - 2>/dev/null)
    if [ -n "$mut" ] && ! EHS_WORK="$w" python3 -c "$mut" >/dev/null 2>&1; then
      printf '  HARNESS  %-44s the mutation itself failed\n' "$name"; f=$((f+1)); return
    fi
    local out rc
    out="$(measure "$w" "$w/data/budget-ledger.json" 2>&1)"; rc=0
    printf '%s' "$out" | grep -q '^1|' && rc=1
    printf '%s' "$out" | grep -q '^2|' && rc=2
    if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
      printf '  PASS  %-46s rc=%s\n' "$name" "$rc"; p=$((p+1))
    else
      printf '  FAIL  %-46s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
      printf '%s\n' "$out" | sed 's/^/        /' | head -4; f=$((f+1))
    fi
  }

  echo "  == the repository as it stands =="
  run_case the-repo-agrees-with-its-ledger 0 "measured:" ""

  echo "  == a budget moves and its declaration does not =="
  run_case enforced-value-raised-behind-the-ledger 1 "enforces 999999" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"gate-plugin-integrity.sh"
p.write_text(p.read_text().replace("EHS_MAX_TREE_BYTES:-786432","EHS_MAX_TREE_BYTES:-999999",1))'

  run_case ledger-lowered-behind-the-code 1 "the ledger declares" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"data/budget-ledger.json"
d=json.loads(p.read_text()); d["knobs"]["EHS_MAX_TREE_BYTES"]["value"]=1
p.write_text(json.dumps(d,indent=2))'

  echo "  == the drift that was already red =="
  run_case stated-default-disagrees-with-the-code 1 "makes the sentence that states it false" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"gate-plugin-integrity.sh"
t=p.read_text().replace("EHS_MAX_TREE_BYTES            default 786432",
                        "EHS_MAX_TREE_BYTES            default 524288",1)
assert "default 524288" in t
p.write_text(t)'

  echo "  == the omission hole =="
  run_case a-new-knob-nobody-classified 1 "appears nowhere in" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"gate-plugin-integrity.sh"
# assembled from parts on purpose: a literal knob here would be scanned out of
# this very file, and the gate would report a finding against its own self-test
p.write_text(p.read_text()+"\nNEWCAP=\"$" + "{EHS_MAX_SOMETHING_NEW:-4096}\"\n")'

  run_case a-declaration-that-outlived-its-knob 1 "no gate reads any more" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"data/budget-ledger.json"
d=json.loads(p.read_text()); d["knobs"]["EHS_MAX_GHOST"]={"kind":"budget","value":1,
  "enforced_in":"nowhere","why":"x","measured":"x"}
p.write_text(json.dumps(d,indent=2))'

  echo "  == a budget without its figure =="
  run_case budget-with-an-empty-measured 1 "is empty" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"data/budget-ledger.json"
d=json.loads(p.read_text()); d["knobs"]["EHS_MAX_TREE_BYTES"]["measured"]="   "
p.write_text(json.dumps(d,indent=2))'

  run_case a-budget-relabelled-as-not-a-budget-still-checks-its-value 1 "the ledger declares" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"data/budget-ledger.json"
d=json.loads(p.read_text()); e=d["knobs"]["EHS_MAX_TREE_BYTES"]
e["kind"]="not_a_budget"; e["value"]=123
p.write_text(json.dumps(d,indent=2))'

  echo "  == could not measure =="
  run_case ledger-missing 2 "missing or unusable" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"data/budget-ledger.json").unlink()'

  run_case ledger-unparseable 2 "missing or unusable" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"data/budget-ledger.json").write_text("{")'

  command rm -rf "$tmp"
  echo "  $p PASS / $f FAIL"
  [ "$f" -eq 0 ] || return 1
  return 0
}

if [ "$ONLY_SELFTEST" -eq 1 ]; then
  selftest; exit $?
fi

gate_header "budget-ledger (a bound may not move without the figure that moved it)"
gate_scope "every \${EHS_*:-<number>} a gate reads, against scripts/gates/data/budget-ledger.json and against every comment in the source that states a default for it"
gate_out_of_scope "whether a 'measured' claim is TRUE, and the DIRECTION of a change - this gate has no history at gate time and does not pretend to tell a raise from a tightening"

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
    0)     [ -n "$msg" ] && echo "· $msg" ;;
    1)     gate_fail "$msg"; RC=1 ;;
    2)     gate_warn "$msg"; RC=2 ;;
    FAILS) : ;;
  esac
done < <(measure "$GATES_DIR" "$LEDGER")

echo "NOT MEASURED: whether a 'measured' claim is true. A gate cannot re-run the reasoning that"
echo "              justified a number; it enforces that the claim exists beside it and that the"
echo "              number is the same everywhere this repository states it."

if [ "$SELFTEST_SKIPPED" -eq 1 ] && [ "$RC" -eq 0 ]; then RC=2; fi
gate_verdict "$RC"; exit "$RC"
