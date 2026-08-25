#!/usr/bin/env python3
"""Where a probe runs, and how much the machine will let it do.

WHY THIS EXISTS
    A probe that runs inside the harness shares the harness's process. The
    probes in this corpus set `PATH`, change the umask and chdir, so a probe
    that died halfway used to leave the harness holding somebody else's
    environment. That is a weak place to run code from, and it is the axis on
    which the neighbouring product leads: it ships four sandbox backends.

WHAT WAS MEASURED BEFORE THIS WAS WRITTEN
    Of those four, exactly one runs on this machine. `gce_env` wants a Google
    Cloud account, `gvisor_env` wants Docker and `runsc` - which is Linux only -
    and `microsandbox_env` wants the `msb` binary; none of the three is present
    here. The one that runs is `static_env`, 145 lines that import `os` and
    isolate nothing.

    What IS present is `/usr/bin/sandbox-exec`, and it was checked rather than
    assumed: without it a probe opens a socket to 1.1.1.1:53, and under a
    profile denying `network*` the same code raises PermissionError.

THE RULE THIS LAYER ENFORCES
    A run records the environment it actually used, and a run weaker than the
    minimum its key declares does not pass. Silently falling back to a weaker
    sandbox and returning 0 would be the same defect as any other unmeasured
    green: the answer is 2, and the reason is printed.

Environments, weakest first: `inprocess` < `subprocess` < `seatbelt`.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

CHILD = Path(__file__).resolve().parent / "_probe_child.py"

# The order is the strength order, and other code depends on it.
ORDER = ("inprocess", "subprocess", "seatbelt")

# Seatbelt profile: everything the interpreter needs, minus the network. The
# write restriction is deliberately NOT here - a profile that also confined
# writes stopped CPython from starting on this machine, and a sandbox that
# prevents the measurement is not a stronger measurement.
SEATBELT_PROFILE = "(version 1)\n(allow default)\n(deny network*)\n"

# What a probe is allowed to spend. Generous enough that no honest probe
# notices, tight enough that a runaway one dies instead of taking the machine.
CPU_SECONDS = 30
ADDRESS_SPACE = 2 * 1024 * 1024 * 1024
FILE_SIZE = 64 * 1024 * 1024


class Result:
    def __init__(self, observation: dict, environment: str, note: str = "") -> None:
        self.observation = observation
        self.environment = environment
        self.note = note


class Environment:
    name = "abstract"

    def available(self) -> tuple[bool, str]:
        raise NotImplementedError

    def run(self, probes: Path, case: Path, defect: str, work: Path) -> Result:
        raise NotImplementedError


class InProcess(Environment):
    """The probe runs inside this interpreter. Fastest, and isolates nothing."""

    name = "inprocess"

    def available(self) -> tuple[bool, str]:
        return True, "always"

    def run(self, probes: Path, case: Path, defect: str, work: Path) -> Result:
        import importlib.util

        def load(path: Path, alias: str):
            spec = importlib.util.spec_from_file_location(alias, path)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            return module

        probe_mod = load(probes, "ehs_probes_inproc")
        case_mod = load(case, f"ehs_case_{defect.replace('-', '_')}")
        cwd = Path.cwd()
        try:
            os.chdir(work)
            obs = probe_mod.PROBES[defect](case_mod, work)
        finally:
            os.chdir(cwd)
        return Result(obs.as_dict(), self.name)


class Subprocess(Environment):
    """The probe runs in a child interpreter, under resource limits.

    Whatever the probe does to its environment, umask or working directory dies
    with the child. That alone is why this is the default: the probes in this
    corpus mutate all three.
    """

    name = "subprocess"
    wrapper: list[str] = []

    def available(self) -> tuple[bool, str]:
        if not CHILD.exists():
            return False, f"the child runner is missing at {CHILD}"
        return True, "python3 and a child process"

    def _argv(self, probes: Path, case: Path, defect: str, work: Path) -> list[str]:
        return [*self.wrapper, sys.executable, str(CHILD), str(probes), str(case), defect, str(work)]

    def run(self, probes: Path, case: Path, defect: str, work: Path) -> Result:
        env = {
            "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
            "HOME": str(work),
            "TMPDIR": str(work),
            "EHS_CPU_SECONDS": str(CPU_SECONDS),
            "EHS_ADDRESS_SPACE": str(ADDRESS_SPACE),
            "EHS_FILE_SIZE": str(FILE_SIZE),
        }
        try:
            done = subprocess.run(
                self._argv(probes, case, defect, work),
                cwd=str(work), env=env, capture_output=True, text=True,
                timeout=CPU_SECONDS * 2,
            )
        except subprocess.TimeoutExpired:
            return Result(
                {"reproduces": None, "evidence": "",
                 "unmeasurable": f"the probe did not finish within {CPU_SECONDS * 2}s"},
                self.name,
            )
        if done.returncode != 0 or not done.stdout.strip():
            detail = (done.stderr or done.stdout or "").strip().splitlines()
            return Result(
                {"reproduces": None, "evidence": "",
                 "unmeasurable": f"the child exited {done.returncode}: "
                                 f"{detail[-1] if detail else 'no output'}"},
                self.name,
            )
        try:
            return Result(json.loads(done.stdout), self.name)
        except ValueError as exc:
            return Result(
                {"reproduces": None, "evidence": "",
                 "unmeasurable": f"the child did not return an observation: {exc}"},
                self.name,
            )


class Seatbelt(Subprocess):
    """A child process with the network denied, through macOS `sandbox-exec`.

    `sandbox-exec` is deprecated and still shipped. It is used here for what was
    measured - it refuses to open a socket - and for nothing that was not.
    """

    name = "seatbelt"

    def __init__(self, profile_dir: Path | None = None) -> None:
        self._profile_dir = profile_dir
        self._profile: Path | None = None

    def available(self) -> tuple[bool, str]:
        ok, why = super().available()
        if not ok:
            return ok, why
        if sys.platform != "darwin":
            return False, "sandbox-exec is a macOS facility and this is not macOS"
        if shutil.which("sandbox-exec") is None:
            return False, "sandbox-exec is not on PATH"
        return True, "sandbox-exec with the network denied"

    def run(self, probes: Path, case: Path, defect: str, work: Path) -> Result:
        directory = self._profile_dir or work
        directory.mkdir(parents=True, exist_ok=True)
        self._profile = directory / "deny-network.sb"
        self._profile.write_text(SEATBELT_PROFILE, encoding="utf-8")
        self.wrapper = ["sandbox-exec", "-f", str(self._profile)]
        return super().run(probes, case, defect, work)


REGISTRY = {"inprocess": InProcess, "subprocess": Subprocess, "seatbelt": Seatbelt}


def survey() -> list[tuple[str, bool, str]]:
    """Every environment, whether it runs here, and why - in strength order."""
    out = []
    for name in ORDER:
        ok, why = REGISTRY[name]().available()
        out.append((name, ok, why))
    return out


def strongest_available() -> tuple[Environment, list[str]]:
    """The strongest environment this machine offers, and what was ruled out."""
    ruled_out = []
    chosen = None
    for name, ok, why in survey():
        if ok:
            chosen = REGISTRY[name]()
        else:
            ruled_out.append(f"{name}: {why}")
    if chosen is None:  # InProcess always reports available, so this is defensive
        chosen = InProcess()
    return chosen, ruled_out


def at_least(name: str, minimum: str) -> bool:
    """Is `name` at least as strong as `minimum`?"""
    if name not in ORDER or minimum not in ORDER:
        return False
    return ORDER.index(name) >= ORDER.index(minimum)
