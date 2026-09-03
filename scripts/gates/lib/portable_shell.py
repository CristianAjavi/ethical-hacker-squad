#!/usr/bin/env python3
"""Refuse BSD-only or GNU-only shell spellings under scripts/.

The measurement, not the policy: the catalogue lives in
scripts/gates/data/portable-shell-catalogue.json and this file only applies it.

THE THREE THINGS THAT MAKE THIS HARDER THAN A GREP

1.  A logical line is not a physical line.  The one real `date` fallback in this
    repository is split across two lines by a trailing backslash, with the BSD
    spelling on the first and the GNU spelling on the second.  Read physically,
    each half looks like a lone platform-specific invocation and both get
    flagged.  Read logically, the pair is the correct idiom.  So continuations
    are joined before anything is matched, and the finding carries the line
    number where the logical line STARTED.

2.  The deliberate fallback must not be a finding.  `A 2>/dev/null || B` is how
    portable shell is actually written.  Measured before this gate existed: over
    104 shell files, a catalogue without this exoneration flagged 18 correct
    lines - sixteen mktemp fallbacks and one date pair - and nothing else.  A
    gate whose first red is its own defect gets switched off, so a candidate is
    exonerated when its logical line also carries the counterpart spelling and
    an `||`.

3.  An exemption has to be WRITTEN.  A line can opt out with a trailing
    `# portable-shell: allow <id> - <reason>`, and an exemption with no reason is
    itself a finding.  Removing a check and saying what replaces it are the same
    edit; a silent opt-out is the half of that edit that never happens.

WHAT THIS DOES NOT DECIDE.  Whether the spelling is REACHABLE.  This is a
lexical check over source text: a BSD-only invocation inside a branch that never
runs on Linux is still reported, because deciding otherwise means interpreting
the shell.  The out_of_scope block of the catalogue names what is not checked at
all - what does not appear in that file passes in silence, and saying so is part
of the check.

Exit codes: 0 = measured and clean | 1 = measured and fails | 2 = could not measure.
"""

from __future__ import annotations

import json
import pathlib
import re
import sys

SCAN_DIR = "scripts"
SUFFIXES = (".sh", ".bash")
MIN_REASON = 10

# `# portable-shell: allow <ids> - <reason>`; the ids are comma-separated.
#
# The id group is GREEDY and excludes the space on purpose. Lazy, it split
# `sed-i-empty` at its own hyphen - the id came out as `sed`, matched no rule,
# and the exemption silently did nothing while reading as if it worked. An
# escape hatch that fails closed is fine; one that fails quietly is not.
EXEMPTION = re.compile(
    r"#\s*portable-shell:\s*allow\s+([A-Za-z0-9_,-]+)(?:\s+[-—:]?\s*(.*))?$"
)


def unmeasurable(reason: str) -> int:
    print("UNMEASURABLE %s" % reason)
    return 2


def logical_lines(text: str):
    """Yield (first_line_number, joined_text) with backslash continuations joined."""
    physical = text.splitlines()
    n = 0
    while n < len(physical):
        start = n + 1
        buf = physical[n]
        while buf.rstrip().endswith("\\") and n + 1 < len(physical):
            buf = buf.rstrip()[:-1] + " " + physical[n + 1]
            n += 1
        yield start, buf
        n += 1


def exemption_on(line: str):
    """(ids, reason) named by a written exemption on this line, or None."""
    m = EXEMPTION.search(line)
    if not m:
        return None
    ids = [i.strip() for i in m.group(1).split(",") if i.strip()]
    return ids, (m.group(2) or "").strip()


def scan(root: pathlib.Path, catalogue: dict) -> tuple[list[str], list[str], int]:
    """Return (findings, honoured_exemptions, files_read)."""
    rules = []
    for raw in catalogue["rules"]:
        rules.append(
            (
                raw["id"],
                raw["why"],
                raw.get("portable") or "no portable spelling recorded",
                re.compile(raw["pattern"]),
                re.compile(raw["counterpart"]) if raw.get("counterpart") else None,
            )
        )

    files = sorted(
        p
        for p in (root / SCAN_DIR).rglob("*")
        if p.is_file() and p.name.endswith(SUFFIXES)
    )
    if not files:
        raise LookupError("no shell file under %s/ - a zero here is a blind zero" % SCAN_DIR)

    findings: list[str] = []
    honoured: list[str] = []
    for path in files:
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            raise LookupError("cannot read %s: %s" % (path, exc))
        rel = path.relative_to(root)
        for lineno, line in logical_lines(text):
            if line.lstrip().startswith("#"):
                continue
            allow = exemption_on(line)
            for rid, why, portable, pattern, counterpart in rules:
                if not pattern.search(line):
                    continue
                if counterpart is not None and "||" in line and counterpart.search(line):
                    continue
                if allow and rid in allow[0]:
                    if len(allow[1]) < MIN_REASON:
                        findings.append(
                            "%s:%d  %s is exempted with no reason written down. "
                            "An exemption is half an edit until it says why."
                            % (rel, lineno, rid)
                        )
                    else:
                        honoured.append("%s:%d  %s - %s" % (rel, lineno, rid, allow[1]))
                    continue
                findings.append(
                    "%s:%d  %s\n         %s\n         portable: %s"
                    % (rel, lineno, rid, why, portable)
                )
    return findings, honoured, len(files)


def main(argv: list[str]) -> int:
    # The second argument exists so the self-test can hand over a broken
    # catalogue. A gate that can only ever read its own shipped catalogue has no
    # way to prove it reports could-not-measure when that catalogue is wrong -
    # and an unprovable branch is one nobody finds out is dead.
    if len(argv) not in (2, 3):
        return unmeasurable("usage: portable_shell.py <repo-root> [catalogue.json]")
    root = pathlib.Path(argv[1])
    if not (root / SCAN_DIR).is_dir():
        return unmeasurable("no %s/ directory under %s" % (SCAN_DIR, root))

    if len(argv) == 3:
        cat_path = pathlib.Path(argv[2])
    else:
        cat_path = pathlib.Path(__file__).resolve().parent.parent / "data" / "portable-shell-catalogue.json"
    try:
        catalogue = json.loads(cat_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return unmeasurable("cannot read the catalogue %s: %s" % (cat_path, exc))
    if not catalogue.get("rules"):
        return unmeasurable("the catalogue names no rule: there is nothing to enforce")
    try:
        for raw in catalogue["rules"]:
            re.compile(raw["pattern"])
            if raw.get("counterpart"):
                re.compile(raw["counterpart"])
    except (KeyError, re.error) as exc:
        return unmeasurable("the catalogue does not compile: %s" % exc)

    try:
        findings, honoured, n_files = scan(root, catalogue)
    except LookupError as exc:
        return unmeasurable(str(exc))

    print("· read %d shell file(s) under %s/ against %d catalogue rule(s)"
          % (n_files, SCAN_DIR, len(catalogue["rules"])))
    # Exemptions are printed on a clean run too. One nobody ever sees is one
    # nobody ever revisits, and this gate's whole premise is that an unwritten
    # limit is an absent limit.
    for line in honoured:
        print("· exempted in writing: %s" % line)
    print("· NOT checked: %s" % " | ".join(catalogue.get("out_of_scope", ["nothing declared"])))

    if findings:
        for line in findings:
            print("FINDING  %s" % line)
        print("%d divergent invocation(s) with no fallback and no written exemption" % len(findings))
        return 1
    print("OK   no BSD-only or GNU-only invocation outside a fallback or a written exemption")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
