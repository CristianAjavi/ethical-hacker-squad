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

import hashlib
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
MERGE_RULE_ID = re.compile(r"`(DUP-\d{2})`")
# The caps region of triage.md: id, tier, ceiling. The ceiling is READ, never
# stored on a finding, so a finding cannot restate the cap it is about to exceed.
SEV_REGION = re.compile(r"<!--\s*severity:caps\s*-->(.*?)<!--\s*/severity:caps\s*-->", re.S)
SEV_ROW = re.compile(r"^\|\s*`(SEV-\d{2})`\s*\|\s*([a-z ]+?)\s*\|\s*`([a-z]+)`\s*\|", re.M)
# The order lives in vocabulary.md and nowhere else. Reading it from the row
# sequence of the term table would let a re-sorted table invert every cap.
SEV_ORDER = re.compile(r"^`(critical)`(?:\s*>\s*`([a-z]+)`)+", re.M)
SEV_ORDER_TERMS = re.compile(r"`([a-z]+)`")
# High-precision formats, the same ones the report contract refuses.
SECRETS = re.compile(
    r"gh[pousr]_[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{12,}|sk-ant-[A-Za-z0-9_-]{16,}|"
    r"-----BEGIN [A-Z ]*PRIVATE KEY-----|xox[baprs]-[A-Za-z0-9-]{10,}"
)


class Unmeasured(Exception):
    pass


def _under(path: str, surface: str) -> bool:
    """True when `path` lies inside `surface`, matched at a segment boundary.

    A surface is documented as being named "as the reader would name it", so it
    can be a path (`migrations/`) or a sentence ("the frame layer, absent from
    the target tree"). Only the first shape can ever be a prefix of a file path,
    and requiring the boundary is what stops `lib` from swallowing `library/`.
    """
    s = (surface or "").strip().lstrip("./").rstrip("/")
    q = (path or "").strip().lstrip("./")
    return bool(s) and bool(q) and (q == s or q.startswith(s + "/"))


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
    for name in ("status", "severity", "confidence", "verification",
                 "baseline_state", "disposition"):
        m = re.search(VOCAB_REGION.format(name=name), text, re.S)
        if not m:
            raise Unmeasured(f"{VOCAB} declares no region for `{name}`")
        terms = {t.strip() for t in TERM.findall(m.group(1))}
        if not terms:
            raise Unmeasured(f"{VOCAB}: the `{name}` region declares no terms")
        out[name] = terms
    return out


def severity_caps(triage_text: str) -> dict[str, tuple[str, str]]:
    """id -> (tier, ceiling), read out of the caps region of triage.md."""
    m = SEV_REGION.search(triage_text)
    if not m:
        raise Unmeasured(f"{TRIAGE} has no <!-- severity:caps --> region to read")
    caps = {r[0]: (r[1], r[2]) for r in SEV_ROW.findall(m.group(1))}
    if not caps:
        raise Unmeasured(f"{TRIAGE} declares a caps region with no rows in it")
    return caps


def severity_order(vocab_text: str) -> list[str]:
    """The severity terms, highest first, as vocabulary.md states them."""
    m = SEV_ORDER.search(vocab_text)
    if not m:
        raise Unmeasured(
            f"{VOCAB} no longer states the order of the severity terms, so the ceiling "
            "this validator enforces would be this validator's memory"
        )
    return SEV_ORDER_TERMS.findall(m.group(0))


