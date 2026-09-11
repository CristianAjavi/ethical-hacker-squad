"""Audit bench/stages/routing against the routing table that forces its key.

Prints `rc|message` lines: 0 informational, 1 measured failure, 2 could not
measure. Nothing here scores a model; see PREREGISTRATION.md in the dataset.

The three parts are deliberately different in kind. The first re-derives the key
from `references/coverage.md`, so a key that drifts from the table is a failure
rather than a second opinion. The second builds a router out of the table's own
words and reports what it scores: a routing set the trivial router answers
perfectly measures string matching, not routing. The third takes that reported
score back to the pre-registration and the dataset README and fails when they
disagree with it -- the number is derived from `coverage.md`, which is free to
change, and a document that froze an older value is a document this gate was
refuting on screen and never comparing.
"""

import hashlib
import json
import re
import sys
from collections import Counter
from pathlib import Path

BACKTICK = re.compile(r"`([^`]+)`")
WORD = re.compile(r"[a-z][a-z0-9_.-]{3,}")

# Where the two documents that quote this gate's score declare it. Both are
# SECTIONS, not whole files: a pre-registration keeps its superseded record and
# a README counts other things out of twenty-two, and a scan over a whole file
# would accuse prose that is right.
REGISTRATION_HEADING = "## Registration in force"
SUPERSEDED_HEADING = "## Superseded registrations"
# In the dataset README the scanned scope is every section whose heading names
# the router, so a second section quoting the score is read without anyone
# having to remember to register it -- and the sections counting other things
# out of the same total are left alone.
ROUTER_HEADING_MARK = "table-word router"
FENCE = re.compile(r"```json\n(.*?)```", re.S)
FRACTION = re.compile(r"\b(\d{1,3})\s*(?:/|\bof\b)\s*(\d{1,3})\b")

# A word that names many rows cannot separate them. Derived from the table
# rather than listed here, so the baseline has no hand-tuned vocabulary.
MAX_DF = 3


def emit(rc, message):
    print(f"{rc}|{message}")


def parse_table(text):
    rows = []
    for lineno, line in enumerate(text.splitlines(), 1):
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 4 or cells[0].startswith("---") or cells[0] == "Signal in the inventory":
            continue
        rows.append({"line": lineno, "signal": cells[0], "role": cells[1],
                     "sections": cells[2], "notes": cells[3]})
    return rows


def dig(obj, path):
    """Resolve a dotted path, treating `[]` as 'every element'. Yields strings."""
    if not path:
        if isinstance(obj, str):
            yield obj
        return
    head, _, rest = path.partition(".")
    if head.endswith("[]"):
        head = head[:-2]
        seq = obj.get(head) if isinstance(obj, dict) else None
        for item in seq or []:
            yield from dig(item, rest)
        return
    nxt = obj.get(head) if isinstance(obj, dict) else None
    if nxt is not None:
        yield from dig(nxt, rest)


def build_router(rows):
    """Tokens per row: every backticked string, plus content words the table
    itself does not spread across many rows."""
    per_row_words = []
    for r in rows:
        plain = BACKTICK.sub(" ", r["signal"]).lower()
        per_row_words.append(set(WORD.findall(plain)))
    df = Counter()
    for words in per_row_words:
        df.update(words)
    router = []
    for r, words in zip(rows, per_row_words):
        marks = {m.lower() for m in BACKTICK.findall(r["signal"])}
        router.append({"row": r,
                       "marks": {m for m in marks if m},
                       "words": {w for w in words if df[w] <= MAX_DF}})
    return router


def predict(router, text):
    low = text.lower()
    best, best_score = None, 0
    for entry in router:
        score = 3 * sum(1 for m in entry["marks"] if m in low)
        score += sum(1 for w in entry["words"] if re.search(rf"(?<![a-z0-9]){re.escape(w)}(?![a-z0-9])", low))
        if score > best_score:
            best, best_score = entry["row"], score
    return best


def section(text, heading):
    """The body under a `## ` heading, up to the next one. None if absent."""
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.strip() == heading:
            body = []
            for nxt in lines[i + 1:]:
                if nxt.startswith("## "):
                    break
                body.append(nxt)
            return "\n".join(body)
    return None


def without_section(text, heading):
    """The file with one `## ` section removed. The superseded record is history
    and is meant to keep the numbers it froze; scanning it would accuse it of
    being what it says it is."""
    lines, out, skip = text.splitlines(), [], False
    for line in lines:
        if line.startswith("## "):
            skip = line.strip() == heading
        if not skip:
            out.append(line)
    return "\n".join(out)


