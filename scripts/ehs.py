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
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

sys.path.insert(0, str(Path(__file__).resolve().parent / "gates" / "lib"))
from secret_formats import find_unredacted_secrets  # noqa: E402  one list, shared with the validators


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


CLAUDE_INSTALL = (
    "claude plugin marketplace add {root}\n"
    "claude plugin install ethical-hacker-squad@ethical-hacker-squad"
)


def cmd_install(args: argparse.Namespace) -> int:
    """Install for Claude Code (as a plugin) and/or link the skill for Antigravity.

    With no target flag it installs nothing and prints how to: the default used
    to be Antigravity, and it replaced an existing directory there with
    `shutil.rmtree` - a user's own files, deleted by a command run with no
    arguments. It never deletes a real directory now; only a symlink it can
    replace.
    """
    source_skill = ROOT / "skills" / "ethical-hacker-squad"
    if not source_skill.exists():
        print(f"Error: Source skill not found at {source_skill}", file=sys.stderr)
        return 2

    if not (args.claude or args.antigravity or args.all):
        print("Nothing was installed. Choose a target:\n"
              "  scripts/ehs install --claude       the plugin, with its nine subagents (recommended)\n"
              "  scripts/ehs install --antigravity  link the skill into ~/.gemini/antigravity-cli/skills\n"
              "  scripts/ehs install --all          both\n\n"
              "Or, inside Claude Code 2.1.275 or later, from GitHub:\n"
              "  /plugin install ethical-hacker-squad --marketplace CristianAjavi/ethical-hacker-squad")
        return 0

    installed, failed = [], []

    if args.claude or args.all:
        claude = shutil.which("claude")
        commands = CLAUDE_INSTALL.format(root=ROOT)
        if claude is None:
            failed.append("Claude Code: the `claude` binary is not on PATH. Run, once it is:\n" + commands)
        else:
            ok = True
            for cmd in ([claude, "plugin", "marketplace", "add", str(ROOT)],
                        [claude, "plugin", "install", "ethical-hacker-squad@ethical-hacker-squad"]):
                proc = subprocess.run(cmd, capture_output=True, text=True)
                if proc.returncode != 0:
                    ok = False
                    failed.append(f"Claude Code: `{' '.join(cmd[1:])}` exited {proc.returncode}: "
                                  f"{(proc.stderr or proc.stdout).strip()[:300]}")
                    break
            if ok:
                installed.append("Claude Code plugin ethical-hacker-squad (marketplace "
                                 f"{ROOT}); restart Claude Code to load it. It installs the "
                                 "published `dist` branch; to try this working copy instead, run "
                                 f"`claude --plugin-dir {ROOT}`")

    if args.antigravity or args.all:
        agy_target = Path.home() / ".gemini" / "antigravity-cli" / "skills" / "ethical-hacker-squad"
        try:
            agy_target.parent.mkdir(parents=True, exist_ok=True)
            if agy_target.is_symlink():
                agy_target.unlink()
            elif agy_target.exists():
                raise FileExistsError(f"{agy_target} exists and is not a link this command made; "
                                      "move it away yourself, nothing was deleted")
            agy_target.symlink_to(source_skill, target_is_directory=True)
            installed.append(f"Antigravity CLI -> {agy_target}")
        except OSError as e:
            failed.append(f"Antigravity CLI: {e}")

    for item in installed:
        print(f"  ✓ {item}")
    for item in failed:
        print(f"  ✗ {item}", file=sys.stderr)
    return 1 if failed else 0


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
CWE_ID = re.compile(r"^CWE-(\d+)$")
CORPUS_URL = ("https://github.com/CristianAjavi/ethical-hacker-squad/blob/main/"
              "skills/ethical-hacker-squad/references/knowledge/")
MAX_TAGS = 20  # GitHub keeps 20 tags per rule and shows 10


def repo_relative(path: str) -> str:
    """`./src/a.py` and `src/a.py` are one file; `.github/` keeps its dot."""
    while path.startswith("./"):
        path = path[2:]
    return path


def sarif_rule_id(f: Dict[str, Any], procedures: Dict[str, Dict[str, Any]]) -> str:
    """The procedure, or an ad-hoc rule per weakness class, never one bucket."""
    proc = f["procedure"]
    if proc in procedures:
        return proc
    cwes = [t for t in f.get("traceability", []) if CWE_ID.match(t)]
    return f"ad-hoc/{cwes[0]}" if cwes else f"ad-hoc/{f['id']}"


