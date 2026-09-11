#!/usr/bin/env python3
"""The measurement behind gate-deferral-lane.sh.

Reads a repository tree and answers, for every control that tree declares it is
NOT running here, whether some workflow in .github/workflows/** actually runs
it. Prints a human report and exits with the repository's gate contract:
0 = measured, no findings · 1 = measured, FAILS · 2 = could not measure.

Everything it reads is a file in the tree. No git, no network, no YAML parser:
a workflow is read as lines, because the question is "does any live line name
this control", and lines are what a person edits.
"""

from __future__ import annotations

import fnmatch
import json
import os
import re
import sys
from pathlib import Path

OK, FAIL, UNMEASURABLE = 0, 1, 2

# --only / --skip with the argument quoted, double-quoted, or bare.
ARG_RE = re.compile(r"--(skip|only)[= ]+(?:'([^']*)'|\"([^\"]*)\"|(\S+))")
# PR_SCOPED='gate-a.sh gate-b.sh'   — the runner's deferral lists.
SCOPED_RE = re.compile(r"^([A-Z][A-Z0-9_]*_SCOPED)='([^']*)'", re.M)


def arg_of(match: re.Match) -> str:
    return match.group(2) or match.group(3) or match.group(4) or ""


class Report:
    def __init__(self) -> None:
        self.failures: list[str] = []
        self.unmeasured: list[str] = []
        self.lines: list[str] = []

    def say(self, text: str) -> None:
        self.lines.append(text)

    def fail(self, text: str) -> None:
        self.failures.append(text)

    def unmeasurable(self, text: str) -> None:
        self.unmeasured.append(text)


