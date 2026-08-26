#!/usr/bin/env python3
"""What does the permission resolve to when the caller says nothing?

WHY IT ASKS THAT
    Measured on 2026-08-26: of the six composition defects this corpus never
    found in any run, **four were in one service** and all four were the same
    family - a value that decides a permission arriving through a default
    parameter, a lookup table, or an opt-in flag, where the call site shows none
    of it:

      prefix = ''            widens arn:...:bucket/${prefix}* to the whole bucket
      publicRead = false     an opt-in that relaxes BLOCK_ALL when passed true
      pickEnv(name)          returns `dev` for any unknown or missing name
      tierTable[env.tier]    maps one tier to an administrator policy

    Every declaration is defensible and every call site is a single tidy line.
    The defect is in neither: it is in what the omitted argument becomes.

WHAT IT DOES
    Finds parameters that carry a default in a declaration whose body builds a
    permission-shaped string, then finds the calls that OMIT that parameter, and
    prints what the caller silently accepted.

    Permission-shaped means the declaration mentions one of: arn, policy, role,
    grant, permission, public, block, allow, principal, action, effect, bucket,
    scope. Nothing else is looked at, because a default that decides a retry
    count is not this tool's business.

WHAT IT IS NOT
    Not a detector. A default may be the right default, and an omitted argument
    may be exactly what the caller meant. It reads TypeScript and JavaScript by
    pattern, not by parser, so a declaration split across lines or a call built
    dynamically is invisible to it - `cleared` here means only *not matched*.

Exit codes: 0 = measured, nothing omitted | 1 = measured, omissions |
            2 = could not measure.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SECURITY = re.compile(
    r"\b(arn|policy|policies|role|grant|permission|public|block|allow|deny|"
    r"principal|action|effect|bucket|scope|managed|admin)\b", re.I)

# The parameter list is read by BALANCING PARENTHESES, not by a regex over one
# line. TypeScript wraps parameter lists as a matter of style, and the first real
# target this tool was pointed at declared its widening default on its own line:
#
#     export function grantArtifacts(
#       role: iam.IRole,
#       bucket: s3.IBucket,
#       prefix = '',
#     ): void {
#
# A single-line pattern found one declaration in eight files and zero omissions.
# This tool's own header had already named "a declaration split across lines" as
# a blind spot, which did not help: documenting a limitation is not fixing it.
NAME_OPEN = re.compile(r"\b([A-Za-z_$][\w$]*)\s*\(")
PARAM_DEFAULT = re.compile(r"([A-Za-z_$][\w$]*)\s*(?::[^=,]+)?=\s*([^,]+)")
NOT_A_CALL = {"if", "for", "while", "switch", "catch", "return", "function",
              "typeof", "await", "new", "super", "constructor", "require"}
SKIP_DIRS = {".git", "node_modules", "dist", "build", "__pycache__", ".venv"}
EXTS = {".ts", ".tsx", ".js", ".jsx", ".mjs"}


def balanced(text: str, open_at: int):
    """Text between the paren at open_at and its match, and the index after it."""
    depth, i = 0, open_at
    while i < len(text):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return text[open_at + 1:i], i + 1
        i += 1
    return None, len(text)


def split_params(raw: str):
    """Split on commas that are not inside brackets."""
    out, depth, cur = [], 0, ""
    for ch in raw:
        if ch in "([{<":
            depth += 1
        elif ch in ")]}>":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur); cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur)
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--target", type=Path, required=True)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    if not a.target.exists():
        print(f"UNMEASURABLE the target does not exist: {a.target}")
        return 2

    files = [p for p in sorted(a.target.rglob("*"))
             if p.is_file() and p.suffix in EXTS
             and not any(d in p.parts for d in SKIP_DIRS)]
    if not files:
        print(f"UNMEASURABLE no TypeScript or JavaScript under {a.target}")
        return 2

    texts = {p: p.read_text(errors="ignore") for p in files}
    decls = {}
    for p, text in texts.items():
        for m in NAME_OPEN.finditer(text):
            name = m.group(1)
            if name in NOT_A_CALL:
                continue
            raw, after = balanced(text, m.end() - 1)
            if raw is None:
                continue
            # a declaration, not a call: a body or a return type leading to one
            if not re.match(r"\s*(?::[^\n{]*)?(?:=>|\{)", text[after:after + 60]):
                continue
            defaults = [(d.group(1), d.group(2).strip())
                        for part in split_params(raw)
                        if (d := PARAM_DEFAULT.search(part.strip()))]
            if not defaults:
                continue
            if not SECURITY.search(text[after:after + 900]):
                continue
            decls[name] = (str(p.relative_to(a.target)),
                           text[:m.start()].count("\n") + 1,
                           defaults, len(split_params(raw)))

    omissions = []
    for name, (df, dl, defaults, n_params) in sorted(decls.items()):
        call = re.compile(r"\b" + re.escape(name) + r"\s*\(")
        n_required = n_params - len(defaults)
        for p, text in texts.items():
            rel = str(p.relative_to(a.target))
            for m in call.finditer(text):
                i = text[:m.start()].count("\n") + 1
                if rel == df and i == dl:
                    continue
                raw, _ = balanced(text, m.end() - 1)
                if raw is None:
                    continue
                given = len([x for x in split_params(raw) if x.strip()])
                if given >= n_params or given < n_required:
                    continue
                taken = defaults[given - n_required:]
                omissions.append({
                    "call": f"{rel}:{i}", "callee": name, "declared": f"{df}:{dl}",
                    "given": given, "expects": n_params,
                    "defaults_taken": [f"{k}={v}" for k, v in taken],
                })

    if a.json:
        print(json.dumps({"files": len(files), "declarations": len(decls),
                          "omissions": omissions}, indent=2))
    else:
        for o in omissions:
            print(f"  OMITTED      {o['call']} calls {o['callee']}() with {o['given']} of "
                  f"{o['expects']} args, silently taking {', '.join(o['defaults_taken'])}"
                  f"   [declared {o['declared']}]")
        print(f"  {len(decls)} permission-shaped declaration(s) with defaults in {len(files)} "
              f"file(s); {len(omissions)} call(s) omit an argument")
    return 1 if omissions else 0


if __name__ == "__main__":
    sys.exit(main())
