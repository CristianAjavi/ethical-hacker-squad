# Run 2026-08-21 — precision, and the claim it kills


> **The run prompts for this round were not kept.** A later round measured the same unaided arm on the same target with the same blind instrument and a freshly written prompt, and scored 0.60 where this family of rounds scored 0.81 — twenty-one points from the prompt alone. **The numbers below are internally valid and are not comparable to numbers from another sitting.** See `../2026-08-21-unaided-pass/`, which archives every prompt it used.

Three rule-picked rounds ended 6/9, 6/9 and 6/9. Recall on published advisories is identical across the corpus, the same model without it, and a competing product, so that dimension is settled and it does not favour anyone.

One difference did survive all three rounds: **the corpus arm reports about half as much**. I refused three times to call that precision, because there was no key for the findings that match no advisory. This run builds that key, and the result kills the claim I was building towards.

## What was measured

All **53 findings from round 3 that match no published advisory** — every arm, all three targets — stripped of anything naming their arm, given opaque ids and an order fixed by a hash. Each was checked **twice**, by independent contexts that saw the claim text and the target files and nothing else, under an adversarial instruction: *for every claim, first try to find the line that kills it; only when you cannot, mark it supported.* Three verdicts, with `undecidable` defined in the prompt as **not a polite `supported`**.

Two passes, not one, because earlier the same day two blind judges disagreed on the two verdicts that decided a case and a published result had to be withdrawn. A single pass is not an instrument.

## Result

| Arm | Claims | Supported by both | Undecidable by both | Refuted by both | Passes disagreed |
|---|---|---|---|---|---|
| corpus | 7 | 6 | 0 | 0 | 1 |
| no corpus | 20 | 17 | 1 | 0 | 2 |
| competitor | 26 | 21 | 3 | 0 | 2 |

**Nothing was refuted by both passes. One claim was refuted by one pass only.** Across 53 claims and 106 verdicts, the arms are not distinguishable on correctness, because there is almost nothing incorrect to distinguish.

## What that does to the "half the output" observation

It removes the reading I was drifting towards. The extra findings the other two arms report are **not noise** — they are true statements about the code, verified line by line by a context trying to break them. The corpus arm's smaller output is **selection, not accuracy**.

Whether reporting fewer true things is better is a real question and this bench cannot answer it. It depends on what a reader's triage costs, and there is no measurement of that here. What can be said:

- The corpus arm reached the same advisories with 7 non-advisory claims where the others needed 20 and 26.
- Its artifact has somewhere to say *I could not decide this*: a status short of `confirmed`, a named inference, `FP-08` answered `UNKNOWN`. The other two arms' output format has **no field for that** — they assert with a severity, or say nothing.
- The verifiers noticed the difference without being told about it. Several claims they marked `undecidable` had **disclosed their own gap**, in the words of one verifier: *"Both of those claims disclose the gap themselves."*

That is a property of the output contract, not of the corpus, and it is the honest version of an advantage that is otherwise unmeasured.

## The instrument, measured on itself

**Inter-pass agreement: 48 of 53 (91%).** All five disagreements sit on one boundary — whether a claim's impact is decided by the file in front of the verifier or by something outside it:

| Claim | pass A | pass B |
|---|---|---|
| exception escaping a reflectively invoked setter | `undecidable` | `supported` |
| the same, on its null path | `undecidable` | `supported` |
| dependency branch support status | `undecidable` | `supported` |
| the same claim's line references and universal | `undecidable` | **`refuted`** |
| nested extents absorbed with no error raised | `supported` | `undecidable` |

Two things follow, and both are now rules here. **A gap of five claims out of fifty-three is the resolution of this instrument**, so no comparison that turns on fewer than that is reportable. And the disagreements are not random: they cluster exactly where the code stops deciding and judgement starts, which is the same boundary that broke a published result earlier today.

## What the verifiers caught that nobody asked for

The adversarial framing paid for itself in a way the tally does not show. Verifiers recorded errors *inside* claims they still marked supported — an "all 25 direct dependencies" that describes 24, three of which carry no version at all; two line references off by one; "no property can be emptied through this path", which an empty string disproves; a claim citing javadoc line 171 where it is 170; seconds labelled as milliseconds. One verifier refused to score the easy half of a privilege-escalation claim whose payload lived outside the target, and said so: *"Marking it supported would have been scoring the easy half."*

None of that changes a number. All of it is what a verifier is for.

## Files

`claims-*.json` are the blinded batches exactly as the verifiers received them. `verdicts-deblinded.json` holds both passes for every claim with their reasons, joined back to the arm afterwards.
