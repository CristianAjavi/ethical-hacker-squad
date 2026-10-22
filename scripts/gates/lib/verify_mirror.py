#!/usr/bin/env python3
"""Compare scripts/verify.sh against the CI job it claims to mirror.

Both directions, because one direction is how this repository keeps getting
caught: a step CI runs and verify.sh omits means a local green is not a green,
and a step verify.sh runs and CI does not means a local red nobody has to fix.
The first is the defect of 2026-09-02; the second is how a mirror rots into a
second, quieter opinion.

The comparison is TEXTUAL. A paraphrase - `run-all.sh` without its `--skip`, a
different quote style - is exactly how a mirror stops mirroring while still
looking like one, so equality is the only thing that counts as agreement.

Usage:  verify_mirror.py <workflow.yml> <verify-steps-file> [job-name]

`verify-steps-file` holds the output of `scripts/verify.sh --list`, one command
per line. The caller runs that; this core never executes anything.

Output lines, one finding per line:
  MISSING_LOCALLY|<cmd>    CI runs it, verify.sh does not
  EXTRA_LOCALLY|<cmd>      verify.sh runs it, CI does not
  ORDER|<n>|<cmd>          both run it, in different positions
  STAT|<key>|<value>
Exit: 0 fine | 1 measured mismatch | 2 could not measure.
"""
import sys

OK, FAIL, UNMEASURABLE = 0, 1, 2


def _indent(line):
    return len(line) - len(line.lstrip(" "))


def job_block(lines, job_name):
    """Return the lines of the job whose `name:` is job_name, else by job id.

    Deliberately not a YAML parser: this reads one known shape and refuses
    anything else, rather than half-understanding an arbitrary document.
    """
    starts = []
    in_jobs = False
    for i, raw in enumerate(lines):
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if _indent(line) == 0:
            in_jobs = line.startswith("jobs:")
            continue
        if in_jobs and _indent(line) == 2 and line.rstrip().endswith(":"):
            starts.append((i, line.strip()[:-1]))

    if not starts:
        return None, "the workflow declares no jobs at the expected indentation"

    bounds = []
    for n, (i, jid) in enumerate(starts):
        end = starts[n + 1][0] if n + 1 < len(starts) else len(lines)
        bounds.append((jid, i, end))

    by_name = []
    for jid, i, end in bounds:
        block = lines[i:end]
        declared = None
        for raw in block:
            stripped = raw.strip()
            if _indent(raw.rstrip("\n")) == 4 and stripped.startswith("name:"):
                declared = stripped[len("name:"):].strip().strip("'\"")
                break
        if declared == job_name or jid == job_name:
            by_name.append((jid, block))

    if len(by_name) == 1:
        return by_name[0][1], None
    if not by_name:
        return None, "no job is named %r and none has that id" % job_name
    return None, "%d jobs answer to %r; the target is ambiguous" % (len(by_name), job_name)


def run_steps(block):
    """Every `run:` in the job, in order. A block scalar becomes one command."""
    out = []
    i = 0
    while i < len(block):
        line = block[i].rstrip("\n")
        stripped = line.strip()
        if stripped.startswith("run:"):
            value = stripped[len("run:"):].strip()
            if value in ("|", ">", "|-", ">-", "|+", ">+"):
                base = _indent(line)
                body, i = [], i + 1
                while i < len(block):
                    nxt = block[i].rstrip("\n")
                    if nxt.strip() and _indent(nxt) <= base:
                        break
                    body.append(nxt.strip())
                    i += 1
                out.append("\n".join(x for x in body if x))
                continue
            out.append(value)
        i += 1
    return out


def main(argv):
    if len(argv) < 3:
        sys.stderr.write("usage: verify_mirror.py <workflow.yml> <steps-file> [job]\n")
        return UNMEASURABLE
    workflow, steps_file = argv[1], argv[2]
    job_name = argv[3] if len(argv) > 3 else "gates"

    try:
        with open(workflow, encoding="utf-8") as fh:
            lines = fh.readlines()
    except OSError as exc:
        sys.stderr.write("cannot read the workflow: %s\n" % exc)
        return UNMEASURABLE

    block, err = job_block(lines, job_name)
    if block is None:
        sys.stderr.write("%s\n" % err)
        return UNMEASURABLE

    ci = run_steps(block)
    if not ci:
        sys.stderr.write("job %r declares no `run:` step; there is nothing to mirror, "
                         "and an empty expectation is not an agreement\n" % job_name)
        return UNMEASURABLE

    try:
        with open(steps_file, encoding="utf-8") as fh:
            local = [ln.rstrip("\n") for ln in fh if ln.strip()]
    except OSError as exc:
        sys.stderr.write("cannot read the local step list: %s\n" % exc)
        return UNMEASURABLE
    if not local:
        sys.stderr.write("`verify.sh --list` named no step. A mirror of nothing is not "
                         "a mirror; this is UNMEASURED, not a match\n")
        return UNMEASURABLE

    findings = 0
    for cmd in ci:
        if cmd not in local:
            print("MISSING_LOCALLY|%s" % cmd)
            findings += 1
    for cmd in local:
        if cmd not in ci:
            print("EXTRA_LOCALLY|%s" % cmd)
            findings += 1

    # Order matters only among the steps both sides agree on: a gate inventory
    # printed after the run it inventories is a different check.
    if findings == 0:
        shared_ci = [c for c in ci if c in local]
        shared_local = [c for c in local if c in ci]
        for n, (a, b) in enumerate(zip(shared_ci, shared_local)):
            if a != b:
                print("ORDER|%d|%s" % (n, a))
                findings += 1

    print("STAT|ci_steps|%d" % len(ci))
    print("STAT|local_steps|%d" % len(local))
    print("STAT|job|%s" % job_name)
    return FAIL if findings else OK


if __name__ == "__main__":
    sys.exit(main(sys.argv))
