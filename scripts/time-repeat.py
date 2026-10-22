#!/usr/bin/env python3
"""Time a command more than once, and print the spread instead of a number.

WHY THIS IS IN THE REPOSITORY.

Wall-clock figures were being published off a single run: "the sweep takes
2695 s", "140.4 s per mutant". (Not all of them - "the battery suite went 364.7 s
to 141.5 s" was taken twice per arm, alternated, with ranges that do not overlap.
That one is under this bar but it is not blind, and the difference matters.)
Then the same battery, run three times back to back on a quiet machine with
nothing else changed, came back 30 s, 45 s, 38 s. A spread of 40% around the
median, which is larger than most of the improvements those figures were used to
claim. None of them carried an error bar, so none of them could be told apart
from noise, and at least one conclusion drawn from them - "the Mac is 9.5x slower
than the runner" - was inflated by whatever the box happened to be doing during
the one run that got measured.

A single timing is not a measurement. It is one sample from a distribution nobody
looked at. This prints the distribution.

WHAT IT REFUSES TO DO.

  - It never prints one number without the range it came from.
  - A run that FAILS is not a slow run: you cannot time work that did not happen.
    Any non-zero exit from the command makes the whole thing exit 2, NOT MEASURED.
  - `--max-spread` is the only way to get a pass/fail out of it, and it judges the
    SPREAD, not the speed: a box too noisy to measure on says so instead of
    handing back a median that means nothing.
  - It does not silently drop a warm-up run. If you want one, ask for it with
    `--warmup`, and the output says it was dropped and what it cost.

Exit codes follow scripts/gates/lib/common.sh: 0 measured, 1 measured and outside
a declared limit, 2 COULD NOT MEASURE, which is never a pass.
"""

from __future__ import annotations

import argparse
import os
import shlex
import statistics
import subprocess
import sys
import time

MEASURED, OUT_OF_LIMIT, UNMEASURABLE = 0, 1, 2


