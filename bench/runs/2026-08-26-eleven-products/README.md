# 2026-08-26 — the answer is no, and it is not close

> **Decoy figures on this page are an upper bound.** The thirteenth round measured that a
> decoy hit was scored by LOCATION rather than by claim: **59% of this project's counted
> false positives asserted a different CWE from the one the decoy was built to provoke**,
> against 31% of `mantis`'s. Corpora before 2026-08-29 carry no `baits_cwe`, so their numbers
> cannot be recomputed and are **not** rewritten from a field invented afterwards. See
> [`../2026-08-29-baited-claim/`](../2026-08-29-baited-claim/).

**Refuted.** The band required this project's recall to exceed each competitor's by **≥ 15
points**. `google/mantis` beat it by **8.3 points**, on **this project's own corpus** — cases
this project wrote, defects it planted, a key it wrote.

| arm | valid runs | recall (mean) | range | decoys reported | findings |
|---|---|---|---|---|---|
| **`google/mantis` @ `56377ad`** | 4 | **88.0%** | 81 – 94% | 1.00 | 64.5 |
| **this project** | 4 | **79.6%** | 78 – 81% | **0.25** | 52.5 |

Over 54 planted defects across eleven vibecoded products, `mantis` found on average **four and
a half more** of them per run. Three of its four runs beat every run of this project's; its
weakest (81%) ties this project's best.

## Why this result is strong where the favourable ones were weak

Every prior page that reported a favourable number on this corpus carried the same warning, and
[the pre-registration](PREREGISTRATION.md) repeated it before these arms ran:

> A comparison of recall on a case this project planted is worth very little: the plant was
> written by the same hand that wrote the procedures.

That cuts one way. It makes a **win** here weak evidence — and it makes a **loss** here strong
evidence, because the bias ran toward this project and the result went the other way anyway.
This is the home fixture, with the home key, and it was lost by eight points.

## The one number that goes the other way

This project reported **0.25 decoys per run against `mantis`'s 1.00** — four times fewer false
positives on the 50 constructs planted to look vulnerable and be ruled out. That is real, it is
this repository's stated first-class defect, and it is the only column it leads.

**It does not rescue the primary and is not offered as doing so.** Recall 79.6% against 88.0%
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

- **`mantis` run 1 was misdiagnosed as stalled and it was not.** Its workspace stopped growing
  for five minutes and this page, in its first version, recorded it as a run that did not
  happen. It completed: **70 minutes, 682 tool calls, 461k tokens** — several times the cost of
  any other run in the round — and scored 81%. Including it moves `mantis` from 90.1% to
  **88.0%** and the gap from 10.5 to **8.3**. Both numbers stay here because the first was
  published before the run landed. The verdict is unchanged: refuted.
- **`Tencent/AI-Infra-Guard` was excluded**, and that exclusion stands: all four of its skills
  were read, `aig-scanner` requires a remote `taskapi` these offline rounds cannot reach, and
  the rest scope to the OpenClaw environment, to skills, and to red-teaming agents.
- **No claim about real code.** This is eleven products this project wrote. On `pyload`, Django
  and `Netflix/lemur` — code nobody here wrote — every arm scored at or near zero, and nothing
  here changes that.

## Where the eight points actually are — and the hypothesis this page first published was wrong

The first version of this section credited `mantis`'s **adversarial review stage**. Comparing
the two arms defect by defect against the key says otherwise, and the arithmetic is not subtle:

| | this project | `mantis` |
|---|---|---|
| detections per run | 43.0 | 47.5 |
| **reach** — union over its 4 runs | **49 / 54** | **52 / 54** |
| **stable** — found in *all* 4 runs | **36 / 54** | **40 / 54** |
| lost per run from inside its own reach | **6.0** | 4.5 |

**The knowledge gap is three defects.** Exactly three are found by `mantis` and never by this
project across any run: `P-19` (`SUP-03`, an install-time hook in `node-supply`) and `P-45` /
`P-47` (both `INF-24`, in `intake-portal`). Nothing is the other way round — `mantis`'s reach
contains this project's entirely.

**The rest is consistency.** This project reaches 49 of 54 and reports 43 in an average run: it
**drops six defects per run that it is demonstrably able to find**, and which six varies. That
is where the gap lives, and it is not a gap in what the corpus knows.

So the adversarial review stage is the wrong suspect. A stage that argues against its own
findings *removes* them; it cannot raise recall. It is not even buying `mantis` precision here
— it reported **1.00 decoys per run against this project's 0.25**.

And it is not dispatch either: this project's runs reached **all three** of those files, in all
four runs. They reported **exactly one finding in each**, every time, where `mantis` reported
one to four.

**The mechanism is depth per file.** On the 14 files carrying more than one planted defect —
**34 of the 54** — this project reported **2.05 findings per file against `mantis`'s 2.50**, and
reached two or more findings in **8.8 of 14 files against 11.5**:

| file | planted | this project | `mantis` |
|---|---|---|---|
| `node-supply/package.json` | 2 | **1.0** | 3.2 |
| `terraform-platform/.github/workflows/deploy.yml` | 2 | **2.0** | 3.0 |
| `rag-agent/agent/memory.py` | 2 | **1.8** | 2.5 |
| `cli-packer/packer.py` | 5 | 4.5 | 4.8 |

A long Python file gets worked through and the arms tie. A twenty-line manifest gets read,
yields its one obvious problem, and is closed. **This project finds something and stops**, and
that accounts for the gap without needing any hypothesis about fan-out or review stages.

`mantis` fanning out eleven auditors, one per product, is a plausible *cause* of that depth —
smaller surface per auditor — but the *symptom* is measured and the cause is not.

## What was changed because of it

[`references/coverage.md`](../../../skills/ethical-hacker-squad/references/coverage.md), cited
by all seven auditing roles: `COV-01` a file that produced a finding is not a file that is
done; `COV-02` manifests and configuration are enumerated key by key rather than read for
*the* problem; `COV-03` declare per file how many distinct defects you looked for and found.

It carries the measurement above, and it says explicitly that it is **not** a licence to report
more — the 0.25 decoy rate is the one column this project led and is not to be traded away.

## The answer to the question that prompted the round
## The answer to the question that prompted the round

*"Are we already the best hacker repo for different products or services built with
vibecoding?"*

**No.** On the only corpus where this project could plausibly have led, against the only
competitor that claims the same job, run through its own entry point: **it is behind by ten
points of recall, and it leads on false positives alone.**

Per the multiplicity commitment, **this corpus is retired for this question.** The next step is
not another run here — it is reading how `mantis` gets those eight points.
