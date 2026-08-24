# Pre-registration — the critic, second attempt: strip the finder's prose

**Written before the runs, and after reading the competitor's own stage rather than inferring from its score.**

## What the first attempt got wrong, and how it was found out

`VER-09` v1 was measured and reverted: it bought the best precision in this bench (33% refuted against 62%) by cutting ground-truth recall from 4/6 to 3/6, killing one true defect in every run. The diagnosis written then was that a competing product must have a critic "calibrated so failing to kill is the default".

**That diagnosis was wrong, and reading the competitor's stage disproves it.** `google/mantis`'s review stage is *harsher* than ours, not gentler — it instructs the reviewer to assume every finding is a false positive and to disprove it adversarially. If a harsh default were the problem, that stage would suppress worse than ours.

What it does that ours did not is in the same paragraph: it evaluates **the claim and the code only, explicitly discarding the finder's own prose reasoning as potentially hallucinated.**

Our v1 handed the critic the whole finding — title, location, evidence narrative, impact narrative. A reviewer short of budget, reading a confident rationale, does one of two things: it is persuaded by it, or it finds a flaw *in the prose* and reports the finding killed. Neither is an assessment of whether the code does what the claim says.

**Mechanism, stated as a hypothesis:** a true claim survives contact with the code whatever its prose was like; a false one is not rescued by good prose. Removing the prose removes the only thing a rushed critic can win an argument against.

## The change

`VER-09` v2, in this project's own words and with nothing copied from the other project's text: **the critic receives the assertion and its location. It does not receive the finder's evidence narrative or impact narrative.** It decides against the code.

**The change is measured in the laboratory copy of the corpus and does not enter the shipped corpus unless it passes.** v1 shipped before it was measured and had to be reverted; that order is not repeated.

## The prediction

Same target, same weak model, same run prompt, same instruments.

**Prediction: ground-truth recall returns to at least 4/6 — the level without any critic stage — while the refuted proportion stays below the 62% measured without it.**

**What refutes it:** recall below 4/6, or a refuted proportion at or above 62%. Either one, and v2 does not ship either.

## Fixed in advance

- Three runs. Recall is scored by the same blind per-run judge with the same neutral mechanism descriptions; precision by the same two adversarial passes with the same verifier prompt byte for byte.
- **Precision is not reported without recall**, for the reason v1 exists to demonstrate: an arm that stops speaking is never refuted.
- The comparison points — no stage 4/6 and 62%, v1 3/6 and 33% — are **not** re-measured. They stand.
- If the claim count collapses again, the count is reported as the result rather than used as a denominator.

## The credit, and the limit of it

The mechanism came from reading `google/mantis` (Apache-2.0) at its pinned commit. **No text of theirs is copied into this repository**, which is the rule every round of this bench has followed. What was taken is an idea about where a critic should be blind, and it is implemented here in our own words and measured on our own bench — where that same product currently beats this one on precision.
