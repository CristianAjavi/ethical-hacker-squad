#!/usr/bin/env python3
"""Silence one report at a time and see whether any battery case notices.

WHY THIS IS IN THE REPOSITORY AND NOT IN SOMEBODY'S SCRATCH DIRECTORY
    The question a battery cannot ask itself is whether it is green for the
    reason it claims. This asks it mechanically: take a gate library, find every
    statement that RECORDS a problem, neuter exactly one of them, and run that
    library's battery. If the battery is still green, the rule behind that line
    has no coverage - the case that appears to test it is passing some other way.

    That sweep has been written three times, in three sessions, in three
    throwaway scripts. Each time it found real holes and each time it died with
    the session, so the repository kept the FINDINGS and never the INSTRUMENT.
    A rule added to a library tomorrow is uncovered in exactly the same way and
    nothing would look.

THE OPERATOR IS DELIBERATELY NARROW
    Flipping comparisons or negating conditions produces mutants that crash, and
    a crash is caught by anything - it scores as coverage the battery does not
    have. A silenced report changes nothing except the verdict, which is
    precisely what a battery is for.

    Statement spans come from `ast`, not from a regex: `findings.append(`
    routinely opens a call that closes three lines later, and replacing only its
    first line produces a syntax error - another mutant killed by the parser.

WHAT IT REFUSES TO GUESS
    A library whose battery cannot be resolved is NOT skipped quietly. The first
    version of this sweep looked only for `gate-<lib>.selftest.sh` and silently
    passed over six of sixteen libraries that prove themselves through
    `gate-<lib>.sh --self-test` instead. Its "24 survivors" was never a statement
    about this repository; it was a statement about ten sixteenths of it, and
    nothing said which ten. Here an unresolvable library is reported and forces
    exit code 2.

ANCHORS, BECAUSE LINE NUMBERS MOVE
    A survivor is recorded as `library::qualified.function#ordinal`, the ordinal
    counting report sites inside that function. Editing an unrelated part of the
    file does not move it; renaming the function does, and that is correct -
    the acceptance was granted to a rule that no longer has that name.

EXIT CODES
    0  measured, every surviving report site is on the accepted list
    1  measured, a report site can be silenced and no battery notices
    2  COULD NOT MEASURE, which is never a pass
"""
from __future__ import annotations

import argparse
import ast
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time

DEFAULT_JOBS = 4
BATTERY_TIMEOUT = 600
# The clones stop before they discover the ceiling the hard way. The floor was a
# flat 3 GiB checked against the whole machine, and that is not a measure of
# anything this run does: `run_mutant` deletes each clone in its `finally`, so
# the most a sweep holds at once is `jobs` copies of the tree. Measured on this
# repository the peak a run can reach is 56 MiB against a 3072 MiB demand - 55x.
# The consequence was not theoretical. Inside `run-batteries.sh` the refusal
# bank sweeps toy trees of a few KB, and it came back COULD NOT MEASURE on a
# machine with 4.6 GiB free because some other battery's temporary files had
# taken the machine under a floor that had nothing to do with the job in front
# of it. A guard that refuses work 55x smaller than its own threshold is not
# protecting the disk; it is manufacturing NOT MEASURED, and a NOT MEASURED that
# arrives for the wrong reason is the instrument lying.
FREE_FLOOR_MULTIPLE = 8
FREE_FLOOR_MIN_BYTES = 256 * 1024 ** 2


def tree_bytes(root: pathlib.Path) -> int:
    """Apparent size of the tree about to be cloned, in bytes."""
    total = 0
    for base, _dirs, names in os.walk(str(root)):
        for n in names:
            try:
                total += os.lstat(os.path.join(base, n)).st_size
            except OSError:
                pass
    return total


def free_floor_bytes(size: int, jobs: int) -> int:
    """Room to demand before cloning: what this run can hold, with margin.

    Deliberately NOT capped at the top. Sweeping a tree big enough to want more
    than the old 3 GiB is exactly the case where the old constant was too small,
    and the reason it was too small is the same reason it was too large here: it
    never looked at the tree.
    """
    floor = max(FREE_FLOOR_MIN_BYTES, size * max(1, jobs) * FREE_FLOOR_MULTIPLE)
    # A knob that can only make the floor STRICTER, never weaker. The abort below
    # is unreachable on a machine that has room, and the first attempt to reach
    # it - a tree and a job count whose product no machine here could meet - was
    # green on this laptop and red on the runner, which has 65 GiB free. That is
    # the same defect this floor was just fixed for, one level up: a verdict that
    # depends on the machine it runs on. `max` is the whole safety argument;
    # raising a threshold cannot be abused into disabling it.
    raise_to = os.environ.get("EHS_SWEEP_MIN_FREE_MIB")
    if raise_to:
        floor = max(floor, int(raise_to) * 1024 ** 2)
    return floor
