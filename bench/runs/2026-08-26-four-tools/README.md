# 2026-08-26 — the tools did not carry the round, and that reverses what this page's author had been saying

> **The arms were not given the same instruction.** Every `mantis` launch in this round
> carried *run the stages inline rather than spawning sub-agents*, and no `ours` launch
> carried anything like it. `mantis` is a supervised nineteen-skill pipeline; told to run
> inline it becomes what this project already is. This round therefore compares two prose
> corpora executed by one agent each, **not two products as they ship**. The numbers stand;
> the claim narrows. See [`../CORRECTION-inline-constraint.md`](../CORRECTION-inline-constraint.md).

**Not supported.** Seventh round, same conjunction, same failing half.

| arm | runs | recall | range | decoys / run | findings / run |
|---|---|---|---|---|---|
| **this project**, four tools | 4 | **78.3%** | 74 – 84% | 3.00 | 47.2 |
| **`google/mantis`** @ `56377ad` | 4 | 72.4% | 63 – 79% | **2.00** | 38.2 |

+5.9 points of recall — the recall half met for the third time — and 3.00 decoys against 2.00,
which fails the conjunction for the seventh.

## The registered secondary, and it says the opposite of what was expected

The pre-registration set this up as the round's real question:

> If this project leads **only** on the shapes its tools cover and matches elsewhere, the tools
> work and the lead is narrow and bought; if it leads on shapes **no tool covers**, something
> other than the tools is doing it and the tools are not the explanation.

| | mechanisms a tool addresses (9 defects) | mechanisms **no** tool addresses (29 defects) |
|---|---|---|
| `mantis` | 66.7% | 74.1% |
| this project | **75.0%** | **79.3%** |
| lead | **+8.3** | **+5.2** |

**It leads in both.** The lead is larger where the tools reach, which is consistent with them
helping — but most of the corpus, and most of the lead, is where they do not reach at all.

## And the tools barely fired

`from_tool` was required on every finding this round precisely so this could be counted rather
than assumed. Across the four runs, **189 findings**:

| tool | findings attributed | of those, on a planted defect |
|---|---|---|
| `log_escaper.py` | 4 | 4 |
| `default_resolver.py` | 4 | 4 |
| `path_coverage.py` | **0** | 0 |
| `writer_parity.py` | **0** | 0 |

**Eight of 189. Ninety-six percent of what this project reported came from reading, not from a
tool.** One run's provenance is blunter still: `writer_parity.py` returned zero flags on a tree
where the same run found *six defects of exactly its shape*; `path_coverage.py` produced two
false positives, no true ones, and silently dropped a whole service from its partition.

## What that reverses

Earlier today this author wrote, more than once, that prose procedure moves this corpus along
the precision/recall curve while a deterministic join moves a number every time it is tried.
**On this corpus that is false.** Three of four joins contributed nothing, and the project led
anyway — including by 5.2 points on the 29 defects no join addresses.

The honest reading is that the tools were **fitted to the instances in the corpus they were
built against**. Each was verified on `corpus-v5` and each was built after measuring what
`corpus-v5` missed. Pointed at six stacks none of them had seen — NestJS, Cloudflare Workers,
Kafka, Phoenix LiveView, Ktor, Envoy — two of the four were silent and one hit a right line for
a wrong reason.

**That is overfitting, and it was invisible until a corpus was commissioned that the tools could
not dominate.** The pre-registration named that risk and asked for eight mechanisms; the corpus
came back with nineteen, none over three defects, which is what made the answer legible.

## What is carrying the lead, then

Not measured here. The remaining candidates are the things added earlier: the coverage rules,
the triage contract that every finding answers, `VER-09` at the roles' entry point, and the
packs themselves. Which of them, and in what share, is the next round's question and is **not**
answered by this one.

## Cost

`path_coverage.py` silently dropping a service from its partition is a defect introduced today,
by the partition fix, and it is filed rather than fixed here — the round is over and changing
the instrument after the fact is what these pages refuse.

## Where the ledger stands after seven rounds

| round | recall | decoys | band |
|---|---|---|---|
| eleven products | behind 8.3 | 0.25 / 1.00 | refuted |
| coverage rules | ahead 5.9 | 9.75 / 5.25 | not supported |
| refutation stage | ahead 11.8 | 9.50 / 3.75 | not supported |
| artifact contract | level | 6.00 / 7.75 | refuted |
| composition | level | 5.00 / 4.75 | refuted |
| join effect *(within-arm)* | +3.1 on composition | 5.00 / 5.50 | not supported |
| **four tools** | **ahead 5.9** | **3.00 / 2.00** | **not supported** |

**No.** Three rounds have now met the recall half and none has met the conjunction.

Per the multiplicity commitment, this corpus is retired.

## An addendum about a favourable cut that was looked for and is not there

Seven rounds have produced the same shape: this project reports ~47 findings against `mantis`'s
~38, which buys recall and costs precision. The obvious next thought is that the surplus is in
the weaker tier — that scoring `confirmed` only would show a cleaner set.

**It was measured, on the data already in hand, and it is not there:**

| arm | cut | recall | decoys | reported |
|---|---|---|---|---|
| this project | everything | 78.3% | 3.00 | 47.2 |
| this project | `confirmed` only | **65.8%** | 2.50 | 38.0 |
| `mantis` | everything | 72.4% | 2.00 | 38.2 |
| `mantis` | `confirmed` only | **65.8%** | 2.00 | 32.8 |

On `confirmed` only the two arms are **exactly level at 65.8%** and this project still reports
more decoys. The band is not met on that reading either.

**This is recorded because it was gone looking for.** Re-scoring after an unfavourable result,
with a cut chosen for how it might read, is the fishing these pages refuse — and it does not
stop being fishing when the cut happens to fail. It is reported as an unregistered observation
and no claim rests on it.

What it does say, and this is worth the next round registering: **this project's entire lead
lives in its `probable` tier.** Dropping probables costs it 12.5 points of recall and saves 0.5
decoys — so those probables are hitting planted defects at a far better rate than chance. The
surplus this project reports is not padding. It is findings it can establish but not confirm,
and the `UNKNOWN` cap in the triage contract is what keeps them out of `confirmed`.

Whether that is a strength or a reporting failure is a product question, not a measurement one,
and it belongs beside the other one this ledger has left open: whether an auditor that finds
more and cries wolf more is worse than one that finds less and is quieter.
