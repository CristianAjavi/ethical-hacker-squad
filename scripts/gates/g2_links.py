#!/usr/bin/env python3
"""G2 - internal links resolve.

Every relative Markdown link and every `${CLAUDE_PLUGIN_ROOT}` path referenced
from `SKILL.md`, `references/**` and `agents/**` must point at a file that
exists. A broken reference in a progressive-disclosure skill is a silent
capability loss: nothing errors, the model simply never reads the file.

Anchors are checked too when they point inside the repository: a link to
`file.md#section` whose heading does not exist sends the reader to the top of
the file with no signal that the section is gone.
"""

from __future__ import annotations

import re
from pathlib import Path

from lib import AGENTS, KNOWLEDGE, REFERENCES, SKILL_MD, Unmeasured, run

LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
PLUGIN_ROOT = re.compile(r"\$\{CLAUDE_PLUGIN_ROOT\}(/[A-Za-z0-9_./-]+)")
HEADING = re.compile(r"^#{1,6}\s+(.*?)\s*$")
ROUTE = re.compile(r"`([a-z-]+\.md)`\s*((?:§\d+(?:-§?\d+)?[,;]?\s*)+)")
SECTION = re.compile(r"§(\d+)")
EXTERNAL = ("http://", "https://", "mailto:", "#")


def slugify(heading: str) -> str:
    text = re.sub(r"`([^`]*)`", r"\1", heading)
    text = re.sub(r"\*\*?([^*]*)\*\*?", r"\1", text)
    text = text.strip().lower()
    text = re.sub(r"[^\w\s-]", "", text, flags=re.UNICODE)
    return re.sub(r"\s+", "-", text)


def anchors_of(path: Path) -> set[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return set()
    out = set()
    for line in text.splitlines():
        m = HEADING.match(line)
        if m:
            out.add(slugify(m.group(1)))
    return out


def check(gate) -> None:
    files: list[Path] = []
    skill = gate.path(SKILL_MD)
    if not skill.is_file():
        raise Unmeasured(f"missing {SKILL_MD}")
    files.append(skill)
    gate.require_dir(REFERENCES)
    files += gate.glob(str(REFERENCES / "**/*.md"))
    gate.require_dir(AGENTS)
    files += gate.glob(str(AGENTS / "*.md"))

    anchor_cache: dict[Path, set[str]] = {}

    for path in files:
        rel = path.relative_to(gate.root)
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            raise Unmeasured(f"cannot read {rel}: {exc}") from exc

        targets: list[tuple[str, Path]] = []
        for target in LINK.findall(text):
            target = target.strip()
            if target.startswith(EXTERNAL) or not target:
                continue
            targets.append((target, (path.parent / target.split("#", 1)[0]).resolve()))
        for suffix in PLUGIN_ROOT.findall(text):
            targets.append((f"${{CLAUDE_PLUGIN_ROOT}}{suffix}", (gate.root / suffix.lstrip("/")).resolve()))

        for label, resolved in targets:
            gate.counted()
            if not resolved.exists():
                gate.fail(f"{rel}", f"link `{label}` points at a file that does not exist")
                continue
            anchor = label.split("#", 1)[1] if "#" in label and not label.startswith("${") else ""
            if anchor and resolved.suffix == ".md":
                if resolved not in anchor_cache:
                    anchor_cache[resolved] = anchors_of(resolved)
                if slugify(anchor) not in anchor_cache[resolved]:
                    gate.fail(f"{rel}", f"link `{label}` points at a heading that does not exist")


def check_routing(gate) -> None:
    """coverage.md routes a signal to a pack section. A section that does not
    exist is the same silent loss as a dead link: the specialist is told to open
    something that is not there and quietly opens nothing."""
    coverage = REFERENCES / "coverage.md"
    text = gate.read_text(coverage)
    sections_cache: dict[str, set[str]] = {}
    for pack, refs in ROUTE.findall(text):
        pack_path = gate.path(KNOWLEDGE / pack)
        gate.counted()
        if not pack_path.is_file():
            gate.fail(str(coverage), f"routes to pack `{pack}`, which does not exist")
            continue
        if pack not in sections_cache:
            sections_cache[pack] = {
                m.group(1)
                for line in pack_path.read_text(encoding="utf-8").splitlines()
                if line.startswith("## ")
                for m in [SECTION.search(line)]
                if m
            }
        for number in SECTION.findall(refs):
            gate.counted()
            if number not in sections_cache[pack]:
                gate.fail(str(coverage), f"routes to `{pack}` §{number}, which has no such section")


def check_all(gate) -> None:
    check(gate)
    check_routing(gate)


if __name__ == "__main__":
    run("G2", "internal links and routing resolve", check_all)
