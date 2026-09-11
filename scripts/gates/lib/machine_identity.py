#!/usr/bin/env python3
"""Engine for gate-machine-identity.sh.

Sweeps the versioned tree for paths that belong to ONE machine and measures the
result against the frozen inventory in scripts/gates/data/machine-identity.json.

The shapes are NOT written here. They are read from that file, which is also
where scripts/gates/lib/external_crosscheck.py's MACHINE_PATHS list is
reconciled against, so the definition has one home instead of one per consumer.
A second list would be a second answer to the same question.

Exit codes follow the repository contract: 0 measured and clean, 1 measured and
failing, 2 could not measure.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

OK, FAIL, UNMEASURABLE = 0, 1, 2

DATA_REL = "scripts/gates/data/machine-identity.json"
CROSSCHECK_REL = "scripts/gates/lib/external_crosscheck.py"
REQUIRED_KEYS = ("patterns", "frozen", "totals", "self_exemption")


class Unmeasurable(Exception):
    pass


def load_contract(root: Path) -> dict:
    path = root / DATA_REL
    if not path.is_file():
        raise Unmeasurable(f"{DATA_REL} is missing")
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise Unmeasurable(f"{DATA_REL} does not parse: {exc}") from exc
    for key in REQUIRED_KEYS:
        if key not in doc:
            raise Unmeasurable(f"{DATA_REL} has no '{key}'")
    if not isinstance(doc["patterns"], list) or not doc["patterns"]:
        raise Unmeasurable(f"{DATA_REL} declares no patterns")
    if not isinstance(doc["frozen"], dict):
        raise Unmeasurable(f"{DATA_REL} 'frozen' is not an object")
    try:
        doc["_compiled"] = [re.compile(p) for p in doc["patterns"]]
    except re.error as exc:
        raise Unmeasurable(f"{DATA_REL} has an unusable pattern: {exc}") from exc
    return doc


def versioned_files(root: Path) -> list[str]:
    try:
        out = subprocess.run(
            ["git", "-C", str(root), "ls-files", "-z"],
            capture_output=True, text=True, check=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError) as exc:
        raise Unmeasurable(f"git could not list the tree: {exc}") from exc
    names = [n for n in out.split("\0") if n]
    if not names:
        raise Unmeasurable("git listed no files - this is not a work tree")
    return names


def count_in(path: Path, compiled) -> int:
    """Occurrences in one file. Binary and undecodable files count as zero.

    They are not skipped silently: the caller reports how many were skipped, so
    an rc=0 never covers a file nobody could read.
    """
    try:
        raw = path.read_bytes()
    except OSError:
        return -1
    if b"\0" in raw[:8192]:
        return -1
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        return -1
    return sum(len(p.findall(text)) for p in compiled)


def sweep(root: Path, doc: dict) -> tuple[dict, int, int]:
    compiled = doc["_compiled"]
    exempt = doc["self_exemption"]
    found: dict[str, int] = {}
    read = skipped = 0
    for rel in versioned_files(root):
        if rel == exempt:
            continue
        n = count_in(root / rel, compiled)
        if n < 0:
            skipped += 1
            continue
        read += 1
        if n:
            found[rel] = n
    return found, read, skipped


def compare(found: dict, frozen: dict, expected: dict) -> tuple:
    """new = a file with no allowance at all; grown = over its allowance;
    stale = an allowance the tree no longer needs; arrived = a file declared in
    advance because it lives on an open branch, now present and within its
    allowance.

    `expected` exists because three files on the open branches carry one of
    these shapes for a legitimate reason - two are fixtures that plant the
    shape, one is the pattern list itself - and none of them is in this branch.
    Without a forward declaration this gate would go red the moment those
    branches merge, which is the precise class of defect that only the union of
    branches can see.
    """
    new, grown, stale, arrived = [], [], [], []
    for rel, n in sorted(found.items()):
        allowed = frozen.get(rel)
        if allowed is None:
            fwd = expected.get(rel)
            if fwd is None:
                new.append((rel, n))
            elif n > fwd["occurrences"]:
                grown.append((rel, fwd["occurrences"], n))
            else:
                arrived.append((rel, n, fwd["branch"]))
        elif n > allowed:
            grown.append((rel, allowed, n))
    for rel, allowed in sorted(frozen.items()):
        actual = found.get(rel, 0)
        if actual < allowed:
            stale.append((rel, allowed, actual))
    return new, grown, stale, arrived


def check_expected(root: Path, expected: dict, frozen: dict) -> tuple[list, list, int]:
    """A file declared as arriving from a branch must actually be on that branch.

    Returns (failures, unverifiable, verified). A ref this checkout does not
    have is NOT a pass: it is counted separately and printed, because a shallow
    CI checkout is exactly where a false declaration would hide.
    """
    failures, unverifiable, verified = [], [], 0
    compiled_cache = None
    for rel, spec in sorted(expected.items()):
        for field in ("occurrences", "branch", "why"):
            if field not in spec:
                failures.append(f"{rel} declares no '{field}'")
        if rel in frozen:
            failures.append(f"{rel} is in both frozen and expected_on_merge: "
                            f"one file, two ceilings, and the looser one wins by accident")
        branch = spec.get("branch")
        if not branch:
            continue
        probe = subprocess.run(["git", "-C", str(root), "cat-file", "-e", f"{branch}:{rel}"],
                               capture_output=True, text=True)
        if probe.returncode != 0:
            has_ref = subprocess.run(["git", "-C", str(root), "rev-parse", "--verify", "-q", branch],
                                     capture_output=True, text=True).returncode == 0
            if has_ref:
                failures.append(f"{rel} claims to come from {branch}, which does not have it")
            else:
                unverifiable.append(f"{rel} names {branch}, a ref this checkout does not have")
            continue
        verified += 1
    return failures, unverifiable, verified


def crosscheck_definition(root: Path, doc: dict) -> tuple[str, list]:
    """Is there a second list of the same shapes in this tree?

    Returns (state, detail). state is 'absent' when the other consumer is not in
    this branch - which is NOT a pass, it is a measurement that does not apply
    here, and the gate says so on screen.
    """
    path = root / CROSSCHECK_REL
    if not path.is_file():
        return "absent", []
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise Unmeasurable(f"{CROSSCHECK_REL} exists but cannot be read: {exc}")
    # The closing bracket is matched at the start of a line, NOT as the first ]
    # in the block: the first ] in this list belongs to [A-Za-z0-9._-], and a
    # non-greedy match stopped there and read the list as empty - which looked
    # exactly like "the other consumer disagrees about all five shapes".
    block = re.search(r"MACHINE_PATHS\s*=\s*\[\s*$(.*?)^\]", text, re.S | re.M)
    if not block:
        return "no-list", []
    theirs = re.findall(r"re\.compile\(r\"(.*?)\"\)", block.group(1))
    mine = list(doc["patterns"])
    if sorted(theirs) == sorted(mine):
        return "agrees", theirs
    return "diverged", [p for p in theirs if p not in mine] + \
                       [p for p in mine if p not in theirs]


def rewrite(root: Path, doc: dict, found: dict) -> None:
    """--update: the ratchet may only turn down. Never writes a new entry."""
    path = root / DATA_REL
    raw = json.loads(path.read_text(encoding="utf-8"))
    frozen = dict(raw["frozen"])
    expected = raw.get("expected_on_merge", {})
    for rel, n in found.items():
        if rel in expected and n <= expected[rel].get("occurrences", -1):
            continue
        if rel not in frozen or n > frozen[rel]:
            raise Unmeasurable(
                f"--update refuses to enlarge the inventory: {rel} would go to {n}"
            )
    for rel in list(frozen):
        actual = found.get(rel, 0)
        if actual == 0:
            del frozen[rel]
        elif actual < frozen[rel]:
            frozen[rel] = actual
    raw["frozen"] = dict(sorted(frozen.items()))
    raw["totals"] = {"files": len(frozen), "occurrences": sum(frozen.values())}
    path.write_text(json.dumps(raw, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main(argv: list[str]) -> int:
    root = Path(argv[1]) if len(argv) > 1 else Path.cwd()
    do_update = "--update" in argv[2:]
    try:
        doc = load_contract(root)
        found, read, skipped = sweep(root, doc)
        frozen = doc["frozen"]

        declared = doc["totals"]
        if declared.get("files") != len(frozen) or \
           declared.get("occurrences") != sum(frozen.values()):
            print(f"FAIL  the inventory contradicts its own total: it lists "
                  f"{len(frozen)} file(s)/{sum(frozen.values())} occurrence(s) "
                  f"and declares {declared.get('files')}/{declared.get('occurrences')}")
            return FAIL

        if do_update:
            rewrite(root, doc, found)
            print("inventory rewritten downward")
            return OK

        expected = doc.get("expected_on_merge", {})
        if not isinstance(expected, dict):
            raise Unmeasurable(f"{DATA_REL} 'expected_on_merge' is not an object")
        new, grown, stale, arrived = compare(found, frozen, expected)
        state, detail = crosscheck_definition(root, doc)
        exp_fail, exp_unver, exp_ok = check_expected(root, expected, frozen)

        print(f"read      : {read} versioned text file(s); {skipped} binary or "
              f"undecodable and not read; 1 exempt ({doc['self_exemption']})")
        print(f"inventory : {len(frozen)} file(s) carry {sum(frozen.values())} "
              f"occurrence(s), frozen; the tree now shows {sum(found.values())}")
        print(f"declared  : {len(expected)} file(s) declared in advance from open "
              f"branches - {exp_ok} confirmed on the branch named, "
              f"{len(exp_unver)} not verifiable from this checkout, "
              f"{len(arrived)} already here")

        rc = OK
        for msg in exp_fail:
            print(f"FAIL  {msg}")
            rc = FAIL
        for msg in exp_unver:
            print(f"n/a   {msg}; the declaration stands unchecked here, which is "
                  f"not the same as checked")
        for rel, n, branch in arrived:
            print(f"OK    {rel} arrived from {branch} carrying {n}, within its "
                  f"declared allowance")
        for rel, n in new:
            print(f"FAIL  {rel} carries {n} machine path(s) and has no allowance: "
                  f"a path that names one laptop is a number nobody can reproduce")
            rc = FAIL
        for rel, allowed, n in grown:
            print(f"FAIL  {rel} grew from {allowed} to {n}: the inventory is a "
                  f"ratchet and only turns down")
            rc = FAIL
        for rel, allowed, n in stale:
            print(f"FAIL  {rel} is allowed {allowed} but carries {n}: the debt was "
                  f"paid and the inventory still claims it "
                  f"(fix: gate-machine-identity.sh --update)")
            rc = FAIL

        if state == "agrees":
            print(f"OK    {CROSSCHECK_REL} spells the same {len(detail)} shape(s); "
                  f"one definition, two consumers")
        elif state == "diverged":
            print(f"FAIL  {CROSSCHECK_REL} spells a different list; these differ: "
                  f"{detail}")
            rc = FAIL
        elif state == "no-list":
            print(f"FAIL  {CROSSCHECK_REL} is present but declares no MACHINE_PATHS "
                  f"to reconcile against")
            rc = FAIL
        else:
            print(f"n/a   {CROSSCHECK_REL} is not in this branch, so the "
                  f"one-definition check did not run here. It is not a pass; it "
                  f"becomes measurable the moment that file arrives.")

        return rc
    except Unmeasurable as exc:
        print(f"COULD NOT MEASURE: {exc}")
        return UNMEASURABLE


if __name__ == "__main__":
    sys.exit(main(sys.argv))
