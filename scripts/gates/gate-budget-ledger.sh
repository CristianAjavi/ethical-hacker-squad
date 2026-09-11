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
#   5. where           the ledger's `enforced_in` names the file that actually
#                      reads the knob. The ledger already said where each bound
#                      is made to bite, for eleven knobs, and nothing read that
#                      field: it could name a gate that had stopped enforcing
#                      the knob, or a gate that never did, and the run stayed
#                      green. A reader consults that column to find the control;
#                      pointing it at the wrong file sends them to a gate that
#                      does not contain the bound and lets them conclude there
#                      is none. Check 2 proves the NUMBER agrees; this one
#                      proves the ADDRESS does.
#   6. bite            every `budget` is MOVED to its extremes and the gate named
#                      in its `enforced_in` is re-run. Checks 1-5 all pass for a
#                      gate that reads `${EHS_*:-<number>}` into a variable and
#                      never compares anything with it (a literal knob cannot be
#                      written here: check 1 scans this file too, and would report
#                      the example as an unclassified knob): the ledger would agree
#                      with the source, the source would agree with its comments,
#                      the `why` would be eloquent, and the bound would decide
#                      nothing. This is the only check here that runs another
#                      gate, so it carries a recursion guard and a timeout.
#
# HOW CHECK 6 DECIDES, and why the bound is moved to THREE points
#   A bound bites if and only if MOVING IT changes the verdict of the gate that
#   applies it. The probe needs neither the magnitude being measured nor whether
#   the knob is a ceiling or a floor: it moves the number to the extremes and
#   watches the exit code. The points are tried in order and it stops at the first
#   one that moves the verdict - 0, then 999999999, then -1.
#
#   -1 is there because it was MEASURED to be necessary, not for symmetry.
#   EHS_TREE_DELTA_HUMAN_BYTES is compared with `-gt` against a delta that is
#   itself 0 on a branch that adds nothing, and `0 -gt 0` is false: at a low
#   extreme of 0 the gate still answers rc 0, and a probe that stopped at 0 and
#   999999999 would have reported a live bound as decoration. At -1 it answers
#   rc 1. One notch was the whole difference between a true and a false
#   accusation. -1 is tried LAST because it is also the point a gate is most
#   likely to reject outright (gate-agent-tools.sh refuses a non-digit knob and
#   answers 2), and a point that never has to be reached cannot misfire.
#
#   Three verdicts, never two:
#     bites          some extreme moved the verdict between 0 and 1
#     does NOT bite  every extreme was measured, none of them moved the verdict,
#                    and the entry DECLARES that the probe reached the comparison
#                    - `probe_env`, the environment that opens the path the knob
#                    guards, empty when the default run already reaches it -> rc 1
#     NOT MEASURED   the gate could not answer somewhere (rc 2, a timeout, a
#                    missing `enforced_in`, no baseline); or nothing moved and the
#                    entry declares no `probe_env`, so a decorative bound and a
#                    comparison this run never reaches cannot be told apart
#                    -> rc 2. Never rc 0: an unprobed bound is not a proved
#                    one, and this check exists precisely because an unexercised
#                    number looks exactly like an enforced one.
#
# WHERE CHECK 6 RUNS, decided by measuring it rather than by taste
#   The rule for this repository is that a probe costing more than ~30 s does not
#   belong on the path that runs on every push. So it was timed, twice, and the
#   figure is a RANGE because it turned out to depend on what else the machine is
#   doing:
#
#     probing all eight budgets   9.5 s   idle machine (load ~1)
#                                21-24 s  three runs at load average 5
#     the whole battery, run-all.sh  31 s  same machine, low load
#
#   17 runs produce that: one baseline per enforcing gate (4) plus 13 probe runs,
#   the early exit having saved 3. gate-plugin-integrity.sh is 5 of the 17 and
#   1.5-3.0 s of each, which is most of the total; the other three gates together
#   cost under 3 s. Both figures are under 30 s, so check 6 runs on the gate path
#   and the answer lands in front of whoever moved the number, in the same run
#   that told them the ledger agreed with the source. The margin at load is thin -
#   if gate-plugin-integrity.sh gets slower, re-time this before assuming it still
#   fits, and put the new figure here.
#
#   There is a second reason, and it is the stronger one: moving check 6 "into the
#   self-test" would save the push path nothing. This gate runs its self-test
#   INLINE on every invocation (see GATE_SELFTEST below) and refuses to report if
#   it fails, so its self-test is already on the push path. Taking the probe off
#   that path would mean a separate scripts/gates/gate-budget-ledger.selftest.sh,
#   which run-all.sh only executes with --selftests - a different decision, about
#   a different file, with a different cost.
#
#   Its two negative-proof cases are built on the CHEAPEST enforcing gate
#   (gate-benign-control.sh, 0.1-0.2 s a run) rather than on
#   gate-plugin-integrity.sh (1.5-3.0 s) on purpose: the mutant proves exactly the
#   same thing for ~2 s instead of ~11 s.
#
# WHY `not_a_budget` KNOBS ARE OUT OF CHECK 6, said out loud instead of skipped
#   Check 6 probes the eight `budget` knobs and deliberately not the three
#   `not_a_budget` ones. Those are not bounds, they are switches:
#   EHS_ALLOW_TOOLS_FRONTMATTER and EHS_REQUIRE_CLAUDE_CLI select a MODE, and
#   EHS_SELFTEST_CHILD marks an invocation launched by the battery. "Moving a
#   switch to its extremes" has no meaning - to a switch, 0 and 999999999 are the
#   same not-1 - so probing them would measure nothing and still print something,
#   which is the failure mode this whole file exists to prevent. What keeps them
#   honest is check 1: a switch is in the ledger because a person classified it,
#   and flipping one shows up in the run, not in a threshold.
#
# WHAT IT DOES NOT MEASURE, and will not pretend to
#   Whether a `measured` claim is TRUE. A gate cannot re-run the reasoning that
#   justified a number, and one that implied it could would be worse than this
#   one. It enforces that the claim exists, sits beside the number, and that the
#   number is the same everywhere the repository states it. It also cannot see
#   the DIRECTION of a change - it has no history at gate time - so it does not
#   claim to distinguish a raise from a tightening.
#
#   Check 6 has a limit of its own, and `probe_env` is where it is answered. The
#   probe moves the THRESHOLD; it cannot move the QUANTITY being compared, and it
#   runs the enforcing gate in one environment. A bound that moves nothing is
#   therefore two facts wearing one face: a decorative bound, or a comparison
#   this run never reaches. gate-tree-delta.sh is the live example - it picks its
#   budget by branch name, so on a human branch no value of the bot budget can
#   move a verdict, and calling that a failing bound would be an accusation this
#   probe cannot support. Reporting it as a failure is also how a check like this
#   one gets switched off: a red that no change caused, on every run, for ever.
#
#   So the ledger says how to reach it. `probe_env` is exported for the BASELINE
#   and for every extreme, which is what keeps the two runs comparable; for the
#   bot budget it is GITHUB_HEAD_REF=bot/..., the same variable the enforcing
#   gate reads to choose. With a path declared, "moved nothing" is a measured
#   failure and worth 1. With none declared it is worth 2 and says so, and the
#   remedy is to declare the environment that opens the comparison - or to delete
#   a knob nobody can show doing anything. An empty `probe_env` is a declaration
#   too: it asserts that the default run already reaches the comparison, and it
#   puts the entry back on the hook for a 1.
#
# Usage:
#   scripts/gates/gate-budget-ledger.sh [--gates-dir DIR] [--ledger FILE]
#                                       [--gates-rel REL]
#   scripts/gates/gate-budget-ledger.sh --self-test
#
#   --gates-rel is the path of the gates directory AS THE LEDGER SPELLS IT, i.e.
#   relative to the repository root. Check 5 compares a declaration written that
#   way against a file found by walking an absolute directory, so it needs the
#   frame of reference; it is derived from --gates-dir and the repo root, and an
#   absolute or empty value is reported as could-not-measure rather than guessed.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, no gates directory, a missing or unusable ledger, no
# frame of reference for `enforced_in`, a ledger in which no knob declares one
# at all - that one is a check that read nothing, not a clean run - or a bound
# whose bite could not be probed).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"
ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
GATES_DIR="$HERE"
LEDGER="$HERE/data/budget-ledger.json"
GATES_REL=""
ONLY_SELFTEST=0

