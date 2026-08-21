#!/usr/bin/env python3
"""G1 - manifest and structure.

Asserts what `docs/gate-requirements.md` calls G1: the three JSON files parse,
the plugin manifest carries a name and no `version`, `SKILL.md` and every agent
definition carry usable frontmatter, agent names match their filenames, every
declared tool is a real tool, and only the remediator may write.

This gate asserts that the JSON files parse, so a syntax error in one of them is
a finding (exit 1), not an unmeasured run.
"""

from __future__ import annotations

import re
from pathlib import Path

from lib import (
    AGENTS,
    KNOWLEDGE,
    REFERENCES,
    ALLOWLIST_JSON,
    AUDITOR_AGENTS,
    MARKETPLACE_JSON,
    PLUGIN_JSON,
    SKILL_DIR,
    SKILL_MD,
    Unmeasured,
    WRITE_TOOLS,
    parse_frontmatter,
    resolve_channel,
    run,
)

SEMVER = re.compile(r"^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$")
DATA = Path(__file__).resolve().parent / "data" / "known-tools.json"


def load_known_tools() -> tuple[set[str], tuple[str, ...]]:
    import json

    try:
        data = json.loads(DATA.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise Unmeasured(f"cannot read the known-tools list at {DATA}: {exc}") from exc
    return set(data["tools"]), tuple(data.get("prefixes", ()))


def check(gate) -> None:
    known_tools, tool_prefixes = load_known_tools()
    channel, how = resolve_channel(gate.root)
    gate.note(f"channel resolved to {channel} ({how})")

    # --- the three JSON files parse ------------------------------------
    plugin = gate.read_json(PLUGIN_JSON, parse_error_is_finding=True)
    marketplace = gate.read_json(MARKETPLACE_JSON, parse_error_is_finding=True)
    gate.read_json(ALLOWLIST_JSON, parse_error_is_finding=True)
    gate.counted(3)

    # --- plugin manifest ------------------------------------------------
    if isinstance(plugin, dict):
        gate.counted(2)
        if not plugin.get("name"):
            gate.fail(str(PLUGIN_JSON), "no `name` field")
        if "version" in plugin:
            gate.fail(
                str(PLUGIN_JSON),
                "declares `version`, which pins every future commit to the same "
                "resolved version and silently stops updates reaching installed "
                "copies (docs/release-channels.md)",
            )
        for rel in plugin.get("agents", []) or []:
            gate.counted()
            if not (gate.root / rel.lstrip("./")).is_file():
                gate.fail(str(PLUGIN_JSON), f"lists agent `{rel}`, which does not exist")

    # --- marketplace entry ----------------------------------------------
    if isinstance(marketplace, dict):
        entries = marketplace.get("plugins") or []
        if not entries:
            gate.fail(str(MARKETPLACE_JSON), "no `plugins` entries")
        for entry in entries:
            gate.counted()
            version = entry.get("version")
            name = entry.get("name", "<unnamed>")
            if channel == "stable":
                if not version:
                    gate.fail(
                        f"{MARKETPLACE_JSON}:{name}",
                        "on `stable` the semver lives here and is missing",
                    )
                elif not SEMVER.match(str(version)):
                    gate.fail(f"{MARKETPLACE_JSON}:{name}", f"`{version}` is not a semver")
            elif version:
                gate.fail(
                    f"{MARKETPLACE_JSON}:{name}",
                    f"declares `version` on `{channel}`, where the channel must resolve "
                    "to the commit SHA (docs/release-channels.md)",
                )

    # --- SKILL.md frontmatter -------------------------------------------
    fm = parse_frontmatter(gate.read_text(SKILL_MD), str(SKILL_MD))
    gate.counted(3)
    if not fm.get("name"):
        gate.fail(str(SKILL_MD), "frontmatter has no `name`")
    elif fm["name"] != SKILL_DIR.name:
        gate.fail(
            str(SKILL_MD),
            f"frontmatter name `{fm['name']}` does not match directory `{SKILL_DIR.name}`",
        )
    if not fm.get("description"):
        gate.fail(str(SKILL_MD), "frontmatter has no `description`")

    # --- agent definitions ----------------------------------------------
    gate.require_dir(AGENTS)
    agent_files = gate.glob(str(AGENTS / "*.md"))
    if not agent_files:
        raise Unmeasured(f"no agent definitions under {AGENTS}")
    seen = set()
    for path in agent_files:
        rel = path.relative_to(gate.root)
        stem = path.stem
        fields = parse_frontmatter(gate.read_text(rel), str(rel))
        gate.counted(3)
        name = fields.get("name")
        if not name:
            gate.fail(str(rel), "frontmatter has no `name`")
        elif name != stem:
            gate.fail(str(rel), f"frontmatter name `{name}` does not match filename `{stem}`")
        else:
            seen.add(name)
        if not fields.get("description"):
            gate.fail(str(rel), "frontmatter has no `description`")

        raw_tools = fields.get("tools", "")
        tools = [t.strip() for t in raw_tools.split(",") if t.strip()] if raw_tools else []
        for tool in tools:
            gate.counted()
            if tool in known_tools or tool.startswith(tool_prefixes):
                continue
            gate.fail(
                str(rel),
                f"lists tool `{tool}`, which is not a known tool name "
                f"(maintained in scripts/gates/data/known-tools.json)",
            )
        if stem in AUDITOR_AGENTS:
            gate.counted()
            offending = [t for t in tools if t in WRITE_TOOLS]
            if offending:
                gate.fail(
                    str(rel),
                    f"is an auditor and lists write tools {offending}; only ehs-remediator may",
                )

    for expected in AUDITOR_AGENTS + ("ehs-remediator",):
        gate.counted()
        if expected not in seen:
            gate.fail(str(AGENTS), f"agent `{expected}` is declared in the contract but absent")

    # --- the roster agrees with the files on disk ------------------------
    # team.md is what the leader reads to dispatch. A role listed there with no
    # agent, or a pack with no role, is a capability that exists in exactly one
    # of the two places - which is how a pack ends up written and never loaded.
    team = gate.read_text(REFERENCES / "team.md")
    rows = re.findall(r"^\|[^|]*\|\s*`(ehs-[a-z-]+)`\s*\|\s*`knowledge/([a-z-]+\.md)`", team, re.M)
    if not rows:
        raise Unmeasured("no role rows found in references/team.md")
    roster_agents = {a for a, _ in rows}
    roster_packs = {pack for _, pack in rows}
    for agent, pack in rows:
        gate.counted(2)
        if agent not in seen:
            gate.fail(str(REFERENCES / "team.md"), f"role table names `{agent}`, which has no definition under agents/")
        if not (gate.root / KNOWLEDGE / pack).is_file():
            gate.fail(str(REFERENCES / "team.md"), f"role table names pack `{pack}`, which does not exist")
    for name in sorted(seen - roster_agents):
        gate.counted()
        gate.fail(str(REFERENCES / "team.md"), f"agent `{name}` exists but is missing from the role table")
    for path in gate.glob(str(KNOWLEDGE / "*.md")):
        if path.name == "README.md":
            continue
        gate.counted()
        if path.name not in roster_packs:
            gate.fail(
                str(REFERENCES / "team.md"),
                f"pack `{path.name}` exists but no role owns it; nothing would ever load it",
            )


if __name__ == "__main__":
    run("G1", "manifest and structure", check)
