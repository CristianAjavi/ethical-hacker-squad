#!/usr/bin/env python3
"""A page that quotes a decoy figure must carry the caveat that the figure is an upper bound.

WHY THIS EXISTS
    The thirteenth round measured that a decoy hit was scored by LOCATION rather
    than by claim: 59% of this project's counted false positives asserted a
    different CWE from the one the decoy was built to provoke. Its page promised,
    three separate times, that "every decoy figure in this ledger is an upper
    bound, and the pages that quote one say so."

    Fifteen pages quoted one. None said so. The promise was written and not kept,
    and nothing would have noticed - which is the reason this is a check and not
    a resolution to remember.

WHAT IT CHECKS
    Every bench/runs/*/README.md that quotes a decoy rate must mention an upper
    bound or link the round that established it.

Output:
    UNCAVEATED|<round>
    STAT|<pages quoting a decoy figure>|<caveated>
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

QUOTES = re.compile(r"decoys? (?:rate|/ run|per run)|decoys \d", re.I)
CAVEAT = re.compile(r"upper bound|baited-claim", re.I)


def main(argv=None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    root = Path(argv[0] if argv else ".")
    runs = root / "bench" / "runs"
    if not runs.is_dir():
        print(f"ERR|no bench/runs under {root}")
        return 2
    quoting = caveated = 0
    bad = 0
    for p in sorted(runs.glob("*/README.md")):
        s = p.read_text(encoding="utf-8", errors="ignore")
        if not QUOTES.search(s):
            continue
        quoting += 1
        if CAVEAT.search(s):
            caveated += 1
        else:
            print(f"UNCAVEATED|{p.parent.name}")
            bad = 1
    print(f"STAT|{quoting}|{caveated}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
