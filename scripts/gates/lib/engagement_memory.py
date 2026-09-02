#!/usr/bin/env python3
"""Measurement core for gate-engagement-memory.sh.

READS
  references/vocabulary.md          dimensions 5 and 6: baseline_state, disposition
  references/findings.schema.json   the fingerprint block and what it may be keyed on
  scripts/gates/fixtures/findings   the artifacts the memory arithmetic is exercised on

The terms are vocabulary.md's and the key's inputs are the schema's. Neither is
this file's to own: a gate that remembers the vocabulary it was built for would
keep enforcing it after the vocabulary changed underneath, which is how a check
survives the thing it was checking.

Prints FINDING / UNMEASURED lines for the wrapper to classify. Exit codes follow
the repo contract: 0 measured fine, 1 measured FAILS, 2 could not measure.
"""
import hashlib
import json
import re
import sys
from pathlib import Path

VOCAB = "skills/ethical-hacker-squad/references/vocabulary.md"
SCHEMA = "skills/ethical-hacker-squad/references/findings.schema.json"
DOC = "skills/ethical-hacker-squad/references/findings-artifact.md"
FIXTURES = "scripts/gates/fixtures/findings"

DECLARE = r"<!--\s*vocabulary:declare {name}\s*-->(.*?)<!--\s*/vocabulary:declare\s*-->"
TERM_ROW = re.compile(r"^\|\s*`([a-z ]+)`\s*\|", re.M)
INVARIANT = re.compile(r"^(\d{1,2})\. \*\*", re.M)

# The terms this gate was built to reason about. NOT the source of truth - the
# claim the gate makes about what it understands. Each is load-bearing somewhere
# in the invariants, so when vocabulary.md stops declaring one the honest answer
# is 2: the gate cannot tell whether the rule was retired or renamed.
STATES_BUILT_FOR = {"new", "unchanged", "updated", "unmeasured"}
DISPOSITIONS_BUILT_FOR = {"fixed", "refuted", "out of scope", "not measured"}


class Unmeasured(Exception):
    pass


def read(root: Path, rel: str) -> str:
    p = root / rel
    if not p.is_file():
        raise Unmeasured(f"{rel} is missing")
    return p.read_text(encoding="utf-8")


def terms(text: str, name: str) -> set[str]:
    m = re.search(DECLARE.format(name=name), text, re.S)
    if not m:
        raise Unmeasured(f"{VOCAB} declares no region for `{name}`: dimension gone")
    got = {t.strip() for t in TERM_ROW.findall(m.group(1))}
    if not got:
        raise Unmeasured(f"{VOCAB}: the `{name}` region declares no terms")
    return got


def fp_v1(finding: dict, inputs) -> str | None:
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