while [ $# -gt 0 ]; do
  case "$1" in
    --gates-dir) GATES_DIR="${2:-}"; shift 2 ;;
    --ledger)    LEDGER="${2:-}"; shift 2 ;;
    --gates-rel) GATES_REL="${2:-}"; shift 2 ;;
    --self-test) ONLY_SELFTEST=1; shift ;;
    -h|--help)   sed -n '2,177p' "$0"; exit 0 ;;
    *)           shift ;;
  esac
done

# How the ledger spells the gates directory. Derived, not assumed: if GATES_DIR
# is not under ROOT the strip leaves an absolute path and check 5 says so
# instead of inventing a prefix.
[ -n "$GATES_REL" ] || GATES_REL="${GATES_DIR#"$ROOT"/}"

measure() {
  python3 - "$1" "$2" "$3" <<'PY'
import json, re, sys, pathlib

gates = pathlib.Path(sys.argv[1])
ledger_path = pathlib.Path(sys.argv[2])
gates_rel = sys.argv[3].strip().rstrip("/")
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
where = {}      # knob -> {paths, spelled the way the ledger spells them}
docs = {}       # knob -> [(file, line, value)]
for f in sorted(gates.rglob("*.sh")):
    rel = f.as_posix()
    if "/fixtures/" in rel or f.name.endswith(".selftest.sh"):
        continue
    try:
        txt = f.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        out(2, f"cannot read {rel}: {exc}"); raise SystemExit
    ledger_spelling = f"{gates_rel}/{f.relative_to(gates).as_posix()}"
    for m in KNOB.finditer(txt):
        enforced.setdefault(m.group(1), (m.group(2).replace("_", ""), rel))
        where.setdefault(m.group(1), set()).add(ledger_spelling)
    for knob in {m.group(1) for m in KNOB.finditer(txt)}:
        for i, line in enumerate(txt.splitlines(), 1):
            if line.lstrip().startswith("#") and knob in line:
                for d in DOC.findall(line):
                    docs.setdefault(knob, []).append((rel, i, d.replace("_", "")))

if not enforced:
    out(2, "no `${EHS_*:-<number>}` knob was found in any gate: this check read nothing, "
           "which is not the same as finding nothing wrong")
    raise SystemExit


def declared_place(entry):
    """`enforced_in` as a string, tolerating an entry that is not an object."""
    if not isinstance(entry, dict):
        return ""
    return str(entry.get("enforced_in") or "").strip()


if not gates_rel or gates_rel.startswith("/"):
    out(2, f"I cannot tell how the ledger spells {gates}: --gates-rel came through as "
           f"{gates_rel!r}. `enforced_in` is written relative to the repository root and "
           f"comparing it to an absolute path would either pass everything or fail everything")
    raise SystemExit
if not any(declared_place(knobs.get(k)) for k in enforced):
    out(2, f"not one of the {len(enforced)} knobs in {ledger_path.name} declares `enforced_in`: "
           f"check 5 read nothing. A ledger that stopped saying where a bound is enforced is not "
           f"a ledger with nothing wrong in it")
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
    # 5. where -- check 2 proves the number agrees; this proves the address does
    places = sorted(where.get(knob, ()))
    declared_at = declared_place(entry)
    if not declared_at:
        out(1, f"{knob}: `enforced_in` is missing or empty, and {rel} reads the knob. The column "
               f"exists to tell a reader where the bound is made to bite; left blank it tells "
               f"them to go looking, and 'I could not find the control' reads like 'there is none'")
        fails += 1
    elif declared_at not in places:
        out(1, f"{knob}: the ledger says `enforced_in` {declared_at} and the knob is read in "
               f"{', '.join(places)}. Following that address lands on a file with no such bound "
               f"in it - the reader concludes the budget is unenforced, and the run stays green")
        fails += 1
    elif len(places) > 1:
        out(1, f"{knob}: read in {len(places)} files ({', '.join(places)}) and the ledger names "
               f"one. A single address cannot describe two controls: split the entry, or stop "
               f"reading the same knob in two places")
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
       f"{sum(len(v) for v in docs.values())} stated default(s) cross-checked, "
       f"{len(enforced)} `enforced_in` address(es) resolved against the source under {gates_rel}/, "
       f"{fails} finding(s)")
