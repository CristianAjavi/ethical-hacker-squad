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

from lib import AGENTS, REFERENCES, SKILL_MD, Unmeasured, run

LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
PLUGIN_ROOT = re.compile(r"\$\{CLAUDE_PLUGIN_ROOT\}(/[A-Za-z0-9_./-]+)")
HEADING = re.compile(r"^#{1,6}\s+(.*?)\s*$")
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


if __name__ == "__main__":
    run("G2", "internal links resolve", check)
