# Pre-registration — does `VER-09` close the precision gap, or just suppress?

**Written before any run of this round, and before any verifier saw a claim.**

## What is being tested

The three-way round measured a competing product ahead of this corpus on precision — **53% of its claims refuted against our 62%** — and named the mechanism: it ships a stage whose only job is to attack the finished list, and we did not.

`VER-09` is now written, and the verifier is invoked in `audit` mode as a separate pass over every `confirmed` and `probable` finding. This measures whether that changes the number.

## Two metrics, together, and the second one is not optional

**Precision alone is trivially gameable: an arm that reports nothing is never refuted.** So this round reports both, from the same runs:

- **precision** — proportion of claims refuted by both adversarial passes, same instrument, same verifier prompt byte for byte.
- **recall** — how many of the two ground-truth defects (D1 the allocation, D2 the recursion) each run reports, same blind judge, same neutral mechanism descriptions.

A drop in refuted proportion that comes with a drop in ground-truth recall is **suppression, not precision**, and will be reported as such.

## The prediction

**Prediction: the refuted proportion falls below 62%, and D1/D2 recall does not fall below the 4/6 measured for this arm without the stage.**

**What refutes it:** a refuted proportion at or above 62%, **or** ground-truth recall below 4/6.

**The bar for the competitor comparison is 53%**, and it is named here so it cannot be moved afterwards. Landing between 53% and 62% is an improvement that still leaves the competitor ahead, and must be reported in those words.

## The validity threat, stated before the result

The critic stage and the measuring instrument are **the same kind of thing** — adversarial refutation of a claim against the code. An arm that filters itself with the grader's own framing will score better on that grader almost by construction.

This does not make the comparison unfair, because **the competitor's `critic`/`review` stages are the same kind of thing and were measured by the same instrument.** What it does mean is that the number measures *how well a product filters its own bad claims*, which is the dimension, and not some independent notion of truth. That is why recall is reported beside it: an arm can only win this metric by filtering, and filtering shows up in recall.

## Method, fixed in advance

- Three fresh runs, same target, same weak model (Haiku 4.5), same run prompt as the previous corpus-arm rounds plus nothing — the stage comes from the corpus, not from the prompt.
- Claims blinded and pooled exactly as before; same verifier prompt byte for byte; two independent adversarial passes.
- Ground truth scored by the same blind per-run judge with the same mechanism descriptions.
- The competitor's 53% and the pre-stage 62% are **not** re-measured. They stand.