def sections_naming(text, mark):
    """Every `## ` section whose heading contains `mark`, as one string."""
    lines, out, keep, seen = text.splitlines(), [], False, 0
    for line in lines:
        if line.startswith("## "):
            keep = mark.lower() in line.lower()
            seen += keep
        if keep:
            out.append(line)
    return ("\n".join(out), seen) if seen else (None, 0)


def prose_of(body):
    """The section body with its fenced JSON removed, so the block this gate
    parses is not also scanned as prose quoting it."""
    return FENCE.sub(" ", body)


def stray_fractions(prose, total, allowed):
    """Fractions over `total` whose numerator is not a score this gate printed.
    A denominator that is not the case count is somebody counting something
    else, and is left alone."""
    out = set()
    for num, den in FRACTION.findall(prose):
        if int(den) == total and int(num) not in allowed:
            out.add(f"{num}/{den}")
    return sorted(out)


def check_registration(root, prereg_rel, readme_rel, dataset_dir,
                       case_ids, total, role_right, full_right, hard):
    """The pre-registered primary metric still describes the set just measured,
    and the dataset README still quotes the score just printed.

    Returns True when something failed. A registration that cannot be read is
    reported as could-not-measure, never as fine.
    """
    bad = False
    prereg = root / prereg_rel
    if not prereg.is_file():
        emit(2, f"missing {prereg_rel}, so the pre-registered primary metric cannot be compared "
                f"with what this gate just measured")
        return bad
    body = section(prereg.read_text(encoding="utf-8"), REGISTRATION_HEADING)
    if body is None:
        emit(2, f"{prereg_rel} has no `{REGISTRATION_HEADING}` section, so there is no "
                f"registration to compare the score against and its silence means nothing")
        return bad
    block = FENCE.search(body)
    if not block:
        emit(2, f"`{REGISTRATION_HEADING}` in {prereg_rel} carries no ```json block")
        return bad
    try:
        reg = json.loads(block.group(1))
    except ValueError as exc:
        emit(2, f"the registration block in {prereg_rel} does not parse: {exc}")
        return bad
    scored = reg.get("table_word_router")
    primary = reg.get("primary_cases")
    if not isinstance(scored, dict) or not isinstance(primary, list):
        emit(2, f"the registration block in {prereg_rel} needs `table_word_router` and "
                f"`primary_cases`")
        return bad

    declared_total = scored.get("total")
    if declared_total != total:
        bad = True
        emit(1, f"{prereg_rel} registers {declared_total} case(s) and the dataset holds {total}")
    for field, measured, what in (("role", role_right, "the role"),
                                  ("role_and_sections", full_right, "role and sections")):
        if scored.get(field) != measured:
            bad = True
            emit(1, f"{prereg_rel} registers {scored.get(field)}/{declared_total} on {what} and "
                    f"this run measured {measured}/{total} -- the registration was frozen against "
                    f"a routing table that has changed since, and a gate printing one number "
                    f"beside a document declaring another is refuting it on screen without ever "
                    f"comparing them")
    if sorted(primary) != sorted(hard):
        bad = True
        gone = sorted(set(primary) - set(hard))
        new = sorted(set(hard) - set(primary))
        emit(1, f"{prereg_rel} registers the primary set as "
                f"{', '.join(sorted(primary)) or 'none'} and this run measured "
                f"{', '.join(sorted(hard)) or 'none'}"
                + (f" -- no longer hard: {', '.join(gone)}" if gone else "")
                + (f" -- newly hard: {', '.join(new)}" if new else ""))

    # Everything the pre-registration says outside its superseded record is in
    # force, not just the block: the sentence that contradicted this gate on
    # 2026-09-10 lived four sections away from it.
    live = without_section(prereg.read_text(encoding="utf-8"), SUPERSEDED_HEADING)
    allowed = {role_right, full_right}
    readme_body, readme_n = None, 0
    if (root / readme_rel).is_file():
        readme_body, readme_n = sections_naming(
            (root / readme_rel).read_text(encoding="utf-8"), ROUTER_HEADING_MARK)
    for rel, text, heading in (
            (prereg_rel, live, f"everything outside `{SUPERSEDED_HEADING}`"),
            (readme_rel, readme_body, f"the {readme_n} section(s) naming the "
                                      f"`{ROUTER_HEADING_MARK}`")):
        if text is None:
            emit(2, f"{rel} has no section heading naming the `{ROUTER_HEADING_MARK}`, so what "
                    f"it says about this gate's score is not being read")
            continue
        stray = stray_fractions(prose_of(text), total, allowed)
        if stray:
            bad = True
            emit(1, f"{heading} in {rel} states {', '.join(stray)} over {total} and this run "
                    f"measured {role_right}/{total} on the role and {full_right}/{total} on role "
                    f"and sections together")

    prose = prose_of(live)
    cited = sorted(c for c in case_ids
                   if re.search(rf"(?<![A-Za-z0-9-]){re.escape(c)}(?![A-Za-z0-9-])", prose))
    if cited and cited != sorted(primary):
        bad = True
        emit(1, f"{prereg_rel} names {', '.join(cited)} outside `{SUPERSEDED_HEADING}` and "
                f"registers {', '.join(sorted(primary))} in its block")

    # Re-registering after a result exists is fitting the registration to the
    # result. Superseding before anything has been run costs nothing; after, it
    # is the whole failure a pre-registration exists to prevent.
    if reg.get("supersedes"):
        results = sorted(
            str(f.relative_to(root)) for f in (root / dataset_dir).rglob("*")
            if f.is_file() and ("score" in f.name.lower()
                                or "/runs/" in "/" + f.relative_to(root).as_posix() + "/"))
        if results:
            bad = True
            emit(1, f"{prereg_rel} supersedes an earlier registration while {dataset_dir} already "
                    f"holds a result ({', '.join(results[:3])}) -- a registration rewritten after "
                    f"a number exists is fitted to that number")

    if not bad:
        emit(0, f"the registration in force still describes the set: {role_right}/{total} on the "
                f"role, {full_right}/{total} on role and sections, and the {len(hard)} primary "
                f"case(s) named under `{REGISTRATION_HEADING}`")
    return bad