# Receivers that carry a printed count, not a failure. Silencing one of these
# changes what a run prints and not what it concludes, so a green battery over it
# is not evidence of anything missing.
INFORMATIONAL = {"info", "notes", "note", "summary"}
# A battery names the case it failed on: `FAILED <case>` or `HARNESS <case>`.
# `FAIL <text>` is something else entirely - it is lib/common.sh's gate_fail,
# the GATE's own verdict line - and accepting it made the first word of any
# failure message look like a case name. That is the instrument lying upward:
# it turned "the gate refused" into "a case caught it" and scored the mutant as
# covered. Proved in the negative by two cases in the battery.
FAILED_CASE = re.compile(r"^\s*(?:FAILED|HARNESS)\s+(\S+)")


# --------------------------------------------------------------------------- #
# Finding the report sites
# --------------------------------------------------------------------------- #

def report_sites(path: pathlib.Path):
    """Every statement that records a problem, with a stable anchor.

    Returns dicts with lo/hi (1-based inclusive line span), indent, receiver,
    the source text of the first line, and `anchor`.
    """
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    tree = ast.parse(text)

    # Qualified name of the function each node sits in.
    owner: dict[int, str] = {}

    def walk(node, prefix):
        for child in ast.iter_child_nodes(node):
            if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                name = prefix + child.name
                owner[id(child)] = name
                walk(child, name + ".")
            else:
                owner[id(child)] = prefix[:-1] if prefix else "<module>"
                walk(child, prefix)

    walk(tree, "")

    def enclosing(node):
        # Climb by line containment: cheaper and steadier than a parent map for
        # the one thing we need, which is "which def am I inside".
        best, best_span = "<module>", None
        for cand in ast.walk(tree):
            if not isinstance(cand, (ast.FunctionDef, ast.AsyncFunctionDef)):
                continue
            if cand.lineno <= node.lineno and node.lineno <= (cand.end_lineno or cand.lineno):
                span = (cand.end_lineno or cand.lineno) - cand.lineno
                if best_span is None or span < best_span:
                    best, best_span = owner.get(id(cand), cand.name), span
        return best

    found = []
    for node in ast.walk(tree):
        if not (isinstance(node, ast.Expr) and isinstance(node.value, ast.Call)
                and isinstance(node.value.func, ast.Attribute)
                and node.value.func.attr == "append"):
            continue
        recv = node.value.func.value
        name = recv.id if isinstance(recv, ast.Name) else (
            recv.attr if isinstance(recv, ast.Attribute) else "?")
        if name in INFORMATIONAL:
            continue
        first = lines[node.lineno - 1]
        found.append({
            "lo": node.lineno,
            "hi": node.end_lineno or node.lineno,
            "indent": len(first) - len(first.lstrip()),
            "receiver": name,
            "stmt": first.strip()[:96],
            "func": enclosing(node),
        })

    found.sort(key=lambda s: s["lo"])
    per_func: dict[str, int] = {}
    for s in found:
        n = per_func.get(s["func"], 0)
        per_func[s["func"]] = n + 1
        s["anchor"] = "%s::%s#%d" % (path.name, s["func"], n)
    return found


# --------------------------------------------------------------------------- #
# Finding the battery that is supposed to cover a library
# --------------------------------------------------------------------------- #

