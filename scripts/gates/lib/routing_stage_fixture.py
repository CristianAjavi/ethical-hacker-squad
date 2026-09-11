"""Build the trees gate-routing-stage.sh proves itself against.

Each is a whole miniature repository: a routing table, a case file, a key, a
pre-registration and a dataset README. All but the first are the healthy tree
with exactly one thing broken, so a check that passes them all is a check that
is not reading the thing it claims to read.
"""

import hashlib
import json
import shutil
import sys
from pathlib import Path

COV_REL = "skills/ethical-hacker-squad/references/coverage.md"
CASES_REL = "bench/stages/routing/cases.json"
KEY_REL = "bench/stages/routing/keys/routing-key.json"
PREREG_REL = "bench/stages/routing/PREREGISTRATION.md"
README_REL = "bench/stages/routing/README.md"

# What the table-word router scores on the healthy fixture. Asserted by the
# gate's self-test through the registration it writes: if the fixture's router
# ever moves, the healthy tree stops being clean and says so.
HEALTHY = {"role": 2, "role_and_sections": 2, "total": 3}
HEALTHY_PRIMARY = ["FX-03"]

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


def docs(scored=None, primary=None, supersedes=False, prose="", heading=True):
    """A pre-registration and a dataset README, both quoting the same score."""
    scored = dict(HEALTHY if scored is None else scored)
    primary = list(HEALTHY_PRIMARY if primary is None else primary)
    block = json.dumps({"registered_on": "2026-01-01",
                        "supersedes": "an earlier one" if supersedes else "",
                        "table_word_router": scored,
                        "primary_cases": primary,
                        "runs_per_arm": 6}, indent=2)
    head = "## Registration in force" if heading else "## Something else entirely"
    # The drifting prose goes in a LATER section, and the superseded record --
    # which must NOT be scanned -- carries numbers that are wrong on purpose.
    # Between them they separate "reads the whole file outside the superseded
    # record" from "reads only the block's own section", which is the distance
    # the real defect lived at: the contradicting sentence was four sections
    # away from where the block now sits.
    prereg = (f"# Pre-registration -- fixture\n\nNothing here has been run.\n\n"
              f"{head}\n\n```json\n{block}\n```\n\n"
              f"## What is measured\n\n{prose}\n\n"
              f"## Superseded registrations\n\n"
              f"> The first registration reported 1/3 on the role and named FX-01.\n")
    readme = (f"# The fixture stage\n\n## What is in here\n\nThree cases.\n\n"
              f"## What the table-word router scores\n\n"
              f"| Instrument | Score |\n|---|---|\n"
              f"| Table-word router, role only | **{scored['role']} / {scored['total']}** |\n")
    return prereg, readme


def write(root, cases, answers, table=TABLE, paper=None):
    (root / COV_REL).parent.mkdir(parents=True, exist_ok=True)
    (root / KEY_REL).parent.mkdir(parents=True, exist_ok=True)
    (root / COV_REL).write_text(table, encoding="utf-8")
    cp = root / CASES_REL
    cp.write_text(json.dumps(cases, indent=2) + "\n", encoding="utf-8")
    key = {"key_for": "cases.json",
           "seals": {"cases.json": "sha256:" + hashlib.sha256(cp.read_bytes()).hexdigest()},
           "answers": answers}
    (root / KEY_REL).write_text(json.dumps(key, indent=2) + "\n", encoding="utf-8")
    prereg, readme = paper if paper else docs()
    (root / PREREG_REL).write_text(prereg, encoding="utf-8")
    (root / README_REL).write_text(readme, encoding="utf-8")


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

    # The registration froze a score the router no longer gets. This is the
    # shape that was live in the real dataset on 2026-09-10: the gate printed
    # one number and the document beside it declared another, and nothing
    # compared them.
    write(work / "prereg-score-drift", CASES, ANSWERS,
          paper=docs(scored={"role": 1, "role_and_sections": 1, "total": 3}))

    # The block agrees and the primary set it names does not.
    write(work / "prereg-primary-drift", CASES, ANSWERS,
          paper=docs(primary=["FX-01", "FX-03"]))

    # The block agrees and the prose four paragraphs away does not.
    write(work / "prereg-prose-drift", CASES, ANSWERS,
          paper=docs(prose="The table-word router scores 1/3 on the role."))

    # The block agrees and the prose names a different primary case.
    write(work / "prereg-cited-drift", CASES, ANSWERS,
          paper=docs(prose="The primary case, the one the router gets wrong, is `FX-01`."))

    # The README quotes a score the gate does not print.
    stale_readme = work / "readme-score-drift"
    prereg, _ = docs()
    write(stale_readme, CASES, ANSWERS,
          paper=(prereg, "# The fixture stage\n\n## What the table-word router scores\n\n"
                         "| Table-word router, role only | **1 / 3** |\n"))

    # There is no section naming the router, so nothing the README says about
    # the score is read. Could-not-measure, never fine.
    no_section = work / "readme-no-section"
    prereg, _ = docs()
    write(no_section, CASES, ANSWERS,
          paper=(prereg, "# The fixture stage\n\n## Notes\n\nNothing about scores here.\n"))

    # A registration rewritten after a result exists is fitted to that result.
    after = work / "superseded-after-result"
    write(after, CASES, ANSWERS, paper=docs(supersedes=True))
    (after / "bench/stages/routing/score.json").write_text(
        '{"primary": 0.61}\n', encoding="utf-8")


if __name__ == "__main__":
    main(sys.argv[1])
