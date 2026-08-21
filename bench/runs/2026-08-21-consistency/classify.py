#!/usr/bin/env python3
"""Reduce a finding to the defect it is ABOUT, so runs can be compared.

    python3 classify.py runs/*.json

Two runs of the same review word the same defect differently. Comparing titles
would measure prose; comparing file+line would split one defect reported at two
lines. So each finding is mapped to a defect CLASS by the construct it names,
and a finding that matches no class keeps its own location as its identity
rather than being dropped.

THE CLASSIFIER IS A JUDGEMENT AND IT IS OURS. It is in this file, in full, so
anyone can disagree with it and re-run: the patterns are ordered, first match
wins, and the fallback is deliberately conservative - an unmatched finding
becomes a class of its own, which can only LOWER measured agreement, never
raise it. That is the direction an author of this bench should want the
uncertainty to point.
"""
import json
import re
import sys
import itertools
from pathlib import Path

CLASSES = [
    ("alloc-from-wire-length",        r"readbytes|new byte\[|contentlength"),
    ("uncapped-recursion",            r"recurs|readtable|readarray|stackoverflow|depth"),
    ("declared-length-vs-remaining",  r"remaining|available\(\)|truncat"),
    ("timestamp-overflow",            r"\*\s*1000|timestamp"),
    ("duplicate-keys",                r"duplicate|first-wins|first wins"),
    ("unchecked-exception",           r"unsupportedoperation|unchecked exception"),
    ("codegen-unpinned",              r"codegen|generate-sources|groovy"),
    ("dependency-eol",                r"slf4j|logback|jetty|end-of-life|eol|optional"),
]


def classes_of(path: Path) -> set:
    data = json.loads(path.read_text(encoding="utf-8"))
    out = set()
    for f in data.get("findings", []):
        loc = f.get("location") or {}
        where = (loc.get("path") or f.get("file") or "").split("/")[-1]
        line = loc.get("line") if loc else f.get("line")
        text = " ".join(str(f.get(k, "")) for k in ("title", "impact", "evidence")).lower()
        for name, pattern in CLASSES:
            if re.search(pattern, text):
                out.add(name)
                break
        else:
            out.add(f"unclassified:{where}:{line}")
    return out


def main() -> int:
    runs = {Path(p).stem: classes_of(Path(p)) for p in sys.argv[1:]}
    for name, s in sorted(runs.items()):
        print(f"{name:14} {len(s):>2}  {sorted(s)}")
    print()
    for arm in ("treatment", "control"):
        sets = [s for n, s in runs.items() if n.startswith(arm)]
        if len(sets) < 2:
            continue
        js = [len(a & b) / len(a | b) for a, b in itertools.combinations(sets, 2)]
        print(f"{arm:10} pairwise Jaccard {[round(j, 2) for j in js]}  mean {sum(js)/len(js):.2f}")
        print(f"{'':10} present in every run: {sorted(set.intersection(*sets))}")
        print(f"{'':10} union across runs:    {len(set.union(*sets))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
