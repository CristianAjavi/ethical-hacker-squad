#!/usr/bin/env python3
"""Refuse BSD-only or GNU-only shell spellings under scripts/.

The measurement, not the policy: the catalogue lives in
scripts/gates/data/portable-shell-catalogue.json and this file only applies it.

THE THREE THINGS THAT MAKE THIS HARDER THAN A GREP

0.  "Shell" here means the shell command, not the file it is spelled in.  The
    same `cp -Rc` is one divergence whether it sits in a `.sh` or inside a
    subprocess argv list in a `.py`, and this repository has already been bitten
    by the second: a `cp -Rc` in a Python argv list ran green on macOS for weeks
    and killed the Linux runner at the first push, while this gate read 107
    shell files beside it and reported OK.  So `.sh` is read as text and `.py`
    is read as a syntax tree, and both are matched against ONE catalogue.

1.  A logical line is not a physical line.  The one real `date` fallback in this
    repository is split across two lines by a trailing backslash, with the BSD
    spelling on the first and the GNU spelling on the second.  Read physically,
    each half looks like a lone platform-specific invocation and both get
    flagged.  Read logically, the pair is the correct idiom.  So continuations
    are joined before anything is matched, and the finding carries the line
    number where the logical line STARTED.

2.  The deliberate fallback must not be a finding.  `A 2>/dev/null || B` is how
    portable shell is actually written.  Measured before this gate existed: over
    104 shell files, a catalogue without this exoneration flagged 18 correct
    lines - sixteen mktemp fallbacks and one date pair - and nothing else.  A
    gate whose first red is its own defect gets switched off, so a candidate is
    exonerated when its logical line also carries the counterpart spelling and
    an `||`.

3.  In Python the fallback is a STRUCTURE, not a line.  `A 2>/dev/null || B`
    has no Python spelling: `run(A) or run(B)` reads like it and is not a
    fallback at all, because CompletedProcess is always truthy and B never runs.
    That exact transliteration is what broke the runner, so it is a rule of its
    own.  The real Python fallback tests a returncode or catches an exception,
    and it spans several statements - so the argv arm is exonerated structurally
    (the counterpart call within a three-statement window under a returncode
    test, or in the handler of the try that holds it) and never by an operator.

4.  An exemption has to be WRITTEN.  A line can opt out with a trailing
    `# portable-shell: allow <id> - <reason>`, and an exemption with no reason is
    itself a finding.  Removing a check and saying what replaces it are the same
    edit; a silent opt-out is the half of that edit that never happens.

WHAT THIS DOES NOT DECIDE.  Whether the spelling is REACHABLE.  This is a
lexical check over source text: a BSD-only invocation inside a branch that never
runs on Linux is still reported, because deciding otherwise means interpreting
the shell.  The out_of_scope block of the catalogue names what is not checked at
all - what does not appear in that file passes in silence, and saying so is part
of the check.

Exit codes: 0 = measured and clean | 1 = measured and fails | 2 = could not measure.
"""

from __future__ import annotations

import ast
import json
import pathlib
import re
import sys

SCAN_DIR = "scripts"
SUFFIXES = (".sh", ".bash")
PY_SUFFIXES = (".py",)
MIN_REASON = 10

# The calls whose first argument is an argv list this scanner will read.
SUBPROCESS_FUNCS = ("run", "call", "check_call", "check_output", "Popen")
# What a non-literal argv element renders as. Deliberately not a word: the
# catalogue matches commands and FLAGS, and a flag is written down or the call
# is not decidable from its argv at all.
EXPR = "<expr>"
# How far the structural exoneration looks: the divergent statement and the two
# after it, in the same block. Wider than a logical line because the Python
# fallback needs at least two statements; narrow enough that a counterpart five
# statements away is not mistaken for one.
WINDOW = 3

# `# portable-shell: allow <ids> - <reason>`; the ids are comma-separated.
#
# The id group is GREEDY and excludes the space on purpose. Lazy, it split
# `sed-i-empty` at its own hyphen - the id came out as `sed`, matched no rule,
# and the exemption silently did nothing while reading as if it worked. An
# escape hatch that fails closed is fine; one that fails quietly is not.
EXEMPTION = re.compile(
    r"#\s*portable-shell:\s*allow\s+([A-Za-z0-9_,-]+)(?:\s+[-—:]?\s*(.*))?$"
)


