# 2026-08-26 — the refutation stage ran, and it changed nothing

**Not supported**, on the same conjunction as last round and the same failing half.

| arm | runs | recall | range | **decoys / run** | findings / run |
|---|---|---|---|---|---|
| **this project**, `COV-01..03` + `VER-09` | 4 | **96.3%** | 94 – 97% | **9.50** | 48.2 |
| **`google/mantis`** @ `56377ad` | 4 | 84.6% | 74 – 94% | **3.75** | 34.5 |

Ahead by **+11.8 points** of recall on six stacks none of these procedures had seen — GraphQL,
Lambda/SAM, Ruby/Sinatra, Java/Spring, Helm, a Chrome extension — and still reporting **two and
a half times** as many of the 29 decoys.

## The registered prediction was refuted, in its own words

> The decoy rate falls to at or below `mantis`'s, *and* recall stays within 3 points of 97.8%.
>
> **If decoys do not fall** — `VER-09` at the entry point does not do what `SKILL.md` claimed
> for it, and the third instance of *a rule that lives where the executor does not look* was
> fixed in the wrong place.

Decoys: **9.75 → 9.50**. Recall held at 96.3%, inside the 3-point tolerance. **The stage did
not move the number it was wired in to move.**

It is not that it failed to run. This round required every arm to declare a `ruled_out` list
precisely so that could be checked rather than assumed, and it ran: **15 to 21 assertions
killed per run**, each naming a line. Last round the same field was empty four times of four.

**Of the ~9.5 decoys reported per run, only 1 to 3 had ever entered that list.** The stage
argues, competently, against things that were not the problem. And every decoy that beats this
project beats it in **4 runs of 4** — systematic, not variance.

## A hypothesis checked and discarded before it reached this page

The obvious story was that `mantis` computes reachability and this project does not: it flags
dead-but-shipped code, and several defeating decoys are dead paths. **It is false.** Across the
four runs of each arm, this project's reports mention unreachability, dead code and absent
callers **44 times against `mantis`'s 48**, and constraints defined in another file — enums,
allowlists, schemas — **158 times against 84**. This project reasons about both *more*, not
less.

## What is actually different: a threshold, not a capability

| | reported | true | decoys | precision on keyed items | planted missed |
|---|---|---|---|---|---|
| this project | 48.2 | 32.8 | 9.50 | **78%** | **1.2 of 34** |
| `mantis` | 34.5 | 28.8 | 3.75 | **88%** | 5.2 of 34 |

The two arms sit at different points on one curve. This project misses **1.2** real defects per
run and cries wolf 9.5 times; `mantis` misses **5.2** and cries wolf 3.75 times. Three rounds
of adding *procedure* have moved this project along that curve rather than off it.

## Which leaves a question the measurements cannot answer

The band says a false positive disqualifies a recall lead, because this repository's doctrine
calls a false positive its first-class defect. **It was met on recall and failed on decoys
twice, and it stands** — it was set before the runs, it was already lowered once and that
lowering was declared, and relitigating it after losing on it twice is exactly the goalpost
move these pages exist to refuse.

But the band encodes a **product decision**, not a measurement: whether an auditor that finds 33
of 34 defects and raises 9 false alarms is worse than one that finds 29 and raises 4. That is a
choice about who the squad is for, it belongs to a person rather than to a scorer, and it is
recorded here as an open question. **It is not used to soften the verdict.**

## Sensitivity

At ±0, ±3, ±6 and ±12 lines this project leads recall by 12.5, 12.5, 11.8 and 10.3 points and
reports more decoys at every window. Unlike the previous round, the recall lead **does not**
depend on the window.

## What ships

All eight reports in [`runs/`](runs/), each with the `ruled_out` list this round required, the
[key](key.json), the [pre-registration](PREREGISTRATION.md) written before its author saw the
corpus, and [`SCORE.txt`](SCORE.txt). Scored by the previous round's
[`score.py`](../2026-08-26-coverage-rules/score.py) — the same file, already proved on synthetic
fixtures, unchanged for this round.

One analysis was attempted here and is **not published as a result**: bucketing the defeating
decoys by the shape of what rules them out put 16 of 29 in *other*, too crude to carry a
diagnosis. It is named so nobody re-derives it and believes it.
