#!/usr/bin/env python3
"""Refuse to score an external case whose defect is not in the checkout.

WHY THIS EXISTS, and it is not hypothetical. On 2026-08-22 a whole-repository
round was published and then retracted: the targets had been cloned with
`git clone --depth 1` of the default branch, which is AFTER each fix commit.
Both arms audited code the defects had already been removed from, and 0/3 was
reported as a detection result. The case file had recorded a `parent` commit -
the pre-fix one - for exactly this reason, and it was ignored.

It was caught only because one arm happened to name the control that made the
defect impossible. A silent non-finding is indistinguishable from a miss, so
the bench cannot rely on that happening again.

WHAT IT CHECKS, per case:
  - the checkout is AT the recorded parent commit, and
  - for every file the fix touched, that file exists in the checkout, and
  - if the case declares `fix_markers` - strings the FIX introduces - none of
    them appears in the checkout. Their presence means the tree is patched.

EXIT CODES (repo contract):
  0  measured, every case's checkout is at its pre-fix commit
  1  measured, at least one checkout is wrong - scoring it would be void
  2  COULD NOT MEASURE (no case file, no checkout, git missing). Never a pass.
"""
import json
import pathlib
import subprocess
import sys


def sh(args, cwd):
    r = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
    return r.returncode, r.stdout.strip()


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: verify-target-checkout.py <cases.json> <checkouts-dir>")
        return 2
    cases_path, root = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    if not cases_path.is_file():
        print(f"COULD NOT MEASURE: no case file at {cases_path}")
        return 2
    if not root.is_dir():
        print(f"COULD NOT MEASURE: no checkout directory at {root}")
        return 2

    cases = json.loads(cases_path.read_text()).get("cases", [])
    if not cases:
        print("COULD NOT MEASURE: the case file declares no cases")
        return 2

    problems, checked = [], 0
    for c in cases:
        adv = c.get("advisory", "?")
        parent = (c.get("parent") or "").strip()
        name = c["repository"].rstrip("/").split("/")[-1]
        # A case may be checked out under its repo name or under an alias
        # recorded by the round; both are tried before giving up.
        candidates = [root / name, root / c.get("checkout_dir", name)]
        tree = next((p for p in candidates if p.is_dir()), None)
        if tree is None:
            print(f"COULD NOT MEASURE: {adv}: no checkout for {name} under {root}")
            return 2
        if not parent:
            problems.append(f"{adv}: the case records no `parent` commit, so the "
                            "checkout cannot be verified as pre-fix")
            continue

        checked += 1
        rc, head = sh(["git", "rev-parse", "HEAD"], tree)
        if rc != 0:
            print(f"COULD NOT MEASURE: {adv}: {tree} is not a git checkout")
            return 2
        if not head.startswith(parent[:12]) and not parent.startswith(head[:12]):
            problems.append(f"{adv}: {name} is checked out at {head[:12]}, not at the "
                            f"pre-fix parent {parent[:12]} - any score is void")

        for f in c.get("fix_files") or []:
            if not (tree / f).is_file():
                problems.append(f"{adv}: {f} is named by the fix and is absent from the "
                                "checkout, so the defect cannot be there either")

        for marker in c.get("fix_markers") or []:
            hits = [p for f in (c.get("fix_files") or [])
                    if (p := tree / f).is_file() and marker in p.read_text(errors="replace")]
            if hits:
                problems.append(f"{adv}: the checkout contains {marker!r}, which the FIX "
                                "introduces - this tree is patched and scoring it is void")

    print(f"measured: {len(cases)} case(s), {checked} with a parent commit to verify")
    for p in problems:
        print(f"FINDING {p}")
    return 1 if problems else 0


sys.exit(main())
