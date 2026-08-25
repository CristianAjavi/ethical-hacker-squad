#!/usr/bin/env python3
"""Map this round's report shape into the shape scripts/bench/score.py expects.

WHY IT EXISTS
    The round's prompt asked each arm for {title, location, class, severity,
    evidence, impact, recommendation}. score.py additionally requires `status`
    in {confirmed, probable, hardening} and treats anything else as NOT
    REPORTED. Scored raw, an arm with 53 well-formed findings reads as recall
    0% - a harness defect that looks exactly like a result.

    Every finding an arm reported is one it says it established, so `status`
    defaults to `confirmed` unless the arm set one. Nothing else is changed:
    no finding is added, dropped, relocated or reworded.

FAIRNESS
    The same adapter runs over every arm, with no per-arm branch. That is the
    whole point of it being one file with no arm argument.

Exit codes: 0 = adapted | 2 = could not read the input.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

VALID = {"confirmed", "probable", "hardening"}


def adapt(doc: dict) -> dict:
    out = dict(doc)
    findings = []
    for f in doc.get("findings") or []:
        if not isinstance(f, dict):
            continue
        g = dict(f)
        if g.get("status") not in VALID:
            g["status"] = "confirmed"
        loc = g.get("location")
        g["location"] = dict(loc) if isinstance(loc, dict) else {}
        findings.append(g)
    out["findings"] = findings
    return out


def main(argv) -> int:
    if len(argv) < 2:
        print("usage: adapt.py <report.json> [<report.json> ...]")
        return 2
    for p in argv[1:]:
        src = Path(p)
        try:
            doc = json.loads(src.read_text())
        except (OSError, json.JSONDecodeError) as e:
            print(f"UNMEASURABLE {src.name}: {e.__class__.__name__}")
            return 2
        dst = src.with_suffix(".adapted.json")
        dst.write_text(json.dumps(adapt(doc), indent=2))
        n = len(doc.get("findings") or [])
        print(f"  {src.name}: {n} finding(s) -> {dst.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
