#!/usr/bin/env python3
"""Measurement core of gate-tooling-blindspot.sh.

`references/tooling.md` states the rule this file enforces: `rg` honours
`.gitignore` and `.ignore` and skips hidden files, so a search that returns
nothing has searched a filtered view of the tree. `fd` does the same. The
document says to use `rg -uu --hidden` before recording a negative. Nothing was
reading that rule back against the procedures that have to obey it.

  1. premise     references/tooling.md still declares the rule. If the rule is
                 gone there is nothing to enforce, and this gate says COULD NOT
                 MEASURE rather than passing on an empty premise.
  2. blind spot  a procedure that sends the auditor to a path the defaults hide
                 must have at least ONE `rg`/`fd` invocation able to reach it.
                 The unit of judgement is the PROCEDURE, not the single command:
                 a procedure often greps source with the defaults on and then
                 points a second, explicit invocation at the dotted file. That
                 pair is correct, and a per-command rule would accuse it.

WHAT MAKES A PROCEDURE SAFE (any one of these, and the check moves on)
  - one of its invocations carries the complete flag pair for its tool:
      rg: `-uu`/`-uuu`, or `--no-ignore` (or `-u`) together with `--hidden`
      fd: `-u`/`--unrestricted`, or `-I`/`--no-ignore` together with `-H`/`--hidden`
  - one of its invocations names a hidden or ignored path as its own argument.
    Pointing the tool at `.github/workflows/` or `~/.config/<app>` is the
    documented way round the default, and a gate that called that a defect
    would be accusing prose that is already right.
  - it never sends the auditor anywhere the defaults hide, so a filtered view
    is the view it wanted.

WHAT THIS DOES NOT MEASURE
  Whether the pattern is the right pattern, whether the procedure finds the
  defect, or whether `rg` and `fd` behave as documented on any given machine -
  this reads text, it runs neither tool. The hidden-path vocabulary below is a
  NAMED, FINITE list, not "anything with a dot": a third-party tool's own cache
  directory mentioned in passing is not a place the audit has to read, and
  treating every dotted token as one would make this gate accuse correct prose.

EXIT CODES: 0 measured fine - 1 measured, findings listed - 2 could not measure
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

KNOWLEDGE = "skills/ethical-hacker-squad/references/knowledge"
TOOLING_DOC = "skills/ethical-hacker-squad/references/tooling.md"

# The premise. If tooling.md stops saying this, the gate has lost its mandate
# and must report that rather than quietly enforcing a rule nobody declares.
PREMISE = re.compile(r"-uu\s+--hidden|--hidden.*-uu", re.S)

PROC_HEAD = re.compile(r"(?m)^(### ([A-Z]{2,4}-\d+)\b.*)$")
BACKTICKED = re.compile(r"`([^`\n]+)`")
IS_INVOCATION = re.compile(r"^\s*(rg|fd)\s+\S")

# Paths the defaults hide. A NAMED, FINITE list matched as a whole path
# SEGMENT, never as "anything with a dot in it". The lookbehind is what keeps
# `os.environ`, `filepath.Join` and `parent.parent` out: a dotted token glued to
# a word is an attribute, not a directory, and a gate that could not tell the
# difference would accuse most of the corpus.
HIDDEN_PATH = re.compile(
    r"""(?<![\w.\-/])\.(?:git|github|gitlab|circleci|azure|env|venv|claude-plugin|claude|
        cursor|vscode|idea|aws|ssh|kube|docker|dockerignore|
        config|cache|next|nuxt|npmrc|yarnrc|mvn|gradle|terraform|serverless)
        (?![\w\-])
        | (?<![\w.\-/])(?:node_modules|__pycache__)(?![\w\-])
        | (?<![\w.\-])(?:dist|build|vendor|third_party)/""",
    re.X,
)

RG_NO_IGNORE = re.compile(r"--no-ignore(?:-vcs)?\b|--unrestricted\b|(?:^|\s)-u{1,3}(?=\s|$)")
RG_HIDDEN = re.compile(r"--hidden\b|--unrestricted\b|(?:^|\s)-u{2,3}(?=\s|$)")
FD_NO_IGNORE = re.compile(r"--no-ignore(?:-vcs)?\b|--unrestricted\b|(?:^|\s)-(?:I|u{1,3})(?=\s|$)")
FD_HIDDEN = re.compile(r"--hidden\b|--unrestricted\b|(?:^|\s)-(?:H|u{1,3})(?=\s|$)")


QUOTED = re.compile(r"""'[^']*'|"[^"]*\"""")
NEGATED_GLOB = re.compile(r"-g\s*'?!")
EXCLUSION = re.compile(r"""-g\s*(?:'![^']*'|"![^"]*"|![^\s`]*)""")


