#!/usr/bin/env python3
"""Mutant bank: proves every gate in the negative.

A gate nobody has watched fail is a gate nobody knows works. For each gate this
harness copies the repository into a temporary directory, breaks exactly one
thing, and asserts the gate notices - and separately, that a tree it cannot
measure exits `2` rather than passing quietly.

    python3 tests/gate_mutants.py            # every mutant
    python3 tests/gate_mutants.py --only G3  # one gate

Exit codes match the gates themselves: 0 all mutants caught, 1 a mutant
survived or an exit code was wrong, 2 the harness itself could not run.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

REPO = Path(__file__).resolve().parents[1]
GATES = {
    "G1": "scripts/gates/g1_manifest.py",
    "G2": "scripts/gates/g2_links.py",
    "G3": "scripts/gates/g3_budget.py",
    "G4": "scripts/gates/g4_citations.py",
}
SKILL = "skills/ethical-hacker-squad/SKILL.md"
KNOWLEDGE = "skills/ethical-hacker-squad/references/knowledge"


@dataclass
class Mutant:
    gate: str
    name: str
    expect: int
    apply: Callable[[Path], None]
    why: str


# --- mutation helpers ---------------------------------------------------
def edit(root: Path, rel: str, old: str, new: str) -> None:
    p = root / rel
    text = p.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"harness: anchor not found in {rel}: {old!r}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


def append(root: Path, rel: str, text: str) -> None:
    with (root / rel).open("a", encoding="utf-8") as fh:
        fh.write(text)


def drop(root: Path, rel: str) -> None:
    target = root / rel
    if target.is_dir():
        shutil.rmtree(target)
    else:
        target.unlink()


def patch_json(root: Path, rel: str, mutate: Callable[[dict], None]) -> None:
    p = root / rel
    data = json.loads(p.read_text(encoding="utf-8"))
    mutate(data)
    p.write_text(json.dumps(data, indent=2), encoding="utf-8")


MUTANTS = [
    # --- G1 -----------------------------------------------------------
    Mutant("G1", "plugin-declares-version", 1,
           lambda r: patch_json(r, ".claude-plugin/plugin.json",
                                lambda d: d.update({"version": "1.0.0"})),
           "the documented trap: every commit then resolves to the same version"),
    Mutant("G1", "marketplace-version-on-main", 1,
           lambda r: patch_json(r, ".claude-plugin/marketplace.json",
                                lambda d: d["plugins"][0].update({"version": "1.0.0"})),
           "latest must resolve to the commit SHA"),
    Mutant("G1", "plugin-json-does-not-parse", 1,
           lambda r: (r / ".claude-plugin/plugin.json").write_text("{ not json", encoding="utf-8"),
           "G1 asserts the file parses, so this is a finding, not an unmeasured run"),
    Mutant("G1", "auditor-gains-write-tool", 1,
           lambda r: edit(r, "agents/ehs-verifier.md",
                          "tools: Read, Grep, Glob, Bash", "tools: Read, Grep, Glob, Bash, Write"),
           "only the remediator may write"),
    Mutant("G1", "misspelled-tool-name", 1,
           lambda r: edit(r, "agents/ehs-web-api.md",
                          "tools: Read, Grep, Glob, Bash", "tools: Read, Grepp, Glob, Bash"),
           "a typo silently removes the tool at runtime"),
    Mutant("G1", "agent-name-does-not-match-file", 1,
           lambda r: edit(r, "agents/ehs-mobile.md", "name: ehs-mobile", "name: ehs-movil"),
           "the harness resolves subagents by name"),
    Mutant("G1", "declared-agent-file-missing", 1,
           lambda r: drop(r, "agents/ehs-privacy-abuse.md"),
           "the manifest lists an agent that is not there"),
    Mutant("G1", "skill-frontmatter-name-drifts", 1,
           lambda r: edit(r, SKILL, "name: ethical-hacker-squad", "name: hacker-squad"),
           "frontmatter name must match the directory"),
    Mutant("G1", "manifest-directory-missing", 2,
           lambda r: drop(r, ".claude-plugin"),
           "cannot measure a manifest that is not there"),

    # --- G2 -----------------------------------------------------------
    Mutant("G2", "broken-relative-link", 1,
           lambda r: edit(r, SKILL, "[references/team.md](references/team.md)",
                          "[references/team.md](references/squad.md)"),
           "progressive disclosure fails silently on a dead link"),
    Mutant("G2", "broken-plugin-root-path", 1,
           lambda r: edit(r, "agents/ehs-web-api.md",
                          "references/knowledge/web-api.md", "references/knowledge/webapi.md"),
           "the specialist would never read its own pack"),
    Mutant("G2", "broken-anchor", 1,
           lambda r: edit(r, SKILL, "[references/report.md](references/report.md)",
                          "[references/report.md](references/report.md#nonexistent-section)"),
           "an anchor that no longer exists sends the reader to the top of the file"),
    Mutant("G2", "references-directory-missing", 2,
           lambda r: drop(r, "skills/ethical-hacker-squad/references"),
           "cannot measure links into a corpus that is not there"),

    # --- G3 -----------------------------------------------------------
    Mutant("G3", "skill-over-budget", 1,
           lambda r: append(r, SKILL, "\nfiller\n" * 500),
           "the entry point stays in context for the whole session"),
    Mutant("G3", "declared-corpus-lines-drift", 1,
           lambda r: edit(r, "README.md", "2,749 lines of corpus", "2,900 lines of corpus"),
           "a hand-repeated number drifts and the copy is the one people trust"),
    Mutant("G3", "declared-procedure-count-drift", 1,
           lambda r: edit(r, "CHANGELOG.md", "122 numbered procedures", "137 numbered procedures"),
           "the exact defect this repository shipped once already"),
    Mutant("G3", "procedure-ids-not-contiguous", 1,
           lambda r: edit(r, f"{KNOWLEDGE}/mobile.md", "### MOB-07", "### MOB-77"),
           "identifiers are referenced from traceability, findings and issues"),
    Mutant("G3", "pack-cost-header-drift", 1,
           lambda r: edit(r, f"{KNOWLEDGE}/web-api.md", "**Cost:** ~485 lines",
                          "**Cost:** ~300 lines"),
           "the cost estimate is what a specialist budgets context against"),
    Mutant("G3", "declared-id-range-drift", 1,
           lambda r: edit(r, f"{KNOWLEDGE}/README.md", "`AI-01`..`AI-22`", "`AI-01`..`AI-25`"),
           "a range that overstates the corpus promises procedures that do not exist"),
    Mutant("G3", "knowledge-directory-missing", 2,
           lambda r: drop(r, KNOWLEDGE),
           "cannot measure a corpus that is not there"),

    # --- G4 -----------------------------------------------------------
    Mutant("G4", "procedure-loses-traceability", 1,
           lambda r: edit(r, f"{KNOWLEDGE}/web-api.md",
                          "**Traceability**: `CWE-347` \u00b7 `CWE-345` \u00b7 `WSTG-ATHN-*` \u00b7 "
                          "`ASVS 5.0 V9` \u00b7 `A07:2025` \u00b7 `API2:2023`",
                          "**Traceability**: standard appsec knowledge"),
           "an uncited claim cannot be checked or corrected"),
    Mutant("G4", "procedure-loses-false-positive-criteria", 1,
           lambda r: edit(r, f"{KNOWLEDGE}/web-api.md",
                          "**What rules it out (false positive)**", "**Notes**"),
           "a procedure without this field manufactures false positives"),
    Mutant("G4", "unsourced-quantitative-claim", 1,
           lambda r: append(r, f"{KNOWLEDGE}/privacy-abuse.md",
                            "\n## §9 Added claim\n\nThis class affects 73% of deployments.\n"),
           "a percentage with no source is unfalsifiable"),
    Mutant("G4", "fabricated-identifier", 1,
           lambda r: edit(r, f"{KNOWLEDGE}/mobile.md",
                          "**Traceability**: `", "**Traceability**: `OWASP-MOBILE-TOP-99` \u00b7 `"),
           "an invented ID survives review by looking correct"),
    Mutant("G4", "knowledge-directory-missing", 2,
           lambda r: drop(r, KNOWLEDGE),
           "cannot measure citations in a corpus that is not there"),
]


def copy_repo(dest: Path) -> None:
    shutil.copytree(
        REPO, dest,
        ignore=shutil.ignore_patterns(".git", "__pycache__", "*.pyc"),
        dirs_exist_ok=True,
    )


def run_gate(gate: str, root: Path) -> tuple[int, str]:
    proc = subprocess.run(
        [sys.executable, str(REPO / GATES[gate]), "--root", str(root)],
        capture_output=True, text=True, check=False,
        env={"PATH": "/usr/bin:/bin", "EHS_CHANNEL": "main"},
    )
    return proc.returncode, (proc.stdout + proc.stderr).strip()


def main() -> int:
    ap = argparse.ArgumentParser(description="prove the gates in the negative")
    ap.add_argument("--only", nargs="*", help="gate ids, e.g. --only G1 G4")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()
    selected = [m for m in MUTANTS if not args.only or m.gate in args.only]
    gates = sorted({m.gate for m in selected})

    failures: list[str] = []

    print("baseline: the unmodified repository must pass every selected gate")
    for gate in gates:
        code, out = run_gate(gate, REPO)
        status = "ok" if code == 0 else f"UNEXPECTED exit {code}"
        print(f"  {gate} baseline: {status}")
        if code != 0:
            failures.append(f"{gate} baseline exited {code}\n{out}")

    print(f"\nmutants: {len(selected)}")
    for m in selected:
        with tempfile.TemporaryDirectory(prefix="ehs-mutant-") as tmp:
            root = Path(tmp) / "repo"
            copy_repo(root)
            try:
                m.apply(root)
            except SystemExit as exc:
                print(f"  {m.gate} {m.name}: HARNESS ERROR - {exc}")
                return 2
            code, out = run_gate(m.gate, root)
            ok = code == m.expect
            print(f"  {m.gate} {m.name}: {'caught' if ok else 'SURVIVED'} "
                  f"(exit {code}, expected {m.expect}) - {m.why}")
            if not ok:
                failures.append(f"{m.gate} {m.name}: exit {code}, expected {m.expect}\n{out}")
            elif args.verbose:
                print("      " + out.replace("\n", "\n      "))

    print()
    if failures:
        print(f"FAIL - {len(failures)} of {len(selected) + len(gates)} checks wrong")
        for f in failures:
            print(f"  - {f}")
        return 1
    print(f"PASS - {len(gates)} baselines and {len(selected)} mutants behaved as specified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