def read_text(path: Path, rep: Report, what: str) -> str | None:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        rep.unmeasurable(f"{what} is there and cannot be read: {exc}")
        return None


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("COULD NOT MEASURE: expected exactly one argument, the repository root")
        return UNMEASURABLE

    root = Path(argv[1])
    rep = Report()

    gates_dir = root / "scripts" / "gates"
    runner = gates_dir / "run-all.sh"
    slow_file = gates_dir / "data" / "slow-scoped.txt"
    lanes_file = gates_dir / "data" / "deferred-lanes.json"
    wf_dir = root / ".github" / "workflows"

    # ---------------------------------------------------------------- controls
    if not gates_dir.is_dir():
        print(f"COULD NOT MEASURE: there is no {gates_dir}")
        return UNMEASURABLE
    controls = sorted(
        p.name
        for p in gates_dir.iterdir()
        if p.is_file() and p.name.startswith("gate-") and p.name.endswith(".sh")
    )
    if not controls:
        print(f"COULD NOT MEASURE: no gate-*.sh under {gates_dir}")
        return UNMEASURABLE

    # ------------------------------------------------------ declared deferrals
    # name -> list of places that declare it deferred
    declared: dict[str, list[str]] = {}

    if not runner.is_file():
        print(f"COULD NOT MEASURE: the runner {runner} is not there, so nothing says what is deferred")
        return UNMEASURABLE
    src = read_text(runner, rep, "the runner")
    if src is None:
        print("COULD NOT MEASURE: " + "; ".join(rep.unmeasured))
        return UNMEASURABLE

    scoped = SCOPED_RE.findall(src)
    if "NOT RUN HERE" in src and not scoped:
        print(
            "COULD NOT MEASURE: run-all.sh still reports 'NOT RUN HERE', so it defers "
            "controls, but no *_SCOPED='...' list parses out of it. The declaration "
            "shape changed and this gate would report an empty deferral set - which "
            "would read exactly like nothing being deferred."
        )
        return UNMEASURABLE
    for var, names in scoped:
        for name in names.split():
            declared.setdefault(name, []).append(f"run-all.sh {var}")

    if slow_file.exists():
        if not os.access(slow_file, os.R_OK):
            print(
                f"COULD NOT MEASURE: {slow_file.name} is there and cannot be read, so "
                "there is no telling which controls it defers"
            )
            return UNMEASURABLE
        text = read_text(slow_file, rep, slow_file.name)
        if text is None:
            print("COULD NOT MEASURE: " + "; ".join(rep.unmeasured))
            return UNMEASURABLE
        for raw in text.splitlines():
            name = raw.split("#", 1)[0].strip()
            if name:
                declared.setdefault(name, []).append(slow_file.name)

    # ------------------------------------------------------------- workflows
    if not wf_dir.is_dir():
        print(
            f"COULD NOT MEASURE: there is no {wf_dir}, so there is nowhere for a "
            "deferred control to run and no way to tell a missing lane from a "
            "missing checkout"
        )
        return UNMEASURABLE
    wf_files = sorted(
        p for p in wf_dir.iterdir() if p.is_file() and p.suffix in (".yml", ".yaml")
    )
    if not wf_files:
        print(f"COULD NOT MEASURE: no workflow files under {wf_dir}")
        return UNMEASURABLE

    # (file, lineno, text) for every line that is not a full-line comment
    live: list[tuple[str, int, str]] = []
    for path in wf_files:
        text = read_text(path, rep, path.name)
        if text is None:
            print("COULD NOT MEASURE: " + "; ".join(rep.unmeasured))
            return UNMEASURABLE
        for number, line in enumerate(text.splitlines(), 1):
            if line.lstrip().startswith("#"):
                continue
            live.append((path.name, number, line))

    # -------------------------------------------- patterns used in the workflows
    skips: list[tuple[str, int, str]] = []
    onlys: list[tuple[str, int, str]] = []
    for name, number, line in live:
        for match in ARG_RE.finditer(line):
            pattern = arg_of(match)
            (skips if match.group(1) == "skip" else onlys).append((name, number, pattern))

    def expand(pattern: str) -> list[str]:
        return [c for c in controls if fnmatch.fnmatch(c, pattern)]

    # QUESTION 2 — every pattern resolves to a control that exists
    for kind, uses in (("skip", skips), ("only", onlys)):
        for name, number, pattern in uses:
            if not pattern:
                rep.fail(f"{name}:{number} has a --{kind} with no argument")
            elif not expand(pattern):
                rep.fail(
                    f"{name}:{number} --{kind} '{pattern}' matches no control in "
                    f"scripts/gates/: the lane runs nothing and reads like one that works"
                )

    # a --skip is itself a declaration that the control does not run there
    for name, number, pattern in skips:
        for control in expand(pattern):
            declared.setdefault(control, []).append(f"{name}:{number} --skip")

    # ------------------------------------------------------------- exemptions
    exempt: dict[str, dict] = {}
    if lanes_file.is_file():
        raw = read_text(lanes_file, rep, lanes_file.name)
        if raw is None:
            print("COULD NOT MEASURE: " + "; ".join(rep.unmeasured))
            return UNMEASURABLE
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as exc:
            print(f"COULD NOT MEASURE: {lanes_file.name} does not parse: {exc}")
            return UNMEASURABLE
        if not isinstance(data, dict) or not isinstance(data.get("no_ci_lane", {}), dict):
            print(
                f"COULD NOT MEASURE: {lanes_file.name} does not have the expected shape "
                "(an object with a 'no_ci_lane' object)"
            )
            return UNMEASURABLE
        exempt = data.get("no_ci_lane", {})

    # ------------------------------------------------------- QUESTION 1: lanes
    def lanes_for(control: str) -> list[str]:
        found: list[str] = []
        for name, number, line in live:
            named = control in line
            matched_only = False
            skipped_here = False
            for match in ARG_RE.finditer(line):
                pattern = arg_of(match)
                if not pattern:
                    continue
                if fnmatch.fnmatch(control, pattern):
                    if match.group(1) == "only":
                        matched_only = True
                    else:
                        skipped_here = True
            if skipped_here:
                continue  # a --skip is never a lane
            if named or matched_only:
                found.append(f"{name}:{number}")
        return found

    lane_of: dict[str, list[str]] = {}
    for control in sorted(declared):
        lane_of[control] = lanes_for(control)

    rep.say(f"{len(controls)} control file(s) in scripts/gates/ · {len(wf_files)} workflow file(s)")
    rep.say("")

    for control in sorted(declared):
        where = "; ".join(sorted(set(declared[control])))
        lanes = lane_of[control]
        if lanes:
            rep.say(f"  LANE     {control:<34} deferred by {where}")
            rep.say(f"           runs at {', '.join(lanes[:4])}")
        elif control in exempt:
            entry = exempt[control]
            reason = (entry or {}).get("reason", "") if isinstance(entry, dict) else ""
            runs = (entry or {}).get("runs", "") if isinstance(entry, dict) else ""
            if not str(reason).strip():
                rep.fail(
                    f"{control} is exempted in {lanes_file.name} with no reason written: "
                    "an exemption without a reason is a silent hole with a JSON key"
                )
            else:
                rep.say(f"  NO CI    {control:<34} deferred by {where}")
                rep.say(f"           declared with no CI lane: {str(runs).strip() or 'see the reason'}")
        else:
            rep.fail(
                f"{control} is declared not to run here ({where}) and no workflow line "
                f"names it: the declaration points at a lane that does not exist"
            )

    # ------------------------------------- QUESTION 3: the exemptions, backwards
    for control in sorted(exempt):
        if control not in controls:
            rep.fail(
                f"{lanes_file.name} exempts {control}, which is not a control in "
                "scripts/gates/: the exemption outlived the thing it excused"
            )
        elif control not in declared:
            rep.fail(
                f"{lanes_file.name} exempts {control}, which nothing defers any more: "
                "a stale exemption is an exemption nobody can be caught by"
            )
        elif lane_of.get(control):
            rep.fail(
                f"{lanes_file.name} exempts {control} from having a CI lane, and it has "
                f"one now ({lane_of[control][0]}): remove the exemption"
            )

    # ------------------------------------------------------------------ verdict
    for line in rep.lines:
        print(line)
    if not declared:
        print("  nothing in this tree is declared as deferred: there is no lane to check")

    if rep.failures:
        print("")
        for text in rep.failures:
            print(f"FAIL  {text}")
        print("")
        print(f"{len(rep.failures)} deferral(s) with no lane behind them.")
        return FAIL

    exempted = sum(1 for c in declared if not lane_of[c] and c in exempt)
    with_lane = sum(1 for c in declared if lane_of[c])
    print("")
    print(
        f"OK   {with_lane} deferred control(s) have a lane that names them; "
        f"{exempted} declared with no CI lane and a written reason."
    )
    return OK


if __name__ == "__main__":
    sys.exit(main(sys.argv))