if fails:
    out("FAILS", "")
PY
}

# bite <repo-root> <ledger> [only-knob] — check 6.
#
# Moves every `budget` knob to its extremes and re-runs the gate its `enforced_in`
# names. Speaks the same `rc|message` protocol as measure(), so the caller reads
# both with one loop. It is the only part of this gate that executes another gate:
# it exports EHS_BITE_PROBE=1 so a probed gate can tell it is being probed, it
# refuses to probe a knob whose `enforced_in` is this file, and every run has a
# timeout - a gate that hangs is a 2, not a wait.
bite() {
  python3 - "$1" "$2" "${3:-}" <<'PY'
import json, os, pathlib, subprocess, sys

root = pathlib.Path(sys.argv[1]).resolve()
ledger_path = pathlib.Path(sys.argv[2])
only = sys.argv[3]

SELF = "gate-budget-ledger.sh"
TIMEOUT = 120
# Tried in this order, stopping at the first point that moves the verdict. 0 and
# 999999999 first because they are the two a gate is least likely to reject; -1
# last because it is both the rarest winner and the likeliest to be refused
# outright, and a point that is never reached cannot misfire. See the header.
POINTS = ("0", "999999999", "-1")

def out(rc, msg):
    print(f"{rc}|{msg}")

try:
    knobs = json.loads(ledger_path.read_text(encoding="utf-8"))["knobs"]
    if not isinstance(knobs, dict):
        raise ValueError("`knobs` is not an object")
except (OSError, ValueError, KeyError) as exc:
    out(2, f"the bite probe could not read the ledger ({ledger_path}): {exc}")
    raise SystemExit

budgets = [(k, v) for k, v in sorted(knobs.items())
           if isinstance(v, dict) and v.get("kind") == "budget" and (not only or k == only)]
if not budgets:
    named = f" named {only}" if only else ""
    out(2, f"the bite probe found no `budget` knob to probe{named}: it read nothing, which is "
           f"not the same as finding nothing wrong")
    raise SystemExit

def run(target, knob=None, value=None, extra=None):
    """rc of the enforcing gate, or None if it could not be run to completion."""
    env = dict(os.environ)
    for name in knobs:          # a knob exported in the caller's shell must not
        env.pop(name, None)     # become the baseline this probe measures against
    env["EHS_BITE_PROBE"] = "1"
    # The declared path is opened for the BASELINE as well as for the extremes.
    # Opening it only for the extremes would compare two different runs and read
    # the difference between them as a bite.
    for name, val in (extra or {}).items():
        env[str(name)] = str(val)
    if knob is not None:
        env[knob] = value
    try:
        return subprocess.run(["bash", str(target)], cwd=str(root), env=env,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                              timeout=TIMEOUT).returncode
    except (subprocess.TimeoutExpired, OSError):
        return None

bites = blunt = unmeasured = 0
for knob, entry in budgets:
    rel = str(entry.get("enforced_in") or "")
    target = root / rel if rel else None
    if not rel or not target.is_file():
        out(2, f"{knob}: `enforced_in` says {rel!r} and no such file exists under {root.name}/, so "
               f"whether this bound bites was NOT MEASURED - which is not the same as it biting")
        unmeasured += 1
        continue
    if target.name == SELF:
        out(2, f"{knob}: `enforced_in` is this gate itself and probing it would recurse, so whether "
               f"this bound bites was NOT MEASURED")
        unmeasured += 1
        continue

    pe = entry.get("probe_env")
    if pe is not None and not isinstance(pe, dict):
        out(2, f"{knob}: `probe_env` is {type(pe).__name__} and not an object of environment "
               f"variables, so the probe does not know what to export and whether this bound "
               f"bites was NOT MEASURED")
        unmeasured += 1
        continue

    base = run(target, extra=pe)
    if base not in (0, 1):
        seen = "a timeout or a failure to start" if base is None else f"rc={base}"
        out(2, f"{knob}: {rel} answered {seen} at the declared value, so there is no verdict for the "
               f"bound to move and whether it bites was NOT MEASURED")
        unmeasured += 1
        continue

    trail, moved = [], None
    for value in POINTS:
        rc = run(target, knob, value, extra=pe)
        trail.append(f"{value}->{'timeout' if rc is None else rc}")
        if rc in (0, 1) and rc != base:
            moved = (value, rc)
            break
    trail = " ".join(trail)

    shown = " ".join(f"{k}={v}" for k, v in sorted(pe.items())) if pe else ""
    if moved:
        value, rc = moved
        via = f" on the declared path [{shown}]" if shown else ""
        out(0, f"{knob} bites{via}: {rel} answers rc={base} at the declared {entry.get('value')!r} "
               f"and rc={rc} with the knob at {value}  [{trail}]")
        bites += 1
    elif "->2" in trail or "->timeout" in trail:
        out(2, f"{knob}: {rel} could not measure at one or more extremes [{trail}] and no other "
               f"extreme moved its verdict, so whether this bound bites was NOT MEASURED. An "
               f"unprobed bound is not a proved one")
        unmeasured += 1
    elif pe is None:
        out(2, f"{knob}: {rel} answers rc={base} at the declared {entry.get('value')!r} and rc={base} "
               f"at every extreme [{trail}], and the ledger declares no `probe_env`. A bound that "
               f"decides nothing and a comparison this run never reaches look identical from here, "
               f"so whether this bound bites was NOT MEASURED. Declare the environment that opens "
               f"the comparison - empty if the default run already reaches it - or delete a knob "
               f"nobody can show doing anything")
        unmeasured += 1
    else:
        opened = (f" with the declared path open [{shown}]" if shown
                  else " and the entry declaring the default run already reaches the comparison")
        out(1, f"{knob}: {rel} answers rc={base} at the declared {entry.get('value')!r} and rc={base} "
               f"at every extreme [{trail}]{opened}. The comparison was declared reachable and "
               f"moving the bound still changed nothing, so the bound decides nothing. Checks 1-5 "
               f"pass in that case, which is the whole reason this one exists")
        blunt += 1

out(0, f"bite probe: {len(budgets)} budget knob(s) moved to 0 / 999999999 / -1 - {bites} bite, "
       f"{blunt} do not, {unmeasured} NOT MEASURED")
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
    # "scripts/gates" is spelled out here and derived in the production path: the
    # case tree is a flat copy of the gates directory, and the ledger inside it
    # still declares repository-relative addresses. Asking the copy where it
    # lives would compare the ledger with itself.
    out="$(measure "$w" "$w/data/budget-ledger.json" "scripts/gates" 2>&1)"; rc=0
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

  echo "  == the address the ledger gives for a bound =="
  run_case enforced-in-names-a-different-gate 1 "and the knob is read in" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"data/budget-ledger.json"
d=json.loads(p.read_text())
e=d["knobs"]["EHS_MAX_TREE_BYTES"]
assert e["enforced_in"]=="scripts/gates/gate-plugin-integrity.sh"
# a real gate, which really exists, and which does not read this knob
e["enforced_in"]="scripts/gates/gate-tree-delta.sh"
p.write_text(json.dumps(d,indent=2))'

  run_case enforced-in-emptied-on-one-knob 1 "missing or empty" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"data/budget-ledger.json"
d=json.loads(p.read_text()); d["knobs"]["EHS_MIN_XREFS"]["enforced_in"]="  "
p.write_text(json.dumps(d,indent=2))'

  run_case the-same-knob-read-in-two-gates 1 "cannot describe two controls" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"gate-tree-delta.sh"
# assembled from parts: a literal here would be scanned out of this very file
p.write_text(p.read_text()+"\nSECOND=\"$" + "{EHS_MIN_XREFS:-2}\"\n")'

  echo "  == could not measure =="
  run_case nobody-declares-where-a-bound-is-enforced 2 "check 5 read nothing" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"data/budget-ledger.json"
d=json.loads(p.read_text())
for e in d["knobs"].values(): e.pop("enforced_in",None)
p.write_text(json.dumps(d,indent=2))'

  run_case ledger-missing 2 "missing or unusable" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"data/budget-ledger.json").unlink()'

  run_case ledger-unparseable 2 "missing or unusable" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"data/budget-ledger.json").write_text("{")'

  # The frame of reference itself. run_case always hands check 5 a usable one, so
  # the branch that refuses to guess is exercised here or nowhere.
  local fr fr_out fr_rc
  for fr in "" "/private/tmp/somewhere"; do
    fr_out="$(measure "$GATES_DIR" "$LEDGER" "$fr" 2>&1)"; fr_rc=0
    printf '%s' "$fr_out" | grep -q '^1|' && fr_rc=1
    printf '%s' "$fr_out" | grep -q '^2|' && fr_rc=2
    if [ "$fr_rc" -eq 2 ] && printf '%s' "$fr_out" | grep -q "how the ledger spells"; then
      printf '  PASS  %-46s rc=2\n' "no-frame-of-reference[${fr:-empty}]"; p=$((p+1))
    else
      printf '  FAIL  %-46s rc=%s (wanted 2)\n' "no-frame-of-reference[${fr:-empty}]" "$fr_rc"
      printf '%s\n' "$fr_out" | sed 's/^/        /' | head -3; f=$((f+1))
    fi
  done
  # -- check 6, proved in the negative ---------------------------------------
  # run_case copies scripts/gates/ and that is enough for measure(), which only
  # READS files. The bite probe RUNS gates, and those gates read skills/, agents/
  # and the rest, so its cases need a copy of the whole tree. .git is left out:
  # nothing probed here needs it, and in a work tree it is a file, not a
  # directory. Both cases are filtered to ONE knob on the cheapest enforcing gate
  # (gate-benign-control.sh, 0.1 s a run), so the negative proof costs ~2 s.
  run_bite_case() {
    local name="$1" knob="$2" want="$3" needle="$4" mut="$5"
    local w="$tmp/$name"
    command rm -rf "$w"; mkdir -p "$w"
    (cd "$ROOT" && tar -cf - --exclude .git . 2>/dev/null) | (cd "$w" && tar -xf - 2>/dev/null)
    if [ ! -f "$w/scripts/gates/data/budget-ledger.json" ]; then
      printf '  HARNESS  %-44s the copy of the tree did not arrive\n' "$name"; f=$((f+1)); return
    fi
    if [ -n "$mut" ] && ! EHS_WORK="$w" python3 -c "$mut" >/dev/null 2>&1; then
      printf '  HARNESS  %-44s the mutation itself failed\n' "$name"; f=$((f+1)); return
    fi
    local out rc
    out="$(bite "$w" "$w/scripts/gates/data/budget-ledger.json" "$knob" 2>&1)"; rc=0
    printf '%s' "$out" | grep -q '^1|' && rc=1
    printf '%s' "$out" | grep -q '^2|' && rc=2
    if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
      printf '  PASS  %-46s rc=%s\n' "$name" "$rc"; p=$((p+1))
    else
      printf '  FAIL  %-46s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
      printf '%s\n' "$out" | sed 's/^/        /' | head -4; f=$((f+1))
    fi
  }

  echo "  == a bound that bites, and the same bound with its comparison removed =="
  # The control comes first on purpose. Without it, the mutant's red proves only
  # that something in a copied tree is unhappy; with it, the red is attributable
  # to the one line the mutation changed.
  run_bite_case bite-sees-a-live-floor EHS_MIN_XREFS 0 "bites" ""

  # PREDICTION, written before this was first run: with the comparison replaced
  # by a test that is always favourable, EHS_MIN_XREFS stops deciding anything,
  # no extreme moves gate-benign-control.sh off rc 0, and the probe must go RED
  # saying so. If it survived this, it would not be measuring bite at all.
  #
  # The mutant also writes an empty `probe_env` on the entry, which is the ledger
  # asserting that the default run already reaches the comparison. That assertion
  # is what makes a dead bound a measured FAILURE here rather than the 2 of the
  # case below: the probe never has to guess which of the two it is looking at.
  #
  # SC2016 is disabled deliberately: `$N_XREFS` and `$MIN_XREFS` below must reach
  # python UNEXPANDED, because they are the literal bash text this mutant looks
  # for in gate-benign-control.sh. Double quotes here would expand them to the
  # empty string, `old` would not be found, and the assert would turn that into a
  # loud HARNESS failure instead of a quiet mutation that changed nothing.
  # shellcheck disable=SC2016
  run_bite_case bite-catches-a-neutralised-comparison EHS_MIN_XREFS 1 \
    "moving the bound still changed nothing" '
