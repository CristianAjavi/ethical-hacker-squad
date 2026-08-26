# 2026-08-26 — the diagnosis reproduced and the remedy failed

> **The arms were not given the same instruction.** Every `mantis` launch in this round
> carried *run the stages inline rather than spawning sub-agents*, and no `ours` launch
> carried anything like it. `mantis` is a supervised nineteen-skill pipeline; told to run
> inline it becomes what this project already is. This round therefore compares two prose
> corpora executed by one agent each, **not two products as they ship**. The numbers stand;
> the claim narrows. See [`../CORRECTION-inline-constraint.md`](../CORRECTION-inline-constraint.md).

**Not supported.** Eighth round, same conjunction, same failing half.

| arm | runs | recall | range | decoys / run | findings / run |
|---|---|---|---|---|---|
| **this project**, with `FP-11` | 4 | **74.3%** | 72 – 75% | 5.50 | 53.8 |
| **`google/mantis`** @ `56377ad` | 4 | 65.3% | 53 – 75% | **4.25** | 42.5 |

**+9.0 points of recall — the widest lead yet** — and the decoy half fails again.

## The registered prediction, refuted in its own words

> The decoy rate falls to at or below `mantis`'s, and recall stays within 3 points of 78.3%.
>
> **Decoys do not fall** — `FP-11` is another sentence in a file. It was derived from two cases
> and it did not generalise, which is the same failure the four tools had, one level up.

Decoys did not fall. That is what happened, and the pre-registration already named what it
means.

## The secondary says the diagnosis was right and the remedy was not

Registered before the runs, on a corpus whose decoy shapes are evenly spread — 5, 5, 5, 5, 4, 4
— precisely so this could not be an artefact of a distribution built for the rule:

| shape | planted | this project | `mantis` | excess |
|---|---|---|---|---|
| **`narrowed-sibling`** | 5 | **1.75** | **0.25** | **+1.50** |
| `unreachable-earlier-layer` | 5 | 1.75 | 1.75 | 0.00 |
| `public-sample` | 4 | 0.50 | 0.00 | +0.50 |
| `constrained-elsewhere` | 5 | 0.25 | 0.00 | +0.25 |
| `coerced-upstream` | 5 | 1.00 | 1.25 | −0.25 |
| `dead-path` | 4 | 0.25 | 1.00 | −0.75 |
| **total** | 28 | 5.50 | 4.25 | **+1.25** |

**The entire excess is one shape.** +1.50 on `narrowed-sibling` against a +1.25 total — every
other shape is level or better for this project, and on `dead-path` it is 0.75 ahead.

Two things follow, and they point in opposite directions:

- **The seventh round's diagnosis was sound.** It rested on n=2, and the pre-registration said
  so and asked this question in case the two were a coincidence of small numbers. They were
  not. On a fresh corpus with an even spread, the weakness reproduces at 1.75 against 0.25.
- **`FP-11` did not fix it.** The rule was added, cited in the file every role reads, given an
  eval case and a sealed key row — and the number it was written for did not move.

## Which is the same lesson, for the fifth time today

A rule in a file the executor reads is still a rule the executor can read and not apply. This
repository has now measured that four ways: the battery-discovery rule inside a CI step, the
`.gitignore` lesson as prose on a run page, `VER-09` in `SKILL.md` firing zero times, and the
artifact contract no agent cited. `FP-11` is the fifth and the most carefully placed of them —
cited, evalled, sealed — **and it still did not change what the arm reported.**

The four tools failed the other way: they changed behaviour and were overfitted to the corpus
they were built on. So neither "write it down" nor "build a checker for the instance" is
sufficient on its own, and this ledger has now paid for both lessons.

## What this does not license

- **`mantis` did not get worse.** 65.3% here against 72.4% there is a different corpus; the
  spread on its runs is wide (53 – 75%) and this round's corpus is harder for both.
- **+9.0 is not a claim of superiority.** The band is a conjunction and it failed, for the
  eighth time, on the half this project has never met.

## Where the ledger stands after eight rounds

| round | recall | decoys | band |
|---|---|---|---|
| eleven products | behind 8.3 | 0.25 / 1.00 | refuted |
| coverage rules | ahead 5.9 | 9.75 / 5.25 | not supported |
| refutation stage | ahead 11.8 | 9.50 / 3.75 | not supported |
| artifact contract | level | 6.00 / 7.75 | refuted |
| composition | level | 5.00 / 4.75 | refuted |
| join effect *(within-arm)* | +3.1 composition | — | not supported |
| four tools | ahead 5.9 | 3.00 / 2.00 | not supported |
| **FP-11** | **ahead 9.0** | **5.50 / 4.25** | **not supported** |

**No.** Four rounds have met the recall half. None has met the conjunction, and the failing
half now has a single name: `narrowed-sibling`, +1.50 per run, unmoved by the rule written for
it.

This corpus is retired.
