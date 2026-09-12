#!/usr/bin/env python3
"""Turn a third-party scanner's raw output into a findings artifact score.py reads.

    python3 scripts/bench/adapt-external.py \
        --format ultrasec \
        --raw bench/external/<tool>-<date>/raw/recall/express-invoices.findings.json \
        --scan-root bench/cases/express-invoices \
        --out /tmp/adapted.json

WHY THIS EXISTS, AND WHY IT IS NOT A SECOND SCORER

  `bench/ground-truth.json` has been scored against this project's own runs and
  against nothing else. Eighteen blinded measurements compare this corpus to
  rivals on rubrics; not one of them took an outside tool's RAW output and
  crossed it against the answer key by file and line. The reason was never the
  scoring - `scripts/bench/score.py` already matches a finding to a planted
  defect by path and span, and has its own battery. The reason was the plumbing:
  no outside tool speaks this project's findings shape. This file is that
  plumbing and nothing else. It decides no verdict and owns no threshold; it
  converts locations and counts what it could not convert.

WHAT IT REFUSES TO DO

  Exit 0 with zero findings on an input it did not recognise. A zero from an
  instrument nobody has seen produce a one is not a measurement, and an adapter
  that shrugs at an unknown shape would hand the bench a clean, flattering zero
  for every tool it cannot read. An unrecognised format is exit 2, with the file
  named and the reason printed. `--format auto` refuses an EMPTY JSON array for
  the same reason: `[]` names no format, and a tool that genuinely found nothing
  must be declared with `--format` so the zero is attributed to the tool rather
  than to this file's guess.

  Drop a finding quietly. Every raw record is either emitted or listed by name
  under `unmapped` with its cause, and the counts `raw in / emitted / unmapped`
  are printed on every run. A dropped finding is a flattering number for the
  bench: it removes a rival's false positive and its hit alike.

PATHS
  A foreign tool reports paths relative to ITS scan root. The scan root is an
  explicit argument, never inferred from the file name, and the emitted path is
  `<scan-root>/<reported path>` - which is what `score.py`'s `norm()` reduces to
  a case-relative path. A reported path that does not resolve to a file in this
  checkout is unmapped and named: the adapter never emits a location it cannot
  point at.

WHAT IT DOES NOT MEASURE, and will not pretend to
  * Whether the tool is RIGHT. This maps locations. A tool that lands on the
    correct line for the wrong reason is a hit here, and that is a limit of
    file-and-line agreement, declared here and again in the gate.
  * The second half of a flow. A taint finding names a source and a sink; the
    sink is the location emitted, the source is recorded in `also_seen` and is
    NOT scored. Scoring both ends would let one report count twice - as a hit at
    one end and a decoy at the other.
  * Triage. The external status is mapped to one of this project's reported
    statuses by `--status` and nothing here judges it. A candidate a tool has
    not adjudicated still reaches its user's screen, which is why the default is
    `probable` rather than `candidate`.

Exit codes: 0 measured · 1 measured and outside a declared threshold ·
2 could not measure (never a pass).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

SARIF = "sarif"
ULTRASEC = "ultrasec"
FORMATS = (SARIF, ULTRASEC)


def fail_unmeasured(msg: str) -> None:
    print(f"UNMEASURED {msg}")
    raise SystemExit(2)


def load(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        fail_unmeasured(f"cannot read {path}: {exc}")
    except ValueError as exc:
        fail_unmeasured(f"{path} is not JSON: {exc}")


def detect(doc, name: str) -> str:
    """Name the format, or refuse. Never guess into a clean zero."""
    if isinstance(doc, dict):
        schema = str(doc.get("$schema", "")).lower()
        if isinstance(doc.get("runs"), list) and ("sarif" in schema or "version" in doc):
            return SARIF
        if isinstance(doc.get("findings"), list) and doc["findings"]:
            return ULTRASEC
        fail_unmeasured(
            f"{name}: a JSON object with keys {sorted(doc)[:6]} matches no format this "
            "adapter knows (SARIF needs `runs` plus `$schema`/`version`). Pass --format "
            "explicitly, or teach this file the shape - a zero here would be a guess.")
    if isinstance(doc, list):
        if not doc:
            fail_unmeasured(
                f"{name}: an empty JSON array names no format. A tool that found nothing "
                "must be declared with --format, so the zero is attributed to the tool "
                "and not to this adapter's guess.")
        if all(isinstance(x, dict) for x in doc) and any(
                ("sink" in x or "location" in x or "file" in x) for x in doc):
            return ULTRASEC
        fail_unmeasured(
            f"{name}: a JSON array whose records carry no location key "
            "(`sink`, `location`, `file`) matches no format this adapter knows.")
    fail_unmeasured(f"{name}: top-level JSON {type(doc).__name__} matches no format this adapter knows.")
    raise AssertionError("unreachable")


def records_ultrasec(doc):
    """One record per raw finding. `sink` is the primary location."""
    items = doc if isinstance(doc, list) else doc.get("findings") or []
    for item in items:
        if not isinstance(item, dict):
            yield {"path": None, "line": None, "why": "record is not an object", "raw": item}
            continue
        sink = item.get("sink") if isinstance(item.get("sink"), dict) else {}
        loc = item.get("location") if isinstance(item.get("location"), dict) else {}
        path = sink.get("file") or loc.get("path") or loc.get("file") or item.get("file")
        line = sink.get("line") or loc.get("line") or item.get("line")
        src = item.get("source") if isinstance(item.get("source"), dict) else {}
        yield {
            "path": path,
            "line": line,
            "title": item.get("title") or item.get("message") or item.get("id"),
            "severity": item.get("severity"),
            "rule": item.get("cwe") or item.get("category"),
            "native_id": item.get("id"),
            "native_status": item.get("status"),
            "second": (src.get("file"), src.get("line")) if src.get("file") else None,
        }


def records_sarif(doc):
    for run in doc.get("runs") or []:
        if not isinstance(run, dict):
            continue
        driver = (run.get("tool") or {}).get("driver") or {}
        for res in run.get("results") or []:
            if not isinstance(res, dict):
                yield {"path": None, "line": None, "why": "result is not an object", "raw": res}
                continue
            locs = res.get("locations") or []
            phys = (locs[0] if locs and isinstance(locs[0], dict) else {}).get("physicalLocation") or {}
            uri = (phys.get("artifactLocation") or {}).get("uri")
            line = (phys.get("region") or {}).get("startLine")
            msg = res.get("message") or {}
            yield {
                "path": uri,
                "line": line,
                "title": (msg.get("text") if isinstance(msg, dict) else None) or res.get("ruleId"),
                "severity": res.get("level"),
                "rule": res.get("ruleId"),
                "native_id": res.get("guid") or res.get("correlationGuid"),
                "native_status": (res.get("kind") or None),
                "second": None,
                "driver": driver.get("name"),
            }


READERS = {SARIF: records_sarif, ULTRASEC: records_ultrasec}


def repo_relative(reported: str | None, scan_root: str, repo_root: Path):
    """<scan-root>/<reported>, or (None, why). Never a location that does not exist."""
    if not reported or not str(reported).strip():
        return None, "the tool reported no path"
    p = str(reported).strip().replace("\\", "/")
    if p.startswith("file://"):
        p = p[len("file://"):]
    if p.startswith("/"):
        try:
            anchor = (repo_root / scan_root).resolve()
            rel = Path(p).resolve().relative_to(anchor)
        except (ValueError, OSError, RuntimeError):
            return None, f"absolute path outside the declared scan root {scan_root}"
        p = rel.as_posix()
    while p.startswith("./"):
        p = p[2:]
    p = p.lstrip("/")
    joined = f"{scan_root.strip('/')}/{p}"
    if ".." in joined.split("/"):
        return None, "path escapes the scan root"
    if not (repo_root / joined).is_file():
        return None, f"{joined} is not a file in this checkout"
    return joined, None


def main() -> int:
    ap = argparse.ArgumentParser(description="adapt a third-party scanner's output for score.py")
    ap.add_argument("--raw", action="append", required=True,
                    help="raw output file; repeatable, paired with --scan-root by position")
    ap.add_argument("--scan-root", action="append", required=True,
                    help="repo-relative root the tool scanned; one, or one per --raw")
    ap.add_argument("--out", required=True, help="findings artifact to write")
    ap.add_argument("--format", default="auto", choices=("auto",) + FORMATS)
    ap.add_argument("--status", default="probable",
                    help="this project's status to record (default: probable)")
    ap.add_argument("--repo-root", default=str(ROOT))
    ap.add_argument("--tool", default="", help="tool name recorded in the artifact")
    ap.add_argument("--max-unmapped", type=int, default=None,
                    help="fail with 1 when more raw findings than this could not be placed")
    ap.add_argument("--json", action="store_true", help="also emit the counts as JSON")
    args = ap.parse_args()

    repo_root = Path(args.repo_root).resolve()
    if not repo_root.is_dir():
        fail_unmeasured(f"--repo-root {args.repo_root} is not a directory")

    raws = args.raw
    roots = args.scan_root
    if len(roots) == 1 and len(raws) > 1:
        roots = roots * len(raws)
    if len(roots) != len(raws):
        fail_unmeasured(
            f"{len(raws)} --raw and {len(roots)} --scan-root: pass one scan root per raw file, "
            "or exactly one for all of them. Guessing which root a file was scanned under is "
            "how a finding lands on the wrong case.")

    findings = []
    unmapped = []
    raw_in = 0
    second_locations = 0
    per_file = []

    for raw_name, root in zip(raws, roots):
        raw_path = Path(raw_name)
        if not raw_path.is_absolute():
            raw_path = repo_root / raw_name
        doc = load(raw_path)
        fmt = args.format if args.format != "auto" else detect(doc, raw_name)
        if fmt not in READERS:
            fail_unmeasured(f"{raw_name}: no reader for format {fmt!r}")
        root = str(root).strip().strip("/")
        if not root:
            fail_unmeasured(f"{raw_name}: an empty --scan-root cannot anchor a path")
        if not (repo_root / root).is_dir():
            fail_unmeasured(f"--scan-root {root} is not a directory under {repo_root}")

        n_here = 0
        emitted_here = 0
        for rec in READERS[fmt](doc):
            raw_in += 1
            n_here += 1
            why = rec.get("why")
            placed, reason = (None, why) if why else repo_relative(rec.get("path"), root, repo_root)
            if placed is None:
                unmapped.append({
                    "raw_file": raw_name,
                    "reported_path": rec.get("path"),
                    "line": rec.get("line"),
                    "title": str(rec.get("title") or "")[:120],
                    "why": reason,
                })
                continue
            line = rec.get("line")
            line = int(line) if isinstance(line, (int, float)) and not isinstance(line, bool) else None
            finding = {
                "id": f"EXT-{len(findings) + 1:03d}",
                "title": str(rec.get("title") or rec.get("rule") or "untitled external finding"),
                "procedure": "external",
                "status": args.status,
                "severity": rec.get("severity"),
                "location": {"path": placed, "line": line},
                "external": {
                    "tool": args.tool or rec.get("driver") or fmt,
                    "format": fmt,
                    "native_id": rec.get("native_id"),
                    "native_status": rec.get("native_status"),
                    "rule": rec.get("rule"),
                    "raw_file": raw_name,
                    "scan_root": root,
                },
            }
            second = rec.get("second")
            if second and second[0]:
                sec_path, sec_reason = repo_relative(second[0], root, repo_root)
                if sec_path:
                    second_locations += 1
                    finding["also_seen"] = {"path": sec_path, "line": second[1],
                                            "note": "the other end of the flow; recorded, NOT scored"}
                else:
                    # Not an unmapped FINDING - the finding itself was placed - but not
                    # silent either: a second location this adapter could not place is
                    # said out loud, in the artifact, where a reader can see it.
                    finding["also_seen"] = {"path": None, "reported": second[0],
                                            "note": f"not placed: {sec_reason}"}
            findings.append(finding)
            emitted_here += 1
        per_file.append({"raw_file": raw_name, "scan_root": root, "format": fmt,
                         "raw_in": n_here, "emitted": emitted_here})

    artifact = {
        "schema_version": 1,
        "engagement": {
            "kind": "external-tool-crosscheck",
            "tool": args.tool or "unnamed external tool",
            "status_recorded": args.status,
            "note": ("Adapted from a third-party tool's raw output by "
                     "scripts/bench/adapt-external.py. Locations only: this artifact "
                     "claims the tool pointed at these places, not that it was right."),
            "sources": per_file,
        },
        "findings": findings,
    }
    out = Path(args.out)
    if not out.is_absolute():
        out = repo_root / args.out
    try:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(artifact, indent=2) + "\n", encoding="utf-8")
    except OSError as exc:
        fail_unmeasured(f"cannot write {out}: {exc}")

    print(f"adapt-external: {len(raws)} raw file(s), tool {args.tool or '(unnamed)'}")
    for s in per_file:
        print(f"  {s['format']:<9} {s['raw_in']:>3} in  {s['emitted']:>3} out  "
              f"{s['scan_root']}  <- {s['raw_file']}")
    print(f"raw findings in = {raw_in}, emitted = {len(findings)}, unmapped = {len(unmapped)}")
    for u in unmapped:
        print(f"  ! unmapped {u['reported_path']!r}:{u['line']} from {u['raw_file']} - {u['why']}")
        if u["title"]:
            print(f"      {u['title']}")
    print(f"second flow locations recorded and NOT scored: {second_locations}")
    print(f"wrote {out}")

    if args.json:
        print(json.dumps({
            "raw_in": raw_in,
            "emitted": len(findings),
            "unmapped": len(unmapped),
            "unmapped_detail": unmapped,
            "second_locations": second_locations,
            "per_file": per_file,
        }, indent=2))

    if args.max_unmapped is not None and len(unmapped) > args.max_unmapped:
        print(f"\nFAIL {len(unmapped)} raw finding(s) could not be placed, over the declared "
              f"maximum {args.max_unmapped}. Each one is named above; a finding this adapter "
              "drops is a false positive the bench never charges and a hit it never credits.")
        return 1
    if args.max_unmapped is None:
        print("\nno --max-unmapped was passed: this run converted, it did not judge")
    return 0


if __name__ == "__main__":
    sys.exit(main())
