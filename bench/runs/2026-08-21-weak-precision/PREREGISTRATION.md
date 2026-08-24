# Pre-registration — is the weak unaided arm's extra output true?

**Written before any verifier ran.** This is the follow-up the weaker-model round named and did not run.

## Why it decides something

On Haiku 4.5 the unaided arm found 5 of 6 ground-truth defects to the corpus arm's 2 of 6 (4 of 6 after the loading rule), and it did so while reporting **8, 10 and 10 findings** against the corpus arm's 2, 2 and 2.

One blind judge, unprompted, said the unaided lists carry filler — a hard-coded charset literal, a "reinvents the wheel" style note, a logging gap. If a large share of those 28 claims is noise or false, then **the recall comparison is measuring output volume, not review quality**, and the honest headline changes: a short true list at similar recall beats a long list padded with things that are not defects.

Precision is also the one dimension where the corpus has machinery the unaided arm has none of — triage rules `FP-01`..`FP-10`, a `ruled_out` section, a status short of `confirmed`, and now a refutation that must name its control. If that machinery is worth anything, this is where it shows.

## Method, fixed in advance

- Every claim from the three unaided Haiku runs — **28 claims** — stripped of anything naming its arm, model or run, given opaque ids, order fixed by a digest of the claim's own text.
- Each claim checked **twice**, by independent contexts that see the claim and the target files and nothing else, under an adversarial instruction: *first try to find the line that kills it; only when you cannot, mark it supported.*
- Three verdicts. **`undecidable` is defined in the prompt as not a polite `supported`.**
- Two passes, not one, because a single pass is not an instrument: earlier in this bench two blind judges disagreed on the two verdicts that decided a case, and a published result had to be withdrawn.
- Inter-pass agreement is reported alongside the result, as the resolution of the instrument.

## The prediction

**Prediction:** at least 6 of the 28 claims are refuted by both passes — roughly a fifth — because the judge's filler observation describes claims with no attacker at all.

**What refutes it:** fewer than 6 refuted by both passes, which would mean the unaided arm's extra output is largely true and the 5/6 recall stands unqualified.

**What either outcome forces.** If the prediction holds, the weaker-model headline must be restated as a precision-recall trade rather than a clean loss. If it fails, the corpus has no precision advantage at weak scale either, and the last place it could have led is gone.

## Caveats stated in advance

- The corpus arm's claims are **not** verified in this round. Its runs produced 2, 2 and 2 findings; six claims is too few to compare precision against 28, and running it anyway would invite a ratio nobody should trust.
- The target is two files. A verifier can reach every line of it, which makes this bench unusually favourable to verification and not representative of a whole repository.
