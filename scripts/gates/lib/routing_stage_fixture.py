"""Build the six trees gate-routing-stage.sh proves itself against.

Each is a whole miniature repository: a routing table, a case file and a key.
Five of them are the healthy tree with exactly one thing broken, so a check that
passes them all is a check that is not reading the thing it claims to read.
"""

import hashlib
import json
import shutil
import sys
from pathlib import Path

COV_REL = "skills/ethical-hacker-squad/references/coverage.md"
CASES_REL = "bench/stages/routing/cases.json"
KEY_REL = "bench/stages/routing/keys/routing-key.json"

TABLE = """# Coverage routing

## Routing table

| Signal in the inventory | Role | Pack sections | Notes |
|---|---|---|---|
| `alpha.conf`, `alpha.d/` | `role-a` | `pack-a.md` §1 | The first surface. |
| `beta.yaml` | `role-b` | `pack-b.md` §2 | The second surface. |
| A worker that trusts what arrives on its socket | `role-c` | `pack-c.md` §3 | Named in prose, so nothing in a case has to repeat it. |
"""

CASES = {
    "dataset": "fixture",
    "presented_fields": ["inventory[].path", "inventory[].excerpt"],
    "cases": [
        {"case": "FX-01", "inventory": [
            {"path": "etc/alpha.conf", "excerpt": "listen = 0.0.0.0:80\ntrusted = *\n"}]},
        {"case": "FX-02", "inventory": [
            {"path": "deploy/beta.yaml", "excerpt": "replicas: 3\nprivileged: true\n"}]},
        {"case": "FX-03", "inventory": [
            {"path": "svc/handle.py",
             "excerpt": "def handle(raw):\n    run(json.loads(raw))\n"}]},
    ],
}

ANSWERS = [
    {"case": "FX-01", "row": "`alpha.conf`, `alpha.d/`", "role": "`role-a`",
     "sections": "`pack-a.md` §1", "why": "the file is the signal"},
    {"case": "FX-02", "row": "`beta.yaml`", "role": "`role-b`",
     "sections": "`pack-b.md` §2", "why": "the file is the signal"},
    {"case": "FX-03", "row": "A worker that trusts what arrives on its socket", "role": "`role-c`",
     "sections": "`pack-c.md` §3", "why": "no token of the row appears in the case"},
]


def write(root, cases, answers, table=TABLE):
    (root / COV_REL).parent.mkdir(parents=True, exist_ok=True)
    (root / KEY_REL).parent.mkdir(parents=True, exist_ok=True)
    (root / COV_REL).write_text(table, encoding="utf-8")
    cp = root / CASES_REL
    cp.write_text(json.dumps(cases, indent=2) + "\n", encoding="utf-8")
    key = {"key_for": "cases.json",
           "seals": {"cases.json": "sha256:" + hashlib.sha256(cp.read_bytes()).hexdigest()},
           "answers": answers}
    (root / KEY_REL).write_text(json.dumps(key, indent=2) + "\n", encoding="utf-8")


def clone(base, name):
    dst = base.parent / name
    shutil.copytree(base, dst)
    return dst


def main(work):
    work = Path(work)
    healthy = work / "healthy"
    write(healthy, CASES, ANSWERS)

    # The key says one thing and the table says another.
    drift = clone(healthy, "role-drift")
    key = json.loads((drift / KEY_REL).read_text())
    key["answers"][0]["role"] = "`role-b`"
    (drift / KEY_REL).write_text(json.dumps(key, indent=2) + "\n", encoding="utf-8")

    # The cases moved after the key sealed them.
    stale = clone(healthy, "stale-seal")
    cases = json.loads((stale / CASES_REL).read_text())
    cases["cases"][0]["inventory"][0]["excerpt"] += "# one more line\n"
    (stale / CASES_REL).write_text(json.dumps(cases, indent=2) + "\n", encoding="utf-8")

    # A case carrying its own answer.
    leaked = work / "leaked-role"
    leaky = json.loads(json.dumps(CASES))
    leaky["cases"][2]["inventory"][0]["excerpt"] = "# owned by the role-c team\ndef handle(raw): ...\n"
    write(leaked, leaky, ANSWERS)

    # A set the table's own words answer perfectly.
    trivial = work / "trivial-router"
    easy = json.loads(json.dumps(CASES))
    easy["cases"][2]["inventory"][0]["path"] = "svc/socket_worker.py"
    easy["cases"][2]["inventory"][0]["excerpt"] = (
        "# a worker that trusts what arrives on its socket\ndef handle(raw): ...\n")
    write(trivial, easy, ANSWERS)

    # No table to derive from.
    blind = work / "no-table"
    write(blind, CASES, ANSWERS, table="# Coverage routing\n\nNo table here yet.\n")


if __name__ == "__main__":
    main(sys.argv[1])
