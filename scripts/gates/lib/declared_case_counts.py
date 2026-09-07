#!/usr/bin/env python3
"""Make the case counts in docs/gate-requirements.md true by running them.

A row in that table reads `gate-X.sh` + self-test (N cases). Nobody ever
compared that N to what the self-test actually runs, and measured on
2026-09-07 the answer was: two of twelve had drifted, and four could not be
compared at all because their self-test never says how many cases it ran.

  gate-coverage-sweep      said 31, ran 47   (+16, cases added and never counted)
  gate-triage-stage        said 32, ran 31   (-1, wrong the day the row was written)
  gate-portable-shell      said 22, ran 25   (on a sibling branch; drifted twice)

A number in a document that nothing checks is a claim, and a claim that has been
wrong twice is worse than no number: the reader trusts it.

HOW A SELF-TEST IS INVOKED. Three conventions live in this repository and this
file does not try to unify them, only to find them:

  1. a sibling `<gate>.selftest.sh`               -> run that
  2. the gate offers `--self-test`                -> run the gate with it
  3. neither                                      -> run the gate; its self-test
                                                     runs inline on a normal run

HOW THE COUNT IS READ. One form, `N passed, M failed`, and the total is N+M.
A self-test that prints no such line is NOT a zero: it is a row that cannot be
checked, and this file says so and exits 2 rather than passing it.

THE TALLY LEDGER. Five of these self-tests are batteries `run-batteries.sh`
also runs, so a CI job that calls both ran them twice - 59.3 s of duplicated
work, median of 3 with a 2% spread. When EHS_TALLY_LEDGER names a file that
run-batteries.sh wrote earlier in the same job, a row whose battery is in it is
answered from the ledger instead of run again.

The key is the sha256 of the battery FILE, never its name, and the ledger is
consulted only for an invocation that is exactly `bash <something>.selftest.sh`
- the shape run-batteries.sh records. Edit a case, rename the file, check out
another branch, or point the row at a gate rather than a battery, and the hash
misses and it runs. There is no staleness window because there is no window,
and a miss costs exactly what this file costs today. run-batteries.sh records
only batteries that exited 0, so a hit cannot be a count read off a red one.

WHAT IT DOES NOT DECIDE. Whether the cases are any good, whether N is the RIGHT
number, or whether a case measures its rule - that is the mutant bank's
question. This only decides whether the document tells the truth about how many
there are.

Exit codes: 0 = measured and true | 1 = measured and drifted | 2 = could not measure.
"""

from __future__ import annotations

import hashlib
import os
import pathlib
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

DOC = "docs/gate-requirements.md"
GATES = "scripts/gates"
# The one row this file cannot run. Its battery ends with a control case
# that invokes this gate over the real tree, so running it from here would
# recurse without a floor. The row is not left unchecked: that battery
# asserts its own doc row against its own tally, in both directions.
SELF = "gate-declared-case-counts"
# `gate-x.sh` ... self-test (N cases) - the `inline` variant sits between them.
ROW = re.compile(r"`(gate-[a-z0-9-]+)\.sh`.*?self-test \((\d+) cases\)")
# The third group is optional: only a battery that can skip a case prints it.
# It still counts toward the row, because a skipped case is a case of the
# file - one that proved nothing here, which is a different statement.
COUNT = re.compile(r"(\d+) passed, (\d+) failed(?:, (\d+) skipped)?")
# Sequential this would be 67 s on a ten-core box; the tail is one 33 s battery,
# so eight at a time buys most of what there is to buy and the floor is that
# battery. Measured: 67.1 s -> 39.7 s.
WORKERS = 8
TIMEOUT = 900
LEDGER_ENV = "EHS_TALLY_LEDGER"
SHA_LEN = 64


def ledger(path):
    """{sha256 of a battery file: the tally line it printed}, or {} for none.

    A ledger that is absent, unreadable or malformed is not an error and never a
    finding: it means nothing is answered from it and every row runs, which is
    what this file did before the ledger existed. The only safe degradation of a
    shortcut is the slow path.
    """
    out = {}
    if not path:
        return out
    try:
        text = pathlib.Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return out
    for line in text.splitlines():
        parts = line.split(" ", 2)
        if len(parts) == 3 and len(parts[0]) == SHA_LEN:
            out[parts[0]] = parts[2]
    return out


def digest(path):
    """sha256 of a file, or None if it cannot be read - which means: run it."""
    try:
        return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()
    except OSError:
        return None


def from_ledger(argv, tallies):
    """The tally line for this invocation, or None if it has to be run.

    Two conditions, both necessary. The invocation must be exactly
    `bash <file>.selftest.sh` - the shape run-batteries.sh records, so a gate
    run inline or with --self-test is never answered from here. And the file's
    CONTENT must hash to a key in the ledger.
    """
    if not tallies:
        return None
    if len(argv) != 2 or argv[0] != "bash" or not argv[1].endswith(".selftest.sh"):
        return None
    return tallies.get(digest(argv[1]))


