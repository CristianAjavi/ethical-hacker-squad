#!/usr/bin/env python3
"""scripts/gates/lib/errexit_rc_capture.py

The step that exists to MEASURE a failure, dying mute exactly when there is one.

THE DEFECT, measured 2026-09-10 on branch `measure/battery-workers`
-------------------------------------------------------------------
`.github/workflows/battery-workers-ab.yml` captured the exit code of the thing
it was measuring like this:

    bash scripts/run-batteries.sh --jobs 1 > one.out 2>&1; r1=$?

GitHub Actions runs every `run:` block under `bash --noprofile --norc -eo
pipefail {0}`. Under `-e` the FIRST command aborts the whole step the moment it
returns non-zero. The `; r1=$?` never executes, the comparison that was the
point of the step never happens, and the step ends with no error title at all.
The run died at ~295 s -- exactly one serial pass -- and the arm that was there
to catch a disagreement caught nothing. `set -e` does not care that you were
about to read `$?`; reading it is not a suppressor.

THE ONLY TWO FORMS THAT SURVIVE `-e`
------------------------------------
    cmd || rc=$?            the sanctioned one: `||` suppresses errexit
    set +e; cmd; rc=$?; set -e   errexit explicitly off for that stretch

Everything else is a capture that the shell never reaches.

WHAT THIS CHECKER ANSWERS
-------------------------
For every `run:` block of every workflow under `.github/workflows/**`: is there
a capture of `$?` at a point where errexit is ON and nothing on that logical
line suppressed it? It reports `file:line`, the variable, and the line.

WHAT IT DOES NOT ANSWER, and will not pretend to
------------------------------------------------
  * Whether the captured code is then USED for anything. A step that captures
    `rc` correctly and never reads it is a different defect and a different
    gate.
  * Shell scripts outside `.github/workflows/**`. This repository's scripts run
    under `set -uo pipefail` WITHOUT `-e`, where `cmd; rc=$?` is correct and
    idiomatic. Flagging them would be a gate acusing the files that comply.
  * A logical line where a top-level `||` appears BEFORE the capture is treated
    as suppressed, even in the corner where the right-hand side of that `||`
    itself fails (`a || b; c=$?` with both failing does abort). That corner is
    declared rather than guessed at: the conservative direction is not to accuse
    a line that looks guarded.
  * `run:` blocks whose step declares a shell this checker cannot interpret. It
    says COULD NOT MEASURE for that block rather than assuming.

Output, one record per line, `|`-separated:
    STAT|<name>|<n>                      accounting, always emitted
    FAIL|<path>|<line>|<var>|<text>      a capture the shell never reaches
    SAFE|<path>|<line>|<var>|<why>       a capture that does survive
    INFO|<path>|<line>|<var>|<why>       a capture in a context where errexit
                                         does not fire (an `if` head, a guarded
                                         line): not this gate's defect
    SKIP|<path>|<line>|<why>             a non-bash block, not analysed
    UNMEAS|<path>|<line>|<why>           could not decide -> rc 2
    ERR|<msg>                            could not measure at all -> rc 2

Exit codes of THIS core: 0 = analysed (findings, if any, are on stdout as FAIL
records) | 2 = could not measure. The wrapper turns FAIL records into rc 1, the
same division of labour every other gate in this repo uses.
"""

import os
import re
import sys

# --------------------------------------------------------------------------
# Shell semantics of GitHub Actions.
# https://docs.github.com/actions -- `run:` defaults to `bash --noprofile
# --norc -eo pipefail {0}` on Linux and macOS; `shell: sh` becomes `sh -e {0}`.
# Both have errexit ON. A custom template has whatever flags it is given.
# --------------------------------------------------------------------------
KEYWORD_SHELLS_ERREXIT = {"bash", "sh"}
KEYWORD_SHELLS_NOT_BASH = {"pwsh", "powershell", "python", "cmd"}

