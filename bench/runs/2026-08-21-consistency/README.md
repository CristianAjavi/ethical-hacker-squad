# Run 2026-08-21 — consistency: **withdrawn**. The instrument does not work.

> **This run published a number and it is retracted.** It reported that three runs with the corpus produced an identical set of defect classes (pairwise agreement 1.00) against 0.60 without it, and called it the first separation of the day that survived its own caveats. **It does not survive. The number was an artifact of the classifier this directory wrote**, and so is the corrected number that replaced it. Nothing here supports a claim about consistency in either direction.

## What was attempted

Ten measurements of **capability** had come back at parity or worse. One property had never been measured and is what a written procedure should confer by construction: do two independent runs of the same review agree with each other? One target, six runs, three per arm, each in a fresh context.

To compare runs, findings have to be reduced to **the defect they are about** — two runs word the same defect differently, so matching on prose measures style, and matching on file and line splits one defect reported at two places. That reduction was done by an ordered set of regular expressions over each finding's title, impact and evidence.

## Why it is withdrawn

The reduction does not work, and it fails in a way that manufactures whichever answer the pattern order happens to produce.

**First version.** `uncapped-recursion` matched the bare method names `readTable|readArray`. Those names appear in the text of the *declared-length* finding too, so a distinct defect was folded into the recursion class, three runs that genuinely differ were scored identical, and the arm came out at a perfect 1.00.

**Second version**, with patterns rewritten to name mechanisms and the specific classes tested first. It reversed the result — corpus 0.63, control 0.69 — and a hand-check of a single run shows it is equally broken:

| Finding, by its own title | Where the classifier put it | Why |
|---|---|---|
| *A 32-bit length taken from the wire sizes a byte array* | `unchecked-exception` | its evidence mentions the `UnsupportedOperationException` on the sibling branch |
| *Mutual recursion between readFieldValue, readTable and readArray* | `declared-length-vs-remaining` | its impact mentions `available()` |

Both are plainly wrong to any reader of the titles. **Two classifiers, two contradictory answers, both demonstrably mis-binning findings a person bins correctly at a glance.** That is not a close call about thresholds; it is an instrument that cannot do the job it was built for, and every number it produced is void.

## What is kept

The six artifacts, in `runs/`. They are real, they were produced blind, and they are the input any working measurement would use. What they show without any classifier at all, by reading the titles:

- Every one of the six runs, both arms, reports **the allocation sized from a wire length** and **the recursion with no depth counter**. Both arms find the two main defects every time.
- The corpus arm reported 4, 5 and 6 findings; the unaided arm 9, 10 and 9. That difference is the same one every measurement today has shown.

Whether the *sets* are more stable in one arm than the other is exactly the question, and this run cannot answer it.

## What a working instrument would need

The advisory judging in this bench already solves the same problem properly: a blind context is given two texts and asked whether they describe the same defect, with its reasoning recorded. Consistency needs that, not regex — every pair of findings across two runs of one arm, judged *are these the same defect?* by a context that does not know which arm or which run either came from, then the agreement computed from those verdicts.

That is a bigger run than the one attempted here, and it is the only version worth publishing.

## The pattern this makes twice today

Earlier a separation was published and withdrawn when a case judged in two batches gave two different verdicts. This is the same failure in a different place: **a favourable number produced by an instrument this project built and did not test before trusting.** The rule that follows is now written where it will be read — an instrument gets a negative test before its output is published, exactly as every gate here does.

## Files

`runs/` holds the six artifacts. `classify.py` is kept **as evidence of the defect**, not as a tool; `consistency.txt` is the retracted output of its first version.
