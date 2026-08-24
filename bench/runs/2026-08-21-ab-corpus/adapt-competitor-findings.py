#!/usr/bin/env python3
"""Convert a competitor's finding index into the shape `score-external.py` reads.

    python3 adapt-competitor-findings.py --in index.json --case mcp --out findings-competitor-mcp.json

The competitor emits `{file, line, title, impact, evidence, severity}`. Our
scorer reads `{id, status, location:{path,line}, title, ...}` and keeps a
finding only if its status is one of confirmed/probable/hardening.

Two decisions, both made in the competitor's favour and both stated here rather
than buried:

  status    their severity is NOT our status - the two vocabularies do not
            correspond, and inventing a correspondence would let us demote
            their findings out of the count. Every finding their own pipeline
            chose to report is carried through as reported. Nothing is dropped.
  path      copied verbatim. If their path does not match the advisory's fix
            files, that is a miss, not a normalisation problem: the file-level
            matcher already anchors on separators at both ends.

Nothing else is touched. Titles, impact and evidence are copied so the blind
judge reads their words, not a paraphrase of ours.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="src", required=True)
    ap.add_argument("--case", required=True, help="namespace for ids, e.g. mcp")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    try:
        raw = json.loads(Path(args.src).read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print(f"UNMEASURED cannot read {args.src}: {exc}")
        return 2

    items = raw.get("findings")
    if not isinstance(items, list):
        print(f"UNMEASURED {args.src} has no 'findings' list")
        return 2

    out = []
    for i, f in enumerate(items, 1):
        fid = f.get("id") or f"C-{i:03d}"
        out.append({
            "id": fid,
            "status": "confirmed",
            "title": f.get("title", ""),
            "location": {"path": f.get("file", ""), "line": f.get("line")},
            "impact": f.get("impact", ""),
            "evidence": f.get("evidence", ""),
            "their_severity": f.get("severity"),
        })

    Path(args.out).write_text(json.dumps({
        "schema": "ehs.findings/v1-adapted",
        "arm": "competitor",
        "case": args.case,
        "source": args.src,
        "note": "status is not their word; see adapt-competitor-findings.py for why every reported finding is carried through as reported",
        "findings": out,
    }, indent=1) + "\n", encoding="utf-8")
    print(f"adapted {len(out)} finding(s) -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
