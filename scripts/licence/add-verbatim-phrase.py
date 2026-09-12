#!/usr/bin/env python3
"""Turn a phrase into denylist entries without ever writing the phrase down.

    python3 scripts/licence/add-verbatim-phrase.py --source "OWASP ASVS 5.0" <<'EOF'
    ...the phrase, pasted on stdin...
    EOF

Prints the JSON objects to paste into scripts/gates/data/verbatim-denylist.json.
The phrase is normalised, cut into windows and hashed; nothing but the hashes
leaves this script, so the denylist never becomes a copy of the text it exists
to forbid.

THE WINDOW SIZE IS NOT WRITTEN HERE. It is read from the denylist's own `ngram`
key, because this script and scripts/gates/lib/licence_hygiene.py have to agree
on it exactly: a hash built over a window of one size is invisible to a sweep
that looks for windows of another, and the symptom of disagreeing is a denylist
that keeps passing and forbids nothing. The number lived in three places - here,
in the sweep, and in the file both of them read - and nothing compared them.
gate-licence-hygiene.sh now measures this script's window by running it.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

DENYLIST = Path(__file__).resolve().parents[2] / "scripts/gates/data/verbatim-denylist.json"


def window_size(denylist: Path) -> int:
    """The n of the n-gram, from the list that will hold the hashes.

    Raises ValueError rather than defaulting: a default would silently rebuild
    the second source of truth this function exists to remove.
    """
    try:
        declared = json.loads(denylist.read_text(encoding="utf-8"))["ngram"]
    except (OSError, ValueError, KeyError) as exc:
        raise ValueError(f"cannot read `ngram` from {denylist}: {exc}") from exc
    if not isinstance(declared, int) or isinstance(declared, bool) or declared < 1:
        raise ValueError(f"`ngram` in {denylist} is {declared!r}, not a positive whole number")
    return declared


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True, help="where the phrase comes from, for the record")
    ap.add_argument("--denylist", default=DENYLIST, type=Path,
                    help="the list whose `ngram` sets the window (default: %(default)s)")
    args = ap.parse_args()
    try:
        ngram = window_size(args.denylist)
    except ValueError as exc:
        print(f"{exc}: refusing to guess a window size, because a guess that differs from the "
              f"sweep's produces hashes nothing will ever match", file=sys.stderr)
        return 2
    words = re.sub(r"[^a-z0-9 ]+", " ", sys.stdin.read().lower()).split()
    if len(words) < ngram:
        print(f"a phrase shorter than {ngram} words is not distinctive enough to denylist",
              file=sys.stderr)
        return 2
    out = []
    for i in range(0, len(words) - ngram + 1):
        h = hashlib.sha256(" ".join(words[i:i + ngram]).encode()).hexdigest()[:16]
        out.append({"hash": h, "source": args.source})
    print(json.dumps(out, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
