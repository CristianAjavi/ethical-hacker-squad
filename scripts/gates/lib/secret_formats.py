#!/usr/bin/env python3
"""The secret formats every check refuses, read from one data file.

`scripts/gates/data/secret-formats.txt` is the single list. This module is how
Python reads it: `findings_artifact.py` (what `findings.json` may carry) and
`scripts/ehs sarif` (the export that gets uploaded) both import it, and
`gate-report-contract.sh` reads the same file from awk and grep. Until
2026-10-15 there were four lists, and the two narrowest guarded the two files
that leave the machine: neither recognised a Stripe, Supabase, OpenAI project
or Google key, nor a signed JWT.

Usage:  secret_formats.py [file ...]   prints the format ids found in each file
                                       (never the matched text); exit 1 if any.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import List, Tuple

DATA = Path(__file__).resolve().parent.parent / "data" / "secret-formats.txt"


def load_formats(path: Path = DATA) -> List[Tuple[str, "re.Pattern[str]"]]:
    formats = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        fid, _prefix, regex, _note = line.split("\t", 3)
        formats.append((fid, re.compile(regex)))
    if not formats:
        raise ValueError(f"{path} declares no secret format")
    return formats


FORMATS = load_formats()


def find_unredacted_secrets(text: str) -> List[str]:
    """The ids of every format present in `text`. Never the matched value."""
    return [fid for fid, rx in FORMATS if rx.search(text)]


def main(argv: List[str]) -> int:
    found = 0
    for name in argv:
        ids = find_unredacted_secrets(Path(name).read_text(encoding="utf-8", errors="replace"))
        if ids:
            found += 1
            print(f"{name}: {', '.join(ids)}")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