def resolve_battery(gates_dir: pathlib.Path, lib: pathlib.Path):
    """(argv, how) for the battery that proves `lib`, or (None, why not).

    Three ways a library is proved in this repository, and the sweep has to know
    all three or its denominator is a fiction:
      1. a sibling `gate-<lib>.selftest.sh`
      2. `gate-<lib>.sh --self-test`, the inline form
      3. neither, because the library is a FIXTURE consumed by another gate -
         then that gate's battery is the one that covers it
    """
    stem = lib.stem.replace("_", "-")
    sibling = gates_dir / ("gate-%s.selftest.sh" % stem)
    if sibling.exists():
        return [str(sibling)], "sibling battery %s" % sibling.name

    gate = gates_dir / ("gate-%s.sh" % stem)
    if gate.exists():
        if "--self-test" in gate.read_text(encoding="utf-8", errors="replace"):
            return [str(gate), "--self-test"], "inline self-test of %s" % gate.name
        return None, "%s exists but accepts no --self-test" % gate.name

    # A fixture: find the gate that names it.
    named_by = []
    for cand in sorted(gates_dir.glob("gate-*.sh")):
        if cand.name.endswith(".selftest.sh"):
            continue
        if lib.stem in cand.read_text(encoding="utf-8", errors="replace"):
            named_by.append(cand)
    if len(named_by) == 1:
        argv, how = resolve_battery(gates_dir, pathlib.Path(
            named_by[0].name.replace("gate-", "").replace("-", "_").replace(".sh", ".py")))
        if argv:
            return argv, "fixture of %s, covered by its %s" % (named_by[0].name, how)
        return None, "fixture of %s, whose own battery is unresolvable" % named_by[0].name
    if not named_by:
        return None, "no gate names this module"
    return None, "named by %d gates, so its battery is ambiguous" % len(named_by)


# --------------------------------------------------------------------------- #
# Running one mutant
# --------------------------------------------------------------------------- #

def free_bytes(p: pathlib.Path) -> int:
    st = os.statvfs(str(p))
    return st.f_bavail * st.f_frsize


def failed_cases(text: str):
    return sorted({m.group(1) for m in
                   (FAILED_CASE.match(l) for l in text.splitlines()) if m})


def clone(pristine: pathlib.Path, dest: pathlib.Path) -> None:
    dest.mkdir(parents=True)
    r = subprocess.run(["cp", "-Rc", "%s/." % pristine, str(dest)],
                       capture_output=True)
    if r.returncode != 0:                       # no clonefile on this filesystem
        subprocess.run(["cp", "-R", "%s/." % pristine, str(dest)], check=True)


def run_mutant(pristine, base, lib_name, battery_argv, site, idx, log):
    work = base / ("m%04d" % idx)
    clone(pristine, work)
    try:
        target = work / "scripts/gates/lib" / lib_name
        lines = target.read_text(encoding="utf-8").splitlines()
        lines[site["lo"] - 1:site["hi"]] = [" " * site["indent"] + "pass  # MUTANT"]
        target.write_text("\n".join(lines) + "\n", encoding="utf-8")

        argv = [a.replace(str(pristine), str(work)) for a in battery_argv]
        t0 = time.time()
        p = subprocess.run(["bash"] + argv, cwd=str(work),
                           stdin=subprocess.DEVNULL, capture_output=True, text=True,
                           env={**os.environ, "EHS_REPO_ROOT": str(work)},
                           timeout=BATTERY_TIMEOUT)
        secs = time.time() - t0
        red = failed_cases(p.stdout + p.stderr)
        survived = p.returncode == 0
        # A mutant that turns the battery red with NO case naming it was not
        # caught by a case; it was caught by a crash, and this file's own header
        # says a crash is caught by anything. `red` was being recorded and never
        # read, so every such death has been scoring as coverage the battery
        # does not have - the exact defect the sweep exists to find, inside the
        # sweep.
        crash_only = (not survived) and not red
        log("%-26s %-42s %-5s %5.1fs  %s"
            % (lib_name, site["anchor"][-42:], "rc %d" % p.returncode, secs,
               "SURVIVES <- " + site["stmt"][:44] if survived
               else "CRASH-ONLY, no case named it <- " + site["stmt"][:32]
               if crash_only else "dies by: " + ", ".join(red[:2])))
        return dict(lib=lib_name, anchor=site["anchor"], line=site["lo"],
                    receiver=site["receiver"], stmt=site["stmt"],
                    rc=p.returncode, caught_by=red, survived=survived,
                    crash_only=crash_only)
    finally:
        subprocess.run(["/bin/rm", "-rf", str(work)])


# --------------------------------------------------------------------------- #
# The sweep
# --------------------------------------------------------------------------- #

class Unmeasurable(Exception):
    pass


