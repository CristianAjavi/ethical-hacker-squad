#!/usr/bin/env python3
"""Does an escaper sit between the value and the log sink?

WHY IT ASKS THAT AND NOT SOMETHING EASIER
    In a blinded round on 2026-08-25, six independent auditors read
    `bench/cases/intake-portal/app/audit.py` and reported the concatenated line
    while naming the deferred `%s` line beside it as *the example of doing it
    right*. Both carry the same defect. The probe proves it: one call, two lines
    in a line-oriented log.

    They were not careless. They recognised an idiom - `%s` placeholders, the
    thing every linter asks for - and recognition stood in for verification.
    Issue #53 asked for "a check a reviewer cannot pass by recognising the
    idiom", so this one does not look at the idiom at all.

WHAT IT LOOKS AT
    For each logging call, whether every argument that could carry a control
    character reaches the sink through something that neutralises one. Not how
    the string was built - concatenation, `%s`, f-string and `.format` are all
    treated identically, because the interpolation style is exactly the thing
    that misled the readers.

    An argument is CLEARED when it is wrapped in a call whose name is in
    `ESCAPERS`, or is a literal, or is a name bound in the same function to a
    cleared expression. Anything else is UNCLEARED and reported.

WHAT IT DOES NOT DO
    Track values across function boundaries, read the handler's formatter, or
    know whether the consumer is line-oriented. It answers one question about
    one call. A cleared result is not a clearance - `json.dumps` escapes a
    newline and a formatter that re-splits on one would undo that - and the
    report says which escaper was credited so a reviewer can disagree with it.

Exit codes: 0 = measured, nothing uncleared | 1 = measured, uncleared arguments |
            2 = could not measure.
"""

from __future__ import annotations

import argparse
import ast
import json
import sys
from pathlib import Path

LOG_METHODS = {"debug", "info", "warning", "warn", "error", "exception", "critical", "log"}

# Names credited with neutralising a control character. Deliberately short, and
# deliberately including only things that ENCODE - not things that merely
# validate, which is why `strip` is absent: stripping whitespace does not remove
# an embedded newline in the middle of a value.
ESCAPERS = {
    "dumps", "json_dumps", "quote", "quote_plus", "urlencode", "escape",
    "unicode_escape", "repr", "sanitize", "sanitise", "sanitized", "sanitised",
    "neutralise", "neutralize", "encode_control", "escape_controls",
}


def is_log_call(node) -> bool:
    if not isinstance(node, ast.Call):
        return False
    f = node.func
    if isinstance(f, ast.Attribute) and f.attr in LOG_METHODS:
        return True
    if (isinstance(f, ast.Call) and isinstance(f.func, ast.Name)
            and f.func.id == "getattr" and f.args):
        base = f.args[0]
        name = getattr(base, "id", "") or getattr(base, "attr", "")
        return "log" in name.lower()
    return False


def cleared(node, bindings: dict[str, bool]) -> tuple[bool, str]:
    """Is this expression neutralised? Returns (cleared, what was credited)."""
    if isinstance(node, ast.Constant):
        return True, "literal"
    if isinstance(node, ast.Call):
        f = node.func
        name = getattr(f, "attr", None) or getattr(f, "id", None) or ""
        if name in ESCAPERS:
            return True, name
        # a call that is not an escaper clears nothing, but its arguments might
        # still all be literals - `str(1)` is fine, `str(x)` is not
        return all(cleared(a, bindings)[0] for a in node.args) and bool(node.args), f"{name}(...)"
    if isinstance(node, ast.Name):
        return bindings.get(node.id, False), f"bound `{node.id}`"
    if isinstance(node, ast.JoinedStr):  # f-string: every interpolation must clear
        parts = [v.value for v in node.values if isinstance(v, ast.FormattedValue)]
        return all(cleared(p, bindings)[0] for p in parts), "f-string"
    if isinstance(node, ast.BinOp):
        return (cleared(node.left, bindings)[0] and cleared(node.right, bindings)[0]), "operands"
    return False, type(node).__name__


def scan_function(fn, rel: str) -> list[dict]:
    """Every logging call in this function, with its uncleared arguments."""
    bindings: dict[str, bool] = {}
    for node in ast.walk(fn):
        if isinstance(node, ast.Assign):
            ok, _ = cleared(node.value, bindings)
            for t in node.targets:
                if isinstance(t, ast.Name):
                    bindings[t.id] = ok

    out = []
    for node in ast.walk(fn):
        if not is_log_call(node):
            continue
        uncleared, credited = [], []
        # every argument is a candidate: the message itself and every value
        for i, arg in enumerate(node.args):
            ok, why = cleared(arg, bindings)
            (credited if ok else uncleared).append(f"arg{i}:{why}")
        for kw in node.keywords:
            if kw.arg in ("exc_info", "stack_info", "stacklevel", "extra"):
                continue
            ok, why = cleared(kw.value, bindings)
            (credited if ok else uncleared).append(f"{kw.arg}:{why}")
        out.append({
            "file": rel, "symbol": fn.name, "line": node.lineno,
            "uncleared": uncleared, "credited": credited,
        })
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--target", type=Path, required=True)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    if not args.target.exists():
        print(f"UNMEASURED the target does not exist: {args.target}")
        return 2

    paths = [args.target] if args.target.is_file() else sorted(args.target.rglob("*.py"))
    if not paths:
        print(f"UNMEASURED no Python file under {args.target}")
        return 2

    rows, parsed = [], 0
    for p in paths:
        try:
            tree = ast.parse(p.read_text(errors="ignore"))
        except (SyntaxError, ValueError):
            continue
        parsed += 1
        rel = str(p) if args.target.is_file() else str(p.relative_to(args.target))
        for fn in ast.walk(tree):
            if isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef)):
                rows.extend(scan_function(fn, rel))

    if not parsed:
        print(f"UNMEASURED nothing under {args.target} parsed as Python")
        return 2

    flagged = [r for r in rows if r["uncleared"]]
    if args.json:
        print(json.dumps({"files_parsed": parsed, "log_calls": len(rows),
                          "uncleared": flagged}, indent=2))
    else:
        for r in flagged:
            print(f"  UNCLEARED {r['file']}:{r['line']} in {r['symbol']} — {', '.join(r['uncleared'])}")
        for r in rows:
            if not r["uncleared"]:
                print(f"  cleared   {r['file']}:{r['line']} in {r['symbol']} — {', '.join(r['credited'])}")
        print(f"  {len(rows)} logging call(s) in {parsed} file(s); {len(flagged)} with an uncleared argument")
    return 1 if flagged else 0


if __name__ == "__main__":
    sys.exit(main())
