# Pre-registration — three-way precision: us, unaided, and a competing product

**Written before the competitor arm ran and before any verifier saw its claims.**

## The gap in sixteen measurements

Every measurement in this bench compares the corpus against **the same model working unaided**. That answers *does the corpus add anything to this model*, and the answer is no on every dimension.

It does not answer the question a reader actually asks, which is **how this compares to the other things that exist**. A competing product has been in the bench exactly once, on recall, where all three arms tied at 6/9 — and that tie is itself evidence for the reading these rounds keep producing: **detection is the model's, not the product's.**

If that reading is right, products cannot differ much on *what they find*, and they can only differ on **what they claim and how wrong those claims are**. That is precision, and precision has now been measured for two arms with a validated instrument (89% and 100% inter-pass agreement). The third arm has never been measured on it by anyone.

## The arms

| Arm | What it is |
|---|---|
| **corpus** | this repository, nine pooled weak runs — already measured: **16/26 refuted by both passes (62%)** |
| **unaided** | the same model, no corpus — already measured: **19/28 refuted by both passes (68%)** |
| **competitor** | [`google/mantis`](https://github.com/google/mantis) at `5f76be0`, Apache-2.0, followed as written; nothing from it copied here |

Same target, same weak model (Haiku 4.5), same target as every weak round.

## The prediction, and it bets against us

`mantis` ships explicit `mantis-critic`, `mantis-dedupe` and `mantis-calibrate` stages — machinery aimed squarely at suppressing bad claims, which this corpus does **not** have as separate stages.

**Prediction: the competitor's refuted proportion comes in below 62%, i.e. better than ours.**

**What refutes it:** the competitor lands at or above 62%.

**What each outcome forces.**
- **Competitor better** — we are not the best on precision either. The documentation stays exactly as honest as it now is, and the finding becomes a concrete thing to adopt: an explicit critic stage, measured before and after.
- **Competitor at or above ours** — then on the one dimension where products can differ, and against the strongest published competitor, this corpus is **not behind**. That is a narrow, specific, measured claim about a single dimension at a single scale on one target. It is **not** "the best that exists", and it may not be reported as one.

## Method, fixed in advance

- The competitor is run by following its own pipeline as written, on the same target, at the same model. Nothing from it is copied into this repository.
- Its claims are blinded exactly as the other two arms were: opaque ids, no arm label, order fixed by a digest of the claim's own text.
- **The same verifier prompt, byte for byte**, as the two rounds already done. Two independent adversarial passes. `undecidable` is not a polite `supported`.
- The other two arms are **not** re-verified. Their numbers stand.
- If the competitor arm dies mid-run, its cell is recorded as **not measured**, never as zero — the rule this bench has already applied twice, including once when it cost us.

## Caveats stated in advance

- One target, one model, one competitor, and the target is two files a verifier can read entirely.
- The corpus arm's 26 claims pool three corpus versions; disclosed in `../2026-08-21-corpus-precision/`.
- A precision comparison says nothing about recall, where all three arms have tied wherever they were measured together.
- Competitor output is produced by a pipeline with several stages; whatever it emits as its final report is what gets verified, exactly as our final artifact is what gets verified.

---

## Amendment, written before any competitor claim was verified

The first competitor run returned **7 findings**. A refuted *proportion* over 7 claims is not comparable to one over 26 or 28, and reporting it as if it were would be exactly the kind of number this bench has already retracted three times.

Our own arm was measured by **pooling nine runs into 26 claims**. The competitor gets the same treatment: **three runs, pooled**, before anything is verified. This is decided now, with only the first run's *count* known and none of its claims yet read by a verifier, and it is recorded here rather than folded silently into the method.

Nothing else changes: same target, same weak model, same verifier prompt byte for byte, two independent adversarial passes, the same blinding.

If the pooled competitor claim count still lands far below the other two arms, the comparison is reported **with that asymmetry in the table itself**, not in a footnote.
