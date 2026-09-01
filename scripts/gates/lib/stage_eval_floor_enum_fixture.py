"""Two stage directories beside one probe config, with `two` in three states.

The enumeration rule in stage_eval_floor.py is the one check in that file that
does not read a dataset at all: it reads the ABSENCE of one from the config. A
check on an absence has to be proved in the negative or it proves nothing.
"""

import json
import sys
from pathlib import Path


def main(stages, state):
    s = Path(stages)
    for name in ("one", "two"):
        (s / name).mkdir(parents=True, exist_ok=True)
        (s / name / "cases.json").write_text(json.dumps({"cases": [
            {"finding": {"title": f"{name} {i}",
                         "detail": f"a parameter reaches a store, revision {i}"}}
            for i in range(12)]}), encoding="utf-8")
        (s / name / "key.json").write_text(json.dumps({"answers": [
            {"case": f"C-{i}", "answer": "HOLDS" if i % 2 == 0 else "DOES_NOT_HOLD"}
            for i in range(12)]}), encoding="utf-8")
    cfg = {"datasets": [{
        "name": "stages/one", "cases": "stages/one/cases.json", "cases_at": "cases",
        "key": "stages/one/key.json", "key_at": "answers",
        "fields": ["finding.title", "finding.detail"], "label": "answer"}]}
    if state == "reasonless":
        cfg["exempt"] = [{"name": "stages/two"}]
    elif state == "reasoned":
        cfg["exempt"] = [{"name": "stages/two",
                          "reason": "its inputs are the label by design"}]
    (s / "probe-config.json").write_text(json.dumps(cfg), encoding="utf-8")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
