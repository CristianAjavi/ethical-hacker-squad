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

EVERY GATE DECLARES ONE. A gate whose row carries no count was simply not
visited: its self-test could fall to two cases, or to none, and nothing here
would say a word, because there is no number to contradict. On 2026-09-07 ten
of the forty-one were in that state. They are not any more, so the rule is
enforceable without an exception list, and a gate that stops declaring is a
finding rather than a silence.

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
# A SECOND DOCUMENT MAKES THE SAME PROMISE. CHANGELOG.md states case counts too,
# in its own phrasing, and nothing read them: on 2026-09-07 one of the two was
# wrong and was found by hand while fixing something else. Only its live section
# is read - a released entry states the numbers of its own time and is history,
# not a claim about today. A secondary that is not there is reported as absent
# rather than counted as clean.
ALSO = ["CHANGELOG.md"]
# ...AND NOTHING SAID A THIRD ONE WOULD BE FOUND. ALSO is written by hand, so
# the sweep below reads every other text file and reports any count it finds
# there for a gate that EXISTS. A count for a gate that does not exist is a
# fixture - the mutant bank holds one - and stays inert with no exception list
# to maintain. Measured on 2026-09-07: 1,153 files in 0.24 s, against the ~90 s
# this gate spends running the self-tests it compares.
SWEEP_EXT = {".md", ".py", ".sh", ".txt", ".json", ".yml", ".yaml"}
SWEEP_SKIP = {".git", "node_modules", ".venv", "__pycache__"}
SWEEP_CAP = 2_000_000
GATES = "scripts/gates"
# The one row this file cannot run. Its battery ends with a control case
# that invokes this gate over the real tree, so running it from here would
# recurse without a floor. The row is not left unchecked: that battery
# asserts its own doc row against its own tally, in both directions.
SELF = "gate-declared-case-counts"
# `gate-x.sh` ... self-test (N cases) - the `inline` variant sits between them.
# A ROW MAY NAME MORE THAN ONE GATE, and `.search` returns the first match on
# the line - so on `| ... | gate-a.sh + self-test (22 cases), gate-b.sh +
# self-test (13 cases) |` only gate-a was ever compared. Read every match.
# The lazy span is FENCED so it cannot cross another gate name: without the
# fence, a row whose first gate carries no count and whose second does would
# hand the first gate its neighbour's number.
# The name may carry its path: CHANGELOG.md writes
# `scripts/gates/gate-governance-drift.sh`, the table writes `gate-x.sh`.
NAME = r"`(?:[A-Za-z0-9._/-]*/)?(gate-[a-z0-9-]+)\.sh`"
FENCE = r"(?:(?!`(?:[A-Za-z0-9._/-]*/)?gate-[a-z0-9-]+\.sh`).)*?"
ROW = re.compile(NAME + FENCE + r"self-test \((\d+) cases\)")
# The other spelling, which is the CHANGELOG's: `(+ 6-case self-test)`.
HYPHEN = re.compile(NAME + FENCE + r"(\d+)-case self-test")
# A GATE MAY CARRY TWO SELF-TESTS. `invocation` below returns the FIRST
# convention that matches, so a gate with a sibling battery AND its own
# `--self-test` had its second one compared against nothing: it could fall from
# ten cases to two with every row in the table still green. The second count is
# declared on the same row, after the first, as `+ --self-test (M cases)`.
# ROW is non-greedy, so it still reads the first number and not this one.
EXTRA = re.compile(NAME + FENCE + r"\+ --self-test \((\d+) cases\)")
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


# A SUBSTRING IS NOT A DECLARATION. `"--self-test" in text` also matches a gate
# that only NAMES the flag in a comment - which is how the second-self-test rule
# accused gate-assertion-pipes.sh, whose header explains that a gate invoked
# `gate-x.sh --self-test` is not a battery. Two shapes actually offer it here: a
# case arm, and a comparison against "$1". Whole-line comments are dropped
# first, for the same reason.
OFFERS = re.compile(r"""--self-test\)|[=!]=?\s*["']--self-test["']""")


def offers_flag(text: str) -> bool:
    for line in text.splitlines():
        stripped = line.lstrip()
        if stripped.startswith("#"):
            continue
        if OFFERS.search(stripped):
            return True
    return False


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
    if offers_flag(text):
        return ["bash", str(src), "--self-test"], "--self-test"
    return ["bash", str(src)], "inline on a normal run"


