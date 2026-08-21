#!/usr/bin/env python3
"""G3 - context budget, and G3b - declared counts match reality.

G3 keeps progressive disclosure workable: the entry point stays small, no single
reference file grows past the point where a specialist can load it selectively,
and loading the whole corpus stays obviously wrong.

G3b watches every number the prose repeats about itself. The corpus size, the
procedure count and the per-pack cost estimates are stated in four files and in
each pack header; nothing else stops the first added procedure from making all
of them wrong at once. Measured facts win, declarations are compared to them.
"""

from __future__ import annotations

import re

from lib import (
    AGENTS,
    Unmeasured,
    KNOWLEDGE,
    PROCEDURE_HEADING,
    REFERENCES,
    SKILL_MD,
    knowledge_packs,
    run,
)

LIMITS = {"skill": 500, "reference": 600, "corpus": 3500, "agent": 120}
PACK_TOLERANCE = 10  # lines; the pack headers declare a cost estimate with `~`

DECLARING_FILES = [
    "README.md",
    "CHANGELOG.md",
    str(SKILL_MD),
    str(KNOWLEDGE / "README.md"),
]

DECL_LINES = re.compile(r"([\d]{1,3}(?:,\d{3})+)\s+lines")
DECL_PROCS = re.compile(r"([\d,]+)\s+(?:numbered\s+)?procedures")
DECL_RANGE = re.compile(r"`([A-Z]{2,3})-01`\.\.`([A-Z]{2,3})-(\d{2})`")
DECL_MUTANTS = re.compile(r"(\d+)\s+mutants")
MUTANT_CTOR = re.compile(r"^\s*Mutant\(", re.M)
MUTANT_FILES = ["docs/gate-requirements.md", "README.md", "CHANGELOG.md"]
MUTANT_BANK = "tests/gate_mutants.py"
PACK_COST = re.compile(r"\*\*Cost:\*\*\s*~([\d,]+)\s*lines")
PACK_ROW = re.compile(r"^\|\s*`([a-z-]+\.md)`\s*\|[^|]*\|\s*~?([\d,]+)\s*\|")


def as_int(text: str) -> int:
    return int(text.replace(",", ""))


def check(gate) -> None:
    packs = knowledge_packs(gate)

    # --- G3: budget ------------------------------------------------------
    skill_lines = len(gate.read_lines(SKILL_MD))
    gate.counted()
    if skill_lines > LIMITS["skill"]:
        gate.fail(str(SKILL_MD), f"{skill_lines} lines, limit {LIMITS['skill']}")

    for path in gate.glob(str(REFERENCES / "**/*.md")):
        rel = path.relative_to(gate.root)
        n = len(gate.read_lines(rel))
        gate.counted()
        if n > LIMITS["reference"]:
            gate.fail(str(rel), f"{n} lines, limit {LIMITS['reference']}")

    pack_lines = {p.name: len(gate.read_lines(p.relative_to(gate.root))) for p in packs}
    corpus_lines = sum(pack_lines.values())
    gate.counted()
    if corpus_lines > LIMITS["corpus"]:
        gate.fail(str(KNOWLEDGE), f"corpus is {corpus_lines} lines, limit {LIMITS['corpus']}")

    for path in gate.glob(str(AGENTS / "*.md")):
        rel = path.relative_to(gate.root)
        n = len(gate.read_lines(rel))
        gate.counted()
        if n > LIMITS["agent"]:
            gate.fail(str(rel), f"{n} lines, limit {LIMITS['agent']}")

    # --- measure the corpus ---------------------------------------------
    families: dict[str, list[int]] = {}
    total_procs = 0
    for path in packs:
        rel = path.relative_to(gate.root)
        for line in gate.read_lines(rel):
            m = PROCEDURE_HEADING.match(line)
            if not m:
                continue
            total_procs += 1
            prefix, number = m.group(1).split("-")
            families.setdefault(prefix, []).append(int(number))

    for prefix, numbers in families.items():
        gate.counted()
        expected = list(range(1, len(numbers) + 1))
        if sorted(numbers) != expected:
            missing = sorted(set(expected) - set(numbers))
            dupes = sorted({n for n in numbers if numbers.count(n) > 1})
            gate.fail(
                f"{KNOWLEDGE}:{prefix}",
                f"identifiers are not contiguous from 01 (missing {missing}, duplicated {dupes})",
            )

    gate.note(f"measured: {corpus_lines} corpus lines, {total_procs} procedures")

    # --- G3b: declarations ----------------------------------------------
    for rel in DECLARING_FILES:
        text = gate.read_text(rel)
        for m in DECL_LINES.finditer(text):
            gate.counted()
            declared = as_int(m.group(1))
            if declared != corpus_lines:
                gate.fail(rel, f"declares {declared} corpus lines; measured {corpus_lines}")
        for m in DECL_PROCS.finditer(text):
            gate.counted()
            declared = as_int(m.group(1))
            if declared != total_procs:
                gate.fail(rel, f"declares {declared} procedures; measured {total_procs}")
        for m in DECL_RANGE.finditer(text):
            gate.counted()
            prefix, end_prefix, end = m.group(1), m.group(2), int(m.group(3))
            if prefix != end_prefix:
                continue
            highest = max(families.get(prefix, [0]))
            if end != highest:
                gate.fail(
                    rel,
                    f"declares `{prefix}-01`..`{prefix}-{end:02d}`; highest measured is "
                    f"`{prefix}-{highest:02d}`",
                )

    # --- G3b: the declared size of the mutant bank ------------------------
    # The bank is the evidence that the gates fail when they should. A number
    # stated in prose about it drifts exactly like the corpus counts do.
    declarations = []
    for rel in MUTANT_FILES:
        if not (gate.root / rel).is_file():
            continue
        for m in DECL_MUTANTS.finditer(gate.read_text(rel)):
            declarations.append((rel, as_int(m.group(1))))
    if declarations:
        if not (gate.root / MUTANT_BANK).is_file():
            raise Unmeasured(
                f"{len(declarations)} declaration(s) state a mutant count, but {MUTANT_BANK} is absent"
            )
        measured = len(MUTANT_CTOR.findall(gate.read_text(MUTANT_BANK)))
        for rel, declared in declarations:
            gate.counted()
            if declared != measured:
                gate.fail(rel, f"declares {declared} mutants; {MUTANT_BANK} defines {measured}")

    # --- G3b: per-pack cost estimates ------------------------------------
    for path in packs:
        rel = path.relative_to(gate.root)
        text = gate.read_text(rel)
        m = PACK_COST.search(text)
        gate.counted()
        if not m:
            gate.fail(str(rel), "pack header declares no `**Cost:** ~N lines`")
            continue
        declared, actual = as_int(m.group(1)), pack_lines[path.name]
        if abs(declared - actual) > PACK_TOLERANCE:
            gate.fail(
                str(rel),
                f"header declares ~{declared} lines; measured {actual} "
                f"(tolerance {PACK_TOLERANCE})",
            )

    readme = KNOWLEDGE / "README.md"
    for line in gate.read_lines(readme):
        m = PACK_ROW.match(line)
        if not m:
            continue
        name, declared = m.group(1), as_int(m.group(2))
        gate.counted()
        if name not in pack_lines:
            gate.fail(str(readme), f"table row names `{name}`, which is not a pack")
        elif abs(declared - pack_lines[name]) > PACK_TOLERANCE:
            gate.fail(
                str(readme),
                f"table declares ~{declared} lines for `{name}`; measured {pack_lines[name]}",
            )


if __name__ == "__main__":
    run("G3", "context budget and declared counts", check)
