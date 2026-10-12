#!/usr/bin/env python3
"""CLI utility for Ethical Hacker Squad (EHS).

Provides terminal commands for inspecting procedures, searching across the
knowledge corpus, validating environment health, and installing skills.

Usage:
  scripts/ehs.py list [pack]
  scripts/ehs.py show <ID>
  scripts/ehs.py search <query>
  scripts/ehs.py stats
  scripts/ehs.py doctor
  scripts/ehs.py install [--antigravity] [--claude] [--all]
  scripts/ehs.py sarif <findings.json> [-o out.sarif]
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional


def find_repo_root() -> Path:
    """Find the root directory of the ethical-hacker-squad repository."""
    candidate = Path(__file__).resolve().parent.parent
    if (candidate / "skills" / "ethical-hacker-squad" / "SKILL.md").exists():
        return candidate
    cwd = Path.cwd()
    if (cwd / "skills" / "ethical-hacker-squad" / "SKILL.md").exists():
        return cwd
    return candidate


ROOT = find_repo_root()
PACKS_JSON_PATH = ROOT / "scripts" / "meter" / "packs.json"


def load_packs_config() -> Dict[str, Any]:
    """Load corpus packs configuration."""
    if not PACKS_JSON_PATH.exists():
        print(f"Error: packs config not found at {PACKS_JSON_PATH}", file=sys.stderr)
        sys.exit(2)
    with open(PACKS_JSON_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def parse_procedures(root: Path) -> List[Dict[str, Any]]:
    """Parse all procedures across the knowledge corpus."""
    cfg = load_packs_config()
    knowledge_dir = root / cfg.get("knowledge_dir", "skills/ethical-hacker-squad/references/knowledge")
    heading_re = re.compile(cfg.get("procedure_heading", r"^### ([A-Z]+)-([0-9]+)\b"))

    req_fields = cfg.get("required_fields", [])
    field_patterns = {f["name"]: re.compile(f["pattern"]) for f in req_fields}

    procedures: List[Dict[str, Any]] = []

    for pack_info in cfg.get("packs", []):
        pack_name = pack_info["pack"]
        role = pack_info["role"]
        for fname in pack_info.get("files", []):
            fpath = knowledge_dir / fname
            if not fpath.exists():
                continue

            with open(fpath, "r", encoding="utf-8") as f:
                lines = f.readlines()

            current_proc: Optional[Dict[str, Any]] = None
            current_field: Optional[str] = None
            current_field_content: List[str] = []

            def finalize_field(proc: Dict[str, Any], field: Optional[str], content_lines: List[str]):
                if field and proc:
                    text = "".join(content_lines).strip()
                    # Strip trailing markdown line-continuation backslashes
                    if text.endswith("\\"):
                        text = text[:-1].rstrip()
                    proc["fields"][field] = text

            for line in lines:
                m = heading_re.match(line)
                if m:
                    if current_proc:
                        finalize_field(current_proc, current_field, current_field_content)
                        procedures.append(current_proc)
                    prefix = m.group(1)
                    num = m.group(2)
                    proc_id = f"{prefix}-{num}"
                    title = line.strip()[len(m.group(0)):].strip()
                    current_proc = {
                        "id": proc_id,
                        "title": title,
                        "pack": pack_name,
                        "role": role,
                        "file": fname,
                        "fields": {},
                        "raw_lines": [line]
                    }
                    current_field = None
                    current_field_content = []
                    continue

                if current_proc:
                    current_proc["raw_lines"].append(line)
                    matched_field = None
                    rest_of_line = ""
                    for fname_key, fpat in field_patterns.items():
                        m_field = fpat.match(line)
                        if m_field:
                            matched_field = fname_key
                            rest_of_line = line[m_field.end():].lstrip(": ").lstrip("— ")
                            break

                    if matched_field:
                        finalize_field(current_proc, current_field, current_field_content)
                        current_field = matched_field
                        current_field_content = [rest_of_line] if rest_of_line.strip() else []
                    elif current_field:
                        current_field_content.append(line)

            if current_proc:
                finalize_field(current_proc, current_field, current_field_content)
                procedures.append(current_proc)

    return procedures


def cmd_list(args: argparse.Namespace) -> int:
    """List procedures with optional pack filter."""
    procs = parse_procedures(ROOT)
    target_pack = args.pack.lower() if args.pack else None

    if target_pack:
        procs = [p for p in procs if p["pack"].lower() == target_pack or p["id"].lower().startswith(target_pack)]

    if not procs:
        print(f"No procedures found{' for pack ' + target_pack if target_pack else ''}.")
        return 1

    print(f"\n{'ID':<10} {'PACK':<16} {'TITLE'}")
    print("-" * 78)
    for p in procs:
        title = p["title"]
        if len(title) > 50:
            title = title[:47] + "..."
        print(f"{p['id']:<10} {p['pack']:<16} {title}")

    print("-" * 78)
    print(f"Total: {len(procs)} procedure(s)\n")
    return 0


def cmd_show(args: argparse.Namespace) -> int:
    """Show details of a specific procedure."""
    proc_id = args.id.upper()
    procs = parse_procedures(ROOT)
    matched = [p for p in procs if p["id"].upper() == proc_id]

    if not matched:
        print(f"Error: Procedure '{proc_id}' not found in corpus.", file=sys.stderr)
        return 1

    p = matched[0]
    print(f"\n{'=' * 78}")
    print(f"  {p['id']} — {p['title']}")
    print(f"  Pack: {p['pack']} | Role: {p['role']} | File: {p['file']}")
    print(f"{'=' * 78}\n")

    field_labels = {
        "where_to_look": "Where to look",
        "vulnerable_pattern": "Vulnerable pattern",
        "rules_it_out": "What rules it out (false positive)",
        "minimal_test": "Minimal test",
        "traceability": "Traceability",
        "tooling": "Tooling",
    }

    for key, label in field_labels.items():
        content = p["fields"].get(key, "(not specified)")
        print(f"▶ {label}:")
        for line in content.splitlines():
            print(f"  {line}")
        print()

    return 0


def cmd_search(args: argparse.Namespace) -> int:
    """Search procedures by keyword in title, pattern, traceability, or false positives."""
    query = args.query.lower()
    procs = parse_procedures(ROOT)
    results = []

    for p in procs:
        combined = f"{p['id']} {p['title']} {p['pack']} " + " ".join(p["fields"].values())
        if query in combined.lower():
            results.append(p)

    if not results:
        print(f"No procedures found matching '{args.query}'.")
        return 0

    print(f"\nSearch results for '{args.query}' ({len(results)} match(es)):")
    print(f"{'ID':<10} {'PACK':<16} {'TITLE'}")
    print("-" * 78)
    for p in results:
        title = p["title"]
        if len(title) > 50:
            title = title[:47] + "..."
        print(f"{p['id']:<10} {p['pack']:<16} {title}")
    print()
    return 0


def cmd_stats(args: argparse.Namespace) -> int:
    """Display quick metrics for the corpus."""
    procs = parse_procedures(ROOT)
    packs_count: Dict[str, int] = {}
    for p in procs:
        packs_count[p["pack"]] = packs_count.get(p["pack"], 0) + 1

    print("\n" + "=" * 50)
    print("  Ethical Hacker Squad — Corpus Stats")
    print("=" * 50)
    for pack, count in sorted(packs_count.items()):
        print(f"  {pack:<20} : {count:>3} procedures")
    print("-" * 50)
    print(f"  {'TOTAL':<20} : {len(procs):>3} procedures\n")
    return 0


def cmd_doctor(args: argparse.Namespace) -> int:
    """Run environment and quality gate health checks."""
    print("\n" + "=" * 60)
    print("  Ethical Hacker Squad — Doctor Diagnostic Check")
    print("=" * 60)

    tools = ["git", "python3", "bash", "curl", "tar", "shasum"]
    print("▶ System Tools:")
    for t in tools:
        found = shutil.which(t) is not None
        status = "OK" if found else "MISSING"
        print(f"  [{status:<7}] {t}")

    gates_runner = ROOT / "scripts" / "gates" / "run-all.sh"
    if gates_runner.exists():
        print("\n▶ Quality Gates Validation:")
        res = subprocess.run(["bash", str(gates_runner)], cwd=str(ROOT), capture_output=True, text=True)
        if res.returncode == 0:
            print("  [OK     ] All Quality Gates are green (exit 0)")
        elif res.returncode == 2:
            print("  [WARN   ] Quality Gates finished with unmeasurable checks (exit 2)")
        else:
            print(f"  [FAIL   ] Quality Gates failed (exit {res.returncode})")
    print()
    return 0


def cmd_install(args: argparse.Namespace) -> int:
    """Install/link skill to Antigravity and/or Claude Code."""
    home = Path.home()
    source_skill = ROOT / "skills" / "ethical-hacker-squad"

    if not source_skill.exists():
        print(f"Error: Source skill not found at {source_skill}", file=sys.stderr)
        return 2

    installed = []

    if args.antigravity or args.all or not (args.claude or args.antigravity):
        agy_target = home / ".gemini" / "antigravity-cli" / "skills" / "ethical-hacker-squad"
        try:
            agy_target.parent.mkdir(parents=True, exist_ok=True)
            if agy_target.is_symlink():
                agy_target.unlink()
            elif agy_target.exists():
                shutil.rmtree(agy_target)
            agy_target.symlink_to(source_skill, target_is_directory=True)
            installed.append(f"Antigravity CLI -> {agy_target}")
        except Exception as e:
            print(f"Warning: Could not link to Antigravity ({e})", file=sys.stderr)

    if args.claude or args.all:
        claude_target = home / ".claude" / "plugins" / "ethical-hacker-squad"
        try:
            claude_target.parent.mkdir(parents=True, exist_ok=True)
            if claude_target.is_symlink():
                claude_target.unlink()
            elif claude_target.exists():
                shutil.rmtree(claude_target)
            claude_target.symlink_to(ROOT, target_is_directory=True)
            installed.append(f"Claude Code -> {claude_target}")
        except Exception as e:
            print(f"Warning: Could not link to Claude Code ({e})", file=sys.stderr)

    if installed:
        print("\nSuccessfully installed/linked Ethical Hacker Squad:")
        for item in installed:
            print(f"  ✓ {item}")
        print()
        return 0
    else:
        print("No installation targets selected.")
        return 1


# GitHub reads a rule's `security-severity` as a CVSS-like score and buckets it:
# >= 9.0 critical, 7.0-8.9 high, 4.0-6.9 medium, 0.1-3.9 low. `informational`
# gets no score on purpose: zero would still be read as a severity.
SARIF_LEVEL = {"critical": "error", "high": "error", "medium": "warning",
               "low": "note", "informational": "note"}
SECURITY_SEVERITY = {"critical": 9.5, "high": 8.0, "medium": 5.5, "low": 3.0}
# What a reader of a code-scanning alert may act on. `discarded` and
# `withdrawn` are the squad saying "this is not a finding"; exporting them would
# turn its own refutations into alerts.
SARIF_KIND = {"confirmed": "fail", "probable": "review", "hardening": "informational"}
# The same high-precision formats the findings validator refuses. SARIF gets
# uploaded, so this file is refused here too rather than trusted upstream.
UNREDACTED_SECRET = re.compile(
    r"gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|sk-ant-[A-Za-z0-9_-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----")


def findings_to_sarif(artifact: Dict[str, Any], titles: Dict[str, str]) -> Dict[str, Any]:
    """Map a findings.json deliverable onto one SARIF 2.1.0 run."""
    results: List[Dict[str, Any]] = []
    rules: Dict[str, Dict[str, Any]] = {}
    for f in artifact.get("findings", []):
        kind = SARIF_KIND.get(f.get("status", ""))
        if kind is None or f.get("duplicate_of"):
            continue
        rule_id = f["procedure"]
        severity = f.get("severity", "")
        rule = rules.setdefault(rule_id, {
            "id": rule_id,
            "name": rule_id,
            "shortDescription": {"text": titles.get(rule_id, "Finding outside any corpus procedure")},
            "properties": {"tags": ["security"]},
        })
        tags = rule["properties"]["tags"]
        tags.extend(t for t in f.get("traceability", []) if t not in tags)
        # A rule carries ONE score in SARIF and a procedure can produce findings
        # of different severities, so the rule keeps the highest; each result
        # still carries its own level and its own severity in properties.
        score = SECURITY_SEVERITY.get(severity)
        if score is not None and score > float(rule["properties"].get("security-severity", "0")):
            rule["properties"]["security-severity"] = f"{score:.1f}"

        physical: Dict[str, Any] = {"artifactLocation": {"uri": f["location"]["path"]}}
        if f["location"].get("line"):
            physical["region"] = {"startLine": f["location"]["line"]}
        text = f["title"].rstrip(".") + ". " + f.get("impact", "")
        results.append({
            "ruleId": rule_id,
            "kind": kind,
            "level": "note" if kind == "informational" else SARIF_LEVEL.get(severity, "warning"),
            "message": {"text": text.strip()},
            "locations": [{"physicalLocation": physical}],
            "partialFingerprints": {"ehsFinding/v1": f"{rule_id}:{f['location']['path']}:{f['location'].get('line', 0)}"},
            "properties": {k: f[k] for k in ("id", "status", "severity", "confidence") if k in f},
        })
    return {
        "$schema": "https://docs.oasis-open.org/sarif/sarif/v2.1.0/errata01/os/schemas/sarif-schema-2.1.0.json",
        "version": "2.1.0",
        "runs": [{
            "tool": {"driver": {
                "name": "ethical-hacker-squad",
                "informationUri": "https://github.com/CristianAjavi/ethical-hacker-squad",
                "rules": [rules[k] for k in sorted(rules)],
            }},
            "results": results,
        }],
    }


def cmd_sarif(args: argparse.Namespace) -> int:
    """Convert a findings.json deliverable into SARIF 2.1.0 for code scanning."""
    try:
        raw = Path(args.findings).read_text(encoding="utf-8")
        artifact = json.loads(raw)
    except (OSError, UnicodeDecodeError, ValueError) as e:
        print(f"Error: cannot read {args.findings} as JSON ({e})", file=sys.stderr)
        return 2
    if not isinstance(artifact, dict) or not isinstance(artifact.get("findings"), list):
        print(f"Error: {args.findings} has no `findings` list; is it a findings.json deliverable?",
              file=sys.stderr)
        return 2
    if UNREDACTED_SECRET.search(raw):
        print("Error: the artifact carries an unredacted secret in a high-precision format. "
              "Nothing was written: SARIF is uploaded, and this would publish it. Redact it and "
              "run scripts/gates/gate-findings-artifact.sh --deliverable first.", file=sys.stderr)
        return 1
    try:
        titles = {p["id"]: p["title"] for p in parse_procedures(ROOT)}
        sarif = findings_to_sarif(artifact, titles)
    except (KeyError, TypeError) as e:
        print(f"Error: a finding is missing a required field ({e}); validate the artifact with "
              "scripts/gates/gate-findings-artifact.sh --deliverable first.", file=sys.stderr)
        return 2
    out = json.dumps(sarif, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        Path(args.output).write_text(out, encoding="utf-8")
        exported = len(sarif["runs"][0]["results"])
        print(f"Wrote {args.output}: {exported} result(s) of {len(artifact['findings'])} finding(s). "
              "Uploading it publishes them to GitHub code scanning; that is the user's call.",
              file=sys.stderr)
    else:
        sys.stdout.write(out)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Ethical Hacker Squad CLI tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    subparsers = parser.add_subparsers(dest="command", help="Command to run")

    # list
    p_list = subparsers.add_parser("list", help="List procedures by pack")
    p_list.add_argument("pack", nargs="?", help="Optional pack name filter (e.g. web-api, ai-safety)")

    # show
    p_show = subparsers.add_parser("show", help="Show full procedure by ID")
    p_show.add_argument("id", help="Procedure ID (e.g. WEB-01, AI-08, INF-04)")

    # search
    p_search = subparsers.add_parser("search", help="Search procedures by keyword")
    p_search.add_argument("query", help="Keyword or topic to search for")

    # stats
    subparsers.add_parser("stats", help="Show corpus metrics summary")

    # doctor
    subparsers.add_parser("doctor", help="Run health diagnostics and quality gates")

    # install
    p_install = subparsers.add_parser("install", help="Link/install skill for CLI environments")
    p_install.add_argument("--antigravity", action="store_true", help="Install to Antigravity CLI")
    p_install.add_argument("--claude", action="store_true", help="Install to Claude Code")
    p_install.add_argument("--all", action="store_true", help="Install to all supported environments")

    # sarif
    p_sarif = subparsers.add_parser("sarif", help="Convert a findings.json deliverable to SARIF 2.1.0")
    p_sarif.add_argument("findings", help="Path to findings.json")
    p_sarif.add_argument("-o", "--output", help="Write to this file instead of stdout")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 0

    commands = {
        "list": cmd_list,
        "show": cmd_show,
        "search": cmd_search,
        "stats": cmd_stats,
        "doctor": cmd_doctor,
        "install": cmd_install,
        "sarif": cmd_sarif,
    }

    handler = commands.get(args.command)
    if handler:
        return handler(args)
    parser.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
