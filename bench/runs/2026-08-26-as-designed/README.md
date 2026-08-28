# 2026-08-26 — both products as they ship, and the curve did not move

> **Decoy figures on this page are an upper bound.** The thirteenth round measured that a
> decoy hit was scored by LOCATION rather than by claim: **59% of this project's counted
> false positives asserted a different CWE from the one the decoy was built to provoke**,
> against 31% of `mantis`'s. Corpora before 2026-08-29 carry no `baits_cwe`, so their numbers
> cannot be recomputed and are **not** rewritten from a field invented afterwards. See
> [`../2026-08-29-baited-claim/`](../2026-08-29-baited-claim/).

**Not supported.** Tenth round, and the first in which each arm was launched at its own entry
point with no architectural constraint: this project forming the squad `SKILL.md` §3 prescribes,
`mantis` fanning out under `mantis-meta-agent`.

| arm | runs | recall | range | decoys / run | findings / run |
|---|---|---|---|---|---|
| **this project**, squad formed | 3 | **73.1%** | 61 – 89% | **10.00** | 91.7 |
| **`google/mantis`** @ `56377ad`, supervisor | 3 | 63.9% | 58 – 69% | **3.67** | 44.7 |

Recall condition **met**: +9.3 points, and ahead at every window (+13.9, +13.0, +9.3, +13.0).
Decoy condition **failed**: 10.00 against 3.67, worse at every window. The band is a conjunction,
so the verdict is not supported — the same shape as rounds two, three and seven, arrived at with
both architectures finally switched on.

## What the architecture actually bought, per run

The registered secondary, and the reason this round was worth running:

| run | own contexts | findings | recall | decoys |
|---|---|---|---|---|
| `ours-2` | **7** | 137 | **88.9%** | **14** |
| `ours-1` | 3 | 85 | 61.1% | 7 |
| `ours-4` | 1 | 53 | 66.7% | 6 |
| `mantis-3` | 5 | 51 | 66.7% | 3 |
| `mantis-2` | **0** | 42 | 63.9% | 4 |
| `mantis-1` | 6 | 41 | 58.3% | 3 |

Two things, and the second is the uncomfortable one.

**Findings scale with how much of the squad formed — recall does not.** 137 / 85 / 53 findings for
7 / 3 / 1 contexts is monotone; 88.9% / 61.1% / 66.7% recall is not. Only the fully-formed squad
stands out, and **that is one run.** An earlier note in this session called the pattern monotone
without separating the two columns; it is monotone in findings and not in recall, and the
distinction is the whole point.

**`mantis`'s numbers barely move with its own fan-out.** Zero sub-agents: 63.9% and 4 decoys. Six
sub-agents in their own contexts: 58.3% and 3. Five: 66.7% and 3. Its supervised pipeline produces
the same answer whether or not it is allowed to fan out — which also means the seven rounds run
under the inline constraint understated it far less than [the correction](../CORRECTION-inline-constraint.md)
feared. That correction is not withdrawn: it was right that the arms were not given the same
instruction, and right that nobody had measured what the constraint cost. This round measures it,
and the answer is: for `mantis`, close to nothing.

**What the squad buys, then, is volume.** 91.7 findings per run against 44.7, carrying both more
real defects and nearly three times the decoys. That is movement *along* the curve this ledger has
documented since round three, not off it. Ten rounds of interventions and the trade has not been
broken once.

## The first attempt, and why it is published as spoiled

Eight arms were launched in parallel, each designed to fan out six to thirteen ways — fifty to a
hundred sub-agents against a cap of twenty. `mantis` ran with **zero** sub-agents despite the
constraint being lifted, one arm had five of six specialists refused, and three arms died holding
an unwritten report while waiting on children the harness could not schedule. The round built to
run both products as they ship prevented both from running as they ship, and the cause was the
harness author's design, not either product.

The relaunch used at most two concurrent arms, a four-in-flight cap per arm, and an instruction to
**write the report even if a stage never returns**. The floor of three valid runs per arm was then
met. The spoiled attempt is not deleted and its diagnosis stands above.

## Cost, registered without a band

| arm | wall minutes / run | findings / run |
|---|---|---|
| this project | 84 | 91.7 |
| `mantis` | 47 | 44.7 |

Roughly 1.8× the wall time for 2.1× the findings — and 2.7× the decoys. The ledger had never
printed a cost figure beside a recall figure before; it does now, and it does not flatter.

## Post-hoc, and labelled as such: the excess has one shape, not one component

**Not registered before the runs.** It was computed from the scored reports afterwards, so it is
a hypothesis for the next round and not a result of this one. It is published because it is the
first specific account this ledger has of *why* the precision half keeps failing.

The decoy excess is **not** concentrated in a component — it is positive in five of six — and the
recall lead is not either, standing in five of six domains. What concentrates is the **shape**:

| decoy shape | this project | `mantis` | excess |
|---|---|---|---|
| `constrained-elsewhere` | 2.33 | 0.33 | **+2.00** |
| `unreachable-earlier-layer` | 2.33 | 0.67 | **+1.67** |
| `coerced-upstream` | 1.33 | 0.00 | **+1.33** |
| `narrowed-sibling` | 2.00 | 1.00 | +1.00 |
| `dead-path` | 0.67 | 0.67 | 0.00 |
| `public-sample` | 0.33 | 0.67 | −0.33 |

The three largest excesses share exactly one property: **what disqualifies them lives in a
different file or a different layer from the line that was flagged.** `public-sample` and
`dead-path` — the two whose exculpation is visible at or near the flagged line — show no excess
at all.

So the honest reading is uncomfortable and symmetric. This project's measured strength is reading
across files: the composition round put the field's blind spot at 40 points and this corpus
planted 25 composition defects deliberately. The same reading appears to manufacture the
false positives. **It searches other files to build a case and does not search them to kill one.**

`scope.narrowed_by` was added for exactly this and evidently does not force the search — a field
can be filled with what the auditor happened to notice. What it does not ask is where the auditor
*looked* for a constraint and failed to find one. That is a negative search, it is the thing a
finder never does spontaneously, and it is the next round's registered hypothesis rather than a
claim here.

## Where the ledger stands after ten rounds

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
| scope field | level (+0.7) | **7.50 / 10.75 — first time ahead** | inconclusive |
| **as designed** | **ahead 9.3** | **10.00 / 3.67** | **not supported** |

**No.** Ten rounds. Five met the recall half, one met the decoy half, **none met both** — and the
one round that ran both products as designed met the recall half by the widest stable margin yet
while failing the decoy half by the largest.

This corpus is retired.
