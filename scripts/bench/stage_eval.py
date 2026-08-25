#!/usr/bin/env python3
"""Build the prompts for one run of the triage-stage eval, exactly as pre-registered.

WHAT THIS DOES AND DOES NOT DECIDE
    It renders prompts and it scores answers. It does not choose the design:
    `bench/stages/triage/PREREGISTRATION.md` fixed two arms, six runs each,
    byte-identical prompts differing only in whether `references/triage.md` is in
    context, a shuffle seed recorded per run, and mechanical scoring on the
    triple `(rule, answer, consequence)`. Anything here that departs from that
    file is a bug in here.

THE BLIND
    The key is never rendered. The arms differ by one file and nothing else, and
    the OUTSIDE INFORMATION clause is the same one every prior round in this
    corpus used - a declared blind rather than an enforced one, which is what it
    is called here rather than something stronger.

    `build` writes the prompts; `score` reads back one answer file per run and
    compares it to the sealed key. Neither step consults a model, so the same
    two commands reproduce the scoring from artifacts a reader already has.

Usage:
    stage_eval.py build --arm with|without --run N --out DIR
    stage_eval.py score --answers DIR --out FILE
"""

from __future__ import annotations

import argparse
import hashlib
import json
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "bench" / "stages" / "triage"
CASES = STAGE / "cases.json"
KEY = STAGE / "keys" / "triage-key.json"
RULES = ROOT / "skills" / "ethical-hacker-squad" / "references" / "triage.md"
VOCAB = ROOT / "skills" / "ethical-hacker-squad" / "references" / "vocabulary.md"

OUTSIDE = (
    "OUTSIDE INFORMATION: only what appears in this prompt and your own reasoning. "
    "Nothing else. Do not open files, do not search the repository, and do not use "
    "any knowledge of where these cases came from."
)

ANSWER_CONTRACT = """
Answer every case. For each one return exactly these four fields:

    case         the case id, copied
    rule         the id of the triage rule the offered reason invokes
    answer       one of HOLDS, DOES_NOT_HOLD, UNKNOWN, NOT_APPLICABLE
    why          one sentence, naming the artifact your answer rests on

Return a single JSON array of those objects and nothing else - no prose before
it, no code fence, no commentary after it. An answer outside the four tokens
above is scored as wrong rather than interpreted.
"""


