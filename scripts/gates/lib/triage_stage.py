#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# triage_stage.py - measurement core for gate-triage-stage.sh.
#
# WHAT THIS IS FOR
#   bench/stages/triage/ asks one question per case: a finding was raised,
#   somebody offered a reason it should not be reported, which rule is that
#   reason invoking, what is the answer, and what follows for the finding.
#
#   The thing that makes it worth building is not the cases. It is that the KEY
#   IS AUDITABLE BY MACHINE. Nobody has to be trusted about the third column:
#   the consequences table in references/triage.md forces it from the answer, so
#   this file re-derives every consequence and fails the case when the key and
#   the table disagree. A key that only its author can check is an opinion with
#   a file name.
#
# WHAT IT MEASURES
#   1. derivation  the consequences table still says what the derivation reads
#                  it for, and the HOLDS delegation is unambiguous
#   2. seal        the key still describes THIS cases.json, by digest
#   3. rows        one key row per case, a declared rule, a declared answer, and
#                  a consequence equal to the derived one
#   4. reason      a HOLDS or an UNKNOWN names an artifact the case presented,
#                  which is invariant 2 of the rules file
#   5. coverage    every rule, every answer, every consequence, and the two
#                  rules where a model over-affirms asked in the direction where
#                  the honest answer is that it could not be established
#   6. leak        no presented field carries the rule id, the answer token or
#                  the consequence terms its own key declares, and none of them
#                  prescribes the remedy
#
# WHAT IT DOES NOT MEASURE
#   Whether a case is well chosen, whether the rule named is the one a reviewer
#   would name, and whether any model answers correctly. It also does not run
#   the eval: this gate reads files and calls no model. A green here says the
#   instrument is intact, not that anything scored.
#
#   The leak check is mechanical in both families and neither is a clearance. It
#   catches a token and it catches an imperative construction. A case that gives
#   the answer away in a paraphrase - "the platform team confirmed it in
#   writing" in a case whose answer turns on nothing having arrived - passes
#   this and needs a reader.
#
# Output: FINDING <text>, UNMEASURED <text>, anything else is info.
# Exit: 0 measured fine / 1 measured FAILS / 2 could not measure.
# ---------------------------------------------------------------------------
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

DATA = "scripts/gates/data/triage-stage.json"

REGION = re.compile(r"<!--\s*triage:rules\s*-->(.*?)<!--\s*/triage:rules\s*-->", re.S)
RULE_ROW = re.compile(r"^\|\s*`(FP-\d{2})`\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|$", re.M)
BACKTICKED = re.compile(r"`([^`]+)`")


class Unmeasured(Exception):
    pass


def read(root: Path, rel: str) -> str:
    try:
        return (root / rel).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise Unmeasured(f"cannot read {rel}: {exc}") from exc


def read_json(root: Path, rel: str):
    try:
        return json.loads(read(root, rel))
    except ValueError as exc:
        raise Unmeasured(f"{rel} does not parse: {exc}") from exc


def dig(doc, dotted: str):
    """Fetch a dotted path out of a nested mapping, or None."""
    cur = doc
    for part in dotted.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur


# ---------------------------------------------------------------------------
# 1. the derivation, read out of triage.md rather than held here
# ---------------------------------------------------------------------------
def build_derivation(rules_text: str, conf: dict):
    """Returns (rule_ids, consequence_cells, derive(rule, answer), notes).

    The consequences table fixes three of the four answers outright. It does not
    fix HOLDS on its own: it says the finding is `ruled out, or drops to
    informational if the rule says so`, which is an explicit delegation to the
    rule row. `holds_overrides` in the data file names the two ways a rule row
    exercises that delegation, and each marker must appear in exactly one row -
    two rows claiming the same override is an ambiguity, not a rule.
    """
    region = REGION.search(rules_text)
    if not region:
        raise Unmeasured("the rules file has no <!-- triage:rules --> region to read")
    rows = RULE_ROW.findall(region.group(1))
    if not rows:
        raise Unmeasured("the rules region declares no rule rows")
    rule_text = {rid: f"{cond} {holds}" for rid, cond, holds in rows}

    # The consequences table lives OUTSIDE the rules region; reading the whole
    # file would let a rule row impersonate an answer row.
    outside = rules_text[:region.start()] + rules_text[region.end():]
    cells = {}
    for answer in conf["answers"]:
        m = re.search(rf"^\|\s*`{re.escape(answer)}`\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|\s*$",
                      outside, re.M)
        if not m:
            raise Unmeasured(
                f"the consequences table declares no row for `{answer}`: the vocabulary this "
                "eval scores against is not the one the rules file states")
        cells[answer] = m.group(2)

    for answer, anchor in conf["consequence_anchors"].items():
        if answer == "comment":
            continue
        if anchor not in cells[answer]:
            raise Unmeasured(
                f"the consequence for `{answer}` no longer contains {anchor!r}: the table was "
                "rewritten and the derivation this gate performs is not the one the file states")

    overrides = {}
    notes = []
    for consequence, marker in conf["holds_overrides"].items():
        if consequence == "comment":
            continue
        owners = [rid for rid, text in rule_text.items() if marker in text]
        if len(owners) > 1:
            raise Unmeasured(
                f"{len(owners)} rule rows carry the HOLDS override marker {marker!r} ({owners}): "
                "an override two rules claim is an ambiguity, not a derivation")
        if owners:
            overrides[owners[0]] = consequence
            notes.append(f"{owners[0]} overrides HOLDS to `{consequence}` via {marker}")

    default = conf["default_consequence"]

    def derive(rule: str, answer: str) -> str:
        if answer == "HOLDS" and rule in overrides:
            return overrides[rule]
        return default[answer]

    return [r[0] for r in rows], cells, derive, notes


