# Pre-registration — does the corpus lift a weaker model?

**Written before any run of this round was launched.** Fixed; the numbers get appended, not the method.

## Why this round exists

Twelve measurements compared the corpus against **the same frontier model working unaided**, and came back at parity on every one: recall on file subsets, recall on whole repositories, precision, reader utility, consistency, and now output volume. The corpus leads on none of them.

There is a reading of that which has never been tested. A written procedure cannot beat a reviewer at what the reviewer already knows, and every target used here — a Java AMQP wire decoder, a TypeScript feature-flag server — sits squarely inside a frontier model's strongest priors. On that terrain a corpus has nothing to add, and parity is the ceiling rather than a failure.

If that reading is right, the corpus is not a capability multiplier for a strong reviewer but a **transfer of expertise to a weaker one**. That is the claim a skill makes by existing, and it is the one claim this bench has never measured.

## The prediction

**Same target, same prompts, same judging — a weaker model.** Both arms run on Haiku 4.5 rather than the frontier model every previous round used.

The target carries two defects that **every** frontier run, in both arms, found every time:

- **D1** — a byte array sized from a peer-controlled 32-bit length and allocated before any payload is read.
- **D2** — mutual recursion between the field-value, table and array decoders with no depth cap.

Those two are the ground truth, and they are ground truth precisely because arms with and without the corpus agreed on them unanimously at frontier scale.

**Prediction:** on the weaker model, the corpus arm finds strictly more of {D1, D2} than the unaided arm across three runs each. Consistency is measured as a secondary and is not the test.

**What refutes it:** the two arms find the same number of D1/D2 hits, or the unaided arm finds more.

**What a null result means, and it is not nothing.** If the corpus does not lift a weaker model either, then its value is not capability at any scale, and the honest product claim has to move to what *has* been measured: an artifact contract with somewhere to say *I could not decide this*, and a coverage declaration that resolves every surface it inventories. Those are real and they are not detection. The claim would have to say so.

## Method, fixed in advance

- Same target as the consistency rounds: the wire-format value decoder plus its dependency manifest.
- Same two run prompts, taken verbatim from `../2026-08-21-unaided-pass/prompts/`. The only variable is the model.
- Three runs per arm, each in a fresh context knowing nothing of the others.
- Scoring is **blind**: a judge receives one run's findings with no arm label, no model label and no run label, plus a neutral description of D1 and D2, and answers for each whether the list contains a finding whose mechanism is that one. The description names the mechanism, never the wording either arm used.
- Consistency, secondary, by the same blind same-defect protocol as the previous round.

## Caveats, stated before the numbers exist

- One target, one weaker model, three runs per arm.
- D1 and D2 are two defects. A one-defect difference is inside this bench's stated resolution of five in fifty-three, so only a clean sweep is reportable as a difference.
- The weaker model may fail to produce a valid artifact at all. That is a measurable outcome and will be reported as one, not quietly retried.
