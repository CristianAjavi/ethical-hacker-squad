#!/usr/bin/env python3
"""Measurement core for gate-severity-calibration.sh.

READS
  references/triage.md              the caps region: id, tier, ceiling
  references/vocabulary.md          the severity terms and, separately, their ORDER
  scripts/gates/fixtures/findings   the artifacts the cap arithmetic is exercised on

The ceilings are triage.md's and the order is vocabulary.md's. Neither is this
file's to own: a gate that remembers the order it was built for would keep
enforcing it after the vocabulary changed underneath, which is how a check
survives the thing it was checking.

Prints FINDING / UNMEASURED lines for the wrapper to classify. Exit codes follow
the repo contract: 0 measured fine, 1 measured FAILS, 2 could not measure.
"""
import json
import re
import sys
from pathlib import Path

TRIAGE = "skills/ethical-hacker-squad/references/triage.md"
VOCAB = "skills/ethical-hacker-squad/references/vocabulary.md"
FIXTURES = "scripts/gates/fixtures/findings"

SEV_REGION = re.compile(r"<!--\s*severity:caps\s*-->(.*?)<!--\s*/severity:caps\s*-->", re.S)
SEV_ROW = re.compile(r"^\|\s*`(SEV-\d{2})`\s*\|\s*([a-z ]+?)\s*\|\s*`([a-z]+)`\s*\|", re.M)
VOCAB_DECLARE = re.compile(
    r"<!--\s*vocabulary:declare severity\s*-->(.*?)<!--\s*/vocabulary:declare\s*-->", re.S)
TERM_ROW = re.compile(r"^\|\s*`([a-z ]+)`\s*\|", re.M)
ORDER_LINE = re.compile(r"^`critical`(?:\s*>\s*`[a-z]+`)+", re.M)
ORDER_TERMS = re.compile(r"`([a-z]+)`")
TITLE = re.compile(r"^#\s+.*$", re.M)
RANGE_CITED = re.compile(r"`SEV-(\d{2})`\.\.`SEV-(\d{2})`")

TIERS = ("always", "on trigger", "derived")

# The order this gate was built to enforce. It is NOT the source of truth - it is
# the claim the gate makes about what it understands. When vocabulary.md says
# something else, the honest answer is 2: the gate cannot know whether its
# arithmetic still means what it meant.
ORDER_BUILT_FOR = ["critical", "high", "medium", "low", "informational"]

NUMERALS = {
    "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
    "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13,
    "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18,
    "nineteen": 19, "twenty": 20,
}
WORD = {v: k for k, v in NUMERALS.items()}


class Unmeasured(Exception):
    pass


