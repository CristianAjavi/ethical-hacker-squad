#!/usr/bin/env python3
"""refutation.py - prove that the clean fixture is one edit away from each rule.

Reads `scripts/gates/data/refutation-cases.json`. Every case names a fixture
that validates CLEAN, the rule it is supposed to be refuting, and the exact
edit that removes the refuting evidence. For each case this script:

  1. runs the declared validator over the fixture untouched, and requires it
     to report nothing - a refutation case that is already dirty refutes
     nothing;
  2. applies the edit to a copy, in a directory named `good/` so the validator
     judges it by the same path it judges the real fixture by;
  3. requires the validator to report a finding whose text contains the
     declared needle.

A case that does not flip is the whole point of the file: it means the rule the
fixture claims to sit next to never fires, so the fixture's cleanliness was
never evidence of anything.

Output is one `code|message` line per event, for the gate to colour:
  0 = information, 1 = finding, 2 = could not measure.
Exit status is always 0; the codes carry the verdict.
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

NOISE = ("measured:", "coverage join:")


def emit(code: int, message: str) -> None:
    print(f"{code}|{message}")


def run_validator(python: str, validator: Path, root: Path, target: Path):
    """Return (rc, [message lines]) for one validator run over one artifact."""
    proc = subprocess.run(
        [python, str(validator), str(root), str(target)],
        capture_output=True, text=True,
    )
    text = (proc.stdout or "") + (proc.stderr or "")
    lines = [ln.strip() for ln in text.splitlines()
             if ln.strip() and not ln.strip().startswith(NOISE)]
    return proc.returncode, lines


def main() -> int:
    if len(sys.argv) < 2:
        emit(2, "no repository root given, so nothing was measured")
        return 0
    root = Path(sys.argv[1]).resolve()
    cases_path = Path(sys.argv[2]) if len(sys.argv) > 2 else (
        root / "scripts" / "gates" / "data" / "refutation-cases.json")

    if not cases_path.is_file():
        emit(2, f"the case file is missing: {cases_path} - without it this gate "
                "would sign a refutation nobody declared")
        return 0
    try:
        doc = json.loads(cases_path.read_text(encoding="utf-8"))
    except ValueError as exc:
        emit(2, f"the case file does not parse: {exc}")
        return 0
    cases = doc.get("cases")
    if not isinstance(cases, list) or not cases:
        emit(2, "the case file declares no `cases` list")
        return 0

    minimum = doc.get("minimum_cases")
    if isinstance(minimum, int) and len(cases) < minimum:
        emit(1, f"{len(cases)} case(s) declared and the floor in the same file says "
                f"{minimum} - a refutation case was retired and this line is the only "
                "record that it existed")

    seen_needles: dict[str, str] = {}
    ok = 0
    with tempfile.TemporaryDirectory() as tmp:
        good = Path(tmp) / "good"
        good.mkdir()
        for index, case in enumerate(cases):
            cid = str(case.get("id") or f"case-{index + 1}")
            fixture = case.get("fixture")
            needle = case.get("needle")
            edit = case.get("edit") or {}
            old, new = edit.get("old"), edit.get("new")
            validator_rel = case.get("validator")
            if not all(isinstance(x, str) for x in (fixture, needle, validator_rel)) \
                    or not isinstance(old, str) or not isinstance(new, str):
                emit(2, f"{cid}: the case is missing `fixture`, `validator`, `needle` "
                        "or `edit.old`/`edit.new`, so it could not be applied")
                continue

            if needle in seen_needles:
                emit(1, f"{cid}: proves the same rule as {seen_needles[needle]} "
                        f"({needle!r}) - two cases for one rule count once")
            else:
                seen_needles[needle] = cid

            target = root / fixture
            if not target.is_file():
                emit(2, f"{cid}: the fixture is gone: {fixture}")
                continue
            if target.parent.name != "good":
                emit(1, f"{cid}: {fixture} does not live under a `good/` directory, so "
                        "the validator never judged it as a clean artifact")
                continue
            validator = root / validator_rel
            if not validator.is_file():
                emit(2, f"{cid}: the validator is gone: {validator_rel}")
                continue

            text = target.read_text(encoding="utf-8")
            clean_copy = good / f"{cid}-clean{target.suffix}"
            clean_copy.write_text(text, encoding="utf-8")
            rc, lines = run_validator(sys.executable, validator, root, clean_copy)
            clean_copy.unlink()
            if rc == 2:
                emit(2, f"{cid}: the validator could not measure the untouched fixture: "
                        f"{lines[0] if lines else 'no message'}")
                continue
            if rc != 0 or lines:
                emit(1, f"{cid}: {fixture} does not validate cleanly to begin with "
                        f"({lines[0] if lines else 'rc %d' % rc}), so its cleanliness "
                        "is not evidence that any rule was refuted")
                continue

            hits = text.count(old)
            if hits != 1:
                emit(1, f"{cid}: the reverting edit matches {hits} time(s) in {fixture} "
                        "and must match exactly once - the case has drifted away from "
                        "the fixture it was written against")
                continue
            mutated = text.replace(old, new)
            if target.suffix == ".json":
                try:
                    json.loads(mutated)
                except ValueError as exc:
                    emit(1, f"{cid}: the reverting edit leaves invalid JSON ({exc}), so "
                            "any rejection would be about the syntax and not about "
                            f"{needle!r}")
                    continue
            mutant = good / f"{cid}{target.suffix}"
            mutant.write_text(mutated, encoding="utf-8")
            rc, lines = run_validator(sys.executable, validator, root, mutant)
            mutant.unlink()

            if rc == 2:
                emit(2, f"{cid}: the validator could not measure the reverted copy: "
                        f"{lines[0] if lines else 'no message'}")
                continue
            if rc == 0 or not lines:
                emit(1, f"{cid}: removing {case.get('removes', 'the refuting evidence')} "
                        "changed nothing - the rule this case claims to sit next to "
                        f"never fired, so {fixture} passing proves nothing about "
                        f"{needle!r}")
                continue
            if not any(needle in ln for ln in lines):
                emit(1, f"{cid}: rejected, but for the wrong reason - expected "
                        f"{needle!r}, got {lines[0]!r}")
                continue
            ok += 1
            emit(0, f"{cid}: one edit from {needle!r} - and clean without it")

    emit(0, f"{ok} of {len(cases)} declared refutation case(s) flipped for their own reason")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # noqa: BLE001 - a crash must not read as a pass
        emit(2, f"the refutation engine crashed: {exc}")
        sys.exit(0)
