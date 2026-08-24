# Pre-registration — does the unaided pass close the consistency gap?

**Written before any run of this round returned.** Everything below is fixed; the numbers get appended, not the method.

## The claim being tested

Eleven measurements said the corpus finds what the same model finds unaided and no more, missed a published advisory while holding the right file open, and agreed with itself across repeated runs **less** than unaided review did (0.68 against 0.81). The change made in response — `engagement.unaided_pass`, enforced by the artifact validator — says a specialist must record what it would report **with no corpus at all** before opening a pack, and may not drop any of it silently.

**Prediction:** the corpus arm stops losing consistency to the unaided arm. Concretely, its mean pairwise agreement rises above 0.68 and reaches or passes the unaided arm's.

**What refutes it:** the corpus arm's mean stays at or below 0.68, or stays below the unaided arm measured in the same round. That would mean substitution is not the mechanism and the cause is elsewhere.

## Why this round re-runs BOTH arms

The historical 0.68 and 0.81 came from a protocol whose exact run prompt was not stored. Comparing today's corpus arm against a stored number would change two things at once — the corpus order and possibly the prompt — and any difference would be unattributable.

So **both arms are re-run today**, three runs each, same target, prompts written in the same sitting and differing only in what the prompt is allowed to reference. The historical numbers stay published as a reference point and are explicitly **not** treated as this round's control.

## Method, fixed in advance

- Target: the same one as the previous round — a Java message-broker client's wire-format value decoder plus its dependency manifest.
- Six runs, three per arm, each in a fresh context that knows nothing of the others.
- Agreement between two runs is judged by a **blind same-defect judge**: two lists, opaque `L##`/`R##` ids, no arm label, no run label, order inside each list fixed by a digest of the item's own text. The judge records a reason for every pair it calls.
- The instruction that carries the measurement, unchanged from the round it is being compared to: *two findings in the same method are not the same defect if what makes them exploitable differs.*
- Agreement = matched / (left + right − matched), the same arithmetic as before.
- Six batches, one per pair of runs within an arm.

## Standing caveats, stated before the numbers exist

- One target, three runs per arm. This bench's own measured resolution is five differences in fifty-three.
- Agreement is not quality. A more consistent arm is not thereby a better one.
- The two arms produce different artifact shapes — the corpus arm a validated schema, the unaided arm a flat list — and that difference is part of what is being compared, not a confound to remove.
