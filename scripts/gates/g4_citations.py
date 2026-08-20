#!/usr/bin/env python3
"""G4 - every knowledge item is cited, and carries the fields that make it usable.

G4a - every procedure has a `Traceability` line naming at least one standard
      identifier, and **every identifier it names belongs to a known family**.
      The second half is what catches a fabricated ID: an invented
      `OWASP-MOBILE-TOP-99` sitting next to four real ones survives human
      review precisely because it looks correct.
G4b - every procedure carries the six fields `CONTRIBUTING.md` requires. The
      one that matters most is `What rules it out (false positive)`: a
      procedure without it manufactures false positives, which is this
      repository's first-class defect type.
G4c - every quantitative claim in the corpus names its source. A prose line
      stating a percentage must carry a citation marker inside its own
      paragraph.

Three limits, stated rather than hidden. A family match proves an identifier is
well-formed, never that the standard says what the procedure claims. Fenced
blocks are not scanned by G4c, so a figure that only appears inside an
illustrative example is not measured. And a citation marker proves a source is
named, not that it supports the sentence - that is a reviewer's job.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

from lib import Unmeasured, knowledge_packs, run, split_procedures

DATA = Path(__file__).resolve().parent / "data" / "identifier-families.json"

FIELDS = [
    ("Where to look", re.compile(r"\*\*Where to look\*\*")),
    ("Vulnerable pattern", re.compile(r"\*\*Vulnerable pattern\*\*")),
    ("What rules it out", re.compile(r"\*\*What rules it out")),
    ("Minimal test", re.compile(r"\*\*Minimal test\*\*")),
    ("Traceability", re.compile(r"\*\*Traceability\*\*")),
    ("Tooling", re.compile(r"\*\*Tooling\*\*")),
]
TRACE_LINE = re.compile(r"^\s*\*\*Traceability\*\*:?(.*)$", re.MULTILINE)
BACKTICKED = re.compile(r"`([^`]*)`")
PERCENT = re.compile(r"\b\d{1,3}(?:\.\d+)?%")
SOURCE_MARKER = re.compile(
    r"et al\.|arXiv:\d{4}\.\d{4,5}|(?:19|20)\d{2}-\d{2}-\d{2}|(?:19|20)\d{2}\b|"
    r"Verizon|DBIR|OWASP|NIST|MITRE|CISA|ENISA|Sonatype|Snyk|Endor|Datadog|Orca|Wiz|"
    r"Veracode|Chainguard|Aqua|Palo Alto|Unit 42|Invariant|Pillar|Willison|Trail of Bits|"
    r"GitHub|Google|Microsoft|Anthropic|OpenAI|CSA|SLSA|ISSTA|EASE|USENIX|IEEE|ACM|DSN|"
    r"AgentDojo|Report|report|study|measured|Measured"
)
# A Traceability line may declare explicitly that no external identifier applies.
# Recorded as a declared exemption and printed, so the escape hatch stays visible
# instead of quietly swallowing uncited procedures.
EXEMPTION = re.compile(r"internal process|no external identifier|from the original finding", re.I)


def load_families() -> re.Pattern[str]:
    try:
        families = json.loads(DATA.read_text(encoding="utf-8"))["families"]
    except (OSError, ValueError, KeyError) as exc:
        raise Unmeasured(f"cannot read the identifier families at {DATA}: {exc}") from exc
    return re.compile("^(?:" + "|".join(families.values()) + ")$")


def check(gate) -> None:
    family_re = load_families()
    exemptions: list[str] = []

    for path in knowledge_packs(gate):
        rel = path.relative_to(gate.root)
        text = gate.read_text(rel)
        procedures = split_procedures(text)
        if not procedures:
            gate.fail(str(rel), "no procedures found; the pack heading pattern may have changed")

        for pid, _tail, body in procedures:
            gate.counted()
            missing = [name for name, pattern in FIELDS if not pattern.search(body)]
            if missing:
                gate.fail(f"{rel}:{pid}", f"missing mandatory field(s): {', '.join(missing)}")
            m = TRACE_LINE.search(body)
            if not m:
                continue  # already reported by the field check
            trace = m.group(1)
            tokens = [t.strip() for t in BACKTICKED.findall(trace) if t.strip()]
            if not tokens:
                if EXEMPTION.search(trace):
                    exemptions.append(f"{rel}:{pid}")
                else:
                    gate.fail(
                        f"{rel}:{pid}",
                        "Traceability line names no standard identifier: "
                        f"{trace.strip()[:80]!r}",
                    )
                continue
            for token in tokens:
                gate.counted()
                if not family_re.match(token):
                    gate.fail(
                        f"{rel}:{pid}",
                        f"identifier `{token}` matches no known family "
                        "(scripts/gates/data/identifier-families.json); either it is "
                        "malformed or the standard is not declared",
                    )

        lines = text.splitlines()
        in_fence = False
        for i, line in enumerate(lines):
            if line.lstrip().startswith("```"):
                in_fence = not in_fence
                continue
            if in_fence or not PERCENT.search(line):
                continue
            gate.counted()
            start = i
            while start > 0 and lines[start - 1].strip():
                start -= 1
            end = i
            while end + 1 < len(lines) and lines[end + 1].strip():
                end += 1
            window = " ".join(lines[start : end + 1])
            if not SOURCE_MARKER.search(window):
                gate.fail(
                    f"{rel}:{i + 1}",
                    f"quantitative claim with no source in its paragraph: {line.strip()[:90]!r}",
                )

    if exemptions:
        gate.note(
            f"{len(exemptions)} procedure(s) declare no external identifier applies: "
            + ", ".join(exemptions)
        )


if __name__ == "__main__":
    run("G4", "knowledge items cited and complete", check)
