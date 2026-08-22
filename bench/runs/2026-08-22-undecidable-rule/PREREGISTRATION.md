# Pre-registration — when is a claim `undecidable` rather than `refuted`?

Committed before the rule is applied to a single verdict.

## The open question

`../2026-08-22-second-target/` records it: both adversarial passes **refuted** `R52`, a claim of broken object-level authorization on `/receipts/:id`, partly because the chain it relies on leaves the target — `routes/invoices.js` never imports `lib/auth.js`. In the **same** passes, six "missing authentication middleware" claims were marked **`undecidable`** on what looks like the same ground: the mounting app is not in the target either.

If those are the same ground, the instrument is inconsistent and one of the two groups is misjudged.

## The suspicion that governs this round

**`R52` is this project's only refuted claim on either target.** Any rule that reclassifies it to `undecidable` moves this project's precision from 3% back to 0%. That is a result I would like, which is exactly why the criterion is written first and why the burden here is asymmetric: **a rule that changes `R52` must also change claims that do not benefit this project, or it is a rule written to win.**

## The candidate rule, stated before it is applied

1. **Refuted** — the claim locates its defect at a place **inside** the target, and the code at that place contradicts it. The verifier can point at the line.
2. **Undecidable** — the claim's defect is the **absence** of code that, if it exists at all, lives outside the target. Nothing inside can settle it either way.
3. **Documented behaviour of a named dependency is not "outside the target".** It is general knowledge available to any reviewer, so a claim contradicted by it is **refuted**, not undecidable. Otherwise every claim about a library becomes unfalsifiable.

## How it will be checked, and what would refute it

The rule is applied to **all 134 claims** of the four-arm round, and its output compared to the verdicts both passes already agreed on.

- **The rule is sound if it reproduces every both-pass verdict**, with any divergence explicable as a defect in that specific verdict rather than in the rule.
- **The rule is wrong if it diverges on claims whose existing verdict is not defensible on inspection**, or if it diverges only where the change favours this project.

## What each outcome forces

- **The rule reproduces everything, including `R52` as refuted.** Then **the instrument was consistent all along**, the apparent inconsistency was mine, `R52` stays refuted, this project's precision stays at **3%**, and the rule ships as an explicit statement of what the verifiers were already doing.
- **The rule reclassifies `R52` and nothing else.** That is the outcome to distrust. It is published as *a rule that changes exactly the one claim its author wanted changed*, and it does **not** move the number until a second, independent adversarial pass reaches the same reclassification without being told about `R52`.
- **The rule reclassifies `R52` and other claims, in both directions.** Then it is a real correction, the affected numbers are restated in every round that used them, and the restatement is published whichever way it moves.
- **The rule cannot be applied mechanically** — too many claims need a judgement call about where their defect is located. Then it is not a rule, it is a preference, and it is not written into the bench at all.

## Where the rule would live if it survives

**In `bench/README.md`, as an instrument rule — not in the shipped corpus.** This governs how verifiers score, not how a specialist audits. This bench has already measured that adding procedure text to the corpus produced no effect on detection; that is one more reason not to put an instrument rule where it would be loaded as doctrine by every user.
