#!/usr/bin/env python3
"""Pick external cases by a published rule instead of by our judgement.

    python3 scripts/bench/pick-external-cases.py --ecosystem npm --severity high --count 5

The objection this answers: every external run so far used advisories WE chose,
and a bench whose cases are hand-picked measures the picker as much as the tool.
This takes the most recent reviewed advisories matching a filter, keeps the ones
that carry a fix commit in the project's own repository, and emits them in the
order the API returned them. No skipping, no "that one looks unfair", and the
rejects are printed with the reason so the filter cannot hide a choice.

What it cannot remove: somebody still types the ecosystem and the severity. The
filter is written into the output, so a reader can see exactly which population
the sample came from and rerun it.

Exit: 0 emitted · 1 nothing matched the filter · 2 the API could not be reached.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

COMMIT = re.compile(r"https://github\.com/([^/]+/[^/]+)/commit/([0-9a-f]{7,40})")


def gh(path: str, jq: str = "."):
    r = subprocess.run(["gh", "api", path, "--jq", jq], capture_output=True, text=True)
    if r.returncode != 0:
        print(f"UNMEASURED gh api {path}: {r.stderr.strip()[:200]}")
        raise SystemExit(2)
    return r.stdout


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ecosystem", required=True)
    ap.add_argument("--severity", default="high")
    ap.add_argument("--count", type=int, default=5)
    ap.add_argument("--page-size", type=int, default=30)
    ap.add_argument("--out", help="write the case file here")
    args = ap.parse_args()

    raw = gh(f"/advisories?ecosystem={args.ecosystem}&severity={args.severity}"
             f"&type=reviewed&per_page={args.page_size}")
    advisories = json.loads(raw)
    print(f"population: {len(advisories)} reviewed {args.severity} advisories for {args.ecosystem}, "
          "newest first, exactly as the API returned them")

    cases, rejected = [], []
    for a in advisories:
        if len(cases) >= args.count:
            break
        ghsa = a["ghsa_id"]
        refs = [r for r in a.get("references", []) if COMMIT.search(r or "")]
        if not refs:
            rejected.append((ghsa, "no fix commit in its references"))
            continue
        repo, sha = COMMIT.search(refs[0]).groups()
        src = (a.get("source_code_location") or "").rstrip("/")
        if src and not src.endswith(repo):
            rejected.append((ghsa, f"the commit is in {repo}, not in the advisory's own repository"))
            continue
        commit = json.loads(gh(f"repos/{repo}/commits/{sha}",
                               '{parent: .parents[0].sha, files: [.files[] | select(.filename | '
                               'test("test|spec|CHANGELOG|\\\\.md$") | not) | .filename]}'))
        if not commit["files"]:
            rejected.append((ghsa, "the fix touches only tests or documentation"))
            continue
        cases.append({"advisory": ghsa, "cve": a.get("cve_id"), "repository": f"https://github.com/{repo}",
                      "fix": sha, "parent": commit["parent"], "fix_files": commit["files"],
                      "advisory_summary": a.get("summary", ""),
                      "advisory_description": (a.get("description") or "")[:1200]})

    print(f"kept {len(cases)}, rejected {len(rejected)}:")
    for ghsa, why in rejected:
        print(f"  - {ghsa}: {why}")

    if not cases:
        print("nothing matched: widen the filter rather than changing the rule after seeing the result")
        return 1

    record = {"schema": "ehs.external-cases/v1",
              "selection": {"rule": "the most recent reviewed advisories matching the filter, in API order, "
                                    "keeping those with a fix commit in the project's own repository",
                            "ecosystem": args.ecosystem, "severity": args.severity,
                            "requested": args.count, "population_page": args.page_size,
                            "rejected": [{"advisory": g, "why": w} for g, w in rejected]},
              "honest_limit": "somebody still types the ecosystem and the severity; the filter is recorded so "
                              "a reader can see the population and rerun it",
              "cases": cases}
    if args.out:
        Path(args.out).write_text(json.dumps(record, indent=2) + "\n")
        print(f"written: {args.out}")
    else:
        print(json.dumps(record, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
