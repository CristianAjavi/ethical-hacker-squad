# Pre-registration — the same three arms, off the specialist's home ground

Committed before any arm runs.

## The limitation this attacks

`../2026-08-22-second-competitor/` put this corpus level with `Tencent/AI-Infra-Guard` and ahead of `google/mantis`. Its largest declared caveat is now the binding one: **one target** — and that target, `rag-agent`, is `AI-Infra-Guard`'s own home domain. A tie on the specialist's home ground is a good result for a general-purpose corpus and a bad basis for any claim about the field.

**The tie is only meaningful if it survives somewhere else.** This round moves the same three arms to a target that is nobody's home ground and is squarely ordinary.

## The target, picked by a rule stated before it was applied

Rule: **among bench cases with at least 4 planted defects, excluding `rag-agent` as already used, take the one with the most decoys; break ties on planted count, then alphabetically.** Applied to `bench/ground-truth.json`: **`express-invoices`, 5 planted defects and 6 decoys** — an HTTP API in Node with routes, a query helper, templates and an outbound fetch.

**This is the direction that costs `AI-Infra-Guard` its advantage and costs this corpus nothing**, which is stated plainly because it cuts our way: the specialist is off its domain, we are general-purpose by design. A tie or a win here therefore means less than it looks, and **a loss here means more**.

## Setup, identical to the round it extends

Six runs per arm, `claude-haiku-4-5`, all claims from all three arms pooled into one blinded batch, two independent adversarial passes, blind defect matching against the 5 planted defects, provenance held where no verifier's prompt names it. Same outside-information clause for every arm, archived. Nothing is carried over from any earlier judging.

## Prediction

**All three arms land inside 10 points of each other on refuted-by-both proportion, and inside 0.5 defects of mean recall of each other.** After tonight, the reading this bench keeps arriving at is that these differences are the model's rather than the products', and this predicts that directly.

**Specifically: `AI-Infra-Guard` does NOT fall behind by more than 10 points off its home ground.** If a specialist's advantage were real and domain-bound, this is where it would show, and this predicts it will not.

## What refutes it

- **Any arm outside a 10-point precision spread**, or outside a 0.5 recall band from the others.
- In particular: **this corpus more than 10 points ahead of `AI-Infra-Guard`** would be the first evidence that the tie was a home-ground artefact and that a general-purpose corpus travels better.

## What each outcome forces

- **Prediction holds — all three inside the bands.** The published claim becomes narrower and more honest still: **on two targets, two competitors and one model scale, these three products are not distinguishable on either dimension.** The word "level" replaces every comparative in `README.md`, and the transparency dimension becomes the only thing this project can claim at all.
- **This corpus pulls ahead of both by more than 10 points.** The first evidence of a lead that is not confined to one target. It is published with the reason it is credible — a general-purpose corpus on ordinary ground — and with the reminder that it is still two targets and one model scale. It does **not** become "the best that exists": three of six surveyed products remain unmeasured, and that sentence stays in the README until they are not.
- **`AI-Infra-Guard` pulls ahead here, off its own home ground.** Then the tie on `rag-agent` was this project's ceiling, not its floor, and `README.md` says the competitor is ahead. This is the outcome that would end the capability claim for good, and it is named here so it cannot be softened later.
- **`mantis` closes its 19-point gap.** Its earlier deficit was target-specific and the two-target statement must say so.

## Declared weaknesses

- Still **one model scale**, and still **two of six** surveyed products measured as arms.
- `express-invoices` was authored in this repository, like every bench case. The external-advisory rounds are the counterweight to that and they are elsewhere.
- Both competitors run as followed-prompt pipelines, read-only and offline: their floor, not their ceiling.
- The verifier and the critic remain the same kind of instrument for all arms.
