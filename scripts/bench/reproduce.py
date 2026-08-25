#!/usr/bin/env python3
"""Run the probes against the vulnerable cases and against every patch of them.

WHY THIS EXISTS
    A neighbouring product ships executable proofs-of-concept and four sandbox
    backends to run them in. This repository declared reproduction out of scope,
    and the cost was measured rather than imagined: in the third-competitor
    round an outside rubric docked a finding of ours for carrying no
    reproduction evidence, and the note of that round records that the deduction
    was our own restriction showing up on somebody else's scoreboard.

WHAT MAKES THIS DIFFERENT FROM COPYING THEIR SANDBOX
    This corpus carries TWO independent keys over the same files: `planted`, in
    `bench/ground-truth.json`, says where each defect is; and `patches`, in
    `bench/patch-truth.json`, says what each patch actually achieves - and those
    patches are deliberately imperfect, so several are declared `not fixed`.
    Running a probe across the patched variants therefore checks the patch key,
    while the patch key checks the probe. Neither is trusted alone, and a
    product with only one key cannot run this check at all.

    A case with no patches gets the first half only, and the run says so rather
    than implying a cross-check that did not happen.

THE CONTRACT IT ENFORCES
    1. On the unpatched case every probe must reproduce its defect. A probe that
       does not is either wrong or the planted key is; the run names BOTH
       candidates rather than deciding in favour of the key.
    2. Where the patch key says `not fixed`, the probe must STILL reproduce.
       That is the machine-checkable half, and the one a wrong probe trips.
    3. Where it says `partially verified`, no outcome is forced. The key states
       which aspect survives, in prose, and this harness records what happened
       without pretending the English implies a boolean.

WHAT IT DOES NOT DO
    Judge whether a patch is good, score a model, or reach anything outside the
    working tree. It runs fixture code this repository owns, offline, in a
    temporary directory it creates and removes.

Exit codes: 0 = measured and consistent | 1 = measured and inconsistent |
            2 = could not measure, which is never a pass. A definite finding
            outranks an unmeasured case: 1 is not a pass either, and hiding a
            known defect behind a 2 helps nobody.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import environments as envs  # noqa: E402  - a sibling, not a package

DEFAULT_ROOT = Path(os.environ.get("EHS_REPO_ROOT") or Path(__file__).resolve().parents[2])

UNMEASURED = 2
FAILED = 1
OK = 0


class Unmeasurable(Exception):
    """Raised when the harness cannot establish an answer either way."""


class Tree:
    """Where everything lives, relative to one root.

    The root is a parameter and not a constant so the gate can point this at a
    fixture tree: a harness that can only ever run against the real repository
    cannot be proved in the negative, and an unproved harness is one nobody has
    watched fail.
    """

    def __init__(self, root: Path) -> None:
        self.root = root
        self.reproduction = root / "bench" / "reproduction"
        self.planted = root / "bench" / "ground-truth.json"
        self.patch_truth = root / "bench" / "patch-truth.json"

    def cases(self) -> list[str]:
        """Every case directory here, in a stable order - key or no key.

        Listing only the directories that HAVE a key looked tidier and was
        wrong: a case whose key went missing then vanished from the run and the
        remaining ones signed a green between them. A directory that is here is
        a case, and a case that cannot be read is answered with 2. The battery
        found this by deleting one key of three and watching the run pass.
        """
        if not self.reproduction.is_dir():
            return []
        return sorted(
            d.name for d in self.reproduction.iterdir()
            if d.is_dir() and not d.name.startswith((".", "_"))
        )

    def probes(self, case: str) -> Path:
        return self.reproduction / case / "probes.py"

    def key(self, case: str) -> Path:
        return self.reproduction / case / "key.json"

    def patches(self, case: str) -> Path:
        return self.root / "bench" / "patches" / case


def load_probes(path: Path):
    spec = importlib.util.spec_from_file_location("ehs_probes", path)
    if spec is None or spec.loader is None:
        raise Unmeasurable(f"cannot load the probes at {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.PROBES


def variant(work: Path, diff: Path | None, label: str, source: Path) -> Path:
    """A private copy of one source file, optionally patched.

    The corpus is read and never written. The copy keeps the original file name
    because a patch names it, and because a probe may import it by name.
    """
    target = work / label
    target.mkdir(parents=True, exist_ok=True)
    copy = target / source.name
    shutil.copy2(source, copy)
    if diff is None:
        return copy
    if shutil.which("patch") is None:
        raise Unmeasurable("`patch` is not on PATH, so no patched variant can be built")
    done = subprocess.run(
        ["patch", "-p1", "-s", "-i", str(diff)],
        cwd=target, capture_output=True, text=True,
    )
    if done.returncode != 0:
        raise Unmeasurable(f"{diff.name} did not apply: {done.stdout.strip()} {done.stderr.strip()}")
    return copy


def run_probe(env, probes_path: Path, case_path: Path, defect: str, work: Path, tag: str) -> dict:
    """One probe, in the environment chosen for this run. Returns the observation."""
    room = work / "run" / tag
    room.mkdir(parents=True)
    return env.run(probes_path, case_path, defect, room).observation


def source_for(tree: Tree, case: str, key: dict, defect: str) -> Path:
    """Which file this probe runs against.

    A case may hold several. `cli-packer` keeps five defects in one file and
    declares `source` once; `analytics-service` spreads three across three, so
    each probe names its own. Per-probe wins where both are given.
    """
    row = key.get("probes", {}).get(defect, {})
    rel = row.get("source") or key.get("source")
    if not rel:
        raise Unmeasurable(f"{case}/{defect} names no source file")
    return tree.root / rel


def measure_case(tree: Tree, case: str, env, planted: dict, patch_truth: dict) -> dict:
    """Everything this run has to say about one case."""
    report = {
        "case": case,
        "base": {}, "patched": {},
        "findings": [], "notes": [],
        "unmeasured_variants": [], "rc": OK,
    }

    try:
        if not tree.key(case).exists():
            raise Unmeasurable(f"there is no key.json, so nothing says what {case} owes")
        key = json.loads(tree.key(case).read_text(encoding="utf-8"))
        probes = load_probes(tree.probes(case))
    except (Unmeasurable, OSError, ValueError) as exc:
        report["notes"].append(f"{case}: NOT MEASURED - {exc}")
        report["rc"] = UNMEASURED
        return report

    covered = set(key.get("probes", {}))
    if not covered:
        report["notes"].append(f"{case}: NOT MEASURED - the reproduction key lists no probes")
        report["rc"] = UNMEASURED
        return report
    missing = sorted(covered - set(probes))
    if missing:
        report["notes"].append(
            f"{case}: NOT MEASURED - the key names probes that do not exist: {', '.join(missing)}")
        report["rc"] = UNMEASURED
        return report

    minimum = key.get("minimum_isolation", "subprocess")
    if minimum not in envs.ORDER:
        report["notes"].append(
            f"{case}: NOT MEASURED - the key asks for an environment nobody offers: {minimum!r}")
        report["rc"] = UNMEASURED
        return report
    if not envs.at_least(env.name, minimum):
        report["notes"].append(
            f"{case}: NOT MEASURED - the probes would run under `{env.name}` and the key requires "
            f"at least `{minimum}`: a weaker sandbox than the one declared is not a pass")
        report["rc"] = UNMEASURED
        return report
    report["minimum_isolation"] = minimum

    ours = {p["id"] for p in planted.get("planted", []) if p.get("case") == case}
    patches = [p for p in patch_truth.get("patches", []) if p.get("case") == case]
    report["planted_here"] = len(ours)
    report["patches_here"] = len(patches)

    work = Path(tempfile.mkdtemp(prefix=f"ehs-reproduce-{case}-"))
    try:
        # ---- 1. the unpatched case: every probe must reproduce ---------------
        for defect in sorted(covered):
            try:
                base_path = variant(
                    work, None, f"base-{defect}", source_for(tree, case, key, defect))
            except (Unmeasurable, OSError) as exc:
                report["notes"].append(f"{case}/{defect}: NOT MEASURED - {exc}")
                report["base"][defect] = {
                    "reproduces": None, "evidence": "", "unmeasurable": str(exc)}
                continue
            obs = run_probe(env, tree.probes(case), base_path, defect, work, f"base-{defect}")
            report["base"][defect] = obs
            if obs["reproduces"] is None:
                report["notes"].append(
                    f"{case}/{defect} on the unpatched case: NOT MEASURED - {obs['unmeasurable']}")
            elif obs["reproduces"] is False:
                report["findings"].append(
                    f"{case}/{defect} did not reproduce on the unpatched case. Either the probe is "
                    f"wrong or the planted key is: {obs['evidence']}")

        # ---- 2. each patch, against the contract its key row states ----------
        for entry in patches:
            pid, fixes, expected = entry["id"], entry["claims_to_fix"], entry["expected"]
            if fixes not in covered:
                report["notes"].append(f"{pid} claims to fix {fixes}, which no probe covers")
                continue
            diff = tree.patches(case) / entry["diff"]
            try:
                patched_path = variant(work, diff, pid, source_for(tree, case, key, fixes))
            except (Unmeasurable, OSError) as exc:
                report["notes"].append(f"{pid}: NOT MEASURED - {exc}")
                report["unmeasured_variants"].append(pid)
                continue
            obs = run_probe(env, tree.probes(case), patched_path, fixes, work, f"{pid}-{fixes}")
            report["patched"][pid] = {"fixes": fixes, "expected": expected, **obs}

            if obs["reproduces"] is None:
                report["notes"].append(
                    f"{pid} against {fixes}: NOT MEASURED - {obs['unmeasurable']}")
                report["unmeasured_variants"].append(pid)
            elif expected == "not fixed" and obs["reproduces"] is False:
                report["findings"].append(
                    f"{pid} is declared `not fixed` for {fixes}, yet the probe stopped reproducing. "
                    f"Either the probe is too narrow or the patch key is wrong: {obs['evidence']}")
            elif expected == "verified" and obs["reproduces"] is True:
                report["findings"].append(
                    f"{pid} is declared `verified` for {fixes}, yet the probe still reproduces: "
                    f"{obs['evidence']}")
    finally:
        shutil.rmtree(work, ignore_errors=True)

    if report["findings"]:
        report["rc"] = FAILED
    elif (any(o["reproduces"] is None for o in report["base"].values())
          or report["unmeasured_variants"]):
        report["rc"] = UNMEASURED
    return report


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--json", action="store_true", help="emit the observations as JSON")
    ap.add_argument("--root", default=None, help="measure this tree instead of the repository")
    ap.add_argument("--case", default=None, help="measure one case instead of every case")
    ap.add_argument("--environment", default=None, choices=envs.ORDER,
                    help="force one environment instead of the strongest available")
    args = ap.parse_args(argv)

    tree = Tree(Path(args.root).resolve() if args.root else DEFAULT_ROOT)

    try:
        for required in (tree.planted, tree.patch_truth):
            if not required.exists():
                raise Unmeasurable(f"missing {required.relative_to(tree.root)}")
        planted = json.loads(tree.planted.read_text(encoding="utf-8"))
        patch_truth = json.loads(tree.patch_truth.read_text(encoding="utf-8"))
    except (Unmeasurable, OSError, ValueError) as exc:
        print(f"UNMEASURED {exc}")
        return UNMEASURED

    cases = tree.cases()
    if args.case:
        cases = [c for c in cases if c == args.case]
        if not cases:
            print(f"UNMEASURED no reproduction key for a case named {args.case!r}")
            return UNMEASURED
    if not cases:
        print("UNMEASURED no case under bench/reproduction/ carries a key")
        return UNMEASURED

    # ---- where the probes will run -----------------------------------------
    if args.environment:
        env = envs.REGISTRY[args.environment]()
        ok, why = env.available()
        if not ok:
            print(f"UNMEASURED the {env.name} environment does not run here: {why}")
            return UNMEASURED
        ruled_out: list[str] = []
    else:
        env, ruled_out = envs.strongest_available()

    reports = [measure_case(tree, case, env, planted, patch_truth) for case in cases]

    observations = {
        "environment": env.name,
        "environments_ruled_out": ruled_out,
        "cases": {r["case"]: r for r in reports},
    }

    # With --json the observations are the ONLY thing on stdout, so the output
    # can be piped into a parser; the prose still has to go somewhere, and a
    # summary silently dropped is worse than one on the wrong stream.
    out = sys.stderr if args.json else sys.stdout
    if args.json:
        print(json.dumps(observations, indent=2, sort_keys=True))

    for report in reports:
        for note in report["notes"]:
            print(f"  note: {note}", file=out)
        for line in report["findings"]:
            print(f"  FINDING: {line}", file=out)

    print(f"  environment: {env.name}", file=out)
    total_probes = sum(len(r["base"]) for r in reports)
    total_planted = sum(r.get("planted_here", 0) for r in reports)
    for report in reports:
        available = report.get("patches_here", 0)
        cross = (f"{len(report['patched'])} of {available} patched variant(s)" if available
                 else "no patch ships for this case, so only the unpatched half was measured")
        print(
            f"  {report['case']}: {len(report['base'])} of {report.get('planted_here', 0)} "
            f"planted defect(s); {cross}",
            file=out,
        )
    print(f"  total: {total_probes} probe(s) over {len(reports)} case(s), "
          f"{total_planted} planted defect(s) in those cases", file=out)

    if any(r["rc"] == FAILED for r in reports):
        return FAILED
    if any(r["rc"] == UNMEASURED for r in reports):
        print("  at least one case could not be measured: this is not a pass", file=out)
        return UNMEASURED
    return OK


if __name__ == "__main__":
    sys.exit(main())
