#!/usr/bin/env python3
"""Break gate-checks-ran.sh on purpose and see whether its battery notices.

A battery that has never been red is a claim, not a measurement. Every mutant
below removes exactly one decision from the gate or from the trigger reader,
and names the case that must die when it goes. A mutant nothing catches is a
case missing, and it is reported as a survivor rather than rounded away.

WHY IT LIVES HERE AND NOT UNDER scripts/gates/
    run-all.sh treats anything matching scripts/gates/gate-*.sh as a gate. This
    is not a gate: it is a proof about one. Its wrapper is
    scripts/checks-ran.mutants.selftest.sh, which run-batteries.sh picks up.

WHAT A MUTANT IS
    One or more literal substitutions in one file. Each `old` must appear
    EXACTLY once, or the mutant reports HARNESS rather than a verdict - a
    substitution that silently matched nothing, or matched twice, is the failure
    mode that makes a bank look green while testing nothing.

EXIT CODES
    0  every mutant was caught by the case that names it
    1  at least one survived, or a substitution did not apply
    2  could not run
"""
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor

ROOT = pathlib.Path(os.environ.get("EHS_REPO_ROOT", pathlib.Path(__file__).resolve().parent.parent))

GATE = "scripts/gates/gate-checks-ran.sh"
AWK = "scripts/gates/lib/workflow-triggers.awk"
BATTERY = "scripts/gates/gate-checks-ran.selftest.sh"
COMMON = "scripts/gates/lib/common.sh"

# Everything the battery needs to run against a mutated copy. It builds its own
# toy repository under its own temporary directory, so nothing else travels.
CARRY = [GATE, AWK, BATTERY, COMMON]

PER_MUTANT_TIMEOUT = 180
WORKERS = 6

# (name, file, old, new, the case that must die)
# `old` may be a list, and then `new` is a list of the same length: a protection
# that overlaps another cannot be mutated on its own, and pretending otherwise
# would count an untested line as proven.
MUTANTS = [
    ("names-are-matched-by-substring", GATE,
     'grep -qxF -- "$w" || missing=',
     'grep -qF -- "$w" || missing=',
     "a name that only contains the required one does not count"),

    ("the-missing-names-are-never-computed", GATE,
     '    if [ -z "$missing" ]; then',
     '    if true; then',
     "runs, but not the required one -> fails"),

    ("the-grace-window-only-covers-an-empty-list", GATE,
     '  if [ "$age_min" -lt "$GRACE_MIN" ]; then',
     '  if [ "$age_min" -lt "$GRACE_MIN" ] && [ "$runs" -eq 0 ]; then',
     "a fresh push missing a workflow is excluded, not accused"),

    ("the-two-silences-are-tallied-as-one", GATE,
     '  if [ "$runs" -gt 0 ]; then\n    n_missing=$((n_missing + 1))',
     '  if false; then\n    n_missing=$((n_missing + 1))',
     "and it does not call a full check list an empty one"),

    ("a-required-name-no-workflow-answers-to-is-tolerated", GATE,
     'if [ -n "$ghost" ]; then',
     'if false; then',
     "a required name no workflow answers to -> 2, not 24 accusations"),

    ("an-undeclared-pull-request-workflow-is-tolerated", GATE,
     'if [ -n "$undeclared" ]; then',
     'if false; then',
     "a pull_request workflow in neither list -> fails"),

    ("the-exemption-list-is-ignored", GATE,
     "  printf '%s\\n' \"$EXEMPT\"   | grep -qxF -- \"$wname\" && continue",
     "  : \"$EXEMPT\"",
     "an exempt workflow is not required and not a finding"),

    ("a-missing-declaration-is-tolerated", GATE,
     '[ -r "$DECL" ] || {\n  gate_warn "$DECL is missing',
     '[ 1 ] || {\n  gate_warn "$DECL is missing',
     "no declaration -> 2, never an empty requirement"),

    ("a-declaration-requiring-nothing-is-tolerated", GATE,
     '[ -n "$REQUIRED" ] || {',
     '[ 1 ] || {',
     "a declaration requiring nothing -> 2"),

    ("an-unreadable-trigger-block-is-read-as-no", GATE,
     'if [ -n "$puzzling" ]; then',
     'if false; then',
     "an unreadable on: block -> 2, not a silent no"),

    ("a-nameless-pull-request-workflow-is-tolerated", GATE,
     'if [ -n "$nameless" ]; then',
     'if false; then',
     "a pull_request workflow with no name: -> 2"),

    ("a-truncated-page-proves-an-absence", GATE,
     '    if [ "$runs" -gt 100 ]; then',
     '    if false; then',
     "over a page of runs and a name not seen -> 2"),

    ("the-page-limit-is-one-run", GATE,
     '    if [ "$runs" -gt 100 ]; then',
     '    if [ "$runs" -gt 0 ]; then',
     "runs, but not the required one -> fails"),

    ("a-deep-line-with-no-key-before-it-is-configuration", AWK,
     '} else if (line !~ /^    / || !saw_key) {',
     '} else if (line !~ /^    /) {',
     "an on: block indented oddly -> 2, not a silent no"),

    ("pull-request-target-counts-as-pull-request", AWK,
     'if (key == "pull_request") seen_pr = 1',
     'if (key ~ /^pull_request/) seen_pr = 1',
     "pull_request_target is not pull_request -> passes"),

    ("flow-style-is-not-noticed", AWK,
     '  if (rest != "" && rest !~ /^#/) puzzled = 1',
     '  if (rest != "" && rest !~ /^./) puzzled = 1',
     "an unreadable on: block -> 2, not a silent no"),
]