RE_RUN_KEY = re.compile(r"^(\s*)(?:-\s+)?run:\s*(.*)$")
RE_SHELL_KEY = re.compile(r"^(\s*)(?:-\s+)?shell:\s*(.+?)\s*$")
RE_STEP_START = re.compile(r"^(\s*)-\s+\S")
RE_DEFAULTS_KEY = re.compile(r"^\s*defaults:\s*$")
RE_ASSIGN_MODIFIER = re.compile(r"^(export|local|declare|typeset|readonly)\s+(-\w+\s+)*")
RE_LEAD_KEYWORD = re.compile(r"^(then|else|elif|do|time|exec|eval|command|!)\s+")
RE_CAPTURE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=\$\?(?![A-Za-z0-9_])")
RE_CONTEXT_OPENER = re.compile(r"^(if|elif|while|until)\b")

SEPARATORS = (";;", "&&", "||", "|&", ";", "|", "&")


class Unmeasurable(Exception):
    pass


# --------------------------------------------------------------------------
# Lexing helpers. Quote- and substitution-aware, because the whole point is not
# to match `rc=$?` inside `echo "serial rc=$?"`.
# --------------------------------------------------------------------------
def strip_comment(line):
    """Remove a trailing shell comment: an unquoted `#` at start or after space."""
    out = []
    sq = dq = False
    depth = 0
    i = 0
    while i < len(line):
        ch = line[i]
        if not sq and ch == "\\" and i + 1 < len(line):
            out.append(ch)
            out.append(line[i + 1])
            i += 2
            continue
        if ch == "'" and not dq:
            sq = not sq
        elif ch == '"' and not sq:
            dq = not dq
        elif not sq and not dq:
            if line.startswith("$(", i):
                depth += 1
            elif ch == ")" and depth > 0:
                depth -= 1
            elif ch == "#" and depth == 0 and (i == 0 or line[i - 1] in " \t"):
                break
        out.append(ch)
        i += 1
    return "".join(out)


def split_segments(line):
    """Split a logical line into (separator_before, text) segments.

    Splitting happens only at top level: outside quotes, outside `$(...)` and
    outside backticks. Grouping characters are treated as separators too, so a
    capture inside `( ... )` is seen as the start of a simple command.
    """
    segs = []
    sep = ""
    buf = []
    sq = dq = False
    depth = 0
    i = 0
    n = len(line)
    while i < n:
        ch = line[i]
        if not sq and ch == "\\" and i + 1 < n:
            buf.append(ch)
            buf.append(line[i + 1])
            i += 2
            continue
        if ch == "'" and not dq:
            sq = not sq
            buf.append(ch)
            i += 1
            continue
        if ch == '"' and not sq:
            dq = not dq
            buf.append(ch)
            i += 1
            continue
        if sq or dq:
            buf.append(ch)
            i += 1
            continue
        if ch == "`":
            # backticks do not nest; the whole run is opaque
            j = line.find("`", i + 1)
            j = n if j < 0 else j + 1
            buf.append(line[i:j])
            i = j
            continue
        if line.startswith("$(", i):
            depth += 1
            buf.append(line[i : i + 2])
            i += 2
            continue
        if ch == ")" and depth > 0:
            depth -= 1
            buf.append(ch)
            i += 1
            continue
        if depth == 0:
            matched = None
            for s in SEPARATORS:
                if line.startswith(s, i):
                    matched = s
                    break
            if matched:
                segs.append((sep, "".join(buf)))
                sep = matched
                buf = []
                i += len(matched)
                continue
            if ch in "(){}":
                segs.append((sep, "".join(buf)))
                sep = ch
                buf = []
                i += 1
                continue
        buf.append(ch)
        i += 1
    segs.append((sep, "".join(buf)))
    return segs


def capture_in_segment(text):
    """Return the variable name if this segment STARTS with an assignment of $?."""
    s = text.strip()
    while True:
        m = RE_LEAD_KEYWORD.match(s)
        if not m:
            break
        s = s[m.end():].lstrip()
    m = RE_ASSIGN_MODIFIER.match(s)
    if m:
        s = s[m.end():].lstrip()
    m = RE_CAPTURE.match(s)
    return m.group(1) if m else None


