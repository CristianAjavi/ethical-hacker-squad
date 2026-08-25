# 2026-08-24 — the triage stage, run against its pre-registration

**The round could not measure what it set out to measure, and it says so rather than
reporting the difference it happened to see.** That outcome was written into
[`../../stages/triage/PREREGISTRATION.md`](../../stages/triage/PREREGISTRATION.md)
before a single model call, and it is the rule this page follows.

## What was run

Twelve runs, six per arm, exactly as pre-registered. Byte-identical prompts differing only
in the reference document in context: the **with** arm held
`skills/ethical-hacker-squad/references/triage.md`, the **without** arm held
`references/vocabulary.md`, so both arms knew the status vocabulary and only one knew the
rules. Case order shuffled per run with the seed recorded in each prompt header. The
sealed key was never in either context. Scoring is mechanical, by
`scripts/bench/stage_eval.py score`, against the triple the key declares.

Every prompt and every answer is in `prompts/` and `answers/`. The scorer's own output is
`score.json`. Nothing here was reconstructed after the fact.

## The primary metric: no measurement

The pre-registered primary was **over-affirmation** — the proportion of runs answering
`HOLDS` on a case where the honest answer is that the condition could not be established
(`TS-04`, `TS-06`, `TS-11`, with `TS-13` as the contrast).

| arm | over-affirmations | of |
|---|---|---|
| with | **0** | 18 |
| without | **0** | 18 |

Neither arm answered `HOLDS` on any of them, in any run. The pre-registration names this
case and dictates the response:

> **Either arm scores near-perfectly.** Ceiling means the cases are too easy to separate
> anything, the round reports that it could not measure, and it does not report the
> difference it happened to see.

So it does not. There is no number in this repository for whether the rules file reduces
over-affirmation, and this round did not produce one.

The contrast held in both arms: `TS-13` — same rule as `TS-11`, but there the exported
artifact arrived and reads against the claim — was answered correctly **6 of 6 in both
arms**. Neither arm was answering `UNKNOWN` blindly, which is the only thing that would
have made a floor of zero meaningless in the other direction.

## What the run did establish: the metric has a hole

This is the round's actual result, and it is about the instrument rather than the corpus.

**Over-affirmation was defined as `HOLDS`, and `HOLDS` is only one of two ways to conclude
more than the evidence carries.** Neither arm accepted the exculpation. Both arms, on the
same cases, answered `DOES_NOT_HOLD` — a positive finding that the condition is false,
asserted where the artifact that would settle it never arrived. That is the same error
wearing the other sign, and the pre-registered metric could not see it.

The per-case picture, from `answers/`:

| case | key | with arm answered `UNKNOWN` | without arm answered `UNKNOWN` |
|---|---|---|---|
| `TS-04` | `UNKNOWN` | 3 of 6 | 0 of 6 |
| `TS-06` | `UNKNOWN` | 6 of 6 | 5 of 6 |
| `TS-11` | `UNKNOWN` | 6 of 6 | 4 of 6 |

**That table is not this round's finding and must not be read as one.** Choosing to score
`DOES_NOT_HOLD`-without-evidence *after* seeing the data is picking an analysis to fit a
result, which is the failure this whole apparatus exists to prevent. It is recorded here
because the next round has to pre-register it, not because it supports anything today.

## What this forces

1. **The next round pre-registers the metric as "concluded either way without the
   evidence"**, not as `HOLDS` alone. The definition shipped here was too narrow, and only
   running it showed that.
2. **`TS-04` needs looking at before it is reused.** It is the only case where the with
   arm split 3–3, and the answers that went the other way argue that Jinja2's bare
   `Template` defaults to `autoescape=False` regardless of version — which, if right, makes
   `DOES_NOT_HOLD` defensible and the key debatable. The key is not corrected here on the
   strength of a run that disagreed with it; that would be the same after-the-fact fitting.
   It is flagged, and it is the first thing the next round has to settle.
3. **No claim about triage quality enters the README.** The corpus leads nothing on
   detection, measured eighteen times, and a per-stage round that could not measure does
   not change that sentence.

## The weaknesses, as they were declared beforehand

All three were written down in the pre-registration before the run, and all three still
stand: the consequence column is a table lookup and was treated as secondary; the fifteen
cases were authored by the same hand that owns the corpus; and a per-stage result would
not transfer to the end-to-end question even if there had been one.

One deviation to record. The pre-registration lists rule selection as a secondary metric
for both arms. The without arm never sees the rule ids and cannot name one, so its score
would be zero by construction rather than by performance; the scorer reports rule selection
for the with arm alone and labels the other as not scored. The resolution is in the code
and in this paragraph rather than left implicit.
