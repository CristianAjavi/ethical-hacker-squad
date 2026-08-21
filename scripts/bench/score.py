#!/usr/bin/env python3
"""Score a findings artifact against the bench answer key.

    python3 scripts/bench/score.py --findings run.json [--min-recall 0.7] [--max-decoys 0]

What it reports, and what each number is worth:

  detected        planted defects that a finding reaches, by path and symbol.
                  This is recall on THIS bench, not on real code.
  missed          planted defects nothing reported. The interesting column.
  decoys reported constructs planted to look vulnerable and be ruled out. Every
                  one of these is a false positive with a name, and this
                  repository calls that its first-class defect.
  decoy triage    when a decoy IS reported, whether the finding at least answers
                  the triage rule that rules it out. A squad that reports a
                  decoy while answering FP-01 `DOES_NOT_HOLD` is wrong twice.
  unlabelled      findings that match neither. NOT counted as false positives:
                  the bench does not claim to have planted everything there is.

Exit codes: 0 measured, within thresholds · 1 measured, outside them ·
2 could not measure. Thresholds only apply when passed.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GROUND_TRUTH = ROOT / "bench" / "ground-truth.json"


def load(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print(f"UNMEASURED cannot read {path}: {exc}")
        raise SystemExit(2)


def norm(path: str) -> str:
    return re.sub(r"^.*?(bench/cases/[^/]+/)?", "", path or "").strip("/")


def matches(finding: dict, item: dict) -> bool:
    """A finding hits an item when it points at the same place.

    LOCATION FIRST, and prose only as a fallback. The first real run exposed why:
    a finding that contrasts the defect with the control beside it mentions both
    symbols, so matching on the finding's text scored five correct findings as one
    detection and six false positives. What a finding is ABOUT is its location.
    """
    fpath = norm(finding.get("location", {}).get("path", ""))
    # A defect can span files - a route that accepts the value and the helper that
    # uses it - and a finding at either half is the same finding. The key says so
    # with `also_at`, and the first run is why: the squad reported the SSRF at the
    # fetch helper and the key named only the route.
    places = [{"path": item["path"], "lines": item.get("lines"), "symbol": item["symbol"]}]
    places += item.get("also_at", [])
    place = next((pl for pl in places
                  if fpath.endswith(norm(pl["path"])) or norm(pl["path"]).endswith(fpath)), None)
    if place is None:
        return False

    line = finding.get("location", {}).get("line")
    span = place.get("lines")
    if isinstance(line, int) and span:
        return span[0] <= line <= span[1]

    # No line, or no span for this item: fall back to the finding's TITLE, which
    # names its subject. Never the evidence or the impact, which discuss the
    # neighbourhood.
    symbol = place.get("symbol", item["symbol"])
    needle = symbol.split()[-1] if " " in symbol else symbol
    title = str(finding.get("title", ""))
    if re.fullmatch(r"\w+", needle):
        return re.search(rf"\b{re.escape(needle)}\b", title, re.I) is not None
    return needle.lower() in title.lower()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--findings", required=True)
    ap.add_argument("--ground-truth", default=str(GROUND_TRUTH))
    ap.add_argument("--min-recall", type=float, default=None)
    ap.add_argument("--max-decoys", type=int, default=None)
    ap.add_argument("--json", action="store_true", help="emit the scores as JSON")
    args = ap.parse_args()

    gt = load(Path(args.ground_truth))
    art = load(Path(args.findings))
    findings = [f for f in art.get("findings", []) if isinstance(f, dict)]
    reportable = [f for f in findings if f.get("status") in ("confirmed", "probable")]

    detected, missed = [], []
    for item in gt["planted"]:
        hit = next((f for f in reportable if matches(f, item)), None)
        (detected if hit else missed).append((item, hit))

    decoys_reported = []
    for decoy in gt["decoys"]:
        hit = next((f for f in reportable if matches(f, decoy)), None)
        if hit:
            answered = {t.get("rule"): t.get("answer") for t in hit.get("triage", []) if isinstance(t, dict)}
            decoys_reported.append((decoy, hit, answered))

    hit_ids = {id(h) for _, h in detected if h} | {id(h) for _, h, _ in decoys_reported}
    unlabelled = [f for f in reportable if id(f) not in hit_ids]

    planted = len(gt["planted"])
    recall = len(detected) / planted if planted else 0.0

    print(f"bench: {len(gt['cases'])} case(s), {planted} planted, {len(gt['decoys'])} decoys")
    print(f"artifact: {len(findings)} finding(s), {len(reportable)} reportable (confirmed or probable)")
    print()
    print(f"detected        {len(detected)}/{planted}  (recall {recall:.0%} on this bench)")
    for item, hit in detected:
        print(f"  + {item['id']} {item['procedure']:<7} {item['symbol']:<24} as {hit.get('id')} [{hit.get('status')}]")
    print(f"missed          {len(missed)}")
    for item, _ in missed:
        print(f"  - {item['id']} {item['procedure']:<7} {item['symbol']:<24} {item['class']}")
    print(f"decoys reported {len(decoys_reported)}  (each one is a false positive with a name)")
    for decoy, hit, answered in decoys_reported:
        rules = ", ".join(decoy["ruled_out_by"])
        given = ", ".join(f"{k}={v}" for k, v in answered.items()) or "no triage answers"
        print(f"  ! {decoy['id']} looks like {decoy['looks_like']} at {decoy['symbol']}")
        print(f"      ruled out by {rules}; the finding answered: {given}")
    print(f"unlabelled      {len(unlabelled)}  (not counted against the run: the bench does not claim to be exhaustive)")
    for f in unlabelled:
        print(f"  ? {f.get('id')} {f.get('procedure')} {f.get('location', {}).get('path')}")

    by_procedure: dict[str, list[str]] = {}
    for item, hit in detected + [(i, None) for i, _ in missed]:
        by_procedure.setdefault(item["procedure"], []).append("hit" if hit else "miss")
    print()
    print("by procedure:")
    for proc in sorted(by_procedure):
        results = by_procedure[proc]
        print(f"  {proc:<8} {results.count('hit')}/{len(results)}")

    if args.json:
        print(json.dumps({
            "recall": recall,
            "detected": [i["id"] for i, _ in detected],
            "missed": [i["id"] for i, _ in missed],
            "decoys_reported": [d["id"] for d, _, _ in decoys_reported],
            "unlabelled": len(unlabelled),
        }, indent=2))

    rc = 0
    if args.min_recall is not None and recall < args.min_recall:
        print(f"\nFAIL recall {recall:.0%} is below the declared minimum {args.min_recall:.0%}")
        rc = 1
    if args.max_decoys is not None and len(decoys_reported) > args.max_decoys:
        print(f"FAIL {len(decoys_reported)} decoys reported, over the declared maximum {args.max_decoys}")
        rc = 1
    if args.min_recall is None and args.max_decoys is None:
        print("\nno threshold was passed: this run measured, it did not judge")
    return rc


if __name__ == "__main__":
    sys.exit(main())
