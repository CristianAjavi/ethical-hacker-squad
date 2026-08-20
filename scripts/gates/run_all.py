#!/usr/bin/env python3
"""Run every gate and aggregate the result.

Aggregation follows the exit-code contract: `2` wins over `1`, and `1` wins over
`0`. A run that could not measure never aggregates to a pass, because a gate
that failed to run looks identical to a clean result unless something insists on
the difference.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
GATES = [
    ("G1", "g1_manifest.py"),
    ("G2", "g2_links.py"),
    ("G3", "g3_budget.py"),
    ("G4", "g4_citations.py"),
]


def main() -> int:
    ap = argparse.ArgumentParser(description="run every gate")
    ap.add_argument("--root", default=str(HERE.parents[1]))
    ap.add_argument("--only", nargs="*", help="gate ids to run, e.g. --only G1 G3")
    args = ap.parse_args()

    worst = 0
    summary: list[tuple[str, int]] = []
    for gate_id, script in GATES:
        if args.only and gate_id not in args.only:
            continue
        proc = subprocess.run(
            [sys.executable, str(HERE / script), "--root", args.root],
            check=False,
        )
        code = proc.returncode
        summary.append((gate_id, code))
        worst = 2 if 2 in (worst, code) else max(worst, code)

    print()
    label = {0: "pass", 1: "fail", 2: "UNMEASURED"}
    for gate_id, code in summary:
        print(f"  {gate_id}: {label.get(code, f'exit {code}')}")
    print(f"result: {label.get(worst, worst)}")
    return worst


if __name__ == "__main__":
    sys.exit(main())
