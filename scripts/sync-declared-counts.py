#!/usr/bin/env python3
"""Rewrite every count the prose states about the corpus, from measurement.

`gate-corpus-contract.sh` says which numbers drifted; this is the verb that
fixes them, so nobody edits four files by hand and misses the fifth. It writes
only numbers that it measured: corpus lines, procedure count, file count,
per-file rows of the loading map and the `**Cost:** ~N lines` header of each
pack. It never touches identifier ranges — those change when a procedure is
added or removed, and that is an editorial decision, not arithmetic.

    python3 scripts/sync-declared-counts.py [--check]

`--check` prints what it would change and exits 1 if anything would change.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORDS = {12: "twelve", 13: "thirteen", 14: "fourteen", 15: "fifteen",
         16: "sixteen", 17: "seventeen", 18: "eighteen", 19: "nineteen", 20: "twenty"}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    packs = json.loads((ROOT / "scripts/meter/packs.json").read_text())
    kdir = ROOT / packs["knowledge_dir"]
    non_proc = set(packs.get("non_procedure_files", []))
    heading = re.compile(packs["procedure_heading"])

    files = sorted(p.name for p in kdir.glob("*.md") if p.name not in non_proc)
    lines = {f: len((kdir / f).read_text().splitlines()) for f in files}
    total_lines = sum(lines.values())
    procs = sum(
        len([1 for line in (kdir / f).read_text().splitlines() if heading.match(line)])
        for f in files
    )
    word = WORDS.get(len(files), str(len(files)))
    changes: list[str] = []

    def rewrite(rel: str, pattern: str, repl: str) -> None:
        p = ROOT / rel
        s = p.read_text()
        s2 = re.sub(pattern, repl, s)
        if s2 != s:
            changes.append(rel)
            if not args.check:
                p.write_text(s2)

    rewrite("README.md", r"[\d,]+ lines of corpus", f"{total_lines:,} lines of corpus")
    rewrite("README.md", r"with \d+ numbered procedures", f"with {procs} numbered procedures")
    rewrite("skills/ethical-hacker-squad/SKILL.md",
            r"The corpus is [\d,]+ lines across \w+ files",
            f"The corpus is {total_lines:,} lines across {word} files")
    rewrite("skills/ethical-hacker-squad/references/knowledge/README.md",
            r"spread over \w+ files, [\d,]+ lines in total, \d+ numbered procedures",
            f"spread over {word} files, {total_lines:,} lines in total, {procs} numbered procedures")
    rewrite("CHANGELOG.md",
            r"\*\*Knowledge corpus\*\* \([\d,]+ lines, \d+ numbered procedures across (\d+) role packs stored in \d+ files\)",
            lambda m: f"**Knowledge corpus** ({total_lines:,} lines, {procs} numbered procedures "
                      f"across {m.group(1)} role packs stored in {len(files)} files)")

    for name, n in lines.items():
        rewrite(f"{packs['knowledge_dir']}/{name}", r"\*\*Cost:\*\* ~[\d,]+ lines", f"**Cost:** ~{n} lines")

    def fix_map(m: re.Match[str]) -> str:
        name = m.group("file")
        if name not in lines:
            return m.group(0)
        return f"| `{name}` | {m.group('role')} | ~{lines[name]} | {m.group('ids')} | {m.group('when')} |"

    rewrite("skills/ethical-hacker-squad/references/knowledge/README.md",
            r"(?m)^\| `(?P<file>[a-z0-9-]+\.md)` \| (?P<role>[^|]+) \| ~\d+ \| (?P<ids>[^|]+) \| (?P<when>[^|]+) \|$",
            fix_map)

    uniq = sorted(set(changes))
    print(f"measured {procs} procedures, {total_lines} lines, {len(files)} files")
    if not uniq:
        print("every declared count already matches")
        return 0
    verb = "would update" if args.check else "updated"
    print(f"{verb}: {', '.join(uniq)}")
    return 1 if args.check else 0


if __name__ == "__main__":
    sys.exit(main())
