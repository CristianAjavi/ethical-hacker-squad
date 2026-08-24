#!/usr/bin/env python3
"""Measurement core of gate-protected-paths.sh (G7).

An automation that can edit its own limits has none. The paths in
scripts/gates/data/protected-paths.json define what this system may do and what
it may read; a branch whose name marks it as automated may not touch them, and a
human branch may, because a maintainer reviews it.

Three measurements:

  1. drift      the fenced list under `## G7 — Protected paths` in
                docs/gate-requirements.md matches the data file exactly. The rule
                and the sentence that documents it cannot diverge.
  2. verdict    an automated branch touching a protected path fails, naming the
                path and the pattern that caught it.
  3. visibility a human branch touching one is reported, never silently allowed,
                so the reviewer knows what to look at.

Usage: protected_paths.py <repo-root> <branch> <changed-files-file>
A branch of `-` or an unreadable file list is could-not-measure, never a pass.

EXIT: 0 measured fine · 1 measured, findings listed · 2 could not measure
"""

from __future__ import annotations

import fnmatch
import json
import re
import sys
from pathlib import Path

DATA = "scripts/gates/data/protected-paths.json"
DOC = "docs/gate-requirements.md"
DOC_BLOCK = re.compile(r"##\s*G7\s*—\s*Protected paths.*?```\n(.*?)```", re.S)


class Unmeasured(Exception):
    pass


def matches(path: str, pattern: str) -> bool:
    if pattern.endswith("/**"):
        return path == pattern[:-3] or path.startswith(pattern[:-2])
    return fnmatch.fnmatch(path, pattern)


def main() -> int:
    if len(sys.argv) < 4:
        raise Unmeasured("usage: protected_paths.py <repo-root> <branch> <changed-files-file>")
    root = Path(sys.argv[1]).resolve()
    branch = sys.argv[2]
    listing = Path(sys.argv[3])

    try:
        data = json.loads((root / DATA).read_text(encoding="utf-8"))
        declared = list(data["paths"])
        prefixes = list(data["automation_branch_prefixes"])
    except (OSError, ValueError, KeyError) as exc:
        raise Unmeasured(f"{DATA} is unusable: {exc}") from exc

    findings: list[str] = []
    checks = 0

    # ---- 1. the doc and the data file say the same thing ---------------
    try:
        doc = (root / DOC).read_text(encoding="utf-8")
    except OSError as exc:
        raise Unmeasured(f"cannot read {DOC}: {exc}") from exc
    m = DOC_BLOCK.search(doc)
    checks += 1
    if not m:
        findings.append(
            f"{DOC}: there is no fenced path list under `## G7 — Protected paths`; the rule is "
            "enforced from a data file nobody can read next to its explanation")
    else:
        documented = [ln.strip() for ln in m.group(1).splitlines() if ln.strip()]
        if documented != declared:
            findings.append(
                f"{DOC}: the documented G7 list and {DATA} differ - documented only "
                f"{sorted(set(documented) - set(declared))}, enforced only "
                f"{sorted(set(declared) - set(documented))}"
                + ("" if set(documented) != set(declared) else " (same paths, different order)"))

    if branch == "-" or not branch:
        raise Unmeasured("the branch under test is unknown; a protected-path check that cannot "
                         "tell whose branch it is has not run")
    try:
        changed = [ln.strip() for ln in listing.read_text(encoding="utf-8").splitlines() if ln.strip()]
    except OSError as exc:
        raise Unmeasured(f"cannot read the changed-file list ({listing}): {exc}") from exc

    automated = any(branch.startswith(p) for p in prefixes)
    touched = [(f, p) for f in changed for p in declared if matches(f, p)]

    print(f"measured: branch {branch!r} ({'automated' if automated else 'human'}), "
          f"{len(changed)} changed file(s) against {len(declared)} protected pattern(s), "
          f"{checks + len(changed)} checks")

    # ---- 2 and 3 -------------------------------------------------------
    if not touched:
        print("no protected path in this diff")
    elif automated:
        for f, p in touched:
            findings.append(
                f"branch {branch!r} is automated and its diff touches {f} (protected by `{p}`); "
                "an automation that can edit its own limits has none")
    else:
        print(f"human branch: {len(touched)} protected path(s) in this diff, allowed and listed "
              "so the reviewer knows where to look:")
        for f, p in touched:
            print(f"  - {f} (matches `{p}`)")

    print("NOT MEASURED: whether the change to a protected path is a good one. This gate asks who "
          "is changing it, not whether they should.")

    for f in findings:
        print(f"FINDING {f}")
    return 1 if findings else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Unmeasured as exc:
        print(f"UNMEASURED {exc}")
        sys.exit(2)
