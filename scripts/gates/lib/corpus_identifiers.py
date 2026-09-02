#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# corpus_identifiers.py — the measurement core for gate-corpus-identifiers.sh.
#
# Three checks, and the third is the one that matters.
#
#   A1  no procedure id appears twice anywhere in the corpus
#   A2  no hole in a pack's numbering (a jump is a procedure lost in a merge)
#   A3  every standards identifier the corpus cites falls inside the scheme
#       that references/traceability.md declares for that standard
#   A4  every INTERNAL identifier the corpus cites resolves to one it declares
#
# A4 is A3 turned on the corpus's own ids, and it was the larger hole. A1 notices
# two procedures sharing an id; A2 notices the hole a lost procedure leaves in
# its pack; A3 guards the ids the corpus borrows from standards. None of the
# three ever looked at the sentences pointing AT a procedure - the run that
# added this check found 960 of them, every one unguarded since the corpus was
# written. Renumber a pack, merge two procedures, delete the last one (which
# leaves no hole for A2 to see), and every citation of what went away still
# reads as real: the failure the citation policy describes for a fabricated
# standards id, sourced from inside instead of from a bibliography.
#
# A3 exists because of a sentence in the citation policy itself: "Inventing a
# plausible-looking ID is a fabrication, and a fabricated identifier is worse
# than no identifier because it survives review by looking correct." `A11:2025`,
# `V18`, `API11:2023`, `CICD-SEC-14` and `MASVS-STORAGE-1-L2` all read as real
# to anyone who does not hold the standard open beside them.
#
# THE BOUNDS ARE NOT THIS FILE'S TO OWN. traceability.md is the authority, and
# every bound below is paired with a probe that must still find that same number
# in the document. If the corpus adopts a newer standard with a different shape,
# the probe stops matching and this gate returns 2 - could not measure - instead
# of quietly enforcing last year's scheme against this year's text.
#
# Output protocol: FINDING <text>, UNMEASURED <text>, anything else is info.
# Exit: 0 measured fine · 1 measured FAILS · 2 could not measure.
# ---------------------------------------------------------------------------
import collections
import os
import re
import sys

findings = []
unmeasured = []
info = []


def finding(msg):
    findings.append(msg)


def unmeasurable(msg):
    unmeasured.append(msg)


