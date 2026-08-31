#!/usr/bin/env python3
"""Does a round's page state the verdict its own scorer produced?

WHY THIS EXISTS
    On 2026-08-29 the same round was published with three different verdicts in
    three commits - not supported, then refuted, then not supported again -
    because a report was scored while its agent was still writing. Each time,
    SCORE.txt and README.md were regenerated together, so they agreed; but
    nothing would have caught a page whose headline drifted from the scorer
    output it ships beside, and a reader has no way to tell which is authoritative.

WHAT IT CHECKS
    For every round with a SCORE.txt containing a VERDICT line, the README must
    contain that verdict word. Where SCORE.txt holds several VERDICT lines - a
    round that scores two definitions - the page must name every distinct one,
    because quoting only the flattering half of a two-definition round is the
    failure this check is for.

WHAT IT DOES NOT CHECK
    Whether the scorer's verdict is correct, or whether the numbers were final
    when it ran. Only that the page and the artifact beside it say the same thing.

Output:
    DRIFT|<round>|<in score>|missing from page
    STAT|<rounds checked>
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

VERDICT = re.compile(r"VERDICT:\s*([A-Z][A-Z ]+?)(?:\s*[—\-(]|$)", re.M)


def main(argv=None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    root = Path(argv[0] if argv else ".")
    runs = root / "bench" / "runs"
    if not runs.is_dir():
        print(f"ERR|no bench/runs under {root}")
        return 2
    checked = 0
    bad = 0
    for d in sorted(p for p in runs.iterdir() if p.is_dir()):
        score, page = d / "SCORE.txt", d / "README.md"
        if not (score.is_file() and page.is_file()):
            continue
        verdicts = {v.strip() for v in VERDICT.findall(score.read_text(errors="ignore"))}
        if not verdicts:
            continue
        checked += 1
        text = page.read_text(errors="ignore").lower()
        for v in sorted(verdicts):
            if v.lower() not in text:
                print(f"DRIFT|{d.name}|{v}")
                bad = 1
    print(f"STAT|{checked}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
