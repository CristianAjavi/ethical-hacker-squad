#!/usr/bin/env python3
"""Mutation bank for the gate that checks the case counts in the requirements.

WHY A BANK AND NOT MORE CASES
    `gate-declared-case-counts` and the tally ledger it reads are both green.
    Green says the cases ran, not that they measure anything. Each mutant here
    breaks ONE decision of the core, the wrapper or the runner that writes the
    ledger, and names IN ADVANCE the case that has to go red. A mutant that
    survives is a green case that watches nothing.

WHY IT DOES NOT TOUCH THE REAL TREE
    Every mutant copies the handful of files it needs into its own directory.
    And the gate battery's control case is pointed at a small, faithful toy
    repository rather than the real one, because a mutation of how an invocation
    is resolved can make that control launch the real weekly coverage sweep. The
    first version of this bank died exactly that way, at 900 s.

WHERE IT LIVES
    Deliberately NOT under scripts/gates/: run-all.sh discovers a gate by
    walking that directory and taking whatever is not documentation, data,
    fixtures or lib/, so a bank left there IS a gate.

Exit codes: 0 = every mutant was caught | 1 = one survived | 2 = the bank broke.
"""

from __future__ import annotations

import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor

ROOT = pathlib.Path(__file__).resolve().parent.parent
CORE = "scripts/gates/lib/declared_case_counts.py"
WRAP = "scripts/gates/gate-declared-case-counts.sh"
RUNNER = "scripts/run-batteries.sh"
# The shared counter every gate that has no counter of its own now uses.
COMMON = "scripts/gates/lib/common.sh"

GATE_BATTERY = "scripts/gates/gate-declared-case-counts.selftest.sh"
RUNNER_BATTERY = "scripts/run-batteries.selftest.sh"

# What each battery needs to be able to run at all, once copied out.
NEEDS = {
    GATE_BATTERY: [WRAP, GATE_BATTERY, "scripts/gates/lib/common.sh", CORE],
    RUNNER_BATTERY: [RUNNER, RUNNER_BATTERY],
}

PER_MUTANT_TIMEOUT = 240
WORKERS = 6

