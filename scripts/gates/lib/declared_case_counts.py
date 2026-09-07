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

WHAT IT DOES NOT DECIDE. Whether the cases are any good, whether N is the RIGHT
number, or whether a case measures its rule - that is the mutant bank's
question. This only decides whether the document tells the truth about how many
there are.

Exit codes: 0 = measured and true | 1 = measured and drifted | 2 = could not measure.
"""

from __future__ import annotations

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
COUNT = re.compile(r"(\d+) passed, (\d+) failed")
# Sequential this would be 67 s on a ten-core box; the tail is one 33 s battery,
# so eight at a time buys most of what there is to buy and the floor is that
# battery. Measured: 67.1 s -> 39.7 s.
WORKERS = 8
TIMEOUT = 900


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


def measure(root: pathlib.Path, gate: str, declared: int):
    argv, how = invocation(root, gate)
    if argv is None:
        return gate, declared, None, how
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
    passed, failed = (int(x) for x in hits[-1])
    if p.returncode != 0:
        return gate, declared, None, (
            "its self-test exited %d with %d failed case(s): a count read off a "
            "red battery is not a measurement" % (p.returncode, failed))
    return gate, declared, passed + failed, how


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

    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        rows = list(pool.map(lambda kv: measure(root, kv[0], kv[1]),
                             sorted(declared.items())))

    drifted = [r for r in rows if r[2] is not None and r[2] != r[1]]
    blind = [r for r in rows if r[2] is None]

    print("ran %d self-test(s) named by a case count in %s"
          % (len(rows), doc.name))
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
