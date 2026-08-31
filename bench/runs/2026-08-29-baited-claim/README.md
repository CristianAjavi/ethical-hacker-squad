# 2026-08-29 — the metric was measuring something else, and correcting it still is not enough

**The band was not met on either definition**, thirteenth round — and the two scorings do
not fail the same way, so the page names each verdict as [`SCORE.txt`](SCORE.txt) produced
it rather than collapsing both into one word: **inconclusive** on the old definition, where
the recall lead itself fell short of the registered 5 points; **not supported** on the new
one, where recall cleared it and the decoy half failed.

| definition | this project | `mantis` | recall gap | verdict |
|---|---|---|---|---|
| **old** — any finding within six lines of a decoy | 89.5% recall, 11.67 decoys | 85.1%, 5.33 | +4.4 | **inconclusive** — under 5 points, decoys worse |
| **new** — counts only when `cwe` equals the decoy's `baits_cwe` | 86.8%, 6.33 | 80.7%, 3.67 | +6.1 | **not supported** — recall met, decoys fail |

## This page was published wrong twice before it was right

Both wrong versions came from the same mistake: **scoring a report while the agent producing it was
still writing.** The file passed through 68 findings, then 41, then 69 — and each intermediate got
scored and published.

| version | what was scored | published | actual |
|---|---|---|---|
| first | `ours-3` at 68 findings — later found to be **contaminated with lane files from an unrelated earlier run** that the agent itself quarantined on timestamps | +4.4, not supported | close to correct by accident |
| second | `ours-3` at 41 findings, 3 of 6 components, still mid-write | **−6.1, refuted** | wrong |
| third *(this one)* | `ours-3` final, 69 findings, agent reported complete | +4.4, not supported | correct |

The second version is the worse failure: it was issued **as a correction**, with a rule attached
saying *a report may not be scored until its agent has reported completion* — and it was itself
scored before that agent reported. Writing the rule and breaking it in the same commit is the part
worth keeping on the page.

What finally satisfied the rule was the agent's own completion notice, which also disclosed the
contamination: its first merge had silently absorbed another run's lanes and produced a
plausible six-component report. Had that shipped, it would have carried an Airflow lane that never
ran — the exact failure `references/team.md` records, arriving from a direction nobody had guarded.

## The run that makes the round scoreable is itself partial

`ours-3` declares two gaps in its own provenance: the **Airflow lane was never staffed**, and the
**blind `VER-09` pass never ran**. It audited 5 of 6 components with no adversarial stage.

Dropping it leaves two runs, and the scorer answers **UNMEASURABLE — only 2 valid runs**. So this
round is scoreable *only* by including a partial run, and every number above carries that: this
project's recall is measured with one arm short of a component, and its decoy count with one run
that never faced its own critic.

## The defect the round was built to measure is real, and asymmetric

`off-claim` — a finding beside a planted decoy asserting a different CWE:

| arm | decoy-adjacent | **off-claim** | share |
|---|---|---|---|
| this project | 15.33 / run | **9.00** | **59%** |
| `mantis` | 5.33 / run | 1.67 | 31% |

**Nearly six in ten of this project's counted false positives were never the false positive the
corpus author planted**, and for twelve rounds the decoy half counted them anyway — nearly twice as
often against this project as against the competitor.

Correcting it removes 46% of this project's decoy hits and 31% of `mantis`'s. It helps the party
that proposed it, by more, which is why it was [pre-registered](PREREGISTRATION.md) and scored both
ways. **On the corrected metric this project is still worse: 6.33 against 3.67.**

## What this forces, as registered

- **Every decoy figure in this ledger is an upper bound**, and the pages that quote one say so.
- **The restatement is scoped and not performed**: retired corpora carry no `baits_cwe`, and
  rewriting a closed round from a field invented afterwards is the move these pages refuse.
- **The ninth round is the one to re-read first** — the only round whose decoy half this project won,
  measured with the same defective rule.

## Where the ledger stands after thirteen rounds

**No.** Thirteen rounds. Eight met the recall half, one met the decoy half, **none met both** — and
that one now carries a caveat about the metric that produced it.

## What also came out of it

**Class breadth, measured for the first time** because no round before required the identifier:
this project names **46 distinct CWEs per run**, `mantis` 26, at almost the same findings-per-class
ratio. Coverage rather than finer labelling, and not part of the band.

**The blind stage moved a severity upward.** In `ours-2`, `VER-09` took 83 assertions as
location-only, killed two, lowered two — and **raised** one from low to medium on pre-authentication
reachability. Directly relevant to [the twelfth round's finding](../2026-08-28-severity-floor/) that
this project puts high-severity defects in the bucket a reader skips. One run, not claimed as more —
and notably the run where the stage ran at all, since `ours-3` had no budget left for it.

This corpus is retired.
