#!/usr/bin/env python3
"""Shared machinery for the repository gates.

Exit-code semantics, from `docs/gate-requirements.md`:

    0  measured, within threshold
    1  measured, outside threshold - the offending items are listed
    2  could not measure - reported as unmeasured, never as a pass

A gate raises `Unmeasured` for anything that stops it from measuring: a file it
has to read is missing or unreadable, a file it has to parse to reach the
property under test does not parse, a tool it needs is absent.

A defect in the property the gate exists to assert is a failure (exit 1), not
an unmeasured run. `G1` asserts that `plugin.json` parses, so a parse error
there is its finding; every other gate that reads the same file to measure
something else exits 2 when it will not parse. Which of the two applies is a
per-call decision, made at the `read_json` call site.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

EXIT_PASS = 0
EXIT_FAIL = 1
EXIT_UNMEASURED = 2

SKILL_DIR = Path("skills/ethical-hacker-squad")
SKILL_MD = SKILL_DIR / "SKILL.md"
REFERENCES = SKILL_DIR / "references"
KNOWLEDGE = REFERENCES / "knowledge"
AGENTS = Path("agents")
PLUGIN_JSON = Path(".claude-plugin/plugin.json")
MARKETPLACE_JSON = Path(".claude-plugin/marketplace.json")
ALLOWLIST_JSON = Path("docs/sources-allowlist.json")

AUDITOR_AGENTS = (
    "ehs-web-api",
    "ehs-mobile",
    "ehs-infra-cloud",
    "ehs-supply-chain",
    "ehs-ai-safety",
    "ehs-privacy-abuse",
    "ehs-verifier",
)
WRITE_TOOLS = ("Edit", "Write", "NotebookEdit")

PROCEDURE_HEADING = re.compile(r"^###\s+([A-Z]{2,3}-\d{2})\b(.*)$")


class Unmeasured(Exception):
    """Raised when the gate cannot establish the fact it is supposed to measure."""


class Gate:
    def __init__(self, gate_id: str, title: str, root: Path):
        self.gate_id = gate_id
        self.title = title
        self.root = root
        self.failures: list[str] = []
        self.notes: list[str] = []
        self.checked = 0

    # --- recording -------------------------------------------------------
    def fail(self, item: str, detail: str) -> None:
        self.failures.append(f"{item}: {detail}")

    def note(self, text: str) -> None:
        self.notes.append(text)

    def counted(self, n: int = 1) -> None:
        self.checked += n

    # --- reading ---------------------------------------------------------
    def path(self, rel) -> Path:
        return self.root / rel

    def read_text(self, rel) -> str:
        p = self.path(rel)
        try:
            return p.read_text(encoding="utf-8")
        except OSError as exc:
            raise Unmeasured(f"cannot read {rel}: {exc}") from exc
        except UnicodeDecodeError as exc:
            raise Unmeasured(f"cannot decode {rel} as UTF-8: {exc}") from exc

    def read_lines(self, rel) -> list[str]:
        return self.read_text(rel).splitlines()

    def read_json(self, rel, parse_error_is_finding: bool = False):
        """Parse a JSON file.

        `parse_error_is_finding=True` means this gate asserts the file parses,
        so a syntax error is a measured failure. Otherwise it is unmeasured:
        the gate wanted a value out of the file and could not get one.
        """
        raw = self.read_text(rel)
        try:
            return json.loads(raw)
        except json.JSONDecodeError as exc:
            if parse_error_is_finding:
                self.fail(str(rel), f"does not parse as JSON ({exc})")
                return None
            raise Unmeasured(f"{rel} does not parse as JSON: {exc}") from exc

    def glob(self, pattern: str) -> list[Path]:
        return sorted(self.root.glob(pattern))

    def require_dir(self, rel) -> Path:
        p = self.path(rel)
        if not p.is_dir():
            raise Unmeasured(f"missing directory {rel}")
        return p

    # --- reporting -------------------------------------------------------
    def report(self) -> int:
        head = f"[{self.gate_id}] {self.title}"
        for n in self.notes:
            print(f"{head} - note: {n}")
        if self.failures:
            print(f"{head}: FAIL ({len(self.failures)} of {self.checked} checks)")
            for f in self.failures:
                print(f"  - {f}")
            return EXIT_FAIL
        print(f"{head}: PASS ({self.checked} checks)")
        return EXIT_PASS


def parse_frontmatter(text: str, source: str) -> dict[str, str]:
    """Minimal YAML frontmatter reader: flat `key: value` pairs only.

    Raises Unmeasured when the block is absent or unterminated - the gate cannot
    say whether the keys are right if it never found the block.
    """
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        raise Unmeasured(f"{source}: no YAML frontmatter opening '---' on line 1")
    fields: dict[str, str] = {}
    for i, line in enumerate(lines[1:], start=2):
        if line.strip() == "---":
            return fields
        m = re.match(r"^([A-Za-z][\w-]*):\s*(.*)$", line)
        if m:
            fields[m.group(1)] = m.group(2).strip()
    raise Unmeasured(f"{source}: frontmatter never closed with '---'")


def split_procedures(text: str) -> list[tuple[str, str, str]]:
    """Return (id, heading tail, body) for every `### XX-NN ...` procedure."""
    out: list[tuple[str, str, str]] = []
    current_id = None
    current_tail = ""
    buf: list[str] = []
    in_fence = False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            if current_id:
                buf.append(line)
            continue
        if in_fence:
            # A shell comment inside a fenced block is not a Markdown heading.
            if current_id:
                buf.append(line)
            continue
        m = PROCEDURE_HEADING.match(line)
        if m:
            if current_id:
                out.append((current_id, current_tail, "\n".join(buf)))
            current_id, current_tail, buf = m.group(1), m.group(2).strip(), []
            continue
        if current_id and (line.startswith("## ") or line.startswith("# ")):
            out.append((current_id, current_tail, "\n".join(buf)))
            current_id, current_tail, buf = None, "", []
            continue
        if current_id:
            buf.append(line)
    if current_id:
        out.append((current_id, current_tail, "\n".join(buf)))
    return out


def knowledge_packs(gate: Gate) -> list[Path]:
    """Every role pack, excluding the corpus README (a map, not a pack)."""
    gate.require_dir(KNOWLEDGE)
    packs = [p for p in gate.glob(str(KNOWLEDGE / "*.md")) if p.name != "README.md"]
    if not packs:
        raise Unmeasured(f"no knowledge packs found under {KNOWLEDGE}")
    return packs


def run(gate_id: str, title: str, check) -> None:
    """Entry point shared by every gate script."""
    ap = argparse.ArgumentParser(description=f"{gate_id} - {title}")
    ap.add_argument(
        "--root",
        default=os.environ.get("EHS_ROOT", repo_root()),
        help="repository root to measure (defaults to the repository this script lives in)",
    )
    args = ap.parse_args()
    root = Path(args.root).resolve()
    gate = Gate(gate_id, title, root)
    if not root.is_dir():
        print(f"[{gate_id}] {title}: UNMEASURED - root {root} is not a directory")
        sys.exit(EXIT_UNMEASURED)
    try:
        check(gate)
    except Unmeasured as exc:
        print(f"[{gate_id}] {title}: UNMEASURED - {exc}")
        sys.exit(EXIT_UNMEASURED)
    sys.exit(gate.report())


def repo_root() -> str:
    return str(Path(__file__).resolve().parents[2])


def resolve_channel(root: Path) -> tuple[str, str]:
    """Return (channel, how it was determined).

    Order: EHS_CHANNEL, GITHUB_REF_NAME, the checked-out branch, then `main`.
    Unknown resolves to `main` on purpose: those are the stricter rules, so an
    undetermined channel fails closed rather than skipping the check.
    """
    for env in ("EHS_CHANNEL", "GITHUB_REF_NAME"):
        value = os.environ.get(env)
        if value:
            return ("stable" if value.strip() == "stable" else "main", f"{env}={value}")
    head = root / ".git" / "HEAD"
    try:
        ref = head.read_text(encoding="utf-8").strip()
    except OSError:
        return ("main", "no branch information; assuming main")
    branch = ref.rsplit("/", 1)[-1] if ref.startswith("ref:") else ref
    return ("stable" if branch == "stable" else "main", f"branch {branch}")
