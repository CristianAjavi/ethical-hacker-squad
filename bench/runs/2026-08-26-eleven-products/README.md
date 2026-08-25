# 2026-08-26 — the answer is no, and it is not close

**Refuted.** The band required this project's recall to exceed each competitor's by **≥ 15
points**. `google/mantis` beat it by **10.5 points**, on **this project's own corpus** — cases
this project wrote, defects it planted, a key it wrote.

| arm | valid runs | recall (mean) | range | decoys reported | findings |
|---|---|---|---|---|---|
| **`google/mantis` @ `56377ad`** | 3 | **90.1%** | 87 – 94% | 1.00 | 66.7 |
| **this project** | 4 | **79.6%** | 78 – 81% | **0.25** | 52.5 |

`mantis`'s **worst** run (87%) beats this project's **best** (81%). Over 54 planted defects
across eleven vibecoded products, it found on average **five and a half more** of them per run.

## Why this result is strong where the favourable ones were weak

Every prior page that reported a favourable number on this corpus carried the same warning, and
[the pre-registration](PREREGISTRATION.md) repeated it before these arms ran:

> A comparison of recall on a case this project planted is worth very little: the plant was
> written by the same hand that wrote the procedures.

That cuts one way. It makes a **win** here weak evidence — and it makes a **loss** here strong
evidence, because the bias ran toward this project and the result went the other way anyway.
This is the home fixture, with the home key, and it was lost by ten points.

## The one number that goes the other way

This project reported **0.25 decoys per run against `mantis`'s 1.00** — four times fewer false
positives on the 50 constructs planted to look vulnerable and be ruled out. That is real, it is
this repository's stated first-class defect, and it is the only column it leads.

**It does not rescue the primary and is not offered as doing so.** Recall 79.6% against 90.1%
is the registered question and the registered question was answered.

## What had to be fixed before this could be measured at all

Two harness defects, both found by exercising the scoring path on artifacts built from the key
rather than on any arm's report, and both recorded in [`LIMITS.md`](LIMITS.md) before scoring:

1. **The scorer would have reported every arm at 0%.** It counts only findings carrying a
   `status`, which this round's prompt never asked for. [`adapt.py`](adapt.py) supplies the
   default and changes nothing else; it has no per-arm branch.
2. **A decoy can be credited as detecting `P-12`.** An all-decoys artifact scores 1/54, not 0.
   So **every recall number above is up to two points high**, for both arms equally.

## And the mistake that made four earlier rounds worthless as comparisons

`mantis` was run in four prior rounds through **`mantis-advise`** — the one skill of nineteen
whose own description says *"Don't use for automated multi-pass red-team exploitation"* — and
scored 0.20 recall with runs coming back empty. Its actual entry point is `mantis-meta-agent`,
*"the persistent supervisor launching and monitoring the automated review campaign"*, driving
history → architecture → threat model → plan → researcher → dedupe → review → critic → chain →
calibrate → reproduce → report → patch. Run through that, it beats this project.

[`CORRECTION.md`](CORRECTION.md) records how that happened. The short version: choosing a fair
entry point for a competitor means reading all nineteen of its skill files, and this project
read one.

## What was not measured

- **`mantis` run 1 stalled** and never wrote a report. It is recorded as a run that did not
  happen, not as an empty run — the same rule the scorer applies to a report with no
  provenance. The arm is scored on 3 valid runs, at the floor the pre-registration fixed.
- **`Tencent/AI-Infra-Guard` was excluded**, and that exclusion stands: all four of its skills
  were read, `aig-scanner` requires a remote `taskapi` these offline rounds cannot reach, and
  the rest scope to the OpenClaw environment, to skills, and to red-teaming agents.
- **No claim about real code.** This is eleven products this project wrote. On `pyload`, Django
  and `Netflix/lemur` — code nobody here wrote — every arm scored at or near zero, and nothing
  here changes that.

## The answer to the question that prompted the round

*"Are we already the best hacker repo for different products or services built with
vibecoding?"*

**No.** On the only corpus where this project could plausibly have led, against the only
competitor that claims the same job, run through its own entry point: **it is behind by ten
points of recall, and it leads on false positives alone.**

Per the multiplicity commitment, **this corpus is retired for this question.** The next step is
not another run here — it is reading how `mantis` gets those ten points.
