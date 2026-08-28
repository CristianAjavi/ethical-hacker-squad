#!/usr/bin/env python3
"""Are the reports a round SHIPPED the ones it SCORED?

WHY THIS EXISTS
    Measured 2026-08-29: a round was published twice with wrong numbers because
    a report was copied out of a live run directory and scored while the agent
    producing it was still writing. The file passed through 68 findings, then
    41, then 69; two intermediates were scored and published as verdicts.

    Part of that is procedural and no gate can see it - whether the author waited
    for the agent's completion notice. But half of it is mechanical: whatever was
    scored must be what ships. If SCORE.txt was computed from bytes that are not
    in runs/, the round is unreproducible and its numbers cannot be rechecked.

WHAT IT CHECKS
    Every round directory that has a SCORE.txt and a runs/ directory must carry a
    REPORTS.sha256 listing one line per scored report: "<sha256>  <filename>".
    Each listed file must exist in runs/ and hash to the recorded value.

WHAT IT DOES NOT CHECK
    Whether the bytes were final when they were scored. Only the author's
    discipline and the agent's completion notice establish that; this check makes
    the artifact reproducible, not the timing correct. Saying so is part of it.

Output, one finding per line:
    MISSING|<round>            has SCORE.txt and runs/ but no REPORTS.sha256
    ABSENT|<round>|<file>      listed and not present in runs/
    MISMATCH|<round>|<file>    present and hashes differently
    STAT|<rounds>|<files>
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path


def main(argv=None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    root = Path(argv[0] if argv else ".")
    runs = root / "bench" / "runs"
    if not runs.is_dir():
        print(f"ERR|no bench/runs under {root}")
        return 2
    exempt_file = runs / "HASHES-EXEMPT.txt"
    exempt = set()
    if exempt_file.is_file():
        for line in exempt_file.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                exempt.add(line)
    bad = 0
    n_rounds = n_files = n_exempt = n_exempt_files = 0
    for d in sorted(p for p in runs.iterdir() if p.is_dir()):
        score = d / "SCORE.txt"
        rdir = d / "runs"
        if not rdir.is_dir() or not any(rdir.iterdir()):
            continue
        shipped = len(list(rdir.iterdir()))
        if not score.is_file():
            # A round that ships reports but has no SCORE.txt is not outside the
            # rule, only outside the check that existed when it ran. Silence here
            # would read as coverage, so it has to be listed by name to be skipped.
            if d.name in exempt:
                n_exempt += 1
                n_exempt_files += shipped
                if (d / "REPORTS.sha256").is_file():
                    print(f"STALE|{d.name}")
                    bad = 1
                continue
            print(f"UNLISTED|{d.name}")
            bad = 1
            continue
        if d.name in exempt:
            print(f"STALE|{d.name}")
            bad = 1
        n_rounds += 1
        manifest = d / "REPORTS.sha256"
        if not manifest.is_file():
            print(f"MISSING|{d.name}")
            bad = 1
            continue
        for line in manifest.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split(None, 1)
            if len(parts) != 2:
                print(f"MISMATCH|{d.name}|{line}")
                bad = 1
                continue
            want, name = parts[0], parts[1].strip()
            f = rdir / name
            n_files += 1
            if not f.is_file():
                print(f"ABSENT|{d.name}|{name}")
                bad = 1
                continue
            got = hashlib.sha256(f.read_bytes()).hexdigest()
            if got != want:
                print(f"MISMATCH|{d.name}|{name}")
                bad = 1
    print(f"STAT|{n_rounds}|{n_files}|{n_exempt}|{n_exempt_files}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
