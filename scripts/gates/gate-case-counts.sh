#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-case-counts.sh — the figures the documentation quotes about the size of
# a battery, measured by RUNNING that battery.
#
# WHY IT EXISTS
#   docs/gate-requirements.md quotes 23 case counts of the form `N cases` beside
#   the name of a battery, and docs/competitive-analysis.md quotes 3 more.
#   Nothing measured any of them. Measured 2026-09-11 on this tree, five of
#   those figures were already false: `11 cases` for a battery that runs 16,
#   `10` for one that runs 12, `9` for one that runs 23, `25` for one that runs
#   32, and the aggregate `57` for four that now run 59. Four went false on a
#   single branch of iteration 4 and a fifth expired when two branches crossed.
#
#   A reader has no way to tell a live figure from an expired one, and neither
#   has a reviewer: a number in prose looks exactly as authoritative when it is
#   wrong. This is the last drift pattern in this repository with no gate on it.
#
# WHAT IT MEASURES
#   In the documents declared by scripts/gates/data/case-counts.json:
#
#   1. Every `<!-- cases: PATH -->` marker. The figure it governs is the LAST
#      integer on that line before the marker — so the marker goes IMMEDIATELY
#      after the figure, not at the end of the line. A marker with no integer
#      before it on its line is exit 2, and so is one naming a file that is not
#      on disk. The number lives ONLY in the prose: the marker does not repeat
#      it, because two copies of a figure are two things that can drift apart.
#
#   2. The real count, read off the battery's own summary line after running it.
#      Three families are recognised, in the five spellings this tree actually
#      prints (measured, not guessed):
#          `  10 PASS / 0 FAIL`
#          `--- 9 passed, 0 failed ---`      (adornment optional)
#          `29 passed, 0 failed`
#          `Summary: 23 ok, 0 failures`
#          `Summary: 23 ok, 0 failure(s)`
#      THE HARD RULE: output with no line this gate recognises, or with two
#      DIFFERENT totals in it, is exit 2 — never a pass. A shape I do not know
#      is a shape I did not measure, and an unmeasured count is not a correct
#      one. That is also what makes adding a sixth spelling visible instead of
#      silent.
#
#      THE TOTAL IS passed + failed + skipped, NOT passed. A failing case is
#      still a case, and so is one skipped with a declared reason: the documents
#      quote the SIZE of a battery, not how much of it ran on today's machine.
#      This was not foresight, it was a bug this gate shipped with and CI found:
#      gate-reproduction.selftest.sh has 33 cases, one of which asks sandbox-exec
#      to deny the network. On macOS 33 run; on Linux that one prints a skip with
#      its reason and the battery prints `32 passed`. Comparing against `passed`
#      alone, this gate called a TRUE citation false on ubuntu and would have
#      called it true here — a verdict that depends on the runner, which is not
#      a measurement. See CASE_SKIP / LEAD_SKIP below for the spellings, which
#      were swept out of the tree rather than guessed, and for why a skip shape
#      this gate cannot read is exit 2 instead of a silently smaller total.
#
#      How a battery is invoked is derived from its name, in one place: a file
#      named `*.selftest.sh` is run as `bash PATH`; anything else is a gate
#      carrying an inline self-test and is run as `bash PATH --self-test`.
#      Each distinct battery is run ONCE per invocation and its total reused,
#      because several citations point at the same battery.
#
#   3. Citations that carry NO marker. Without this half the gate approves by
#      omission: an author adds `(12 cases)` with no marker, nothing measures
#      it, and the gate stays green. So unmarked citations are COUNTED and
#      compared against `unmarked_ceiling` in the data file — a RATCHET that
#      only goes down. More unmarked citations than declared is exit 1. They
#      are printed line by line on EVERY run, green included: a tolerance
#      nobody can see is a tolerance nobody removes. Why the tolerance is not
#      zero, citation by citation, is written in the data file.
#
# WHAT IT DOES NOT MEASURE, and will not pretend to
#   Whether a battery PASSES. That is run-batteries.sh's question, and this gate
#   reports the battery's exit code as information and does not judge it: a
#   battery that fails still ran the number of cases it ran. Nor whether a case
#   is any good — counting cases cannot answer that, and a gate implying it
#   could would be worse than none.
#
# IT REFUSES TO MEASURE ITSELF
#   A marker pointing at this gate's own battery would make the gate run the
#   battery that runs the gate: recursion, not measurement. That path is
#   refused with a reason and counted as exit 2.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure. When both a failure and an unmeasurable appear, the verdict is 1 and
# both are printed — the same rule run-all.sh applies to gates.
#
# Usage:
#   scripts/gates/gate-case-counts.sh
#   scripts/gates/gate-case-counts.sh --root DIR --data FILE --timeout SECONDS
#
# Environment variables:
#   EHS_REPO_ROOT   root to sweep (default: the repository root)
#
# WHAT THIS COSTS, MEASURED, because a number nobody wrote down is a number
# nobody can act on. Measured 2026-09-11 on this tree: 411 s wall clock over
# the 20 distinct batteries the migrated documents cite, of which 342 s is the
# batteries themselves (slowest: gate-reproduction 64 s, gate-protected-paths
# 43 s, gate-bench-integrity 34 s) and the rest is process start-up. Each
# battery is run ONCE however many citations point at it - memoised - so the
# figure is the sum of the batteries, not of the citations. On a tree with no
# markers it costs 0 s, because it runs nothing.
#
# 411 s IS TOO MUCH FOR THE PUSH PATH. This repository's written rule - cited
# by gate-budget-ledger.sh in its own header - is that anything over ~30 s does
# not belong in the serial suite, and the CI `gates` job takes 45 s today. This
# gate must therefore be declared BY NAME in a scope of its own in run-all.sh
# (the pattern exists: LIVE_SCOPED) and wired to a CI job of its own running in
# parallel with `gates`, so the push clock does not grow and the control still
# runs on every pull request. Neither of those two files is this author's to
# edit; both are named in the handover rather than left implied. Until that
# wiring lands THIS GATE RUNS NOWHERE, which is the failure mode it was written
# to prevent, so it is the first thing to check if this header is still here.
#
# Nesting, since this gate EXECUTES other gates' batteries: the nesting is one
# level deep and cannot recurse. A marker naming this gate's own battery is
# refused with a reason and counted as exit 2 (case
# `a-marker-pointing-at-this-battery-is-refused`), so run-all.sh --selftests ->
# this battery -> this gate cannot re-enter this battery. No recursion guard of
# the EHS_..._PROBE kind is needed; the refusal is the guard, and it is proved.
# What the nesting DOES cost is real: once the markers land, the real-tree
# control inside this gate's own battery pays the full 411 s. That control is
# the case that would notice a citation going false in the repository itself,
# so it is not deleted - but if this battery's own budget matters more than
# that, bound the control rather than the gate.
#
# THE WATCHDOG IS A FLAG, NOT AN ENVIRONMENT KNOB, and that is a decision
# rather than an oversight, so it is written here where a reviewer can overrule
# it. A battery that hangs must become exit 2 instead of hanging the suite, and
# 300 s is the bound: the slowest battery in this tree measured 35 s on
# 2026-09-11. Written instead as an EHS_-prefixed expansion with a numeric
# default, it would become a knob of gate-budget-ledger.sh, whose check 5
# probes every `budget` knob by moving it to its extremes and RUNNING the gate
# that enforces it - twice. This gate runs every battery the documents cite,
# ~200 s a run measured the same day, so that probe would add ~400 s to the
# push path to learn what one case in this gate's own battery already proves
# (`a-battery-that-does-not-finish-is-unmeasurable`). If that trade is the wrong
# one, the fix is one line here plus an entry in
# scripts/gates/data/budget-ledger.json - never a quieter gate.
# (The knob spelling is deliberately not written out anywhere in this file:
# that scanner reads comments too, and a knob that exists only in prose is a
# ledger entry nobody can enforce.)
#
# Negative proof: scripts/gates/gate-case-counts.selftest.sh
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
DATA="$HERE/data/case-counts.json"
TIMEOUT=300

