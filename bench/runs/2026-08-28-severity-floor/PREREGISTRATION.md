# Pre-registration — a severity floor, declared before it is used

Written **after** an observation that favours this project, and published for that reason rather
than in spite of it.

## The observation, and why it is not a result

Classifying every finding of the tenth and eleventh rounds by the arm's own `severity`:

| arm | bucket | n | planted defects per finding | decoys per finding |
|---|---|---|---|---|
| this project | **`low`** | 92 | **0.065** | **0.293** |
| this project | `high` | 220 | 0.609 | 0.095 |
| `mantis` | `high` | 167 | 0.713 | 0.090 |

**This project's `low` findings are four and a half times likelier to sit on a decoy than on a real
defect.** At `high` the two arms are close. The extra volume is not spread across the report; it is
concentrated in one bucket the arm itself already labelled as least important.

Recomputing both rounds with `low` dropped: the eleventh would meet the band — recall unchanged,
decoys 5.67 against 7.00 — and the tenth still would not.

**That is not a claim that the band was met, and three separate reasons say so:**

1. **It is a filter chosen after seeing the data**, and it flips a verdict this project's way. The
   ledger has refused exactly this three times before: a confirmed-only cut, a ±40-line window, and
   re-scoring a retired corpus.
2. **It flips one round of two.** A real effect would not depend on which corpus it met.
3. **It was computed with a cruder matcher than the registered scorer** — 73.7% where the published
   figure is 81.6% — so it is not even in the same units as the verdicts it appears to overturn.

## So it is registered instead

The next round declares the floor **before any arm runs**: findings the arm itself labels `low`
are reported in a separate section and are not scored. Both arms, one rule, applied by `adapt.py`
with no per-arm branch.

## What each outcome forces

- **The band is met.** Then the eleven previous verdicts stand as measured, and what changed is a
  reporting decision that was available all along — which is a smaller and more honest claim than
  "the product improved".
- **The band is not met.** Then the observation above was corpus-specific noise, and the ledger has
  a fourth entry in the list of favourable post-hoc cuts it refused to adopt.
- **Recall falls by more than 3 points.** Then `low` was carrying real defects after all, the floor
  costs more than it saves, and it is withdrawn rather than tuned to a different threshold.

## Band, unchanged for the twelfth time

Supported iff recall exceeds `mantis`'s by **≥ 5 points** *and* the decoy rate is **not higher**.
Failed eleven times: six met the recall half, one met the decoy half, none met both.

## Registered secondaries

- **What the floor discards.** How many planted defects fall inside the dropped bucket, per arm. A
  floor that hides real defects to buy a number is worse than no floor, and this is the figure that
  says so.
- **Decoys per shape and per exculpation distance**, the cuts the last two rounds established.
- **Cost**, beside recall, as the tenth round started doing.

## Scoring and multiplicity

The registered scorer, unchanged, with `--sensitivity`; a fresh corpus, since v9 and v10 are
retired; floor of three valid runs per arm; at most two concurrent arms with four sub-agents each;
every arm instructed to write its report even if a stage never returns. One round, then retired.
