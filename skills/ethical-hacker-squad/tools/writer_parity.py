#!/usr/bin/env python3
"""Two writers to one table. Does the second one check what the first checks?

WHY IT ASKS THAT
    Across the composition corpus this is the densest shape there is - the
    competitor's own run named four instances of it in six services, and two of
    them are defects this project never found in any run:

      ledger-flow  services/postings.py calls posting.clean() before writing;
                   services/importer.py:82 calls bulk_insert_mappings(Posting)
                   and calls nothing.
      atlas-sync   UpsertRecord pins owner_id to the caller the handler
                   resolved; BulkInsertRecords takes it from the payload.

    Both files are defensible. `bulk_insert_mappings` is the documented way to
    load a lot of rows fast, and skipping the ORM lifecycle is the reason it
    exists. The defect is that the invariant lives on the path nobody took.

WHAT IT DOES
    Groups write sites by the ENTITY they write - a model class, a table name in
    SQL, a collection - and reports an entity written from more than one function
    where at least one caller runs a validator and at least one runs none. It
    names both, because the finding is the asymmetry and not either line.

WHAT IT COSTS, MEASURED
    On the six-service corpus it makes **8 distinct flags**. Three fall within
    five lines of a planted defect, four within ten. That is roughly a 40-50%
    hit rate, and it is the number to plan around.

    A first count put it at 100%, using a forty-line window on files of sixty to
    a hundred lines - a window that catches almost anything in the file. The
    honest window is tight, and the honest number is smaller.

    What it buys: `T-15`, a defect this corpus never reported in any run -
    `import_batch()` writing `posting` while `create_entry()` reaches
    `posting.clean()` through a helper.

WHAT IT IS NOT
    Not a detector. A second writer may be validating somewhere this cannot see,
    validating by a name not on the list, or writing rows that were already
    checked upstream. It splits functions by declaration and indentation rather
    than by parsing each language, so a nested closure can be attributed to its
    parent. Read a pair as *go compare these two*, never as a verdict.

Exit codes: 0 = measured, no asymmetry | 1 = measured, asymmetries |
            2 = could not measure.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

WRITE = re.compile(
    r"\b(?:add_all|add|bulk_insert_mappings|bulk_save_objects|insert_many|insert|"
    r"upsert|save|create|update|put_item|write|persist)\s*\(", re.I)

# `execute(` and `exec(` run whatever SQL they are handed, and most of it is not
# a write. Counting them blindly flagged `REINDEX TABLE postings` - a
# maintenance statement - as a second writer that skipped the invariant. They
# count only when the statement beside them actually writes rows.
EXEC = re.compile(r"\b(?:exec|execute|query|raw)\s*\(", re.I)
WRITES_ROWS = re.compile(r"\b(?:INSERT\s+INTO|UPDATE\s+\w|DELETE\s+FROM|UPSERT|MERGE\s+INTO)\b", re.I)
SQL_WRITE = re.compile(r"\b(?:INSERT\s+INTO|UPDATE)\s+[`\"']?(\w+)", re.I)
ENTITY = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]{2,})\b")

# One writer names the class and the other names the variable holding the rows:
#   bulk_insert_mappings(Posting, mappings)      vs   add_all(postings)
# Grouped literally these are two different entities and the asymmetry
# disappears - which is what happened on the first real target, 0 findings on a
# tree with two known instances. Lowercase and drop a trailing plural, so
# `Posting` and `postings` are one thing.
STOP = {"self", "cls", "the", "and", "for", "new", "err", "nil", "none", "true",
        "false", "this", "session", "conn", "ctx", "tx", "db", "row", "rows",
        "data", "item", "items", "value", "values", "result", "obj", "args",
        "commit", "return", "len", "str", "int", "list", "dict", "map", "append",
        "error", "print", "log", "now", "time", "json"}


def norm_entity(word: str) -> str:
    w = word.lower().rstrip("_")
    if w.endswith("ies") and len(w) > 4:
        w = w[:-3] + "y"
    elif w.endswith("es") and len(w) > 4 and w[-3] in "sxz":
        w = w[:-2]
    elif w.endswith("s") and len(w) > 3:
        w = w[:-1]
    return w
VALIDATOR = re.compile(
    r"\b(clean|validate|validated|check|verify|verified|sanitize|sanitise|"
    r"assert\w*|schema|parse|ensure|guard|normalize|normalise|require\w*)\s*\(", re.I)
DECL = re.compile(
    r"^(\s*)(?:async\s+)?(?:def|func|function|fn|sub)\s+([A-Za-z_][\w]*)|"
    r"^(\s*)(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*(?:async\s*)?\(", re.M)
SKIP_DIRS = {".git", "node_modules", "vendor", "dist", "build", "__pycache__", ".venv"}
EXTS = {".py", ".go", ".js", ".ts", ".rb", ".java", ".cs", ".rs", ".php"}


def functions(text: str):
    """(name, start_line, body) for each declaration, body ending at the next
    declaration indented no deeper. Crude on purpose: this has to cross six
    languages, and a parser per language is a different tool."""
    marks = []
    for m in DECL.finditer(text):
        indent = m.group(1) if m.group(1) is not None else m.group(3)
        name = m.group(2) or m.group(4)
        marks.append((m.start(), len(indent or ""), name))
    lines = text.splitlines()
    out = []
    for i, (pos, ind, name) in enumerate(marks):
        start = text[:pos].count("\n")
        end = len(lines)
        for pos2, ind2, _ in marks[i + 1:]:
            if ind2 <= ind:
                end = text[:pos2].count("\n")
                break
        out.append((name, start + 1, "\n".join(lines[start:end])))
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--target", type=Path, required=True)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    if not a.target.exists():
        print(f"UNMEASURABLE the target does not exist: {a.target}")
        return 2
    files = [p for p in sorted(a.target.rglob("*"))
             if p.is_file() and p.suffix in EXTS
             and not any(d in p.parts for d in SKIP_DIRS)]
    if not files:
        print(f"UNMEASURABLE no source file this can read under {a.target}")
        return 2

    # ONE HOP. The invariant is rarely called from the function that writes:
    #   create_entry() -> _validated(posting) -> posting.clean() -> add_all(...)
    # Looking only inside the writing function found ZERO asymmetries on a tree
    # with two known ones, because both writers looked equally unvalidated. So a
    # function counts as validating if it calls a local function that validates.
    # One hop, not a call graph: two hops is a different tool.
    fn_validators: dict[str, list] = {}
    parsed_files = []
    for p in files:
        text = p.read_text(errors="ignore")
        parsed_files.append((p, text))
        for name, line, body in functions(text):
            v = sorted({m.group(1) for m in VALIDATOR.finditer(body)})
            if v:
                fn_validators.setdefault(name, []).extend(v)

    # An entity has to look like an entity somewhere. Without this the tool
    # picked `await`, `digest`, `hex` and `utf8` out of crypto helpers, because
    # `create(`/`write(` appear there and the next identifier is whatever
    # follows. Half its flags on JavaScript were hash functions, not writers.
    #
    # The filter is structural rather than a blocklist: a name counts only if
    # the tree declares it as a class or model, or names it as a SQL table.
    # `Posting` qualifies; `await` never will.
    declared = set()
    for _, text in parsed_files:
        for m in re.finditer(r"\b(?:class|model|table|interface|struct|type)\s+([A-Za-z_]\w*)", text, re.I):
            declared.add(norm_entity(m.group(1)))
        for m in re.finditer(r"__tablename__\s*=\s*['\"](\w+)", text):
            declared.add(norm_entity(m.group(1)))
        for m in SQL_WRITE.finditer(text):
            declared.add(norm_entity(m.group(1)))
        for m in re.finditer(r"\b(?:from|into|join|update)\s+[`\"']?(\w+)", text, re.I):
            declared.add(norm_entity(m.group(1)))
    if not declared:
        print(f"UNMEASURABLE no class, model or table declaration found under {a.target}; "
              "this check has no entity to group by")
        return 2

    writers: dict[str, list] = {}
    for p, text in parsed_files:
        rel = str(p.relative_to(a.target))
        for name, line, body in functions(text):
            hits = set()
            spans = [m for m in WRITE.finditer(body)]
            for m in EXEC.finditer(body):
                if WRITES_ROWS.search(body[m.end():m.end() + 200]):
                    spans.append(m)
            for m in spans:
                tail = body[m.end():m.end() + 120]
                for e in ENTITY.findall(tail):
                    n = norm_entity(e)
                    if n and n not in STOP and len(n) > 2 and n in declared:
                        hits.add(n)
            for m in SQL_WRITE.finditer(body):
                hits.add(norm_entity(m.group(1)))
            if not hits:
                continue
            validators = {v.group(1) for v in VALIDATOR.finditer(body)}
            for callee, vs in fn_validators.items():
                if callee != name and re.search(r"\b" + re.escape(callee) + r"\s*\(", body):
                    validators.update(f"{callee}->{x}" for x in vs)
            validators = sorted(validators)
            for e in hits:
                writers.setdefault(e, []).append(
                    {"where": f"{rel}:{line}", "fn": name, "validators": validators})

    asym = []
    for entity, ws in sorted(writers.items()):
        if len(ws) < 2:
            continue
        checked = [w for w in ws if w["validators"]]
        unchecked = [w for w in ws if not w["validators"]]
        if checked and unchecked:
            asym.append({"entity": entity, "checked": checked, "unchecked": unchecked})

    if a.json:
        print(json.dumps({"files": len(files), "entities": len(writers),
                          "asymmetries": asym}, indent=2))
    else:
        # One line per PLACE, not per entity. A function writing four entities
        # produced four identical lines and turned 8 findings into 15.
        seen = {}
        for x in asym:
            c = x["checked"][0]
            for u in x["unchecked"]:
                key = (u["where"], c["where"])
                seen.setdefault(key, {"u": u, "c": c, "entities": []})["entities"].append(x["entity"])
        for (uw, cw), v in sorted(seen.items()):
            ents = ", ".join(f"`{e}`" for e in sorted(v["entities"])[:3])
            more = f" (+{len(v['entities']) - 3} more)" if len(v["entities"]) > 3 else ""
            print(f"  UNCHECKED    {uw} {v['u']['fn']}() writes {ents}{more} with no validator, "
                  f"while {v['c']['fn']}() at {cw} calls {', '.join(v['c']['validators'][:2])}")
        print(f"  {len(writers)} written entit(ies) in {len(files)} file(s); "
              f"{len(asym)} with one writer checked and another not")
    return 1 if asym else 0


if __name__ == "__main__":
    sys.exit(main())
