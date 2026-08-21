#!/usr/bin/env python3
"""Measurement core of gate-corpus-contract.sh.

Everything here answers one question: does the corpus still agree with what the
repository says about it? Seven checks, all mechanical, all driven by
scripts/meter/packs.json so that the layout lives in exactly one place:

  1. numbering        identifiers contiguous from 01, no duplicates, per family
  2. declared counts  corpus lines, procedure count and file count, wherever
                      prose states them
  3. declared ranges  `AI-01`..`AI-28` must end at the highest identifier there is
  4. pack headers     the `**Cost:** ~N lines` estimate and the loading-map table
  5. identifiers      every procedure carries the six mandatory fields, its
                      Traceability line names at least one identifier, every
                      backticked token matches a known family, and no identifier
                      is written outside backticks where nothing can check it
  6. roster           team.md, agents/ and packs.json name the same roles, the
                      same agents and the same files
  7. routing          every `pack.md §N` in coverage.md names a section that exists

EXIT CODES (the repository contract):
  0 measured, no findings · 1 measured, findings listed · 2 could not measure
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

PACKS_JSON = "scripts/meter/packs.json"
FAMILIES_JSON = "scripts/gates/data/identifier-families.json"
DECLARING_FILES = [
    "README.md",
    "CHANGELOG.md",
    "skills/ethical-hacker-squad/SKILL.md",
    "skills/ethical-hacker-squad/references/knowledge/README.md",
]
TEAM = "skills/ethical-hacker-squad/references/team.md"
COVERAGE = "skills/ethical-hacker-squad/references/coverage.md"
AGENTS_DIR = "agents"

NUMBER_WORDS = {
    10: "ten", 11: "eleven", 12: "twelve", 13: "thirteen", 14: "fourteen",
    15: "fifteen", 16: "sixteen", 17: "seventeen", 18: "eighteen",
    19: "nineteen", 20: "twenty",
}

DECL_LINES = re.compile(r"([\d]{1,3}(?:,\d{3})+)\s+lines")
DECL_PROCS = re.compile(r"([\d,]+)\s+(?:numbered\s+)?procedures")
DECL_FILES = re.compile(r"(?:over|across|in)\s+([a-z]+)\s+files")
DECL_RANGE = re.compile(r"`([A-Z]{2,4})-0*1`\.\.`([A-Z]{2,4})-(\d{2})`")
PACK_COST = re.compile(r"\*\*Cost:\*\*\s*~([\d,]+)\s*lines")
MAP_ROW = re.compile(r"^\|\s*`([a-z0-9-]+\.md)`\s*\|[^|]*\|\s*~?([\d,]+)\s*\|")
TRACE_LINE = re.compile(r"^\*\*Traceability\*\*:?(.*)$", re.M)
BACKTICKED = re.compile(r"`([^`]*)`")
ROUTE = re.compile(r"`([a-z0-9-]+\.md)`\s*((?:§\d+(?:-§?\d+)?[,;]?\s*)+)")
SECTION = re.compile(r"§(\d+)")
EXEMPTION = re.compile(
    r"internal process|no external identifier|from the original finding|from the finding", re.I)
TEAM_ROW = re.compile(r"^\|[^|]*\|\s*`(ehs-[a-z-]+)`\s*\|\s*(.+?)\s*\|\s*(.*?)\s*\|$", re.M)
PACK_REF = re.compile(r"`knowledge/([a-z0-9-]+\.md)`")
COST_TOLERANCE = 10


class Unmeasured(Exception):
    pass


HISTORICAL = re.compile(
    r"<!--\s*counts:historical\s*-->.*?<!--\s*/counts:historical\s*-->", re.S)


def drop_historical(text: str, counter: list[int] | None = None) -> str:
    """Text that quotes a superseded figure on purpose - a changelog entry saying
    what a file *used to* declare - is history, not a claim about today. It is
    exempted only inside an explicit marked region, in the same idiom the
    vocabulary gate uses, so the exemption is visible in the file and counted in
    the output rather than inferred from tense."""
    if counter is not None:
        counter[0] += len(HISTORICAL.findall(text))
    return HISTORICAL.sub("", text)


def current_section(rel: str, text: str) -> str:
    """CHANGELOG entries for past releases state the numbers of their own time and
    are history, not a claim about today. Only the top section is measured."""
    if not rel.endswith("CHANGELOG.md"):
        return text
    parts = text.split("\n## [")
    return parts[0] + ("\n## [" + parts[1] if len(parts) > 1 else "")


def read(root: Path, rel: str) -> str:
    p = root / rel
    try:
        return p.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise Unmeasured(f"cannot read {rel}: {exc}") from exc


def as_int(text: str) -> int:
    return int(text.replace(",", ""))


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    findings: list[str] = []
    checks = 0
    historical = [0]

    try:
        packs = json.loads(read(root, PACKS_JSON))
        families = json.loads(read(root, FAMILIES_JSON))["families"]
    except (ValueError, KeyError) as exc:
        raise Unmeasured(f"a data file this gate depends on is unusable: {exc}") from exc

    exact = re.compile("^(?:" + "|".join(families.values()) + ")$")
    loose = re.compile("(?:" + "|".join(families.values()) + ")")

    kdir = Path(packs["knowledge_dir"])
    heading = re.compile(packs["procedure_heading"])
    non_procedure = set(packs.get("non_procedure_files", []))
    declared_files = [f for p in packs["packs"] for f in p["files"]]

    on_disk = sorted(
        p.name for p in (root / kdir).glob("*.md") if p.name not in non_procedure
    ) if (root / kdir).is_dir() else []
    if not on_disk:
        raise Unmeasured(f"no knowledge files under {kdir}")

    # ---- 6a. every file on disk is declared, and vice versa ------------
    for name in on_disk:
        checks += 1
        if name not in declared_files:
            findings.append(
                f"{PACKS_JSON}: {name} exists on disk and no pack declares it, so its "
                "procedures are in no count and no role loads it"
            )
    for name in declared_files:
        checks += 1
        if name not in on_disk:
            findings.append(f"{PACKS_JSON}: declares {name}, which is not on disk")

    # ---- measure the corpus -------------------------------------------
    per_file_lines: dict[str, int] = {}
    per_pack_ids: dict[str, list[tuple[str, int]]] = {}
    ids_by_prefix: dict[str, list[int]] = {}
    total_procs = 0
    for pack in packs["packs"]:
        for name in pack["files"]:
            if name not in on_disk:
                continue
            text = read(root, str(kdir / name))
            per_file_lines[name] = len(text.splitlines())
            for line in text.splitlines():
                m = heading.match(line)
                if not m:
                    continue
                prefix, number = m.group(1), int(m.group(2))
                total_procs += 1
                per_pack_ids.setdefault(pack["pack"], []).append((prefix, number))
                ids_by_prefix.setdefault(prefix, []).append(number)
    total_lines = sum(per_file_lines.values())

    # ---- 1. numbering --------------------------------------------------
    for prefix, numbers in sorted(ids_by_prefix.items()):
        checks += 1
        expected = list(range(1, len(numbers) + 1))
        if sorted(numbers) != expected:
            missing = sorted(set(expected) - set(numbers))
            dupes = sorted({n for n in numbers if numbers.count(n) > 1})
            findings.append(
                f"{kdir}: `{prefix}` identifiers are not contiguous from 01 "
                f"(missing {missing}, duplicated {dupes}); every one of them is "
                "referenced from traceability, findings and issues"
            )

    # ---- 2 and 3. declarations ----------------------------------------
    file_word = NUMBER_WORDS.get(len(on_disk))
    for rel in DECLARING_FILES:
        text = drop_historical(current_section(rel, read(root, rel)), historical)
        for m in DECL_LINES.finditer(text):
            checks += 1
            if as_int(m.group(1)) != total_lines:
                findings.append(f"{rel}: declares {m.group(1)} corpus lines; measured {total_lines}")
        for m in DECL_PROCS.finditer(text):
            checks += 1
            if as_int(m.group(1)) != total_procs:
                findings.append(f"{rel}: declares {m.group(1)} procedures; measured {total_procs}")
        for m in DECL_FILES.finditer(text):
            checks += 1
            if file_word and m.group(1) != file_word:
                findings.append(
                    f"{rel}: declares '{m.group(1)} files'; there are {len(on_disk)} ({file_word})"
                )
    for rel in DECLARING_FILES + [TEAM]:
        text = drop_historical(current_section(rel, read(root, rel)))
        for m in DECL_RANGE.finditer(text):
            line_start = text.rfind("\n", 0, m.start()) + 1
            line = text[line_start:text.find("\n", m.start())]
            # A row that names a pack file states the range of THAT file, which is
            # not the pack's range. The loading map is full of them by design.
            if re.search(r"`[a-z0-9-]+\.md`", line):
                continue
            checks += 1
            prefix, end = m.group(1), int(m.group(3))
            if m.group(2) != prefix or prefix not in ids_by_prefix:
                continue
            highest = max(ids_by_prefix[prefix])
            if end != highest:
                findings.append(
                    f"{rel}: declares `{prefix}-01`..`{prefix}-{end:02d}`; the highest that "
                    f"exists is `{prefix}-{highest:02d}`"
                )

    # ---- 4. pack cost headers and the loading map ---------------------
    for name, measured in sorted(per_file_lines.items()):
        text = read(root, str(kdir / name))
        m = PACK_COST.search(text)
        checks += 1
        if not m:
            findings.append(f"{kdir/name}: the header declares no `**Cost:** ~N lines`")
        elif abs(as_int(m.group(1)) - measured) > COST_TOLERANCE:
            findings.append(
                f"{kdir/name}: header declares ~{m.group(1)} lines; measured {measured} "
                f"(tolerance {COST_TOLERANCE})"
            )
    map_file = str(kdir / "README.md")
    mapped = set()
    for line in read(root, map_file).splitlines():
        m = MAP_ROW.match(line)
        if not m:
            continue
        name, declared = m.group(1), as_int(m.group(2))
        mapped.add(name)
        checks += 1
        if name not in per_file_lines:
            findings.append(f"{map_file}: maps `{name}`, which is not a declared pack file")
        elif abs(declared - per_file_lines[name]) > COST_TOLERANCE:
            findings.append(
                f"{map_file}: maps `{name}` at ~{declared} lines; measured {per_file_lines[name]}"
            )
    for name in sorted(set(per_file_lines) - mapped):
        checks += 1
        findings.append(f"{map_file}: `{name}` is a pack file and the loading map does not list it")

    # ---- 5. anatomy and identifiers ------------------------------------
    required = [(f["label"], re.compile(f["pattern"], re.M)) for f in packs["required_fields"]]
    exempt = 0
    for name in sorted(per_file_lines):
        text = read(root, str(kdir / name))
        # A shell comment inside a fenced block is not a Markdown heading. Mask
        # the fences first, keeping the line count, or a procedure whose Tooling
        # field shows a commented command looks like it lost half its fields.
        masked, in_fence = [], False
        for line in text.splitlines():
            if line.lstrip().startswith("```"):
                in_fence = not in_fence
                masked.append("")
                continue
            masked.append("" if in_fence else line)
        # one procedure = heading line to the next heading of any level
        blocks = re.split(r"^(?=#{1,3} )", "\n".join(masked), flags=re.M)
        for block in blocks:
            m = heading.match(block.splitlines()[0] if block.splitlines() else "")
            if not m:
                continue
            pid = f"{m.group(1)}-{int(m.group(2)):02d}"
            checks += 1
            missing = [label for label, pattern in required if not pattern.search(block)]
            if missing:
                findings.append(
                    f"{kdir/name}:{pid} is missing mandatory field(s): {', '.join(missing)}. "
                    "A procedure without `What rules it out` manufactures false positives"
                )
            tm = TRACE_LINE.search(block)
            if tm:
                checks += 1
                tokens = [t.strip() for t in BACKTICKED.findall(tm.group(1)) if t.strip()]
                if not tokens:
                    if EXEMPTION.search(tm.group(1)):
                        exempt += 1
                    else:
                        findings.append(
                            f"{kdir/name}:{pid} names no standard identifier and declares no "
                            f"exemption: {tm.group(1).strip()[:70]!r}"
                        )
        for m in TRACE_LINE.finditer(text):
            trace = m.group(1)
            checks += 1
            bare = loose.findall(BACKTICKED.sub("", trace))
            if bare:
                findings.append(
                    f"{kdir/name}: identifier(s) {sorted(set(bare))} written outside backticks; "
                    "unquoted, they are invisible to every check and to anyone grepping coverage"
                )
            for token in [t.strip() for t in BACKTICKED.findall(trace) if t.strip()]:
                checks += 1
                if not exact.match(token):
                    findings.append(
                        f"{kdir/name}: `{token}` matches no known identifier family "
                        f"({FAMILIES_JSON}); either it is malformed or the standard is undeclared"
                    )

    # ---- 6b. the roster ------------------------------------------------
    team = read(root, TEAM)
    agent_files = {p.stem for p in (root / AGENTS_DIR).glob("*.md")}
    if not agent_files:
        raise Unmeasured(f"no agent definitions under {AGENTS_DIR}")
    roster_agents, roster_packs = set(), set()
    for m in TEAM_ROW.finditer(team):
        agent, packs_cell = m.group(1), m.group(2)
        roster_agents.add(agent)
        for name in PACK_REF.findall(packs_cell):
            roster_packs.add(name)
            checks += 1
            if name not in per_file_lines:
                findings.append(f"{TEAM}: role `{agent}` is sent to `{name}`, which is not a pack file")
        checks += 1
        if agent not in agent_files:
            findings.append(f"{TEAM}: names `{agent}`, which has no definition under {AGENTS_DIR}/")
    for agent in sorted(agent_files - roster_agents):
        checks += 1
        findings.append(
            f"{TEAM}: `{agent}` exists under {AGENTS_DIR}/ and the roster does not list it; "
            "the leader dispatches from that table"
        )
    for name in sorted(set(per_file_lines) - roster_packs):
        checks += 1
        findings.append(f"{TEAM}: `{name}` is a pack file and no role in the roster reads it")

    # ---- 7. routing ----------------------------------------------------
    coverage = read(root, COVERAGE)
    sections: dict[str, set[str]] = {}
    for name, refs in ROUTE.findall(coverage):
        checks += 1
        if name not in per_file_lines:
            findings.append(f"{COVERAGE}: routes to `{name}`, which is not a pack file")
            continue
        if name not in sections:
            sections[name] = {
                sm.group(1)
                for line in read(root, str(kdir / name)).splitlines()
                if line.startswith("## ")
                for sm in [SECTION.search(line)]
                if sm
            }
        for number in SECTION.findall(refs):
            checks += 1
            if number not in sections[name]:
                findings.append(f"{COVERAGE}: routes to `{name}` §{number}, which has no such section")

    print(f"measured: {total_procs} procedures, {total_lines} lines, {len(on_disk)} files, "
          f"{checks} checks")
    if exempt:
        print(f"exempted: {exempt} procedure(s) declare that no external identifier applies")
    if historical[0]:
        print(f"exempted: {historical[0]} region(s) marked counts:historical, which quote "
              "superseded figures on purpose")
    for f in findings:
        print(f"FINDING {f}")
    return 1 if findings else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Unmeasured as exc:
        print(f"UNMEASURED {exc}")
        sys.exit(2)
