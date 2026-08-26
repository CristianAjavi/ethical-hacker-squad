# 2026-08-26 — the rules work, and they bought recall with noise

> **The arms were not given the same instruction.** Every `mantis` launch in this round
> carried *run the stages inline rather than spawning sub-agents*, and no `ours` launch
> carried anything like it. `mantis` is a supervised nineteen-skill pipeline; told to run
> inline it becomes what this project already is. This round therefore compares two prose
> corpora executed by one agent each, **not two products as they ship**. The numbers stand;
> the claim narrows. See [`../CORRECTION-inline-constraint.md`](../CORRECTION-inline-constraint.md).

> **The harness bypassed a shipped control.** Every round's prompt asked for a report shape
> without the `triage` field that `findings.schema.json` requires and
> `gate-findings-artifact.sh` enforces, so no arm was ever obliged to name and answer a
> false-positive rule before reporting. The decoy numbers below were measured with this
> project's own false-positive control switched off at the door. See
> [`../2026-08-26-refutation-stage/HARNESS-DEFECT.md`](../2026-08-26-refutation-stage/HARNESS-DEFECT.md).
> The recall numbers are unaffected and no verdict here is edited.

**Not supported.** The band was a conjunction and it was written that way on purpose: recall
ahead by ≥ 5 points **and** a decoy rate no higher. The first held. The second failed.

| arm | runs | recall | range | **decoys / run** | findings / run |
|---|---|---|---|---|---|
| **this project**, with `COV-01..03` | 4 | **97.8%** | 94 – 100% | **9.75** | 68.5 |
| **`google/mantis`** @ `56377ad` | 4 | 91.9% | 82 – 97% | **5.25** | 46.2 |

Ahead by **+5.9 points** of recall over 34 planted defects in six services this project's
procedures had never seen — and reporting **nearly twice as many decoys**, on the 26 constructs
planted to look vulnerable and be ruled out.

## The mechanism test passed, which is the point

`COV-01` (a file that produced a finding is not done) and `COV-02` (manifests are enumerated
key by key) predicted a specific change, registered with its own band before the arms ran:

| on the 10 multi-defect files | this project | `mantis` |
|---|---|---|
| findings per file | **2.98** | 2.50 |
| files reaching 2+ findings | **10.0 / 10** | 8.8 / 10 |

**Confirmed.** Last round this project reported 2.05 per multi-defect file against `mantis`'s
2.50 and reached two-or-more in 8.8 of 14 against 11.5. The rules inverted both. The diagnosis
was right and the fix does what it was built to do.

## And it cost exactly what the rules themselves said not to spend

`coverage.md` closes with:

> It does not say to report more. Padding a report with weak findings is the defect
> `triage.md` exists to prevent, and this corpus's decoy rate — 0.25 per run against `mantis`'s
> 1.00 — is the one number it led on in that round and is not to be traded away.

**It was traded away.** 9.75 decoys per run against 5.25. Writing the warning into the file did
not prevent the thing the file warns about, which is the same lesson as the run whose evidence
was ignored by `.gitignore` after a prior page had explained the trap in prose: **a sentence is
not a control.**

## Sensitivity — the honest check on a number this file's author chose

The key carries a single line per defect, so a match window had to be picked. It was not
picked to flatter:

| window | ours | `mantis` | gap | decoys ours / `mantis` |
|---|---|---|---|---|
| ±0 (symbol or exact line) | 92.6% | 87.5% | **+5.1** | 6.75 / 4.00 |
| ±3 | 94.1% | 87.5% | **+6.6** | 8.00 / 5.00 |
| ±6 *(reported)* | 97.8% | 91.9% | **+5.9** | 9.75 / 5.25 |
| ±12 | 99.3% | 95.6% | **+3.7** | 11.50 / 6.75 |

The recall lead is **window-dependent at the margin** — at ±12 it falls below the 5-point
threshold. The decoy failure is not: this project reports more decoys at every window. The
verdict does not rest on the window; the *magnitude* of the recall lead does, and that is said
here rather than left for someone to find.

## What this changes about `mantis`

Two rounds ago this page's author wrote that `mantis`'s adversarial review stage — the one that
argues against its own findings before reporting — could not explain its recall lead. That was
right, and it was the wrong question. **It explains its precision**, and precision is now this
project's failure: depth generates candidates, and something has to kill the bad ones.

`mantis` runs 52 raw findings down to 47 through `mantis-review`, and its own report names the
constraint that killed each. This project's triage is applied by the same agent that made the
finding. That is the next thing to test, and it is not tested here.

## Where this leaves the question

*"Are we the best?"* — **still no, and for a different reason than last time.** Last round the
answer was "behind on recall." This round it is "ahead on recall, worse on false positives, so
the band is not met." A product that finds more and cries wolf more has not won; this
repository's own doctrine calls a false positive its first-class defect.

Per the multiplicity commitment, **this corpus is retired for this question.**

## What ships

All eight reports in [`runs/`](runs/), the [key](key.json), the [scorer](score.py) with its
[battery](score.selftest.sh) (6 cases, including a decoy-only arm and the three-valid-run
floor), the [pre-registration](PREREGISTRATION.md) written before its author saw the corpus,
and the [deviations](LIMITS.md) — the session's authentication failure mid-round, and the extra
instruction two relaunched `mantis` runs carry — recorded before anything was scored.
