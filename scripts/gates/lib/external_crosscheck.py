#!/usr/bin/env python3
"""Core of gate-external-crosscheck.sh. See that file for what this is for.

    python3 scripts/gates/lib/external_crosscheck.py --root .

Exit: 0 measured and fine | 1 measured and fails | 2 could not measure.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

# An absolute path that belongs to ONE machine. `/tmp/report.csv` quoted out of a
# case file is not one of these and must not be: `bench/cases/cli-packer` plants a
# predictable-temporary-file defect, so a rule that hunted a bare `/tmp/` would go
# red on a faithful recording of a tool quoting that very line.
MACHINE_PATHS = [
    re.compile(r"/Users/[A-Za-z0-9._-]+"),
    re.compile(r"/home/[A-Za-z0-9._-]+"),
    re.compile(r"/private/(?:tmp|var)/"),
    re.compile(r"/var/folders/"),
    re.compile(r"[A-Za-z]:\\\\?Users\\\\?"),
]

SHA_RE = re.compile(r"^[0-9a-f]{40}$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

REQUIRED_PROVENANCE = [
    "tool", "repository", "pinned_commit", "version_as_the_tool_reports_it",
    "date", "runner", "install", "scan_roots", "arms", "raw_sha256",
]
REQUIRED_SCORECARD_ARM = [
    "command", "raw_findings_in", "emitted", "unmapped", "detected", "detected_ids",
    "missed", "decoys_reported", "decoy_ids", "unlabelled", "recall",
]


class Unmeasurable(Exception):
    pass


def read_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise Unmeasurable(f"cannot read {path}: {exc}") from exc
    except ValueError as exc:
        raise Unmeasurable(f"{path} is not JSON: {exc}") from exc


def count_raw(doc, name: str) -> int:
    """Count raw records WITHOUT the adapter.

    Deliberately independent, and deliberately dumb. The gate must not take the
    adapter's word for how many findings went in: an adapter that quietly drops
    one reports a smaller number at both ends and every derived check agrees with
    it. A shape this cannot count is UNMEASURABLE, never zero.
    """
    if isinstance(doc, list):
        return len(doc)
    if isinstance(doc, dict):
        if isinstance(doc.get("findings"), list):
            return len(doc["findings"])
        if isinstance(doc.get("runs"), list):
            n = 0
            for run in doc["runs"]:
                if not isinstance(run, dict):
                    raise Unmeasurable(f"{name}: a SARIF run is not an object")
                n += len(run.get("results") or [])
            return n
    raise Unmeasurable(f"{name}: this gate cannot count the records in that shape")


def tail_json(text: str, what: str = "the command"):
    """The last JSON object printed at column 0.

    The failure carries the output. A tool that crashed exits 1 with a traceback
    and no JSON, and reporting only "no JSON object" names the symptom while
    hiding the cause - two different failures arriving as the same sentence is
    how a crash gets filed as a measured result.
    """
    offset = 0
    starts = []
    for line in text.splitlines(keepends=True):
        if line.rstrip("\n") == "{":
            starts.append(offset)
        offset += len(line)
    for i in reversed(starts):
        try:
            return json.JSONDecoder().raw_decode(text[i:])[0]
        except ValueError:
            continue
    raise Unmeasurable(f"{what} printed no JSON object at column 0; its output was:\n{text[-1200:]}")


def run(cmd, root: Path):
    # `capture_output` + an explicit returncode. Never `cmd > log` with the code
    # read afterwards, and never a pipe into head: under `set -e` the first dies
    # mute and the second reports the rc of the pipe.
    proc = subprocess.run([str(c) for c in cmd], cwd=str(root), capture_output=True, text=True)
    return proc.returncode, proc.stdout + proc.stderr


def probe_adapter(root: Path, adapter: Path, findings: list, checks: list) -> None:
    """The instrument must be able to say ONE, and must refuse to say ZERO blind.

    Both halves run on every gate run, not only in the battery. A gate that pins
    a number produced by an adapter is worth exactly what the adapter is worth,
    and an adapter that answered 0 to everything would keep this gate green for
    ever while measuring nothing.
    """
    case = "bench/cases/express-invoices"
    target = "routes/invoices.js"
    if not (root / case / target).is_file():
        raise Unmeasurable(f"{case}/{target} is missing: the reachability probe has nothing to point at")

    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        # (1) POSITIVE: a SARIF document it must read, and emit exactly one finding for.
        sarif = {
            "version": "2.1.0",
            "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
            "runs": [{"tool": {"driver": {"name": "probe"}}, "results": [{
                "ruleId": "probe.rule",
                "message": {"text": "reachability probe"},
                "locations": [{"physicalLocation": {
                    "artifactLocation": {"uri": target},
                    "region": {"startLine": 8}}}]}]}],
        }
        (tmp / "probe.sarif").write_text(json.dumps(sarif), encoding="utf-8")
        checks.append("adapter reachability probe (SARIF in, one finding out)")
        rc, out = run(["python3", str(adapter), "--format", "sarif", "--raw", str(tmp / "probe.sarif"),
                       "--scan-root", case, "--out", str(tmp / "probe-out.json"),
                       "--max-unmapped", "0", "--json"], root)
        if rc != 0:
            findings.append(
                f"the adapter answered {rc} to a well-formed SARIF document naming a file that "
                f"exists ({case}/{target}). Output:\n{out[-800:]}")
        else:
            counts = tail_json(out, "the adapter reachability probe")
            if counts.get("emitted") != 1 or counts.get("raw_in") != 1:
                findings.append(
                    f"the adapter read a one-result SARIF document as raw_in={counts.get('raw_in')}, "
                    f"emitted={counts.get('emitted')}: an instrument nobody has seen produce a ONE "
                    "cannot be trusted when it produces a zero")

        # (2) NEGATIVE: a shape it has never seen. The answer must be 2, never 0.
        (tmp / "unknown.json").write_text(json.dumps({"totally": "unknown", "shape": [1, 2]}), encoding="utf-8")
        checks.append("adapter blindness guard (unrecognised object refused with 2)")
        rc, out = run(["python3", str(adapter), "--format", "auto", "--raw", str(tmp / "unknown.json"),
                       "--scan-root", case, "--out", str(tmp / "unknown-out.json")], root)
        if rc != 2:
            findings.append(
                f"the adapter answered {rc} to a format it does not recognise; the contract is 2. "
                "A zero from an instrument that did not understand its input is not a measurement.")

        # (2b) A finding whose path is not in this checkout must be COUNTED and
        # NAMED, never dropped. A dropped finding is a false positive the bench
        # never charges and a hit it never credits, and it leaves no trace in
        # any number - which is why the probe reads the text as well as the
        # counts: an adapter that stopped printing the name would still be
        # arithmetically consistent with itself.
        ghost = dict(sarif)
        ghost["runs"] = [{"tool": {"driver": {"name": "probe"}}, "results": [{
            "ruleId": "probe.ghost",
            "message": {"text": "points at a file this checkout does not have"},
            "locations": [{"physicalLocation": {
                "artifactLocation": {"uri": "routes/no-such-file-here.js"},
                "region": {"startLine": 3}}}]}]}]
        (tmp / "ghost.sarif").write_text(json.dumps(ghost), encoding="utf-8")
        checks.append("adapter names an unplaceable finding instead of dropping it")
        rc, out = run(["python3", str(adapter), "--format", "sarif", "--raw", str(tmp / "ghost.sarif"),
                       "--scan-root", case, "--out", str(tmp / "ghost-out.json"),
                       "--max-unmapped", "0", "--json"], root)
        if rc == 2:
            findings.append(f"the adapter answered 2 to a well-formed SARIF document whose only "
                            f"fault is an unresolvable path. Output:\n{out[-800:]}")
        else:
            counts = tail_json(out, "the adapter unplaceable-path probe")
            if (counts.get("raw_in"), counts.get("emitted"), counts.get("unmapped")) != (1, 0, 1):
                findings.append(
                    f"the adapter read one unplaceable SARIF result as raw_in={counts.get('raw_in')}, "
                    f"emitted={counts.get('emitted')}, unmapped={counts.get('unmapped')}. The "
                    "contract is 1/0/1: a finding it cannot place is still a finding it was given")
            if "routes/no-such-file-here.js" not in out:
                findings.append(
                    "the adapter did not name the finding it could not place. A silent drop is the "
                    "one failure that leaves no trace in any number this gate pins")
            if rc != 1:
                findings.append(
                    f"the adapter answered {rc} with one unplaceable finding and --max-unmapped 0; "
                    "the contract is 1. A cap nobody enforces is not a cap")

        # (3) NEGATIVE: the empty array, which is the shape a clean zero hides in.
        (tmp / "empty.json").write_text("[]", encoding="utf-8")
        checks.append("adapter blindness guard (bare empty array refused with 2 under --format auto)")
        rc, out = run(["python3", str(adapter), "--format", "auto", "--raw", str(tmp / "empty.json"),
                       "--scan-root", case, "--out", str(tmp / "empty-out.json")], root)
        if rc != 2:
            findings.append(
                f"the adapter answered {rc} to a bare `[]` under --format auto; the contract is 2. "
                "An empty array names no tool, and attributing its zero to a tool nobody named is "
                "the flattering number this whole directory exists to prevent.")


def check_one(root: Path, d: Path, adapter: Path, scorer: Path, findings: list, checks: list) -> None:
    rel = d.relative_to(root).as_posix()
    prov_path, score_path = d / "provenance.json", d / "scorecard.json"
    for p in (prov_path, score_path):
        checks.append(f"{rel}: {p.name} exists")
        if not p.is_file():
            findings.append(f"{rel} records an external run and has no {p.name}: a number nobody "
                            "can trace to a tool, a commit and a command is not evidence")
            return
    prov = read_json(prov_path)
    card = read_json(score_path)

    # --- provenance completeness -------------------------------------------
    for field in REQUIRED_PROVENANCE:
        checks.append(f"{rel}: provenance declares {field}")
        if field not in prov or prov[field] in (None, "", [], {}):
            findings.append(f"{rel}/provenance.json is missing `{field}`")
    if isinstance(prov.get("pinned_commit"), str):
        checks.append(f"{rel}: pinned_commit is a full commit sha")
        if not SHA_RE.match(prov["pinned_commit"]):
            findings.append(f"{rel}: pinned_commit {prov['pinned_commit']!r} is not a 40-hex sha. A tag "
                            "or a branch is a pointer that moves, and a moved pointer un-pins the run")
    if isinstance(prov.get("date"), str):
        checks.append(f"{rel}: date is YYYY-MM-DD and matches the directory name")
        if not DATE_RE.match(prov["date"]):
            findings.append(f"{rel}: date {prov['date']!r} is not YYYY-MM-DD")
        elif d.name != f"{prov.get('tool')}-{prov['date']}":
            findings.append(f"{rel}: the directory is named {d.name} and provenance says "
                            f"{prov.get('tool')}-{prov['date']}")
    runner = prov.get("runner")
    checks.append(f"{rel}: provenance names the runner OS")
    if not isinstance(runner, dict) or not runner.get("os"):
        findings.append(f"{rel}: provenance does not name the OS the run happened on")

    # Kept, because the arm loop below needs it: a root that has moved is a
    # MEASURED defect of the record, and must not be handed to the adapter,
    # which would refuse it and turn a finding this gate already has into
    # "could not measure". A plain directory rename is the commonest way this
    # record goes stale and it is the one a gate must not answer with a 2.
    absent_roots = []
    for sr in prov.get("scan_roots") or []:
        checks.append(f"{rel}: scan root {sr} exists")
        if not (root / sr).is_dir():
            absent_roots.append(sr)
            findings.append(f"{rel}: scan root {sr} is not a directory in this checkout")

    # --- no machine path anywhere in the recorded directory ------------------
    for f in sorted(p for p in d.rglob("*") if p.is_file()):
        checks.append(f"{rel}: {f.relative_to(d).as_posix()} carries no machine path")
        try:
            body = f.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        for pat in MACHINE_PATHS:
            m = pat.search(body)
            if m:
                findings.append(
                    f"{rel}/{f.relative_to(d).as_posix()} contains {m.group(0)!r}: an absolute path "
                    "of the machine that produced it. Nobody else can follow it, and it says who ran it")
                break

    # --- checksums: the bytes are still the ones the tool emitted ------------
    sums = prov.get("raw_sha256")
    checks.append(f"{rel}: provenance carries a checksum per raw file")
    if not isinstance(sums, dict) or not sums:
        findings.append(f"{rel}: provenance carries no raw_sha256 map")
        sums = {}
    on_disk = sorted(p.relative_to(d).as_posix() for p in d.rglob("raw/*/*.json"))
    checks.append(f"{rel}: the raw files on disk are exactly the ones provenance lists")
    if sorted(sums) != on_disk:
        missing = sorted(set(sums) - set(on_disk))
        extra = sorted(set(on_disk) - set(sums))
        findings.append(f"{rel}: raw files listed but absent {missing or 'none'}; present but "
                        f"unlisted {extra or 'none'}")
    for name, want in sorted(sums.items()):
        f = d / name
        checks.append(f"{rel}: {name} matches its recorded checksum")
        if not f.is_file():
            continue
        got = hashlib.sha256(f.read_bytes()).hexdigest()
        if got != want:
            findings.append(f"{rel}/{name} has changed since it was recorded "
                            f"(sha256 {got[:12]}, recorded {want[:12]})")

    # --- the arms agree between the two records ------------------------------
    p_arms = prov.get("arms") if isinstance(prov.get("arms"), dict) else {}
    c_arms = card.get("arms") if isinstance(card.get("arms"), dict) else {}
    checks.append(f"{rel}: provenance and scorecard describe the same arms")
    if sorted(p_arms) != sorted(c_arms):
        findings.append(f"{rel}: provenance describes arms {sorted(p_arms)} and the scorecard "
                        f"{sorted(c_arms)}")

    fmt = ((card.get("adapter_arguments") or {}).get("format")) or "auto"
    status = ((card.get("adapter_arguments") or {}).get("status")) or "probable"
    max_unmapped = (card.get("adapter_arguments") or {}).get("max_unmapped")
    tool = prov.get("tool") or ""
    roots = list(prov.get("scan_roots") or [])

    # The denominators of the published recall, checked once and before the arms:
    # they depend on the key and the scorecard alone, and they must still be
    # reported when the arms cannot be re-run.
    gt = read_json(root / (card.get("key") or "bench/ground-truth.json"))
    planted = card.get("planted_total")
    checks.append(f"{rel}: planted_total matches the answer key")
    if planted != len(gt.get("planted") or []):
        findings.append(f"{rel}: the scorecard says {planted} planted defects and the key has "
                        f"{len(gt.get('planted') or [])}: the denominator of a published recall moved")
    checks.append(f"{rel}: decoys_total matches the answer key")
    if card.get("decoys_total") != len(gt.get("decoys") or []):
        findings.append(f"{rel}: the scorecard says {card.get('decoys_total')} decoys and the key "
                        f"has {len(gt.get('decoys') or [])}")

    if absent_roots:
        # The finding is already recorded above, with the root that moved named
        # in it. Re-running the arms would only hand the adapter a root it is
        # right to refuse, and its 2 would overwrite a verdict this gate has
        # already measured. 1 is the honest answer here, not 2.
        checks.append(f"{rel}: arms re-run (skipped: {len(absent_roots)} scan root(s) have moved)")
        return

    for arm in sorted(c_arms):
        info = c_arms[arm] if isinstance(c_arms[arm], dict) else {}
        for field in REQUIRED_SCORECARD_ARM:
            checks.append(f"{rel}[{arm}]: scorecard records {field}")
            if field not in info:
                findings.append(f"{rel}: arm {arm} does not record `{field}`")
        if any(f not in info for f in REQUIRED_SCORECARD_ARM):
            continue

        raws, missing = [], []
        independent = 0
        for sr in roots:
            case = Path(sr).name
            f = d / "raw" / arm / f"{case}.findings.json"
            if not f.is_file():
                missing.append(f.relative_to(d).as_posix())
                continue
            raws.append((f, sr))
            independent += count_raw(read_json(f), f.relative_to(d).as_posix())
        checks.append(f"{rel}[{arm}]: one raw file per scan root")
        if missing:
            findings.append(f"{rel}: arm {arm} is missing raw output for {missing}")
            continue

        checks.append(f"{rel}[{arm}]: the gate's own count of raw records equals the recorded one")
        if independent != info["raw_findings_in"]:
            findings.append(
                f"{rel}: arm {arm} records raw_findings_in={info['raw_findings_in']} and this gate "
                f"counts {independent} in the raw files themselves. The gate counts them WITHOUT "
                "the adapter on purpose: an adapter that drops a finding quietly reports a smaller "
                "number at both ends and every derived check agrees with it")

        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / f"adapted-{arm}.json"
            cmd = ["python3", str(adapter), "--format", fmt, "--tool", tool, "--status", status]
            for f, sr in raws:
                cmd += ["--raw", str(f), "--scan-root", sr]
            cmd += ["--out", str(out), "--json"]
            if isinstance(max_unmapped, int):
                cmd += ["--max-unmapped", str(max_unmapped)]
            rc, text = run(cmd, root)
            checks.append(f"{rel}[{arm}]: the committed raw output still adapts")
            if rc == 2:
                raise Unmeasurable(f"{rel}: the adapter could not read arm {arm}:\n{text[-1200:]}")
            counts = tail_json(text, f"the adapter on arm {arm} of {rel}")
            if rc == 1:
                findings.append(f"{rel}: arm {arm} now leaves {counts.get('unmapped')} raw finding(s) "
                                f"unplaced, over the declared maximum {max_unmapped}")
            for key in ("raw_findings_in", "emitted", "unmapped"):
                got = counts.get({"raw_findings_in": "raw_in"}.get(key, key))
                checks.append(f"{rel}[{arm}]: {key} still {info[key]}")
                if got != info[key]:
                    findings.append(f"{rel}: arm {arm} recorded {key}={info[key]}, the adapter now "
                                    f"reports {got}")

            rc, text = run(["python3", str(scorer), "--findings", str(out), "--json"], root)
            checks.append(f"{rel}[{arm}]: the adapted artifact still scores")
            if rc == 2:
                raise Unmeasurable(f"{rel}: the scorer could not read arm {arm}:\n{text[-1200:]}")
            sc = tail_json(text, f"the scorer on arm {arm} of {rel}")

        got = {
            "detected": len(sc.get("detected") or []),
            "detected_ids": sorted(sc.get("detected") or []),
            "missed": len(sc.get("missed") or []),
            "decoys_reported": len(sc.get("decoys_reported") or []),
            "decoy_ids": sorted(sc.get("decoys_reported") or []),
            "unlabelled": sc.get("unlabelled"),
            "recall": round(float(sc.get("recall") or 0.0), 6),
        }
        want = {
            "detected": info["detected"],
            "detected_ids": sorted(info["detected_ids"]),
            "missed": info["missed"],
            "decoys_reported": info["decoys_reported"],
            "decoy_ids": sorted(info["decoy_ids"]),
            "unlabelled": info["unlabelled"],
            "recall": round(float(info["recall"]), 6),
        }
        for key in want:
            shown = f"{len(want[key])} id(s)" if key.endswith("_ids") else want[key]
            checks.append(f"{rel}[{arm}]: {key} still {shown}")
            if got[key] != want[key]:
                findings.append(
                    f"{rel}: arm {arm} recorded {key}={want[key]!r} and re-scoring gives {got[key]!r}. "
                    "Either the answer key moved, the adapter changed, or the raw output did: all "
                    "three change what the published number means")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    args = ap.parse_args()
    root = Path(args.root).resolve()

    adapter = root / "scripts" / "bench" / "adapt-external.py"
    scorer = root / "scripts" / "bench" / "score.py"
    base = root / "bench" / "external"

    findings: list[str] = []
    checks: list[str] = []
    try:
        for p in (adapter, scorer):
            if not p.is_file():
                raise Unmeasurable(f"{p.relative_to(root)} is missing: there is nothing to re-run")
        if not base.is_dir():
            raise Unmeasurable("bench/external does not exist")
        dirs = sorted(p for p in base.iterdir() if p.is_dir())
        if not dirs:
            raise Unmeasurable(
                "bench/external holds no recorded external-tool run. This gate pins the numbers a "
                "third-party tool scored against the answer key; with nothing recorded it measures "
                "nothing, and a green here would say the opposite")
        probe_adapter(root, adapter, findings, checks)
        for d in dirs:
            check_one(root, d, adapter, scorer, findings, checks)
    except Unmeasurable as exc:
        print(f"UNMEASURED {exc}")
        return 2

    print(f"checks: {len(checks)}")
    print(f"recorded external runs: {len(dirs)} ({', '.join(p.name for p in dirs)})")
    if findings:
        for f in findings:
            print(f"FINDING {f}")
        print(f"\n{len(findings)} finding(s) over {len(checks)} check(s)")
        return 1
    print(f"no findings over {len(checks)} check(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