while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --data) DATA="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,91p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

# Backticks are deliberately absent from this string: inside a double-quoted
# argument they are command substitution, not quotation marks.
gate_header "case-counts (every case count the docs quote, measured by running the battery)"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was checked"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$DATA" ]; then
  gate_warn "the scope declaration $DATA is missing: I do not know what to sweep"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

# The gate's own battery, so a marker can never point the gate at itself.
SELF_BATTERY="scripts/gates/gate-case-counts.selftest.sh"

RC=""
OUTPUT="$(
  EHS_CC_ROOT="$ROOT" EHS_CC_DATA="$DATA" EHS_CC_TIMEOUT="$TIMEOUT" \
  EHS_CC_SELF_BATTERY="$SELF_BATTERY" python3 - <<'PY'
import json, os, pathlib, re, subprocess, sys

ROOT = pathlib.Path(os.environ["EHS_CC_ROOT"])
DATA = pathlib.Path(os.environ["EHS_CC_DATA"])
SELF_BATTERY = os.environ.get("EHS_CC_SELF_BATTERY", "")
try:
    TIMEOUT = int(os.environ.get("EHS_CC_TIMEOUT", "300"))
except ValueError:
    TIMEOUT = 300

def emit(kind, text):
    print("%s\t%s" % (kind, text))