def sarif_rule(rule_id: str, procedures: Dict[str, Dict[str, Any]]) -> Dict[str, Any]:
    proc = procedures.get(rule_id)
    if proc is None:
        text = ("Reported outside every corpus procedure. Nothing in the corpus states how this "
                "class is ruled out or tested; the result's message and the report carry the "
                "evidence and the recommendation.")
        return {"id": rule_id, "name": rule_id,
                "shortDescription": {"text": "Finding outside any corpus procedure"},
                "help": {"text": text, "markdown": text},
                "properties": {"tags": ["security"]}}
    fields = proc.get("fields", {})
    url = CORPUS_URL + proc["file"]
    parts = [(label, fields.get(key, "").strip()) for label, key in (
        ("Vulnerable pattern", "vulnerable_pattern"),
        ("What rules it out", "rules_it_out"),
        ("Minimal test", "minimal_test"))]
    markdown = f"**{rule_id} {proc['title']}**\n\n" + "\n\n".join(
        f"**{label}**\n\n{body}" for label, body in parts if body) + f"\n\nProcedure: {url}"
    text = f"{rule_id} {proc['title']}. " + " ".join(
        f"{label}: {' '.join(body.split())}" for label, body in parts if body) + f" Procedure: {url}"
    return {"id": rule_id, "name": rule_id,
            "shortDescription": {"text": proc["title"]},
            "helpUri": url,
            "help": {"text": text, "markdown": markdown},
            "properties": {"tags": ["security"]}}


def sarif_fingerprint(rule_id: str, f: Dict[str, Any], seen: Dict[str, int]) -> str:
    """Stable across line moves: rule, file and component, never the line.

    Two findings of the same rule in the same component get an ordinal in line
    order, so they stay distinct; inserting a third above them renumbers them,
    which is the price of not hashing the line. GitHub computes its own
    `primaryLocationLineHash` from the source on upload; this key is what
    `scripts/ehs` itself uses to match a finding across runs.
    """
    loc = f["location"]
    base = "|".join((rule_id, repo_relative(loc["path"]), loc.get("component", "")))
    seen[base] = seen.get(base, 0) + 1
    return hashlib.sha256(f"{base}|{seen[base]}".encode("utf-8")).hexdigest()[:32]


