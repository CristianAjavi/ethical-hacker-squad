#!/usr/bin/env python3
"""Derive what each pack file DEFINES and what each router CLAIMS about it.

The corpus is only reachable through prose. A specialist opens the pack file its
agent definition names, and opens a sibling only because the entry file's header
names it. Nothing scans the directory at runtime. So a procedure that is defined,
numbered and traced is still unreachable if the two routers that lead to it do
not say it is there - and every other check stays green, because the file is
present and the identifier is unique.

This module answers three questions from the tree alone:

  DEFINES(f)  the procedure ids `f` declares as `### <ID> ...` headings.
  PACKS       which files belong to one role, and which of them is the entry.
  CLAIMS(r,f) the ids router `r` states are in `f`, read off the lines of `r`
              that name `f`.

`gate-pack-routing.sh` turns the comparison into a verdict. Nothing here reads
the network or the git history.
"""
import re
import sys
from pathlib import Path

HEADING = re.compile(r"^###\s+([A-Z]{2,4}-\d{2,3})\b")
# `AI-12`..`AI-24`  /  `AI-12`..`AI-22`, `AI-24`  /  `INF-13`..`INF-18`
RANGE = re.compile(r"`([A-Z]{2,4})-(\d{2,3})`\s*\.\.\s*`([A-Z]{2,4})-(\d{2,3})`")
SINGLE = re.compile(r"`([A-Z]{2,4}-\d{2,3})`")
TABLE_ROW = re.compile(r"^\|\s*`([a-z0-9-]+\.md)`\s*\|\s*`([a-z0-9-]+)`\s*\|")


def defines(path):
    """The ids this file declares as procedure headings."""
    out = set()
    for line in path.read_text().splitlines():
        m = HEADING.match(line)
        if m:
            out.add(m.group(1))
    return out


def claims_on_line(line):
    """Every id a line asserts, with `A`..`B` expanded.

    A range is read before the singles so that the endpoints of `A`..`B` are not
    also counted as bare mentions - they are, but they are already covered, and
    counting them twice changes nothing because this returns a set.
    """
    out = set()
    for pre_a, n_a, pre_b, n_b in RANGE.findall(line):
        if pre_a != pre_b:
            continue
        lo, hi = int(n_a), int(n_b)
        if lo > hi or hi - lo > 200:
            continue
        width = len(n_a)
        for n in range(lo, hi + 1):
            out.add("%s-%0*d" % (pre_a, width, n))
    for single in SINGLE.findall(line):
        out.add(single)
    return out


#
# WHY PHANTOM IS THE WEAKER HALF
#
# A router line is prose, and prose does not bind an id to a file name in any
# way a parser can trust. The corpus's own header sentences routinely name two
# siblings and carry both ranges, and the range is written before the file name
# as often as after it. Two attempts at attributing a claim to the nearer file
# were written here and both accused a *correct* router - first by reading the
# whole line for each file named on it, then by reading from a file's name to
# the end of the line, which swallowed two trailing sentences about a third
# file. An instrument that invents a defect is worse than one that misses it,
# because it teaches the reader to disbelieve its greens too.
#
# So the attribution was dropped rather than guessed. PHANTOM reports only an
# id that no file of the pack defines: a range running past the last procedure,
# which is what drift looks like when a procedure is deleted or renumbered. It
# deliberately does NOT catch two siblings whose ranges are swapped with each
# other - every id in that line does exist in the pack. MISSING, which is the
# half that caught the real defect, keeps full strength: it reads the whole
# line and asks only whether the id is named anywhere near the file's name.


def region(path, start_pat, stop_pat):
    """Lines of `path` from the first line matching start_pat up to the next
    line matching stop_pat. An absent start means an empty region, which the
    caller reports rather than silently treating as 'nothing claimed'. A file
    that is not there is the same answer, not an exception: a gate that raises
    prints a red with no finding, which reads as a broken gate rather than as
    the missing router it is."""
    if not path.is_file():
        return []
    lines = path.read_text().splitlines()
    out, inside = [], False
    for line in lines:
        if not inside:
            if re.match(start_pat, line):
                inside = True
                out.append(line)
            continue
        if re.match(stop_pat, line):
            break
        out.append(line)
    return out


