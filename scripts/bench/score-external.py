#!/usr/bin/env python3
"""Score an audit of third-party code against advisories nobody here wrote.

    python3 scripts/bench/score-external.py --findings a.json [b.json ...] \
        --key bench/external/lemur-2026.json --judgements judge.json

Two levels, and neither of them is this project's opinion:

  file level   deterministic. A finding can only hit an advisory whose fix
               commit touched the file the finding points at. Nothing here is
               interpretation: the file list comes from the upstream commit.
  class level  judged by an INDEPENDENT context that saw the advisory text and
               the finding text and nothing else - not the repository, not who
               wrote either, not this project. Its verdicts arrive in a file.

A hit needs both. Without judgements the script reports file-level candidates
and refuses to call anything a hit, because the first external run was scored by
this project reading the upstream diff, and that is the hand this removes.

Exit: 0 measured · 1 measured and below a declared threshold · 2 could not measure.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def load(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print(f"UNMEASURED cannot read {path}: {exc}")
        raise SystemExit(2)


def tail(path: str, files: list[str]) -> str | None:
    """Match a reported path against a fix file, anchored on a separator."""
    p = (path or "").replace("\\", "/").lstrip("./")
    for f in files:
        if p == f or p.endswith("/" + f) or f.endswith("/" + p):
            return f
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--findings", nargs="+", required=True)
    ap.add_argument("--key", required=True)
    ap.add_argument("--judgements", help="verdicts from the independent judge")
    ap.add_argument("--min-found", type=int, default=None)
    args = ap.parse_args()

    key = load(Path(args.key))
    cases = {c["advisory"]: c for c in key["cases"]}
    findings = []
    for f in args.findings:
        art = load(Path(f))
        # Ids repeat across artifacts (every specialist starts at F-001), so they
        # are namespaced by the file they came from. Two findings that scored as
        # one is a scoring bug, not a result.
        tag = Path(f).stem.replace("findings-", "").replace("findings", "")[:12] or Path(f).parent.name
        for item in art.get("findings", []):
            if item.get("status") in ("confirmed", "probable", "hardening"):
                item = dict(item)
                item["id"] = f"{tag}:{item['id']}" if tag else item["id"]
                findings.append(item)

    judged = {}
    if args.judgements:
        for j in load(Path(args.judgements)).get("judgements", []):
            judged[(j["advisory"], j["finding"])] = j["verdict"]

    print(f"external key: {len(cases)} advisory(ies) from {key.get('repository')}")
    print(f"artifact: {len(findings)} reported finding(s)")
    print()

    found, missed, unmatched = [], [], list(findings)
    for adv, case in cases.items():
        candidates = [f for f in findings if tail(f.get("location", {}).get("path", ""), case["fix_files"])]
        hit = None
        for c in candidates:
            verdict = judged.get((adv, c["id"]))
            if verdict == "yes":
                hit = c
                break
        if hit:
            found.append((adv, hit))
            if hit in unmatched:
                unmatched.remove(hit)
            print(f"FOUND    {adv} ({case.get('cve')}) by {hit['id']} [{hit['status']}] "
                  f"at {hit.get('location', {}).get('path')}")
        else:
            missed.append((adv, candidates))
            if not args.judgements:
                print(f"candidate{'s' if len(candidates) != 1 else ''} for {adv}: "
                      f"{[c['id'] for c in candidates] or 'none'} - NOT scored: no judgements given")
            else:
                print(f"MISSED   {adv} ({case.get('cve')}); file-level candidates: "
                      f"{[c['id'] for c in candidates] or 'none'}")

    print()
    if args.judgements:
        print(f"found {len(found)} / {len(cases)} published advisories")
    else:
        print(f"found 0 / {len(cases)} — file-level candidates only; a hit requires an independent class judgement")
    print(f"findings matching no advisory file: {len([f for f in unmatched if not any(tail(f.get('location', {}).get('path', ''), c['fix_files']) for c in cases.values())])}")
    print("Not counted either way: a defect nobody has published is neither a hit nor a miss.")

    if args.min_found is not None and len(found) < args.min_found:
        print(f"\nFAIL found {len(found)}, below the declared minimum {args.min_found}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
