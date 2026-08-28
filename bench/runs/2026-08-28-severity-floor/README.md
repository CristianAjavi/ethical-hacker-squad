# 2026-08-28 — the floor was refuted, and it exposed something worse than noise

**Not supported**, twelfth time. And the registered rule for this outcome fires: **the floor is
withdrawn, not tuned.**

| | recall | decoys / run | findings / run |
|---|---|---|---|
| **baseline**, everything scored | | | |
| this project | 76.6% | 6.00 | 70.7 |
| `mantis` | 67.6% | 3.67 | 38.0 |
| **with the registered floor**, `low` not scored | | | |
| this project | **69.4%** | 3.33 | 50.0 |
| `mantis` | 56.8% | **0.33** | 30.0 |

The floor cut this project's decoys from 6.00 to 3.33 — and cut `mantis`'s from 3.67 to **0.33**.
The gap widened from 2.3 decoys to 3.0, and in ratio from 1.6× to **10×**. It also cost **7.2
points of recall**.

The pre-registration named that outcome and its consequence before the runs:

> **Recall falls by more than 3 points.** Then `low` was carrying real defects after all, the floor
> costs more than it saves, and it is **withdrawn rather than tuned to a different threshold.**

So it is withdrawn. The post-hoc observation from the tenth and eleventh rounds — where `low`
carried 0.065 defects and 0.293 decoys per finding — **did not replicate.**

## What the floor actually discarded

The registered secondary, and the reason this round matters more than its verdict:

| arm | `low` discarded / run | **real defects inside** | decoys inside |
|---|---|---|---|
| this project | 20.7 | **5.3** | 2.7 |
| `mantis` | 8.0 | 4.0 | 3.3 |

The floor threw away more real defects than decoys, in both arms. And the key's own honest
severities say what those defects were: of the nine planted defects this project labelled `low`,
**five are `high`**, two are `medium`, and two are actually `low`.

## The finding: this project mis-rates high-severity defects as low

Matching every real defect each arm found against the key's `true_severity`:

| arm | matches | **underrates** | overrates | **`high` called `low`** |
|---|---|---|---|---|
| this project | 64% | 23% | 13% | **10** |
| `mantis` | 59% | 34% | 7% | **0** |

This project agrees with the key more often overall — and still puts **ten high-severity defects in
the bucket a reader skips.** `mantis` underrates more often in total and **never** falls two steps;
its errors are `high`→`medium`, which a reader still reads.

**An auditor that finds an authorization bypass and calls it low is worse than one that misses it**,
because it hands the reader a written reason to ignore it. That is a defect of this product, it is
larger than the recall lead this round posted, and no previous round could have seen it because no
previous corpus carried an honest severity for each planted defect.

## And the mis-rating is predicted by the report's own field

Post-hoc on this round's artifacts, so it is a hypothesis for the next round rather than a result
of this one — but it is mechanical, not judged, and it is sharp.

Splitting every real defect each arm found by how many files its own `scope.applies_to` names:

| arm | scope names **one** file | scope names **two or more** |
|---|---|---|
| this project | 40 findings, **40% underrated** | 44 findings, **7% underrated** |
| `mantis` | 16 findings, 38% underrated | 55 findings, 33% underrated |

**This project's severity is right when it established reach and wrong when it did not** — a nearly
six-fold difference. `mantis` shows no such relationship, so its underrating has some other cause,
and it never falls two steps.

All ten of the `high`-called-`low` findings are `kind: composition`, and in three of the four
inspected the `applies_to` names a single file. Reading them, the pattern is not that the defect
was missed: `list() builds a tenant-and-status filter it never executes` describes the mechanism
correctly and never records that the ignored filter is the **tenant** one. The line was found, the
description is accurate, and the chain was never followed — so severity was assigned to the blast
radius of a line rather than of what it reaches.

The useful part is that **the report already says which case it is in.** A composition finding whose
`applies_to` names one file has an unestablished reach, and the severity attached to it is
unreliable by 40%.

**A check built on that was designed and then refused, because measuring it first killed it.** The
intended flag was a bookkeeping mismatch: a finding whose `evidence` names a file its `applies_to`
does not. Measured on the same artifacts, the signal runs **backwards** — 14% underrated when the
mismatch is present against **30%** when the scope is fully recorded. Findings with tidy scope are
underrated *more*.

So breadth predicts and mismatch does not, and the two are consistent: what matters is how many
files were actually traced, not whether the bookkeeping about them is complete. That leaves no
check to build, because a single-file `applies_to` is not a defect — most real findings have one.
What it leaves is a disclosure a reader can act on: **a finding whose reach was never established
carries a severity that is 40% unreliable in the dangerous direction**, and this project can say so
without pretending to have fixed it.

## What it forces

- **The floor is dead** as a scoring rule and as a product idea, on the evidence of the round that
  was built to test it.
- **The next lever is severity calibration, not volume.** The gap between finding a defect and
  rating it correctly is now measured, and it is where this project loses something a user would
  actually feel.
- **The eleventh round's post-hoc cut is retired for good.** It flattered this project on two
  corpora and reversed on the third, which is what a corpus-specific artefact does.

## Where the ledger stands after twelve rounds

**No.** Twelve rounds. Seven met the recall half, one met the decoy half, **none met both.**

## What ships

All twelve reports in [`runs/`](runs/), the [key](key.json) with `true_severity` on every planted
defect, both scorings in [`SCORE.txt`](SCORE.txt), and the
[pre-registration](PREREGISTRATION.md) — including the sentence that decided what to do with this
result, written before the corpus existed.

Two corpus deviations, recorded before the numbers were read: `dead-path` got 2 decoys and
`same-line` 4, against the even spread requested, so the by-shape secondary is weaker this round
than in the eleventh. The corpus builder also fixed four real defects that were in neither list
and corrected 16 cited line spans after re-reading; the key was verified independently against the
final files, 0 line or path errors.

This corpus is retired.