# A citation: a figure in prose describing the size of something, `7 case(s)`.
CITATION = re.compile(r"\b(\d+)\s+cases?\b")
# The marker that binds a citation to the battery it is about.
MARKER = re.compile(r"<!--\s*cases:\s*(\S+?)\s*-->")
INTEGER = re.compile(r"\d+")
# Colour never reaches a pipe here (common.sh checks for a TTY), but a battery
# that colours unconditionally would hide its own total behind escape bytes.
ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")

# The three families, in the five spellings measured on this tree. Anchored to a
# WHOLE line on purpose: batteries print per-case lines containing `PASS` and
# `FAIL`, and a loose match would read a case for a total.
FAMILIES = (
    ("N PASS / M FAIL",
     re.compile(r"^\s*(?:[-=]{3,}\s*)?(\d+)\s*PASS\s*/\s*(\d+)\s*FAIL(?:\s*[-=]{3,})?\s*$")),
    ("N passed, M failed",
     re.compile(r"^\s*(?:[-=]{3,}\s*)?(\d+)\s+passed,\s*(\d+)\s+failed(?:\s*[-=]{3,})?\s*$")),
    ("Summary: N ok, M failure(s)",
     re.compile(r"^\s*Summary:\s*(\d+)\s+ok,\s*(\d+)\s+(?:failures?|failure\(s\))\s*$")),
)
FAMILY_NAMES = " | ".join(name for name, _ in FAMILIES)

# A SKIPPED CASE IS STILL A CASE. The figure the documents quote is the SIZE of
# a battery, not how many of its cases happened to run on today's machine, and
# the difference is not academic: gate-reproduction.selftest.sh has 33 cases, of
# which one asks sandbox-exec to deny the network. On macOS all 33 run. On Linux
# that one prints a skip with its reason and the battery prints `32 passed`, so
# a gate comparing against `passed` alone called a TRUE citation false on CI and
# would have called it true on this Mac. A verdict that depends on the runner is
# not a measurement. The total is therefore passed + failed + skipped.
#
# The two expressions below were derived by SWEEPING the tree for every spelling
# it emits (2026-09-11), not by guessing one:
#   `skip     <case name>`     gate-reproduction.selftest.sh
#   `  skip  <case name>`      gate-agent-tools.selftest.sh
#   `  SKIP  <case name>`      scripts/meter/meter.selftest.sh
# In all three the skip is printed INSTEAD of running the case and the battery's
# own counter is not incremented — verified by reading each branch. The verdict
# word leads the line bare, exactly as `ok` and `FAILED` do in those same files.
CASE_SKIP = re.compile(r"^\s*skip\b[ \t]+\S", re.I)

# And the shapes that are skip-ish but are NOT a battery case. Measured on this
# tree: gate-plugin-integrity.sh and gate-plugin-version.sh print `  [SKIP] ...`
# per check and a `  skipped in this run: N` footer — those belong to a GATE,
# not to the battery running it, and counting them would inflate a true citation
# into a false one. Today no battery surfaces them (their batteries capture gate
# stdout; measured: zero occurrences in all 23 battery logs). If one ever does,
# this gate must say SO rather than guess: a total that silently drops skips it
# cannot read is a total that lies DOWNWARD, which is the failure this whole
# block exists to prevent. Anything skip-shaped at the head of a line that
# CASE_SKIP did not claim is therefore exit 2, never a quiet pass.
LEAD_SKIP = re.compile(r"^\s*[\[(]?\s*skip\w*\b", re.I)

