#!/usr/bin/env python3
"""Run exactly one probe and print its observation as JSON. Nothing else.

This is what the `subprocess` and `seatbelt` environments execute. It exists so
that everything a probe does to its process - `PATH`, the umask, the working
directory - dies with the child instead of leaking back into the harness.

    _probe_child.py <probes.py> <case.py> <defect-id> <workdir>

Anything printed on stdout other than the observation would be read as a broken
answer, so failures go to stderr and a non-zero exit; the parent turns that into
COULD NOT MEASURE rather than into a negative.
"""

from __future__ import annotations

import importlib.util
import json
import os
import sys
from pathlib import Path


def _limit() -> None:
    """Cap what the probe may spend, where the platform allows it.

    A limit that cannot be set is not worth failing over: the parent already
    enforces a wall-clock timeout, and refusing to run here would turn a
    measurable case into an unmeasured one on a platform that is merely stricter.
    """
    try:
        import resource
    except ImportError:
        return
    for name, key in (
        ("RLIMIT_CPU", "EHS_CPU_SECONDS"),
        ("RLIMIT_AS", "EHS_ADDRESS_SPACE"),
        ("RLIMIT_FSIZE", "EHS_FILE_SIZE"),
    ):
        value = os.environ.get(key)
        if not value or not hasattr(resource, name):
            continue
        try:
            limit = int(value)
            soft, hard = resource.getrlimit(getattr(resource, name))
            ceiling = limit if hard == resource.RLIM_INFINITY else min(limit, hard)
            resource.setrlimit(getattr(resource, name), (ceiling, hard))
        except (ValueError, OSError):
            continue


def _load(path: Path, alias: str):
    spec = importlib.util.spec_from_file_location(alias, path)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main(argv: list[str]) -> int:
    if len(argv) != 5:
        print(__doc__, file=sys.stderr)
        return 2
    probes_path, case_path, defect, work = Path(argv[1]), Path(argv[2]), argv[3], Path(argv[4])
    _limit()
    try:
        probes = _load(probes_path, "ehs_probes_child")
        case = _load(case_path, f"ehs_case_{defect.replace('-', '_')}")
    except Exception as exc:  # noqa: BLE001 - the parent needs the reason, not the class
        print(f"could not load: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 2
    if defect not in probes.PROBES:
        print(f"no probe named {defect}", file=sys.stderr)
        return 2

    os.chdir(work)

    # stdout is the observation channel and nothing else may write to it. A
    # probe shells out to the tool the case invokes, and a child that PRINTS -
    # `/bin/echo` stood in for the uploader in one battery case - lands its
    # output in front of the JSON and the parent reads a broken answer. The real
    # stdout is set aside at the file-descriptor level, so anything the probe or
    # its own subprocesses emit goes to stderr with the rest of the diagnostics.
    saved = os.dup(1)
    try:
        os.dup2(2, 1)
        try:
            observation = probes.PROBES[defect](case, work)
        except Exception as exc:  # noqa: BLE001
            print(f"the probe raised: {type(exc).__name__}: {exc}", file=sys.stderr)
            return 2
    finally:
        sys.stdout.flush()
        os.dup2(saved, 1)
        os.close(saved)

    json.dump(observation.as_dict(), sys.stdout)
    sys.stdout.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
