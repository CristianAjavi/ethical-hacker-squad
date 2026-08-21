#!/usr/bin/env python3
"""Turn nine findings artifacts into one blind judging batch.

    python3 build-judge-pairs.py --root <scratch>/extern3 --key bench/external/go-2026-rule-picked.json --out pairs.json

The judge must not be able to tell which arm wrote which finding, and it must not
be able to infer it from the ORDER either - three artifacts concatenated in arm
order would hand it the answer without a single label. So:

  * every field that names an arm is dropped, and the id is rewritten to an
    opaque `P-nnn` that carries nothing;
  * the pairs are ordered by a hash of (case, arm, finding id), which is stable
    across runs and unrelated to the arm;
  * the mapping back to (arm, original id) is written to a SEPARATE file that the
    judge is never given, so the run can be scored afterwards and audited later.

The three arms emit two different shapes - the corpus arm writes this project's
findings schema, the other two a flat one - and the normaliser below is the only
place that difference is handled. It copies title, location, impact and evidence
verbatim: the judge reads each arm's own words, never a paraphrase of ours.

EXIT: 0 written · 2 could not read something it needs.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ARMS = ("treatment", "control", "competitor")


def normalise(item: dict) -> dict:
    """One finding, from either shape, with nothing that names its arm."""
    loc = item.get("location") or {}
    path = loc.get("path") or item.get("file") or ""
    line = loc.get("line") if loc else item.get("line")
    return {
        "title": item.get("title", ""),
        "location": f"{path}:{line}" if line is not None else path,
        "impact": item.get("impact", ""),
        "evidence": item.get("evidence", ""),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True, help="directory holding <case>/<arm>/out/")
    ap.add_argument("--key", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--map", required=True, help="where to write the arm mapping the judge never sees")
    args = ap.parse_args()

    try:
        key = json.loads(Path(args.key).read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print(f"UNMEASURED cannot read the key: {exc}")
        return 2

    root = Path(args.root)
    rows = []
    for case in key["cases"]:
        slug = case["repository"].split("github.com/")[1].split("/")[1]
        adv = {
            "advisory_id": case["advisory"],
            "advisory_summary": case["advisory_summary"],
            "advisory_description": case["advisory_description"],
        }
        for arm in ARMS:
            out = root / slug / arm / "out"
            files = sorted(out.glob("*.json")) if out.is_dir() else []
            if not files:
                print(f"UNMEASURED no artifact for {slug}/{arm}")
                return 2
            try:
                art = json.loads(files[0].read_text(encoding="utf-8"))
            except (OSError, ValueError) as exc:
                print(f"UNMEASURED cannot read {files[0]}: {exc}")
                return 2
            for item in art.get("findings", []):
                fid = item.get("id", "?")
                order = hashlib.sha256(f"{slug}|{arm}|{fid}".encode()).hexdigest()
                rows.append((order, slug, arm, fid, {**adv, **normalise(item)}))

    rows.sort(key=lambda r: r[0])
    pairs, mapping = [], []
    for i, (_, slug, arm, fid, payload) in enumerate(rows, 1):
        opaque = f"P-{i:03d}"
        pairs.append({"finding_id": opaque, **payload})
        mapping.append({"finding_id": opaque, "case": slug, "arm": arm, "original_id": fid})

    # Blinding check, before anything is written. It looks at KEYS and at whole
    # values, never at substrings of the findings' prose: an arm's own words
    # legitimately contain "access control" and "control socket", and a check
    # that greps for the bare word fires on those and teaches whoever runs it to
    # ignore the alarm. What must not appear is an arm NAME as a label.
    for pair in pairs:
        for k, v in pair.items():
            if k in ARMS or (isinstance(v, str) and v.strip().lower() in ARMS):
                raise SystemExit(f"BLINDING FAILURE: {pair['finding_id']} carries an arm label "
                                 f"in {k!r}; the judge would be told the answer")
        if not re.fullmatch(r"P-\d{3}", pair["finding_id"]):
            raise SystemExit(f"BLINDING FAILURE: {pair['finding_id']!r} is not an opaque id")

    Path(args.out).write_text(json.dumps(
        {"instructions": "one verdict per pair", "pairs": pairs}, indent=1) + "\n", encoding="utf-8")
    Path(args.map).write_text(json.dumps({"mapping": mapping}, indent=1) + "\n", encoding="utf-8")
    print(f"{len(pairs)} pair(s) -> {args.out}; the arm mapping is in {args.map} and the judge never sees it")
    return 0


if __name__ == "__main__":
    sys.exit(main())
