#!/usr/bin/env bash
# A reference no role can reach is a rule that does not exist.
#
# WHY THIS EXISTS — four instances in one day
#     1. The battery-discovery rule lived inside a CI step: locally nothing ran it.
#     2. A .gitignore trap was written up as prose on a run page; the trap repeated a day later.
#     3. VER-09 - the stage that refutes your own findings - lived in SKILL.md, which no role
#        file cites. Measured across four blinded runs: it fired ZERO times, and the round it
#        would have won was lost on precision.
#     4. The artifact contract requiring a triage answer per finding was bypassed by the
#        measurement harness itself.
#
#     Each was written correctly, and each lived somewhere the thing that executes never looks.
#     Prose about this did not stop the next one, so this is a check.
#
# THE RULE
#     Every file under references/ must be reachable, by citation, from at least one agent in
#     the plugin manifest - directly or through another reference. Reachability is computed,
#     not asserted: the graph is walked.
#
# Exit codes: 0 = every reference reachable | 1 = orphans | 2 = could not measure.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${EHS_REPO_ROOT:-$(cd "$HERE/../.." && pwd)}"
AGENTS="${EHS_AGENTS_DIR:-$ROOT/agents}"
REFS="${EHS_REFS_DIR:-$ROOT/skills/ethical-hacker-squad/references}"

command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is absent"; exit 2; }
[ -d "$AGENTS" ] || { echo "UNMEASURABLE no agents directory at $AGENTS"; exit 2; }
[ -d "$REFS" ]   || { echo "UNMEASURABLE no references directory at $REFS"; exit 2; }

EHS_AGENTS="$AGENTS" EHS_REFS="$REFS" python3 - <<'PY'
import os, re, sys
from pathlib import Path

agents = Path(os.environ["EHS_AGENTS"]); refs = Path(os.environ["EHS_REFS"])
all_refs = {p.relative_to(refs).as_posix() for p in refs.rglob("*") if p.is_file()}
if not all_refs:
    print("UNMEASURABLE the references directory holds no files"); sys.exit(2)
seeds = sorted(agents.glob("*.md"))
if not seeds:
    print("UNMEASURABLE no agent files to start from"); sys.exit(2)

# A citation is any references/<path> mention. Deliberately generous: the question is
# whether a reader is POINTED at the file, not how prettily.
CITE = re.compile(r"references/([A-Za-z0-9_\-./]+\.(?:md|json))")

def cites(text):
    return {m.group(1) for m in CITE.finditer(text)}

reached, frontier = set(), set()
for a in seeds:
    frontier |= cites(a.read_text(errors="ignore"))
while frontier:
    nxt = set()
    for r in frontier:
        if r in reached or r not in all_refs:
            continue
        reached.add(r)
        nxt |= cites((refs / r).read_text(errors="ignore"))
    frontier = nxt - reached

orphans = sorted(all_refs - reached)
print(f"  {len(seeds)} agent(s), {len(all_refs)} reference file(s), {len(reached)} reachable")
if orphans:
    print(f"FAIL  {len(orphans)} reference(s) no agent can reach by citation:")
    for o in orphans:
        print(f"        references/{o}")
    print("      A rule nobody is pointed at is not a rule. Cite it from the role that must")
    print("      follow it, or delete it - VER-09 sat unreachable and fired zero times in four")
    print("      measured runs.")
    sys.exit(1)
print("OK    every reference is reachable by citation from at least one agent")
PY