import os,pathlib,json
w=pathlib.Path(os.environ["EHS_WORK"])
p=w/"scripts/gates/gate-benign-control.sh"
t=p.read_text()
old="if [ \"$N_XREFS\" -ge \"$MIN_XREFS\" ]; then"
assert t.count(old)==1, "the comparison to neutralise is not where this mutant thinks it is"
p.write_text(t.replace(old,"if [ 1 -eq 1 ]; then",1))
lp=w/"scripts/gates/data/budget-ledger.json"
d=json.loads(lp.read_text())
d["knobs"]["EHS_MIN_XREFS"]["probe_env"]={}
lp.write_text(json.dumps(d,indent=2))'

  # PREDICTION, written before this was first run: the SAME neutralised
  # comparison with no `probe_env` on the entry must come back 2, not 1. From
  # inside the probe a bound nothing reaches and a bound nothing compares look
  # identical, and the older code called both of them a failure - which is how
  # gate-tree-delta.sh's bot budget, unreachable on any branch that is not
  # bot/*, was accused of deciding nothing on a repository where it decides
  # plenty. If this case ever comes back 1, the probe is once more claiming a
  # measurement it does not have.
  # shellcheck disable=SC2016
  run_bite_case bite-will-not-call-an-unreached-bound-dead EHS_MIN_XREFS 2 \
    "look identical from here" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/gate-benign-control.sh"
