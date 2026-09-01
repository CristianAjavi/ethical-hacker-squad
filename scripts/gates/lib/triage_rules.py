#!/usr/bin/env python3
"""Measurement core of gate-triage-rules.sh.

Checks that the triage rule set exists, is closed, is cited only by real ids,
and that the packs declared converted really are — with a ratchet so the ones
still being converted can only move forwards.

  1. rules        triage.md declares FP-01..FP-NN inside its marked region, and
                  DUP-01..DUP-0N inside the merge one; contiguous and unique,
                  each with a `HOLDS` requirement
  2. citations    every FP- and DUP-id cited anywhere under skills/ or agents/
                  exists. A rule family with no citation check is a family that
                  can be invented in prose, which is the hole this closes for
                  the merge rules on the day they were added
  3. answers      the four answers are the only ones the contract uses, and the
                  files that carry findings point at the rules file
  4. conformance  a pack marked `required` cites rules in every procedure; a
                  pack still converting may never fall below its floor

EXIT CODES: 0 measured fine · 1 measured, findings listed · 2 could not measure
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

PACKS_JSON = "scripts/meter/packs.json"
CONFORMANCE_JSON = "scripts/gates/data/triage-conformance.json"
RULE_ROW = re.compile(r"^\|\s*`(FP-\d{2})`\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|$", re.M)
REGION = re.compile(r"<!--\s*triage:rules\s*-->(.*?)<!--\s*/triage:rules\s*-->", re.S)
MERGE_ROW = re.compile(r"^\|\s*`(DUP-\d{2})`\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|$", re.M)
MERGE_REGION = re.compile(
    r"<!--\s*triage:merge-rules\s*-->(.*?)<!--\s*/triage:merge-rules\s*-->", re.S)
CITE = re.compile(r"`?((?:FP|DUP)-\d{2})`?")
ANSWERS = ("HOLDS", "DOES_NOT_HOLD", "UNKNOWN", "NOT_APPLICABLE")
CARRIERS = [
    "skills/ethical-hacker-squad/references/team.md",
    "skills/ethical-hacker-squad/references/report.md",
]
FP_FIELD = re.compile(
    r"\*\*What rules it out \(false positive\)\*\*\n(.*?)(?=\n\*\*|\n### |\n## |\Z)", re.S)


class Unmeasured(Exception):
    pass


def read(root: Path, rel: str) -> str:
    try:
        return (root / rel).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise Unmeasured(f"cannot read {rel}: {exc}") from exc


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    findings: list[str] = []
    checks = 0

    try:
        conf = json.loads(read(root, CONFORMANCE_JSON))
        packs = json.loads(read(root, PACKS_JSON))
    except ValueError as exc:
        raise Unmeasured(f"a data file this gate depends on does not parse: {exc}") from exc

    rules_rel = conf["rules_file"]
    citation_line = re.compile(conf["citation_line"], re.M)
    text = read(root, rules_rel)

    # ---- 1. the rule set -------------------------------------------------
    region = REGION.search(text)
    if not region:
        raise Unmeasured(f"{rules_rel} has no <!-- triage:rules --> region to read")
    rows = RULE_ROW.findall(region.group(1))
    if not rows:
        raise Unmeasured(f"{rules_rel}: the rules region declares no rule rows")
    ids = [r[0] for r in rows]
    checks += 1
    numbers = sorted(int(i.split("-")[1]) for i in ids)
    if numbers != list(range(1, len(numbers) + 1)):
        findings.append(f"{rules_rel}: rule ids are not contiguous from FP-01: {ids}")
    checks += 1
    if len(set(ids)) != len(ids):
        findings.append(f"{rules_rel}: duplicate rule ids: {ids}")
    for rid, condition, holds in rows:
        checks += 1
        if len(condition) < 40 or len(holds) < 20:
            findings.append(
                f"{rules_rel}:{rid} is a rule in name only: a rule states the exculpating "
                "condition and what a HOLDS requires, in enough words to be answerable"
            )
    # The merge family, measured the same way. It is a second region on purpose:
    # triage_rules.py and triage_stage.py both read the FP one by marker, and a
    # family appended inside it would have been silently answered as an FP rule.
    mregion = MERGE_REGION.search(text)
    if not mregion:
        raise Unmeasured(f"{rules_rel} has no <!-- triage:merge-rules --> region to read")
    mrows = MERGE_ROW.findall(mregion.group(1))
    if not mrows:
        raise Unmeasured(f"{rules_rel}: the merge region declares no rule rows")
    mids = [r[0] for r in mrows]
    checks += 2
    mnumbers = sorted(int(i.split("-")[1]) for i in mids)
    if mnumbers != list(range(1, len(mnumbers) + 1)):
        findings.append(f"{rules_rel}: merge rule ids are not contiguous from DUP-01: {mids}")
    if len(set(mids)) != len(mids):
        findings.append(f"{rules_rel}: duplicate merge rule ids: {mids}")
    for rid, condition, holds in mrows:
        checks += 1
        if len(condition) < 40 or len(holds) < 20:
            findings.append(
                f"{rules_rel}:{rid} is a rule in name only: a merge rule states the separating "
                "condition and what a HOLDS requires, in enough words to be answerable"
            )
    # A separating rule that is only ever DOES_NOT_HOLD decides nothing, so the
    # file has to say what a merge costs when one of them does hold.
    checks += 1
    if "possible_duplicate_of" not in text:
        findings.append(
            f"{rules_rel}: the merge rules never name `possible_duplicate_of`, so an UNKNOWN "
            "answer has nowhere to go and the only written outcome is the merge - which is the "
            "expensive error")

    known = set(ids) | set(mids)

    # ---- 3. the answer vocabulary is closed and the carriers point here ---
    for answer in ANSWERS:
        checks += 1
        if answer not in text:
            findings.append(f"{rules_rel}: the answer `{answer}` is not declared")
    for rel in CARRIERS:
        carrier = read(root, rel)
        checks += 2
        if "triage.md" not in carrier:
            findings.append(f"{rel}: carries findings and never points at {rules_rel}")
        if not any(a in carrier for a in ANSWERS):
            findings.append(f"{rel}: never names an answer from the triage vocabulary")

    # ---- 2. every cited id exists ----------------------------------------
    for base in ("skills", "agents"):
        for path in sorted((root / base).rglob("*.md")):
            rel = path.relative_to(root)
            for cited in set(CITE.findall(path.read_text(encoding="utf-8"))):
                checks += 1
                if cited not in known:
                    findings.append(f"{rel}: cites `{cited}`, which {rules_rel} does not declare")

    # ---- 4. conformance, ratcheted --------------------------------------
    kdir = Path(packs["knowledge_dir"])
    heading = re.compile(packs["procedure_heading"])
    for pack in packs["packs"]:
        name = pack["pack"]
        policy = conf["packs"].get(name)
        checks += 1
        if policy is None:
            findings.append(
                f"{CONFORMANCE_JSON}: pack `{name}` exists and has no conversion policy; "
                "a pack with no policy is a pack nobody is converting"
            )
            continue
        total = cited = none_declared = 0
        for fname in pack["files"]:
            body = read(root, str(kdir / fname))
            for block in re.split(r"^(?=### )", body, flags=re.M):
                first = block.splitlines()[0] if block.splitlines() else ""
                if not heading.match(first):
                    continue
                total += 1
                field = FP_FIELD.search(block)
                if field:
                    m = citation_line.search(field.group(1))
                    if m:
                        cited += 1
                        if m.group(1).startswith("none"):
                            none_declared += 1
        checks += 1
        if policy.get("required"):
            if cited != total:
                findings.append(
                    f"pack `{name}` is declared converted and {total - cited} of {total} "
                    "procedures cite no triage rule in their false-positive field"
                )
        elif cited < policy.get("floor", 0):
            findings.append(
                f"pack `{name}` fell to {cited} procedures citing triage rules, below its "
                f"floor of {policy['floor']}; the ratchet only turns forwards"
            )
        print(f"pack {name}: {cited}/{total} procedures cite triage rules"
              f"{f', {none_declared} declaring none' if none_declared else ''}"
              f"{' (required)' if policy.get('required') else ''}")

    print(f"measured: {len(ids)} rules that rule a finding out, {len(mids)} that rule a "
          f"merge out, {checks} checks")
    for f in findings:
        print(f"FINDING {f}")
    return 1 if findings else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Unmeasured as exc:
        print(f"UNMEASURED {exc}")
        sys.exit(2)
