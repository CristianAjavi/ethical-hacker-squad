#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# competitive_backlog.py — the measurement core for gate-competitive-backlog.sh.
#
# WHY IT EXISTS
#   docs/competitive-analysis.md §5 is this repository's roadmap against the
#   neighbouring products: fifteen numbered items, each naming the gate that
#   would keep it. For two weeks it carried no status at all, so the only way to
#   learn that items 1..7 had already shipped was to grep the gate directory and
#   infer - which is how two gates came to print, on every run,
#
#       "delivered audit reports: no machine-readable finding is emitted yet
#        (backlog #7)"
#
#   while item 7's schema, validator and fixtures were shipping. The caveat was
#   still true; the REASON attached to it had gone stale, and a stale reason is
#   read as a live one. Nothing turned red, because nothing was looking.
#
# WHAT IT MEASURES
#   B1  every row's status is one of the three declared values
#   B2  every `shipped` or `partial` row names a gate the runner actually has
#   B3  no `open` row is quietly kept by a gate that already exists - an item
#       built and never crossed off is the same defect pointing the other way
#   B4  no line anywhere in the repository calls a SHIPPED item missing: a
#       citation of `backlog #N` beside a word of absence, where row N ships
#
# B4 is the tooth. B1..B3 keep the table honest about the gate directory; B4
# keeps the rest of the repository honest about the table.
#
# Output protocol: FINDING <text>, UNMEASURED <text>, anything else is info.
# Exit: 0 measured fine · 1 measured FAILS · 2 could not measure.
# ---------------------------------------------------------------------------
import os
import re
import sys

findings, unmeasured, info = [], [], []


def unmeasurable(msg):
    """Record a could-not-measure reason.

    This existed as a bare `unmeasured(...)` call against the LIST above, which
    is a TypeError, so all four could-not-measure arms of this gate crashed
    instead of firing - and python exits 1 on an unhandled exception, which the
    wrapper read as "measured, FAILS". A gate that cannot measure was reporting
    a failure it had not measured, which is the one thing the exit-code contract
    of this repository exists to prevent. Nothing caught it because the gate had
    only ever been run on a healthy tree; the self-test caught it on its first
    run, in the two cases that break the document.
    """
    unmeasured.append(msg)

STATUSES = ("shipped", "partial", "open")

# A closed, visible list, and every entry is PRESENT tense on purpose. The first
# draft carried "we did not" and immediately produced a false positive on
# docs/gate-requirements.md: "Four of the five neighbouring products emit a
# machine-readable findings file and we did not" is the sentence that explains
# why item 7 was ever written, two lines above the paragraph describing the file
# it shipped. Past-tense narration of a motive is how every gate header in this
# repository opens; a check that flagged it would be fighting the house style to
# find nothing. What B4 is for is a claim of absence made in the PRESENT.
ABSENCE = ("yet", "nowhere", "unimplemented",
           "not implemented", "does not exist", "not built")

CITE = re.compile(r"backlog\s*(?:item\s*)?#?\s*(\d{1,2})\b", re.I)

# Quoting the defect is how this repository documents it: a gate header opens by
# quoting the sentence that motivated it, a docs section blockquotes the stale
# line it retired, a self-test must contain the exact string it tests. All three
# tripped B4 while it was being written, and none of them was a stale reason -
# they were the record of one. The exemption is a deliberate token on the line
# or the one above it, and every use is COUNTED AND PRINTED, because a silent
# exemption is an approval nobody sees. It excuses one line, never a file, never
# a shape: a real stale reason cannot hide behind a blockquote without someone
# typing this next to it.
EXEMPT = "backlog:quoted"


