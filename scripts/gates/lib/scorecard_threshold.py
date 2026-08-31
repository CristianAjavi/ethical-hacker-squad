#!/usr/bin/env python3
"""Measurement core of gate-scorecard-threshold.sh (G9).

Scorecard has been running here as measurement since the beginning and nothing
gated on it. The reason not to gate on the aggregate is written in the workflow
and it is a good reason: the aggregate is a risk-weighted average that EXCLUDES
checks returning `?`, so it can fall for doing things right. What was missing is
the other half - the per-check subset that does reflect real risk here.

Six measurements:

  1. drift       BOTH tables under `## G9` in docs/gate-requirements.md still say
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
  5. relocation  a check may sit in `checks` or in `not_gated_here`. In both is a
                 contradiction and in neither is a check that quietly stopped
                 existing, so either is a finding. This is what stops the list
                 above from being softened by deletion: dropping a check from
                 `checks` without writing it into `not_gated_here` FAILS.
  6. the escape  every file a `not_gated_here` entry names as the thing that
                 really checks the property must exist. "Something else measures
                 it" pointing at nothing is how a control is retired in writing
                 while reading as still enforced.

WHY 5 AND 6 EXIST. `Branch-Protection` was gated at a minimum of 8 that CI could
never read - the workflow token cannot reach the protection block - so G9 exited
2 on every push from the day it started gating, and with a maintainer token the
real number was 3, so the threshold had never been reachable either. Moving it
out of the gated subset was the honest answer and is also the dangerous one: the
same edit, made silently, is how a repository stops checking something and keeps
the green. So the move is only expressible in writing, with a live score printed
on every run and a named file that has to exist.

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
# Two delimited regions rather than one loose search. The tables sit in the same
# section and have the same row shape, so a single regex over the section would
# read the not-gated table as thresholds - and a check moved between them would
# come out as no change at all.
GATED_REGION = re.compile(r"<!--\s*g9:gated\s*-->(.*?)<!--\s*/g9:gated\s*-->", re.S)
NOT_GATED_REGION = re.compile(r"<!--\s*g9:not-gated\s*-->(.*?)<!--\s*/g9:not-gated\s*-->", re.S)
ROW = re.compile(r"^\|\s*`([A-Za-z-]+)`\s*\|\s*(?:must be\s*)?`?>?=?\s*(\d+)`?\s*\|", re.M)
NAME_ROW = re.compile(r"^\|\s*`([A-Za-z-]+)`\s*\|", re.M)


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
        # A missing key here would be an unusable file, not an empty list: the
        # whole point of measurement 5 is that "not gated" has to be written
        # down, and a file that cannot say so cannot be gated against.
        relocated = {c["check"]: c for c in data["not_gated_here"]}
        agg_cfg = data["aggregate"]
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise Unmeasured(f"{DATA} is unusable: {exc}") from exc

    findings: list[str] = []
    checks = 0

    # ---- 1. the doc table and the data file say the same thing ---------
    try:
        doc = (root / DOC).read_text(encoding="utf-8")
    except OSError as exc:
        raise Unmeasured(f"cannot read {DOC}: {exc}") from exc
    m = GATED_REGION.search(doc)
    checks += 1
    if not m:
        findings.append(f"{DOC}: there is no `<!-- g9:gated -->` region; the thresholds are "
                        "enforced from a data file with nothing next to it explaining them")
    else:
        documented = {name: int(score) for name, score in ROW.findall(m.group(1))}
        if documented != declared:
            only_doc = {k: v for k, v in documented.items() if declared.get(k) != v}
            only_data = {k: v for k, v in declared.items() if documented.get(k) != v}
            findings.append(
                f"{DOC}: the documented G9 thresholds and {DATA} differ - documented {only_doc}, "
                f"enforced {only_data}")

    # The same drift check over the OTHER table. Without it, a check could be
    # taken out of the gated subset in the data file and out of the document
    # too, and every remaining measurement would still be green: the gate would
    # be measuring a shorter list and saying so nowhere.
    m2 = NOT_GATED_REGION.search(doc)
    checks += 1
    if not m2:
        findings.append(f"{DOC}: there is no `<!-- g9:not-gated -->` region, so what {DATA} takes "
                        "out of the gated subset is written down nowhere a reader would find it")
    else:
        documented_out = set(NAME_ROW.findall(m2.group(1)))
        if documented_out != set(relocated):
            findings.append(
                f"{DOC}: the documented not-gated checks and {DATA} differ - documented "
                f"{sorted(documented_out - set(relocated))}, enforced "
                f"{sorted(set(relocated) - documented_out)}")

    # ---- 5. a check is gated, or relocated in writing. Never both, never ----
    #         neither. Deleting a row is the soft way to stop checking.
    checks += 1
    both = sorted(set(declared) & set(relocated))
    if both:
        findings.append(
            f"{DATA}: {', '.join(both)} is declared as gated AND as not gated here. One of the two "
            "is a leftover, and which one it is decides whether the check has teeth")

    # ---- 6. "something else really checks it" has to point at something ----
    for name, entry in sorted(relocated.items()):
        checks += 1
        named = entry.get("measured_by") or []
        if not named:
            findings.append(f"{DATA}: {name} is taken out of the gated subset and names nothing "
                            "that checks the property instead")
            continue
        missing = [f for f in named if not (root / f).exists()]
        if missing:
            findings.append(
                f"{DATA}: {name} says it is really checked by {', '.join(missing)}, and that does "
                "not exist. A control retired in favour of a file that is not there is a control "
                "retired")

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

    # ---- the relocated checks: printed, every run, with their real score --
    #      A check that stops being gated does not stop being measured. The
    #      number stays on screen so a fall is visible to whoever reads the run,
    #      and an entry that quietly disappeared from the results says so too.
    for name in sorted(relocated):
        score = scored.get(name)
        if score is None:
            shown = "absent from the results"
        elif score == -1:
            shown = "-1, inconclusive"
        else:
            shown = str(score)
        by = ", ".join(relocated[name].get("measured_by") or []) or "nothing named"
        print(f"  {name}: {shown} - NOT GATED on this number; really checked by {by}")

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
