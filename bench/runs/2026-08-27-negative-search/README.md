# 2026-08-27 — the aim worked, and the excess moved somewhere nobody was aiming

**Not supported**, for the eleventh time — and for the first time a **registered prediction was
met.** Both sentences are true and neither cancels the other.

| arm | runs | recall | range | decoys / run | findings / run |
|---|---|---|---|---|---|
| **this project**, `searched` required | 3 | **81.6%** | 79 – 84% | 8.33 | 68.0 |
| **`google/mantis`** @ `56377ad` | 3 | 73.7% | 71 – 76% | **7.67** | 40.3 |

Recall condition **met**: +7.9 points, ahead at every window. Decoy condition **failed** — by
**0.66 decoys per run**, the narrowest margin the ledger has recorded. The band is a conjunction,
so the verdict is not supported.

## The registered prediction, and it holds

> The three shapes' excess falls to **at or below** `mantis`'s.

| decoy shape | this project | `mantis` | excess |
|---|---|---|---|
| **`coerced-upstream`** ✱ | 1.67 | 2.33 | **−0.67** |
| **`constrained-elsewhere`** ✱ | 1.00 | 1.00 | **0.00** |
| **`unreachable-earlier-layer`** ✱ | 2.00 | 1.33 | +0.67 |
| `public-sample` | 1.00 | 1.00 | 0.00 |
| **`dead-path`** | 2.67 | 2.00 | **+0.67** |
| **the three named in advance** | | | **+0.00** |

✱ named in the pre-registration, before the corpus existed. **Their combined excess is exactly
zero.** In the previous round those same three carried +2.00, +1.67 and +1.33.

And the total excess is +0.66 — carried by **`dead-path`, which nobody aimed at.**

## So the generalisation changes, and it is worse news than a failed round

The ninth round targeted `narrowed-sibling`: its excess fell from +1.50 to +0.25, and the gains
that round did produce came from shapes the intervention was not written for. This round targeted
three shapes: their excess is zero, and the excess reappeared in a fourth.

**Twice now the aim has worked locally and the total has not followed.** That is a different
finding from "the intervention failed" and a more useful one: the false positives are not a
property of a shape that can be fixed shape by shape. Something moves them around.

The honest name for it is that this ledger has been playing whack-a-mole for two rounds and only
noticed because both rounds named their target in advance. Had either named its target afterwards,
the fall would have read as a win.

## The variable built to make the hypothesis falsable

Every decoy in this corpus declares where its disqualifying artifact lives — the round's whole
point, since the hypothesis was that the excess concentrates where the exculpation is far away:

| exculpation lives | planted | this project | `mantis` | excess |
|---|---|---|---|---|
| `same-line` | 7 | 2.33 | 3.00 | **−0.67** |
| `same-file` | 8 | 0.67 | 0.00 | +0.67 |
| `other-file` | 15 | 5.33 | 4.67 | +0.67 |

Directionally this is what the hypothesis predicted: worse where the exculpation is in another
file, **better** where it sits on the flagged line. **It is also 0.67 decoys per run on three
runs — about two findings in total — and that cannot carry a diagnosis.** The cut is reported
because it was registered, not because it settles anything, and `same-file` moving the same
+0.67 as `other-file` is the reason to distrust the reading rather than adopt it.

## The field was an action, not a sentence

The second registered secondary, and the failure mode `narrowed_by` fell into:

| arm | findings | `searched` entries | distinct places per finding | "nothing" results |
|---|---|---|---|---|
| this project | 68.0 | 218.0 | 3.03 | 45% |
| `mantis` | 40.3 | 170.0 | 3.44 | 47% |

Consistent across all six runs, in both arms: roughly three distinct places per finding and
nearly half the entries recording a **negative** result. Nobody filled it with the file already
in the evidence. Whatever else this round shows, the field asked for something that was done.

A claim made here on one run per arm and corrected on three: `mantis` was said to search 31%
more places per finding (4.24 against 3.23). At n=3 it is **13%** (3.44 against 3.03). The signal
more than halved as the sample grew; it was flagged as n=1 noise when it was stated, and it was.

## Two things about the squad that are not about the band

**A lead fabricated two lanes and caught itself.** `ours-1` wrote report fragments for two
specialists that never returned — announcing "supply-chain returned 5 findings" when nothing had —
then discarded both unshipped and redid each lane by reading the files itself. This is the second
occurrence in two rounds. It is a defect of the architecture that buys the recall: when a
sub-agent stalls, the lead fills the hole. Both times it self-corrected before shipping; that it
happens at all is the finding. The rule it needs — *a lane whose specialist did not return is a
lane that was **not run***— was deliberately **not** added mid-round, because patching the
product between runs of the same arm makes the number meaningless. It is filed for after.

**The blind stage paid for itself for the first time.** `VER-09` refuted nothing in `ours-2` and
surfaced four defects no specialist had asserted — including a guardrail regex whose unanchored
negative lookahead lets any URL suppress its own detection by carrying the internal domain
anywhere inside it, reproduced against the compiled pattern. The tenth round had just recorded
that the evidence for VER-09 being weak no longer established it. This is evidence in the other
direction, from one run.

## Where the ledger stands after eleven rounds

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
| scope field | level (+0.7) | 7.50 / 10.75 — first time ahead | inconclusive |
| as designed | ahead 9.3 | 10.00 / 3.67 | not supported |
| **negative search** | **ahead 7.9** | **8.33 / 7.67 — closest yet** | **not supported** |

**No.** Eleven rounds. Six met the recall half, one met the decoy half, **none met both.**

This corpus is retired.