def unmeasurable(reason: str) -> int:
    print("UNMEASURABLE %s" % reason)
    return 2


def invocation(root: pathlib.Path, gate: str):
    """(argv, how) for this gate's self-test, or (None, why not)."""
    sibling = root / GATES / ("%s.selftest.sh" % gate)
    if sibling.is_file():
        return ["bash", str(sibling)], "sibling battery"
    src = root / GATES / ("%s.sh" % gate)
    if not src.is_file():
        return None, "the row names %s.sh and there is no such file" % gate
    try:
        text = src.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        return None, "cannot read %s.sh: %s" % (gate, exc)
    if "--self-test" in text:
        return ["bash", str(src), "--self-test"], "--self-test"
    return ["bash", str(src)], "inline on a normal run"


def measure(root: pathlib.Path, gate: str, declared: int, tallies=None):
    argv, how = invocation(root, gate)
    if argv is None:
        return gate, declared, None, how
    recorded = from_ledger(argv, tallies)
    if recorded is not None:
        hits = COUNT.findall(recorded)
        if hits:
            passed, failed, skipped = (int(x or 0) for x in hits[-1])
            how = "earlier in this job, by run-batteries.sh"
            if skipped:
                how = "%s, %d skipped there" % (how, skipped)
            return gate, declared, passed + failed + skipped, how
    try:
        p = subprocess.run(argv, capture_output=True, text=True,
                           cwd=str(root), timeout=TIMEOUT)
    except (OSError, subprocess.SubprocessError) as exc:
        return gate, declared, None, "the self-test could not be run: %s" % exc
    out = p.stdout + p.stderr
    hits = COUNT.findall(out)
    if not hits:
        return gate, declared, None, (
            "its self-test (%s) prints no `N passed, M failed` line, so the row "
            "cannot be checked against anything" % how)
    passed, failed, skipped = (int(x or 0) for x in hits[-1])
    if p.returncode != 0:
        return gate, declared, None, (
            "its self-test exited %d with %d failed case(s): a count read off a "
            "red battery is not a measurement" % (p.returncode, failed))
    if skipped:
        how = "%s, %d skipped here" % (how, skipped)
    return gate, declared, passed + failed + skipped, how


def main(argv: list[str]) -> int:
    if len(argv) not in (2, 3):
        return unmeasurable("usage: declared_case_counts.py <repo-root> [doc.md]")
    root = pathlib.Path(argv[1])
    doc = pathlib.Path(argv[2]) if len(argv) == 3 else root / DOC
    if not (root / GATES).is_dir():
        return unmeasurable("no %s/ directory under %s" % (GATES, root))
    try:
        text = doc.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        return unmeasurable("cannot read %s: %s" % (doc, exc))

    declared: dict[str, int] = {}
    for line in text.splitlines():
        m = ROW.search(line)
        if m:
            declared[m.group(1)] = int(m.group(2))
    mine = declared.pop(SELF, None)
    if not declared:
        return unmeasurable(
            "%s declares no `self-test (N cases)` row - a zero here is a blind "
            "zero, not a clean table" % doc)

    tallies = ledger(os.environ.get(LEDGER_ENV))
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        rows = list(pool.map(lambda kv: measure(root, kv[0], kv[1], tallies),
                             sorted(declared.items())))

    drifted = [r for r in rows if r[2] is not None and r[2] != r[1]]
    blind = [r for r in rows if r[2] is None]
    # "ran N" would be a lie the moment a row is answered from the ledger, and
    # the whole point of the ledger is that some are. Say which is which.
    reused = sum(1 for r in rows if r[3].startswith("earlier in this job"))

    print("checked %d self-test(s) named by a case count in %s: %d run here, "
          "%d read off the ledger" % (len(rows), doc.name, len(rows) - reused, reused))
    if mine is not None:
        print("  NOT run here: %s (%d cases). Its battery ends by invoking this\n"
              "  gate over the real tree, so running it from here would recurse.\n"
              "  That battery checks its own row instead." % (SELF, mine))
    for gate, n, got, how in rows:
        if got is not None and got == n:
            print("  %-34s %3d, and %d ran (%s)" % (gate, n, got, how))
    for gate, n, got, how in drifted:
        print("FINDING  %s\n         the row says %d cases and the self-test runs %d\n"
              "         read from its %s" % (gate, n, got, how))
    for gate, n, got, how in blind:
        print("UNMEASURED %s\n         the row says %d cases and nothing here can confirm it\n"
              "         %s" % (gate, n, how))

    if blind:
        print("%d row(s) could NOT be checked" % len(blind))
        return 2
    if drifted:
        print("%d declared case count(s) do not match what runs" % len(drifted))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
