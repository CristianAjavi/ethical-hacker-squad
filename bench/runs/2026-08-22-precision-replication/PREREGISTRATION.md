# Pre-registration — does the precision lead replicate on a second target?

Committed before any arm runs.

## What is being replicated, and why it is the right thing to attack

After tonight's rounds, this project leads on **two** measured dimensions. One is transparency, which is a claim about checkability and not about capability. The other is the only capability claim left standing:

> On precision at weak scale, pooled over nine runs at a claim count matched to the competitor's, **21% of this corpus's claims are refuted by two independent adversarial passes against 53% of `google/mantis`'s**, with ground-truth recall at 14/18.

It rests on **one target, one competitor, one model scale**, and on a critic stage that was measured *harmful* two rounds before it worked. It is the most load-bearing unreplicated sentence in the README, so it is the one to attack.

## The target, picked by a rule stated before it was applied

Rule: **among bench cases with at least 4 planted defects, take the one with the most decoys; break ties on planted count, then alphabetically.** Applied to `bench/ground-truth.json`: **`rag-agent`, 7 planted, 6 decoys.**

`wire-decoder`, the original target, has **2** planted defects, and the original round's own caveat says why that matters: *"the arm now reports exactly the two ground-truth defects. On a target with only two known defects, this bench cannot tell a perfectly-calibrated critic from one that would also kill a true third finding. That needs a target with more ground truth, and it has not been run."* This is that target.

**One thing was checked before accepting the pick and is recorded because it could have gone the other way.** `rag-agent` is an AI-agent surface, and this corpus has a dedicated pack for it; if the competitor had nothing comparable, the round would measure pack coverage rather than precision and would flatter us. It does not: `google/mantis` treats prompt injection and jailbreaking as an attack class it scores, with a severity-calibration rule of its own for `probabilistic_llm` vectors. **No handicap, so the rule's answer stands unamended.**

## Setup

- **Arms**: this corpus as shipped (`VER-09` v2 wired as step 8) and `google/mantis` @ `5f76be0`, followed as written, nothing of theirs copied into this repository.
- **Model**: `claude-haiku-4-5` for both — the same weak scale as the result being replicated.
- **Runs**: three per arm, fresh context each, same target path, same read-only instruction, same outside-information policy.
- **Instrument**: two independent adversarial verifier passes over the pooled claims, both arms' claims blinded to arm, model and run, order fixed by a digest of each claim's own text. `undecidable` is not a polite `supported`.
- **Recall**: scored against the 7 planted defects **for both arms**. The round being replicated never measured the competitor's recall; this one does, which is what makes the suppression check below possible at all.

## Prediction

**The lead replicates**: the corpus arm's refuted proportion comes in **at least 10 points below** the competitor's, at a pooled count of **15 or more claims per arm**, **and the corpus arm's ground-truth recall is at or above the competitor's**.

## What refutes it

Either of these, and both are reported in these words:

1. **The corpus arm's refuted proportion is at or above the competitor's**, or within 10 points of it. The lead does not replicate.
2. **The corpus arm's recall is below the competitor's.** That is **suppression**, not precision, and gets that word regardless of how good the precision number looks. This is the failure mode that killed `VER-09` v1, and the only reason it was caught then is that the prediction demanded both numbers.

## What each outcome forces this project to write

- **Replicates.** The README's precision claim becomes **two targets** rather than one, and gains the sentence that the second target carried 7 planted defects rather than 2, so the "perfectly-calibrated critic versus one that kills a true third finding" caveat is answered. It remains one competitor and one model scale, and those stay in the text.
- **Does not replicate, on either criterion.** **The README drops to ONE dimension in this project's favour, transparency, which is a claim about checkability and not about finding anything.** The `wire-decoder` result is not deleted — it gets a banner in `../2026-08-21-critic-stage/` recording that it did not replicate on a target with more ground truth, and the single-target caveat it already carries stops being a caveat and becomes the finding.
- **Recall below the competitor's specifically.** In addition to the above, `VER-09` v2's place in the shipping path is reconsidered exactly as v1's was — a stage that suppresses true findings does not stay wired because its precision number is pretty.
- **An arm dies, or the verifiers cannot decide.** Not measured. Partial output preserved unscored, per rule 4.

## Known weaknesses, declared now

- **One competitor and one model scale**, unchanged from the round being replicated.
- **Our deduplication is measurably worse than the competitor's** — the round being replicated found 19 of our claims covering 3 distinct assertions against their 17 covering about 9. That inflates our denominator and **flatters us**, and it will inflate it again here.
- The verifier and the critic are the same kind of instrument, adversarial refutation against code, for both arms. This measures how well a product filters its own bad claims, not truth.
- **The competitor runs read-only and offline**, so its `reproduce`, `patch`, `chain` and `calibrate` stages do not run. This is its floor, not its ceiling, and it was its floor in the original round too.