def build_plan(root: pathlib.Path, only=None, out=lambda _m: None):
    """(plan, unresolved) for a tree, without running anything.

    Split out of the sweep because the SHARDED run needs it twice: once per
    shard to know what to mutate, and once at the end to check the shards
    between them covered every report site the tree has. Without that second
    check a library nobody put in the matrix is skipped in silence - which is
    the precise defect this whole control exists to stop.
    """
    gates = root / "scripts/gates"
    libdir = gates / "lib"
    if not libdir.is_dir():
        raise Unmeasurable("%s has no scripts/gates/lib" % root)

    libs = sorted(p for p in libdir.glob("*.py") if p.name != "coverage_sweep.py")
    if only:
        libs = [p for p in libs if p.name in set(only)]
    if not libs:
        raise Unmeasurable("no gate library matched the selection")

    plan, unresolved = [], []
    for lib in libs:
        argv, how = resolve_battery(gates, lib)
        if argv is None:
            unresolved.append((lib.name, how))
            continue
        sites = report_sites(lib)
        # Name the instrument. A sweep that does not say which battery it ran
        # against a library cannot be checked by anybody reading its output, and
        # resolving the battery is the exact step three earlier versions of this
        # got wrong without saying a word.
        out("%-32s %2d site(s) via %s" % (lib.name, len(sites), how))
        for site in sites:
            plan.append((lib.name, argv, site))
    return plan, unresolved


def sweep(root: pathlib.Path, only=None, jobs=DEFAULT_JOBS, accepted=None,
          out=print):
    plan, unresolved = build_plan(root, only=only, out=out)

    for name, why in unresolved:
        out("NOT MEASURED  %-30s %s" % (name, why))
    out("%d report site(s) across %d library(ies); %d library(ies) unmeasurable"
        % (len(plan), len({p[0] for p in plan}), len(unresolved)))
    if not plan:
        raise Unmeasurable("no report site could be swept")

    base = pathlib.Path(tempfile.mkdtemp(prefix="ehs-sweep-"))
    pristine = base / "pristine"
    try:
        pristine.mkdir(parents=True)
        subprocess.run(
            "(cd %s && tar --exclude .git --exclude __pycache__ --exclude node_modules "
            "-cf - .) | (cd %s && tar -xf -)" % (root, pristine),
            shell=True, check=True)

        size = tree_bytes(pristine)
        floor = free_floor_bytes(size, jobs)
        out("disk floor: %d MiB applied (%d job(s) x %.1f KiB of tree x %d = "
            "%.1f MiB, never under %d MiB)"
            % (floor / 2 ** 20, max(1, jobs), size / 1024, FREE_FLOOR_MULTIPLE,
               size * max(1, jobs) * FREE_FLOOR_MULTIPLE / 2 ** 20,
               FREE_FLOOR_MIN_BYTES / 2 ** 20))

        # A battery that is already red says nothing about a mutant. Refuse before
        # spending an hour producing verdicts that mean nothing.
        for argv in sorted({tuple(a for a in p[1]) for p in plan}):
            argv = [a.replace(str(root), str(pristine)) for a in argv]
            p = subprocess.run(["bash"] + argv, cwd=str(pristine),
                               stdin=subprocess.DEVNULL, capture_output=True,
                               text=True,
                               env={**os.environ, "EHS_REPO_ROOT": str(pristine)},
                               timeout=BATTERY_TIMEOUT)
            if p.returncode != 0:
                raise Unmeasurable(
                    "%s is already rc %d with nothing mutated, so no verdict from it "
                    "would mean anything" % (pathlib.Path(argv[0]).name, p.returncode))
        out("baseline: %d battery invocation(s) green before any mutation"
            % len({tuple(p[1]) for p in plan}))

        results, queue = [], list(enumerate(plan))
        lock, qlock = threading.Lock(), threading.Lock()
        aborted = []

        def log(msg):
            with lock:
                out(msg)

        def worker():
            while True:
                with qlock:
                    if not queue or aborted:
                        return
                    if free_bytes(base) < floor:
                        aborted.append("free disk fell below %d MiB with %d "
                                       "mutant(s) unrun"
                                       % (floor / 2 ** 20, len(queue)))
                        queue.clear()
                        return
                    idx, (lib_name, argv, site) = queue.pop(0)
                argv = [a.replace(str(root), str(pristine)) for a in argv]
                try:
                    r = run_mutant(pristine, base, lib_name, argv, site, idx, log)
                except Exception as exc:                      # noqa: BLE001
                    r = dict(lib=lib_name, anchor=site["anchor"], line=site["lo"],
                             receiver=site["receiver"], stmt=site["stmt"], rc=-1,
                             caught_by=[], survived=None, crash_only=False,
                             error=str(exc)[:120])
                    log("%-26s %-42s ERROR %s"
                        % (lib_name, site["anchor"][-42:], str(exc)[:60]))
                with lock:
                    results.append(r)

        threads = [threading.Thread(target=worker) for _ in range(max(1, jobs))]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        if aborted:
            raise Unmeasurable(aborted[0])
    finally:
        shutil.rmtree(base, ignore_errors=True)

    errors = [r for r in results if r["survived"] is None]
    if errors:
        raise Unmeasurable("%d mutant(s) neither survived nor died: %s"
                           % (len(errors), errors[0].get("error", "?")))
    return results, unresolved


