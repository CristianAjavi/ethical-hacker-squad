# Run 2026-08-21 — precision was the last place the corpus could lead, and it does not

`PREREGISTRATION.md` was committed before any verifier saw a claim. It predicted the corpus arm's refuted proportion would be **more than ten points below** the unaided arm's 68%, and it named what a failure would force the documentation to say.

**Measured: 62% against 68%. Six points. The prediction is refuted.**

| | claims | refuted by both passes | supported by both | inter-pass agreement |
|---|---|---|---|---|
| **with the corpus** (9 weak runs pooled) | 26 | **16 (62%)** | 9 | **26/26 (100%)** |
| **without it** (3 weak runs) | 28 | **19 (68%)** | 4 | 25/28 (89%) |

Same verifier prompt byte for byte, two independent adversarial passes each, `undecidable` defined as not a polite `supported`, both arms' claims blinded to arm, model and run.

## The finding underneath the number, which is larger than the comparison

**Every claim that survived, in either arm, is D1 or D2.**

The corpus arm's nine survivors are the allocation defect (`K04`, `K10`, `K16`, `K22`) and the recursion defect (`K13`, `K15`, `K17`, `K18`, `K21`) — the same two defects, filed once per run. The unaided arm's four survivors were the same two defects.

**Across twelve weak-model runs and 54 claims, neither arm produced a single true finding beyond the two the ground truth already names.** Everything else — twenty-six claims between them refuted twice over — is refutable from the file the reviewer had open. That is a fact about what a small-context model does with this task, and the corpus neither causes it nor cures it.

The refutations are the same shape on both sides. From the corpus arm: a claim asserting *"no bounds checking is performed on `contentLength` before allocation"* when line 87 is exactly that check; a `throw` at line 217 titled "silent corruption"; five separate claims that overflowing a timestamp the peer already chooses grants the peer something; a GPG **key id** treated as a secret; a test-scoped dependency reported as shipped.

## The one asymmetry that did show up

**Inter-pass agreement was 26/26 on the corpus arm's claims and 25/28 on the unaided arm's.** Two independent adversarial verifiers reached the same verdict on every single corpus-arm claim.

That is consistent with claims that state their mechanism precisely enough to be decided — which is what a procedure-shaped write-up should produce. It is also consistent with a claim set that simply contains fewer marginal cases. **This round cannot separate those two**, 26 versus 28 claims is nowhere near enough to call a three-point agreement difference, and it is recorded as an observation, not a result.

## What this forces, in the words the pre-registration committed to

Sixteen measurements: recall on file subsets, recall on whole repositories, precision at frontier scale, reader utility, consistency, recall at weak scale, and now precision at weak scale.

**The corpus leads on none of them, at any scale, on any dimension this bench has measured.**

That sentence now belongs in the project's own documentation and not only here, because the pre-registration said it would if this round came out this way, and it did.

What remains true and measured is narrower and worth stating exactly: an artifact contract with somewhere to say *I could not decide this*, a coverage declaration that resolves every surface it inventories, and a loading rule that took a weak model from measurably harmful back to indistinguishable. None of those is detection.

## Files

`PREREGISTRATION.md` is what was committed first, including the disclosure that the nine pooled runs used three different corpus versions and that no per-version claim may be drawn. `claims.json` is the blinded batch exactly as both verifiers received it. `verdicts-deblinded.json` holds both passes joined back to their runs afterwards.
