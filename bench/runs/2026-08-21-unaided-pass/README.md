# Run 2026-08-21 — the unaided pass: prediction registered, prediction **refuted**


> **Outside information was not settled in this round.** No prompt in this bench said whether consulting sources beyond the target — an advisory database, an upstream branch, a diff against another version — was allowed, and later rounds found that some runs did consult them. **Any recall number here measures review and library familiarity together and cannot separate them.** Consistency comparisons are unaffected: they compare runs of one arm, which had the same latitude. `../../prompts/external-sources.txt` is the clause that closes this for later rounds; it did not exist when this one ran.

`PREREGISTRATION.md` was written before any run returned. It said: the corpus arm's mean pairwise agreement should rise above 0.68 and reach or pass the unaided arm's. It also said what would refute that.

**It is refuted.**

| Arm | Run sizes | Pairwise agreement | Mean |
|---|---|---|---|
| with the corpus | 10, 7, 7 | 0.55 · 0.55 · 0.56 | **0.55** |
| without it | 8, 9, 7 | 0.55 · 0.67 · 0.60 | **0.60** |

Both arms re-run in one sitting, same target, same blind same-defect judging, **every prompt archived under `prompts/`**. The corpus arm is behind by five points, and five is this bench's own stated resolution, so the honest statement is that **the two arms are indistinguishable on consistency and the corpus still does not lead.**

## What the change did do, and it is not nothing

`engagement.unaided_pass` — write down what you would report with no corpus at all, before opening a pack, and account for every one of those labels — was designed to stop the corpus substituting for judgement. Mechanically it worked:

- **Output roughly doubled and now matches the unaided arm's.** The corpus arm reported 4, 5 and 6 findings in the previous round and 10, 7 and 7 here, against the unaided arm's 8, 9 and 7. The half-the-output gap that ran through every earlier measurement is gone.
- **The accounting held.** Across the three runs, 9, 9 and 9 candidates were recorded before any pack was opened; every one ended as a finding carrying its `unaided_label` or in `dropped` with a reason, and the validator enforced it. No drop cited a missing procedure. All three artifacts pass the full validator.

What it did **not** do is make the arm agree with itself more.

## The reading that survives

The diagnosis was: a stable core of procedure-shaped findings plus a different tail each time. That survives, sharpened. The corpus arm's three pairings are 0.55, 0.55 and 0.56 — **almost identical to each other**, which is what a stable core plus a proportionally-sized variable tail looks like. The unaided arm's spread is wider (0.55 to 0.67).

So the unaided pass enlarged the core and the tail together instead of converting tail into core. The mechanism it was aimed at may not be the mechanism that produces the variance. What the judges kept apart in every batch is the same short list every time — an unbounded allocation, an uncapped recursion, an exception of the wrong type on the same line, `available()` as a loop bound, first-wins duplicate keys, non-injective UTF-8 — and which of those a run *writes up* is what moves.

## What cannot be said, and why the previous numbers are not the comparison

The previous round measured 0.68 with the corpus and 0.81 without. **Neither is comparable to this round.** That round did not keep its run prompt, and when the unaided arm was re-run here with a freshly written one it scored 0.60 instead of 0.81 — twenty-one points, from the prompt alone, on the same arm and the same target with the same instrument.

Twenty-one points is larger than any corpus-versus-no-corpus difference this bench has ever produced. That is the most consequential number in this directory, and it is not about the corpus at all: **a published comparison whose prompt was not archived cannot be compared to anything.** Every prompt this round used is in `prompts/`, verbatim.

## The rest of the honesty

- **One run died and is not scored.** `treatment-6` delegated to a specialist, the child went silent, both stopped writing, and it was stopped by hand. Its partial artifact is preserved unscored and did not validate when it died. Same rule the competitor arm got when it died in the whole-repository round.
- **Its replacement carries one extra sentence** forbidding delegation. Runs 4 and 5 never delegated, so it removes a failure mode rather than changing the method — and it is archived as its own prompt file rather than folded in.
- **The arms did not compete under the same rules about outside information.** One unaided run diffed the target against upstream `main`; one corpus run cites CVE identifiers. The protocol never said whether that was allowed. Consistency is unaffected — it is agreement between runs of one arm — but no recall reading may be taken from this round, and the earlier recall rounds had the same silence.
- **One target, three runs per arm, one model.** `ROUND-NOTES.md` has the rest.

## Where this leaves the project

Twelve measurements. The corpus leads on none of them. The one change made in response to that produced a real, measurable effect on what the arm reports and no effect on the property it was aimed at. That is a refuted hypothesis, not a setback: the substitution story explained the narrow output, and the narrow output is fixed, but it does not explain the variance. The variance needs its own explanation and its own measurement.

## Files

`PREREGISTRATION.md` is what was committed before any result existed. `ROUND-NOTES.md` is what happened while it ran. `prompts/` holds every prompt verbatim. `agreement-blind.json` holds the per-pair numbers.
