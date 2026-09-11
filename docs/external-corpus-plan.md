# Plan — measuring this corpus against a third-party-labelled corpus

**Status: a plan. Nothing here has been run.** It exists so the decision to spend
model runs can be taken with the figures on the table instead of after the bill.
Running it is a spending decision and it belongs to the owner of this repository.

## The hole this closes

`bench/README.md` opens with the honest row: no product in this field publishes a
number for how much it actually finds, this one included. Every detection number
this repository has ever produced came from one of two places:

- **Cases this project planted.** `bench/ground-truth.json` says so in its own
  `warning` field, and every round built on it repeats it. `intake-portal` is the
  clearest example: recall 0.83 against 0.48 and 0.20, and the round reported it
  as weak and claimed it as nothing, because the defect was written here.
- **Two rounds on code nobody here wrote**, both against `pyload/pyload` at the
  parent of its own fix commit. The key is a public advisory and the finding is
  real — but it is **one defect**. One case is not a rate. It cannot produce a
  denominator, it cannot produce an interval, and it cannot be compared against a
  competitor's number without overclaiming.

A third-party-labelled corpus is the only thing that fixes this, because the
label has to come from somebody with no stake in the answer.

## Candidate corpora, and the one this plan picks

| Corpus | Label written by | Subject | Gives a false-positive rate? | Verdict |
|---|---|---|---|---|
| **A. Public advisories with a fix commit** (OSV / GHSA + the commit that fixed it) | The project that shipped the fix | Whole repository, real code | No | **Primary** |
| **B. OWASP Benchmark** | The benchmark authors | Synthetic Java, per-case | **Yes** — it labels the true and the false cases | **Secondary, for precision only** |
| C. NIST Juliet / SARD | NIST | Synthetic, per-case, highly templated | Partly | Rejected |
| D. PrimeVul / CVEFixes / BigVul | Mined from commit history | One function, out of its repository | No | Rejected |

**Why A is primary.** It is the only option where the subject matches what this
product actually does — a whole repository, cross-file, no pointer to the file —
and the label is a public commit anyone can re-check. The machinery already
exists: `bench/external/*.json` holds the ecosystem pulls for npm, pip, go and
maven, and `bench/runs/2026-08-25-external-log-injection/` is a worked example of
exactly one case of this shape, end to end.

**Why B is secondary and narrow.** A has no negatives: an advisory tells you what
IS there and never what is not, so it can measure recall and cannot measure
noise. A published recall with no companion false-positive rate is half a number,
and the half that flatters. B is synthetic and Java-only, so it may not be used
for a headline detection claim — only for the false-positive rate, and labelled
as synthetic wherever it appears.

**Why C and D are rejected.** Juliet's cases are templated to the point where a
score measures template recognition, not auditing. D hands over a single function
with its repository removed, which measures a different product than this one:
the cross-file path is where this corpus's procedures live.

### What is NOT established about the corpora

**NO-MEDIDO.** The sizes, licences and current maintenance status of B, C and D
are prior knowledge and were **not verified in the session that wrote this**, by
instruction. Before a single model run is spent, each must be re-checked against
its source, and the licence must be confirmed to permit publishing per-case
results. If a corpus cannot be confirmed, it is dropped rather than cited.

Corpus A needs no such check — it is assembled from advisories one at a time —
but each case does need the verification below.

## Sampling

**Population.** Advisories from 2024-01-01 onward, in ecosystems this corpus has
procedures for, whose fix commit touches **one to three files** and whose parent
commit still builds. The upper bound on files is not convenience: a fix spanning
twenty files is usually a refactor, and "did the auditor find it" stops having a
single answer.

**Sample size: 40 cases**, drawn at random from the eligible population with the
seed committed to the pre-registration before the draw.

Why 40 and not a rounder number. The published quantity is a proportion, so the
width of its 95% Wilson interval at the worst case (p = 0.5) is what the sample
size buys:

| n | interval half-width at p = 0.5 |
|---|---|
| 8 | ±0.31 |
| 20 | ±0.21 |
| **40** | **±0.15** |
| 100 | ±0.10 |

At n = 40 two products whose true rates differ by about a third are
distinguishable, and two that differ by a tenth are not. That is the honest limit
of this budget and the published text has to say so. Going to n = 100 costs two
and a half times as much for a third less width; that trade is Cristian's to
make, not this document's.

**Stratification.** The 40 are drawn to hold at least 8 cases in each of the four
ecosystems already pulled in `bench/external/`, so a single ecosystem cannot carry
the result.

**Per-case verification, before it enters the sample.** The defect must be
confirmed present at the parent commit by reading the code, not the advisory
summary — the `pyload` round did exactly this and it is what makes its key
checkable. `.git` is removed from the copy handed to every arm, so no history is
reachable. A case that cannot be confirmed is replaced by the next draw, and the
replacement is logged.

