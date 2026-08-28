#!/usr/bin/env python3
"""Which Next.js route handlers does the middleware never see?

WHY THIS EXISTS
    In `bench/runs/2026-08-27-artifact-contract/`, both arms - this project and
    `google/mantis` - audited the same corpus four times each, found 32 of the 33
    planted defects, and BOTH missed the same one in all eight runs: `S-26`, a
    `config.matcher` whose negative lookahead excluded `api`, so a session gate in
    `middleware.ts` never ran on the route handlers, and one of them read any note
    by id with no session.

    Nothing about it is subtle to a machine and everything about it is subtle to a
    reader: the middleware is correct, the gate is real, and a reader who opens a
    route handler that DOES check its own session concludes the API is guarded.
    The defect lives in the distance between two files.

WHAT IT REPORTS
    For every route handler, whether any matcher pattern can reach it, and - for
    those it cannot - whether that file authenticates for itself. A handler the
    middleware never sees AND that does not check for itself is the S-26 shape.

WHAT IT CANNOT SEE
    * Auth performed by a helper this file does not name. A handler calling an
      imported wrapper under another name reads as unguarded here.
    * The full path-to-regexp grammar. Patterns it cannot interpret are reported
      as UNPARSED and counted, never silently treated as covering everything -
      a pattern nobody understood is not a pattern that protects.
    * Whether the middleware's own logic is correct. It only asks who reaches it.

Exit: 0 nothing unguarded | 1 something is | 2 could not measure.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

MIDDLEWARE = ("middleware.ts", "middleware.js", "middleware.mts", "middleware.mjs")
HANDLER = re.compile(r"^(route|page)\.(ts|tsx|js|jsx|mts|mjs)$")
CONFIG_START = re.compile(r"export\s+const\s+config\s*=\s*\{")
# Greedy to the LAST `]`, not the first: a pattern like "/[a-z]{2}/:path*" carries
# a `]` inside the string, and a non-greedy match truncated the array there and
# reported "the matcher is empty" - failing safe, with the wrong reason.
MATCHER = re.compile(r"matcher\s*:\s*(\[[\s\S]*\]|['\"][^'\"]*['\"])", re.S)
STRINGS = re.compile(r"['\"]([^'\"]+)['\"]")
LOOKAHEAD = re.compile(r"\(\?!([^)]*)\)")
# Deliberately a list of spellings, not a pattern that guesses: a name is
# credited only when the file says it. `log_escaper.py` learned this the hard
# way - a clever exception cleared two sites of a published advisory.
AUTH_MARKERS = (
    "getServerSession", "requireSession", "requireUser", "requireAuth",
    "getSession", "auth()", "verifyToken", "getToken", "currentUser",
    "assertAuthenticated", "withAuth",
)


def config_block(text: str) -> str | None:
    """The body of `export const config = { ... }`, by counting braces.

    A non-greedy `\\{(.*?)\\}` stopped at the `}` inside a matcher like
    "/[a-z]{2}/:path*" and handed back ` matcher: ["/[a-z]{2` - which then read
    as an empty matcher and reported COULD NOT MEASURE for the wrong reason.
    Counting is exact where a regex was guessing.
    """
    m = CONFIG_START.search(text)
    if not m:
        return None
    depth = 1
    i = m.end()
    while i < len(text) and depth:
        c = text[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        i += 1
    return text[m.end():i - 1] if depth == 0 else None


def url_path(rel: Path) -> str:
    """app/api/share/route.ts -> /api/share ; pages/api/x.ts -> /api/x"""
    parts = list(rel.parts)
    if parts and parts[0] in ("app", "src"):
        parts = parts[1:]
        if parts and parts[0] == "app":
            parts = parts[1:]
    if parts and HANDLER.match(parts[-1]):
        parts = parts[:-1]
    elif parts:
        parts[-1] = re.sub(r"\.[^.]+$", "", parts[-1])
    # Route groups (folder) and parallel routes @slot do not appear in the URL.
    parts = [p for p in parts if not (p.startswith("(") and p.endswith(")")) and not p.startswith("@")]
    return "/" + "/".join(parts) if parts else "/"


def covers(pattern: str, path: str) -> str:
    """'yes' | 'no' | 'unparsed' - never guess 'yes'."""
    excluded = set()
    for group in LOOKAHEAD.findall(pattern):
        for name in re.split(r"\|", group):
            name = name.strip().strip("^$").split("/")[0]
            if name and re.fullmatch(r"[A-Za-z0-9._-]+", name):
                excluded.add(name)
    first = path.strip("/").split("/")[0] if path.strip("/") else ""
    if first and first in excluded:
        return "no"
    body = LOOKAHEAD.sub("", pattern)
    # `/((?!_next/static|_next/image|favicon.ico).*)` is the matcher almost every
    # Next.js app ships. Reading it as UNPARSED made the first version of this
    # tool return "could not measure" on the common case, which is worthless.
    # So the wrappers are normalised away and only genuinely unread grammar -
    # alternation outside a lookahead, repetition, character classes - is
    # reported as unparsed.
    body = body.replace("(", "").replace(")", "")
    body = re.sub(r"/:[A-Za-z0-9_]+\*?", "/*", body)
    if re.search(r"[{}+?^$\\\[\]|]", body):
        return "unparsed"
    literal = body.split("*")[0].split(".")[0].rstrip("/")
    if not literal:
        return "yes"
    return "yes" if path == literal or path.startswith(literal + "/") else "no"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--target", required=True)
    args = ap.parse_args(argv)
    root = Path(args.target)
    if not root.is_dir():
        print(f"COULD NOT MEASURE  {root} is not a directory")
        return 2

    mids = [p for p in root.rglob("*") if p.is_file() and p.name in MIDDLEWARE]
    if not mids:
        print("COULD NOT MEASURE  no middleware file: this check has nothing to say here")
        return 2
    patterns: list[str] = []
    for m in mids:
        block = config_block(m.read_text(encoding="utf-8", errors="ignore"))
        if block is None:
            print(f"COULD NOT MEASURE  {m.name} exports no `config`, so what reaches it is unknown")
            return 2
        raw = MATCHER.search(block)
        if not raw:
            print(f"COULD NOT MEASURE  {m.name} declares `config` with no `matcher`")
            return 2
        patterns += STRINGS.findall(raw.group(1))
    if not patterns:
        print("COULD NOT MEASURE  the matcher is empty")
        return 2

    handlers = sorted(
        p for p in root.rglob("*")
        if p.is_file() and HANDLER.match(p.name) and p.name.startswith("route")
    )
    if not handlers:
        print("COULD NOT MEASURE  no route handlers under the target")
        return 2

    unguarded = unparsed = 0
    for h in handlers:
        path = url_path(h.relative_to(root))
        verdicts = [covers(p, path) for p in patterns]
        text = h.read_text(encoding="utf-8", errors="ignore")
        seen = [m for m in AUTH_MARKERS if m in text]
        rel = h.relative_to(root)
        if "unparsed" in verdicts and "yes" not in verdicts:
            unparsed += 1
            print(f"UNPARSED   {rel}  {path}  - the matcher could not be read; not counted as covered")
        elif "yes" in verdicts:
            print(f"reached    {rel}  {path}")
        elif seen:
            print(f"self-check {rel}  {path}  - middleware never runs here; file checks: {', '.join(seen)}")
        else:
            unguarded += 1
            print(f"UNGUARDED  {rel}  {path}  - middleware never runs here and the file checks nothing")

    print(f"\nmatcher patterns: {len(patterns)} | route handlers: {len(handlers)} | "
          f"unguarded: {unguarded} | unparsed: {unparsed}")
    if unparsed and not unguarded:
        return 2
    return 1 if unguarded else 0


if __name__ == "__main__":
    sys.exit(main())
