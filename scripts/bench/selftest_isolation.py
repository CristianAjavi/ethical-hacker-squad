#!/usr/bin/env python3
"""Does the sandbox actually deny the network? Measure it, do not trust it.

The same probe - open a socket to 1.1.1.1:53 - is run in the `subprocess`
environment and in the `seatbelt` one. The unsandboxed run must succeed and the
sandboxed run must fail, because a sandbox that lets the socket through and one
that is never exercised look identical from the outside.

Prints `{"subprocess": true, "seatbelt": false}` when both behaved, or
`{"skip": "<reason>"}` when this machine offers no sandbox to test - which the
battery reports as a skip rather than as a pass.
"""

from __future__ import annotations

import json
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import environments as envs  # noqa: E402  - a sibling, not a package

NET_PROBE = '''
import socket


class Observation:
    def __init__(self, reproduces, evidence):
        self.reproduces = reproduces
        self.evidence = evidence

    def as_dict(self):
        return {"reproduces": self.reproduces, "evidence": self.evidence, "unmeasurable": ""}


def opens_a_socket(case, work):
    try:
        conn = socket.create_connection(("1.1.1.1", 53), timeout=5)
        conn.close()
        return Observation(True, "the socket opened")
    except Exception as exc:
        return Observation(False, type(exc).__name__)


PROBES = {"NET": opens_a_socket}
'''


def main() -> int:
    seatbelt = envs.Seatbelt()
    ok, why = seatbelt.available()
    if not ok:
        print(json.dumps({"skip": why}))
        return 0

    work = Path(tempfile.mkdtemp(prefix="ehs-isolation-"))
    try:
        probe = work / "netprobe.py"
        probe.write_text(NET_PROBE, encoding="utf-8")
        case = work / "case.py"
        case.write_text("VALUE = 1\n", encoding="utf-8")

        out = {}
        for env in (envs.Subprocess(), seatbelt):
            room = work / env.name
            room.mkdir()
            out[env.name] = env.run(probe, case, "NET", room).observation["reproduces"]
        print(json.dumps(out))
    finally:
        shutil.rmtree(work, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