def forbidden_consequence_terms(cell: str) -> list[str]:
    """The terms an answer's own consequence cell names, and nothing else.

    Read out of the cell so the gate forbids what the key actually declares
    rather than what the author of this file remembered. Ordinary English -
    `survives`, `moves`, `nothing` - is not in the list because it is not
    backticked in the table: those cells contribute no term, and the gate says
    so out loud rather than passing them silently.
    """
    terms = [t.strip() for t in BACKTICKED.findall(cell)]
    if "ruled out" in cell:
        terms.append("ruled out")
    return sorted(set(terms))


# ---------------------------------------------------------------------------
# 2. the leak scan, used on this eval and on a foreign one unchanged
# ---------------------------------------------------------------------------
def token_leaks(blob: str, conf: dict, own_terms: list[str]) -> list[str]:
    hits = []
    for m in set(re.findall(conf["forbidden_in_statement"]["rule_id"], blob)):
        hits.append(f"the rule id {m}")
    for tok in conf["forbidden_in_statement"]["answer_tokens_any_case"]:
        if re.search(re.escape(tok), blob, re.I):
            hits.append(f"the answer token {tok}")
    for tok in conf["forbidden_in_statement"]["answer_tokens_upper_only"]:
        if re.search(rf"\b{re.escape(tok)}\b", blob):
            hits.append(f"the answer token {tok}")
    for term in own_terms:
        if re.search(rf"\b{re.escape(term)}\b", blob, re.I):
            hits.append(f"the term `{term}` its own key declares")
    return hits


def label_leaks(blob: str, conf: dict) -> list[str]:
    """The vocabulary commit b8bce3d wired into gate-bench-integrity.sh.

    Borrowed rather than reinvented, and declared in one place: see
    `borrowed_label_vocabulary` in the data file for why it is applied here and
    what the drift guard is for.
    """
    m = re.search(conf["borrowed_label_vocabulary"]["pattern"], blob, re.I)
    return [f"labels its own answer with {m.group(0)!r}"] if m else []


def check_no_drift(root: Path, conf: dict) -> None:
    """The borrowed pattern must still be the one its owner enforces."""
    spec = conf["borrowed_label_vocabulary"]
    src = read(root, spec["source_file"])
    if spec["pattern"] not in src:
        raise Unmeasured(
            f"{spec['source_file']} no longer contains the label vocabulary this gate borrows "
            f"({spec['pattern']!r}). The two have drifted, and enforcing a rule its owner has "
            "changed is worse than not enforcing it")


def remedy_leaks(blob: str, conf: dict) -> list[str]:
    hits = []
    for pat in conf["remedy_constructions"]["patterns"]:
        m = re.search(pat, blob, re.I)
        if m:
            start = max(0, m.start() - 30)
            hits.append(f"prescribes the remedy: ...{blob[start:m.end() + 60].strip()}...")
    return hits


def presented_blob(case: dict, fields: list[str]) -> str:
    """Concatenate the declared presented fields, list and nested forms included."""
    out = []

    def walk(value):
        if isinstance(value, str):
            out.append(value)
        elif isinstance(value, list):
            for v in value:
                walk(v)
        elif isinstance(value, dict):
            for v in value.values():
                walk(v)

    for field in fields:
        cur, ok = case, True
        for part in field.replace("[]", "").split("."):
            if isinstance(cur, list):
                cur = [c.get(part) for c in cur if isinstance(c, dict)]
            elif isinstance(cur, dict) and part in cur:
                cur = cur[part]
            else:
                ok = False
                break
        if ok:
            walk(cur)
    return "\n".join(x for x in out if x)