# --- the families, each with the bound and the probe that must still confirm it
#
# The probe reads ONE row of the "Verified state of each standard" table - the
# row whose first cell is `row`, matched exactly - and its group(1) must equal
# `expect`. Anchoring matters: an unanchored probe found the same scheme written
# in the mapping table further down, so deleting the standard's own declaration
# left the gate happily enforcing a bound the document no longer stated.
# `row = None` means the probe reads the whole document, which is only safe for
# a phrase that appears nowhere else.
FAMILIES = [
    # name, regex over the corpus, validator, table row, probe within it, expect
    ("OWASP Top 10",
     r"\bA(\d{2}):(\d{4})\b",
     lambda m: (None if 1 <= int(m.group(1)) <= 10 else "rank outside A01..A10")
               or (None if m.group(2) == "2025" else "year is not the declared 2025"),
     "OWASP Top 10", r"\*\*(\d{4})\*\*", "2025"),
    ("OWASP API Top 10",
     r"\bAPI(\d{1,2}):(\d{4})\b",
     lambda m: (None if 1 <= int(m.group(1)) <= 10 else "rank outside API1..API10")
               or (None if m.group(2) == "2023" else "year is not the declared 2023"),
     "OWASP API Security Top 10", r"`API1:(\d{4})`\.\.`API10:\d{4}`", "2023"),
    ("OWASP LLM Top 10",
     r"\bLLM(\d{2}):(\d{4})\b",
     lambda m: (None if 1 <= int(m.group(1)) <= 10 else "rank outside LLM01..LLM10")
               or (None if m.group(2) == "2026" else "year is not the declared 2026"),
     "OWASP Top 10 for LLM Applications", r"`LLM01:(\d{4})`\.\.`LLM10:\d{4}`", "2026"),
    ("OWASP Agentic Top 10",
     r"\bASI(\d{2})\b",
     lambda m: None if 1 <= int(m.group(1)) <= 10 else "outside ASI01..ASI10",
     "OWASP Top 10 for Agentic Applications", r"`ASI01`\.\.`ASI(\d{2})`", "10"),
    ("OWASP CI/CD Top 10",
     r"\bCICD-SEC-(\d{1,2})\b",
     lambda m: None if 1 <= int(m.group(1)) <= 10 else "outside CICD-SEC-1..CICD-SEC-10",
     "OWASP Top 10 CI/CD Security Risks", r"`CICD-SEC-1`\.\.`CICD-SEC-(\d{1,2})`", "10"),
    ("OWASP ASVS chapter",
     r"\bASVS[^\n]{0,12}?\bV(\d{1,2})\b",
     lambda m: None if 1 <= int(m.group(1)) <= 17 else "chapter outside V1..V17",
     "OWASP ASVS", r"chapters `V1`\.\.`V(\d{1,2})`", "17"),
    ("OWASP WSTG",
     r"\bWSTG-([A-Z]{4})-(?:\*|\d{2})(?![A-Z0-9-])",
     lambda m: None if m.group(1) in {
         "INFO", "CONF", "IDNT", "ATHN", "ATHZ", "SESS",
         "INPV", "ERRH", "CRYP", "BUSL", "CLNT", "APIT"
     } else "category is not one of the 12 declared",
     "OWASP WSTG", r"`WSTG-<CAT>-<NN>`, (\d{1,2}) categories", "12"),
    ("OWASP MASVS group",
     r"\bMASVS-([A-Z]+)-\d+\b",
     lambda m: None if m.group(1) in {
         "STORAGE", "CRYPTO", "AUTH", "NETWORK",
         "PLATFORM", "CODE", "RESILIENCE", "PRIVACY"
     } else "group is not one of the 8 declared",
     "OWASP MASVS", r"`MASVS-<GROUP>-<N>`, (\d) groups", "8"),
    ("OWASP MASVS level",
     r"\bMASVS-[A-Z]+-\d+-?(L1|L2|R)\b",
     lambda m: "L1/L2/R are MAS testing profiles, never a level on a control",
     "OWASP MASVS", r"no (L1/L2/R) \*\*control\*\* levels", "L1/L2/R"),
    ("CIS Controls",
     r"CIS[^\n]{0,14}?Control\s+(\d{1,2})\b",
     lambda m: None if 1 <= int(m.group(1)) <= 18 else "outside Control 1..18",
     "CIS Controls", r"v8\.1, (\d{2}) controls", "18"),
    ("SLSA Build level",
     r"\bSLSA\s+Build\s+L(\d)\b",
     lambda m: None if 0 <= int(m.group(1)) <= 3 else "Build level outside L0..L3",
     "SLSA", r"Build `L0`\.\.`L(\d)`", "3"),
    ("SLSA Source level",
     r"\bSLSA\s+Source\s+L(\d)\b",
     lambda m: None if 1 <= int(m.group(1)) <= 4 else "Source level outside L1..L4",
     "SLSA", r"Source `L1`\.\.`L(\d)`", "4"),
    ("NIST SSDF group",
     r"\bSSDF\s+([A-Z]{2})\.",
     lambda m: None if m.group(1) in {"PO", "PS", "PW", "RV"}
               else "practice group is not one of PO/PS/PW/RV",
     "NIST SP 800-218 (SSDF)", r"`(PO)`/`PS`/`PW`/`RV`", "PO"),
]