def path_arguments(cmd: str) -> str:
    """What is left of an invocation once its search PATTERN is removed.

    A hidden path inside the pattern is a string being searched FOR, not a place
    being searched IN: `rg -n "os\\.environ|~/\\.aws" <dir>` reaches nothing
    hidden, and reading `~/\\.aws` there as coverage is how this check would
    have exonerated the worst offender in the corpus. Negated globs go too -
    `-g '!.git'` EXCLUDES a hidden path, it does not visit one.
    """
    stripped = QUOTED.sub(" ", cmd)
    return " " .join(w for w in stripped.split() if not NEGATED_GLOB.match(w))


def reaches_hidden_path(cmd: str) -> bool:
    """The invocation is pointed AT a hidden path, which is the documented way round."""
    if NEGATED_GLOB.search(cmd):
        return False
    return bool(HIDDEN_PATH.search(path_arguments(cmd)))


def complete_pair(cmd: str) -> bool:
    """True when the invocation defeats BOTH defaults: ignore files and hidden files."""
    tool = cmd.split()[0]
    if tool == "rg":
        return bool(RG_NO_IGNORE.search(cmd)) and bool(RG_HIDDEN.search(cmd))
    return bool(FD_NO_IGNORE.search(cmd)) and bool(FD_HIDDEN.search(cmd))


def procedures(text: str):
    """Yield (procedure id, body) for every `### XXX-NN` section in a pack file."""
    parts = PROC_HEAD.split(text)
    # parts = [preamble, head, id, body, head, id, body, ...]
    for i in range(1, len(parts), 3):
        yield parts[i + 1], parts[i + 2]


def invocations(body: str):
    """Every backticked `rg`/`fd` command in a procedure body, with its line number."""
    for lineno, line in enumerate(body.splitlines(), 1):
        for match in BACKTICKED.finditer(line):
            cmd = match.group(1)
            if IS_INVOCATION.match(cmd):
                yield lineno, cmd


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    doc = root / TOOLING_DOC
    kdir = root / KNOWLEDGE

    if not doc.is_file():
        print(f"UNMEASURED the premise is missing: {TOOLING_DOC}")
        return 2
    if not PREMISE.search(doc.read_text(encoding="utf-8")):
        print(f"UNMEASURED {TOOLING_DOC} no longer declares the `-uu --hidden` rule, "
              "so there is no rule to enforce and this is not a pass")
        return 2
    if not kdir.is_dir():
        print(f"UNMEASURED the corpus is missing: {KNOWLEDGE}")
        return 2

    packs = sorted(kdir.glob("*.md"))
    if not packs:
        print(f"UNMEASURED no pack files under {KNOWLEDGE}")
        return 2

    findings: list[str] = []
    scanned = exposed = checked = 0

    for pack in packs:
        text = pack.read_text(encoding="utf-8")
        for pid, body in procedures(text):
            cmds = [c for _, c in invocations(body)]
            if not cmds:
                continue
            scanned += 1
            # An excluded path is not a visited one: `-g '!.git'` must not make
            # the procedure look like it sends the auditor into `.git`.
            hidden = HIDDEN_PATH.search(EXCLUSION.sub(" ", body))
            if not hidden:
                continue
            exposed += 1
            checked += len(cmds)
            if any(complete_pair(c) or reaches_hidden_path(c) for c in cmds):
                continue
            shown = " / ".join(c if len(c) <= 56 else c[:53] + "..." for c in cmds)
            findings.append(
                f"{pack.name} {pid}: sends the auditor to `{hidden.group(0).strip()}`, "
                f"a path rg and fd hide by default, and not one of its {len(cmds)} "
                f"invocation(s) can reach it - neither by carrying the flags nor by "
                f"naming the path: {shown}. tooling.md calls this a false-negative "
                "source that nothing in the output warns you about"
            )

    print(f"measured: {len(packs)} pack files, {scanned} procedures that invoke rg or fd, "
          f"{exposed} of them pointing at a path the defaults hide, {checked} invocations checked")
    for f in findings:
        print(f"FINDING {f}")
    return 1 if findings else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # noqa: BLE001 - an unreadable input is a 2, never a 0
        print(f"UNMEASURED {exc}")
        sys.exit(2)