def unmeasurable(reason: str) -> int:
    print("UNMEASURABLE %s" % reason)
    return 2


def logical_lines(text: str):
    """Yield (first_line_number, joined_text) with backslash continuations joined."""
    physical = text.splitlines()
    n = 0
    while n < len(physical):
        start = n + 1
        buf = physical[n]
        while buf.rstrip().endswith("\\") and n + 1 < len(physical):
            buf = buf.rstrip()[:-1] + " " + physical[n + 1]
            n += 1
        yield start, buf
        n += 1


def exemption_on(line: str):
    """(ids, reason) named by a written exemption on this line, or None."""
    m = EXEMPTION.search(line)
    if not m:
        return None
    ids = [i.strip() for i in m.group(1).split(",") if i.strip()]
    return ids, (m.group(2) or "").strip()


def _is_subprocess_call(node) -> bool:
    return (isinstance(node, ast.Call)
            and isinstance(node.func, ast.Attribute)
            and node.func.attr in SUBPROCESS_FUNCS
            and isinstance(node.func.value, ast.Name)
            and node.func.value.id == "subprocess")


def argv_text(call):
    """The command line a subprocess argv literal spells, or None.

    None means this scanner cannot name the command being run - the first
    element is not a literal string, or there is no argv list at all. Those are
    COUNTED and the count is printed, because a divergence the instrument never
    looked at is not an absence of divergence.

    An empty string element renders as `''` so that `["sed", "-i", "", ...]`
    reaches the catalogue as the `sed -i ''` it actually is.
    """
    if not call.args:
        return None
    first = call.args[0]
    if not isinstance(first, ast.List) or not first.elts:
        return None
    head = first.elts[0]
    if not (isinstance(head, ast.Constant) and isinstance(head.value, str)):
        return None
    out = []
    for el in first.elts:
        if isinstance(el, ast.Constant) and isinstance(el.value, str):
            out.append(el.value if el.value != "" else "''")
        else:
            out.append(EXPR)
    return " ".join(out)


def _index(tree):
    """(statement of each call, block+index of each statement, try of each call).

    The three things the structural exoneration needs, walked once.
    """
    stmt_of, block_of, try_of = {}, {}, {}
    for node in ast.walk(tree):
        for field in ("body", "orelse", "finalbody"):
            seq = getattr(node, field, None)
            if isinstance(seq, list):
                for i, st in enumerate(seq):
                    if isinstance(st, ast.stmt):
                        block_of[id(st)] = (seq, i)

    def walk(node, stmt, tri):
        if isinstance(node, ast.stmt):
            stmt = node
        if isinstance(node, ast.Call):
            stmt_of[id(node)] = stmt
            if tri is not None:
                try_of[id(node)] = tri
        if isinstance(node, ast.Try):
            for child in node.body:
                walk(child, stmt, node)
            for field in ("handlers", "orelse", "finalbody"):
                for child in getattr(node, field):
                    walk(child, stmt, tri)
            return
        for child in ast.iter_child_nodes(node):
            walk(child, stmt, tri)

    walk(tree, None, None)
    return stmt_of, block_of, try_of


def _counterpart_near(nodes, pattern, exclude) -> bool:
    for n in nodes:
        if n is exclude or not _is_subprocess_call(n):
            continue
        text = argv_text(n)
        if text is not None and pattern.search(text):
            return True
    return False


