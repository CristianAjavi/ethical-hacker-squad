#!/usr/bin/env python3
"""Measurement core of gate-licence-hygiene.sh (G5).

The repository is MIT and most of what it cites is not: OWASP is CC BY-SA, the
CIS Controls are non-commercial no-derivatives, several vendor guides are
proprietary. `NOTICE.md` states the consequence as an absolute - the corpus
cites identifiers and writes its own prose - and until now nothing checked it.

Four measurements:

  1. attributed verbatim   a quoted span longer than MAX_QUOTED_WORDS words,
                           near the name of an external owner, anywhere under
                           skills/ or docs/. Spans containing a backtick are
                           skipped: those are commands and regexes, not prose.
  2. denylist              normalised n-gram hashes of phrases known to come
                           from a copyleft or proprietary source. The list is
                           stored as HASHES, not text, so detecting a phrase
                           does not require keeping a copy of it - and its size
                           is printed on every run, because an empty denylist
                           that passes silently is decoration.
  3. NOTICE completeness   every identifier-family OWNER the corpus cites has a
                           section in NOTICE.md. Adding a family without an
                           attribution is how a licence obligation goes missing.
  4. allowlist integrity   every source in docs/sources-allowlist.json carries
                           id, name, url, license and reuse, and no id repeats.

WHAT IT CANNOT DO: prove the absence of plagiarism. It catches the obvious
failure mode - pasting a control description or a checklist - and says so.

EXIT: 0 measured fine · 1 measured, findings listed · 2 could not measure
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

FAMILIES = "scripts/meter/standards-families.json"
ALLOWLIST = "docs/sources-allowlist.json"
DENYLIST = "scripts/gates/data/verbatim-denylist.json"
NOTICE = "NOTICE.md"
SCANNED = ("skills", "docs")
MAX_QUOTED_WORDS = 15
NGRAM = 8

# Quoting a licence term in order to record a licence determination is the one
# case where the words themselves are the evidence. It is exempt only inside an
# explicit region, and the count is printed like every other exemption here.
EXEMPT = re.compile(r"<!--\s*licence:quoted-terms\s*-->.*?<!--\s*/licence:quoted-terms\s*-->", re.S)
QUOTED = re.compile(r'"([^"\n]{40,})"|“([^”\n]{40,})”')
# Names that make a nearby quotation an attributed one. Owners come from the
# families file; the rest are the vendors and bodies the coverage documents cite.
EXTRA_OWNERS = ["Datadog", "Verizon", "Google", "Microsoft", "Snyk", "GitHub",
                "AWS", "Amazon", "Azure", "CompTIA", "OffSec", "SANS", "Cloud Security Alliance"]


class Unmeasured(Exception):
    pass


def read(root: Path, rel: str) -> str:
    try:
        return (root / rel).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise Unmeasured(f"cannot read {rel}: {exc}") from exc


def normalise(text: str) -> list[str]:
    return re.sub(r"[^a-z0-9 ]+", " ", text.lower()).split()


def ngram_hashes(words: list[str], n: int) -> set[str]:
    return {hashlib.sha256(" ".join(words[i:i + n]).encode()).hexdigest()[:16]
            for i in range(0, max(0, len(words) - n + 1))}


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    findings: list[str] = []
    checks = 0

    try:
        families = json.loads(read(root, FAMILIES))["families"]
        allowlist = json.loads(read(root, ALLOWLIST))
    except (ValueError, KeyError) as exc:
        raise Unmeasured(f"a data file this gate depends on is unusable: {exc}") from exc

    owners = sorted({f["owner"] for f in families})
    notice = read(root, NOTICE)

    # ---- 3. NOTICE completeness ---------------------------------------
    for owner in owners:
        checks += 1
        if owner not in notice:
            findings.append(
                f"{NOTICE}: the corpus cites identifiers owned by {owner} and NOTICE.md does not "
                "name it; an attribution obligation that is not written down is not discharged")

    # ---- 4. allowlist integrity ---------------------------------------
    seen: set[str] = set()
    for src in allowlist.get("sources", []):
        checks += 1
        missing = [k for k in ("id", "name", "url", "license", "reuse") if not src.get(k)]
        if missing:
            findings.append(
                f"{ALLOWLIST}: source {src.get('id', '<no id>')!r} is missing {missing}; a source "
                "whose licence is not recorded cannot be reused safely by anyone")
        sid = src.get("id")
        if sid in seen:
            findings.append(f"{ALLOWLIST}: duplicate source id {sid!r}")
        seen.add(sid)

    # ---- 2. denylist ---------------------------------------------------
    try:
        deny = json.loads(read(root, DENYLIST))
        deny_hashes = {d["hash"]: d for d in deny.get("phrases", [])}
    except Unmeasured:
        raise
    except (ValueError, KeyError) as exc:
        raise Unmeasured(f"{DENYLIST} is unusable: {exc}") from exc

    # ---- 1. attributed verbatim, and the denylist sweep ----------------
    names = owners + EXTRA_OWNERS
    exempt_regions = 0
    files = 0
    for top in SCANNED:
        base = root / top
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*.md")):
            files += 1
            text = read(root, str(path.relative_to(root)))
            exempt_regions += len(EXEMPT.findall(text))
            text = EXEMPT.sub("", text)
            lines = text.splitlines()

            if deny_hashes:
                present = ngram_hashes(normalise(text), NGRAM)
                for h in present & set(deny_hashes):
                    checks += 1
                    d = deny_hashes[h]
                    findings.append(
                        f"{path.relative_to(root)}: contains a phrase on the verbatim denylist "
                        f"(source: {d.get('source', 'unrecorded')}); it may not be redistributed "
                        "under MIT")

            for i, line in enumerate(lines, 1):
                near = " ".join(lines[max(0, i - 3):i])
                if not any(n in near for n in names):
                    continue
                for m in QUOTED.finditer(line):
                    span = m.group(1) or m.group(2)
                    if "`" in span:
                        continue          # a command or a regex, not prose
                    words = span.split()
                    if len(words) <= MAX_QUOTED_WORDS:
                        continue
                    checks += 1
                    findings.append(
                        f"{path.relative_to(root)}:{i}: a {len(words)}-word quotation next to the "
                        f"name of an external source: {span[:60]!r}... Cite the identifier and "
                        "write the description in our own words, or mark the region "
                        "`licence:quoted-terms` if the wording itself is the evidence")

    print(f"measured: {files} markdown file(s), {len(owners)} identifier owner(s), "
          f"{len(allowlist.get('sources', []))} allowlisted source(s), {checks} checks")
    print(f"denylist: {len(deny_hashes)} phrase hash(es) - stored as {NGRAM}-gram SHA-256 prefixes, "
          "so the list can be checked without keeping a copy of the text it forbids")
    if exempt_regions:
        print(f"exempted: {exempt_regions} region(s) marked licence:quoted-terms, where the wording "
              "of a licence is the evidence for a licence determination")
    print("NOT MEASURED: whether prose that is not quoted was nonetheless derived from a source. "
          "This gate catches pasting, not paraphrase, and a green here is not a plagiarism clearance.")

    for f in findings:
        print(f"FINDING {f}")
    return 1 if findings else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Unmeasured as exc:
        print(f"UNMEASURED {exc}")
        sys.exit(2)
