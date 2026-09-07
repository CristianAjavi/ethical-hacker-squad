#!/usr/bin/env python3
"""Mutation bank over the coverage sweep's OWN refusals.

`coverage_sweep.py` excludes itself from its own sweep, and the backlog called
that a hole in the SUBJECT list: the engine simply is not among the libraries it
mutates. Measured, that reading is wrong. The sweep's operator is
`X.append(...)` as a statement, and this engine has seven of those - `plan`,
`results`, `seen`, `found`, `named_by`, `unresolved`, `aborted` - of which NONE
is a report site. They are all plumbing. Adding the engine to the subject list
would manufacture seven mutants that crash and cover zero rules.

The engine does not report through a findings list. It reports by REFUSING: a
`print` and then `return 1` (measured, fails) or `return 2` (could not measure).
Those are its report sites, and the question this bank asks is the sweep's own
question in the engine's own vocabulary:

    if this refusal silently became a pass, would any case notice?

Each mutant is one `return 1` / `return 2` rewritten to `return 0`, in a copy of
the tree, judged by the 44-case battery. The judge is the unmutated original.

WHAT IT FOUND, the first time it ran: fourteen refusals, ELEVEN caught, THREE
alive. All three were `except` blocks - the cases covered the checks and left the
catches uncovered - and the worst of them was `the sweep itself failed`. A
library that does not parse raises out of report_sites, and with that refusal
gone the deepest scanner in the repository falls over and reports green. Cases
33-35 of the battery close all three; this bank is what keeps them closed.

WHERE IT LIVES, and why not next to the gates. `run-all.sh` discovers gates by
walking scripts/gates/ and taking everything that is not documentation, data,
fixtures or the shared library - on purpose, so a new file of an unknown type
cannot slip past unnoticed. A bank dropped in there is therefore a GATE, and two
governance gates said so immediately: contract-inventory wanted a row in the
requirements document and negative-proof wanted a sibling self-test. They were
right and the placement was wrong. It sits beside time-repeat.mutants.py, which
is the convention for a mutation bank in this tree, with a thin
`*.mutants.selftest.sh` next to it so run-batteries.sh runs it.

Exit codes follow the house rule in lib/common.sh: 0 measured and clean, 1
measured and a refusal is unwatched, 2 COULD NOT MEASURE, which is never a pass.

The baseline run is not decoration. The first version of this bank copied only
`scripts/` and not `.github/`, so the case that reads the workflow file failed in
every mutant for want of a file, and the bank counted that failure as the case
catching the mutant - reporting coverage that did not exist, which is the exact
defect it exists to find. An unmutated tree that does not come back green means
no red below can be attributed to a mutant, and this refuses instead of guessing.
"""
import concurrent.futures as cf
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
ENGINE = "scripts/gates/lib/coverage_sweep.py"
BATTERY = "scripts/gates/gate-coverage-sweep.selftest.sh"
NEEDED = ("scripts", ".github")

# A refusal is a bare `return 1` or `return 2` on a line of its own. The engine
# writes them that way throughout; anything fancier is not a refusal.
REFUSAL = re.compile(r"^(\s+)return ([12])\s*$")
# Same vocabulary the sweep reads: a battery names the case it failed on.
# `FAIL <text>` is gate_fail - the gate's verdict, not a case - and reading it as
# a name is how a crash gets scored as coverage.
NAMED = re.compile(r"^\s*(?:FAILED|HARNESS)\s+(\S+)")
JOBS = int(os.environ.get("EHS_REFUSAL_JOBS", "4"))


def enclosing(src, i):
    for j in range(i, -1, -1):
        m = re.match(r"(?:def|    def) (\w+)", src[j])
        if m:
            return m.group(1)
    return "?"


def refusal_sites(src):
    sites = []
    for i, line in enumerate(src):
        m = REFUSAL.match(line)
        if m:
            said = re.findall(r'"([A-Z][^"%]{10,})', "".join(src[max(0, i - 7):i]))
            sites.append(dict(idx=i, lineno=i + 1, code=int(m.group(2)),
                              fn=enclosing(src, i), indent=m.group(1),
                              says=(said[-1].strip() if said else "")))
    return sites