def _has_fallback(call, counterpart, stmt_of, block_of, try_of) -> bool:
    """Is this divergent call the tried half of a real Python fallback?

    Two shapes, and both are in this repository already:
      r = run([cp -Rc ...]); if r.returncode != 0: run([cp -R ...])
      if run([cp -Rc ...]).returncode != 0: run([cp -R ...])
    plus the third that subprocess makes available:
      try: run([...], check=True) except CalledProcessError: run([...])
    """
    if counterpart is None:
        return False
    st = stmt_of.get(id(call))
    loc = block_of.get(id(st)) if st is not None else None
    if loc is not None:
        block, i = loc
        nodes = [n for s in block[i:i + WINDOW] for n in ast.walk(s)]
        guarded = any(
            (isinstance(n, ast.Attribute) and n.attr == "returncode")
            or isinstance(n, ast.Try)
            for n in nodes
        )
        if guarded and _counterpart_near(nodes, counterpart, call):
            return True
    tri = try_of.get(id(call))
    if tri is not None:
        nodes = [n for h in tri.handlers for n in ast.walk(h)]
        nodes += [n for s in tri.orelse for n in ast.walk(s)]
        if _counterpart_near(nodes, counterpart, call):
            return True
    return False


def scan_python(path, rel, text, rules, boolop_rule, findings, honoured):
    """Read one .py against the catalogue. Returns how many argv it could not name."""
    try:
        tree = ast.parse(text, filename=str(path))
    except SyntaxError as exc:
        raise LookupError("cannot parse %s: %s" % (rel, exc))
    physical = text.splitlines()
    stmt_of, block_of, try_of = _index(tree)

    def written_allow(node):
        """The exemption on any physical line this node occupies."""
        lo = getattr(node, "lineno", 0)
        hi = getattr(node, "end_lineno", None) or lo
        for ln in range(lo, hi + 1):
            if 1 <= ln <= len(physical):
                got = exemption_on(physical[ln - 1])
                if got:
                    return got
        return None

    def record(node, rid, why, portable, extra=""):
        allow = written_allow(node)
        if allow and rid in allow[0]:
            if len(allow[1]) < MIN_REASON:
                findings.append(
                    "%s:%d  %s is exempted with no reason written down. "
                    "An exemption is half an edit until it says why."
                    % (rel, node.lineno, rid))
            else:
                honoured.append("%s:%d  %s - %s" % (rel, node.lineno, rid, allow[1]))
            return
        findings.append("%s:%d  %s\n         %s\n         portable: %s%s"
                        % (rel, node.lineno, rid, why, portable, extra))

    undecided = 0
    for node in ast.walk(tree):
        # (a) the transliterated `||`, which is not a fallback in Python
        if boolop_rule and isinstance(node, ast.BoolOp):
            calls = [v for v in node.values if _is_subprocess_call(v)]
            if len(calls) >= 2:
                op = "or" if isinstance(node.op, ast.Or) else "and"
                record(node, boolop_rule[0], boolop_rule[1], boolop_rule[2],
                       "\n         spelled here as: run(...) %s run(...)" % op)
            continue
        if not _is_subprocess_call(node):
            continue
        text_argv = argv_text(node)
        if text_argv is None:
            undecided += 1
            continue
        for rid, why, portable, pattern, counterpart in rules:
            if not pattern.search(text_argv):
                continue
            if _has_fallback(node, counterpart, stmt_of, block_of, try_of):
                continue
            record(node, rid, why, portable,
                   "\n         the argv reads: %s" % text_argv)
    return undecided