def second_selftest(root: pathlib.Path, gate: str):
    """argv for a SECOND self-test this gate offers beyond its sibling battery.

    Only that shape: a gate whose sibling battery exists and which also answers
    `--self-test`. A gate with no sibling already has its `--self-test` measured
    as its first and only one.
    """
    sibling = root / GATES / ("%s.selftest.sh" % gate)
    src = root / GATES / ("%s.sh" % gate)
    if not sibling.is_file() or not src.is_file():
        return None
    try:
        text = src.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None
    if not offers_flag(text):
        return None
    return ["bash", str(src), "--self-test"]


def measure(root: pathlib.Path, gate: str, declared: int, tallies=None, forced=None):
    argv, how = forced if forced else invocation(root, gate)
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


def sweep(root: pathlib.Path, already: set[str], onfile: set[str]):
    """Every text file outside the document list, and what it declares.

    Returns (findings, swept, unread). `unread` is not an empty list dressed up
    as a clean one: a file this cannot open is named, because a count inside it
    would go unchecked and the silence would read exactly like a file with none.
    """
    findings: list[str] = []
    swept = 0
    unread: list[str] = []
    for q in sorted(root.rglob("*")):
        if any(s in q.parts for s in SWEEP_SKIP):
            continue
        if not q.is_file() or q.suffix not in SWEEP_EXT:
            continue
        rel = q.relative_to(root).as_posix()
        if rel in already:
            continue
        try:
            if q.stat().st_size > SWEEP_CAP:
                unread.append("%s (over %d bytes)" % (rel, SWEEP_CAP))
                continue
            body = q.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            unread.append("%s (%s)" % (rel, exc))
            continue
        swept += 1
        for i, line in enumerate(body.splitlines(), 1):
            for rx in (ROW, HYPHEN):
                for m in rx.finditer(line):
                    if m.group(1) not in onfile:
                        continue
                    findings.append(
                        "%s:%d\n         it states %s cases for `%s.sh` and no document "
                        "list reads\n         this file, so the number answers to "
                        "nothing. Read the file,\n         or take the number out"
                        % (rel, i, m.group(2), m.group(1)))
    return findings, swept, unread


def live_section(name: str, text: str) -> str:
    """A released changelog entry states the numbers of ITS OWN time. Only the
    top section is a claim about today; accusing history of drifting from a
    present it was never describing would be a finding nobody could clear."""
    if not name.endswith("CHANGELOG.md"):
        return text
    head, sep, _ = text.partition("\n## [")
    if not sep:
        return text
    rest = text[len(head) + len(sep):]
    return head + sep + rest.split("\n## [")[0]


