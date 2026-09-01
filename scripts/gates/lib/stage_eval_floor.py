#!/usr/bin/env python3
"""Is a stage dataset separable without reading anything?

A per-stage eval is only worth its cost if answering it requires the work the
stage does. When the answer is spelled out in the words of the question -- a
case whose expected verdict is `false_positive` under a rule named
`sample_test_or_mock_code`, whose title says "mock" and whose path says
`tests/mocks/` -- the dataset measures paraphrase, and a stage that cannot
reason scores like one that can.

THE PROBE, and why it is not a list of keywords
    A hand-written keyword table proves whatever its author wanted. This runs
    leave-one-out nearest-centroid over word overlap instead: for each case,
    every OTHER case's input text is pooled by answer class, and the held-out
    case is assigned the class it shares most vocabulary with. Nothing is
    tuned, nothing is chosen, and the same code runs on any dataset. It reads
    only the input the stage is handed -- never the key's prose.

    High accuracy means the input's wording alone sorts the cases. That is a
    property of the dataset, not of any model, and it is the thing a floor is
    for.

POWER COMES BEFORE THE VERDICT
    Leave-one-out over four cases is not a clean bill of health, it is noise
    with a percent sign. Below `MIN_CASES` this reports 2 -- could not measure
    -- and never 0, because an instrument with nothing to learn from returns a
    low number for a leaky dataset just as readily as for a sound one. A class
    holding a single case is also dropped from the denominator and named:
    when it is held out its centroid is empty, so the probe can never emit it,
    and counting a case that is unpredictable by construction moves the score
    without measuring anything.

THE CEILING IS PRE-REGISTERED, not fitted
    `max(majority_class_rate + 0.20, 0.50)`. Majority-class rate is what a stub
    scores by always answering the commonest label, so the margin is what the
    wording is allowed to add on top of the free lunch the label distribution
    already gives. The rule was written down before any dataset was measured
    with it; a ceiling chosen after seeing the number is the number.

Exit codes: 0 = at or under the ceiling | 1 = over it | 2 = could not measure.
"""
from __future__ import annotations

import json
import math
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

WORD = re.compile(r"[a-z][a-z0-9_]{2,}")

# Pre-registered before any dataset was measured with this file.
MIN_CASES = 10      # under this, the verdict is 2 and never 0
MIN_PER_CLASS = 2   # a class below this is dropped from the denominator, and named


def dig(obj, path):
    """Resolve a dotted path, treating `[]` as 'every element of this list'."""
    parts = path.replace("[]", "").split(".")
    cur = [obj]
    for part in parts:
        nxt = []
        for c in cur:
            if isinstance(c, list):
                nxt.extend(x.get(part) for x in c if isinstance(x, dict))
            elif isinstance(c, dict):
                nxt.append(c.get(part))
        cur = [x for x in nxt if x is not None]
    out = []
    for c in cur:
        out.extend(c) if isinstance(c, list) else out.append(c)
    return [str(x) for x in out if isinstance(x, (str, int, float))]


def bag(text):
    return Counter(WORD.findall(text.lower()))


def probe(inputs, labels):
    """Leave-one-out nearest centroid over word overlap. Returns accuracy."""
    n = len(inputs)
    if n < 3:
        raise ValueError(f"{n} case(s) is too few to hold one out")
    bags = [bag(t) for t in inputs]
    hits = 0
    for i in range(n):
        centroid = defaultdict(Counter)
        for j in range(n):
            if j != i:
                centroid[labels[j]].update(bags[j])
        best, best_score = None, -1.0
        for lab in sorted(centroid):
            c = centroid[lab]
            num = sum(bags[i][w] * c[w] for w in bags[i])
            den = math.sqrt(sum(v * v for v in bags[i].values())) * math.sqrt(
                sum(v * v for v in c.values())) or 1.0
            score = num / den
            if score > best_score:
                best, best_score = lab, score
        hits += best == labels[i]
    return hits / n


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: stage_eval_floor.py <config.json>", file=sys.stderr)
        return 2
    try:
        cfg = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print(f"2|cannot read the probe config: {exc}")
        return 2

    worst = 0
    for ds in cfg["datasets"]:
        name = ds["name"]
        try:
            case_list = json.loads(Path(ds["cases"]).read_text(encoding="utf-8"))
            for part in ds["cases_at"].split("."):
                case_list = case_list[part] if part else case_list
            key_doc = json.loads(Path(ds["key"]).read_text(encoding="utf-8"))
            key_list = key_doc
            for part in ds["key_at"].split("."):
                key_list = key_list[part] if part else key_list
        except (OSError, ValueError, KeyError, TypeError) as exc:
            print(f"2|{name}: cannot read the dataset: {exc}")
            worst = max(worst, 2)
            continue

        if len(case_list) != len(key_list):
            print(f"2|{name}: {len(case_list)} case(s) against {len(key_list)} key entr(ies)")
            worst = max(worst, 2)
            continue

        inputs = [" ".join(sum((dig(c, f) for f in ds["fields"]), [])) for c in case_list]
        labels = [dig(k, ds["label"])[0] if dig(k, ds["label"]) else "" for k in key_list]
        if "" in labels:
            print(f"2|{name}: a key entry has no `{ds['label']}`")
            worst = max(worst, 2)
            continue
        if any(not t.strip() for t in inputs):
            print(f"2|{name}: a case presents no text under {ds['fields']}")
            worst = max(worst, 2)
            continue

        counts = Counter(labels)
        singles = sorted(lab for lab, c in counts.items() if c < MIN_PER_CLASS)
        keep = [i for i, lab in enumerate(labels) if counts[lab] >= MIN_PER_CLASS]
        note = (f"; {len(labels) - len(keep)} case(s) dropped as the only member of "
                f"{', '.join(singles)}, unpredictable by construction" if singles else "")

        if len(labels) < MIN_CASES:
            print(f"2|{name}: {len(labels)} case(s) is below the pre-registered floor of "
                  f"{MIN_CASES}; a separability probe on this many cases returns a low "
                  f"number whether the dataset leaks or not, so this is NOT a clearance")
            worst = max(worst, 2)
            continue

        inputs = [inputs[i] for i in keep]
        labels = [labels[i] for i in keep]
        try:
            acc = probe(inputs, labels)
        except ValueError as exc:
            print(f"2|{name}: {exc}")
            worst = max(worst, 2)
            continue

        majority = Counter(labels).most_common(1)[0][1] / len(labels)
        ceiling = max(majority + 0.20, 0.50)
        over = acc > ceiling + 1e-9
        code = 1 if over else 0
        worst = max(worst, code)
        verdict = "OVER the ceiling" if over else "under the ceiling"
        print(f"{code}|{name}: wording alone sorts {acc:.0%} of {len(labels)} case(s) "
              f"(majority class {majority:.0%}, ceiling {ceiling:.0%}) — {verdict}{note}")
    return worst


if __name__ == "__main__":
    sys.exit(main())