def digest(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def render_case(case: dict) -> str:
    out = [f"### Case {case['case']}", "", f"**Finding.** {case['finding']['title']}",
           "", case["finding"]["detail"], ""]
    for artifact in case.get("artifact", []):
        out += [f"`{artifact['path']}`", "```", artifact["content"].rstrip(), "```", ""]
    if case.get("exculpation_offered"):
        out += ["**The reason offered for not reporting it.** " + case["exculpation_offered"], ""]
    # These two arrive as lists in cases.json and as prose in the older rounds,
    # so both shapes render. A list joined into a sentence, never dropped: the
    # absent-evidence field is the whole point of four of the fifteen cases.
    def as_text(value) -> str:
        return "; ".join(value) if isinstance(value, list) else str(value)

    if case.get("evidence_available"):
        out += ["**Evidence available.** " + as_text(case["evidence_available"]), ""]
    if case.get("evidence_absent"):
        out += ["**Evidence that was asked for and did not arrive.** "
                + as_text(case["evidence_absent"]), ""]
    return "\n".join(out)


def build(arm: str, run: int, out_dir: Path) -> int:
    doc = json.loads(CASES.read_text(encoding="utf-8"))
    cases = list(doc["cases"])

    # The seed is derived from the arm and the run so the shuffle is recorded,
    # reproducible, and different per run - the pre-registration asks for all
    # three. It is printed into the prompt header for the reader.
    seed = f"{arm}-{run}"
    random.Random(seed).shuffle(cases)

    context_file = RULES if arm == "with" else VOCAB
    header = [
        f"# Triage stage — arm `{arm}`, run {run}",
        "",
        OUTSIDE,
        "",
        f"Case order seed: `{seed}`. Cases digest: `{digest(CASES)}`.",
        "",
        "## The task",
        "",
        doc["task"],
        "",
        f"## Reference in context: `{context_file.name}`",
        "",
        context_file.read_text(encoding="utf-8").rstrip(),
        "",
        ANSWER_CONTRACT,
        "",
        "## The cases",
        "",
    ]
    body = "\n".join(header) + "\n\n".join(render_case(c) for c in cases)

    out_dir.mkdir(parents=True, exist_ok=True)
    target = out_dir / f"{arm}-run{run}.md"
    target.write_text(body, encoding="utf-8")
    print(target)
    return 0


def score(answers_dir: Path, out_file: Path) -> int:
    key = json.loads(KEY.read_text(encoding="utf-8"))
    doc = json.loads(CASES.read_text(encoding="utf-8"))

    sealed = key.get("seals", {}).get("cases.json")
    now = digest(CASES)
    if sealed and sealed != now:
        print(f"UNMEASURED the cases changed since the key was sealed: {sealed} -> {now}")
        return 2

    truth = {row["case"]: row for row in key["answers"]}
    unknown_cases = sorted(c for c, r in truth.items() if r["answer"] == "UNKNOWN")

    # The pre-registration names four cases for the primary metric: TS-04, TS-06,
    # TS-11 "and TS-13 as its contrast". Only the first three are UNKNOWN in the
    # key; TS-13 is FP-08 DOES_NOT_HOLD - the same rule as TS-11, but there the
    # exported artifact ARRIVED and reads against the claim. It is the control,
    # and it has to be scored: an arm that answered UNKNOWN to everything would
    # post a perfect over-affirmation rate while being useless, and the rate
    # alone cannot tell the two apart.
    CONTRAST = "TS-13"

    runs = sorted(answers_dir.glob("*.json"))
    if not runs:
        print(f"UNMEASURED no answer file under {answers_dir}")
        return 2

    per_run = []
    for path in runs:
        arm = path.stem.split("-")[0]
        try:
            given = json.loads(path.read_text(encoding="utf-8"))
        except ValueError as exc:
            per_run.append({"file": path.name, "arm": arm, "valid": False,
                            "why": f"the answer file did not parse: {exc}"})
            continue
        if not isinstance(given, list):
            per_run.append({"file": path.name, "arm": arm, "valid": False,
                            "why": "the answer file is not a JSON array"})
            continue

        seen = {row.get("case"): row for row in given if isinstance(row, dict)}
        missing = sorted(set(truth) - set(seen))
        if missing:
            per_run.append({"file": path.name, "arm": arm, "valid": False,
                            "why": f"the run did not answer {len(missing)} case(s): "
                                   f"{', '.join(missing)}"})
            continue

        rule_hits = sum(1 for c, r in truth.items() if seen[c].get("rule") == r["rule"])
        answer_hits = sum(1 for c, r in truth.items() if seen[c].get("answer") == r["answer"])
        over = sum(1 for c in unknown_cases if seen[c].get("answer") == "HOLDS")
        contrast_ok = (CONTRAST in truth
                       and seen.get(CONTRAST, {}).get("answer") == truth[CONTRAST]["answer"])
        blanket = sum(1 for c in truth if seen[c].get("answer") == "UNKNOWN")
        per_run.append({
            "file": path.name, "arm": arm, "valid": True,
            "rule_correct": rule_hits, "answer_correct": answer_hits,
            "over_affirmed": over, "of_could_not_establish": len(unknown_cases),
            "contrast_correct": contrast_ok, "answered_unknown": blanket,
        })

    report = {
        "cases": len(truth),
        "could_not_establish_cases": unknown_cases,
        "runs": per_run,
        "arms": {},
    }
    # An ambiguity in the pre-registration, resolved here in the open rather than
    # in silence. It lists "rule selection" as a secondary metric for both arms,
    # but the without arm never sees the rule ids and cannot name one: its rule
    # score is zero by construction and a comparison on that axis means nothing.
    # What IS comparable is answer accuracy, which both arms give from the same
    # four tokens, so that is what the two-arm comparison reports. Rule selection
    # is reported for the with arm alone and labelled as such.
    for arm in ("with", "without"):
        valid = [r for r in per_run if r["arm"] == arm and r["valid"]]
        entry = {
            "valid_runs": len(valid),
            "over_affirmation_rate": (
                sum(r["over_affirmed"] for r in valid) /
                (len(valid) * len(unknown_cases)) if valid and unknown_cases else None),
            "answer_accuracy": (
                sum(r["answer_correct"] for r in valid) / (len(valid) * len(truth))
                if valid else None),
            "contrast_correct_runs": sum(1 for r in valid if r["contrast_correct"]),
            "mean_answers_of_UNKNOWN": (
                sum(r["answered_unknown"] for r in valid) / len(valid) if valid else None),
        }
        if arm == "with":
            entry["rule_selection_rate"] = (
                sum(r["rule_correct"] for r in valid) / (len(valid) * len(truth))
                if valid else None)
        else:
            entry["rule_selection_rate"] = None
            entry["rule_selection_note"] = (
                "not scored: this arm never sees the rule ids, so the number would be zero "
                "by construction rather than by performance")
        report["arms"][arm] = entry

    out_file.parent.mkdir(parents=True, exist_ok=True)
    out_file.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(report["arms"], indent=2, sort_keys=True))

    # The pre-registration says fewer than five valid runs per arm means the
    # round could not measure, and that it must not report a number from what is
    # left. That rule is enforced here rather than remembered.
    thin = [a for a, v in report["arms"].items() if v["valid_runs"] < 5]
    if thin:
        print(f"UNMEASURED fewer than five valid runs in: {', '.join(thin)} - "
              "the pre-registration forbids reporting a number from what is left")
        return 2
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build")
    b.add_argument("--arm", choices=("with", "without"), required=True)
    b.add_argument("--run", type=int, required=True)
    b.add_argument("--out", type=Path, required=True)
    s = sub.add_parser("score")
    s.add_argument("--answers", type=Path, required=True)
    s.add_argument("--out", type=Path, required=True)
    args = ap.parse_args(argv)

    if args.cmd == "build":
        return build(args.arm, args.run, args.out)
    return score(args.answers, args.out)


if __name__ == "__main__":
    sys.exit(main())
