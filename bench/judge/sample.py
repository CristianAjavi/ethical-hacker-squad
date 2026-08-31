#!/usr/bin/env python3
"""Build a blind judging set from published run reports.

WHY IT EXISTS
    The scorer can only rule on a finding the key names. Measured across twelve
    published runs, that is about one finding in eight for one of the arms, so
    the bench is silent about the majority of what that arm produces and about
    the whole of what makes the two arms differ.

WHAT IT DOES
    Pools every finding, strips the arm and the run, shuffles deterministically,
    and emits a judging set of three kinds mixed together and indistinguishable:

      outside   the finding the key does not name - the question being asked
      planted   a finding that sits on a planted defect - the judge SHOULD call true
      decoy     a finding that sits on a planted decoy - the judge SHOULD call false

    The last two are the CONTROL. A judge that cannot separate them is not
    measuring anything about the first, and its verdicts on `outside` are void.
    The answer file is written separately and is never shown to a judge.

Exit codes: 0 = set written | 2 = could not build one.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path


def near(path, line, pairs, w=6):
    return any(path == p and abs(line - l) <= w for p, l in pairs)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--rounds", nargs="+", required=True, help="round directories")
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--answers", type=Path, required=True)
    ap.add_argument("--root", nargs="+", default=[], metavar="ROUND=PATH",
                    help="tree a judge must read for each round, so it can check "
                         "the code rather than the claim")
    ap.add_argument("--n-outside", type=int, default=40)
    ap.add_argument("--n-control", type=int, default=10,
                    help="planted and decoy controls, each")
    a = ap.parse_args(argv)

    pool = []
    for rd in a.rounds:
        rdp = Path(rd)
        key = json.loads((rdp / "key.json").read_text())
        P = [(p["path"], p["line"]) for p in key["planted"]]
        D = [(d["path"], d["line"]) for d in key["decoys"]]
        for f in sorted((rdp / "runs").glob("*.adapted.json")):
            doc = json.loads(f.read_text())
            for x in doc.get("findings", []):
                loc = x.get("location") or {}
                if not loc.get("line"):
                    continue
                p, l = loc["path"], loc["line"]
                kind = ("planted" if near(p, l, P)
                        else "decoy" if near(p, l, D) else "outside")
                pool.append({
                    "kind": kind, "round": rdp.name,
                    "path": p, "line": l,
                    "symbol": loc.get("symbol", ""),
                    "title": x.get("title", ""),
                    "claim": x.get("class", ""),
                })
    if not pool:
        print("UNMEASURABLE no findings with a location in those rounds")
        return 2

    # Deterministic order that does not depend on the arm: sort by a digest of
    # the finding itself. Using random would make the set unreproducible, and a
    # reader who cannot rebuild the set cannot check the result.
    for i, x in enumerate(pool):
        x["_h"] = hashlib.sha256(
            f"{x['path']}:{x['line']}:{x['title']}".encode()).hexdigest()
    pool.sort(key=lambda x: x["_h"])

    picked = []
    for kind, n in (("outside", a.n_outside), ("planted", a.n_control), ("decoy", a.n_control)):
        seen = set()
        for x in pool:
            if x["kind"] != kind:
                continue
            sig = (x["path"], x["line"])
            if sig in seen:
                continue
            seen.add(sig)
            picked.append(x)
            if len(seen) >= n:
                break
    if not any(x["kind"] == "decoy" for x in picked):
        print("UNMEASURABLE no decoy controls available: a judge with no negative "
              "control measures nothing")
        return 2

    roots = dict(r.split("=", 1) for r in a.root if "=" in r)
    picked.sort(key=lambda x: x["_h"])
    items, answers = [], []
    for i, x in enumerate(picked, 1):
        items.append({"id": f"J-{i:03d}", "root": roots.get(x["round"], ""),
                      "path": x["path"], "line": x["line"],
                      "symbol": x["symbol"], "assertion": x["title"],
                      "class": x["claim"]})
        answers.append({"id": f"J-{i:03d}", "kind": x["kind"],
                        "path": x["path"], "line": x["line"], "round": x["round"]})
    a.out.write_text(json.dumps({"items": items}, indent=2) + "\n")
    a.answers.write_text(json.dumps({"answers": answers}, indent=2) + "\n")
    counts = {k: sum(1 for x in picked if x["kind"] == k) for k in ("outside", "planted", "decoy")}
    print(f"  {len(items)} item(s): {counts['outside']} outside the key, "
          f"{counts['planted']} planted controls, {counts['decoy']} decoy controls")
    print(f"  set     -> {a.out}")
    print(f"  answers -> {a.answers}  (never shown to a judge)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
