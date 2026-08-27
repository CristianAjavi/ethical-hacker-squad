#!/usr/bin/env python3
"""Does the manifest declare every role the repository holds?

WHY THIS EXISTS
    Measured 2026-08-27: agents/ held nine roles and .claude-plugin/plugin.json
    listed eight, so every install was missing ehs-local-app entirely - the
    desktop and local-application specialist, absent with no error anywhere.

    The reachability gate could not see it. That one walks citations from the
    agents DIRECTORY, which is the tree as its author sees it, not the tree a
    user receives. A file can be present, cited, and still not ship.

Output, one finding per line:
    UNDECLARED|<file>    present in agents/ and absent from the manifest
    MISSING|<file>       declared by the manifest and absent from the tree
    STAT|<declared>|<present>
"""
from __future__ import annotations

import json
import sys
from pathlib import Path


def main(argv=None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    if not argv:
        print("ERR|usage: manifest_agents.py <repo-root>")
        return 2
    root = Path(argv[0])
    manifest = root / ".claude-plugin" / "plugin.json"
    if not manifest.is_file():
        print(f"ERR|no manifest at {manifest}")
        return 2
    try:
        m = json.loads(manifest.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"ERR|the manifest does not parse: {exc}")
        return 2
    declared = {Path(p).name for p in (m.get("agents") or [])}
    adir = root / "agents"
    if not adir.is_dir():
        print("ERR|no agents/ directory to compare the manifest against")
        return 2
    present = {p.name for p in sorted(adir.glob("*.md"))}
    bad = 0
    for n in sorted(present - declared):
        print(f"UNDECLARED|{n}")
        bad = 1
    for n in sorted(declared - present):
        print(f"MISSING|{n}")
        bad = 1
    print(f"STAT|{len(declared)}|{len(present)}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