# (name, file to mutate, old, new, battery that must notice, the case that dies)
MUTANTS = [
    # --- reading the count -------------------------------------------------
    # The two branches of measure() - ran here, read off the ledger - share these
    # lines, so each anchor carries enough context to name exactly one of them.
    ("the-count-drops-the-failed-cases", CORE,
     '        how = "%s, %d skipped here" % (how, skipped)\n'
     "    return gate, declared, passed + failed + skipped, how",
     '        how = "%s, %d skipped here" % (how, skipped)\n'
     "    return gate, declared, passed + skipped, how",
     GATE_BATTERY, "the-total-is-passed-plus-failed"),
    ("the-first-count-line-wins", CORE,
     "    passed, failed, skipped = (int(x or 0) for x in hits[-1])\n"
     "    if p.returncode != 0:",
     "    passed, failed, skipped = (int(x or 0) for x in hits[0])\n"
     "    if p.returncode != 0:",
     GATE_BATTERY, "the-last-count-line-is-the-summary"),
    ("a-red-battery-counts-the-same", CORE,
     "    if p.returncode != 0:",
     "    if False:",
     GATE_BATTERY, "a-self-test-that-came-back-red"),
    ("no-count-means-zero-cases", CORE,
     "    if not hits:\n        return gate, declared, None, (",
     "    if not hits:\n        return gate, declared, 0, (",
     GATE_BATTERY, "a-self-test-that-says-nothing"),
    ("the-third-number-does-not-count", CORE,
     '        how = "%s, %d skipped here" % (how, skipped)\n'
     "    return gate, declared, passed + failed + skipped, how",
     '        how = "%s, %d skipped here" % (how, skipped)\n'
     "    return gate, declared, passed + failed, how",
     GATE_BATTERY, "a-skipped-case-still-counts-toward-the-row"),
    ("the-skip-is-not-named", CORE,
     '    if skipped:\n        how = "%s, %d skipped here" % (how, skipped)',
     "    if False:\n        how = how",
     GATE_BATTERY, "a-skipped-case-still-counts-toward-the-row"),

    # --- resolving the invocation ------------------------------------------
    ("the-flag-beats-the-sibling", CORE,
     '    sibling = root / GATES / ("%s.selftest.sh" % gate)\n'
     '    if sibling.is_file():\n'
     '        return ["bash", str(sibling)], "sibling battery"\n    src',
     '    src',
     GATE_BATTERY, "the-sibling-battery-beats-the-flag"),
    ("there-is-no-flag", CORE,
     '    if offers_flag(text):\n'
     '        return ["bash", str(src), "--self-test"], "--self-test"',
     '    if False:\n'
     '        return ["bash", str(src), "--self-test"], "--self-test"',
     GATE_BATTERY, "the-flag-when-there-is-no-sibling"),
    ("a-gate-that-is-not-there-runs-anyway", CORE,
     '    if not src.is_file():\n'
     '        return None, "the row names %s.sh and there is no such file" % gate',
     '    if not src.is_file():\n'
     '        return ["bash", str(src)], "inline on a normal run"',
     GATE_BATTERY, "a-row-naming-a-gate-that-is-not-there"),

    # --- one row, more than one gate ---------------------------------------
    ("only-the-first-gate-on-a-row-is-read", CORE,
     "                for m in rx.finditer(line):",
     "                for m in list(rx.finditer(line))[:1]:",
     GATE_BATTERY, "both-gates-on-one-row-are-compared"),
    # THE RULE THAT EVERY GATE DECLARES ONE. Ten gates sat undeclared and
    # unaccused because the reading walks declarations and an absent row
    # declares nothing to walk.
    ("an-undeclared-gate-is-not-a-finding", CORE,
     "    if drifted or uncounted or phantom or clash or undeclared:",
     "    if drifted or uncounted or phantom or clash:",
     GATE_BATTERY, "a-gate-whose-row-declares-no-count"),
    ("the-undeclared-gate-is-never-named", CORE,
     "    for gate in undeclared:",
     "    for gate in []:",
     GATE_BATTERY, "a-gate-whose-row-declares-no-count"),
    # And the other end: demanding a row for every FILE would demand one for
    # each sibling battery, which no gate could ever satisfy.
    ("a-sibling-battery-counts-as-a-gate-of-its-own", CORE,
     '              if not q.name.endswith(".selftest.sh")}',
     '              if q.name}',
     GATE_BATTERY, "a-sibling-battery-is-not-a-gate-of-its-own"),
    # THE SHARED COUNTER. Ten self-tests borrow it, so a counter that miscounts
    # or falls silent takes ten rows down with it, and the only thing that would
    # notice is a run over the real tree.
    ("the-shared-tally-says-nothing", COMMON,
     "gate_tally() {\n  printf -- '--- %d passed, %d failed ---\\n' \\",
     "gate_tally() {\n  : printf -- '--- %d passed, %d failed ---\\n' \\",
     GATE_BATTERY, "my-own-row-says-what-this-battery-runs"),
    ("the-shared-counter-never-advances", COMMON,
     "gate_case() { GATE_CASES=$((GATE_CASES + 1)); }",
     "gate_case() { GATE_CASES=$((GATE_CASES + 0)); }",
     GATE_BATTERY, "my-own-row-says-what-this-battery-runs"),
    ("the-fence-comes-down", CORE,
     'FENCE = r"(?:(?!`(?:[A-Za-z0-9._/-]*/)?gate-[a-z0-9-]+\\.sh`).)*?"',
     'FENCE = r".*?"',
     GATE_BATTERY, "a-count-does-not-cross-to-the-gate-before-it"),
    ("a-second-declaration-replaces-the-first-in-silence", CORE,
     "                    if gate in declared and declared[gate] != n:\n"
     "                        clash.append((gate, declared[gate], n,\n"
     "                                      where.get(gate, doc.name), src.name))",
     "                    if False:\n"
     "                        clash.append((gate, declared[gate], n,\n"
     "                                      where.get(gate, doc.name), src.name))",
     GATE_BATTERY, "the-same-gate-declared-twice-with-two-numbers"),

    # --- the SECOND document ------------------------------------------------
    # CHANGELOG.md stated case counts nobody read, and one of the two live
    # claims was wrong. Four mutants: one per thing that had to hold for
    # reading a second document to be an improvement rather than a surface.
    ("the-second-document-is-never-opened", CORE,
     'ALSO = ["CHANGELOG.md"]',
     "ALSO = []",
     GATE_BATTERY, "a-count-in-the-changelog-is-read-too"),
    ("history-is-accused-of-the-present", CORE,
     '    if not name.endswith("CHANGELOG.md"):\n'
     "        return text\n",
     "    if True:\n"
     "        return text\n",
     GATE_BATTERY, "a-released-section-states-its-own-times-numbers"),
    ("an-absent-second-document-says-nothing", CORE,
     "    for rel in absent:",
     "    for rel in []:",
     GATE_BATTERY, "a-changelog-that-is-not-there-is-said-out-loud"),
    ("a-clash-cannot-name-the-other-document", CORE,
     '        said = ("the table declares it twice" if one == two else\n'
     '                "`%s` and `%s` declare it twice between them" % (one, two))',
     '        said = "the table declares it twice"',
     GATE_BATTERY, "the-two-documents-cannot-say-different-numbers"),
    ("a-clash-is-not-a-finding", CORE,
     "    if drifted or uncounted or phantom or clash or undeclared:",
     "    if drifted or uncounted or phantom:",
     GATE_BATTERY, "the-same-gate-declared-twice-with-two-numbers"),

    # --- the SECOND self-test ----------------------------------------------
    # invocation() returns the first convention that matches, so a gate with a
    # sibling battery AND its own --self-test had the second one compared
    # against nothing. Five mutants: one per end of the rule, one for the
    # false positive that started it, one for what makes a self-test "second",
    # and one for finding it and never running it.
    ("the-flag-is-any-mention-of-it", CORE,
     "    for line in text.splitlines():\n"
     "        stripped = line.lstrip()\n"
     '        if stripped.startswith("#"):\n'
     "            continue\n"
     "        if OFFERS.search(stripped):\n"
     "            return True\n"
     "    return False",
     '    return "--self-test" in text',
     GATE_BATTERY, "naming-the-flag-in-a-comment-is-not-offering-it"),
    ("a-second-self-test-need-not-be-declared", CORE,
     "    uncounted = sorted(has_second - set(extra))",
     "    uncounted = []",
     GATE_BATTERY, "a-second-self-test-nobody-declared"),
    ("a-declared-second-need-not-exist", CORE,
     "    phantom = sorted(set(extra) - has_second)",
     "    phantom = []",
     GATE_BATTERY, "a-declared-second-self-test-that-is-not-there"),
    ("a-second-self-test-needs-no-sibling", CORE,
     "    if not sibling.is_file() or not src.is_file():",
     "    if not src.is_file():",
     GATE_BATTERY, "a-flag-with-no-sibling-is-not-a-second"),
    ("the-second-self-test-is-found-and-not-run", CORE,
     '    jobs += [(g, n, (second_selftest(root, g), "--self-test, the second one"))\n'
     "             for g, n in sorted(extra.items()) if g in has_second]",
     "    pass",
     GATE_BATTERY, "the-second-count-is-compared-too"),

    # --- the verdict --------------------------------------------------------
    ("an-empty-table-is-a-clean-table", CORE,
     "    if not declared:\n        return unmeasurable(",
     "    if False:\n        return unmeasurable(",
     GATE_BATTERY, "a-document-with-not-one-count"),
    ("what-could-not-be-measured-passes", CORE,
     "    if blind:\n        print(",
     "    if False:\n        print(",
     GATE_BATTERY, "a-self-test-that-says-nothing"),
    ("drift-does-not-fail", CORE,
     "    if drifted or uncounted or phantom or clash or undeclared:",
     "    if uncounted or phantom or clash:",
     GATE_BATTERY, "the-row-says-fewer-than-it-runs"),
    ("only-drift-upward-is-drift", CORE,
     "drifted = [r for r in rows if r[2] is not None and r[2] != r[1]]",
     "drifted = [r for r in rows if r[2] is not None and r[2] > r[1]]",
     GATE_BATTERY, "the-row-says-more-than-it-runs"),
    ("its-own-row-is-run-from-here", CORE,
     "    mine = declared.pop(SELF, None)",
     "    mine = declared.get(SELF)",
     GATE_BATTERY, "the-row-for-this-gate-is-not-run-from-here"),
    ("a-crash-is-a-verdict", WRAP,
     'if [ "$rc" -eq 1 ] && [ "$findings" -eq 0 ]; then',
     'if [ "$rc" -eq 1 ] && [ "$findings" -eq -1 ]; then',
     GATE_BATTERY, "a-crash-is-not-a-verdict"),

    # --- the tally ledger ---------------------------------------------------
    ("the-ledger-answers-without-checking-the-hash", CORE,
     "    return tallies.get(digest(argv[1]))",
     "    return next(iter(tallies.values()), None)",
     GATE_BATTERY, "a-ledger-entry-whose-file-changed-is-ignored"),
    ("the-ledger-answers-for-anything-not-only-a-battery", CORE,
     '    if len(argv) != 2 or argv[0] != "bash" or not argv[1].endswith(".selftest.sh"):\n'
     "        return None",
     "    if False:\n        return None",
     GATE_BATTERY, "the-ledger-cannot-answer-for-a-gate-run-inline"),
    ("a-ledger-hit-can-never-be-drift", CORE,
     '            how = "earlier in this job, by run-batteries.sh"',
     '            passed, failed, skipped = declared, 0, 0\n'
     '            how = "earlier in this job, by run-batteries.sh"',
     GATE_BATTERY, "a-drifted-row-is-caught-through-the-ledger-too"),
    ("a-missing-ledger-is-not-survivable", CORE,
     "    except (OSError, UnicodeDecodeError):\n        return out",
     "    except (OSError, UnicodeDecodeError):\n        raise",
     GATE_BATTERY, "a-ledger-that-is-not-there-runs-everything"),

    # --- the runner that writes the ledger ----------------------------------
    ("a-red-battery-gets-into-the-ledger", RUNNER,
     'if [ "$rc" -eq 0 ] && [ -n "$LEDGER" ]; then',
     'if [ -n "$LEDGER" ]; then',
     RUNNER_BATTERY, "a red battery got into the ledger"),
    ("the-ledger-is-written-whether-asked-for-or-not", RUNNER,
     'LEDGER="${EHS_TALLY_LEDGER:-}"',
     'LEDGER="${EHS_TALLY_LEDGER:-$ROOT.txt}"',
     RUNNER_BATTERY, "a ledger appeared without being asked for"),
    # Two protections cover the same hole here, so neither is provable alone:
    # with pipefail on, `$?` after the pipe is still non-zero when the battery
    # fails, and with PIPESTATUS[0] in place, dropping pipefail changes nothing.
    # The mutant is therefore the pair. Taking both away is what the case sees.
    # The ledger records only batteries that exited 0, so the runner has to
    # carry each battery's OWN exit code from a background worker back to the
    # printer. Drop it on the floor - the worker reports 0 whatever happened -
    # and a red battery's tally is written down as if it had passed.
    ("the-battery-code-is-thrown-away", RUNNER,
     ['bash "$t" </dev/null > "$TMPD/$i.out" 2>&1 || rc=$?'],
     ['bash "$t" </dev/null > "$TMPD/$i.out" 2>&1'],
     RUNNER_BATTERY, "expected rc 1, got 0"),

    # The other half of the same rule: the printer must read the code the worker
    # wrote, not assume it. Written this way the ledger takes every battery.
    ("the-printer-assumes-the-code", RUNNER,
     ['  rc="$(cat "$TMPD/$n.rc")"'],
     ['  rc=0'],
     RUNNER_BATTERY, "expected rc 1, got 0"),
]