try:
    spec = json.loads(DATA.read_text(encoding="utf-8"))
except Exception as exc:
    emit("WARN", "the scope declaration %s will not parse: %s" % (DATA, exc))
    emit("RC", "2")
    sys.exit(0)

docs = spec.get("docs")
ceiling = spec.get("unmarked_ceiling")
if not isinstance(docs, list) or not docs or not isinstance(ceiling, int):
    emit("WARN", "%s must declare a non-empty `docs` list and an integer "
                 "`unmarked_ceiling`; I will not guess either" % DATA)
    emit("RC", "2")
    sys.exit(0)

MEMO = {}

def invocation(rel):
    # ONE rule, written once: a `*.selftest.sh` is a battery; anything else is a
    # gate whose battery is inline behind --self-test.
    path = str(ROOT / rel)
    if rel.endswith(".selftest.sh"):
        return ["bash", path]
    return ["bash", path, "--self-test"]

def measure(rel):
    """Run the battery once and read its total. ('ok', n, line, rc) or ('err', why)."""
    if rel in MEMO:
        return MEMO[rel]
    target = ROOT / rel
    if os.path.normpath(rel) == os.path.normpath(SELF_BATTERY):
        result = ("err", "%s is this gate's OWN battery: running it would make the "
                         "gate run the battery that runs the gate, which recurses "
                         "instead of measuring" % rel)
    elif not target.is_file():
        result = ("err", "the marker names `%s` and there is no such file on disk" % rel)
    else:
        try:
            proc = subprocess.run(invocation(rel), cwd=str(ROOT),
                                  stdin=subprocess.DEVNULL,
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                  timeout=TIMEOUT)
            text = ANSI.sub("", proc.stdout.decode("utf-8", "replace"))
            totals, shown, skipped, puzzling = [], [], 0, []
            for line in text.splitlines():
                hit = None
                for _, rx in FAMILIES:
                    hit = rx.match(line)
                    if hit:
                        break
                if hit:
                    # A failing case is still a case: the figure is the SIZE.
                    totals.append(int(hit.group(1)) + int(hit.group(2)))
                    shown.append(line.strip())
                elif CASE_SKIP.match(line):
                    skipped += 1
                elif LEAD_SKIP.match(line):
                    puzzling.append(line.strip())
            distinct = sorted(set(totals))
            if puzzling:
                result = ("err", "%s printed %d line(s) that look like a skipped case "
                                 "in a shape I cannot read, the first being `%s`. A "
                                 "total that drops skips it does not understand lies "
                                 "DOWNWARD, so this is not measured, not a pass"
                                 % (rel, len(puzzling), puzzling[0]))
            elif not distinct:
                result = ("err", "%s printed no summary line I recognise (%s). An "
                                 "output shape I do not know is NOT a pass" % (rel, FAMILY_NAMES))
            elif len(distinct) > 1:
                result = ("err", "%s printed %d different totals (%s): I cannot tell "
                                 "which one is this battery's" %
                                 (rel, len(distinct), ", ".join(str(d) for d in distinct)))
            else:
                result = ("ok", distinct[0] + skipped, shown[0], proc.returncode,
                          distinct[0], skipped)
        except subprocess.TimeoutExpired:
            result = ("err", "%s did not finish within %ds" % (rel, TIMEOUT))
        except OSError as exc:
            result = ("err", "%s could not be launched: %s" % (rel, exc))
    MEMO[rel] = result
    return result

failed = False
unmeasurable = False
unmarked_all = []
checked = 0