def read(root: Path, rel: str) -> str:
    p = root / rel
    if not p.is_file():
        raise Unmeasured(f"{rel} is not there to read")
    return p.read_text(encoding="utf-8")


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    findings: list[str] = []

    triage_text = read(root, TRIAGE)
    vocab_text = read(root, VOCAB)

    # ---- C1 the caps region -------------------------------------------------
    m = SEV_REGION.search(triage_text)
    if not m:
        raise Unmeasured(f"{TRIAGE} has no <!-- severity:caps --> region to read")
    rows = SEV_ROW.findall(m.group(1))
    if not rows:
        raise Unmeasured(f"{TRIAGE} declares a caps region with no rows in it")

    ids = [r[0] for r in rows]
    caps = {}
    for rid, tier, ceiling in rows:
        if rid in caps:
            findings.append(f"the caps region declares `{rid}` twice")
            continue
        caps[rid] = (tier, ceiling)
    for i, rid in enumerate(sorted(caps), start=1):
        want = f"SEV-{i:02d}"
        if rid != want:
            findings.append(f"the caps region skips `{want}`: the ids must run contiguously from `SEV-01`")
            break

    # ---- C6 the order, before anything that depends on it -------------------
    om = ORDER_LINE.search(vocab_text)
    if not om:
        raise Unmeasured(
            f"{VOCAB} no longer states the order of the severity terms, so the ceiling "
            "this gate enforces would be this gate's memory")
    order = ORDER_TERMS.findall(om.group(0))
    if order != ORDER_BUILT_FOR:
        raise Unmeasured(
            f"{VOCAB} now orders the severity terms as {' > '.join(order)} where this gate "
            f"was built for {' > '.join(ORDER_BUILT_FOR)}; the arithmetic may no longer mean "
            "what it meant, and a gate that keeps applying its own memory outlives the thing "
            "it was checking")

    # ---- C2 / C3 / C4 the cells ---------------------------------------------
    dm = VOCAB_DECLARE.search(vocab_text)
    if not dm:
        raise Unmeasured(f"{VOCAB} has no <!-- vocabulary:declare severity --> region")
    declared = set(TERM_ROW.findall(dm.group(1)))
    if not declared:
        raise Unmeasured(f"{VOCAB} declares no severity term")

    for rid in sorted(caps):
        tier, ceiling = caps[rid]
        if ceiling not in declared:
            findings.append(
                f"`{rid}` names the ceiling `{ceiling}`, which vocabulary.md does not declare")
        elif ceiling == order[0]:
            findings.append(
                f"`{rid}` names the ceiling `{ceiling}`, the top of the order: a cap that "
                "forbids nothing is not a cap")
        if tier not in TIERS:
            findings.append(
                f"`{rid}` declares the tier `{tier}`, which is none of {', '.join(TIERS)}")
    if not any(t == "always" for t, _ in caps.values()):
        findings.append(
            "no cap is declared `always`: nothing is then required of a `critical`, and the "
            "requirement that buys the expensive labels could never fire")

    # ---- C5 the two counts that drift ---------------------------------------
    n = len(caps)
    title = TITLE.search(triage_text)
    title_text = title.group(0) if title else ""
    tm = re.search(r"\b(" + "|".join(NUMERALS) + r")\s+caps\b", title_text)
    if not tm:
        raise Unmeasured(
            f"{TRIAGE}'s title does not say how many caps it declares, so nothing can be "
            "compared against the rows")
    announced = NUMERALS[tm.group(1)]
    if announced != n:
        findings.append(
            f"triage.md announces {WORD.get(announced, announced)} caps and declares "
            f"{WORD.get(n, n)}")
    rm = RANGE_CITED.search(vocab_text)
    if not rm:
        raise Unmeasured(
            f"{VOCAB} does not cite the cap range, so the two documents cannot be compared")
    lo, hi = int(rm.group(1)), int(rm.group(2))
    if (lo, hi) != (1, n):
        findings.append(
            f"vocabulary.md points at `SEV-{lo:02d}`..`SEV-{hi:02d}` and triage.md declares "
            f"`SEV-01`..`SEV-{n:02d}`")

    # ---- C7 / C8 the arithmetic actually ran --------------------------------
    rank = {t: i for i, t in enumerate(order)}
    compared = 0
    expensive_total = 0
    expensive_calibrated = 0
    fixtures = sorted((root / FIXTURES).rglob("*.json"))
    if not fixtures:
        raise Unmeasured(f"{FIXTURES} holds no artifact to exercise the caps on")
    always = sorted(k for k, (t, _) in caps.items() if t == "always")
    for f in fixtures:
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except (ValueError, OSError):
            continue  # malformed fixtures are gate-findings-artifact.sh's business
        if not isinstance(data, dict):
            continue
        for item in data.get("findings") or []:
            if not isinstance(item, dict):
                continue
            sev = item.get("severity")
            if sev not in ("critical", "high"):
                continue
            expensive_total += 1
            cal = item.get("severity_calibration")
            cal = cal if isinstance(cal, list) else []
            answered = {c.get("rule") for c in cal if isinstance(c, dict)}
            if all(a in answered for a in always):
                expensive_calibrated += 1
            for c in cal:
                if not isinstance(c, dict):
                    continue
                rid, ans = c.get("rule"), c.get("answer")
                if ans in ("HOLDS", "UNKNOWN") and rid in caps and sev in rank:
                    if caps[rid][1] in rank:
                        compared += 1

    print(f"caps: {n} declared, {len(always)} in the `always` tier ({', '.join(always)})")
    print(f"order: {' > '.join(order)} (vocabulary.md's, not this gate's)")
    print(f"severity.calibration_rules = {n}")
    print(f"severity.findings_calibrated = {expensive_calibrated}/{expensive_total}")
    print(f"severity.caps_compared = {compared}")

    # C8 before C7, and the order is load-bearing. A comparison is only ever
    # counted on a `critical` or `high` finding, so no expensive finding forces
    # zero comparisons too: reporting the missing arithmetic first would name a
    # symptom and hide its cause, which is a correct exit code for the wrong
    # reason. The self-test asserts the message, not only the 2.
    if expensive_total == 0:
        raise Unmeasured(
            "no fixture carries a `critical` or `high` finding, so the requirement that buys "
            "those labels was not exercised")
    if compared == 0:
        raise Unmeasured(
            "not one ceiling was compared against a label in this run: either the fixtures "
            "stopped exercising the caps or this gate stopped recognising how they do")

    for msg in findings:
        print(f"FINDING {msg}")
    if findings:
        return 1
    print("every ceiling is a term vocabulary.md declares, none of them the top of the order")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Unmeasured as e:
        print(f"UNMEASURED {e}")
        sys.exit(2)
