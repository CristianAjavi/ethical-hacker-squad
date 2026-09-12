#!/usr/bin/env python3
"""Does the sandbox actually deny the network? Measure it, do not trust it.

The same probe - open a socket to 1.1.1.1:53 - is run in the `subprocess`
environment and in the `seatbelt` one. The unsandboxed run must succeed and the
sandboxed run must fail, because a sandbox that lets the socket through and one
that is never exercised look identical from the outside.

Prints `{"subprocess": true, "seatbelt": false}` when both behaved, or
`{"skip": "<reason>"}` when this machine cannot answer the question - which the
battery reports as a skip rather than as a pass.

There are two ways it cannot answer, and only one of them used to be said out
loud. The other is a machine with no network: the unsandboxed control fails to
open the socket too, the pair reads (False, False), and a sandbox that is
working is indistinguishable from one that was never exercised. Reporting that
as a failure of the sandbox is a red aimed at the only component known to be
behaving. `verdict()` below separates the three answers, and it is a pure
function of two observations so that all three can be measured on a machine with
neither a sandbox nor a network - which is what
`scripts/bench/selftest_isolation.selftest.sh` does.
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


# MUTATION ANCHORS. One line each, a literal, read from nowhere else, so that
# the battery can knock out exactly one rule and show which case goes red. A
# rule no mutation can remove is a rule whose battery has never been shown to
# notice it.
SKIP_WHEN_NO_CONTROL = 1
SKIP_WHEN_UNMEASURABLE = 1


def verdict(subprocess_obs: dict, seatbelt_obs: dict) -> dict:
    """What the pair of observations proves - in three answers, not two.

    The sandbox is only under test when the control shows there was something to
    deny. Without that, `seatbelt: false` is not evidence of a sandbox: it is the
    same answer an unplugged cable gives.
    """
    for name, obs in (("unsandboxed", subprocess_obs), ("sandboxed", seatbelt_obs)):
        why = (obs or {}).get("unmeasurable") or ""
        if SKIP_WHEN_UNMEASURABLE and why:
            return {"skip": "the %s run returned no observation: %s" % (name, why)}
    if SKIP_WHEN_NO_CONTROL and (subprocess_obs or {}).get("reproduces") is not True:
        return {"skip": "the unsandboxed control did not open the socket either (%s), so "
                        "this machine cannot tell a denied network from an absent one"
                        % ((subprocess_obs or {}).get("evidence") or "no evidence given")}
    return {"subprocess": True, "seatbelt": (seatbelt_obs or {}).get("reproduces") is True}


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
            # the WHOLE observation, not just `reproduces`: the evidence is what
            # tells a denied network from an absent one, and the child's own
            # `unmeasurable` is not a False.
            out[env.name] = env.run(probe, case, "NET", room).observation
        print(json.dumps(verdict(out.get("subprocess", {}), out.get("seatbelt", {}))))
    finally:
        shutil.rmtree(work, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