t=p.read_text()
old="if [ \"$N_XREFS\" -ge \"$MIN_XREFS\" ]; then"
assert t.count(old)==1, "the comparison to neutralise is not where this mutant thinks it is"
p.write_text(t.replace(old,"if [ 1 -eq 1 ]; then",1))'

  # PREDICTION, written before this was first run: with the comparison put
  # behind an environment variable and that variable declared in `probe_env`,
  # the probe must REACH it and report the bound as biting - rc 0. Unreached,
  # this same tree is the case above and answers 2, so a 0 here can only come
  # from the declared environment being exported on both the baseline and the
  # extremes. This is the whole mechanism, proved in the one direction that
  # cannot be faked by the gate simply being lenient.
  # shellcheck disable=SC2016
  run_bite_case bite-reaches-a-comparison-behind-a-declared-context EHS_MIN_XREFS 0 \
    "on the declared path" '
import os,pathlib,json
w=pathlib.Path(os.environ["EHS_WORK"])
p=w/"scripts/gates/gate-benign-control.sh"
t=p.read_text()
old="if [ \"$N_XREFS\" -ge \"$MIN_XREFS\" ]; then"
assert t.count(old)==1, "the comparison to gate is not where this mutant thinks it is"
new="if [ \"${EHS_BITE_PATH:-shut}\" != \"open\" ] || [ \"$N_XREFS\" -ge \"$MIN_XREFS\" ]; then"
p.write_text(t.replace(old,new,1))
lp=w/"scripts/gates/data/budget-ledger.json"
d=json.loads(lp.read_text())
d["knobs"]["EHS_MIN_XREFS"]["probe_env"]={"EHS_BITE_PATH":"open"}
lp.write_text(json.dumps(d,indent=2))'

  command rm -rf "$tmp"
  echo "  $p PASS / $f FAIL"
  [ "$f" -eq 0 ] || return 1
  return 0
}

