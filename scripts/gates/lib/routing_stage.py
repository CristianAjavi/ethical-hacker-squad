"""Audit bench/stages/routing against the routing table that forces its key.

Prints `rc|message` lines: 0 informational, 1 measured failure, 2 could not
measure. Nothing here scores a model; see PREREGISTRATION.md in the dataset.

The two halves are deliberately different in kind. The first re-derives the key
from `references/coverage.md`, so a key that drifts from the table is a failure
rather than a second opinion. The second builds a router out of the table's own
words and reports what it scores: a routing set the trivial router answers
perfectly measures string matching, not routing.
"""

import hashlib
import json
import re
import sys
from collections import Counter
from pathlib import Path

BACKTICK = re.compile(r"`([^`]+)`")
WORD = re.compile(r"[a-z][a-z0-9_.-]{3,}")

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

    if not bad:
        emit(0, f"{len(by_case)} case(s), every key row taken from {cov_rel} cell for cell, no "
                f"presented field carrying a role, a pack file, a section marker or a procedure id")


if __name__ == "__main__":
    main(sys.argv)