def run_once(argv, cwd, env, contenders=0):
    """One timed execution, optionally with N copies of the same command running
    alongside it.

    The contenders are never killed. A battery cut down with SIGKILL leaves its
    temporary trees behind - this repository has already lost 62,510 files that
    way - so the measured run finishes, then we WAIT for the others and check
    that they succeeded too. A contender that died is not contention: it is a
    box that could not do the work, and the run it shadowed measured nothing.

    They are the same command on purpose. Contention against some other load
    would measure that load; contention against itself is the condition a
    four-worker sweep actually puts each mutant in."""
    side = [subprocess.Popen(argv, cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            for _ in range(contenders)]
    t0 = time.monotonic()
    p = subprocess.run(argv, cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    dt = time.monotonic() - t0
    rc, err = p.returncode, p.stderr.decode("utf-8", "replace")
    for q in side:
        q.wait()
        if q.returncode != 0 and rc == 0:
            rc = q.returncode
            err = ("a contender exited %d. The box could not run %d copies of "
                   "this command at once, so the run beside them is not a "
                   "measurement of anything." % (q.returncode, contenders + 1))
    return dt, rc, err


def spread_pct(samples):
    """Full range as a percentage of the median - the number that says whether
    the median is worth quoting. Half-widths and standard deviations both hide
    a single ugly outlier; the range does not."""
    med = statistics.median(samples)
    if med <= 0:
        return None
    return 100.0 * (max(samples) - min(samples)) / med


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Run a command N times and report the spread, not a number.")
    ap.add_argument("--runs", type=int, default=5,
                    help="how many timed runs (default 5; 1 is refused)")
    ap.add_argument("--warmup", type=int, default=0,
                    help="untimed runs first; they are reported, never hidden")
    ap.add_argument("--label", default="",
                    help="what is being timed, for the output")
    ap.add_argument("--cwd", default=None)
    ap.add_argument("--against", default=None,
                    help="a second command, run ALTERNATELY with the first; the "
                         "verdict is whether their ranges overlap")
    ap.add_argument("--against-label", default="",
                    help="what the second command is, for the output")
    ap.add_argument("--contenders", type=int, default=0,
                    help="run N extra copies of the same command alongside each "
                         "timed run; they are waited for, never killed")
    ap.add_argument("--max-spread", type=float, default=None,
                    help="exit 1 if the range exceeds this %% of the median")
    ap.add_argument("command", nargs=argparse.REMAINDER,
                    help="the command, after --")
    a = ap.parse_args(argv)

    cmd = [c for c in a.command if c != "--"] if a.command else []
    if not cmd:
        print("COULD NOT MEASURE: no command given", file=sys.stderr)
        return UNMEASURABLE
    if a.runs < 2:
        # The whole point. One sample cannot show a spread, and a figure with no
        # spread beside it is exactly what this script exists to stop shipping.
        print("COULD NOT MEASURE: --runs %d cannot show a spread; use 2 or more"
              % a.runs, file=sys.stderr)
        return UNMEASURABLE
    if a.warmup < 0:
        print("COULD NOT MEASURE: --warmup cannot be negative", file=sys.stderr)
        return UNMEASURABLE
    if a.contenders < 0:
        print("COULD NOT MEASURE: --contenders cannot be negative", file=sys.stderr)
        return UNMEASURABLE

    other = shlex.split(a.against) if a.against else None
    if a.against is not None and not other:
        print("COULD NOT MEASURE: --against was given nothing to run",
              file=sys.stderr)
        return UNMEASURABLE

    cwd = a.cwd or os.getcwd()
    if not os.path.isdir(cwd):
        print("COULD NOT MEASURE: no directory %s" % cwd, file=sys.stderr)
        return UNMEASURABLE

    env = dict(os.environ)
    label = a.label or " ".join(shlex.quote(c) for c in cmd)
    load = ("" if a.contenders <= 0 else
            " under %d-way contention" % (a.contenders + 1))
    print("=== %s ===" % label)
    print("   %d warm-up + %d timed run(s)%s of: %s" %
          (a.warmup, a.runs,
           "" if not load else " with %d copies at once" % (a.contenders + 1),
           " ".join(shlex.quote(c) for c in cmd)))
    if other:
        print("   alternating, run for run, against: %s"
              % " ".join(shlex.quote(c) for c in other))

    for i in range(a.warmup):
        dt, rc, err = run_once(cmd, cwd, env, a.contenders)
        if rc != 0:
            print("\nCOULD NOT MEASURE: warm-up %d exited %d. A command that fails "
                  "is not a slow command.\n%s" % (i + 1, rc, err.strip()[:800]),
                  file=sys.stderr)
            return UNMEASURABLE
        print("   warm-up %d: %.1f s (dropped, on purpose, and said so)" % (i + 1, dt))

    samples, others = [], []
    for i in range(a.runs):
        for arm, argv, bucket in (("A", cmd, samples),
                                  ("B", other, others)):
            if argv is None:
                continue
            dt, rc, err = run_once(argv, cwd, env, a.contenders)
            if rc != 0:
                print("\nCOULD NOT MEASURE: run %d%s exited %d. A command that "
                      "fails is not a slow command.\n%s"
                      % (i + 1, "" if other is None else " (arm %s)" % arm,
                         rc, err.strip()[:800]), file=sys.stderr)
                return UNMEASURABLE
            bucket.append(dt)
            print("   run %d%s: %.1f s"
                  % (i + 1, "" if other is None else " %s" % arm, dt))

    def report(name, xs):
        m = statistics.median(xs)
        s_ = spread_pct(xs)
        print("\n%s%s: median %.1f s, range %.1f-%.1f s over %d run(s)"
              % (name, load, m, min(xs), max(xs), len(xs)))
        if s_ is None:
            # Everything landed on zero: faster than the clock can see.
            print("the range is 0 s because every run was too fast to time; quote "
                  "it as 'under the resolution of this instrument', not a number")
        else:
            print("spread %.0f%% of the median. %s" % (
                s_,
                "Quote the median." if s_ < 10 else
                "Quote the range, not the median - a change smaller than this "
                "is noise."))
        return s_

    sp = report(label, samples)
    if other:
        report(a.against_label or " ".join(shlex.quote(c) for c in other), others)
        # The verdict, and the only reason --against exists. Two medians can sit
        # far apart and still be the same machine on two afternoons; two ranges
        # that do not touch cannot.
        if max(samples) < min(others) or max(others) < min(samples):
            print("\nThe two ranges do not overlap. That is a difference between "
                  "the commands, not the box under them.")
        else:
            print("\nThe two ranges OVERLAP. Whatever separates these medians is "
                  "not distinguishable from the box; do not publish it as a "
                  "change.")
    if sp is None:
        return MEASURED

    if a.max_spread is not None and sp > a.max_spread:
        print("\nOUTSIDE THE LIMIT: spread %.0f%% is over the %.0f%% asked for. "
              "This box is too noisy right now for the median to mean anything."
              % (sp, a.max_spread))
        return OUT_OF_LIMIT
    return MEASURED


if __name__ == "__main__":
    sys.exit(main())
