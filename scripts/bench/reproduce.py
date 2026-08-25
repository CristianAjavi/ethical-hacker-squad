#!/usr/bin/env python3
"""Run the probes against the vulnerable case and against every patch of it.

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
    `bench/patch-truth.json`, says what each patch actually achieves - and the
    patches here are deliberately imperfect, so several are declared `not
    fixed`. Running a probe across the patched variants therefore checks the
    patch key, while the patch key checks the probe. Neither is trusted alone,
    and a product with only one key cannot run this check at all.

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
            2 = could not measure, which is never a pass.
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
CASE = "cli-packer"


class Tree:
    """Where everything lives, relative to one root.

    The root is a parameter and not a constant so the gate can point this at a
    fixture tree: a harness that can only ever run against the real repository
    cannot be proved in the negative, and an unproved harness is one nobody has
    watched fail.
    """

    def __init__(self, root: Path) -> None:
        self.root = root
        self.source = root / "bench" / "cases" / CASE / "packer.py"
        self.patches = root / "bench" / "patches" / CASE
        self.probes = root / "bench" / "reproduction" / CASE / "probes.py"
        self.key = root / "bench" / "reproduction" / CASE / "key.json"
        self.planted = root / "bench" / "ground-truth.json"
        self.patch_truth = root / "bench" / "patch-truth.json"

    def all(self):
        return (self.source, self.patches, self.probes, self.key, self.planted, self.patch_truth)

UNMEASURED = 2
FAILED = 1
OK = 0


class Unmeasurable(Exception):
    """Raised when the harness cannot establish an answer either way."""


def load_probes(PROBES: Path):
    spec = importlib.util.spec_from_file_location("ehs_probes", PROBES)
    if spec is None or spec.loader is None:
        raise Unmeasurable(f"cannot load the probes at {PROBES}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.PROBES


def load_case(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise Unmeasurable(f"cannot load the case at {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def variant(work: Path, diff: Path | None, label: str, SOURCE: Path) -> Path:
    """A private copy of the case, optionally patched. The corpus is never touched."""
    target = work / label
    target.mkdir(parents=True)
    copy = target / "packer.py"
    shutil.copy2(SOURCE, copy)
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


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--json", action="store_true", help="emit the observations as JSON")
    ap.add_argument("--root", default=None, help="measure this tree instead of the repository")
    ap.add_argument("--environment", default=None, choices=envs.ORDER,
                    help="force one environment instead of the strongest available")
    args = ap.parse_args(argv)

    tree = Tree(Path(args.root).resolve() if args.root else DEFAULT_ROOT)
    PATCHES, KEY = tree.patches, tree.key

    try:
        for required in tree.all():
            if not required.exists():
                raise Unmeasurable(f"missing {required.relative_to(tree.root)}")
        probes = load_probes(tree.probes)
        key = json.loads(tree.key.read_text(encoding="utf-8"))
        planted = json.loads(tree.planted.read_text(encoding="utf-8"))
        patch_truth = json.loads(tree.patch_truth.read_text(encoding="utf-8"))
    except (Unmeasurable, OSError, ValueError) as exc:
        print(f"UNMEASURED {exc}")
        return UNMEASURED

    ours = {p["id"] for p in planted.get("planted", []) if p.get("case") == CASE}
    covered = set(key.get("probes", {}))
    if not covered:
        print("UNMEASURED the reproduction key lists no probes")
        return UNMEASURED
    missing_probe = sorted(covered - set(probes))
    if missing_probe:
        print(f"UNMEASURED the key names probes that do not exist: {', '.join(missing_probe)}")
        return UNMEASURED

    # ---- where the probes will run, and whether that is strong enough -------
    if args.environment:
        env = envs.REGISTRY[args.environment]()
        ok, why = env.available()
        if not ok:
            print(f"UNMEASURED the {env.name} environment does not run here: {why}")
            return UNMEASURED
        ruled_out = []
    else:
        env, ruled_out = envs.strongest_available()

    minimum = key.get("minimum_isolation", "subprocess")
    if minimum not in envs.ORDER:
        print(f"UNMEASURED the key asks for an environment nobody offers: {minimum!r}")
        return UNMEASURED
    if not envs.at_least(env.name, minimum):
        print(
            f"UNMEASURED the probes would run under `{env.name}` and the key requires at least "
            f"`{minimum}`: a weaker sandbox than the one declared is not a pass"
            + (f" ({'; '.join(ruled_out)})" if ruled_out else "")
        )
        return UNMEASURED

    patches = [p for p in patch_truth.get("patches", []) if p.get("case") == CASE]
    findings: list[str] = []
    notes: list[str] = []
    # A variant that could not be built, or a probe that could not answer on
    # one, is a measurement that did not happen. Recording it as a note and
    # signing a 0 anyway is exactly the failure this project's exit-code rule
    # exists to prevent, and this harness shipped it until its own battery
    # replaced a patch with a line of prose and watched the run come back green.
    unmeasured_variants: list[str] = []
    observations: dict = {
        "case": CASE,
        "environment": env.name,
        "minimum_isolation": minimum,
        "environments_ruled_out": ruled_out,
        "base": {},
        "patched": {},
    }

    work = Path(tempfile.mkdtemp(prefix="ehs-reproduce-"))
    try:
        # ---- 1. the unpatched case: every probe must reproduce ---------------
        try:
            base_path = variant(work, None, "base", tree.source)
        except Unmeasurable as exc:
            print(f"UNMEASURED {exc}")
            return UNMEASURED

        for defect in sorted(covered):
            obs = run_probe(env, tree.probes, base_path, defect, work, f"base-{defect}")
            observations["base"][defect] = obs
            if obs["reproduces"] is None:
                notes.append(f"{defect} on the unpatched case: NOT MEASURED - {obs['unmeasurable']}")
            elif obs["reproduces"] is False:
                findings.append(
                    f"{defect} did not reproduce on the unpatched case. Either the probe is wrong "
                    f"or the planted key is: {obs['evidence']}"
                )

        # ---- 2. each patch, against the contract its key row states ----------
        for entry in patches:
            pid, fixes, expected = entry["id"], entry["claims_to_fix"], entry["expected"]
            if fixes not in covered:
                notes.append(f"{pid} claims to fix {fixes}, which no probe covers")
                continue
            diff = PATCHES / entry["diff"]
            try:
                patched_path = variant(work, diff, pid, tree.source)
            except Unmeasurable as exc:
                notes.append(f"{pid}: NOT MEASURED - {exc}")
                unmeasured_variants.append(pid)
                continue
            obs = run_probe(env, tree.probes, patched_path, fixes, work, f"{pid}-{fixes}")
            observations["patched"][pid] = {"fixes": fixes, "expected": expected, **obs}

            if obs["reproduces"] is None:
                notes.append(f"{pid} against {fixes}: NOT MEASURED - {obs['unmeasurable']}")
                unmeasured_variants.append(pid)
            elif expected == "not fixed" and obs["reproduces"] is False:
                findings.append(
                    f"{pid} is declared `not fixed` for {fixes}, yet the probe stopped reproducing. "
                    f"Either the probe is too narrow or the patch key is wrong: {obs['evidence']}"
                )
            elif expected == "verified" and obs["reproduces"] is True:
                findings.append(
                    f"{pid} is declared `verified` for {fixes}, yet the probe still reproduces: "
                    f"{obs['evidence']}"
                )
    finally:
        shutil.rmtree(work, ignore_errors=True)

    # With --json the observations are the ONLY thing on stdout, so the output
    # can be piped into a parser; the prose still has to go somewhere, and a
    # summary silently dropped is worse than one on the wrong stream.
    out = sys.stderr if args.json else sys.stdout
    if args.json:
        print(json.dumps(observations, indent=2, sort_keys=True))

    for note in notes:
        print(f"  note: {note}", file=out)
    for line in findings:
        print(f"  FINDING: {line}", file=out)

    print(f"  environment: {env.name} (the key requires at least `{minimum}`)", file=out)
    unmeasured = [d for d, o in observations["base"].items() if o["reproduces"] is None]
    print(
        f"  probes {len(covered)} of {len(ours)} planted defect(s) in {CASE}; "
        f"patched variants {len(observations['patched'])} of {len(patches)}",
        file=out,
    )
    if unmeasured:
        print(f"  {len(unmeasured)} probe(s) could not measure on the unpatched case", file=out)
        return UNMEASURED
    if unmeasured_variants:
        print(
            f"  {len(unmeasured_variants)} patched variant(s) could not be measured "
            f"({', '.join(sorted(set(unmeasured_variants)))}): this is not a pass",
            file=out,
        )
        return UNMEASURED
    if findings:
        return FAILED
    return OK


if __name__ == "__main__":
    sys.exit(main())
