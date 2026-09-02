#!/usr/bin/env python3
"""Measurement core for gate-lockfile-coherence.sh.

Prints one line per problem and returns 1 if it found any, 0 if it measured and
found none, 2 if it could not measure. The wrapper turns those into the gate's
verdict; the crash discriminator lives there, because a python3 that dies also
exits 1 and the two are indistinguishable from outside.

  FINDING <text>      measured, and it is wrong
  UNMEASURED <text>   could not measure - never a pass
  anything else       information
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

PKG_DIR = "tooling/claude-cli"
WORKFLOWS = ".github/workflows"

# An exact pin. A range ("^2.1.0", "~2.1", "*") needs a semver resolver this
# gate does not have, and guessing would be worse than saying so.
EXACT = re.compile(r"^\d+\.\d+\.\d+$")

# `  SOME_NAME: '1.2.3'` or `  SOME_NAME: "1.2.3"` at any indentation. Read as
# text on purpose: the repository has no yaml module on the gate path, and the
# question here is lexical - does a workflow carry a version literal at all.
ENV_LINE = re.compile(r"""^\s*([A-Za-z_][A-Za-z0-9_]*VERSION)\s*:\s*['"]?(\d+\.\d+\.\d+)['"]?\s*(?:#.*)?$""")


def normalise(env_name: str) -> str:
    """`CLAUDE_CODE_VERSION` -> `claude-code`, so it can be matched against a
    package name. Crude on purpose: the alternative is resolving what a shell
    variable refers to, which nothing static can do."""
    return env_name[: -len("_VERSION")].lower().replace("_", "-")


def names_a_package(stem: str, package: str) -> bool:
    """Does an env var stem refer to this locked package?

    Substring in one direction alone is not enough, and the gap is not
    hypothetical: `CLAUDE_CODE_VERSION` gives `claude-code`, which IS inside
    `@anthropic-ai/claude-code`, but renaming the variable to
    `ANTHROPIC_AI_CLAUDE_CODE_VERSION` gives a stem the package name does not
    contain - and the gate would have gone green on a rename. So the package's
    bare name has to be looked for inside the stem as well.
    """
    if not stem:
        return False
    bare = package.rsplit("/", 1)[-1]
    return stem in package or bare in stem


