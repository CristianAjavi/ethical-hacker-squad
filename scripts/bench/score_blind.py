#!/usr/bin/env python3
"""Score a blinded audit against the planted key, by the rule fixed before the run.

WHAT IT DOES NOT DECIDE
    The matching rule, the metrics and the refutation criteria come from
    `bench/runs/2026-08-25-vibecoding-blind/PREREGISTRATION.md`, committed and
    pushed before the first run. This file implements them and nothing else. A
    generous reading of a near-miss would be choosing an analysis after seeing
    the data, so there is no near-miss handling here at all.

THE RULE, VERBATIM FROM THE PRE-REGISTRATION
    A reported finding MATCHES a planted defect when it names the same file AND
    either the same symbol or a line inside the planted range. Nothing else
    counts: not a finding of the right class in the wrong file, not a general
    remark about the file.

WHERE A REPORT IS ALLOWED TO COME FROM
    Every round on 2026-08-25 and 26 was scored from files the ORCHESTRATOR typed
    by hand out of what each agent returned. Nothing mechanical connected the
    text an arm produced to the text that got scored, and the risk stopped being
    theoretical when a sub-agent whose parent had died routed its slice to the
    orchestrator instead: a fragment that was never a run's answer arrived
    looking exactly like one.

    So a report must now carry a `provenance` block that the ARM itself wrote,
    naming what produced it. A file without one is not scored. This does not
    make transcription impossible - it makes it something a person has to
    deliberately fake rather than something that happens by being tired, and a
    round whose numbers cannot be traced to an arm is a round nobody can check.

WHY THE DECOY COUNT IS NOT OPTIONAL
    A run that reports everything scores perfect recall and is worthless. The
    decoy rate is printed beside recall in the same call, and this script has no
    flag that prints one without the other.

Exit codes: 0 = measured | 2 = could not measure, which is never a pass.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CASE = "intake-portal"
GROUND_TRUTH = ROOT / "bench" / "ground-truth.json"

# The primary metric's subject, named in the pre-registration rather than picked
# out of the results.
HIDING_CLASS = "a control that runs and cannot fail"

# The floor below which a round reports that it could not measure. It is a
# PARAMETER and not a constant because it belongs to a round's pre-registration
# rather than to this file: the 2026-08-25 blind round fixed five for its single
# arm, and the comparative round that followed fixed three for each competitor
# arm. Baking one round's number in here silently applied it to the other, which
# is what happened the first time this was run.
DEFAULT_MIN_VALID_RUNS = 5


def matches(finding: dict, entry: dict) -> bool:
    """The pre-registered rule. Same file, and then symbol or line."""
    got = str(finding.get("file", "")).strip().lstrip("./")
    want = str(entry.get("path", "")).strip().lstrip("./")
    if got != want:
        return False

    symbol = str(entry.get("symbol", "")).strip()
    if symbol and str(finding.get("symbol", "")).strip() == symbol:
        return True

    lines = entry.get("lines") or []
    if len(lines) == 2 and finding.get("line") is not None:
        try:
            return int(lines[0]) <= int(finding["line"]) <= int(lines[1])
        except (TypeError, ValueError):
            return False
    return False


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--reports", type=Path, required=True, help="directory of run-*.findings.json")
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--allow-untraced", action="store_true",
                    help="score reports with no provenance block. Every round before "
                         "2026-08-26 was transcribed by hand and needs this; a new round "
                         "that needs it is a round whose artefacts were retyped.")
    ap.add_argument("--min-valid-runs", type=int, default=DEFAULT_MIN_VALID_RUNS,
                    help="the floor this ROUND pre-registered, not a number chosen here")
    args = ap.parse_args(argv)

    try:
        truth = json.loads(GROUND_TRUTH.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print(f"UNMEASURED cannot read the key: {exc}")
        return 2

    planted = [p for p in truth.get("planted", []) if p.get("case") == CASE]
    decoys = [d for d in truth.get("decoys", []) if d.get("case") == CASE]
    hiding = [p for p in planted if p.get("class") == HIDING_CLASS]
    if not planted or not hiding:
        print(f"UNMEASURED the key holds no planted defect for {CASE}, or none of the class")
        return 2

    files = sorted(args.reports.glob("run-*.findings.json"))
    if not files:
        print(f"UNMEASURED no report under {args.reports}")
        return 2

    runs = []
    for path in files:
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
            # Two accepted shapes: a bare array (legacy, pre-provenance) or an
            # object carrying the findings and the block the arm wrote.
            if isinstance(raw, dict):
                report = raw.get("findings")
                prov = raw.get("provenance")
            else:
                report, prov = raw, None
            if prov is None and not args.allow_untraced:
                runs.append({"run": path.stem.replace(".findings", ""), "valid": False,
                             "why": "no provenance block: this file cannot be traced to an "
                                    "arm, and --allow-untraced was not given"})
                continue
        except ValueError as exc:
            runs.append({"run": path.stem.replace(".findings", ""), "valid": False, "why": f"did not parse: {exc}"})
            continue
        if not isinstance(report, list):
            runs.append({"run": path.stem.replace(".findings", ""), "valid": False, "why": "not a JSON array"})
            continue

        found = {p["id"] for p in planted if any(matches(f, p) for f in report if isinstance(f, dict))}
        dec = {d["id"] for d in decoys if any(matches(f, d) for f in report if isinstance(f, dict))}
        runs.append({
            "run": path.stem.replace(".findings", ""), "valid": True,
            "reported": len(report),
            "matched": sorted(found),
            "matched_hiding": sorted(found & {p["id"] for p in hiding}),
            "decoys_reported": sorted(dec),
        })

    valid = [r for r in runs if r["valid"]]
    report = {
        "case": CASE,
        "untraced_accepted": bool(args.allow_untraced),
        "planted": len(planted), "decoys": len(decoys),
        "hiding_class": sorted(p["id"] for p in hiding),
        "runs": runs,
        "valid_runs": len(valid),
        "min_valid_runs": None,  # filled from the argument below
    }
    if valid:
        report["recall_mean"] = sum(len(r["matched"]) for r in valid) / (len(valid) * len(planted))
        report["hiding_recall_mean"] = (
            sum(len(r["matched_hiding"]) for r in valid) / (len(valid) * len(hiding)))
        report["runs_reporting_any_hiding"] = sum(1 for r in valid if r["matched_hiding"])
        report["decoy_rate_mean"] = (
            sum(len(r["decoys_reported"]) for r in valid) / (len(valid) * len(decoys))
            if decoys else None)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    for r in runs:
        if r["valid"]:
            print(f"  {r['run']}: reported {r['reported']} · matched {len(r['matched'])}/{len(planted)}"
                  f" · hiding {len(r['matched_hiding'])}/{len(hiding)}"
                  f" · decoys {len(r['decoys_reported'])}/{len(decoys)}")
        else:
            print(f"  {r['run']}: INVALID - {r['why']}")

    if len(valid) < args.min_valid_runs:
        print(f"UNMEASURED only {len(valid)} valid run(s); the pre-registration requires "
              f"{args.min_valid_runs} and forbids reporting a number from what is left")
        return 2

    print(f"  recall {report['recall_mean']:.2f} · hiding-class recall "
          f"{report['hiding_recall_mean']:.2f} · runs reporting any of the class "
          f"{report['runs_reporting_any_hiding']}/{len(valid)} · decoy rate "
          f"{report['decoy_rate_mean']:.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
