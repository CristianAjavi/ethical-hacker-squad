# Pre-registration — the unaided arm on the verified pre-fix tree

Committed before the unaided arm runs. The treatment and control arms already exist and are published in `../2026-08-22-exhaust-the-file-2/`; **no unaided arm has been run against this checkout**, and this file is written before one is.

## Why this round exists

The last round compared *corpus with a rule* against *corpus without that rule*. Both arms carried the corpus, so its 3/3 says nothing about whether the corpus helps. The only corpus-versus-unaided evidence on whole repositories is two old rounds of three advisories, plus a third round that was **retracted for measuring a patched tree**.

This is the comparison that round set out to make and got wrong.

## Setup, fixed now

- **Target**: `getkin/kin-openapi` at `61f37b6`, the recorded pre-fix parent, already verified by `scripts/bench/verify-target-checkout.py`: `maxSliceMapToSliceGap` absent, `sliceMapToSlice` present.
- **Ground truth**: `GHSA-xhj3-7xw9-vr34`, one advisory.
- **Arm**: three runs, fresh context each, **the treatment prompt with the corpus paragraph removed and nothing else changed**. The diff will be published as `prompt-diff.txt` the way `corpus-diff.txt` was.
- **Judge**: the same blind judge prompt, byte for byte, three runs in one context, opaque ids, no arm label, order fixed by a digest of each item's own text.
- Whole repository, 293 Go files, no pointer to a module or a file. Same outside-information policy, `../../prompts/external-sources.txt`.

## Prediction

**The unaided arm lands at 2 or 3 of 3.** Every capability comparison this bench has run has tied, and the last round showed the finding survives removing corpus text, which is weak evidence that it does not depend on corpus text at all.

**What refutes it: the unaided arm at 0 or 1 of 3.**

## What each outcome forces this project to write

- **Unaided 2–3 of 3 (predicted).** Whole-repository detection of this advisory is **the model's**, and the corpus adds nothing to it. This goes in `README.md` and `bench/README.md` in those words. It also retires the last plausible hope that the corpus leads on any capability dimension, and the honest summary at the top of the README stops being provisional.
- **Unaided 0–1 of 3 (refutes).** **The first measured capability lead in this bench.** It gets published with the caveats it deserves — one advisory, one repository, one model, three runs per arm, and a difference of two is at the edge of this bench's stated resolution of five in fifty-three. It does **not** license a headline change until a second advisory reproduces it, and this sentence is what stops that from happening in the excitement.
- **Any arm dies, or the judge cannot decide.** Not measured. The partial output is preserved unscored, per rule 4.

## What is already known to be weak here

- **One advisory.** A 3-versus-1 difference on a single case is one advisory of evidence, which is exactly the thinness the retracted round was trying to fix.
- The judge has already seen this defect twice today, in two prior batches. It is a fresh context each time and the batches are blinded, but the *defect* is not novel to the instrument, and a judge that has learned what to look for is not the same instrument as one that has not. **Recorded now, before the result, because after the result it would look like an excuse.**
- The treatment and control arms are not re-run. This round adds one arm to an existing comparison rather than running all three at once, which is weaker than a simultaneous three-arm design and is disclosed for that reason.