def main(argv):
    root = Path(argv[1])
    cov_rel = argv[2] if len(argv) > 2 else "skills/ethical-hacker-squad/references/coverage.md"
    cases_rel = argv[3] if len(argv) > 3 else "bench/stages/routing/cases.json"
    key_rel = argv[4] if len(argv) > 4 else "bench/stages/routing/keys/routing-key.json"

    cov_p, cases_p, key_p = root / cov_rel, root / cases_rel, root / key_rel
    for required in (cov_p, cases_p, key_p):
        if not required.is_file():
            emit(2, f"missing {required.relative_to(root)}")
            return

    rows = parse_table(cov_p.read_text(encoding="utf-8"))
    if not rows:
        emit(2, f"{cov_rel} holds no routing row I can parse, so there is nothing to derive from")
        return

    try:
        cases_doc = json.loads(cases_p.read_text(encoding="utf-8"))
        key_doc = json.loads(key_p.read_text(encoding="utf-8"))
    except ValueError as exc:
        emit(2, f"the dataset does not parse: {exc}")
        return

    cases = cases_doc.get("cases")
    answers = key_doc.get("answers")
    fields = cases_doc.get("presented_fields")
    if not isinstance(cases, list) or not isinstance(answers, list) or not isinstance(fields, list):
        emit(2, "cases.json needs `cases` and `presented_fields`, and the key needs `answers`")
        return

    bad = False

    sealed = (key_doc.get("seals") or {}).get("cases.json", "")
    actual = "sha256:" + hashlib.sha256(cases_p.read_bytes()).hexdigest()
    if sealed != actual:
        bad = True
        emit(1, f"{cases_rel} no longer hashes to the digest the key sealed "
                f"({sealed or 'no seal'} vs {actual}) -- the key describes a file that has moved")

    by_case = {c.get("case"): c for c in cases}
    keyed = {a.get("case"): a for a in answers}
    if len(by_case) != len(cases) or len(keyed) != len(answers):
        bad = True
        emit(1, "a case id appears twice, so one of its two rows is unreachable")
    for missing in sorted(set(by_case) - set(keyed)):
        bad = True
        emit(1, f"{missing}: presented as a case and absent from the key")
    for missing in sorted(set(keyed) - set(by_case)):
        bad = True
        emit(1, f"{missing}: answered by the key and absent from cases.json")

    # 1. The key is the table's own cells, or it is wrong.
    by_signal = {}
    for r in rows:
        by_signal.setdefault(r["signal"], []).append(r)
    for cid in sorted(set(by_case) & set(keyed)):
        a = keyed[cid]
        hits = by_signal.get(a.get("row", ""), [])
        if not hits:
            bad = True
            emit(1, f"{cid}: the key names a row that is not in the routing table -- "
                    f"{a.get('row', '')[:70]!r}")
            continue
        if len(hits) > 1:
            emit(2, f"{cid}: the routing table holds {len(hits)} rows with that signal, so "
                    f"the key's row is ambiguous and I will not pick one")
            continue
        r = hits[0]
        for cell in ("role", "sections"):
            if a.get(cell) != r[cell]:
                bad = True
                emit(1, f"{cid}: the key's `{cell}` does not match the table at "
                        f"{cov_rel}:{r['line']} -- key {a.get(cell)!r}, table {r[cell]!r}")

    # 2. The answer stays out of the question. What is forbidden is read out of
    #    the table, never listed here.
    roles = sorted({m for r in rows for m in BACKTICK.findall(r["role"])})
    packs = sorted({m.group(0) for r in rows for m in re.finditer(r"[a-z0-9-]+\.md", r["sections"])})
    ids = sorted({m.group(0) for m in re.finditer(r"\b[A-Z]{2,4}-\d{2}\b", cov_p.read_text(encoding="utf-8"))})
    prefixes = sorted({i.split("-")[0] for i in ids})
    id_re = re.compile(rf"\b(?:{'|'.join(prefixes)})-\d{{2}}\b") if prefixes else None

    for cid in sorted(by_case):
        text = "\n".join(t for f in fields for t in dig(by_case[cid], f) if isinstance(t, str))
        low = text.lower()
        for role in roles:
            if re.search(rf"(?<![a-z0-9-]){re.escape(role.lower())}(?![a-z0-9-])", low):
                bad = True
                emit(1, f"{cid}: a presented field names the role `{role}` -- the case carries its "
                        f"own answer, so what it measures is copying")
        for pack in packs:
            if pack.lower() in low:
                bad = True
                emit(1, f"{cid}: a presented field names the pack file `{pack}`")
        if "§" in text:
            bad = True
            emit(1, f"{cid}: a presented field carries a section marker")
        if id_re:
            found = sorted(set(id_re.findall(text)))
            if found:
                bad = True
                emit(1, f"{cid}: a presented field names {', '.join(found)}")

    if not roles or not packs:
        emit(2, "the routing table declares no role or no pack file in backticks, so the leak scan "
                "has nothing to forbid and its silence means nothing")

    # 3. What a router built from the table's own words scores.
    router = build_router(rows)
    role_right, full_right, hard, blind = [], [], [], []
    for cid in sorted(set(by_case) & set(keyed)):
        text = "\n".join(t for f in fields for t in dig(by_case[cid], f) if isinstance(t, str))
        guess = predict(router, text)
        k = keyed[cid]
        if guess is None:
            blind.append(cid)
        if guess is not None and guess["role"] == k.get("role"):
            role_right.append(cid)
        else:
            hard.append(cid)
        if guess is not None and guess["role"] == k.get("role") and guess["sections"] == k.get("sections"):
            full_right.append(cid)
    total = len(set(by_case) & set(keyed))
    if total:
        emit(0, f"a router built from the routing table's own words -- backticked tokens, plus the "
                f"content words the table does not spread over more than {MAX_DF} rows -- scores "
                f"{len(role_right)}/{total} on the role and {len(full_right)}/{total} on role and "
                f"sections together"
                + (f"; it matched no row at all on {', '.join(blind)}" if blind else ""))
        emit(0, f"the {len(hard)} case(s) it gets wrong are the ones this dataset is for: "
                f"{', '.join(hard) if hard else 'none'}")
        if len(full_right) == total:
            bad = True
            emit(1, f"the table-word router answers every case -- {total}/{total} on role and "
                    f"sections. A routing set solvable by matching the table it was drawn from "
                    f"measures string matching, and has nothing left to say about routing")

        # 4. The documents that quote that score still agree with it.
        dataset_dir = Path(cases_rel).parent.as_posix()
        if check_registration(root, (Path(dataset_dir) / "PREREGISTRATION.md").as_posix(),
                              (Path(dataset_dir) / "README.md").as_posix(), dataset_dir,
                              sorted(by_case), total, len(role_right), len(full_right), hard):
            bad = True

    if not bad:
        emit(0, f"{len(by_case)} case(s), every key row taken from {cov_rel} cell for cell, no "
                f"presented field carrying a role, a pack file, a section marker or a procedure id")


if __name__ == "__main__":
    main(sys.argv)