def toy(base: pathlib.Path) -> pathlib.Path:
    """A tiny faithful repository: this gate's own row, one ordinary row.

    The gate battery's control case runs over EHS_REPO_ROOT. Pointed at the real
    tree it would launch every real battery, including the weekly sweep.
    """
    d = base / "toy"
    (d / "docs").mkdir(parents=True)
    (d / "scripts/gates").mkdir(parents=True)
    (d / "docs/gate-requirements.md").write_text(
        "| the case count this document promises | running | "
        "`gate-declared-case-counts.sh` + `lib/declared_case_counts.py` + "
        "self-test (27 cases) |\n"
        "| something | running | `gate-toy.sh` + self-test (3 cases) |\n")
    (d / "scripts/gates/gate-toy.sh").write_text("#!/usr/bin/env bash\nexit 0\n")
    (d / "scripts/gates/gate-toy.selftest.sh").write_text(
        '#!/usr/bin/env bash\necho "3 passed, 0 failed"\nexit 0\n')
    return d


def failures(out: str) -> list[str]:
    """Every case the battery reported as failed, whichever spelling it uses."""
    hits = []
    for line in out.splitlines():
        if line.startswith("FAILED") or line.startswith("  FAIL "):
            hits.append(line.strip())
    return hits


def run_one(m):
    name, rel, old, new, battery, expected = m
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="ehs-dcc-mut-"))
    try:
        for f in NEEDS[battery] + [rel]:
            dst = tmp / f
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / f, dst)
        target = tmp / rel
        text = target.read_text(encoding="utf-8")
        # A mutant may be a PAIR of edits: where two protections cover the same
        # hole, neither is provable alone and only taking both away is a test.
        pairs = list(zip(old, new)) if isinstance(old, list) else [(old, new)]
        for was, becomes in pairs:
            if text.count(was) != 1:
                return name, "HARNESS", (
                    "the mutation matches %d times in %s, not once: %s"
                    % (text.count(was), rel, was.strip()[:50]))
            text = text.replace(was, becomes)
        target.write_text(text, encoding="utf-8")
        env = dict(os.environ, EHS_REPO_ROOT=str(toy(tmp)))
        # Run each battery blind to any ledger the caller happens to be using.
        # Found the hard way: standalone the bank was 22 of 22, and under
        # run-batteries.sh - which exports EHS_TALLY_LEDGER - one mutant
        # survived, because it changes what happens when that variable is UNSET
        # and it was set. A mutant whose effect depends on the environment it
        # inherits is not a measurement, it is a coincidence. Every case that
        # wants a ledger builds its own.
        env.pop("EHS_TALLY_LEDGER", None)
        try:
            p = subprocess.run(["bash", str(tmp / battery)], capture_output=True,
                               text=True, env=env, timeout=PER_MUTANT_TIMEOUT)
        except subprocess.TimeoutExpired:
            return name, "HARNESS", "the battery did not finish in %d s" % PER_MUTANT_TIMEOUT
        dead = failures(p.stdout + p.stderr)
        if any(expected in d for d in dead):
            return name, "PASS", "%d case(s) died, including the one named" % len(dead)
        if not dead:
            return name, "SURVIVES", "the battery stayed green"
        return name, "SURVIVES", ("another case died, not the one named: %s"
                                  % "; ".join(d[:60] for d in dead[:3]))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main() -> int:
    for battery, needs in NEEDS.items():
        for f in needs:
            if not (ROOT / f).is_file():
                print("HARNESS  %s is missing, so nothing here measures anything" % f)
                return 2
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        rows = list(pool.map(run_one, MUTANTS))
    caught = sum(1 for _, v, _ in rows if v == "PASS")
    broke = sum(1 for _, v, _ in rows if v == "HARNESS")
    for name, verdict, why in rows:
        print("%-9s %-52s %s" % (verdict, name, why))
    print("\n%d mutant(s) in %.0f s · %d caught by a named case · %d survive · "
          "%d could not be run"
          % (len(rows), time.time() - t0, caught,
             len(rows) - caught - broke, broke))
    if broke:
        print("FAIL  a mutant that could not be applied measures nothing, and a "
              "bank that quietly skips one is worth less than no bank")
        return 2
    if caught != len(rows):
        print("FAIL  a surviving mutant is a green case that watches nothing")
        return 1
    print("OK    every decision in the gate, the ledger and the runner has a "
          "case that notices when it is taken away")
    return 0


if __name__ == "__main__":
    sys.exit(main())
