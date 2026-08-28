# 2026-08-29 — the metric was measuring something else, and this project loses on both definitions

**Refuted**, thirteenth round, on **both** the old metric and the corrected one. `mantis`'s recall
is higher than this project's in each.

| definition | this project | `mantis` | recall gap | verdict |
|---|---|---|---|---|
| **old** — any finding within six lines of a decoy | 78.9% recall, 10.00 decoys | 85.1%, 5.33 | **−6.1** | **refuted** |
| **new** — counts only when `cwe` equals the decoy's `baits_cwe` | 76.3%, 5.67 | 80.7%, 3.67 | **−4.4** | **refuted** |

This project's recall range is **45 – 97%** across three runs. That spread is larger than the gap
being argued about, and it is the honest headline of the round: on this corpus the squad is not
merely behind, it is **inconsistent**.

## A correction to this page, caught after it was first published

**The first version of this page reported +4.4 and "not supported".** It was wrong. `ours-3` was
copied out of the run directory and scored **while the agent that produced it was still writing**:
the file had 68 findings at the moment of the copy and 41 when the agent finished. The intermediate
state was better for this project, so the published numbers flattered it.

What caught it was not a gate: it was a scheduler notice saying that agent was still running, read
after the page had already been committed and pushed. The check that should have existed did not.

So the rule this earns, and it costs nothing to keep: **a report may not be scored until the agent
that produces it has reported completion.** The correct numbers are above, the wrong ones are named
here rather than quietly replaced, and the verdict moved against this project in both definitions.

## The defect the round was built to measure is real, and it is asymmetric

`off-claim` — a finding sitting beside a planted decoy while asserting a different CWE:

| arm | decoy-adjacent findings | **off-claim** | share |
|---|---|---|---|
| this project | 13.33 / run | **7.67** | **58%** |
| `mantis` | 5.33 / run | 1.67 | 31% |

**Nearly six in ten of this project's counted false positives were never the false positive the
corpus author planted.** For twelve rounds the decoy half counted them anyway, nearly twice as often
against this project as against the competitor.

Correcting it removes 43% of this project's decoy hits and 31% of `mantis`'s — it helps the party
that proposed it, by more, which is why it was
[pre-registered before the corpus existed](PREREGISTRATION.md) and scored both ways. **And on the
corrected metric this project is still worse, and now also behind on recall.**

Recall moves between the two scorings (78.9% → 76.3%) because a finding can sit within six lines of
both a planted defect and a decoy, so removing off-claim entries removes a few real detections too.
That is a property of line-proximity matching, not of the CWE rule, and it is reported rather than
netted out.

## What this forces, as registered

The pre-registration named this outcome: *if the off-claim bucket is large, the decoy half has been
measuring something other than what it claimed for twelve rounds, and every published decoy rate
needs restating.*

- **Every decoy figure in this ledger is an upper bound**, and the pages that quote one say so.
- **The restatement is scoped and not performed.** Retired corpora carry no `baits_cwe`; rewriting a
  closed round from a field invented afterwards is the move these pages refuse.
- **The ninth round is the one to re-read first** — the only round whose decoy half this project won,
  measured with the same defective rule.

## Where the ledger stands after thirteen rounds

**No.** Thirteen rounds. Eight met the recall half, one met the decoy half, **none met both** — and
that one now carries a caveat about the metric that produced it.

## What also came out of it

**Class breadth, measured for the first time**, because no round before required the identifier:
this project names **46 distinct CWEs per run across 64 findings**, `mantis` 26 across 42 — almost
the same findings-per-class ratio, so coverage rather than finer labelling. It is the one dimension
where this project is clearly ahead on this corpus, and it is not part of the band.

**The blind stage moved a severity upward.** In `ours-2`, `VER-09` took 83 assertions as
location-only, killed two with named lines, lowered two findings to informational — and **raised**
one from low to medium after establishing pre-authentication reachability. A blind critic that only
removes is a filter; one that corrects in both directions is a reviewer. One run, not claimed as
more, and directly relevant to [the twelfth round's finding](../2026-08-28-severity-floor/) that
this project puts ten high-severity defects in the bucket a reader skips.

This corpus is retired.