def main(root):
    refs = os.path.join(root, "skills", "ethical-hacker-squad", "references")
    trace_path = os.path.join(refs, "traceability.md")
    if not os.path.isdir(refs):
        unmeasurable("the corpus references directory is not where this gate expects it: %s" % refs)
        return 2
    try:
        trace = open(trace_path, encoding="utf-8").read()
    except OSError as exc:
        unmeasurable("traceability.md declares every bound this gate enforces and could not be read: %s" % exc)
        return 2

    # --- the corpus: everything a specialist can load, minus the authority itself
    paths = [os.path.join(root, "skills", "ethical-hacker-squad", "SKILL.md")]
    for d in (refs, os.path.join(refs, "knowledge")):
        try:
            paths += [os.path.join(d, f) for f in sorted(os.listdir(d)) if f.endswith(".md")]
        except OSError as exc:
            unmeasurable("a corpus directory could not be listed: %s" % exc)
            return 2
    paths = [p for p in paths if os.path.basename(p) != "traceability.md"]
    texts = {}
    for p in paths:
        try:
            texts[p] = open(p, encoding="utf-8").read()
        except OSError as exc:
            unmeasurable("a corpus file could not be read, so this run measured only part of it: %s" % exc)
            return 2
    if not texts:
        unmeasurable("no corpus file was found to check; a green here would mean nothing")
        return 2

    def rel(p):
        return os.path.relpath(p, root)

    # --- A1 / A2: procedure ids
    heading = re.compile(r"^###\s+([A-Z]{2,5})-(\d{2,3})\b", re.M)
    seen = collections.defaultdict(list)
    for p, t in texts.items():
        for m in heading.finditer(t):
            seen[(m.group(1), int(m.group(2)))].append(rel(p))
    if not seen:
        unmeasurable("no procedure heading matched at all: the corpus changed shape and this gate is checking nothing")
        return 2
    for (pref, num), where in sorted(seen.items()):
        if len(where) > 1:
            finding("A1 procedure %s-%02d is declared %d times (%s): two procedures under one id means a citation "
                    "resolves to whichever the reader opened first" % (pref, num, len(where), ", ".join(sorted(set(where)))))
    by_prefix = collections.defaultdict(list)
    for pref, num in seen:
        by_prefix[pref].append(num)
    for pref, nums in sorted(by_prefix.items()):
        lo, hi = min(nums), max(nums)
        holes = [n for n in range(lo, hi + 1) if n not in nums]
        if holes:
            finding("A2 pack %s skips %s (declared %s-%02d..%s-%02d): a hole is the shape a procedure lost in a "
                    "merge leaves behind" % (pref, ", ".join("%s-%02d" % (pref, h) for h in holes), pref, lo, pref, hi))
    info.append("A1/A2: %d procedures across %d prefixes, %d files"
                % (len(seen), len(by_prefix), len(texts)))

    # --- A4: the corpus's own ids, cited against declared
    #
    # Two declaration shapes, because the corpus has two. Procedures declare
    # themselves as `### XXX-NN Title` (A1/A2 above collected those). The triage
    # rules declare themselves as the first cell of a table row, `| `FP-01` | ...`,
    # and a check that knew only the first shape would call all 394 citations of
    # `FP-*` dangling - the gate accusing the corpus of its own blind spot.
    rule_row = re.compile(r"^\|\s*`([A-Z]{2,5})-(\d{2,3})`\s*\|", re.M)
    declared = {"%s-%02d" % (pref, num) for pref, num in seen}
    rules = 0
    for p, t in texts.items():
        for m in rule_row.finditer(t):
            declared.add("%s-%02d" % (m.group(1), int(m.group(2))))
            rules += 1
    if rules == 0:
        # Same doctrine as the A3 probes: the corpus is the authority on how it
        # declares things. If the rule tables stop having this shape, A4 would
        # keep matching citations against headings alone and report the triage
        # rules as fabricated. That green-turned-red would be this file's fault.
        unmeasurable("no triage rule is declared as a table row any more, so A4 would measure the corpus's "
                     "citations against half its declarations; the shape changed and this gate did not")
        return 2

    # A prefix is internal because the corpus declares it, never because this
    # file remembers it. That is what keeps `CICD-SEC-14` and `WSTG-INPV-05` out:
    # `SEC` and `INPV` are nobody's pack here, so their ids are A3's business.
    internal = {d.split("-")[0] for d in declared}
    cited = re.compile(r"\b([A-Z]{2,5})-(\d{2,3})\b")
    dangling = collections.defaultdict(list)
    checked = 0
    # A declaration is not a cross-reference. `### REM-07` and `| `FP-08` |` name
    # an id in the act of creating it, so counting them would make the guard
    # below unfireable: a corpus that declared 187 ids and cross-referenced none
    # would still report 187 citations checked and pass as if it had measured
    # something. What A4 is for is the OTHER mentions.
    #
    # Skip the declaring OCCURRENCE, not the line. A rule row declares one id in
    # its first cell and cross-references three more further along; dropping the
    # whole line hid 63 of them behind the declaration that shared it.
    heading_line = re.compile(r"^###\s+[A-Z]{2,5}-\d{2,3}\b")
    for p, t in texts.items():
        for i, line in enumerate(t.split("\n"), 1):
            d = heading_line.match(line) or rule_row.match(line)
            for m in cited.finditer(line, d.end() if d else 0):
                if m.group(1) not in internal:
                    continue
                checked += 1
                key = "%s-%02d" % (m.group(1), int(m.group(2)))
                if key not in declared:
                    dangling[key].append("%s:%d" % (rel(p), i))
    for key, where in sorted(dangling.items()):
        shown = ", ".join(where[:3]) + (" and %d more" % (len(where) - 3) if len(where) > 3 else "")
        finding("A4 `%s` is cited %d time(s) (%s) and declared nowhere in the corpus: a reader who follows it "
                "finds nothing, and a citation that resolves to nothing survives review by looking correct"
                % (key, len(where), shown))
    info.append("A4: %d cross-references checked against %d declared ids across %d prefixes (%s)"
                % (checked, len(declared), len(internal), ", ".join(sorted(internal))))
    if checked == 0:
        unmeasurable("not one internal id is cross-referenced anywhere in the corpus: either the corpus stopped "
                     "cross-referencing itself or this gate stopped recognising how it does")
        return 2

    # --- A3: cited standards identifiers, against the scheme traceability.md declares
    reached = collections.OrderedDict()
    rows = {}
    for line in trace.splitlines():
        if line.startswith("|"):
            cells = line.split("|")
            if len(cells) > 2:
                rows.setdefault(cells[1].strip(), line)

    for name, pattern, check, row, probe, expect in FAMILIES:
        where = rows.get(row) if row else trace
        if where is None:
            unmeasurable("%s: traceability.md has no row for %r in its table of verified standards, so this gate "
                         "cannot confirm the scheme it is about to enforce" % (name, row))
            return 2
        pm = re.search(probe, where)
        if not pm:
            unmeasurable("%s: traceability.md no longer declares its scheme where this gate reads it, so the bound "
                         "being enforced is this gate's memory rather than the document's statement" % name)
            return 2
        if pm.group(1) != expect:
            unmeasurable("%s: traceability.md now declares %r where this gate was built for %r. The document is the "
                         "authority; update the gate deliberately rather than let it check the old scheme"
                         % (name, pm.group(1), expect))
            return 2
        rx = re.compile(pattern)
        n = 0
        for p, t in texts.items():
            for m in rx.finditer(t):
                n += 1
                why = check(m)
                if why:
                    finding("A3 %s in %s cites `%s`: %s" % (name, rel(p), m.group(0), why))
        reached[name] = n

    empty = [k for k, v in reached.items() if v == 0]
    info.append("A3: %d citations checked across %d families"
                % (sum(reached.values()), len(reached)))
    if empty:
        info.append("A3: %d families are cited nowhere in the corpus and so could not fail here: %s"
                    % (len(empty), ", ".join(empty)))
    return 1 if findings else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: corpus_identifiers.py <repo-root>", file=sys.stderr)
        sys.exit(2)
    code = main(sys.argv[1])
    for line in info:
        print(line)
    for line in findings:
        print("FINDING " + line)
    for line in unmeasured:
        print("UNMEASURED " + line)
    sys.exit(code)