def main(argv: list[str]) -> int:
    if len(argv) not in (2, 3):
        return unmeasurable("usage: declared_case_counts.py <repo-root> [doc.md]")
    root = pathlib.Path(argv[1])
    doc = pathlib.Path(argv[2]) if len(argv) == 3 else root / DOC
    if not (root / GATES).is_dir():
        return unmeasurable("no %s/ directory under %s" % (GATES, root))
    try:
        text = live_section(doc.name, doc.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError) as exc:
        return unmeasurable("cannot read %s: %s" % (doc, exc))

    # The primary document is the contract; a secondary merely also states
    # numbers. One that cannot be read is not survivable either: a count it
    # holds would go unchecked and nothing would say so.
    sources = [(doc, text)]
    absent: list[str] = []
    for rel in ALSO:
        q = root / rel
        if q == doc:
            continue
        if not q.is_file():
            absent.append(rel)
            continue
        try:
            sources.append((q, live_section(rel, q.read_text(encoding="utf-8"))))
        except (OSError, UnicodeDecodeError) as exc:
            return unmeasurable("cannot read %s: %s" % (rel, exc))

    declared: dict[str, int] = {}
    # THE LAST WRITER WINS unless somebody looks. A gate declared twice with two
    # different numbers used to resolve in silence, and the row that lost said
    # something no instrument would ever contradict.
    clash: list[tuple[str, int, int, str, str]] = []
    # WHERE a number was written is part of the finding: two documents that
    # disagree is a clash, and the message has to be able to say which is which.
    where: dict[str, str] = {}
    primary: set[str] = set()
    for src, body in sources:
        for line in body.splitlines():
            for rx in (ROW, HYPHEN):
                for m in rx.finditer(line):
                    gate, n = m.group(1), int(m.group(2))
                    if gate in declared and declared[gate] != n:
                        clash.append((gate, declared[gate], n,
                                      where.get(gate, doc.name), src.name))
                    declared[gate] = n
                    where[gate] = src.name
                    if src is doc:
                        primary.add(gate)
    # THE GATE THAT DECLARES NOTHING answers to nothing. Read the files rather
    # than the prose: a row can be deleted, a file cannot be talked away.
    onfile = {q.stem for q in (root / GATES).glob("gate-*.sh")
              if not q.name.endswith(".selftest.sh")}
    # An EMPTY gates directory is not a clean table, but it is not this rule's
    # to report: every declared row is then a file that is not there, and the
    # gate already says so, per row, with a better message than this one could.
    # Reporting zero undeclared gates here cannot hide anything, because there
    # is no green road out of a run where every row names a missing file.
    # Scoped to the PRIMARY document on purpose: the contract is what has to
    # name every gate. A gate mentioned only in a changelog entry would
    # otherwise satisfy the rule without the table ever growing a row.
    undeclared = sorted(onfile - primary) if onfile else []

    already = set()
    for src, _ in sources:
        try:
            already.add(src.relative_to(root).as_posix())
        except ValueError:
            pass
    stray, swept, unread = sweep(root, already, onfile)

    mine = declared.pop(SELF, None)
    primary.discard(SELF)
    if not declared:
        return unmeasurable(
            "%s declares no `self-test (N cases)` row - a zero here is a blind "
            "zero, not a clean table" % doc)

    # The second-self-test contract is the table's alone; no other document
    # writes that phrasing, and a blind zero here would need a reader first.
    extra: dict[str, int] = {}
    for line in text.splitlines():
        for m in EXTRA.finditer(line):
            gate, n = m.group(1), int(m.group(2))
            if gate in extra and extra[gate] != n:
                clash.append((gate, extra[gate], n, doc.name, doc.name))
            extra[gate] = n
    extra.pop(SELF, None)

    # A SECOND SELF-TEST NOBODY COUNTS, and a count for a second self-test that
    # is not there. Both are the same defect seen from its two ends, and both
    # are findings rather than silence.
    has_second = {g for g in declared if second_selftest(root, g) is not None}
    uncounted = sorted(has_second - set(extra))
    phantom = sorted(set(extra) - has_second)

    tallies = ledger(os.environ.get(LEDGER_ENV))
    jobs = [(g, n, None) for g, n in sorted(declared.items())]
    jobs += [(g, n, (second_selftest(root, g), "--self-test, the second one"))
             for g, n in sorted(extra.items()) if g in has_second]
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        rows = list(pool.map(lambda j: measure(root, j[0], j[1], tallies, j[2]), jobs))

    drifted = [r for r in rows if r[2] is not None and r[2] != r[1]]
    blind = [r for r in rows if r[2] is None]
    # "ran N" would be a lie the moment a row is answered from the ledger, and
    # the whole point of the ledger is that some are. Say which is which.
    reused = sum(1 for r in rows if r[3].startswith("earlier in this job"))

    print("checked %d self-test(s) named by a case count in %s: %d run here, "
          "%d read off the ledger"
          % (len(rows), ", ".join(s.name for s, _ in sources),
             len(rows) - reused, reused))
    print("  swept %d file(s) outside that list for counts nobody reads" % swept)
    for rel in absent:
        print("  not present here: %s. Any case count it states is unchecked,\n"
              "  and this run is not evidence that it states none." % rel)
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

    for gate, first, second, one, two in clash:
        said = ("the table declares it twice" if one == two else
                "`%s` and `%s` declare it twice between them" % (one, two))
        print("FINDING  %s\n         %s, %d cases and then %d. Whichever\n"
              "         one is wrong, nothing here can contradict it: the second\n"
              "         reading silently replaced the first"
              % (gate, said, first, second))
    for gate in uncounted:
        print("FINDING  %s\n         it has a sibling battery AND its own --self-test, and only the\n"
              "         first is declared. Add `+ --self-test (N cases)` to its row,\n"
              "         or the second one can fall to nothing with the table still green"
              % gate)
    for gate in undeclared:
        print("FINDING  %s\n         it exists under %s/ and its row declares no case count, so\n"
              "         nothing compares its self-test with anything. Add\n"
              "         `+ self-test (N cases)` to its row, with N read off a run"
              % (gate, GATES))
    for f in stray:
        print("FINDING  %s" % f)
    for u in unread:
        print("UNMEASURED %s\n         a case count inside it would go unchecked, and this run\n"
              "         is not evidence that it holds none" % u)
    for gate in phantom:
        print("FINDING  %s\n         its row declares `+ --self-test (%d cases)` and the gate has\n"
              "         no second self-test: either the row is stale or the test is gone"
              % (gate, extra[gate]))

    if blind or unread:
        print("%d row(s) and %d file(s) could NOT be checked"
              % (len(blind), len(unread)))
        return 2
    if drifted or uncounted or phantom or clash or undeclared or stray:
        n = (len(drifted) + len(uncounted) + len(phantom) + len(clash)
             + len(undeclared) + len(stray))
        print("%d declared case count(s) do not match what runs" % n)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
