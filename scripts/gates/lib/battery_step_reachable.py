#!/usr/bin/env python3
"""Can a workflow's battery step be skipped by an earlier failure?

WHY THIS EXISTS
    `ci.yml` discovers every `*.selftest.sh` and runs them - in a step placed
    after the one that runs the gates, in the same job, with no condition.
    GitHub Actions skips the remaining steps of a job when one fails, so from
    2026-08-25, when `gate-tree-delta` went red, twenty consecutive CI runs
    executed ZERO batteries. One of them was failing that whole time and its
    red reached nobody.

    A battery that only runs on the days everything else is green is not a
    control. It is the shape this repository exists to catch: a known red that
    reads as "I know why that fails" while silently disabling everything after it.

WHAT IT CHECKS
    Any step that invokes a battery - its `run` mentions `selftest` or
    `battery` - must either be the first step that can fail in its job, or
    carry an `if:` that survives a previous failure (`always()`, `!cancelled()`,
    `failure()`, `success() || failure()`).

WHAT IT DOES NOT CHECK
    Whether the batteries themselves are correct, or whether the job's final
    conclusion is right. Only that a red elsewhere cannot make them vanish.

Output:
    SKIPPABLE|<workflow>|<job>|<step>
    STAT|<battery steps found>|<workflows read>
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

SURVIVES = re.compile(r"always\s*\(\s*\)|!\s*cancelled\s*\(\s*\)|failure\s*\(\s*\)")
INVOKES = re.compile(r"selftest|battery|batteries", re.I)


def main(argv=None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    root = Path(argv[0] if argv else ".")
    wf = root / ".github" / "workflows"
    if not wf.is_dir():
        print(f"ERR|no .github/workflows under {root}")
        return 2
    try:
        import yaml
    except ImportError:
        print("ERR|pyyaml is not available, so the workflows cannot be parsed")
        return 2
    found = 0
    files = 0
    bad = 0
    for path in sorted(wf.glob("*.y*ml")):
        try:
            doc = yaml.safe_load(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, yaml.YAMLError) as exc:
            print(f"ERR|{path.name} is unusable: {exc}")
            return 2
        files += 1
        for job_name, job in (doc or {}).get("jobs", {}).items():
            steps = job.get("steps") or []
            # A step is only at risk if something that can fail MEANINGFULLY runs
            # before it. A `uses:` step is setup - checkout, setup-python: if it
            # fails there is no repository to test and skipping is correct. A
            # `run:` step is this repository's own logic, and its failure is
            # exactly the case where the batteries are most worth having. So the
            # rule is: an earlier `run:` step in the same job.
            #
            # LIMIT: a `uses:` step can fail for its own reasons too (a linting
            # action, a cache miss treated as fatal). Those are not flagged, and
            # this is a deliberate floor rather than an oversight.
            for i, step in enumerate(steps):
                run = step.get("run") or ""
                if not INVOKES.search(run):
                    continue
                found += 1
                if not any(s.get("run") for s in steps[:i]):
                    continue
                cond = str(step.get("if") or "")
                if SURVIVES.search(cond):
                    continue
                label = step.get("name") or f"step {i}"
                print(f"SKIPPABLE|{path.name}|{job_name}|{label}")
                bad = 1
    print(f"STAT|{found}|{files}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