# ---------------------------------------------------------------------------
# 3. the foreign measurement - the same instrument, pointed elsewhere
# ---------------------------------------------------------------------------
def measure_foreign(root: Path, conf: dict, map_rel: str):
    """Run the leak scan over a dataset this project did not write.

    Reported, never enforced: a neighbouring product's data is evidence about
    the field, not a gate on this repository, and a gate that failed because
    somebody else's file changed would be a gate nobody could keep green. A
    missing snapshot is announced as not measured rather than counted as clean.
    """
    spec = read_json(root, map_rel)
    src = spec.get("snapshot_path_env")
    import os
    base = os.environ.get(src) if src else None
    if not base:
        return None, f"{spec['name']}: not measured here - set {src} to a checkout of {spec['commit'][:7]}"
    path = Path(base) / spec["path_in_snapshot"]
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return None, f"{spec['name']}: not measured - {exc}"

    cases = dig(doc, spec["cases_at"]) or []
    rows = []
    for case in cases:
        cid = str(case.get(spec["case_id_field"], "?"))
        blob = presented_blob(case, spec["presented_fields"])
        declared = []
        for kf in spec["key_fields"]:
            val = dig(case, kf)
            if isinstance(val, str) and val:
                declared.append(val)
        tok = [f"the value `{v}` its own key declares" for v in declared
               if re.search(rf"\b{re.escape(v)}\b", blob, re.I)]
        rem = remedy_leaks(blob, conf)
        rows.append((cid, tok, rem))
    return (spec, rows), None


