# Pre-registration — resolving the recall difference that withdrew the claim

Committed before the six new runs per arm.

## What is unresolved

`../2026-08-22-precision-replication/` split. Precision replicated at **6% against 30%**, a 24-point gap where 10 was required. Recall came in **4.33 of 7 against 4.67**, below the competitor, so by its own pre-registration the capability claim was withdrawn and the top-level `README.md` dropped to one dimension.

That recall margin is **one defect in one of three runs**. Three runs cannot resolve it, and the criterion that turned it into a verdict was mis-specified: an absolute "at or above" on a 7-item scale, no noise band.

## The design, and its one honest weakness stated first

**The primary comparison is SIX NEW runs per arm, and the three pilot runs are excluded from it.** I have already seen the pilot numbers, so a criterion set now cannot be tested by data I have read. The pilot is reported as a secondary, pooled to nine per arm, and labelled as such.

- Target `bench/cases/rag-agent`, unchanged, 7 planted defects.
- `claude-haiku-4-5`, both arms, prompts byte-identical to the pilot's — archived there and reused.
- Claims pooled into one blinded batch, order by digest of the claim's own text, provenance held in a directory no verifier's prompt names.
- Two independent adversarial passes. Recall by the same blind defect-matching judge, same prompt.

## Prediction, with the band the last criterion lacked

**Recall: the corpus arm's mean is no more than 0.5 defects below the competitor's** — over six runs, half a defect of mean is three defect-instances, which is a difference this design can see.

**Precision: the corpus arm's refuted-by-both proportion stays at least 10 points below the competitor's**, the same threshold the pilot cleared.

**The band is disclosed as chosen with knowledge of the pilot.** The pilot's 4.33-against-4.67 gap is 0.34 and would pass it. That is exactly why the pilot is excluded from the primary: a band that the data I have already read would satisfy is not evidence, and only the six fresh runs per arm can be.

## What refutes it

- **Recall: the corpus mean falls more than 0.5 below the competitor's.** The one-defect margin was real and not noise.
- **Precision: the gap closes to under 10 points.** The pilot's precision result did not hold either.

## What each outcome forces

- **Both hold.** The capability claim returns to `README.md` — precision at weak scale against the strongest published competitor — **with both halves stated together and the recall band named**, because precision alone is what made `VER-09` v1 look like a win while it deleted true findings. It remains one target, one competitor, one model scale, and those stay in the text.
- **Recall refutes.** The word is **suppression**, in `README.md` and here. `VER-09` v2's place in the shipping path is reconsidered exactly as v1's was, and a stage that costs true findings does not stay wired because its precision number is pretty.
- **Precision refutes.** The pilot's 24 points were the artefact, the claim stays withdrawn permanently rather than pending, and the pilot round gets that banner.
- **Both refute.** Both of the above, and this corpus has no measured capability lead of any kind.
- **Runs die.** Not measured, preserved unscored, per rule 4. If fewer than five runs per arm survive, the round reports that it could not measure rather than reporting a number from what is left.

## Weaknesses carried forward unchanged

One target, one competitor, one model scale. The verifier and the critic are the same kind of instrument for both arms. The competitor runs read-only and offline, which is its floor and not its ceiling.