def main(root_s: str) -> int:
    root = pathlib.Path(root_s)
    pkg_path = root / PKG_DIR / "package.json"
    lock_path = root / PKG_DIR / "package-lock.json"

    for p in (pkg_path, lock_path):
        if not p.is_file():
            print(f"UNMEASURED missing: {p.relative_to(root)}")
            return 2
    try:
        pkg = json.loads(pkg_path.read_text(encoding="utf-8"))
        lock = json.loads(lock_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        print(f"UNMEASURED {PKG_DIR} will not parse: {e}")
        return 2

    packages = lock.get("packages")
    if not isinstance(packages, dict) or "" not in packages:
        print("UNMEASURED the lock has no root `packages[\"\"]` entry: "
              "nothing to reconcile the manifest against")
        return 2

    findings = 0
    unmeasured = 0

    declared: dict[str, str] = {}
    for field in ("dependencies", "devDependencies", "optionalDependencies"):
        declared.update(pkg.get(field) or {})
    if not declared:
        print("UNMEASURED package.json declares no dependency at all: a green here "
              "would mean the file went empty, not that it agrees with the lock")
        return 2

    locked_root: dict[str, str] = {}
    for field in ("dependencies", "devDependencies", "optionalDependencies"):
        locked_root.update(packages[""].get(field) or {})

    # ---- direction 1: the manifest and the lock's copy of it, both ways -----
    for name, spec in sorted(declared.items()):
        if name not in locked_root:
            print(f"FINDING `{name}` is declared in package.json and absent from the "
                  f"lock's own copy of the manifest: the lock was not regenerated")
            findings += 1
        elif locked_root[name] != spec:
            print(f"FINDING `{name}`: package.json asks for {spec} and the lock's copy "
                  f"of the manifest records {locked_root[name]}")
            findings += 1
    for name, spec in sorted(locked_root.items()):
        if name not in declared:
            print(f"FINDING `{name}` is in the lock's copy of the manifest and no longer "
                  f"in package.json: a dependency nobody declared still installs")
            findings += 1

    # ---- direction 2: the installed version answers the pin ----------------
    for name, spec in sorted(declared.items()):
        entry = packages.get(f"node_modules/{name}")
        if entry is None:
            print(f"FINDING the lock pins no tree entry for `{name}`: `npm ci` would "
                  f"install nothing under that name")
            findings += 1
            continue
        if not EXACT.match(spec):
            print(f"UNMEASURED `{name}` is pinned as `{spec}`, not an exact version: "
                  f"deciding whether {entry.get('version')} satisfies it needs a semver "
                  f"resolver this gate does not have")
            unmeasured += 1
            continue
        if entry.get("version") != spec:
            print(f"FINDING `{name}`: package.json pins {spec} and the lock resolves "
                  f"{entry.get('version')}")
            findings += 1

    # ---- direction 3: no third copy of a locked version, in any workflow ----
    # Removed on 2026-09-02: a CLAUDE_CODE_VERSION env var in release.yml that
    # duplicated this lock and was compared against it by a check living in a
    # workflow that never runs on a pull request. Dependabot PR #81 was open,
    # MERGEABLE and 23/23 green with the two already disagreeing. Deleting the
    # copy is the fix; this is what stops it coming back, because a comment
    # saying "do not re-add this" is exactly the prose this repository refuses
    # to call a control.
    locked_names = [k[len("node_modules/"):] for k in packages if k.startswith("node_modules/")]
    locked_versions = {v.get("version") for k, v in packages.items()
                       if k.startswith("node_modules/") and isinstance(v, dict)}
    wf_dir = root / WORKFLOWS
    if not wf_dir.is_dir():
        print(f"UNMEASURED {WORKFLOWS} is not a directory: the third-copy check "
              f"measured nothing")
        unmeasured += 1
    else:
        files = sorted(wf_dir.glob("*.yml")) + sorted(wf_dir.glob("*.yaml"))
        if not files:
            print(f"UNMEASURED {WORKFLOWS} holds no workflow: a zero here would be blind")
            unmeasured += 1
        for f in files:
            try:
                lines = f.read_text(encoding="utf-8").splitlines()
            except OSError as e:
                print(f"UNMEASURED cannot read {f.name}: {e}")
                unmeasured += 1
                continue
            for n, line in enumerate(lines, 1):
                m = ENV_LINE.match(line)
                if not m:
                    continue
                var, value = m.group(1), m.group(2)
                stem = normalise(var)
                by_name = [p for p in locked_names if names_a_package(stem, p)]
                if by_name:
                    print(f"FINDING {WORKFLOWS}/{f.name}:{n} declares `{var}`, and "
                          f"{by_name[0]} is already pinned by {PKG_DIR}/package-lock.json -- "
                          f"a second place to say the same version is a second place for "
                          f"it to be wrong")
                    findings += 1
                elif value in locked_versions:
                    # The name gave nothing away, but the value is one this lock
                    # already carries. A variable called CLI_VERSION cannot be
                    # resolved by name, and refusing to look at the value would
                    # leave the rename as a way out of the rule.
                    print(f"FINDING {WORKFLOWS}/{f.name}:{n} declares `{var}` = {value}, "
                          f"which is a version {PKG_DIR}/package-lock.json already pins. "
                          f"The name does not say which package, so this is matched by "
                          f"value: if the two are unrelated, rename the variable so it "
                          f"cannot be read as a copy of the lock")
                    findings += 1

        print(f"third-copy check: {len(files)} workflow(s) against "
              f"{len(locked_names)} locked package(s)")

    print(f"measured: {len(declared)} declared dependency(ies) in {PKG_DIR}")

    if unmeasured:
        return 2
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
