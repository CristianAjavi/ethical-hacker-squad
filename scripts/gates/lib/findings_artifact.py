#!/usr/bin/env python3
"""Measurement core of gate-findings-artifact.sh.

Validates a findings artifact against four sources that each own one thing:

  references/findings.schema.json  the shape
  references/vocabulary.md         the words (status, severity, confidence,
                                   verification) - read from its declared
                                   regions, never copied here
  references/triage.md             the rules a triage answer may cite
  scripts/meter/packs.json         the procedures a finding may claim

and then the invariants that are the reason the file is worth having: a
`confirmed` finding is expensive, `probable` names its gap, `candidate` never
ships, no identifier is invented and no secret travels.

Usage:  findings_artifact.py <repo-root> [artifact.json ...]
With no artifact it validates the fixtures under scripts/gates/fixtures/findings.

EXIT: 0 measured fine · 1 measured, findings listed · 2 could not measure
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

SCHEMA = "skills/ethical-hacker-squad/references/findings.schema.json"
VOCAB = "skills/ethical-hacker-squad/references/vocabulary.md"
TRIAGE = "skills/ethical-hacker-squad/references/triage.md"
DOC = "skills/ethical-hacker-squad/references/findings-artifact.md"
PACKS = "scripts/meter/packs.json"
FAMILIES = "scripts/gates/data/identifier-families.json"
FIXTURES = "scripts/gates/fixtures/findings"

VOCAB_REGION = r"<!--\s*vocabulary:declare {name}\s*-->(.*?)<!--\s*/vocabulary:declare\s*-->"
TERM = re.compile(r"^\|\s*`([a-z ]+)`\s*\|", re.M)
RULE_ID = re.compile(r"`(FP-\d{2})`")
# High-precision formats, the same ones the report contract refuses.
SECRETS = re.compile(
    r"gh[pousr]_[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{12,}|sk-ant-[A-Za-z0-9_-]{16,}|"
    r"-----BEGIN [A-Z ]*PRIVATE KEY-----|xox[baprs]-[A-Za-z0-9-]{10,}"
)


class Unmeasured(Exception):
    pass


def read(root: Path, rel: str) -> str:
    try:
        return (root / rel).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise Unmeasured(f"cannot read {rel}: {exc}") from exc


def load_json(root: Path, rel: str):
    try:
        return json.loads(read(root, rel))
    except ValueError as exc:
        raise Unmeasured(f"{rel} does not parse: {exc}") from exc


def vocabulary(root: Path) -> dict[str, set[str]]:
    text = read(root, VOCAB)
    out = {}
    for name in ("status", "severity", "confidence", "verification"):
        m = re.search(VOCAB_REGION.format(name=name), text, re.S)
        if not m:
            raise Unmeasured(f"{VOCAB} declares no region for `{name}`")
        terms = {t.strip() for t in TERM.findall(m.group(1))}
        if not terms:
            raise Unmeasured(f"{VOCAB}: the `{name}` region declares no terms")
        out[name] = terms
    return out


def check_shape(node, schema, path, fail) -> None:
    """Enough of JSON Schema for this contract, with no dependency to install."""
    t = schema.get("type")
    if t == "object":
        if not isinstance(node, dict):
            fail(f"{path}: expected an object"); return
        for key in schema.get("required", []):
            if key not in node:
                fail(f"{path}: missing required field `{key}`")
        props = schema.get("properties", {})
        for key, value in node.items():
            if key not in props:
                if schema.get("additionalProperties") is False:
                    fail(f"{path}: unknown field `{key}`")
                continue
            check_shape(value, props[key], f"{path}.{key}" if path else key, fail)
    elif t == "array":
        if not isinstance(node, list):
            fail(f"{path}: expected an array"); return
        if len(node) < schema.get("minItems", 0):
            fail(f"{path}: needs at least {schema['minItems']} item(s)")
        for i, item in enumerate(node):
            check_shape(item, schema.get("items", {}), f"{path}[{i}]", fail)
    elif t == "string":
        if not isinstance(node, str):
            fail(f"{path}: expected a string"); return
        if "const" in schema and node != schema["const"]:
            fail(f"{path}: must be `{schema['const']}`, found `{node}`")
        if "enum" in schema and node not in schema["enum"]:
            fail(f"{path}: `{node}` is not one of {schema['enum']}")
        if "pattern" in schema and not re.match(schema["pattern"], node):
            fail(f"{path}: `{node}` does not match {schema['pattern']}")
        if len(node) < schema.get("minLength", 0):
            fail(f"{path}: shorter than {schema['minLength']} characters")
    elif t == "integer":
        if not isinstance(node, int) or isinstance(node, bool):
            fail(f"{path}: expected an integer"); return
        if "minimum" in schema and node < schema["minimum"]:
            fail(f"{path}: below {schema['minimum']}")


def main() -> int:
    args = sys.argv[1:]
    if not args:
        raise Unmeasured("no repository root given")
    root = Path(args[0]).resolve()
    targets = [Path(a) for a in args[1:]]

    schema = load_json(root, SCHEMA)
    packs = load_json(root, PACKS)
    families = load_json(root, FAMILIES)["families"]
    vocab = vocabulary(root)
    family_re = re.compile("^(?:" + "|".join(families.values()) + ")$")
    rules = set(RULE_ID.findall(read(root, TRIAGE)))
    if not rules:
        raise Unmeasured(f"{TRIAGE} declares no rules")

    kdir = Path(packs["knowledge_dir"])
    heading = re.compile(packs["procedure_heading"])
    procedures = set()
    for pack in packs["packs"]:
        for name in pack["files"]:
            for line in read(root, str(kdir / name)).splitlines():
                m = heading.match(line)
                if m:
                    procedures.add(f"{m.group(1)}-{int(m.group(2)):02d}")

    # The doc and the schema must agree on which fields exist AND AT WHICH LEVEL.
    # The level is not a detail: `ruled_out` is a sibling of `findings`, the field
    # table listed it among the per-finding rows, and a blinded specialist
    # faithfully put it inside all nine of its findings, where
    # `additionalProperties: false` rejects it. The artifact was thrown out over
    # a defect in this document. So the table states the level in the row - a
    # bare name is top-level, `engagement.x` and `findings[].x` are the others -
    # and this check reads only table rows, in both directions.
    doc = read(root, DOC)
    documented: set[str] = set()
    for line in doc.splitlines():
        if not line.lstrip().startswith("|"):
            continue
        cell = line.split("|")[1] if line.count("|") >= 2 else ""
        documented.update(re.findall(r"`(engagement\.[a-z_]+|findings\[\]\.[a-z_]+|[a-z_]+)`", cell))
    findings_props = schema["properties"]["findings"]["items"]["properties"]
    engagement_props = schema["properties"]["engagement"]["properties"]
    problems: list[str] = []

    expected = {k for k in schema["properties"] if k not in ("engagement", "findings")}
    expected |= {f"engagement.{k}" for k in engagement_props}
    expected |= {f"findings[].{k}" for k in findings_props}
    for name in sorted(expected - documented):
        problems.append(
            f"{DOC}: the schema has `{name}` and the field table does not explain it at that level")
    # and the other way: a row for a field the schema does not have sends an
    # auditor to write something the validator will refuse.
    for name in sorted(documented - expected):
        if name in ("engagement", "findings") or "." not in name and name not in schema["properties"]:
            continue
        problems.append(
            f"{DOC}: the field table has a row for `{name}`, which the schema does not declare there")

    if not targets:
        fixtures = sorted((root / FIXTURES).rglob("*.json")) if (root / FIXTURES).is_dir() else []
        if not fixtures:
            raise Unmeasured(f"no fixtures under {FIXTURES} and no artifact given")
        targets = fixtures

    total = 0
    for target in targets:
        expected_bad = target.parent.name == "bad"
        try:
            data = json.loads(target.read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            if expected_bad:
                continue
            raise Unmeasured(f"{target}: {exc}") from exc

        found: list[str] = []
        def fail(msg: str) -> None:
            found.append(msg)

        check_shape(data, schema, "", fail)

        # The inventory must be resolved. A blinded reader test found a report that
        # inventoried a data-access layer, named knex as the routing signal that
        # selected its procedures, and then listed that layer in neither what it
        # read nor what it did not - and the reader's verdict was that silence
        # about SQL injection there was not evidence of its absence. Prose could
        # not stop that. Set arithmetic can.
        cov = (data.get("engagement") or {}).get("coverage")
        if isinstance(cov, dict):
            inv = set(cov.get("inventoried") or [])
            examined = set(cov.get("read") or [])
            skipped = set(cov.get("not_read") or [])
            for s in sorted(inv - (examined | skipped)):
                fail(f"engagement.coverage: {s!r} is inventoried and resolved as neither read nor "
                     "not_read - that silence is what a reader mistakes for a clean bill")
            for s in sorted(examined & skipped):
                fail(f"engagement.coverage: {s!r} is in both `read` and `not_read`")
            for s in sorted((examined | skipped) - inv):
                fail(f"engagement.coverage: {s!r} is resolved but was never inventoried")

        for i, f in enumerate(data.get("findings", []) if isinstance(data.get("findings"), list) else []):
            if not isinstance(f, dict):
                continue
            where = f.get("id", f"findings[{i}]")
            status = f.get("status")
            if status and status not in vocab["status"]:
                fail(f"{where}: status `{status}` is not declared in vocabulary.md")
            if f.get("severity") and f["severity"] not in vocab["severity"]:
                fail(f"{where}: severity `{f['severity']}` is not declared in vocabulary.md")
            if f.get("confidence") and f["confidence"] not in vocab["confidence"]:
                fail(f"{where}: confidence `{f['confidence']}` is not declared in vocabulary.md")
            if f.get("verification") and f["verification"] not in vocab["verification"]:
                fail(f"{where}: verification `{f['verification']}` is not declared in vocabulary.md")

            if status == "candidate":
                fail(f"{where}: `candidate` is internal working state and may never appear in a deliverable")
            triage = f.get("triage") if isinstance(f.get("triage"), list) else []
            answers = [t.get("answer") for t in triage if isinstance(t, dict)]
            if status == "confirmed":
                if "UNKNOWN" in answers:
                    fail(f"{where}: reported `confirmed` with a triage rule left UNKNOWN; the ceiling is `probable`")
                if "HOLDS" in answers:
                    fail(f"{where}: reported `confirmed` while a triage rule HOLDS, which rules the finding out")
                if f.get("confidence") == "low":
                    fail(f"{where}: `confirmed` with confidence `low` - nobody followed the path")
            if status == "probable" and not f.get("inference"):
                fail(f"{where}: `probable` must name the link that was inferred, in `inference`")
            # A gap named with no way to close it sends the reader nowhere. Across a
            # day of blinded runs the arms volunteered this unprompted and the
            # verifiers said out loud that it was what let them mark a claim
            # undecidable rather than wave it through; requiring it makes the habit
            # part of the contract instead of a courtesy.
            if status == "probable" and not f.get("what_would_settle_it"):
                fail(f"{where}: `probable` must say what would settle it - the artifact, file or "
                     "symbol that turns the inference into an observation")
            if status == "withdrawn" and not f.get("withdrawn_reason"):
                fail(f"{where}: `withdrawn` must say why the claim did not survive")

            proc = f.get("procedure")
            if proc and proc != "ad-hoc" and proc not in procedures:
                fail(f"{where}: procedure `{proc}` does not exist in the corpus")
            for ident in f.get("traceability", []) if isinstance(f.get("traceability"), list) else []:
                if isinstance(ident, str) and not family_re.match(ident):
                    fail(f"{where}: traceability `{ident}` matches no known identifier family")
            for t in triage:
                if not isinstance(t, dict):
                    continue
                if t.get("rule") and t["rule"] not in rules:
                    fail(f"{where}: triage cites `{t['rule']}`, which triage.md does not declare")
                if t.get("answer") in ("HOLDS", "UNKNOWN", "NOT_APPLICABLE") and not t.get("reason"):
                    fail(f"{where}: triage `{t.get('rule')}` answered `{t['answer']}` with no reason naming the artifact")

        blob = json.dumps(data)
        if SECRETS.search(blob):
            fail(f"{target.name}: an unredacted secret format appears in the artifact")

        total += 1
        if expected_bad:
            # A fixture that fails for an unrelated reason proves the validator
            # runs, not that it catches what the fixture is named after.
            sidecar = target.with_suffix(".expected")
            if not found:
                problems.append(f"{target}: a fixture under bad/ validated cleanly, so it proves nothing")
            elif sidecar.is_file():
                needle = sidecar.read_text(encoding="utf-8").strip()
                if needle and not any(needle in m for m in found):
                    problems.append(
                        f"{target}: rejected, but for the wrong reason - expected {needle!r}, got {found}")
            else:
                problems.append(f"{target}: no .expected sidecar saying which defect it stands for")
        elif not expected_bad and found:
            problems.extend(f"{target.name}: {m}" for m in found)

    print(f"measured: {total} artifact(s), {len(rules)} triage rules, {len(procedures)} procedures")
    for p in problems:
        print(f"FINDING {p}")
    return 1 if problems else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Unmeasured as exc:
        print(f"UNMEASURED {exc}")
        sys.exit(2)