def scan(root: pathlib.Path, catalogue: dict) -> tuple[list[str], list[str], int]:
    """Return (findings, honoured_exemptions, stats)."""
    rules = []
    boolop_rule = None
    for raw in catalogue["rules"]:
        portable = raw.get("portable") or "no portable spelling recorded"
        # A structural rule has no pattern to match: what it refuses is a SHAPE,
        # and a shape is not lexically decidable. It still lives in the
        # catalogue, because what a gate enforces has to be readable by someone
        # who is not reading its code.
        if raw.get("structural") == "python-subprocess-boolop":
            boolop_rule = (raw["id"], raw["why"], portable)
            continue
        rules.append(
            (
                raw["id"],
                raw["why"],
                portable,
                re.compile(raw["pattern"]),
                re.compile(raw["counterpart"]) if raw.get("counterpart") else None,
            )
        )

    def under(suffixes):
        return sorted(
            q
            for q in (root / SCAN_DIR).rglob("*")
            if q.is_file() and q.name.endswith(suffixes)
        )

    files = under(SUFFIXES)
    py_files = under(PY_SUFFIXES)
    if not files and not py_files:
        raise LookupError(
            "no shell or Python file under %s/ - a zero here is a blind zero" % SCAN_DIR)

    findings: list[str] = []
    honoured: list[str] = []
    undecided = 0
    for path in py_files:
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            raise LookupError("cannot read %s: %s" % (path, exc))
        undecided += scan_python(path, path.relative_to(root), text,
                                 rules, boolop_rule, findings, honoured)

    for path in files:
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            raise LookupError("cannot read %s: %s" % (path, exc))
        rel = path.relative_to(root)
        for lineno, line in logical_lines(text):
            if line.lstrip().startswith("#"):
                continue
            allow = exemption_on(line)
            for rid, why, portable, pattern, counterpart in rules:
                if not pattern.search(line):
                    continue
                if counterpart is not None and "||" in line and counterpart.search(line):
                    continue
                if allow and rid in allow[0]:
                    if len(allow[1]) < MIN_REASON:
                        findings.append(
                            "%s:%d  %s is exempted with no reason written down. "
                            "An exemption is half an edit until it says why."
                            % (rel, lineno, rid)
                        )
                    else:
                        honoured.append("%s:%d  %s - %s" % (rel, lineno, rid, allow[1]))
                    continue
                findings.append(
                    "%s:%d  %s\n         %s\n         portable: %s"
                    % (rel, lineno, rid, why, portable)
                )
    return findings, honoured, {
        "shell": len(files),
        "python": len(py_files),
        "rules": len(rules) + (1 if boolop_rule else 0),
        "undecided": undecided,
    }


def main(argv: list[str]) -> int:
    # The second argument exists so the self-test can hand over a broken
    # catalogue. A gate that can only ever read its own shipped catalogue has no
    # way to prove it reports could-not-measure when that catalogue is wrong -
    # and an unprovable branch is one nobody finds out is dead.
    if len(argv) not in (2, 3):
        return unmeasurable("usage: portable_shell.py <repo-root> [catalogue.json]")
    root = pathlib.Path(argv[1])
    if not (root / SCAN_DIR).is_dir():
        return unmeasurable("no %s/ directory under %s" % (SCAN_DIR, root))

    if len(argv) == 3:
        cat_path = pathlib.Path(argv[2])
    else:
        cat_path = pathlib.Path(__file__).resolve().parent.parent / "data" / "portable-shell-catalogue.json"
    try:
        catalogue = json.loads(cat_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return unmeasurable("cannot read the catalogue %s: %s" % (cat_path, exc))
    if not catalogue.get("rules"):
        return unmeasurable("the catalogue names no rule: there is nothing to enforce")
    try:
        for raw in catalogue["rules"]:
            if raw.get("structural"):
                continue
            re.compile(raw["pattern"])
            if raw.get("counterpart"):
                re.compile(raw["counterpart"])
    except (KeyError, re.error) as exc:
        return unmeasurable("the catalogue does not compile: %s" % exc)

    try:
        findings, honoured, stats = scan(root, catalogue)
    except LookupError as exc:
        return unmeasurable(str(exc))

    print("· read %d shell file(s) and %d Python file(s) under %s/ "
          "against %d catalogue rule(s)"
          % (stats["shell"], stats["python"], SCAN_DIR, stats["rules"]))
    # The blindness gets a number, not just a sentence in out_of_scope. An argv
    # this scanner could not name is an argv it did not check, and a count of
    # them is the difference between "no divergence" and "did not look".
    print("· NOT decidable: %d subprocess call(s) whose argv does not start with "
          "a literal command name" % stats["undecided"])
    # Exemptions are printed on a clean run too. One nobody ever sees is one
    # nobody ever revisits, and this gate's whole premise is that an unwritten
    # limit is an absent limit.
    for line in honoured:
        print("· exempted in writing: %s" % line)
    print("· NOT checked: %s" % " | ".join(catalogue.get("out_of_scope", ["nothing declared"])))

    if findings:
        for line in findings:
            print("FINDING  %s" % line)
        print("%d divergent invocation(s) with no fallback and no written exemption" % len(findings))
        return 1
    print("OK   no BSD-only or GNU-only invocation, in shell or in a Python argv, "
          "outside a fallback or a written exemption")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