def main(root, doc, inventory_text):
    inventory = {l.strip().lstrip("· ").split()[0]
                 for l in inventory_text.splitlines() if l.strip()}
    inventory = {g for g in inventory if g.startswith("gate-")}
    if not inventory:
        unmeasurable("the runner listed no gate at all, so every row would look unkept: "
                   "this gate checks the table against run-all.sh --list and had nothing to check against")
        return 2
    try:
        text = open(doc, encoding="utf-8").read()
    except OSError as exc:
        unmeasurable("the competitive analysis could not be read, and it is the document this gate "
                   "exists to keep honest: %s" % exc)
        return 2

    # --- the table: the one whose header carries both `#` and `Status`
    rows, header = {}, None
    lines = text.split("\n")
    for i, line in enumerate(lines):
        if line.startswith("| # | Status | Item |"):
            header = i
            break
    if header is None:
        unmeasurable("no backlog table with a `Status` column was found in %s. The column is what this "
                   "gate reads; without it the roadmap is prose again and nothing here is measured"
                   % os.path.relpath(doc, root))
        return 2
    for line in lines[header + 2:]:
        if not line.startswith("|"):
            break
        cells = [c.strip() for c in line.split("|")]
        if len(cells) < 4 or not cells[1].isdigit():
            break
        num = int(cells[1])
        status = cells[2].replace("*", "").strip().lower()
        rows[num] = (status, line)
    if not rows:
        unmeasurable("the backlog table has a header and no rows, so B1..B4 would all pass over nothing")
        return 2

    # --- B1 / B2 / B3
    kept = 0
    for num, (status, line) in sorted(rows.items()):
        if status not in STATUSES:
            findings.append("B1 backlog item %d declares status %r, which is not one of %s: a status "
                            "nobody defined cannot be checked, and an unchecked status is the prose "
                            "this column replaced" % (num, status, "/".join(STATUSES)))
            continue
        named = set(re.findall(r"`(gate-[A-Za-z0-9_.-]+\.sh)`", line))
        missing = sorted(named - inventory)
        if status in ("shipped", "partial"):
            if not named:
                findings.append("B2 backlog item %d says %s and names no gate file. `shipped` is a claim "
                                "about the gate directory; without a `gate-*.sh` in the row there is "
                                "nothing to verify it against" % (num, status))
            elif missing:
                findings.append("B2 backlog item %d says %s and names %s, which the runner does not have. "
                                "Either the gate was renamed and the row was not, or the item is not "
                                "shipped after all" % (num, status, ", ".join("`%s`" % g for g in missing)))
            else:
                kept += 1
        elif status == "open" and named and not missing:
            findings.append("B3 backlog item %d is listed as open and names %s, which exists and runs. "
                            "An item built and never crossed off sends the next reader to build it twice"
                            % (num, ", ".join("`%s`" % g for g in sorted(named))))

    shipped = sum(1 for s, _ in rows.values() if s.replace("*", "") == "shipped")
    info.append("B1/B2/B3: %d backlog items — %d shipped, %d partial, %d open; %d row(s) name a gate the "
                "runner has" % (len(rows), shipped,
                                sum(1 for s, _ in rows.values() if s == "partial"),
                                sum(1 for s, _ in rows.values() if s == "open"), kept))

    # --- B4: the rest of the repository, against the table
    scanned, cites, exempt = 0, 0, 0
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames
                       if d not in (".git", "node_modules", "__pycache__", "runs")]
        for name in filenames:
            if not name.endswith((".sh", ".md", ".py", ".json", ".yml", ".yaml")):
                continue
            path = os.path.join(dirpath, name)
            rp = os.path.relpath(path, root)
            if rp == os.path.relpath(doc, root):
                continue          # the table is allowed to describe itself
            try:
                body = open(path, encoding="utf-8").read()
            except (OSError, UnicodeDecodeError):
                continue
            if "backlog" not in body.lower():
                continue
            scanned += 1
            body_lines = body.split("\n")
            for n, line in enumerate(body_lines, 1):
                low = line.lower()
                marked = EXEMPT in line or (n > 1 and EXEMPT in body_lines[n - 2])
                for m in CITE.finditer(line):
                    num = int(m.group(1))
                    if num not in rows:
                        continue
                    cites += 1
                    if rows[num][0] != "shipped":
                        continue
                    hit = next((w for w in ABSENCE if w in low), None)
                    if hit and marked:
                        exempt += 1
                    elif hit:
                        findings.append(
                            "B4 %s:%d cites backlog #%d beside %r, and row %d ships. A reason that has "
                            "gone stale is read as a live one: the caveat may still hold, but the item "
                            "it blames no longer explains it" % (rp, n, num, hit, num))
    info.append("B4: %d citation(s) of a backlog row, across %d file(s), checked against the table"
                % (cites, scanned))
    if exempt:
        info.append("B4: %d line(s) marked `%s`, which quote a retired reason on purpose"
                    % (exempt, EXEMPT))
    # The guard counts CITATIONS, not files. The first version counted files
    # containing the word "backlog", and this gate's own wrapper, core and
    # self-test all contain it - so the arm could never reach 0 and was a safety
    # net that could not fall. The same shape had already been fixed once, in A4
    # of gate-corpus-identifiers.sh, where every declaration counted as its own
    # citation. What B4 needs to know is whether any resolvable `backlog #N`
    # survives outside the table; strip the numbers and this fires.
    if cites == 0:
        unmeasurable("no line outside the document cites a numbered backlog item any more, so B4 "
                     "compared nothing against the table; either the citations went away or this "
                     "gate stopped recognising them")
        return 2
    return 1 if findings else 0


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("usage: competitive_backlog.py <repo-root> <doc> <inventory-file>", file=sys.stderr)
        sys.exit(2)
    try:
        inv = open(sys.argv[3], encoding="utf-8").read()
    except OSError as exc:
        print("UNMEASURED the runner inventory could not be read: %s" % exc)
        sys.exit(2)
    code = main(sys.argv[1], sys.argv[2], inv)
    for line in info:
        print(line)
    for line in findings:
        print("FINDING " + line)
    for line in unmeasured:
        print("UNMEASURED " + line)
    sys.exit(code)