FAILED = re.compile(r"^\s*\[self-test FAIL\]\s+(.*?)\s{2,}", re.M)


def lab(tmp):
    """A copy of just the files the battery touches, mutated in place."""
    dest = pathlib.Path(tmp) / "repo"
    for rel in CARRY:
        target = dest / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, target)
    return dest


def dead(name, out):
    """Did the case that must die actually appear among the failures?"""
    return any(name in line for line in FAILED.findall(out))


def run_one(m):
    name, rel, old, new, expected = m
    pairs = list(zip(old, new)) if isinstance(old, list) else [(old, new)]
    with tempfile.TemporaryDirectory(prefix="ehs-cr-mut-") as tmp:
        repo = lab(tmp)
        target = repo / rel
        text = target.read_text(encoding="utf-8")
        for was, becomes in pairs:
            if text.count(was) != 1:
                return name, "HARNESS", (
                    "the substitution matched %d times in %s, not once"
                    % (text.count(was), rel))
            text = text.replace(was, becomes)
        target.write_text(text, encoding="utf-8")
        env = dict(os.environ)
        # The battery must be blind to whatever the caller is pointing at, or a
        # mutant's verdict would depend on the environment it inherited rather
        # than on the edit.
        for k in ("EHS_REPO_ROOT", "EHS_CHECKS_REPO", "EHS_CHECKS_GRACE_MIN"):
            env.pop(k, None)
        try:
            p = subprocess.run(["bash", str(repo / BATTERY)],
                               capture_output=True, text=True,
                               timeout=PER_MUTANT_TIMEOUT, env=env)
        except subprocess.TimeoutExpired:
            return name, "HARNESS", "the battery did not finish in %ds" % PER_MUTANT_TIMEOUT
        out = p.stdout + p.stderr
        if p.returncode == 2:
            return name, "HARNESS", "the battery could not run (rc 2)"
        if dead(name=expected, out=out):
            n = len(FAILED.findall(out))
            return name, "PASS", "%d case(s) died, including the one named" % n
        if p.returncode == 0:
            return name, "SURVIVES", "the battery stayed green: '%s' does not measure this" % expected
        return name, "SURVIVES", "the battery went red but never on '%s'" % expected


def main():
    for rel in CARRY:
        if not (ROOT / rel).is_file():
            print("  COULD NOT MEASURE: %s is missing" % rel)
            return 2
    started = time.time()
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        rows = list(pool.map(run_one, MUTANTS))
    for name, verdict, detail in rows:
        print("%-9s %-52s %s" % (verdict, name, detail))
    caught = sum(1 for _, v, _ in rows if v == "PASS")
    survived = sum(1 for _, v, _ in rows if v == "SURVIVES")
    broken = sum(1 for _, v, _ in rows if v == "HARNESS")
    print()
    print("%d mutant(s) in %d s · %d caught by a named case · %d survive · "
          "%d could not be run" % (len(rows), time.time() - started, caught, survived, broken))
    if survived or broken:
        print("FAIL  a decision nothing notices being removed is a decision nobody is testing")
        return 1
    print("OK    every decision in the gate and in the trigger reader has a case "
          "that notices when it is taken away")
    return 0


if __name__ == "__main__":
    sys.exit(main())
