# 2026-08-26 — the precision half, met at last, and the recall half lost in the same breath

**Inconclusive.** Ninth round. For the first time the decoy condition is met — and the recall
condition fails.

| arm | runs | recall | range | decoys / run | findings / run |
|---|---|---|---|---|---|
| **this project**, `scope` required | 4 | 80.9% | 76 – 84% | **7.50** | 45.8 |
| **`google/mantis`** @ `56377ad` | 4 | 80.3% | 79 – 84% | 10.75 | 45.2 |

+0.7 points of recall, which is a quarter of a defect, and **3.25 fewer decoys per run**. Eight
rounds failed on precision; this one meets precision and ties on recall.

## The registered prediction, read strictly

> `narrowed-sibling` decoys reported fall **to at or below** `mantis`'s rate on that shape, and
> total recall stays within 3 points of 74.3%.

| | previous round | this round |
|---|---|---|
| this project on `narrowed-sibling` | 1.75 | **1.50** |
| `mantis` on the same | 0.25 | **1.25** |
| excess | **+1.50** | **+0.25** |

The excess collapsed. **The prediction is still not met**, because +0.25 is not *at or below*,
and the honest reason matters more than the arithmetic: **this project moved 1.75 → 1.50 and
`mantis` moved 0.25 → 1.25.** Most of the collapse is the competitor getting worse on this
corpus, not this project getting better.

Cross-corpus absolutes are not comparable and nothing here treats them as though they were.
What is comparable is within this round, and within this round the target shape is **parity, not
a win**.

## What did move, and it is not what the field was aimed at

| shape | planted | this project | `mantis` | excess |
|---|---|---|---|---|
| `narrowed-sibling` *(the target)* | 5 | 1.50 | 1.25 | **+0.25** |
| `coerced-upstream` | 5 | 2.75 | 3.00 | −0.25 |
| `public-sample` | 5 | 1.00 | 1.00 | 0.00 |
| `unreachable-earlier-layer` | 5 | 0.50 | 0.50 | 0.00 |
| `constrained-elsewhere` | 5 | **1.00** | 2.50 | **−1.50** |
| `dead-path` | 5 | **0.75** | 2.50 | **−1.75** |
| **total** | 30 | **7.50** | 10.75 | **−3.25** |

**The whole −3.25 comes from two shapes the `scope` field was not written for.** On
`constrained-elsewhere` and `dead-path` this project is 3.25 decoys per run ahead; on the shape
the field targets it is 0.25 behind.

A field asking *where does this actually apply, and how did you establish that* plausibly helps
against a construct constrained in another file, and against a path with no callers — both are
answered by enumerating where something takes effect. That reading is **not registered and not
measured**, and it is written here as the next round's question rather than this one's finding.

## What this costs to say plainly

The one generalisation this ledger had — *a required field moves a number where a rule does
not* — is **half-supported and half-refuted by the same table**. The field moved a total by 3.25
decoys and did not move the number it was written for. `FP-11`, the rule, moved nothing at all.
So a field still beats a rule, and **aiming either one at a specific shape still fails.**

## Where the ledger stands after nine rounds

| round | recall | decoys | band |
|---|---|---|---|
| eleven products | behind 8.3 | 0.25 / 1.00 | refuted |
| coverage rules | ahead 5.9 | 9.75 / 5.25 | not supported |
| refutation stage | ahead 11.8 | 9.50 / 3.75 | not supported |
| artifact contract | level | 6.00 / 7.75 | refuted |
| composition | level | 5.00 / 4.75 | refuted |
| join effect *(within-arm)* | +3.1 composition | — | not supported |
| four tools | ahead 5.9 | 3.00 / 2.00 | not supported |
| FP-11 | ahead 9.0 | 5.50 / 4.25 | not supported |
| **scope field** | **level (+0.7)** | **7.50 / 10.75 — first time ahead** | **inconclusive** |

**No.** Nine rounds. Four met the recall half, one met the decoy half, **none met both.**

This corpus is retired.
