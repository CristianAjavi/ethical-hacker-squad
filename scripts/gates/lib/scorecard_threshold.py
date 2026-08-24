#!/usr/bin/env python3
"""Measurement core of gate-scorecard-threshold.sh (G9).

Scorecard has been running here as measurement since the beginning and nothing
gated on it. The reason not to gate on the aggregate is written in the workflow
and it is a good reason: the aggregate is a risk-weighted average that EXCLUDES
checks returning `?`, so it can fall for doing things right. What was missing is
the other half - the per-check subset that does reflect real risk here.

Four measurements:

  1. drift       the table under `## G9` in docs/gate-requirements.md still says
                 exactly what scripts/gates/data/scorecard-thresholds.json
                 enforces, check for check and number for number.
  2. thresholds  every declared check is present in the results and at or above
                 its minimum.
  3. inconclusive a check Scorecard could not run comes back as -1. That is
                 COULD NOT MEASURE, never a pass: the whole exit-code doctrine
                 of this repository applied to somebody else's tool.
  4. regression  the aggregate may not fall more than max_drop_from_baseline
                 below the recorded baseline. No baseline recorded is printed as
                 "nothing to compare", not silently treated as fine.

Usage: scorecard_threshold.py <repo-root> <results.json>

EXIT: 0 measured fine · 1 measured, findings listed · 2 could not measure
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

DATA = "scripts/gates/data/scorecard-thresholds.json"
DOC = "docs/gate-requirements.md"
DOC_TABLE = re.compile(r"##\s*G9\s*—\s*Repository quality metric(.*?)(?=\n##\s)", re.S)
ROW = re.compile(r"^\|\s*`([A-Za-z-]+)`\s*\|\s*(?:must be\s*)?`?>?=?\s*(\d+)`?\s*\|", re.M)


class Unmeasured(Exception):
    pass


def main() -> int:
    if len(sys.argv) < 3:
        raise Unmeasured("usage: scorecard_threshold.py <repo-root> <results.json>")
    root = Path(sys.argv[1]).resolve()
    results_path = Path(sys.argv[2])

    try:
        data = json.loads((root / DATA).read_text(encoding="utf-8"))
        declared = {c["check"]: int(c["min"]) for c in data["checks"]}
        agg_cfg = data["aggregate"]
    except (OSError, ValueError, KeyError) as exc:
        raise Unmeasured(f"{DATA} is unusable: {exc}") from exc

    findings: list[str] = []
    checks = 0

    # ---- 1. the doc table and the data file say the same thing ---------
    try:
        doc = (root / DOC).read_text(encoding="utf-8")
    except OSError as exc:
        raise Unmeasured(f"cannot read {DOC}: {exc}") from exc
    m = DOC_TABLE.search(doc)
    checks += 1
    if not m:
        findings.append(f"{DOC}: there is no `## G9` section; the thresholds are enforced from a "
                        "data file with nothing next to it explaining them")
    else:
        documented = {name: int(score) for name, score in ROW.findall(m.group(1))}
        if documented != declared:
            only_doc = {k: v for k, v in documented.items() if declared.get(k) != v}
            only_data = {k: v for k, v in declared.items() if documented.get(k) != v}
            findings.append(
                f"{DOC}: the documented G9 thresholds and {DATA} differ - documented {only_doc}, "
                f"enforced {only_data}")

    # ---- the results ---------------------------------------------------
    try:
        results = json.loads(results_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise Unmeasured(f"cannot read the Scorecard results ({results_path}): {exc}. A gate with "
                         "no results has not run; it has not passed.") from exc

    scored = {c.get("name"): c.get("score") for c in results.get("checks", [])
              if isinstance(c, dict)}
    if not scored:
        raise Unmeasured(f"{results_path} carries no checks; there is nothing to gate on")

    print(f"measured: {len(scored)} check(s) in the results, {len(declared)} gated, "
          f"aggregate {results.get('score')}")

    inconclusive = []
    for name, minimum in sorted(declared.items()):
        checks += 1
        score = scored.get(name)
        if score is None:
            inconclusive.append(f"{name} is not in the results at all")
            continue
        if score == -1:
            inconclusive.append(f"{name} came back inconclusive (-1): Scorecard could not run it")
            continue
        if score < minimum:
            findings.append(
                f"Scorecard {name} = {score}, below the declared minimum {minimum}: "
                + (next((c.get("why") for c in data["checks"] if c["check"] == name), "") or
                   "declared in scripts/gates/data/scorecard-thresholds.json"))
        else:
            print(f"  {name}: {score} (>= {minimum})")

    # ---- 4. the aggregate, by movement rather than by level ------------
    baseline_rel = agg_cfg.get("baseline_file")
    aggregate = results.get("score")
    if baseline_rel:
        try:
            base = json.loads((root / baseline_rel).read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            raise Unmeasured(f"cannot read {baseline_rel}: {exc}") from exc
        recorded = base.get("aggregate")
        checks += 1
        if recorded is None:
            print(f"aggregate: {aggregate} - no baseline recorded in {baseline_rel}, so there is "
                  "nothing to compare. This is printed rather than passed silently.")
        elif isinstance(aggregate, (int, float)):
            drop = float(recorded) - float(aggregate)
            if drop > float(agg_cfg.get("max_drop_from_baseline", 0.5)):
                findings.append(
                    f"the aggregate fell from {recorded} to {aggregate} ({drop:.1f}), more than the "
                    f"{agg_cfg['max_drop_from_baseline']} the contract allows")
            else:
                print(f"aggregate: {aggregate} against a baseline of {recorded} (drop {drop:.1f})")
        else:
            inconclusive.append("the results carry no aggregate score")

    print("NOT MEASURED: every Scorecard check outside the gated subset. They are measured by the "
          "workflow and published, and they are deliberately not gated - the aggregate excludes "
          "checks returning '?', so gating on it would fall for doing things right.")

    for i in inconclusive:
        print(f"UNMEASURED {i}")
    for f in findings:
        print(f"FINDING {f}")
    if inconclusive:
        return 2
    return 1 if findings else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Unmeasured as exc:
        print(f"UNMEASURED {exc}")
        sys.exit(2)