for doc in docs:
    path = ROOT / doc
    if not path.is_file():
        emit("WARN", "%s is declared in the scope and is not on disk" % doc)
        unmeasurable = True
        continue
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError as exc:
        emit("WARN", "%s could not be read: %s" % (doc, exc))
        unmeasurable = True
        continue

    for lineno, line in enumerate(lines, 1):
        cits = [(m.start(), int(m.group(1)), m.group(0)) for m in CITATION.finditer(line)]
        marks = [(m.start(), m.group(1)) for m in MARKER.finditer(line)]
        if not cits and not marks:
            continue

        # A citation counts as MARKED when the very next token on its line is a
        # marker. Positional, not per-line: two citations and one marker on one
        # line must not let the unmarked one hide behind the marked one.
        tokens = sorted([(s, "c", i) for i, (s, _, _) in enumerate(cits)] +
                        [(s, "m", j) for j, (s, _) in enumerate(marks)])
        marked = set()
        for k, (_, kind, idx) in enumerate(tokens):
            if kind == "c" and k + 1 < len(tokens) and tokens[k + 1][1] == "m":
                marked.add(idx)
        for i, (_, number, text) in enumerate(cits):
            if i not in marked:
                unmarked_all.append((doc, lineno, text))

        for start, rel in marks:
            before = INTEGER.findall(line[:start])
            if not before:
                emit("WARN", "%s:%d  the marker for `%s` has no figure before it on "
                             "its line: there is nothing to compare" % (doc, lineno, rel))
                unmeasurable = True
                continue
            cited = int(before[-1])
            result = measure(rel)
            if result[0] == "err":
                emit("WARN", "%s:%d  %s" % (doc, lineno, result[1]))
                unmeasurable = True
                continue
            _, total, summary, battery_rc, ran, skipped = result
            checked += 1
            agree = (cited == total)
            # With a skip in play, the bare total does not explain itself: the
            # summary line says 32 and the gate says 33. Show the arithmetic, or
            # the reader cannot tell a correct verdict from a broken one.
            how = ("%d = %d run + %d skipped" % (total, ran, skipped)) if skipped \
                else str(total)
            if agree:
                emit("OK", "%s:%d  `%s` cites %d and runs %s  [%s, battery rc=%d]"
                           % (doc, lineno, rel, cited, how, summary, battery_rc))
            else:
                emit("FAIL", "%s:%d  `%s` is cited as %d cases and runs %s  [%s, "
                             "battery rc=%d]" % (doc, lineno, rel, cited, how,
                                                 summary, battery_rc))
                failed = True

emit("INFO", "%d marked citation(s) measured by running %d distinct batter(ies)"
             % (checked, len(MEMO)))

# The ratchet. Printed line by line on every run, green included.
emit("INFO", "%d citation(s) carry no marker, against a declared ceiling of %d"
             % (len(unmarked_all), ceiling))
for doc, lineno, text in unmarked_all:
    emit("INFO", "    unmarked  %s:%d  `%s`" % (doc, lineno, text))
if len(unmarked_all) > ceiling:
    emit("FAIL", "%d citation(s) carry no marker and the declared ceiling is %d. An "
                 "unmarked figure is a figure nobody measures; mark it, or raise the "
                 "ceiling in %s and say there why" %
                 (len(unmarked_all), ceiling, DATA.name))
    failed = True
elif len(unmarked_all) < ceiling:
    emit("INFO", "the ceiling has slack: %d declared, %d found. It is a ratchet - "
                 "lower it in %s and the hole closes for good"
                 % (ceiling, len(unmarked_all), DATA.name))

if failed:
    emit("RC", "1")
elif unmeasurable:
    emit("RC", "2")
else:
    emit("RC", "0")
PY
)"
PY_RC=$?

gate_scope "$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(", ".join(d["docs"]) + "  (ceiling of unmarked citations: " + str(d["unmarked_ceiling"]) + ")")' "$DATA" 2>/dev/null || echo "$DATA")"
gate_out_of_scope "whether a battery PASSES (that is run-batteries.sh) and whether its cases are any good - counting cases cannot answer that"

while IFS=$'\t' read -r kind text; do
  case "$kind" in
    OK)   gate_ok   "$text" ;;
    FAIL) gate_fail "$text" ;;
    WARN) gate_warn "$text" ;;
    INFO) gate_info "$text" ;;
    RC)   RC="$text" ;;
    *)    [ -n "$kind" ] && gate_log "$kind $text" ;;
  esac
done <<EOF
$OUTPUT
EOF

# The scanner is the only thing that measures anything here, so its silence is
# never a pass. A crash (traceback on stderr, no RC line on stdout) and an empty
# result look identical to a caller that only reads the exit code, and the one
# that reads neither reports green. Both are caught here.
if [ "$PY_RC" -ne 0 ] || [ -z "$RC" ]; then
  gate_warn "the scanner did not report a verdict (exit $PY_RC): nothing was measured"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

case "$RC" in
  0) gate_ok "every marked citation matches the count its battery actually runs" ;;
  1) : ;;
  *) RC=2 ;;
esac

gate_verdict "$RC"
exit "$RC"
