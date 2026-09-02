#!/usr/bin/env python3
"""Measurement core for gate-untrusted-content.sh.

Prints one line per problem and returns 1 if it found any, 0 if it measured and
found none, 2 if it could not measure. The wrapper turns those into the gate's
verdict; the crash discriminator lives there, because a python3 that dies also
exits 1 and the two are indistinguishable from outside.

  FINDING <text>      measured, and it is wrong
  UNMEASURED <text>   could not measure - never a pass
  anything else       information
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

REGISTRY = "scripts/gates/data/untrusted-content-contract.json"

# A numbered rule of the safety contract: `1. **...` at the start of a line.
RULE_RE = re.compile(r"^(\d+)\.\s", re.M)


def section_of(text: str, heading: str) -> str | None:
    """The body under `heading`, up to the next heading of the same depth.

    An empty heading means the whole file: some clauses live in a table row or a
    prose paragraph that carries no heading of its own, and inventing one just
    to be checkable would be the document bending to the gate.
    """
    if not heading:
        return text
    i = text.find(heading)
    if i < 0:
        return None
    depth = len(heading) - len(heading.lstrip("#"))
    rest = text[i + len(heading):]
    nxt = re.search(r"^#{1,%d} " % depth, rest, re.M)
    return rest[: nxt.start()] if nxt else rest


def main(root_s: str) -> int:
    root = pathlib.Path(root_s)
    reg_path = root / REGISTRY
    if not reg_path.is_file():
        print(f"UNMEASURED the registry is missing: {REGISTRY}")
        return 2
    try:
        reg = json.loads(reg_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        print(f"UNMEASURED {REGISTRY} will not parse: {e}")
        return 2

    for key in ("clauses", "safety_contract", "hedges"):
        if key not in reg:
            print(f"UNMEASURED {REGISTRY} has no `{key}`: nothing to compare against")
            return 2

    hedges = [h.lower() for h in reg["hedges"].get("refused", [])]
    if not hedges:
        print("UNMEASURED the hedge list is empty: modality would go unmeasured")
        return 2

    findings = 0
    unmeasured = 0
    cache: dict[str, str] = {}

    def read(rel: str) -> str | None:
        if rel not in cache:
            p = root / rel
            try:
                cache[rel] = p.read_text(encoding="utf-8")
            except OSError as e:
                print(f"UNMEASURED cannot read {rel}: {e}")
                return None
        return cache[rel]

    # ---- direction 1: every registered clause is still in the corpus --------
    for c in reg["clauses"]:
        cid = c.get("id", "<unnamed>")
        rel = c.get("file", "")
        text = read(rel)
        if text is None:
            unmeasured += 1
            continue
        body = section_of(text, c.get("section", ""))
        if body is None:
            print(f"UNMEASURED {cid}: {rel} no longer has the section `{c.get('section')}`")
            unmeasured += 1
            continue
        for needle in c.get("must_contain", []):
            if needle not in body:
                print(f"FINDING {cid}: `{rel}` no longer says \"{needle}\" -- "
                      f"{c.get('why', 'a load-bearing clause went missing')}")
                findings += 1
                continue
            # Modality. The substring surviving is not the rule surviving: a
            # line can keep every required token and stop being absolute.
            for line in body.splitlines():
                if needle not in line:
                    continue
                low = line.lower()
                for h in hedges:
                    if h in low:
                        print(f"FINDING {cid}: the clause in `{rel}` still carries its words "
                              f"but was softened with \"{h}\" -- an absolute rule that admits "
                              f"a normal case is not an absolute rule")
                        findings += 1

    # ---- direction 2: the safety contract's rules, both ways ----------------
    sc = reg["safety_contract"]
    rel = sc.get("file", "")
    text = read(rel)
    if text is None:
        unmeasured += 1
    else:
        body = section_of(text, sc.get("heading", ""))
        if body is None:
            print(f"UNMEASURED the safety contract heading `{sc.get('heading')}` is gone from {rel}")
            unmeasured += 1
        else:
            present = sorted({int(m) for m in RULE_RE.findall(body)})
            declared = sorted(sc.get("rules_registered", []))
            if not present:
                print(f"UNMEASURED no numbered rule found under `{sc.get('heading')}` in {rel}: "
                      f"the parser found nothing, which is not the same as an empty contract")
                unmeasured += 1
            else:
                for n in declared:
                    if n not in present:
                        print(f"FINDING safety contract rule {n} is registered and no longer "
                              f"present in `{rel}`")
                        findings += 1
                for n in present:
                    if n not in declared:
                        print(f"FINDING safety contract rule {n} is present in `{rel}` and "
                              f"registered nowhere: a rule nobody declared is a rule nobody "
                              f"notices going missing")
                        findings += 1
                print(f"safety contract: {len(present)} numbered rule(s), "
                      f"{len(declared)} registered, reconciled both ways")

    print(f"measured: {len(reg['clauses'])} clause(s) across "
          f"{len({c.get('file') for c in reg['clauses']})} file(s), "
          f"{len(hedges)} hedge(s) refused")

    if unmeasured:
        return 2
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