def findings_to_sarif(artifact: Dict[str, Any], procedures: Dict[str, Dict[str, Any]],
                      category: str = "ethical-hacker-squad") -> Dict[str, Any]:
    """Map a findings.json deliverable onto one SARIF 2.1.0 run."""
    results: List[Dict[str, Any]] = []
    rules: Dict[str, Dict[str, Any]] = {}
    seen: Dict[str, int] = {}
    exported = [f for f in artifact.get("findings", [])
                if SARIF_KIND.get(f.get("status", "")) and not f.get("duplicate_of")]
    exported.sort(key=lambda f: (f["location"]["path"], f["location"].get("line") or 0))
    for f in exported:
        kind = SARIF_KIND[f["status"]]
        rule_id = sarif_rule_id(f, procedures)
        severity = f.get("severity", "")
        rule = rules.setdefault(rule_id, sarif_rule(rule_id, procedures))
        tags = rule["properties"]["tags"]
        for t in f.get("traceability", []):
            m = CWE_ID.match(t)
            for tag in ((f"external/cwe/cwe-{m.group(1)}", t) if m else (t,)):
                if tag not in tags and len(tags) < MAX_TAGS:
                    tags.append(tag)
        # A rule carries ONE score in SARIF and a procedure can produce findings
        # of different severities, so the rule keeps the highest; each result
        # still carries its own level and its own severity in properties.
        score = SECURITY_SEVERITY.get(severity)
        if score is not None and score > float(rule["properties"].get("security-severity", "0")):
            rule["properties"]["security-severity"] = f"{score:.1f}"

        physical: Dict[str, Any] = {"artifactLocation": {
            "uri": repo_relative(f["location"]["path"]), "uriBaseId": "SRCROOT"}}
        if f["location"].get("line"):
            physical["region"] = {"startLine": f["location"]["line"]}
        text = f["title"].rstrip(".") + ". " + f.get("impact", "")
        results.append({
            "ruleId": rule_id,
            "kind": kind,
            # SARIF 2.1.0 3.27.10: a result whose kind is not `fail` SHALL have
            # level `none`. A `probable` finding asks for review; it does not
            # assert a failure, and its severity still travels in properties.
            "level": SARIF_LEVEL.get(severity, "warning") if kind == "fail" else "none",
            "message": {"text": text.strip()},
            "locations": [{"physicalLocation": physical}],
            "partialFingerprints": {"ehsFinding/v2": sarif_fingerprint(rule_id, f, seen)},
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
            # A trailing slash makes the whole id the category: every upload of
            # the same category replaces the previous one, which is what closes
            # an alert once the finding is gone.
            "automationDetails": {"id": category.strip("/") + "/"},
            "originalUriBaseIds": {"SRCROOT": {
                "description": {"text": "The root of the audited repository; every path is relative to it."}}},
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
    leaked = find_unredacted_secrets(raw)
    if leaked:
        print("Error: the artifact carries an unredacted secret (" + ", ".join(sorted(set(leaked))) +
              "). Nothing was written: SARIF is uploaded, and this would publish it. Redact it and "
              "run scripts/gates/gate-findings-artifact.sh --deliverable first.", file=sys.stderr)
        return 1
    if any(Path(f.get("location", {}).get("path", "")).is_absolute()
           for f in artifact["findings"] if isinstance(f, dict)):
        print("Error: a finding carries an absolute path. Code scanning resolves paths from the "
              "repository root; write them relative to it.", file=sys.stderr)
        return 2
    try:
        procedures = {p["id"]: p for p in parse_procedures(ROOT)}
        sarif = findings_to_sarif(artifact, procedures, args.category)
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


# ---------------------------------------------------------------------------
# prescan: deterministic leads before any model reads the code
# ---------------------------------------------------------------------------
SKIP_DIRS = {".git", "node_modules", ".next", "dist", "build", "out", ".venv", "venv",
             "__pycache__", "coverage", ".turbo", ".vercel", "vendor", ".svelte-kit", ".nuxt"}
TEXT_EXT = {".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".vue", ".svelte", ".astro", ".py",
            ".rb", ".go", ".php", ".sql", ".rules", ".json", ".toml", ".yaml", ".yml", ".env"}
SESSION_READ = re.compile(
    r"\bauth\(\)|getServerSession|currentUser\(|auth\.getUser\(|getClaims\(|auth\.protect\(|"
    r"getSession\(|requireUser|verifyIdToken|validateRequest\(|withAuth|clerkClient|getAuth\(")
PUBLIC_SECRETISH = re.compile(
    r"\b((?:NEXT_PUBLIC|VITE|REACT_APP|EXPO_PUBLIC|GATSBY|NUXT_PUBLIC|PUBLIC)_[A-Z0-9_]*"
    r"(?:SECRET|SERVICE_ROLE|PRIVATE|PASSWORD|TOKEN|_KEY)[A-Z0-9_]*)\b")
PUBLIC_BY_DESIGN = re.compile(r"ANON|PUBLISHABLE|PUBLIC_KEY|FIREBASE|SITE_KEY|MEASUREMENT|MAPS|POSTHOG|SENTRY_DSN")
LLM_IMPORT = re.compile(r"from ['\"](openai|@anthropic-ai/sdk|ai|@ai-sdk/[a-z-]+|@google/generative-ai|groq-sdk)['\"]|require\(['\"](openai|@anthropic-ai/sdk)['\"]\)")
NEXT_VULN = [((11, 1, 4), (12, 3, 5)), ((13, 0, 0), (13, 5, 9)), ((14, 0, 0), (14, 2, 25)), ((15, 0, 0), (15, 2, 3))]


def _walk(target: Path):
    for dirpath, dirnames, filenames in os.walk(target):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            p = Path(dirpath) / name
            if p.suffix in TEXT_EXT or name.startswith(".env") or name in ("package.json",):
                try:
                    if p.stat().st_size <= 1_000_000:
                        yield p
                except OSError:
                    continue


def _line_of(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def _exported_functions(text: str):
    """(name, line, body) of each exported function, braces matched naively."""
    pat = re.compile(r"export\s+(?:default\s+)?(?:async\s+)?function\s+(\w+)\s*\(|"
                     r"export\s+const\s+(\w+)\s*=\s*(?:async\s*)?\([^)]*\)\s*(?::[^=]+)?=>\s*")
    for m in pat.finditer(text):
        start = text.find("{", m.end() - 1)
        if start < 0:
            continue
        depth, i = 0, start
        while i < len(text):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        yield (m.group(1) or m.group(2)), _line_of(text, m.start()), text[start:i + 1]


def prescan(target: Path) -> List[Dict[str, Any]]:
    """Leads, not findings: each names the procedure that decides it."""
    leads: List[Dict[str, Any]] = []
    sql: Dict[str, str] = {}

    def lead(rule, procedure, path, line, text):
        leads.append({"rule": rule, "procedure": procedure,
                      "path": str(path.relative_to(target)), "line": line, "lead": text})

    for p in sorted(_walk(target)):
        try:
            text = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        rel = str(p.relative_to(target))
        if p.suffix == ".sql":
            sql[rel] = text
        # secrets in any format the deliverables refuse; never the value
        if not rel.endswith(("package-lock.json", "pnpm-lock.yaml", "yarn.lock")):
            for fid in find_unredacted_secrets(text):
                lead("secret-format", "SUP-16", p, None, f"a value in the `{fid}` format (not shown)")
        for m in PUBLIC_SECRETISH.finditer(text):
            if not PUBLIC_BY_DESIGN.search(m.group(1)):
                lead("public-prefix-secret-name", "SUP-27", p, _line_of(text, m.start()),
                     f"`{m.group(1)}` is named like a secret behind a public build prefix")
                break
        if p.name == "config.toml" and "supabase" in rel:
            for m in re.finditer(r"verify_jwt\s*=\s*false", text):
                lead("edge-function-verify-jwt-off", "WEB-32", p, _line_of(text, m.start()),
                     "an Edge Function with `verify_jwt = false`")
        if "--no-verify-jwt" in text and p.suffix in (".json", ".yml", ".yaml", ".toml"):
            lead("edge-function-verify-jwt-off", "WEB-32", p, None, "a deploy with `--no-verify-jwt`")
        if p.suffix == ".rules" or p.name == "database.rules.json":
            for m in re.finditer(r"if\s+true|request\.time\s*<|request\.auth\s*!=\s*null|\"\.(read|write)\"\s*:\s*true", text):
                lead("firebase-open-rule", "WEB-30", p, _line_of(text, m.start()),
                     f"a rule that does not name the owner: `{m.group(0)}`")
        is_ts = p.suffix in (".ts", ".tsx", ".js", ".jsx", ".mjs")
        if is_ts and re.search(r"^\s*['\"]use server['\"]", text, re.M):
            # Per exported function: a module where one action checks the session
            # says nothing about the action beside it.
            for name, line, body in _exported_functions(text):
                if not SESSION_READ.search(body):
                    lead("server-action-without-session", "WEB-33", p, line,
                         f"Server Action `{name}` never reads the session")
        in_api = re.search(r"(^|/)(app/.*/route\.(t|j)sx?|pages/api/.*)$", rel)
        if is_ts and in_api:
            if not SESSION_READ.search(text) and not re.search(r"constructEvent|CRON_SECRET", text):
                if LLM_IMPORT.search(text):
                    lead("llm-route-without-session", "AI-19", p, None,
                         "a route that calls a model API and never reads the session")
                else:
                    lead("route-without-session", "WEB-33", p, None, "a route handler that never reads the session")
            if re.search(r"webhook", rel, re.I) and re.search(r"stripe|checkout\.session", text, re.I) \
                    and "constructEvent" not in text:
                lead("stripe-webhook-unverified", "WEB-36", p, None,
                     "a Stripe webhook route with no `constructEvent` call")
            m = re.search(r"unit_amount\s*:\s*(?!\d)[A-Za-z_$][\w.$]*", text)
            if m and re.search(r"req(uest)?\.json\(\)|formData\(\)|searchParams", text):
                lead("client-chosen-price", "WEB-36", p, _line_of(text, m.start()),
                     "`unit_amount` taken from a variable in a route that reads the request body")
            if re.search(r"Bearer \$\{process\.env\.CRON_SECRET\}", text) and \
                    not re.search(r"!\s*process\.env\.CRON_SECRET|!\s*cronSecret|CRON_SECRET\s*\)\s*(\|\||throw)", text):
                lead("cron-secret-fails-open", "WEB-35", p, None,
                     "compares `Bearer ${process.env.CRON_SECRET}` with no guard for an unset secret")
        if p.name in ("middleware.ts", "middleware.js", "proxy.ts", "proxy.js") and \
                re.search(r"matcher[\s\S]{0,300}\(\?!\s*api", text):
            lead("matcher-skips-api", "WEB-34", p, None,
                 "the matcher excludes `/api`: every API route must check the session itself")
        if p.name == "package.json":
            m = re.search(r'"next"\s*:\s*"[~^]?(\d+)\.(\d+)\.(\d+)', text)
            if m:
                v = tuple(int(x) for x in m.groups())
                if any(lo <= v < hi for lo, hi in NEXT_VULN):
                    lead("next-cve-2025-29927", "WEB-34", p, None,
                         f"next {'.'.join(map(str, v))} is in the CVE-2025-29927 range; it matters only when self-hosted")

    # Supabase: a table created in a migration that no migration puts under RLS
    created: Dict[str, str] = {}
    rls = set()
    for rel, text in sql.items():
        for m in re.finditer(r"create\s+table\s+(?:if\s+not\s+exists\s+)?([\w.\"]+)", text, re.I):
            name = m.group(1).replace('"', "").split(".")[-1]
            created.setdefault(name, rel)
        for m in re.finditer(r"alter\s+table\s+(?:only\s+)?([\w.\"]+)\s+enable\s+row\s+level\s+security", text, re.I):
            rls.add(m.group(1).replace('"', "").split(".")[-1])
        for m in re.finditer(r"create\s+policy[\s\S]{0,300}?(using\s*\(\s*true\s*\)|auth\.uid\(\)\s+is\s+not\s+null|user_metadata)", text, re.I):
            leads.append({"rule": "policy-does-not-bind-owner", "procedure": "WEB-29", "path": rel,
                          "line": _line_of(text, m.start()), "lead": f"a policy built on `{m.group(1)}`"})
        for m in re.finditer(r"create\s+table\s+(?:if\s+not\s+exists\s+)?([\w.\"]+)\s*\(([\s\S]*?)\);", text, re.I):
            name = m.group(1).replace('"', "").split(".")[-1]
            if re.search(r"\b(role|is_admin|plan|tier|credits)\b", m.group(2)) and \
                    re.search(rf"for\s+(update|all)[\s\S]{{0,80}}" , text, re.I) and \
                    re.search(rf"on\s+[\w.\"]*{re.escape(name)}\b[\s\S]{{0,40}}for\s+(update|all)", text, re.I) and \
                    not re.search(rf"revoke\s+update\s+on\s+(table\s+)?[\w.\"]*{re.escape(name)}\b", text, re.I):
                leads.append({"rule": "owner-can-write-privilege-column", "procedure": "WEB-31", "path": rel,
                              "line": _line_of(text, m.start()),
                              "lead": f"`{name}` has a privilege column and an update policy, and no column grant"})
    for name, rel in sorted(created.items()):
        if name not in rls:
            leads.append({"rule": "table-without-rls", "procedure": "WEB-29", "path": rel, "line": None,
                          "lead": f"`{name}` is created and never put under row-level security"})
    return leads


def cmd_prescan(args: argparse.Namespace) -> int:
    """Deterministic leads for an app built fast, before any model reads it."""
    target = Path(args.target).resolve()
    if not target.is_dir():
        print(f"Error: {target} is not a directory", file=sys.stderr)
        return 2
    leads = prescan(target)
    if args.json:
        print(json.dumps({"target": str(target), "leads": leads}, indent=2))
        return 0
    if not leads:
        print("No leads. That is not a clean bill: these are pattern checks, and the squad still reads the code.")
        return 0
    print(f"{len(leads)} lead(s) in {target} — leads, not findings: each names the procedure that decides it.\n")
    for l in leads:
        where = l["path"] + (f":{l['line']}" if l["line"] else "")
        print(f"  {l['procedure']:<7} {where}\n          {l['lead']}")
    return 0


# ---------------------------------------------------------------------------
# compare: what is new, what is gone, what is suppressed, across two runs
# ---------------------------------------------------------------------------
SEVERITY_ORDER = {"informational": 0, "low": 1, "medium": 2, "high": 3, "critical": 4}


def fingerprints(artifact: Dict[str, Any], procedures: Dict[str, Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
    seen: Dict[str, int] = {}
    out: Dict[str, Dict[str, Any]] = {}
    rows = [f for f in artifact.get("findings", [])
            if SARIF_KIND.get(f.get("status", "")) and not f.get("duplicate_of")]
    rows.sort(key=lambda f: (f["location"]["path"], f["location"].get("line") or 0))
    for f in rows:
        out[sarif_fingerprint(sarif_rule_id(f, procedures), f, seen)] = f
    return out


def cmd_compare(args: argparse.Namespace) -> int:
    """Compare two findings.json deliverables by stable fingerprint."""
    try:
        before = json.loads(Path(args.before).read_text(encoding="utf-8"))
        after = json.loads(Path(args.after).read_text(encoding="utf-8"))
        suppress = json.loads(Path(args.suppress).read_text(encoding="utf-8")) if args.suppress else []
    except (OSError, ValueError) as e:
        print(f"Error: {e}", file=sys.stderr)
        return 2
    procedures = {p["id"]: p for p in parse_procedures(ROOT)}
    try:
        a, b = fingerprints(before, procedures), fingerprints(after, procedures)
    except (KeyError, TypeError) as e:
        print(f"Error: a finding is missing a required field ({e}); validate both artifacts first.", file=sys.stderr)
        return 2
    today = __import__("datetime").date.today().isoformat()
    active, expired = {}, []
    for s in suppress if isinstance(suppress, list) else []:
        if s.get("expires") and s["expires"] < today:
            expired.append(s)
        elif s.get("fingerprint") and s.get("reason"):
            active[s["fingerprint"]] = s
    new = [k for k in b if k not in a]
    gone = [k for k in a if k not in b]
    kept = [k for k in b if k in a]
    report = {
        "new": [dict(fingerprint=k, **{f: b[k].get(f) for f in ("id", "procedure", "severity", "status", "title")},
                     path=b[k]["location"]["path"], suppressed=k in active) for k in new],
        "gone": [dict(fingerprint=k, **{f: a[k].get(f) for f in ("id", "procedure", "severity", "status", "title")},
                      path=a[k]["location"]["path"]) for k in gone],
        "persisting": [dict(fingerprint=k, id=b[k].get("id"), procedure=b[k].get("procedure"),
                            severity=b[k].get("severity"), was=a[k].get("status"), now=b[k].get("status"),
                            suppressed=k in active) for k in kept],
        "expired_suppressions": expired,
    }
    floor = SEVERITY_ORDER.get(args.fail_on, 99) if args.fail_on else 99
    blocking = [n for n in report["new"] if not n["suppressed"]
                and SEVERITY_ORDER.get(n.get("severity") or "", 0) >= floor]
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(f"new: {len(new)}  gone: {len(gone)}  persisting: {len(kept)}  "
              f"suppressed: {sum(1 for r in report['new'] + report['persisting'] if r['suppressed'])}")
        for n in report["new"]:
            print(f"  + {n['procedure']:<12} {n['severity'] or '-':<13} {n['path']}  {n['title']}"
                  + ("  [suppressed]" if n["suppressed"] else ""))
        for g in report["gone"]:
            print(f"  - {g['procedure']:<12} {g['severity'] or '-':<13} {g['path']}  {g['title']}")
        for s in expired:
            print(f"  ! suppression {s.get('fingerprint')} expired on {s.get('expires')}: it no longer hides anything")
        print("Gone means absent from the second run, not fixed: a narrower run also loses findings.")
    return 1 if blocking else 0


# ---------------------------------------------------------------------------
# cost: what a run spent, read from Claude Code's own transcripts
# ---------------------------------------------------------------------------
def _usage(path: Path) -> Dict[str, Dict[str, int]]:
    per_model: Dict[str, Dict[str, int]] = {}
    last: Dict[str, Tuple[str, Dict[str, Any]]] = {}
    with path.open(encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            m = d.get("message") or {}
            u = m.get("usage")
            if isinstance(u, dict):
                # one assistant message is written once per content block, each
                # carrying the same usage: count every message once
                last[m.get("id") or d.get("requestId") or d.get("uuid")] = (m.get("model") or "?", u)
    for model, u in last.values():
        acc = per_model.setdefault(model, {"input": 0, "cache_write": 0, "cache_read": 0, "output": 0, "messages": 0})
        acc["input"] += int(u.get("input_tokens") or 0)
        acc["cache_write"] += int(u.get("cache_creation_input_tokens") or 0)
        acc["cache_read"] += int(u.get("cache_read_input_tokens") or 0)
        acc["output"] += int(u.get("output_tokens") or 0)
        acc["messages"] += 1
    return per_model


def cmd_cost(args: argparse.Namespace) -> int:
    """Tokens a session spent, main thread and every subagent, from its transcripts."""
    base = Path(args.projects_dir).expanduser()
    if args.session:
        mains = sorted(base.glob(f"*/{args.session}.jsonl"))
    else:
        # The session still running is the newest transcript of the project
        # Claude Code keys by the working directory, every non-alphanumeric
        # character turned into "-".
        project = base / re.sub(r"[^A-Za-z0-9]", "-", os.getcwd())
        mains = sorted(project.glob("*.jsonl"), key=lambda p: p.stat().st_mtime)[-1:]
    if not mains:
        print(f"Error: no transcript for session {args.session or '(latest)'} under {base}", file=sys.stderr)
        return 2
    main_path = mains[0]
    session = main_path.stem
    rows = [("leader (main thread)", main_path)]
    for sub in sorted((main_path.parent / session / "subagents").glob("*.jsonl")):
        label = sub.stem
        meta = sub.with_suffix(".meta.json")
        try:
            m = json.loads(meta.read_text(encoding="utf-8"))
            label = f"{m.get('agentType', '?')}: {m.get('description', sub.stem)}"
        except (OSError, ValueError):
            pass
        rows.append((label, sub))
    total = {"input": 0, "cache_write": 0, "cache_read": 0, "output": 0, "messages": 0}
    out = []
    for label, path in rows:
        for model, acc in _usage(path).items():
            out.append({"agent": label, "model": model, **acc})
            for k in total:
                total[k] += acc[k]
    if args.json:
        print(json.dumps({"session": session, "rows": out, "total": total}, indent=2))
        return 0
    print(f"session {session}: {len(rows)} transcript(s)\n")
    print(f"  {'agent':<46} {'model':<22} {'input':>9} {'cache wr':>10} {'cache rd':>11} {'output':>9}")
    for r in out:
        print(f"  {r['agent'][:46]:<46} {r['model'][:22]:<22} {r['input']:>9,} {r['cache_write']:>10,} "
              f"{r['cache_read']:>11,} {r['output']:>9,}")
    print(f"  {'TOTAL':<46} {'':<22} {total['input']:>9,} {total['cache_write']:>10,} "
          f"{total['cache_read']:>11,} {total['output']:>9,}")
    print("\nTokens only: prices change and depend on the plan, so no currency figure is printed here.")
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
    p_sarif.add_argument("--category", default="ethical-hacker-squad",
                         help="Code-scanning category (automationDetails.id); one per analysis you upload")

    # prescan
    p_pre = subparsers.add_parser("prescan", help="Deterministic leads in a target before any model reads it")
    p_pre.add_argument("target", help="Directory to scan (read-only)")
    p_pre.add_argument("--json", action="store_true", help="Machine-readable output")

    # compare
    p_cmp = subparsers.add_parser("compare", help="Compare two findings.json by stable fingerprint")
    p_cmp.add_argument("before", help="The earlier findings.json (the baseline)")
    p_cmp.add_argument("after", help="The later findings.json")
    p_cmp.add_argument("--suppress", help="JSON list of {fingerprint, reason, expires} to accept")
    p_cmp.add_argument("--fail-on", choices=sorted(SEVERITY_ORDER, key=SEVERITY_ORDER.get),
                       help="Exit 1 when a new, unsuppressed finding is at least this severe")
    p_cmp.add_argument("--json", action="store_true", help="Machine-readable output")

    # cost
    p_cost = subparsers.add_parser("cost", help="Tokens a Claude Code session spent, per agent")
    p_cost.add_argument("--session", help="Session id; without it, the newest session of the current directory")
    p_cost.add_argument("--projects-dir", default="~/.claude/projects", help="Where Claude Code keeps transcripts")
    p_cost.add_argument("--json", action="store_true", help="Machine-readable output")

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
        "prescan": cmd_prescan,
        "compare": cmd_compare,
        "cost": cmd_cost,
    }

    handler = commands.get(args.command)
    if handler:
        return handler(args)
    parser.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
