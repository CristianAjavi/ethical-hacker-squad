# Run 2026-08-22 — the instrument was consistent, the inconsistency was mine

**`R52` stays refuted. This project's precision on the HTTP API stays at 3%.**

An independent classifier applied the written rule to all 134 claims of the four-arm round. It never saw the existing verdicts, was not told which claim was `R52`, and was not told which arm any claim came from. It located `R52`'s defect at `routes/invoices.js:14-17` and wrote:

> *the claim locates broken object-level authorization in `/receipts/:id`, but line 15 contains exactly the `AND owner_id = $2` predicate bound to `req.user.id` that the claim says is missing*

That is the same ground both adversarial passes gave. **The apparent inconsistency between refuting `R52` and marking six "missing middleware" claims `undecidable` was mine, not the instrument's**, and the rule says why they differ: `R52` locates its defect **inside** the target at a line that contradicts it, while the middleware claims assert the **absence** of code that would live outside it.

## The pre-registered suspicion, and how it turned out

The pre-registration named the outcome to distrust — *a rule that reclassifies `R52` and nothing else* — because `R52` is this project's only refuted claim on either target and moving it restores a 0%.

**It was not reclassified.** And of the seven claims where the rule diverges from the verdicts, **every one belongs to a competitor and every one would move in that competitor's favour**, not ours:

| claims | both passes said | rule says | arm |
|---|---|---|---|
| `R21`, `R41`, `R101`, `R103` | refuted | undecidable | `mantis`, `pentest-ai-agents` |
| `R16`, `R58`, `R134` | refuted | supported | `mantis`, `pentest-ai-agents` |

A rule written to win would not have produced that.

## The rule reproduced 125 of 132, and the misses expose a hole in the rule

**Four of the seven are a defect in the rule, not in the verdicts.** The `tagRequest` claims were refuted on the ground that they describe *no attacker and no impact* — a branch the verdict vocabulary has carried all along (*"the claim describes something that is not a defect at all… with no attacker and no impact"*) and which **I simply failed to write into the candidate rule.** The classifier, given an incomplete rule, routed them to the only other branch that fit.

The remaining three are genuine judgement differences about **what a claim asserts** — whether `R134` is about `currentUser` returning a truthy object or about a handler that never reads `req.user`; whether `R16`'s defect is the missing `try/catch` or the framework behaviour behind it. Those are not mechanical, and the pre-registration said what that means.

## What ships, and what does not

**No number moves anywhere.** `R52` is confirmed refuted by an independent application, so every figure in every round stands as published.

**The rule ships as a description, not as a mechanism.** It reproduced 125 of 132 both-pass verdicts, which is enough to say it states a distinction the verifiers were already drawing; it is not enough to say a verifier could be replaced by it. Its third branch — *no attacker, no impact* — is added, because leaving it out is what produced four of the seven divergences.

It goes in `bench/README.md` as an **instrument** rule. It does not go into the shipped corpus: it governs how a verifier scores, not how a specialist audits, and this bench has already measured that corpus text bought no detection.

## What this does not establish

- One round, one target, 134 claims about five defects.
- The classifier is the same kind of instrument as the verifiers it was checked against, so agreement partly measures a shared way of reading rather than a fact.
- Three divergences are unresolved. They are named above rather than adjudicated, because adjudicating them here would be me deciding a tie I have an interest in.

## Files

`PREREGISTRATION.md` first, with the asymmetric burden stated before the rule was applied. `blind-application.json` is the classifier's output for all 134 claims, including where it located each defect.
