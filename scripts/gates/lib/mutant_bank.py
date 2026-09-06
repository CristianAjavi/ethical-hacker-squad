#!/usr/bin/env python3
"""Break one gate rule on purpose and demand that its battery notice.

A green battery says the cases ran. It does not say they measured anything. A
case named `the-copy-renamed-around-the-rule` sat green in this repository for
weeks proving nothing: its fixture carried a version string the lockfile already
held, so the value check fired first and returned the expected code, and the name
path the case was named after was never reached. Nothing in the repository could
tell the difference between that and coverage.

This can. Each entry in the bank names one line of one gate, the edit that
silences it, and the battery case that claims to cover it. The line is silenced
in a THROWAWAY CLONE of the tree, the battery is run there, and three outcomes
are distinguished where a naive runner sees two:

  caught          the battery went red AND the named case is among the failures
  caught-elsewhere  the battery went red, but not through the case that claims
                  the rule - the rule has coverage, the case does not deserve
                  its name, and both facts are worth printing
  survived        the battery stayed green - the rule has no coverage at all

`expect: survives` is a first-class entry, not a bug. One mutant here makes
`github_checksum_valid` return True unconditionally and no case can tell, because
telling would mean committing a checksum-valid GitHub token to a public
repository - which is refused. Writing that down as an accepted survivor is
honest; leaving it out would make the bank's pass rate a flattering fiction. If
someone later adds that coverage, the entry flips to caught and this gate goes
RED asking for the bank to be updated: a bank that only fails in one direction
rots quietly.

Why a clone and not the tree itself. An earlier draft of this file mutated the
working tree in place and defended itself with a sentinel file, a byte-verified
restore and a refusal to auto-recover, because copying 268 MB per mutant "is not
affordable". That stopped being true: the fixture trees now clone through APFS
clonefile in 0.22 s. The whole apparatus was deleted along with its worst case,
which was leaving a developer's checkout broken.

Exit codes follow scripts/gates/lib/common.sh: 0 measured and OK, 1 measured and
FAILS, 2 COULD NOT MEASURE - never a pass. A bank entry whose anchor no longer
appears in the file, or appears twice, is a 2 and not a 1: the gate has not
measured that rule, it has lost track of it.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

# Four is the cap the battery runner settled on for the same reason: measured,
# four copy-heavy jobs at once expand each other by x2.0 to x4.5, and past that
# the wall clock stops improving.
DEFAULT_JOBS = 4
BATTERY_TIMEOUT = 600
# A clone is cheap but not free, and this repository is developed on a laptop
# whose data volume runs near full. Stopping with "could not measure" beats
# filling the disk and blaming the gate.
FREE_FLOOR_BYTES = 3 * 1024 ** 3

FAILED_CASE = re.compile(r"^\s*(?:FAILED|FAIL|HARNESS)\s+(\S+)")


def repo_root() -> Path:
    env = os.environ.get("EHS_REPO_ROOT")
    if env:
        return Path(env).resolve()
    here = Path(__file__).resolve().parent
    try:
        out = subprocess.run(["git", "-C", str(here), "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True, timeout=30)
        if out.returncode == 0 and out.stdout.strip():
            return Path(out.stdout.strip()).resolve()
    except (OSError, subprocess.SubprocessError):
        pass
    return here.parent.parent


def free_bytes(path: Path) -> int:
    s = os.statvfs(str(path))
    return s.f_bavail * s.f_frsize


def failed_cases(text: str) -> list[str]:
    """Case names the battery reported as failing - a SUPERSET, on purpose.

    Batteries print `FAILED <case>`, `FAIL <case>` and `HARNESS <case>`, and the
    gates they run print `FAIL <message>` for each finding. The two are not
    reliably distinguishable, so this list also carries fragments of gate
    findings. That is harmless because nothing here decides anything by
    counting: the verdict tests whether a SPECIFIC declared case name is in the
    list, and a stray `docs/example.md:1` can never satisfy that.
    """
    return sorted({m.group(1) for m in
                   (FAILED_CASE.match(line) for line in text.splitlines()) if m})


def build_pristine(root: Path, dest: Path) -> float:
    """One copy of the tree, without `.git`, that every mutant clones from.

    `.git` is excluded on purpose: it is the bulk of the tree, no battery reads
    it once EHS_REPO_ROOT is set, and a clone that carries it costs 5.5 s where
    one without costs 0.9 s. Measured on this repository, not assumed.
    """
    dest.mkdir(parents=True, exist_ok=True)
    t0 = time.time()
    subprocess.run(
        "(cd %s && tar --exclude .git --exclude __pycache__ --exclude node_modules "
        "-cf - .) | (cd %s && tar -xf -)" % (shell_quote(root), shell_quote(dest)),
        shell=True, check=True)
    return time.time() - t0


def shell_quote(p: Path) -> str:
    return "'" + str(p).replace("'", "'\\''") + "'"


def clone(pristine: Path, work: Path) -> None:
    """APFS clonefile if the platform has it, a plain copy if it does not.

    `cp -c` is BSD-only; GNU coreutils exits at option parsing. So it is TRIED
    and never assumed - the `||` is the probe, and scripts/gates/data/
    portable-shell-catalogue.json has a rule that refuses this spelling written
    any other way.
    """
    work.mkdir(parents=True, exist_ok=True)
    r = subprocess.run(["cp", "-Rc", "%s/." % pristine, str(work)], capture_output=True)
    if r.returncode != 0:
        subprocess.run(["cp", "-R", "%s/." % pristine, str(work)], check=True)


def run_battery(root: Path, battery: str) -> tuple[int, str]:
    path = root / battery
    if not path.exists():
        return 2, "battery not found: %s" % battery
    env = dict(os.environ)
    env["EHS_REPO_ROOT"] = str(root)
    # A battery that inherits the outer job cap would fan out inside a mutant run
    # that is already running four at a time.
    env["EHS_BATTERY_JOBS"] = "1"
    try:
        p = subprocess.run(["bash", str(path)], cwd=str(root), stdin=subprocess.DEVNULL,
                           capture_output=True, text=True, env=env,
                           timeout=BATTERY_TIMEOUT)
    except subprocess.TimeoutExpired:
        return 2, "battery timed out after %d s" % BATTERY_TIMEOUT
    return p.returncode, p.stdout + p.stderr


def apply_mutant(work: Path, m: dict) -> str | None:
    """Edit the clone. Returns an error string, or None when the edit landed.

    Two things are checked and neither is optional. The anchor must appear
    EXACTLY ONCE - zero means the bank is describing code that no longer exists,
    two means the edit would land somewhere nobody chose. And the bytes must
    actually differ afterwards, because a replacement identical to its anchor
    silently produces a green run that looks like coverage.
    """
    target = work / m["target"]
    if not target.exists():
        return "target missing: %s" % m["target"]
    text = target.read_text(encoding="utf-8")
    n = text.count(m["find"])
    if n != 1:
        return "anchor appears %d times, expected exactly 1" % n
    mutated = text.replace(m["find"], m["replace"], 1)
    if mutated == text:
        return "replacement is identical to the anchor; nothing was changed"
    target.write_text(mutated, encoding="utf-8")
    return None


def judge(m: dict, rc: int, out: str) -> tuple[str, str]:
    """(verdict, one-line explanation). Verdict is ok / fail / unmeasured."""
    expect = m.get("expect", "caught")
    if rc == 2:
        return "unmeasured", out.strip().splitlines()[-1] if out.strip() else "rc 2"
    red = failed_cases(out)
    if expect == "survives":
        if rc == 0:
            why = " ".join(m.get("why", "").split())
            return "ok", "survives, as the bank records: %s" % (
                why if len(why) <= 96 else why[:93] + "...")
        return "fail", ("the bank says this one cannot be caught, but %s caught it - "
                        "coverage was added and the bank is stale"
                        % (", ".join(red[:2]) or "the battery"))
    # expect == "caught"
    if rc == 0:
        return "fail", "SURVIVED: no case noticed, so nothing covers this rule"
    by = m.get("by")
    if by and by not in red:
        return "fail", ("caught by %s, but NOT by `%s`, which is the case that claims "
                        "this rule" % (", ".join(red[:2]) or "?", by))
    return "ok", "caught by %s" % by if by else "caught by %s" % ", ".join(red[:2])


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--bank", default=None, help="path to mutant-bank.json")
    ap.add_argument("--only", default=None, help="run one mutant by id")
    ap.add_argument("--jobs", type=int, default=None)
    ap.add_argument("--no-color", action="store_true")
    args = ap.parse_args()

    root = repo_root()
    bank_path = Path(args.bank) if args.bank else root / "scripts/gates/data/mutant-bank.json"
    if not bank_path.exists():
        print("COULD NOT MEASURE: no bank at %s" % bank_path)
        return 2
    try:
        bank = json.loads(bank_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as e:
        print("COULD NOT MEASURE: bank will not parse: %s" % e)
        return 2

    mutants = bank.get("mutants", [])
    declared = bank.get("declared")
    if declared is not None and declared != len(mutants):
        print("FAIL the bank declares %s mutants and carries %d" % (declared, len(mutants)))
        return 1
    if args.only:
        mutants = [m for m in mutants if m["id"] == args.only]
        if not mutants:
            print("COULD NOT MEASURE: no mutant with id %s" % args.only)
            return 2
    if not mutants:
        print("COULD NOT MEASURE: the bank is empty")
        return 2

    if free_bytes(Path(tempfile.gettempdir())) < FREE_FLOOR_BYTES:
        print("COULD NOT MEASURE: under %.1f GB free in TMPDIR; a clone per mutant "
              "would not fit" % (FREE_FLOOR_BYTES / 1024 ** 3))
        return 2

    base = Path(tempfile.mkdtemp(prefix="ehs-mutant-"))
    try:
        pristine = base / "pristine"
        secs = build_pristine(root, pristine)

        jobs = args.jobs or int(os.environ.get("EHS_MUTANT_JOBS", DEFAULT_JOBS))

        # Nothing below means anything if a battery is already red without a
        # mutant in it. That is a 2, not a 1: this gate did not measure the
        # batteries, it inherited their failure.
        #
        # Each baseline runs in its OWN clone rather than all of them in
        # `pristine`. Batteries write into the tree they are pointed at, and a
        # shared tree would let one baseline see another's fixtures - which is
        # also why they can run at the same time at all.
        batteries = sorted({m["battery"] for m in mutants})
        base_lock = threading.Lock()
        base_bad: list[tuple[str, int, str]] = []
        base_queue = list(enumerate(batteries))
        bq_lock = threading.Lock()

        def baseline_worker() -> None:
            while True:
                with bq_lock:
                    if not base_queue:
                        return
                    i, b = base_queue.pop(0)
                work = base / ("base%02d" % i)
                try:
                    clone(pristine, work)
                    rc, out = run_battery(work, b)
                finally:
                    subprocess.run(["/bin/rm", "-rf", str(work)])
                if rc != 0:
                    with base_lock:
                        base_bad.append((b, rc, out))

        bts = [threading.Thread(target=baseline_worker)
               for _ in range(max(1, min(jobs, len(batteries))))]
        for t in bts:
            t.start()
        for t in bts:
            t.join()
        if base_bad:
            for b, rc, out in sorted(base_bad):
                print("COULD NOT MEASURE: %s is rc %d on an unmutated tree" % (b, rc))
                for line in failed_cases(out)[:5]:
                    print("    already failing: %s" % line)
            return 2
        print("baseline: %d batter%s green on an unmutated clone (%.2f s to build "
              "the tree they clone from)"
              % (len(batteries), "y" if len(batteries) == 1 else "ies", secs))

        jobs = max(1, min(jobs, len(mutants)))
        lock = threading.Lock()
        queue = list(enumerate(mutants))
        qlock = threading.Lock()
        rows: list[tuple[str, str, str, float]] = []

        def worker() -> None:
            while True:
                with qlock:
                    if not queue:
                        return
                    i, m = queue.pop(0)
                work = base / ("m%03d" % i)
                t0 = time.time()
                try:
                    clone(pristine, work)
                    err = apply_mutant(work, m)
                    if err:
                        verdict, why, rc = "unmeasured", err, 2
                    else:
                        rc, out = run_battery(work, m["battery"])
                        verdict, why = judge(m, rc, out)
                finally:
                    subprocess.run(["/bin/rm", "-rf", str(work)])
                with lock:
                    rows.append((verdict, m["id"], why, time.time() - t0))

        threads = [threading.Thread(target=worker) for _ in range(jobs)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        # Output follows the convention every other gate core in this directory
        # uses: the shell wrapper reads the prefix and decides the colour, so the
        # verdict lives in one place instead of two.
        rows.sort(key=lambda r: ({"fail": 0, "unmeasured": 1, "ok": 2}[r[0]], r[1]))
        for verdict, mid, why, took in rows:
            if verdict == "fail":
                print("FINDING %s — %s" % (mid, why))
            elif verdict == "unmeasured":
                print("UNMEASURED %s — %s" % (mid, why))
            else:
                print("%-46s %5.1fs  %s" % (mid, took, why))

        n_fail = sum(1 for r in rows if r[0] == "fail")
        n_un = sum(1 for r in rows if r[0] == "unmeasured")
        n_surv = sum(1 for m in mutants if m.get("expect") == "survives")
        print("%d mutant(s) run at %d at a time: %d behaved as the bank says, "
              "%d did not, %d could not be measured"
              % (len(rows), jobs, len(rows) - n_fail - n_un, n_fail, n_un))
        # The survivor count is printed on every run, green or not. A bank whose
        # accepted gaps are invisible reports a flattering number: the point of
        # writing a gap down is that somebody keeps seeing it.
        if n_surv:
            print("%d of the %d banked rule(s) ha%s NO case that catches them. They are "
                  "recorded with a reason, not fixed."
                  % (n_surv, len(mutants), "s" if n_surv == 1 else "ve"))
        print("NOT SCANNED: every gate rule that is not in the bank. This gate "
              "measures the entries it carries and says nothing about the rest.")
        if n_un:
            return 2
        return 1 if n_fail else 0
    finally:
        shutil.rmtree(base, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