# --------------------------------------------------------------------------
# `set` tracking.
# --------------------------------------------------------------------------
def errexit_change(segment_text):
    """None if this segment is not a `set` touching errexit; else True/False."""
    s = segment_text.strip()
    while True:
        m = RE_LEAD_KEYWORD.match(s)
        if not m:
            break
        s = s[m.end():].lstrip()
    parts = s.split()
    if not parts or parts[0] != "set":
        return None
    state = None
    i = 1
    while i < len(parts):
        tok = parts[i]
        if tok in ("-o", "+o"):
            if i + 1 < len(parts) and parts[i + 1] == "errexit":
                state = tok == "-o"
                i += 2
                continue
            i += 2
            continue
        if tok.startswith("-") and not tok.startswith("--"):
            if "e" in tok[1:]:
                state = True
        elif tok.startswith("+"):
            if "e" in tok[1:]:
                state = False
        i += 1
    return state


# --------------------------------------------------------------------------
# YAML-shaped, line-oriented extraction of `run:` blocks. Deliberately textual:
# a real YAML load gives no reliable line number for a line INSIDE a block
# scalar, and a line number is the whole product of this gate. It also means the
# gate needs no third-party module and can therefore never report 2 because
# PyYAML was missing.
# --------------------------------------------------------------------------
def shell_for_block(lines, run_idx, indent):
    """The `shell:` declared by the step that owns this `run:`, or None."""
    start = 0
    for i in range(run_idx, -1, -1):
        m = RE_STEP_START.match(lines[i])
        if m and len(m.group(1)) + 2 <= indent:
            start = i
            break
    end = len(lines)
    for i in range(run_idx + 1, len(lines)):
        m = RE_STEP_START.match(lines[i])
        if m and len(m.group(1)) + 2 <= indent:
            end = i
            break
    for i in range(start, end):
        m = RE_SHELL_KEY.match(lines[i])
        if m and len(m.group(1)) + (2 if lines[i].lstrip().startswith("- ") else 0) == indent:
            return m.group(2).strip().strip("'\"")
        if m and len(m.group(1)) == indent:
            return m.group(2).strip().strip("'\"")
    return None


def errexit_for_shell(shell):
    """(errexit_on, kind) where kind is 'bash' | 'other' | 'unknown'."""
    if shell is None:
        return True, "bash"
    s = shell.strip()
    base = s.split()[0] if s.split() else ""
    if s in KEYWORD_SHELLS_ERREXIT:
        return True, "bash"
    if s in KEYWORD_SHELLS_NOT_BASH:
        return False, "other"
    if "{0}" in s:
        if os.path.basename(base) in KEYWORD_SHELLS_NOT_BASH:
            return False, "other"
        flags = []
        for tok in s.split():
            if tok == "{0}":
                break
            flags.append(tok)
        on = False
        i = 0
        while i < len(flags):
            tok = flags[i]
            if tok == "-o" and i + 1 < len(flags) and flags[i + 1] == "errexit":
                on = True
                i += 2
                continue
            if tok.startswith("-") and not tok.startswith("--") and "e" in tok[1:]:
                on = True
            i += 1
        return on, "bash"
    return True, "unknown"


def extract_run_blocks(path, lines):
    """Yield (first_body_line_index, body_lines_with_numbers, shell, indent)."""
    blocks = []
    i = 0
    while i < len(lines):
        m = RE_RUN_KEY.match(lines[i])
        if not m:
            i += 1
            continue
        lead, rest = m.group(1), m.group(2).strip()
        indent = len(lead) + (2 if lines[i].lstrip().startswith("- ") else 0)
        shell = shell_for_block(lines, i, indent)
        if rest and rest[0] not in "|>":
            blocks.append((i, [(i + 1, rest)], shell))
            i += 1
            continue
        body = []
        j = i + 1
        body_indent = None
        while j < len(lines):
            ln = lines[j]
            if ln.strip() == "":
                body.append((j + 1, ""))
                j += 1
                continue
            cur = len(ln) - len(ln.lstrip())
            if body_indent is None:
                if cur <= indent:
                    break
                body_indent = cur
            if cur < body_indent:
                break
            body.append((j + 1, ln[body_indent:].rstrip("\n")))
            j += 1
        while body and body[-1][1] == "":
            body.pop()
        blocks.append((i, body, shell))
        i = j
    return blocks