def workspace(src, mutate=None):
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="ehs-refusal."))
    for d in NEEDED:
        shutil.copytree(ROOT / d, tmp / d, symlinks=True)
    if mutate is not None:
        lines = list(src)
        lines[mutate["idx"]] = "%sreturn 0  # MUTANT\n" % mutate["indent"]
        (tmp / ENGINE).write_text("".join(lines), encoding="utf-8")
    return tmp


def battery(tmp):
    p = subprocess.run(["bash", str(tmp / BATTERY)], capture_output=True,
                       text=True, cwd=str(tmp))
    out = p.stdout + p.stderr
    named = [NAMED.match(l).group(1).rstrip(":")
             for l in out.splitlines() if NAMED.match(l)]
    return p.returncode, named, out


def main():
    for d in NEEDED:
        if not (ROOT / d).is_dir():
            print("HARNESS  tree-is-complete: %s has no %s" % (ROOT, d))
            return 2
    if not (ROOT / ENGINE).is_file() or not (ROOT / BATTERY).is_file():
        print("HARNESS  engine-and-battery-exist: one of them is missing")
        return 2

    src = (ROOT / ENGINE).read_text(encoding="utf-8").splitlines(keepends=True)
    sites = refusal_sites(src)
    if not sites:
        print("HARNESS  engine-has-refusals: no `return 1` or `return 2` found, "
              "which means this bank is reading the wrong file or the engine "
              "stopped refusing - either way nothing below would mean anything")
        return 2

    tmp = workspace(src)
    try:
        rc, named, out = battery(tmp)
    finally:
        subprocess.run(["/bin/rm", "-rf", str(tmp)])
    if rc != 0 or named:
        print("HARNESS  baseline-is-green: the unmutated tree came back rc %d "
              "(%s), so no red below could be blamed on a mutant"
              % (rc, ", ".join(named) or "no case named"))
        print("\n".join("        | " + l for l in out.splitlines()[-15:]))
        return 2
    print("baseline  the unmutated tree is green, so the battery's silence "
          "means something")
    print("%d refusal(s) in %s: %d of code 1, %d of code 2"
          % (len(sites), pathlib.Path(ENGINE).name,
             sum(s["code"] == 1 for s in sites),
             sum(s["code"] == 2 for s in sites)))

    def run_one(site):
        tmp = workspace(src, mutate=site)
        try:
            rc, named, _ = battery(tmp)
        finally:
            subprocess.run(["/bin/rm", "-rf", str(tmp)])
        return dict(site, rc=rc, named=named, survived=rc == 0,
                    crash_only=rc != 0 and not named)

    t0 = time.time()
    with cf.ThreadPoolExecutor(max_workers=max(1, JOBS)) as ex:
        results = sorted(ex.map(run_one, sites), key=lambda r: r["lineno"])

    survivors = [r for r in results if r["survived"]]
    crashes = [r for r in results if r["crash_only"]]
    for r in results:
        case = "refusal:%s:%d" % (pathlib.Path(ENGINE).name, r["lineno"])
        if r["survived"]:
            print("FAILED  %s  return %d in %s() can become a pass and no case "
                  "notices%s" % (case, r["code"], r["fn"],
                                 (' - it says "%s"' % r["says"][:44])
                                 if r["says"] else ""))
        elif r["crash_only"]:
            print("FAILED  %s  the battery went red with no case naming it, so "
                  "the mutant was caught by a crash, and a crash is caught by "
                  "anything" % case)
        else:
            print("PASS    %s  %s" % (case, ", ".join(r["named"][:3])))

    print("\n%d mutant(s) in %.0f s · %d caught by a named case · %d survive · "
          "%d red with no case naming them"
          % (len(results), time.time() - t0,
             len(results) - len(survivors) - len(crashes), len(survivors),
             len(crashes)))
    if survivors or crashes:
        print("\nFAIL  a refusal nobody watches is a refusal that can be deleted "
              "by accident. Write the case, in %s." % BATTERY)
        return 1
    print("OK    every refusal in the engine has a case that notices when it "
          "turns into a pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