if [ "$ONLY_SELFTEST" -eq 1 ]; then
  selftest; exit $?
fi

gate_header "budget-ledger (a bound may not move without the figure that moved it)"
gate_scope "every \${EHS_*:-<number>} a gate reads, against scripts/gates/data/budget-ledger.json - its value, its \`enforced_in\` address, and every comment in the source that states a default for it - and, for each \`budget\`, against the verdict of the gate that \`enforced_in\` names, with the bound moved to its extremes"
gate_out_of_scope "whether a 'measured' claim is TRUE, and the DIRECTION of a change - this gate has no history at gate time and does not pretend to tell a raise from a tightening. The bite probe is also out of scope for the three \`not_a_budget\` knobs: they are mode switches, not bounds, and moving a switch to an extreme measures nothing"

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
done < <(measure "$GATES_DIR" "$LEDGER" "$GATES_REL")

echo "== does each declared bound actually BITE? =="
if [ "${EHS_BITE_PROBE:-}" = "1" ]; then
  # Only ever set by this gate's own probe. Seeing it here means something is
  # running this gate from inside a probe, and probing on would recurse.
  gate_warn "EHS_BITE_PROBE=1: this run is already inside a bite probe, so check 6 did NOT run"
  [ "$RC" -eq 0 ] && RC=2
else
  while IFS= read -r line; do
    code="${line%%|*}"; msg="${line#*|}"
    case "$code" in
      0) [ -n "$msg" ] && gate_info "$msg" ;;
      1) gate_fail "$msg"; RC=1 ;;
      2) gate_warn "$msg"; [ "$RC" -eq 0 ] && RC=2 ;;
    esac
  done < <(bite "$ROOT" "$LEDGER" "")
fi

echo "NOT MEASURED: whether a 'measured' claim is true. A gate cannot re-run the reasoning that"
echo "              justified a number; it enforces that the claim exists beside it and that the"
echo "              number is the same everywhere this repository states it."
echo "NOT MEASURED: whether a bound that bites bites at the RIGHT number. Check 6 proves the bound"
echo "              reaches a live comparison; the figure itself is argued for in \`measured\`, and"
echo "              no gate can re-run that argument."

if [ "$SELFTEST_SKIPPED" -eq 1 ] && [ "$RC" -eq 0 ]; then RC=2; fi
gate_verdict "$RC"; exit "$RC"