def join_continuations(body):
    """[(line_no, text)] -> [(line_no_of_last_physical_line, joined_text)]."""
    out = []
    acc = []
    acc_line = None
    for lineno, text in body:
        stripped = text.rstrip()
        if acc_line is None:
            acc_line = lineno
        cont = stripped.endswith("\\") and not stripped.endswith("\\\\")
        acc.append(stripped[:-1] if cont else stripped)
        if not cont:
            out.append((lineno, " ".join(a.strip() for a in acc).strip()))
            acc = []
            acc_line = None
    if acc:
        out.append((acc_line, " ".join(a.strip() for a in acc).strip()))
    return out


def analyse_block(rel, body, shell, records, stats):
    errexit_on, kind = errexit_for_shell(shell)
    first_line = body[0][0] if body else 0
    if kind == "other":
        stats["skipped_blocks"] += 1
        records.append("SKIP|%s|%d|shell %r is not a POSIX shell: errexit does not apply" % (rel, first_line, shell))
        return
    if kind == "unknown":
        stats["unmeasurable"] += 1
        records.append("UNMEAS|%s|%d|shell %r cannot be interpreted: I do not know whether errexit is on" % (rel, first_line, shell))
        return

    stats["run_blocks"] += 1
    prev_code = ""
    for lineno, raw in join_continuations(body):
        code = strip_comment(raw).strip()
        if not code:
            continue
        segs = split_segments(code)
        guarded = False
        bare_assignment_line = bool(RE_CAPTURE.match(code))
        for sep, text in segs:
            if sep == "||":
                guarded = True
            ch = errexit_change(text)
            if ch is not None:
                errexit_on = ch
            var = capture_in_segment(text)
            if var is None:
                continue
            stats["captures"] += 1
            snippet = code if len(code) <= 120 else code[:117] + "..."
            if sep == "||":
                stats["safe_or"] += 1
                records.append("SAFE|%s|%d|%s|`|| %s=$?` survives errexit" % (rel, lineno, var, var))
            elif not errexit_on:
                stats["safe_noerrexit"] += 1
                records.append("SAFE|%s|%d|%s|errexit is off here (`set +e`)" % (rel, lineno, var))
            elif guarded:
                stats["info_context"] += 1
                records.append("INFO|%s|%d|%s|a top-level `||` earlier on this line suppressed errexit" % (rel, lineno, var))
            elif bare_assignment_line and (
                RE_CONTEXT_OPENER.match(prev_code) or prev_code.endswith("then") or prev_code.endswith("do")
            ):
                stats["info_context"] += 1
                records.append("INFO|%s|%d|%s|the preceding command is a condition head, where errexit does not fire" % (rel, lineno, var))
            else:
                stats["fail"] += 1
                records.append("FAIL|%s|%d|%s|%s" % (rel, lineno, var, snippet))
        prev_code = code


