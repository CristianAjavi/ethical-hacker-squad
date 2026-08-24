#!/usr/bin/env python3
"""Turn a phrase into denylist entries without ever writing the phrase down.

    python3 scripts/licence/add-verbatim-phrase.py --source "OWASP ASVS 5.0" <<'EOF'
    ...the phrase, pasted on stdin...
    EOF

Prints the JSON objects to paste into scripts/gates/data/verbatim-denylist.json.
The phrase is normalised, cut into 8-word windows and hashed; nothing but the
hashes leaves this script, so the denylist never becomes a copy of the text it
exists to forbid.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys

NGRAM = 8


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True, help="where the phrase comes from, for the record")
    args = ap.parse_args()
    words = re.sub(r"[^a-z0-9 ]+", " ", sys.stdin.read().lower()).split()
    if len(words) < NGRAM:
        print(f"a phrase shorter than {NGRAM} words is not distinctive enough to denylist",
              file=sys.stderr)
        return 2
    out = []
    for i in range(0, len(words) - NGRAM + 1):
        h = hashlib.sha256(" ".join(words[i:i + NGRAM]).encode()).hexdigest()[:16]
        out.append({"hash": h, "source": args.source})
    print(json.dumps(out, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