# --------------------------------------------------------------------------- #
# The verdict
# --------------------------------------------------------------------------- #

def load_accepted(path: pathlib.Path):
    if path is None or not path.exists():
        return {}, {}
    data = json.loads(path.read_text(encoding="utf-8"))
    return ({e["anchor"]: e for e in data.get("accepted", [])},
            {e["battery"]: e for e in data.get("detector_unproven", [])})


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=None,
                    help="repository to sweep (default: the one this file is in)")
    ap.add_argument("--only", action="append", default=None,
                    help="library file name; repeatable")
    ap.add_argument("--jobs", type=int, default=DEFAULT_JOBS)
    ap.add_argument("--accepted", default=None,
                    help="JSON of survivors already accounted for")
    ap.add_argument("--json", dest="json_out", default=None,
                    help="write the raw per-mutant result here")
    ap.add_argument("--verdict-from", nargs="+", default=None, metavar="JSON",
                    help="render ONE verdict over per-mutant results already "
                         "measured, instead of sweeping. This is how a run "
                         "sharded by library reaches a single answer: without "
                         "it every shard judges its own survivors against the "
                         "whole acceptance file and fails over the other "
                         "shards' entries.")
    ap.add_argument("--list-libraries", action="store_true",
                    help="print the libraries with report sites, one per line, "
                         "and exit. The CI matrix is built from this rather "
                         "than from a hand-written list that would go stale.")
    args = ap.parse_args(argv)

    here = pathlib.Path(__file__).resolve()
    root = pathlib.Path(args.root).resolve() if args.root else here.parents[3]
    accepted_path = (pathlib.Path(args.accepted) if args.accepted
                     else root / "scripts/gates/data/coverage-sweep-accepted.json")

    t0 = time.time()

    if args.list_libraries:
        try:
            plan, unresolved = build_plan(root, only=args.only)
        except Unmeasurable as exc:
            print("COULD NOT MEASURE: %s" % exc, file=sys.stderr)
            return 2
        if unresolved:
            for name, why in unresolved:
                print("COULD NOT MEASURE: %s: %s" % (name, why), file=sys.stderr)
            return 2
        seen = []
        for lib_name, _argv, _site in plan:
            if lib_name not in seen:
                seen.append(lib_name)
                print(lib_name)
        return 0

    if args.verdict_from:
        print("=== coverage sweep verdict over %d shard(s) ==="
              % len(args.verdict_from))
        results, unresolved, seen = [], [], set()
        for f in args.verdict_from:
            try:
                part = json.loads(pathlib.Path(f).read_text(encoding="utf-8"))
            except Exception as exc:                           # noqa: BLE001
                print("COULD NOT MEASURE: shard %s is unreadable: %s" % (f, exc))
                return 2
            if not isinstance(part, list) or not part:
                print("COULD NOT MEASURE: shard %s carries no result, and an "
                      "absent shard is not a clean one" % f)
                return 2
            for r in part:
                if r.get("anchor") in seen:
                    print("COULD NOT MEASURE: %s appears in two shards, so they "
                          "overlap and the tally would double-count it"
                          % r.get("anchor"))
                    return 2
                seen.add(r.get("anchor"))
            results.extend(part)
            print("   %-52s %3d mutant(s)" % (f, len(part)))

        # The shards between them have to cover the tree. A library nobody put
        # in the matrix would otherwise be skipped in silence - which is the
        # exact defect this control exists to stop, walking back in through the
        # workflow instead of through the resolver.
        try:
            plan, unresolved = build_plan(root)
        except Unmeasurable as exc:
            print("COULD NOT MEASURE: %s" % exc)
            return 2
        want = {site["anchor"] for _lib, _argv, site in plan}
        missing = sorted(want - seen)
        if missing:
            print("\nCOULD NOT MEASURE: %d report site(s) are in the tree and in "
                  "no shard. A sweep with a gap in it is not a clean sweep:"
                  % len(missing))
            for a in missing[:20]:
                print("   %s" % a)
            return 2
        print("   shards cover %d of %d report site(s) in the tree"
              % (len(want), len(want)))
    else:
        print("=== coverage sweep: %s ===" % root)
        try:
            results, unresolved = sweep(root, only=args.only, jobs=args.jobs)
        except Unmeasurable as exc:
            print("COULD NOT MEASURE: %s" % exc)
            return 2
        except Exception as exc:                               # noqa: BLE001
            print("COULD NOT MEASURE: the sweep itself failed: %s" % exc)
            return 2

    if args.json_out:
        pathlib.Path(args.json_out).write_text(
            json.dumps(results, indent=1) + "\n", encoding="utf-8")

    accepted, unproven_on_file = load_accepted(accepted_path)
    survivors = [r for r in results if r["survived"]]
    live_anchors = {r["anchor"] for r in results}

    # Absence of a case name is only evidence where a name has been SEEN. A
    # battery this sweep never watched name a failing case has an unproven
    # detector, and calling its silence a hole would be a zero from a blind
    # instrument. Those subjects are declared by name in the acceptance file,
    # on the same ratchet as the survivors: listed, or the sweep exits 2.
    proven = {r["lib"] for r in results if r.get("caught_by")}
    all_crash = [r for r in results if r.get("crash_only")]
    blind = sorted({r["lib"] for r in all_crash if r["lib"] not in proven})
    crash_only = [r for r in all_crash if r["lib"] in proven]

    unaccounted = [r for r in survivors + crash_only
                   if r["anchor"] not in accepted]
    stale = sorted(a for a in accepted if a not in live_anchors)
    stale_unproven = sorted(b for b in unproven_on_file if b not in blind
                            and b in {r["lib"] for r in results})

    n_open = sum(1 for e in accepted.values() if e.get("kind") == "open")
    print("\n%d mutant(s) in %.0f s · %d survive · %d die by a named case · "
          "%d die with no case naming them · %d on file "
          "(%d deliberate, %d open hole(s) waiting for a case)"
          % (len(results), time.time() - t0, len(survivors),
             len(results) - len(survivors) - len(all_crash), len(all_crash),
             len(accepted), len(accepted) - n_open, n_open))
    if blind:
        print("   %d battery(ies) were never watched name a failing case, so "
              "their silence measures nothing: %s"
              % (len(blind), ", ".join(blind)))

    if unresolved:
        print("\nCOULD NOT MEASURE %d library(ies); a denominator with a hole in it "
              "is not a denominator:" % len(unresolved))
        for name, why in unresolved:
            print("   %-30s %s" % (name, why))
        return 2

    undeclared_blind = [b for b in blind if b not in unproven_on_file]
    if undeclared_blind:
        print("\nCOULD NOT MEASURE  %d battery(ies) turn red over a mutant without "
              "ever naming the case that did it, and this sweep has never seen "
              "them name one. Whether a case caught the mutant is unknown, not "
              "no:" % len(undeclared_blind))
        for b in undeclared_blind:
            print("   %s" % b)
        print("\n  Give the battery a line the sweep can read (FAILED <case>), or "
              "declare it under detector_unproven in %s with why."
              % accepted_path.name)
        return 2

    if stale_unproven:
        print("\nFAIL  %d battery(ies) are on file as unable to name a failing case "
              "and this run watched them name one. Delete the entry:"
              % len(stale_unproven))
        for b in stale_unproven:
            print("   %s" % b)
        return 1

    if stale:
        print("\nFAIL  %d acceptance(s) name a report site that no longer exists. "
              "The reason was written for a rule that has moved or gone:" % len(stale))
        for a in stale:
            print("   %s" % a)
        return 1

    if unaccounted:
        print("\nFAIL  %d report site(s) can be silenced and no case notices:"
              % len(unaccounted))
        for r in sorted(unaccounted, key=lambda x: x["anchor"]):
            print("   %-46s %-9s %s"
                  % (r["anchor"], "CRASH" if r.get("crash_only") else "survives",
                     r["stmt"]))
        print("\n  A survivor is a rule no case exercises. A CRASH is a rule whose "
              "case does not fail over it either - the battery went red because "
              "the mutant broke something, which any mutant would. Write the "
              "case, or record it in %s with why." % accepted_path.name)
        return 1

    print("\nOK    every surviving report site is accounted for, and every "
          "death is named by a case or declared")
    return 0


if __name__ == "__main__":
    sys.exit(main())