## Cost, in model runs

The unit this repository counts in is a **model run**: one complete agent pass
over one repository copy. One run is many API calls internally; this repository
has never recorded tokens or money for a round, so the dollar cost is **NO
MEDIDO** and Stage 0 below exists partly to measure it.

**Arms: 3.** This corpus, plus the two competitors that have testified before —
`Tencent/AI-Infra-Guard` and `google/mantis` — each at a pinned commit.

**Runs per case per arm: 3.** Not 1: the rounds already run show the same arm
giving different answers on the same tree (0 of 6 on one case, 1 of 4 on
another). One run per case would publish that variance as a difference between
products.

| Stage | Cases | Runs | Purpose |
|---|---|---|---|
| **Stage 0 — calibration** | 8 | 8 × 3 × 3 = **72** | Measure between-run variance and the real cost of a run. Produces no published number. |
| **Stage 1 — the measurement** | 32 more | 32 × 3 × 3 = **288** | The sample the number comes from. |
| **Total** | 40 | **360 model runs** | |

Stage 0 is a real gate and not a warm-up: **after Stage 0 the round stops by
default** and only continues if Cristian says so with the Stage 0 figures in
hand. It costs 20% of the budget to find out whether the other 80% can answer the
question.

## The stopping rule, fixed before the first run

Committed to `bench/runs/<date>-external-corpus/PREREGISTRATION.md` **before a
single model call**, as every round in this directory has been.

1. **Exhaustion.** 360 runs is a hard ceiling. On reaching it, whatever has been
   measured is published with its n, finished or not.
2. **Futility, decided at Stage 0.** If after 8 cases the gap between this corpus
   and the best competitor is smaller than the between-run variance measured in
   the same stage, the round stops and publishes *"not distinguishable at n = 8;
   separating a gap this size would need N cases"*, with N computed from the
   measured variance. A null result published with its required-n is a result.
3. **Engagement, per arm.** An arm that does not reach the file does not testify —
   the rule this corpus already applies in `2026-08-25-vibecoding-comparative`,
   where two zeros were read as silence rather than agreement. If an arm is silent
   on more than a third of its cases, that arm is reported as *did not engage* and
   gets **no rate at all**, rather than a low one.
4. **Contamination.** If any case turns out to be in a public training-set corpus
   under a searchable name, it is removed and logged. Its removal is reported.
5. **The rule that is not allowed.** The round may NOT stop because the numbers
   came out well, and may not add cases because they came out badly. The sample is
   drawn once, from a seed committed in advance.

## What would actually get published

One table, one row per arm:

```
                          reached   found   rate    95% CI
  this corpus               38/40    22      0.58   0.42-0.72
  Tencent/AI-Infra-Guard    31/40    11      0.35   0.21-0.53
  google/mantis             ...
```

(The figures above are **shape, not results**. Nothing has been run.)

Binding rules on that table:

- **`reached` is a separate column from `found`,** and the rate's denominator is
  `reached`, never 40. Hiding non-engagement in the denominator turns "could not
  read the repository" into "read it and found nothing".
- **Every rate carries its 95% Wilson interval and its n.** A rate without an
  interval at n = 40 is a number pretending to a precision it does not have.
- **If two intervals overlap, the published sentence says they overlap.** No
  ranking, no "N% better", no ordinal language over overlapping intervals.
- **Corpus B's false-positive rate is published in its own table**, labelled
  synthetic and Java-only, and is never combined with A into a single score.
- **The per-case results ship with it** — case, advisory, pinned commit, each
  arm's verdict — so the number is re-checkable by whoever doubts it. A published
  rate whose cases are not published is a claim, not a measurement.
- **The competitors' commits are pinned and named,** and
  `scripts/gh/competitive-freshness.sh` decides when that pin has gone stale.

## What this plan is still missing

- The eligible population has not been enumerated, so the draw cannot be
  performed yet. That costs API calls but **zero model runs**, and is the sensible
  next step if this goes forward.
- Licence confirmation for corpus B (see NO-MEDIDO above).
- A run harness for arms 2 and 3 at 3 runs × 40 cases. The existing rounds drove
  them by hand at a much smaller scale; 240 competitor runs by hand is not a
  plan, it is a wish.

## If it does not go forward

Then `bench/README.md` keeps the empty row and keeps saying why it is empty,
which is what it does today and is not dishonest. What may not happen is the
third option: publishing the planted-case numbers without the sentence that says
this project wrote the defects.

<!-- Written 2026-09-10 against the baseline at docs/competitive-baseline.json
     (measured_on 2026-08-22, 11 products, 3 declined). If the field has moved,
     the arms are what move with it -- the corpus design does not. -->
