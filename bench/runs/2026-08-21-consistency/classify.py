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

# ORDER IS LOAD-BEARING and the first version got it wrong. `uncapped-recursion`
# matched on the bare method names `readtable|readarray`, which appear in the
# text of the DECLARED-LENGTH finding too, so a distinct defect was silently
# folded into the recursion class and three runs that differ were reported as
# identical. The patterns below name the MECHANISM, never just the method that
# happens to be nearby, and the most specific classes are tested first.
CLASSES = [
    ("duplicate-keys",                r"duplicate (field |key)|first[- ]wins|first occurrence wins|repeated field"),
    ("unchecked-exception",           r"unsupportedoperation|unchecked exception|unchecked runtime"),
    ("timestamp-overflow",            r"timestamp|\*\s*1000"),
    ("codegen-unpinned",              r"codegen|generate-sources|generator script|groovy|shipped api source"),
    ("dependency-eol",                r"slf4j|logback|jetty|end-of-life|end of life|\beol\b"),
    ("declared-length-vs-remaining",  r"never compared with the bytes|bytes that remain|bytes remaining|"
                                      r"available\(\)|silently truncat|swallow its sibling"),
    ("alloc-from-wire-length",        r"sizes (a|the) byte array|new byte\[|readbytes|contentlength"),
    ("uncapped-recursion",            r"depth counter|no depth|recurs|stackoverflow"),
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