def ehs_fp_v1(finding: dict, inputs) -> str | None:
    """The fingerprint algorithm, executable.

    sha256 over the named fields in the order `inputs` lists them, each list-valued
    field sorted and joined by U+001E, the whole joined by U+001F. Returns None when
    a named field is absent - invariant 25 reports that separately, and a digest over
    a hole would be a second, quieter complaint about the same defect.
    """
    parts = []
    for name in inputs:
        head, _, tail = str(name).partition(".")
        node = finding.get(head)
        if tail:
            node = node.get(tail) if isinstance(node, dict) else None
        if node in (None, "", [], {}):
            return None
        if isinstance(node, list):
            node = "\x1e".join(sorted(str(x) for x in node))
        parts.append(str(node))
    return "sha256:" + hashlib.sha256("\x1f".join(parts).encode("utf-8")).hexdigest()


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
    triage_text = read(root, TRIAGE)
    rules = set(RULE_ID.findall(triage_text))
    if not rules:
        raise Unmeasured(f"{TRIAGE} declares no rules")
    caps = severity_caps(triage_text)
    always_caps = sorted(k for k, (tier, _) in caps.items() if tier == "always")
    if not always_caps:
        raise Unmeasured(
            f"{TRIAGE} declares no cap in the `always` tier: nothing would then be "
            "required of a `critical`, and invariant 12 could never fire"
        )
    order = severity_order(read(root, VOCAB))
    unknown_ceilings = sorted({c for _, c in caps.values()} - set(order))
    if unknown_ceilings:
        raise Unmeasured(
            f"{TRIAGE} names the ceiling(s) {', '.join(unknown_ceilings)}, which "
            f"{VOCAB} does not order"
        )
    rank = {term: i for i, term in enumerate(order)}  # 0 is the top of the order
    merge_rules = set(MERGE_RULE_ID.findall(triage_text))
    if not merge_rules:
        raise Unmeasured(f"{TRIAGE} declares no merge rules")

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
    # [findings with a path, of those inside a `read` surface, of those
    #  inside no inventoried surface at all]. Printed, never a verdict: see
    #  the summary line for why the third number cannot be one.
    paths_seen = [0, 0, 0]
    # [artifacts declaring a baseline, baseline findings accounted for,
    #  findings carrying a fingerprint]. Printed so a reader can see whether
    #  the memory invariants had anything to bite on in this run.
    memory_seen = [0, 0, 0]
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

        # The unaided pass must be resolved too, for the same reason and against a
        # sharper measurement. Eleven runs said the corpus arm found what an
        # unaided engineer found and no more, missed one advisory while holding
        # the right file open, and agreed with ITSELF less across repeated runs
        # (0.68 against 0.81) - its stable core plus a different tail each time.
        # The reading those numbers support is substitution: what a procedure
        # named got found, what it did not name got bent into the nearest
        # procedure or quietly dropped. So a candidate written down before any
        # pack was opened has exactly two honest endings, reported or dropped
        # with a reason, and `reported` has to be provable against the findings
        # rather than merely asserted.
        up = (data.get("engagement") or {}).get("unaided_pass")
        if isinstance(up, dict):
            # These are declared as arrays of strings. A run that writes objects
            # here used to crash this validator with TypeError instead of being
            # told what was wrong - and a crash is not a verdict, it is a gate
            # that could not measure. Found by a real run, not by reasoning.
            def _labels(field):
                raw = up.get(field) or []
                if not isinstance(raw, list):
                    fail(f"engagement.unaided_pass.{field} must be a list of short labels, not "
                         f"{type(raw).__name__}")
                    return set()
                bad = [x for x in raw if not isinstance(x, str)]
                for x in bad:
                    fail(f"engagement.unaided_pass.{field} contains a {type(x).__name__} where a short "
                         "label string belongs; the set arithmetic this field exists for cannot run over it")
                return {x for x in raw if isinstance(x, str)}

            cand = _labels("candidates")
            kept = _labels("reported")
            dropped_rows = up.get("dropped") or []
            gone = set()
            ids = {f.get("id") for f in (data.get("findings") or []) if isinstance(f, dict)}
            for row in dropped_rows:
                if isinstance(row, dict) and isinstance(row.get("label"), str):
                    gone.add(row["label"])
                    reason = (row.get("reason") or "").strip()
                    if reason.lower().startswith(("no procedure", "the pack has no procedure",
                                                  "not in the corpus", "no matching procedure")):
                        fail(f"engagement.unaided_pass: {row['label']!r} is dropped because no "
                             "procedure covers it, and that is the one reason this field exists to "
                             "refuse - a finding with no procedure is `ad-hoc`, not absent")
                    # A dismissal has to cost what an assertion costs. Measured: a
                    # weaker model on a short budget does not go quiet, it refutes
                    # confidently - twice dismissing a real unbounded allocation,
                    # once by asserting the bounds were fine and once by citing the
                    # length cap of a different method.
                    res = row.get("resolution")
                    if res == "refuted" and not (row.get("control_at") or "").strip():
                        fail(f"engagement.unaided_pass: {row['label']!r} is refuted with no `control_at` - "
                             "a refutation names the line where the bound is enforced on the path to the "
                             "sink, exactly as a confirmation names where it is missing")
                    if res == "merged":
                        into = (row.get("merged_into") or "").strip()
                        if not into:
                            fail(f"engagement.unaided_pass: {row['label']!r} is merged into nothing - "
                                 "name the finding that absorbed it")
                        elif into not in ids:
                            fail(f"engagement.unaided_pass: {row['label']!r} is merged into {into!r}, "
                                 "which is not a finding in this artifact")
            for s in sorted(cand - (kept | gone)):
                fail(f"engagement.unaided_pass: {s!r} was a candidate before any pack was opened and "
                     "is resolved as neither reported nor dropped - that is the substitution this "
                     "field exists to make visible")
            for s in sorted(kept & gone):
                fail(f"engagement.unaided_pass: {s!r} is in both `reported` and `dropped`")
            for s in sorted((kept | gone) - cand):
                fail(f"engagement.unaided_pass: {s!r} is resolved but was never a candidate")

            labelled = {f.get("unaided_label") for f in (data.get("findings") or [])
                        if isinstance(f, dict) and isinstance(f.get("unaided_label"), str)}
            for s in sorted(kept - labelled):
                fail(f"engagement.unaided_pass: {s!r} is declared reported, but no finding carries it "
                     "as `unaided_label` - the claim has to be checkable against the findings")
            for s in sorted(labelled - cand):
                fail(f"a finding carries unaided_label {s!r}, which is not among the candidates of "
                     "engagement.unaided_pass")

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
                # 31. `confirmed` means demonstrated. Anything short of `high`
                #     confidence is an inference, and vocabulary.md spells the
                #     status for an inference `probable`. The check refused only
                #     `low` until now, so the middle term - the one an author
                #     reaches for when they are almost sure - went through. Three
                #     of the blinded bench runs took that door.
                if f.get("confidence") and f["confidence"] != "high":
                    fail(f"{where}: `confirmed` with confidence `{f['confidence']}` - confirmed "
                         "means demonstrated, and anything less than `high` is an inference, "
                         "whose status is `probable`")
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
            # 32. A refutation is a verdict about the claim, not a note about the
            #     test. `refuted` says a second look established there was no
            #     defect; a finding that survives its own refutation as
            #     `confirmed` or `probable` is a claim the reader has already
            #     acted on and nothing retracts. Nothing else implies `withdrawn`,
            #     which is why the implication runs one way only.
            if f.get("verification") == "refuted" and status != "withdrawn":
                fail(f"{where}: `refuted` with status `{status}` - a refutation establishes there "
                     "was no defect, and the only status that says so is `withdrawn`")

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

            # Invariants 12-19. The caps of triage.md, answered. `FP-*` asks whether
            # the finding survives; `SEV-*` asks how high it may be written once it
            # has. The ceiling is read from triage.md and the order from
            # vocabulary.md, so neither is this file's to own.
            sev = f.get("severity")
            expensive = sev in ("critical", "high")
            calib = f.get("severity_calibration")
            calib = calib if isinstance(calib, list) else []
            seen: dict[str, int] = {}
            for c in calib:
                if not isinstance(c, dict):
                    continue
                rule, answer = c.get("rule"), c.get("answer")
                if not isinstance(rule, str):
                    continue
                seen[rule] = seen.get(rule, 0) + 1
                if seen[rule] == 2:
                    # 18.
                    fail(f"{where}: severity_calibration answers `{rule}` twice; a rule has "
                         "one answer, and two let a reader pick the convenient one")
                if rule not in caps:
                    # 17.
                    fail(f"{where}: severity_calibration cites `{rule}`, which triage.md does not declare")
                    continue
                tier, ceiling = caps[rule]
                if tier == "derived":
                    # 19, second message.
                    fail(f"{where}: `{rule}` is derived from `status` and answering it can only "
                         "disagree with the artifact; remove the entry")
                    continue
                if answer in ("HOLDS", "UNKNOWN", "NOT_APPLICABLE") and not c.get("reason"):
                    # 15.
                    fail(f"{where}: `{rule}` answered `{answer}` with no reason naming the artifact")
                if answer == "DOES_NOT_HOLD" and expensive and not c.get("reason"):
                    # 16.
                    fail(f"{where}: `{rule}` answered `DOES_NOT_HOLD` on a `{sev}` finding with no "
                         "reason; that is the answer that buys the label, and it pays what the label costs")
                if answer in ("HOLDS", "UNKNOWN") and sev in rank and ceiling in rank:
                    if rank[sev] < rank[ceiling]:
                        if answer == "HOLDS":
                            # 13.
                            fail(f"{where}: severity `{sev}` sits above the `{ceiling}` ceiling that "
                                 f"`{rule}` imposes while answered `HOLDS`; the ceiling is "
                                 "triage.md's, not the finding's to overrule")
                        else:
                            # 14.
                            fail(f"{where}: severity `{sev}` sits above the `{ceiling}` ceiling of "
                                 f"`{rule}`, answered `UNKNOWN`; an unestablished cap binds, exactly "
                                 "as exit code `2` is not a green gate")
            if expensive:
                for rule in always_caps:
                    if rule not in seen:
                        # 12.
                        fail(f"{where}: severity `{sev}` and the always-answered cap `{rule}` is not "
                             "answered; a cap nobody answered is a cap nobody applied")
                if status == "hardening":
                    # 19, first message.
                    fail(f"{where}: status `hardening` claims there is nothing to exploit and severity "
                         f"`{sev}` claims how much the exploit matters; `SEV-10` derives this and the "
                         "finding is on both sides of it")

        # Invariant 10. `merged_into` above closes this for a candidate absorbed
        # inside one specialist's unaided pass. The leader's merge ACROSS
        # specialists - ordered three times in team.md, governed by nothing -
        # left no trace at all, which is the same substitution one level up.
        # A merge is not a deletion: the absorbed finding keeps its id here.
        by_id = {f["id"]: f for f in (data.get("findings") or [])
                 if isinstance(f, dict) and isinstance(f.get("id"), str)}
        for fid, f in by_id.items():
            into = f.get("duplicate_of")
            maybe = f.get("possible_duplicate_of") or []
            if isinstance(into, str):
                if into == fid:
                    fail(f"{fid}: is its own duplicate")
                elif into not in by_id:
                    fail(f"{fid}: `duplicate_of` names {into!r}, which is not a finding here - a "
                         "merge that points at nothing is a deletion with a footnote")
                elif by_id[into].get("duplicate_of"):
                    fail(f"{fid}: merged into {into!r}, which is itself merged into "
                         f"{by_id[into]['duplicate_of']!r} - a chain is how the reader loses the "
                         "surviving entry; point every duplicate at the one that survives")
                answered = f.get("merge_rules") if isinstance(f.get("merge_rules"), list) else []
                given = {m.get("rule") for m in answered if isinstance(m, dict)}
                for missing in sorted(merge_rules - given):
                    fail(f"{fid}: merged with `{missing}` unanswered - a merge deletes a finding "
                         "from the reader's list and pays what a claim pays")
                for m in answered:
                    if not isinstance(m, dict):
                        continue
                    if m.get("rule") and m["rule"] not in merge_rules:
                        fail(f"{fid}: merge_rules cites `{m['rule']}`, which triage.md does not declare")
                    if m.get("answer") == "HOLDS":
                        fail(f"{fid}: merged while `{m.get('rule')}` HOLDS, which is the answer that "
                             "says these are two findings")
                    if m.get("answer") == "UNKNOWN":
                        fail(f"{fid}: merged with `{m.get('rule')}` UNKNOWN - an undecided pair is "
                             "`possible_duplicate_of`, never a merge; the wrong merge is the "
                             "expensive error and the long report is the cheap one")
                    if m.get("answer") in ("HOLDS", "UNKNOWN", "NOT_APPLICABLE") and not m.get("reason"):
                        fail(f"{fid}: merge rule `{m.get('rule')}` answered `{m['answer']}` with no reason")
            if isinstance(maybe, list):
                for other in maybe:
                    if other == fid:
                        fail(f"{fid}: is a possible duplicate of itself")
                    elif isinstance(other, str) and other not in by_id:
                        fail(f"{fid}: `possible_duplicate_of` names {other!r}, which is not a finding here")
                    elif other == into:
                        fail(f"{fid}: names {other!r} as both a merge and an undecided pair - the "
                             "two states are the decision and the lack of it")

        # 11. A finding may not live where the report says it did not look.
        #
        # `engagement.coverage` already forces every inventoried surface into
        # exactly one of `read` or `not_read`. What nothing compared, until this
        # block, is that partition against the findings it sits beside: they were
        # two documents in one file. Measured on the fixture that models a
        # CONFORMING artifact, an entry declaring `not_read: ["migrations/"]` and
        # reporting a defect at `migrations/003_add_invoices.sql:12` passed all
        # ten invariants and signed verdict 0. Both sentences cannot be true, and
        # whichever one is false, the reader is being told the audit is something
        # it is not.
        #
        # `maxgfr/ultrasec` reaches the same problem from the other side and is
        # worth naming, because its answer is the better-known one: it scores a
        # coverage matrix FROM the findings, so a category with no finding shows
        # as `unexamined` rather than being silently omitted. That is the half we
        # did not have. Its state machine, though, reads
        #     hits > 0 ? "examined" : engineCovers ? "engine" : "unexamined"
        # where `engineCovers` is true when ANY finding anywhere in the run
        # carries one of the category's kinds - so a class is credited as covered
        # by the engine's capability, not by anything having been read. There is
        # no denominator in it at all. Ours is the opposite trade: we hold the
        # denominator and never joined it to the findings. This closes the join
        # in the only direction that is a flat contradiction rather than a
        # judgement call.
        #
        # Matching is at a path segment boundary, which is what keeps this from
        # accusing the compliant: `not_read` is documented as naming surfaces
        # "as the reader would name it", and in the 60 real artifacts under
        # bench/runs those names are usually descriptive sentences, which can
        # never be a path prefix. Measured over those 60: 277 findings carry a
        # path and ZERO contradict a `not_read` entry. The rule accuses no
        # existing work; it forbids a class that has not happened yet.
        cov_read = [s for s in (cov.get("read") or []) if isinstance(s, str)] if isinstance(cov, dict) else []
        cov_skip = [s for s in (cov.get("not_read") or []) if isinstance(s, str)] if isinstance(cov, dict) else []
        cov_inv = [s for s in (cov.get("inventoried") or []) if isinstance(s, str)] if isinstance(cov, dict) else []
        for f in (data.get("findings") or []):
            if not isinstance(f, dict):
                continue
            loc = f.get("location")
            path = loc.get("path") if isinstance(loc, dict) else None
            if not isinstance(path, str) or not path.strip():
                continue
            for surface in cov_skip:
                if _under(path, surface):
                    fail(f"{f.get('id')}: reported at {path!r}, inside {surface!r}, which "
                         "`engagement.coverage.not_read` says was not examined - a finding is "
                         "proof someone looked, so one of the two statements is false")
            paths_seen[0] += 1
            if any(_under(path, s) for s in cov_read):
                paths_seen[1] += 1
            elif not any(_under(path, s) for s in cov_inv):
                paths_seen[2] += 1

        # --- 20-29: the engagement memory -----------------------------------
        # Mantis ships the closest thing to this in the field, and its Tier 1 key
        # is sound - a digest over fingerprint, CWE and target symbol, invariant to
        # line shifts and to paraphrased titles. What it does not survive is its own
        # fallback: the embedding tier catches every exception and returns a mock
        # vector, the dimension check then skips every candidate, and a deployment
        # with no model silently reports each run as all-new. Nothing in the
        # artifact says so. That is the defect these ten rules exist to make
        # unwriteable: `new` is a measurement, and its absence has its own word.
        eng = data.get("engagement") if isinstance(data.get("engagement"), dict) else {}
        base = eng.get("baseline") if isinstance(eng.get("baseline"), dict) else None
        carried = data.get("carried_over")
        carried = carried if isinstance(carried, list) else None
        findings = [f for f in (data.get("findings") or []) if isinstance(f, dict)]
        is_v2 = data.get("schema_version") == "ehs.findings/v2"
        memory_used = bool(
            base or carried is not None or eng.get("target_digest")
            or any(f.get("fingerprint") or f.get("baseline_state") for f in findings)
        )

        # 20. v2 requires the memory. Below v2 the block is optional, but every
        #     rule under it applies the moment any part of it is present: an
        #     artifact does not get to opt into the field and out of the arithmetic.
        if is_v2:
            if not eng.get("target_digest"):
                fail("`ehs.findings/v2` without `engagement.target_digest`: nothing "
                     "identifies the bytes this run compared")
            if not base and not eng.get("baseline_absent_reason"):
                fail("`ehs.findings/v2` with neither `engagement.baseline` nor "
                     "`engagement.baseline_absent_reason`: the same silence would cover "
                     "`no previous audit exists` and `nobody looked for one`")
            if base and carried is None:
                fail("`ehs.findings/v2` declares a baseline and omits `carried_over`: a "
                     "baseline finding that stops appearing reads exactly like one that "
                     "was fixed")
            for f in findings:
                if not f.get("baseline_state"):
                    fail(f"{f.get('id')}: `ehs.findings/v2` finding with no "
                         "`baseline_state`")

        if base and base.get("target_digest") and eng.get("target_digest") == base["target_digest"]:
            same = [f.get("id") for f in findings if f.get("baseline_state") == "new"]
            if same:
                fail(f"the baseline digest equals this run's, so the same bytes were read "
                     f"twice, yet {', '.join(str(i) for i in same)} is `new`")

        if memory_used:
            if base:
                memory_seen[0] += 1
            values: dict[str, list] = {}
            lineage_refs: set[str] = set()
            for f in findings:
                fid = f.get("id")
                fp = f.get("fingerprint") if isinstance(f.get("fingerprint"), dict) else None
                state = f.get("baseline_state")
                lineage = f.get("lineage") if isinstance(f.get("lineage"), list) else None
                changed = f.get("changed_fields") if isinstance(f.get("changed_fields"), list) else None
                reg = f.get("regression") if isinstance(f.get("regression"), dict) else None

                if state and state not in vocab["baseline_state"]:
                    fail(f"{fid}: `{state}` is not a declared `baseline_state`")

                # 21. a state that claims a comparison needs something to compare with
                if state in ("new", "unchanged", "updated") and not base:
                    fail(f"{fid}: `{state}` claims a comparison against a baseline this "
                         "artifact does not declare - the honest term is `unmeasured`")
                # 22. and a key to compare on
                if state in ("new", "unchanged", "updated") and not fp:
                    fail(f"{fid}: `{state}` with no `fingerprint`: there was no key to "
                         "match on, so no comparison happened")
                # 23. what a continuation continues, and what a discovery does not
                if state in ("unchanged", "updated") and not lineage:
                    fail(f"{fid}: `{state}` names no `lineage`, so nothing says what it "
                         "continues")
                if state in ("new", "unmeasured") and lineage:
                    fail(f"{fid}: `{state}` carries a `lineage`: a finding that continues "
                         "a baseline entry is not new and was not unmeasured")
                # 24. `updated` is a diff or it is a mood
                if state == "updated" and not changed:
                    fail(f"{fid}: `updated` names no `changed_fields`")
                if state == "unchanged" and changed:
                    fail(f"{fid}: `unchanged` names `changed_fields`, which is the "
                         "definition of `updated`")

                if fp:
                    memory_seen[2] += 1
                    # 25. a key declares the fields it was computed over, and it
                    #     cannot have been computed over a field that is not there.
                    for name in (fp.get("inputs") or []):
                        head, _, tail = str(name).partition(".")
                        node = f.get(head)
                        if tail:
                            node = node.get(tail) if isinstance(node, dict) else None
                        if node in (None, "", [], {}):
                            fail(f"{fid}: `fingerprint.inputs` names `{name}`, which this "
                                 "finding does not carry - the key was computed over nothing")
                    val = fp.get("value")
                    if isinstance(val, str):
                        values.setdefault(val, []).append(f)
                    # ...and the value is that computation. An algorithm nothing
                    # recomputes is prose wearing a field name: `value` would be
                    # whatever the writer put there and `inputs` a decoration.
                    if fp.get("algorithm") == "ehs.fp/v1" and isinstance(val, str):
                        recomputed = ehs_fp_v1(f, fp.get("inputs") or [])
                        if recomputed and recomputed != val:
                            fail(f"{fid}: `fingerprint.value` does not reproduce from the "
                                 f"fields `inputs` names - `ehs.fp/v1` over "
                                 f"{list(fp.get('inputs') or [])} gives {recomputed[:19]}..., "
                                 f"the artifact says {val[:19]}...")
                if lineage:
                    lineage_refs.update(x for x in lineage if isinstance(x, str))

                # 27. a regression is a claim about somebody's conclusion
                if reg:
                    if not lineage:
                        fail(f"{fid}: `regression` with no `lineage`: there is nothing "
                             "recorded for it to have regressed from")
                    prev = reg.get("previous_disposition")
                    if prev and prev not in vocab["disposition"]:
                        fail(f"{fid}: `regression.previous_disposition` `{prev}` is not a "
                             "declared `disposition`")
                    elif prev in ("not measured", "out of scope"):
                        fail(f"{fid}: `regression` against a previous disposition of "
                             f"`{prev}`, which concluded nothing - a defect can only come "
                             "back from having been declared gone")

            # 26. the ordinal exists for collisions and for nothing else
            for val, group in values.items():
                ords = [g["fingerprint"].get("ordinal") for g in group]
                if len(group) == 1:
                    if ords[0] != 0:
                        fail(f"{group[0].get('id')}: its `fingerprint.value` is unique in "
                             f"this artifact and its ordinal is {ords[0]}, not 0 - an "
                             "ordinal is a tiebreak, not a second identifier")
                elif len(set(ords)) != len(ords):
                    fail(f"{len(group)} findings share the fingerprint {val[:19]}... and "
                         f"do not have distinct ordinals: {ords}")

            # 29. a carried-over entry pays for what it claims
            for i, c in enumerate(carried or []):
                if not isinstance(c, dict):
                    continue
                disp = c.get("disposition")
                where = c.get("fingerprint", f"carried_over[{i}]")
                if disp and disp not in vocab["disposition"]:
                    fail(f"carried_over[{i}]: `{disp}` is not a declared `disposition`")
                # 30. The schema requires the field; what it cannot check is that
                #     the id RESOLVES. `WEB-99` satisfies every schema rule and
                #     still leaves the next engagement unable to look up what
                #     found the defect, which is the whole point of the rule.
                cproc = c.get("procedure")
                if cproc and cproc != "ad-hoc" and cproc not in procedures:
                    fail(f"carried_over[{i}]: procedure `{cproc}` does not exist in the "
                         "corpus - a citation that resolves to nothing is the same dead "
                         "end as no citation, one step further along")
                if disp == "fixed" and not c.get("evidence"):
                    fail(f"carried_over[{i}]: `fixed` with no `evidence` - the one "
                         "disposition that lowers a reader's guard is the one that has to "
                         "pay for it")
                if disp == "out of scope":
                    surface = c.get("surface")
                    if not surface:
                        fail(f"carried_over[{i}]: `out of scope` names no `surface`")
                    elif surface not in cov_skip:
                        fail(f"carried_over[{i}]: `out of scope` names the surface "
                             f"{surface!r}, which `engagement.coverage.not_read` does not "
                             "exclude - the claim is unchecked")
                if isinstance(where, str) and where in lineage_refs:
                    fail(f"carried_over[{i}]: {where[:19]}... is also continued by a "
                         "finding in this run: it cannot both have come back and not")

            # 28. the baseline is accounted for, the same way the inventory and the
            #     unaided pass are. This is the rule Mantis's fallback would trip:
            #     a matcher that silently stopped matching reports every finding
            #     `new`, and then nothing balances.
            if base:
                declared = base.get("findings_count")
                if isinstance(declared, int):
                    accounted = len(lineage_refs) + len([c for c in (carried or [])
                                                         if isinstance(c, dict)])
                    if accounted == declared:
                        memory_seen[1] += declared
                    else:
                        fail(f"the baseline declares {declared} finding(s); this artifact "
                             f"accounts for {accounted} ({len(lineage_refs)} continued, "
                             f"{len(carried or [])} carried over). A baseline entry that is "
                             "neither continued nor answered is a defect this run lost in "
                             "silence")

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

    print(f"measured: {total} artifact(s), {len(rules)} triage rules, {len(merge_rules)} merge rules, "
          f"{len(procedures)} procedures")
    # The join between the coverage declaration and the findings, as a number
    # rather than as a rule. It is NOT a verdict, and the measurement is the
    # reason: across the 60 real artifacts in bench/runs, 273 of 277 findings
    # with a path lie under no inventoried surface at all. A gate that failed on
    # that would accuse 98.6% of this repository's own best work, which is how a
    # new check ends up arguing with everyone who complied. The two documents
    # are simply written in different vocabularies - the inventory names
    # surfaces a reader would recognise, the findings name files - and the gap
    # between them is recorded as a known coverage gap in
    # `references/traceability.md` rather than pretended away here.
    if memory_seen[2] or memory_seen[0]:
        print(f"engagement memory: {memory_seen[0]} artifact(s) declare a baseline, "
              f"{memory_seen[1]} baseline finding(s) accounted for, {memory_seen[2]} "
              f"finding(s) carry a fingerprint")
    else:
        print("engagement memory: no artifact in this run carries a baseline or a "
              "fingerprint, so invariants 20-29 were NOT MEASURED")
    if paths_seen[0]:
        print(f"coverage join: {paths_seen[0]} finding(s) carry a path, {paths_seen[1]} of them "
              f"inside a surface declared `read`, {paths_seen[2]} inside no inventoried surface "
              f"at all (reported, not judged)")
    else:
        print("coverage join: no finding in this run carries a path, so the join was NOT MEASURED")
    for p in problems:
        print(f"FINDING {p}")
    return 1 if problems else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Unmeasured as exc:
        print(f"UNMEASURED {exc}")
        sys.exit(2)
