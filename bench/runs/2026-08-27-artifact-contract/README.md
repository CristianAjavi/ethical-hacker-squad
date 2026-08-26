# 2026-08-27 — the control works; the band is refuted anyway

Two things are true and both go at the top.

**The registered prediction was confirmed, on both halves.** With the shipped artifact contract
required — every finding carrying an answered `FP-nn` rule — the decoy rate fell from **9.50 to
6.00**, below `mantis`'s 7.75, and recall moved 96.3% → 93.9%, a **2.4-point** cost inside the
3-point tolerance fixed before the round.

**The band is refuted.** It reads *refuted if `mantis`'s recall is greater than or equal to
ours*, and at the reported window it is: **95.5% against 93.9%.**

| arm | runs | recall | range | decoys / run | findings / run |
|---|---|---|---|---|---|
| **this project**, contract required | 4 | 93.9% | 91 – 97% | **6.00** | 46.8 |
| **`google/mantis`** @ `56377ad` | 4 | **95.5%** | 91 – 97% | 7.75 | 39.5 |

## The recall difference does not survive its own sensitivity check

| window | ours | `mantis` | gap |
|---|---|---|---|
| ±0 | 91.7% | 90.9% | **+0.8** |
| ±3 | 92.4% | 91.7% | **+0.8** |
| ±6 *(the tool's default, fixed before the round)* | 93.9% | 95.5% | **−1.5** |
| ±12 | 97.0% | 95.5% | **+1.5** |

**The sign flips.** Three of four windows put this project ahead; the reported one puts
`mantis` ahead by 1.5. A difference that changes direction with the matching tolerance is not a
difference this round can resolve — the two arms are **indistinguishable on recall** at this
sample size.

**That is not an escape.** The band is evaluated at the window the tool defaults to, which was
fixed before the round, and by that reading it is refuted. Sensitivity is reported here for the
same reason it was reported in the round where it cut the other way, when a favourable
5.9-point lead fell to 3.7 at ±12.

The decoy advantage, unlike the recall gap, is **stable at every window**.

## The contract was exercised, not filled in

Registered as a secondary precisely because a form can be satisfied without being used:

| | findings | distinct `FP` rules | entries per finding | `NOT_APPLICABLE` | `UNKNOWN` | assertions killed |
|---|---|---|---|---|---|---|
| this project | 46.8 | 10.0 | 2.57 | **0%** | 8% | **27.8** |
| `mantis` | 39.5 | 11.2 | 3.00 | 3% | 8% | 19.0 |

Zero percent `NOT_APPLICABLE`: the free answer was never used to dodge a rule. Assertions
killed per run rose from ~18 last round to **27.8**. The control is real, and the decoy rate
moved with it.

`mantis` mapped its own thirteen review constraints onto `FP-nn` labels one-to-one and
published the map in its provenance — the round asked it for bookkeeping it already did, which
is what the pre-registration predicted and why the extra requirement is not a handicap on that
arm.

## What may not be concluded

**`mantis` did not "improve" from 84.6% to 95.5%.** That is a different corpus. Cross-round
comparison of absolute rates is invalid and nothing here does it; the only valid comparison is
within this round, where the arms are level on recall.

**A favourable result here is worth less than an unfavourable one, as the pre-registration said
before the runs.** This round exists because the author of the harness found that his own
harness had disabled the control being measured. A number produced by that author fixing his
own defect is exactly the sequence to distrust, and the honest weight of the precision result
is *one round, on a corpus this project commissioned, by the person with a reason to want it*.

## Where the ledger stands after four rounds

| round | recall | decoys | band |
|---|---|---|---|
| eleven products | **behind 8.3** | 0.25 vs 1.00 | refuted |
| coverage rules | ahead 5.9 | **9.75 vs 5.25** | not supported |
| refutation stage | ahead 11.8 | **9.50 vs 3.75** | not supported |
| **artifact contract** | **level** (−1.5, sign flips) | **6.00 vs 7.75** | **refuted** |

This morning the answer was *behind on recall*. Then *ahead on recall, worse on noise*. Now
*level on recall, better on noise* — and still not the claim the band requires, because the
band asks for a clear lead and there is not one.

**No.** Level is not best.

Per the multiplicity commitment, this corpus is retired for this question.

## What ships

All eight reports in [`runs/`](runs/), each carrying its `triage` answers and `ruled_out` list,
the [key](key.json), [`SCORE.txt`](SCORE.txt), and the
[pre-registration](PREREGISTRATION.md) written before its author saw the corpus — including the
sentence, written in advance, that a favourable result here counts for less.
