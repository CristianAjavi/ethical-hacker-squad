# 2026-08-29 — the metric was measuring something else, correcting it helps this project, and it still loses

**Not supported**, thirteenth time — on **both** definitions, which is the point of the round.

| definition | this project | `mantis` | recall gap | verdict |
|---|---|---|---|---|
| **old** — any finding within six lines of a decoy | 89.5% recall, **11.33** decoys | 85.1%, 5.33 | +4.4 | fails **both** halves |
| **new** — counts only when the finding's `cwe` equals the decoy's `baits_cwe` | 86.8% recall, **6.33** decoys | 80.7%, 3.67 | +6.1 | recall met, decoys fail |

## The defect the round was built to measure is real, and it is asymmetric

`off-claim` — a finding sitting beside a planted decoy while asserting a different CWE:

| arm | decoy-adjacent findings | **off-claim** | share |
|---|---|---|---|
| this project | 15.33 / run | **9.00** | **59%** |
| `mantis` | 5.33 / run | 1.67 | 31% |

**Nearly six in ten of this project's counted false positives were never the false positive the
corpus author planted.** For twelve rounds the decoy half of the band counted them anyway, and it
counted them nearly twice as often against this project as against the competitor.

## And correcting it does not rescue the round

The correction removes 44% of this project's decoy hits and 31% of `mantis`'s — it helps the party
that proposed it, by more, which is exactly why it was
[pre-registered before the corpus existed](PREREGISTRATION.md) and scored on both definitions.

**On the corrected metric this project is still worse: 6.33 against 3.67.** The recall half is met
at +6.1, the decoy half is not, and the band is a conjunction. A metric change that flatters its
author and still fails is the only kind worth adopting on the author's own evidence.

One honest wrinkle: recall moves between the two scorings (89.5% → 86.8%) because a finding can sit
within six lines of both a planted defect and a decoy, so removing off-claim entries removes a few
real detections too. That is a property of line-proximity matching, not of the CWE rule, and it is
reported rather than netted out.

## What this forces, as registered

The pre-registration named this outcome: *if the off-claim bucket is large, the decoy half has been
measuring something other than what it claimed for twelve rounds, and every published decoy rate
needs restating — including the ones that favoured this project.*

**The bucket is large.** So:

- **Every decoy figure in this ledger is an upper bound**, and the pages that quote one say so.
- **The scope of the restatement is stated and not performed here.** Retired corpora have no
  `baits_cwe`, so their off-claim share cannot be computed without re-authoring keys for corpora
  whose rounds are closed. Rewriting a retired round's numbers from a field invented afterwards is
  the move these pages refuse; the caveat travels with them instead.
- **The ninth round's `scope-field` result is the one to re-read first.** It is the only round whose
  decoy half this project *won*, and on this evidence that win was measured with the same defective
  rule.

## Where the ledger stands after thirteen rounds

**No.** Thirteen rounds. Eight met the recall half, one met the decoy half, **none met both** — and
the one that met the decoy half now carries a caveat about the metric that produced it.

## What also came out of it

**Class breadth, measured for the first time.** Nobody had required a CWE before, so no round could
count how many distinct defect classes an arm names: **this project 46 distinct identifiers across
71 findings per run, `mantis` 26 across 42.** Almost the same findings-per-class ratio, so it is
coverage rather than finer labelling.

**The blind stage moved a severity upward.** In `ours-2`, `VER-09` received 83 assertions as
location-only, killed two with named lines, lowered two findings to informational — and **raised**
one from low to medium after establishing it was reachable pre-authentication. A blind critic that
only ever removes is a filter; one that corrects in both directions is a reviewer, and this is the
first round where that is on record. It is one run, and it is not claimed as more.

This corpus is retired.
