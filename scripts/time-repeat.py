#!/usr/bin/env python3
"""Time a command more than once, and print the spread instead of a number.

WHY THIS IS IN THE REPOSITORY.

Every wall-clock figure this project has published was a single run: "the battery
suite went 364.7 s to 141.5 s", "the sweep takes 2695 s", "140.4 s per mutant".
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


def run_once(argv, cwd, env):
    t0 = time.monotonic()
    p = subprocess.run(argv, cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    return time.monotonic() - t0, p.returncode, p.stderr.decode("utf-8", "replace")


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

    cwd = a.cwd or os.getcwd()
    if not os.path.isdir(cwd):
        print("COULD NOT MEASURE: no directory %s" % cwd, file=sys.stderr)
        return UNMEASURABLE

    env = dict(os.environ)
    label = a.label or " ".join(shlex.quote(c) for c in cmd)
    print("=== %s ===" % label)
    print("   %d warm-up + %d timed run(s) of: %s" %
          (a.warmup, a.runs, " ".join(shlex.quote(c) for c in cmd)))

    for i in range(a.warmup):
        dt, rc, err = run_once(cmd, cwd, env)
        if rc != 0:
            print("\nCOULD NOT MEASURE: warm-up %d exited %d. A command that fails "
                  "is not a slow command.\n%s" % (i + 1, rc, err.strip()[:800]),
                  file=sys.stderr)
            return UNMEASURABLE
        print("   warm-up %d: %.1f s (dropped, on purpose, and said so)" % (i + 1, dt))

    samples = []
    for i in range(a.runs):
        dt, rc, err = run_once(cmd, cwd, env)
        if rc != 0:
            print("\nCOULD NOT MEASURE: run %d exited %d. A command that fails is "
                  "not a slow command.\n%s" % (i + 1, rc, err.strip()[:800]),
                  file=sys.stderr)
            return UNMEASURABLE
        samples.append(dt)
        print("   run %d: %.1f s" % (i + 1, dt))

    med = statistics.median(samples)
    sp = spread_pct(samples)
    print("\n%s: median %.1f s, range %.1f-%.1f s over %d run(s)"
          % (label, med, min(samples), max(samples), len(samples)))
    if sp is None:
        # Everything landed on zero: the command is faster than the clock can see.
        print("the range is 0 s because every run was too fast to time; quote it "
              "as 'under the resolution of this instrument', not as a number")
        return MEASURED
    print("spread %.0f%% of the median. %s" % (
        sp,
        "Quote the median." if sp < 10 else
        "Quote the range, not the median - a change smaller than this is noise."))

    if a.max_spread is not None and sp > a.max_spread:
        print("\nOUTSIDE THE LIMIT: spread %.0f%% is over the %.0f%% asked for. "
              "This box is too noisy right now for the median to mean anything."
              % (sp, a.max_spread))
        return OUT_OF_LIMIT
    return MEASURED


if __name__ == "__main__":
    sys.exit(main())