# ---------------------------------------------------------------------------
def main(argv) -> int:
    root = Path(argv[1] if len(argv) > 1 else ".").resolve()
    conf = read_json(root, DATA)
    findings: list[str] = []
    info: list[str] = []
    checks = 0

    check_no_drift(root, conf)
    checks += 1

    rules_text = read(root, conf["rules_file"])
    rule_ids, cells, derive, notes = build_derivation(rules_text, conf)
    checks += 1
    for n in notes:
        info.append("derivation: " + n)

    terms_for = {a: forbidden_consequence_terms(cells[a]) for a in conf["answers"]}
    for answer, terms in terms_for.items():
        info.append(
            f"consequence terms forbidden for a `{answer}` case: "
            + (", ".join(f"`{t}`" for t in terms) if terms
               else "none - that row names no term, so only the rule id and the answer tokens are checked"))

    # ---- 2. the seal ------------------------------------------------------
    cases_rel = conf["dataset"]
    cases_text = read(root, cases_rel)
    key = read_json(root, conf["key"])
    try:
        dataset = json.loads(cases_text)
    except ValueError as exc:
        raise Unmeasured(f"{cases_rel} does not parse: {exc}") from exc

    digest = "sha256:" + hashlib.sha256(cases_text.encode("utf-8")).hexdigest()
    sealed = (key.get("seals") or {}).get("cases.json")
    checks += 1
    if not sealed:
        raise Unmeasured(
            f"{conf['key']} seals nothing: without a digest the key cannot be shown to "
            "describe this version of the cases, and a stale key scores nonsense confidently")
    if sealed != digest:
        findings.append(
            f"the key seals {sealed[:23]}... and {cases_rel} hashes to {digest[:23]}...: the cases "
            "were edited and the key was not, so every answer in it is about a file that no longer exists")

    # ---- 3. the rows ------------------------------------------------------
    cases = {c["case"]: c for c in dataset.get("cases", [])}
    answers = {a["case"]: a for a in key.get("answers", [])}
    if not cases:
        raise Unmeasured(f"{cases_rel} declares no cases")
    if not answers:
        raise Unmeasured(f"{conf['key']} declares no answers")

    checks += 2
    orphan_key = sorted(set(answers) - set(cases))
    orphan_case = sorted(set(cases) - set(answers))
    if orphan_key:
        findings.append(f"the key answers cases that do not exist: {orphan_key}")
    if orphan_case:
        findings.append(
            f"cases with no key row: {orphan_case} - a case nobody can score is a case that "
            "measures nothing")

    presented = dataset.get("presented_fields")
    if not presented:
        raise Unmeasured(
            f"{cases_rel} does not declare presented_fields, so the leak scan does not know "
            "which fields reach the reader and a green would mean it read nothing")

    for cid in sorted(set(cases) & set(answers)):
        case, row = cases[cid], answers[cid]
        rule, answer, consequence = row.get("rule"), row.get("answer"), row.get("consequence")

        checks += 1
        if rule not in rule_ids:
            findings.append(f"{cid}: cites `{rule}`, which {conf['rules_file']} does not declare")
            continue
        checks += 1
        if answer not in conf["answers"]:
            findings.append(
                f"{cid}: answers `{answer}`, which is outside the closed vocabulary "
                f"{conf['answers']}")
            continue

        checks += 1
        want = derive(rule, answer)
        if consequence != want:
            findings.append(
                f"{cid}: the key declares the consequence `{consequence}` and the table in "
                f"{conf['rules_file']} forces `{want}` from a `{answer}` on {rule}. The key and "
                "the table disagree, so the case is broken - not the table")

        checks += 1
        why = (row.get("why") or "").strip()
        if not why:
            findings.append(f"{cid}: the key gives no reason, and an answer with no reason is a guess")
        elif answer in conf["why_must_name_an_artifact_for"]:
            paths = [a.get("path", "") for a in case.get("artifact", []) if a.get("path")]
            if not any(p and p in why for p in paths):
                findings.append(
                    f"{cid}: a `{answer}` must name the artifact it rests on, and its reason names "
                    f"none of {paths}. This is invariant 2 of {conf['rules_file']}: "
                    '"it looked fine" is not an answer')

        # ---- 6. leak -----------------------------------------------------
        blob = presented_blob(case, presented)
        checks += 2
        if not blob.strip():
            findings.append(
                f"{cid}: the presented fields are empty, so the leak scan read nothing and a "
                "green for this case would be a green over an empty string")
            continue
        for hit in token_leaks(blob, conf, terms_for.get(answer, [])):
            findings.append(f"{cid}: its statement contains {hit} - the answer is inside the question")
        for hit in remedy_leaks(blob, conf):
            findings.append(f"{cid}: its statement {hit}")
        for hit in label_leaks(blob, conf):
            findings.append(
                f"{cid}: its statement {hit} - the vocabulary gate-bench-integrity.sh enforces "
                "over bench/cases, applied here because its scope does not reach bench/stages")

    # ---- 5. coverage ------------------------------------------------------
    cov = conf["coverage"]
    scored = [answers[c] for c in sorted(set(cases) & set(answers))]
    checks += 1
    if len(scored) < cov["minimum_cases"]:
        findings.append(
            f"the eval scores {len(scored)} cases and owes at least {cov['minimum_cases']}")
    for rid in rule_ids:
        checks += 1
        n = sum(1 for a in scored if a.get("rule") == rid)
        if n < cov["every_rule_at_least"]:
            findings.append(f"no case asks {rid}: a rule the eval never asks is a rule it does not measure")
    for ans in conf["answers"]:
        checks += 1
        n = sum(1 for a in scored if a.get("answer") == ans)
        if n < cov["every_answer_at_least"]:
            findings.append(
                f"no case answers `{ans}`: an answer the eval never reaches is a quarter of the "
                "vocabulary it does not test")
    reachable = {derive(r, a) for r in rule_ids for a in conf["answers"]}
    for cons in sorted(reachable):
        checks += 1
        n = sum(1 for a in scored if a.get("consequence") == cons)
        if n < cov["every_consequence_at_least"]:
            findings.append(f"no case lands on the consequence `{cons}`, which the table can reach")
    for rid in cov["unknown_required_for"]:
        checks += 1
        if not any(a.get("rule") == rid and a.get("answer") == "UNKNOWN" for a in scored):
            findings.append(
                f"no case asks {rid} in the direction where the condition could not be established. "
                "That is the direction a model over-affirms, and it is why this eval exists")

    info.append(
        f"measured: {len(scored)} case(s), {len(rule_ids)} rules, {checks} checks, "
        f"consequences reached {sorted(reachable)}")

    # ---- the foreign measurement, reported and never enforced -------------
    for map_rel in conf.get("foreign_maps", []):
        try:
            result, why_not = measure_foreign(root, conf, map_rel)
        except Unmeasured as exc:
            info.append(f"foreign: not measured - {exc}")
            continue
        if result is None:
            info.append(f"foreign: {why_not}")
            continue
        spec, rows = result
        leaked = [r for r in rows if r[1] or r[2]]
        info.append(f"foreign: {spec['name']} @ {spec['commit'][:7]} - "
                    f"{len(leaked)} of {len(rows)} case(s) would not pass this scan")
        for cid, tok, rem in rows:
            for h in tok + rem:
                info.append(f"foreign:   {cid}: {h}")

    return 1 if findings else 0, findings, info


if __name__ == "__main__":
    try:
        code, findings, info = main(sys.argv)
    except Unmeasured as exc:
        print(f"UNMEASURED {exc}")
        sys.exit(2)
    for line in info:
        print(line)
    for line in findings:
        print("FINDING " + line)
    sys.exit(code)
