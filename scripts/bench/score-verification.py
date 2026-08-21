#!/usr/bin/env python3
"""Score a verifier's verdicts against the patch answer key.

    python3 scripts/bench/score-verification.py --verdicts run.json

The verifier receives a finding and a diff that claims to fix it, and returns
one outcome per patch from the closed set in references/vocabulary.md. This
compares those outcomes to what a verifier that actually reached the code must
return.

Not all errors are equal, and the report says so:

  accepted a patch that does not fix   the expensive one. The finding is closed,
                                       the client ships, and the hole is still
                                       there. Reported first and counted alone.
  rejected a correct patch             costly and visible: someone re-does work
                                       that was already right.
  wrong but not accepting              e.g. `not fixed` where the key says
                                       `partially verified`. Conservative, and
                                       still wrong.
  unmeasured                           the verifier returned `inconclusive`,
                                       `not executed` or `blocked`. Never scored
                                       as a pass, and listed with its reason.

Exit: 0 measured, within thresholds · 1 measured, outside them · 2 could not measure.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KEY = ROOT / "bench" / "patch-truth.json"
ACCEPTING = {"verified"}
UNMEASURED = {"inconclusive", "not executed", "blocked"}


def load(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print(f"UNMEASURED cannot read {path}: {exc}")
        raise SystemExit(2)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--verdicts", required=True)
    ap.add_argument("--key", default=str(KEY))
    ap.add_argument("--max-false-accepts", type=int, default=None)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    key = load(Path(args.key))
    run = load(Path(args.verdicts))
    expected = {p["id"]: p for p in key["patches"]}
    given = {v["patch"]: v for v in run.get("verdicts", []) if isinstance(v, dict)}

    exact, false_accept, false_reject, other, unmeasured, missing = [], [], [], [], [], []
    for pid, patch in expected.items():
        v = given.get(pid)
        if v is None:
            missing.append(pid)
            continue
        outcome = v.get("outcome")
        want = patch["expected"]
        if outcome == want:
            exact.append((pid, outcome))
        elif outcome in UNMEASURED:
            unmeasured.append((pid, outcome, v.get("reason", "")))
        elif outcome in ACCEPTING and want not in ACCEPTING:
            false_accept.append((pid, outcome, want, patch["why"]))
        elif want in ACCEPTING and outcome not in ACCEPTING:
            false_reject.append((pid, outcome, want))
        else:
            other.append((pid, outcome, want))

    total = len(expected)
    print(f"patch bench: {total} patch(es), {len(given)} verdict(s) returned")
    print()
    print(f"exact                       {len(exact)}/{total}")
    for pid, outcome in exact:
        print(f"  = {pid} {outcome}")
    print(f"ACCEPTED A PATCH THAT DOES NOT FIX   {len(false_accept)}   <- the expensive error")
    for pid, outcome, want, why in false_accept:
        print(f"  ! {pid} said `{outcome}`, must be `{want}`")
        print(f"      {why}")
    print(f"rejected a correct patch    {len(false_reject)}")
    for pid, outcome, want in false_reject:
        print(f"  - {pid} said `{outcome}`, must be `{want}`")
    print(f"wrong, not accepting        {len(other)}")
    for pid, outcome, want in other:
        print(f"  ~ {pid} said `{outcome}`, must be `{want}`")
    print(f"unmeasured                  {len(unmeasured)}  (never a pass)")
    for pid, outcome, reason in unmeasured:
        print(f"  ? {pid} `{outcome}`: {reason[:90]}")
    if missing:
        print(f"no verdict returned         {len(missing)}: {', '.join(missing)}")

    if args.json:
        print(json.dumps({
            "total": total, "exact": [p for p, _ in exact],
            "false_accepts": [p for p, _, _, _ in false_accept],
            "false_rejects": [p for p, _, _ in false_reject],
            "other": [p for p, _, _ in other],
            "unmeasured": [p for p, _, _ in unmeasured],
            "missing": missing,
        }, indent=2))

    rc = 0
    if args.max_false_accepts is not None and len(false_accept) > args.max_false_accepts:
        print(f"\nFAIL {len(false_accept)} patch(es) accepted that do not fix, over the declared "
              f"maximum {args.max_false_accepts}")
        rc = 1
    if args.max_false_accepts is None:
        print("\nno threshold was passed: this run measured, it did not judge")
    return rc


if __name__ == "__main__":
    sys.exit(main())