def read_packs(knowledge_readme):
    """file -> role, from the pack table. The table is the one place that says
    which role owns which file, and it is already checked elsewhere."""
    out = {}
    for line in knowledge_readme.read_text().splitlines():
        m = TABLE_ROW.match(line)
        if m:
            out[m.group(1)] = m.group(2)
    return out


def entry_of(files):
    """The entry file of a pack: the one whose stem prefixes the others. A pack
    whose files share no such stem returns None, and the caller reports that it
    cannot tell rather than guessing."""
    stems = sorted((f[:-3] for f in files), key=len)
    head = stems[0]
    if all(s == head or s.startswith(head + "-") for s in stems):
        return head + ".md"
    return None


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    kdir = root / "skills/ethical-hacker-squad/references/knowledge"
    readme = kdir / "README.md"
    if not readme.is_file():
        print("UNMEASURABLE\tno knowledge/README.md: nothing says which file belongs to which pack")
        return 2

    roles = read_packs(readme)
    if not roles:
        print("UNMEASURABLE\tthe pack table in knowledge/README.md parsed to zero rows")
        return 2

    by_role = {}
    for fname, role in roles.items():
        by_role.setdefault(role, []).append(fname)

    findings = []
    checked = 0
    for role, files in sorted(by_role.items()):
        for fname in files:
            if not (kdir / fname).is_file():
                findings.append("TABLE\t%s\tthe pack table names %s, which is not in knowledge/" % (role, fname))
        files = [f for f in files if (kdir / f).is_file()]
        if len(files) < 2:
            continue
        entry = entry_of(files)
        if entry is None:
            findings.append("SHAPE\t%s\tcannot tell which file is the entry point of this pack: %s"
                            % (role, ", ".join(sorted(files))))
            continue
        siblings = sorted(f for f in files if f != entry)

        agent = root / "agents" / (role + ".md")
        routers = [
            ("entry header %s" % entry, kdir / entry,
             region(kdir / entry, r"^# ", r"^## ")),
            ("agent agents/%s.md" % role, agent,
             region(agent, r"^## First actions", r"^## (?!First actions)")),
        ]
        for rname, rpath, lines in routers:
            if not rpath.is_file():
                findings.append("ROUTER\t%s\t%s does not exist, so it has no region to read: "
                                "nothing sends anyone to this pack's other files" % (role, rname))
                continue
            if not lines:
                findings.append("ROUTER\t%s\t%s has no region to read: a router that says nothing routes nowhere"
                                % (role, rname))
                continue
            for sib in siblings:
                checked += 1
                hits = [l for l in lines if sib in l]
                if not hits:
                    findings.append("UNNAMED\t%s\t%s never names %s, so %d procedure(s) in it are unreachable through this route: %s"
                                    % (role, rname, sib, len(defines(kdir / sib)),
                                       ", ".join(sorted(defines(kdir / sib)))))
                    continue
                actual = defines(kdir / sib)
                # Only ids of this pack's prefixes matter; a line may cite a
                # neighbour's id in passing and that is not a claim about `sib`.
                prefixes = {i.split("-")[0] for i in actual}
                named = set()
                for l in hits:
                    named |= claims_on_line(l)
                named = {c for c in named if c.split("-")[0] in prefixes}
                missing = sorted(actual - named)
                # See WHY PHANTOM IS THE WEAKER HALF at the top of this file.
                in_pack = set()
                for other in files:
                    in_pack |= defines(kdir / other)
                phantom = sorted(named - in_pack)
                if missing:
                    findings.append("MISSING\t%s\t%s names %s but not %s, which %s defines: unreachable through this route"
                                    % (role, rname, sib, ", ".join(missing), sib))
                if phantom:
                    findings.append("PHANTOM\t%s\t%s sends a reader to %s for %s, which no file of this pack defines"
                                    % (role, rname, sib, ", ".join(phantom)))

    for f in findings:
        print(f)
    print("CHECKED\t%d route(s) from a router to a sibling file" % checked)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
