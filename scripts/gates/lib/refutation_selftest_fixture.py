#!/usr/bin/env python3
"""Build one mutated copy of the declared refutation cases, for the self-test.

usage: refutation_selftest_fixture.py <cases.json> <workdir> <mutation> <workdir>

Prints the path of the file it wrote. Each mutation is a way a refutation case
stops being evidence while the file still looks like evidence.
"""
import json
import sys
from pathlib import Path

cases_path, work, mutation = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
doc = json.loads(cases_path.read_text(encoding="utf-8"))
cases = doc["cases"]
out = work / f"cases-{mutation}.json"

if mutation == "no-op-edit":
    # The edit is applied and changes nothing, so the validator sees the clean
    # artifact and reports nothing: the case claims a distance that is zero.
    cases[0]["edit"]["new"] = cases[0]["edit"]["old"]
elif mutation == "wrong-needle":
    # It flips, but the rejection says something else entirely.
    cases[0]["needle"] = "a sentence no rule in this repository prints"
elif mutation == "drifted-anchor":
    cases[0]["edit"]["old"] = '"path": "this-anchor-was-refactored-away.sql"'
elif mutation == "ambiguous-anchor":
    # A string that appears in more than one finding: the edit no longer names
    # one place, so nobody can say which rule the case is about.
    cases[0]["edit"]["old"] = '"severity": "high"'
    cases[0]["edit"]["new"] = '"severity": "low"'
elif mutation in ("dirty-fixture", "not-under-good"):
    artifact = json.loads((cases_path.parents[3] / cases[0]["fixture"]).read_text(encoding="utf-8"))
    if mutation == "dirty-fixture":
        # Clean is the claim; this copy never was. A procedure the corpus does
        # not have makes the validator reject the artifact on its own.
        artifact["findings"][0]["procedure"] = "LOC-99"
    folder = work / ("good" if mutation == "dirty-fixture" else "elsewhere")
    folder.mkdir(parents=True, exist_ok=True)
    planted = folder / "planted.json"
    planted.write_text(json.dumps(artifact, indent=2) + "\n", encoding="utf-8")
    cases[0]["fixture"] = str(planted)
elif mutation == "below-floor":
    doc["cases"] = cases[:-1]
elif mutation == "duplicate-needle":
    cases[1]["needle"] = cases[0]["needle"]
elif mutation == "missing-validator":
    cases[0]["validator"] = "scripts/gates/lib/there-is-no-such-validator.py"
elif mutation == "unparseable":
    out.write_text('{"cases": [', encoding="utf-8")
    print(out)
    raise SystemExit(0)
else:
    raise SystemExit(f"unknown mutation: {mutation}")

out.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(out)