def main() -> int:
    if len(sys.argv) < 2:
        raise Unmeasured("no repository root given")
    root = Path(sys.argv[1]).resolve()
    problems: list[str] = []

    vocab_text = read(root, VOCAB)
    states = terms(vocab_text, "baseline_state")
    disps = terms(vocab_text, "disposition")

    # C1/C2. The gate says what it understands, and stops when it stops understanding.
    for missing, name in ((STATES_BUILT_FOR - states, "baseline_state"),
                          (DISPOSITIONS_BUILT_FOR - disps, "disposition")):
        if missing:
            raise Unmeasured(
                f"{VOCAB} no longer declares {', '.join(sorted(repr(m) for m in missing))} "
                f"for `{name}`: every invariant that branches on those terms is now "
                "unenforceable, and this gate cannot tell a retirement from a rename")

    schema = json.loads(read(root, SCHEMA))
    try:
        fp = schema["properties"]["findings"]["items"]["properties"]["fingerprint"]
        alg = fp["properties"]["algorithm"]
        allowed = fp["properties"]["inputs"]["items"]["enum"]
    except (KeyError, TypeError) as exc:
        raise Unmeasured(f"{SCHEMA}: the fingerprint block is not where it was ({exc})") from exc

    # C3. The decision this whole design rests on. A key that includes a line
    #     number moves when a comment is inserted above the defect, and then every
    #     rebase reports the whole tree as new findings. Measured over 117 real
    #     artifacts: the line key re-identified 55 findings where the structural
    #     key re-identified 18 - it looks better precisely because it is counting
    #     matches a rebase would have destroyed.
    linekeys = [k for k in allowed if k.endswith(".line") or k == "line"]
    if linekeys:
        problems.append(
            f"{SCHEMA}: `fingerprint.inputs` admits {linekeys}, so a key may be built on a "
            "line number. That is the one input this algorithm exists to exclude")
    # C3b. The constraint the roadmap item was written with. A carried-over
    #      entry is the only record of a defect that left the live list, so
    #      dropping `procedure` from it restores, in silence, the exact
    #      failure mode this whole item exists to avoid.
    try:
        co_required = schema["properties"]["carried_over"]["items"]["required"]
    except (KeyError, TypeError) as exc:
        raise Unmeasured(
            f"{SCHEMA}: the carried_over block is not where it was ({exc})") from exc
    if "procedure" not in co_required:
        problems.append(
            f"{SCHEMA}: `carried_over` no longer requires `procedure`. That array is "
            "the only place a defect leaves the live list, so it is the only place the "
            "audit trail can end without anything saying so")
    if alg.get("const") != "ehs.fp/v1":
        problems.append(f"{SCHEMA}: the fingerprint algorithm is no longer `ehs.fp/v1`")
    for needed in ("U+001F", "RECOMPUTES"):
        if needed not in alg.get("description", ""):
            problems.append(
                f"{SCHEMA}: the algorithm description no longer states `{needed}` - an "
                "algorithm that stops being specified stops being reproducible")

    # C4. The doc numbers its invariants contiguously. A gap is a rule that was
    #     deleted without saying so; a repeat is two rules a reader will conflate.
    nums = [int(n) for n in INVARIANT.findall(read(root, DOC))]
    if not nums:
        raise Unmeasured(f"{DOC} declares no numbered invariant")
    if sorted(nums) != list(range(1, len(nums) + 1)):
        problems.append(
            f"{DOC}: the invariants are numbered {nums}, which is not 1..{len(nums)} - a gap "
            "is a rule retired in silence and a repeat is two rules a reader will conflate")

    # --- the corpus ---------------------------------------------------------
    fixdir = root / FIXTURES
    if not fixdir.is_dir():
        raise Unmeasured(f"{FIXTURES} is missing")
    states_seen: set[str] = set()
    disps_seen: set[str] = set()
    baselines = lineages = carried = collisions = 0
    fp_total = fp_ok = 0
    for path in sorted(fixdir.rglob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue  # bad/ holds artifacts that are meant to be broken
        if not isinstance(data, dict):
            continue
        eng = data.get("engagement") if isinstance(data.get("engagement"), dict) else {}
        if isinstance(eng.get("baseline"), dict):
            baselines += 1
        by_value: dict[str, int] = {}
        for f in (data.get("findings") or []):
            if not isinstance(f, dict):
                continue
            if isinstance(f.get("baseline_state"), str):
                states_seen.add(f["baseline_state"])
            if f.get("lineage"):
                lineages += 1
            block = f.get("fingerprint")
            if isinstance(block, dict) and isinstance(block.get("value"), str):
                by_value[block["value"]] = by_value.get(block["value"], 0) + 1
                # Only under good/. A fixture in bad/ is a deliberately broken
                # artifact - two of them exist precisely BECAUSE their fingerprint
                # does not reproduce - and counting those as corpus defects would
                # make this gate accuse the negative proof of being negative.
                if block.get("algorithm") == "ehs.fp/v1" and path.parent.name == "good":
                    fp_total += 1
                    if fp_v1(f, block.get("inputs") or []) == block["value"]:
                        fp_ok += 1
        collisions += sum(1 for n in by_value.values() if n > 1)
        for c in (data.get("carried_over") or []):
            if isinstance(c, dict):
                carried += 1
                if isinstance(c.get("disposition"), str):
                    disps_seen.add(c["disposition"])

    # C5. A term nobody ever writes is a term nobody checks. This is the one that
    #     catches a vocabulary drifting away from the corpus that uses it.
    unexercised = (states - states_seen) | (disps - disps_seen)
    if unexercised:
        problems.append(
            f"{FIXTURES}: no fixture ever writes "
            f"{', '.join(sorted(repr(t) for t in unexercised))}, so the rules that branch on "
            "those terms are never exercised by anything in this repository")

    # C6/C7/C8. Each of these reaches zero through a state someone can actually
    # create - delete the v2 fixtures, drop the colliding pair, empty the
    # carried_over list - and each such state silently retires a control while
    # every gate stays green. That is not "I checked nothing": it is a control
    # withdrawn without a line of prose saying so, so it exits 2.
    if baselines == 0:
        raise Unmeasured(
            "not one fixture declares `engagement.baseline`, so invariants 20-29 had nothing "
            "to bite on in this run: either the corpus stopped carrying a memory or this "
            "gate stopped recognising one")
    if lineages == 0:
        raise Unmeasured(
            "no fixture continues a baseline finding, so the whole matching half of the "
            "contract was never exercised")
    if collisions == 0:
        raise Unmeasured(
            "no two findings in any fixture share a fingerprint, so `ordinal` was never "
            "asked to break a tie and the rule that governs it never fired")
    if carried == 0:
        raise Unmeasured(
            "no fixture carries a `carried_over` entry, so the list that exists to stop a "
            "defect vanishing in silence vanished in silence")

    if fp_total and fp_ok != fp_total:
        problems.append(
            f"{fp_total - fp_ok} of {fp_total} `ehs.fp/v1` fingerprint(s) in the corpus do "
            "not reproduce from the fields their `inputs` name")

    print(f"vocabulary: {len(states)} baseline_state term(s), {len(disps)} disposition(s), "
          f"all exercised by the corpus")
    print(f"memory.baselines_declared = {baselines}")
    print(f"memory.lineages = {lineages}, memory.carried_over = {carried}, "
          f"memory.fingerprint_collisions = {collisions}")
    print(f"memory.fingerprints_reproduced = {fp_ok}/{fp_total} (good/ only: a bad/ "
          f"fixture whose key does not reproduce is doing its job)")
    print(f"invariants: {len(nums)} numbered 1..{len(nums)} in findings-artifact.md")
    for p in problems:
        print(f"FINDING {p}")
    return 1 if problems else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Unmeasured as exc:
        print(f"UNMEASURED {exc}")
        sys.exit(2)
