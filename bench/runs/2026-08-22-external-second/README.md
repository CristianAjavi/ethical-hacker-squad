# Run 2026-08-22 — the second external advisory: nobody found it, and the parked result stays parked

| Arm | runs | found `GHSA-pxmc-2ffp-8j67` | claims produced |
|---|---|---|---|
| this corpus | 4 | **0 / 4** | 25 |
| `Tencent/AI-Infra-Guard` @ `4908db1` | 4 | **0 / 4** | **0** |
| `google/mantis` @ `5f76be0` | 4 | **0 / 4** | 31 |

`Netflix/lemur` at the verified pre-fix commit `e9ade7d`, **575 files**, Python, whole repository, no pointer. 56 claims in one blinded batch, judged against the advisory's published text.

## What this round was for, and the answer

`../2026-08-22-external-competitive/` measured **1-0-0** in this corpus's favour on `vouch-proxy` and **parked it**, under an explicit condition: *it must be reproduced on a second external advisory before it is written anywhere but in this round's own README.*

**It did not reproduce. This corpus found nothing here, and so did everyone else.**

Per that pre-registration the parked result now stays parked **permanently**, and the earlier round is annotated to say so. The prediction written before these runs — *all three arms within one run of each other, most likely all at zero*, and specifically *this corpus does NOT reproduce a 1-and-others-0* — **holds on both halves.**

## The near-miss is this corpus's, and it is one link short of the chain

The advisory is a chain: **upload a duplicate certificate record, then revoke it**, which revokes the real certificate at the CA. Any user can do it.

`LC4` reported *"Certificate upload endpoint lacks authorization gate present in creation endpoint"* — **a precondition of that chain**, correctly identified, at the right endpoint. It never states the second step. **Across all 56 claims from three products, exactly one mentions revocation at all.**

So the failure is not routing and not reading: an arm reached the right endpoint, saw the missing gate, and did not carry it to what the gate protects. That is the same shape as `mantis` on the previous external target, which reached the exact function of the advisory and named an out-of-bounds access instead of an unbounded allocation. **Two external advisories, two arms reaching the right code, two misses on mechanism.**

## `AI-Infra-Guard` reported zero findings in four runs, and that needs its context

Its four runs produced **no claims at all**, one concluding *"SAFE FOR DEPLOYMENT"* and another *"NORMAL (Benign)"*, on a repository with a published privilege-escalation advisory.

**Reported with the reason, because the number alone would be unfair to the product.** Its `skill-scan` pipeline classifies against a taxonomy that asks *is this code malicious* — backdoors, exfiltration, supply-chain implants — and answers that question correctly here: `lemur` is a legitimate Netflix project with no malicious code. The defect it missed is not malice, it is authorization wired wrongly. **A tool answering the question it was built for is not the same as a tool failing**, and this bench should not score it as though those were the same thing.

That is also a limit on this round: **it measures three products against one question, and only one of them was built to answer that question.**

## What two external advisories now say

**Two published advisories, two real repositories, twelve runs each, three products: one detection in twenty-four measured runs, and it does not reproduce.**

That is the external-validity finding, and it is unfavourable to everyone here, this project included. Nothing measured in this bench supports a claim that any of these products finds published advisories in unfamiliar code without a pointer.

## A process failure of mine, four times over

**I pooled a batch before every run had closed, four separate times tonight**, each time reading the artifact's modification time instead of waiting for the completion notification. In this round `LM3` went from 9 claims to 12 and `LM4` from 8 to 5 after I had already pooled them. Every instance was caught before judging — by looking, not by design.

The rule *"the reliable signal is the completion notification"* was written into the bench hours ago and it did not stop me once, because nothing enforces it. **A rule that depends on the author remembering is not a control**, which is the same conclusion the blinding gate came from. Wiring it is the next change.

## What this does not establish

- Two advisories is not external validity. It is two advisories.
- Four runs per arm, one model scale, three of the four comparable products.
- Both competitors ran at their read-only offline floor.
- No precision measurement: the 56 claims were judged only for whether they are the advisory. Nobody's false-positive rate on this target is known.

## Files

`PREREGISTRATION.md` first, including the rule amendment — *exclude repositories already audited in a published round* — made before any run, for a reason unrelated to results, and moving the target to a **larger** repository. `case.json` and `checkout-verification.txt` record the tree at the advisory's parent. `runs/` holds all twelve artifacts including the four empty ones. `verify/` holds the blinded batch and the verdict.