def analyse_file(path, root, records, stats):
    rel = os.path.relpath(path, root) if root else path
    try:
        with open(path, "r", encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except OSError as exc:
        records.append("ERR|cannot read %s: %s" % (rel, exc))
        raise Unmeasurable()
    for i, ln in enumerate(lines):
        if RE_DEFAULTS_KEY.match(ln):
            for j in range(i + 1, min(i + 6, len(lines))):
                if RE_SHELL_KEY.match(lines[j]):
                    stats["unmeasurable"] += 1
                    records.append(
                        "UNMEAS|%s|%d|a `defaults:` block sets a shell for a whole job or workflow; "
                        "this checker only reads the shell declared on the step" % (rel, j + 1)
                    )
                    return
    stats["files"] += 1
    for _idx, body, shell in extract_run_blocks(path, lines):
        if body:
            analyse_block(rel, body, shell, records, stats)


def collect(targets):
    files = []
    for t in targets:
        if os.path.isdir(t):
            for dirpath, _dirs, names in sorted(os.walk(t)):
                for name in sorted(names):
                    if name.endswith((".yml", ".yaml")):
                        files.append(os.path.join(dirpath, name))
        elif os.path.isfile(t):
            files.append(t)
    return files


# --------------------------------------------------------------------------
# The known-positive / known-negative control. It runs on every invocation of
# the gate, over strings embedded HERE, so a checker that has gone blind is
# caught by the gate itself rather than by the absence of findings. A sweep that
# reports zero because it cannot see is indistinguishable from a clean tree, and
# this repository has already paid for that once, in the competitor sweep.
# --------------------------------------------------------------------------
CONTROL_CASES = [
    (
        "positive-trailing",
        "jobs:\n  a:\n    steps:\n      - run: |\n"
        "          bash x.sh > one.out 2>&1; r1=$?\n",
        1,
    ),
    (
        "positive-own-line",
        "jobs:\n  a:\n    steps:\n      - run: |\n"
        "          bash x.sh\n          status=$?\n",
        1,
    ),
    (
        "negative-or-capture",
        "jobs:\n  a:\n    steps:\n      - run: |\n"
        "          rc=0\n          bash x.sh || rc=$?\n",
        0,
    ),
    (
        "negative-set-plus-e",
        "jobs:\n  a:\n    steps:\n      - run: |\n"
        "          set +e\n          bash x.sh\n          RC=$?\n          set -e\n",
        0,
    ),
    (
        "negative-quoted-text",
        "jobs:\n  a:\n    steps:\n      - run: |\n"
        '          echo "serial rc=$? parallel rc=$?"\n',
        0,
    ),
]


def self_check():
    import tempfile

    bad = []
    for name, text, expected in CONTROL_CASES:
        with tempfile.NamedTemporaryFile("w", suffix=".yml", delete=False) as fh:
            fh.write(text)
            tmp = fh.name
        try:
            recs = []
            st = new_stats()
            analyse_file(tmp, os.path.dirname(tmp), recs, st)
            got = st["fail"]
        finally:
            os.unlink(tmp)
        if got != expected:
            bad.append("%s: expected %d FAIL, detector produced %d" % (name, expected, got))
    return bad


def new_stats():
    return {
        "files": 0,
        "run_blocks": 0,
        "captures": 0,
        "fail": 0,
        "safe_or": 0,
        "safe_noerrexit": 0,
        "info_context": 0,
        "skipped_blocks": 0,
        "unmeasurable": 0,
    }


def main(argv):
    if "--self-check" in argv:
        bad = self_check()
        for b in bad:
            print("ERR|control case disagreed -- %s" % b)
        if bad:
            return 2
        print("STAT|control_cases|%d" % len(CONTROL_CASES))
        return 0

    root = None
    targets = []
    i = 0
    while i < len(argv):
        if argv[i] == "--root":
            root = argv[i + 1]
            i += 2
            continue
        targets.append(argv[i])
        i += 1

    if not targets:
        print("ERR|no target given")
        return 2
    files = collect(targets)
    if not files:
        print("ERR|no workflow file found under: %s" % " ".join(targets))
        return 2

    records = []
    stats = new_stats()
    try:
        for f in files:
            analyse_file(f, root, records, stats)
    except Unmeasurable:
        for r in records:
            print(r)
        return 2

    # The blindness guard comes AFTER the unmeasurable check on purpose: a file
    # this checker refused to analyse has zero parsed blocks by construction, and
    # reporting that as "the extractor is blind" would hand the reader a false
    # cause for a correct verdict.
    if stats["run_blocks"] == 0 and not stats["unmeasurable"]:
        print("ERR|%d workflow file(s) read and not one `run:` block was parsed: "
              "the extractor is blind, not the tree clean" % len(files))
        return 2

    for k in sorted(stats):
        print("STAT|%s|%d" % (k, stats[k]))
    for r in records:
        print(r)
    return 2 if stats["unmeasurable"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
