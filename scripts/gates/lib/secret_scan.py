#!/usr/bin/env python3
"""Measurement core of gate-secret-scan.sh — G6.

Distinctive formats first, entropy never. `references/tooling.md` records the
measurement this rests on: format-specific patterns reach far higher precision
than entropy, which is why nothing here scores a string by how random it looks.

Two scopes, and the second is what makes the first honest:

  1. The working tree, minus `bench/cases/`, which ships planted secrets on
     purpose - that is what an evaluation bench is.
  2. `bench/cases/` itself, against the answer key: a secret-shaped string there
     must be a defect the key declares. A planted secret nobody planted is a
     real secret hiding behind the exclusion.

EXIT: 0 measured, nothing found · 1 measured, findings listed · 2 could not measure
"""

from __future__ import annotations

import binascii
import json
import re
import sys
from pathlib import Path

BENCH_CASES = "bench/cases"
KEY = "bench/ground-truth.json"
SKIP_DIRS = {".git", "__pycache__", "node_modules", ".venv"}
MAX_BYTES = 2_000_000

# Every pattern here is a published, distinctive format. A hit is a candidate;
# the GitHub family is the one that can be settled offline, by its checksum.
PATTERNS = {
    "github-token": re.compile(r"\bgh[pousr]_[A-Za-z0-9]{36}\b"),
    "aws-access-key-id": re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    "anthropic-key": re.compile(r"\bsk-ant-[A-Za-z0-9_-]{24,}"),
    "openai-key": re.compile(r"\bsk-[A-Za-z0-9]{32,}\b"),
    "slack-token": re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}"),
    "google-api-key": re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b"),
    "npm-token": re.compile(r"\bnpm_[A-Za-z0-9]{36}\b"),
    "stripe-live-key": re.compile(r"\bsk_live_[A-Za-z0-9]{16,}\b"),
    "private-key-block": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |PGP )?PRIVATE KEY-----"),
    # Vendor live-mode tokens follow a family convention rather than one format:
    # a short vendor prefix, `_live_`, and a long body. Lower precision than the
    # published formats above, which is why it sits last and why `sk_test_` and
    # the other inert markers are excluded before anything is reported.
    "vendor-live-token": re.compile(r"\b[a-z][a-z0-9]{2,11}_live_[A-Za-z0-9]{24,}\b"),
}
# Strings that carry a real format and are inert by construction.
BENIGN = re.compile(r"sk_test_|changeme|CHANGEME|replace-me|example|EXAMPLE|xxxxx|0{16,}", re.I)


def github_checksum_valid(token: str) -> bool:
    """GitHub tokens carry a CRC32 of the body in their last six characters,
    base62-encoded. A valid checksum makes a hit a fact rather than a guess."""
    alphabet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    prefix, _, rest = token.partition("_")
    if len(rest) < 7:
        return False
    body, checksum = rest[:-6], rest[-6:]
    value = 0
    for ch in checksum:
        if ch not in alphabet:
            return False
        value = value * 62 + alphabet.index(ch)
    return value == binascii.crc32(f"{prefix}_{body}".encode())


def scan(path: Path) -> list[tuple[str, int, str, str]]:
    try:
        if path.stat().st_size > MAX_BYTES:
            return []
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return []
    out = []
    for i, line in enumerate(text.splitlines(), 1):
        for name, pattern in PATTERNS.items():
            m = pattern.search(line)
            if not m:
                continue
            hit = m.group(0)
            if BENIGN.search(line):
                continue
            note = ""
            if name == "github-token":
                note = " (checksum valid)" if github_checksum_valid(hit) else " (checksum invalid: likely a fixture)"
            out.append((name, i, hit[:6] + "[REDACTED]", note))
    return out


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    if not root.is_dir():
        print(f"UNMEASURED {root} is not a directory")
        return 2

    findings: list[str] = []
    scanned = 0
    bench_root = root / BENCH_CASES

    for path in sorted(root.rglob("*")):
        if not path.is_file() or any(part in SKIP_DIRS for part in path.parts):
            continue
        in_bench = bench_root in path.parents
        scanned += 1
        for name, line, redacted, note in scan(path):
            rel = path.relative_to(root)
            if in_bench:
                continue  # handled against the key below
            findings.append(f"{rel}:{line} carries a {name}{note}: {redacted}")

    # The bench exclusion, made honest: every secret-shaped string under
    # bench/cases must be a defect the answer key declares.
    if bench_root.is_dir():
        try:
            key = json.loads((root / KEY).read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            print(f"UNMEASURED bench/cases exists and its key is unreadable ({exc}): "
                  "the exclusion cannot be checked")
            return 2
        declared = {
            (item["case"], item["path"])
            for item in key.get("planted", []) + key.get("decoys", [])
        }
        cases = {c["case"]: Path(c["path"]) for c in key.get("cases", [])}
        for path in sorted(bench_root.rglob("*")):
            if not path.is_file():
                continue
            hits = scan(path)
            if not hits:
                continue
            rel = path.relative_to(root)
            owner = next(((name, rel.relative_to(base)) for name, base in cases.items()
                          if base in rel.parents or str(rel).startswith(str(base))), None)
            if owner is None or (owner[0], str(owner[1])) not in declared:
                for name, line, redacted, note in hits:
                    findings.append(
                        f"{rel}:{line} carries a {name}{note}: {redacted} - it is under "
                        "bench/cases and the answer key declares no defect there, so the "
                        "exclusion would be hiding a real secret")

    print(f"measured: {scanned} file(s) outside bench/cases, {len(PATTERNS)} formats, "
          "distinctive patterns only (never entropy)")
    print("NOT SCANNED: git history. Run with EHS_SCAN_HISTORY=1 for the history pass, "
          "which this core does not do: a rewritten history needs its own tool and its own "
          "authorization conversation.")
    for f in findings:
        print(f"FINDING {f}")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
