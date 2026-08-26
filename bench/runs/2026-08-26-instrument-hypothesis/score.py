#!/usr/bin/env python3
"""Score the instrument round against the key, by the pre-registered rule.

The rule was fixed before any arm ran: a claim matches when it names the same
path AND (the same symbol OR a line inside the keyed range). Either keyed site
counts - the fix commit treats them as one defect.

A report that does not parse, or that carries no provenance block, is INVALID
and is not counted as a miss: it is a run that did not happen. Fewer than three
valid runs in an arm is 2, could not measure.

Exit codes: 0 = measured | 2 = could not measure.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).parent
KEY = json.loads((HERE / "key.json").read_text())
MIN_VALID = 3


def matches(loc: dict, planted: dict) -> bool:
    path = (loc.get("path") or "").replace("\\", "/").lstrip("./")
    if not path.endswith(planted["path"]):
        return False
    if (loc.get("symbol") or "") == planted["symbol"]:
        return True
    line = loc.get("line")
    lo, hi = planted["line_range"]
    return isinstance(line, int) and lo <= line <= hi


def score_report(p: Path) -> dict:
    try:
        data = json.loads(p.read_text())
    except (json.JSONDecodeError, OSError) as e:
        return {"valid": False, "why": f"{e.__class__.__name__}"}
    if not isinstance(data.get("provenance"), dict):
        return {"valid": False, "why": "no provenance block"}
    findings = data.get("findings") or []
    if not isinstance(findings, list):
        return {"valid": False, "why": "findings is not a list"}

    hit, hit_id = False, None
    for f in findings:
        loc = f.get("location") or {}
        for planted in KEY["planted"]:
            if matches(loc, planted):
                hit, hit_id = True, planted["id"]
                break
        if hit:
            break

    # registered secondary: does the run report ANY log-injection site at all
    cls_hit = any("log" in (f.get("class") or "").lower()
                  and "inject" in (f.get("class") or "").lower()
                  or "log injection" in (f.get("title") or "").lower()
                  or "log-injection" in (f.get("title") or "").lower()
                  for f in findings)
    return {"valid": True, "advisory": hit, "which": hit_id,
            "class_level": cls_hit, "claims": len(findings)}


def main() -> int:
    base = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "runs"
    if not base.is_dir():
        print(f"UNMEASURABLE no runs directory at {base}")
        return 2

    arms: dict[str, list] = {}
    for p in sorted(base.glob("*.json")):
        arm = p.stem.split("-")[0]
        arms.setdefault(arm, []).append((p.stem, score_report(p)))

    if not arms:
        print(f"UNMEASURABLE no run reports under {base}")
        return 2

    rc = 0
    for arm in sorted(arms):
        rows = arms[arm]
        valid = [r for _, r in rows if r["valid"]]
        adv = sum(1 for r in valid if r["advisory"])
        cls = sum(1 for r in valid if r["class_level"])
        claims = sum(r["claims"] for r in valid)
        print(f"\n== arm {arm} ==")
        for name, r in rows:
            if not r["valid"]:
                print(f"  {name}: INVALID ({r['why']})")
            else:
                mark = f"ADVISORY {r['which']}" if r["advisory"] else "-"
                print(f"  {name}: {r['claims']:>3} claims  class:{'yes' if r['class_level'] else 'no ':<3}  {mark}")
        if len(valid) < MIN_VALID:
            print(f"  UNMEASURABLE only {len(valid)} valid run(s), floor is {MIN_VALID}")
            rc = 2
        else:
            print(f"  advisory {adv} of {len(valid)} | class-level {cls} of {len(valid)} | {claims} claims")
    return rc


if __name__ == "__main__":
    sys.exit(main())
