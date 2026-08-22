# Pre-registration — the first competitive round on ground nobody here wrote

Committed before any arm runs and before the target repository is cloned.

## The gap this attacks

Every competitive comparison in this bench — `rag-agent`, `express-invoices` — runs on a case **authored in this repository**, with an answer key written here. That was named at the close of the four-arm round as one of three things standing between what is published and any stronger claim.

This round moves the same arms onto an **external repository with a published advisory as the ground truth**, at a checkout verified to sit before the fix.

## The target, picked by a rule stated before it is applied

Rule, over `bench/external/*-rule-picked.json`: **among cases whose fix touches exactly one file, take the one whose repository has the fewest tracked files at its recorded parent commit**, so every arm can read the whole target rather than being measured on how far it got. Ties break alphabetically by advisory id.

The six eligible cases, listed before measuring any of them:

| advisory | repository | parent |
|---|---|---|
| `GHSA-45ph-gxxr-gwgw` | `xwiki/xwiki-platform` | `8b71bc4` |
| `GHSA-6g32-pxv4-2wfj` | `rabbitmq/rabbitmq-java-client` | `3bbc091` |
| `GHSA-pxmc-2ffp-8j67` | `Netflix/lemur` | `e9ade7d` |
| `GHSA-qqff-5854-px68` | `vouch/vouch-proxy` | `b683f60` |
| `GHSA-r5pq-6chh-j3xp` | `Unleash/unleash` | `8b09768` |
| `GHSA-rxjr-6c9q-h67x` | `logto-io/logto` | `0213812` |

**Smallest wins, and that direction is neutral**: a target every arm can read whole removes "ran out of budget" as an explanation for anyone, which is the confound that has muddied whole-repository rounds before.

## Setup

- **Checkout verified first**, with `scripts/bench/verify-target-checkout.py`: at the recorded parent, fix file present, no marker the fix introduces. **If verification fails or cannot run, the round does not run.** That rule exists because ignoring a recorded parent is what forced the retraction of `runs/2026-08-22-routing-at-N/`.
- **Three arms**: this corpus, `Tencent/AI-Infra-Guard` @ `4908db1`, `google/mantis` @ `5f76be0`. `0xSteph/pentest-ai-agents` is omitted for cost and that is a gap, not a judgement about it.
- **Four runs per arm**, `claude-haiku-4-5`, whole repository, **no pointer** to a file or a module.
- Same outside-information clause for every arm, archived. All claims pooled into one blinded batch; the advisory match decided by a blind judge that sees the advisory text and opaque finding ids.

## Prediction

**Every arm lands at the same count, within one run of each other**, and most likely **all of them at zero**. Whole-repository detection without a pointer is the dimension this bench has consistently found hardest for everyone: the only advisory ever found here was found 3/3 by three arms including one with no corpus at all, and every earlier whole-repository round scored 0 or 1 out of 3.

## What refutes it

- **Any arm two or more runs ahead of another.** That would be the first evidence that a product changes whole-repository detection.
- **This corpus alone finding it.** Named separately because it is the outcome I would want, and it is the one to distrust: it must be reproduced on a second external advisory before it is written anywhere but in this round's own README.

## What each outcome forces

- **All arms level, all at zero.** Published as *no product measured here detects a published advisory in an unfamiliar repository without a pointer*, and the external-target gap closes as **measured and unfavourable to everyone**, this project included.
- **All arms level, all finding it.** Then the target was easier than intended, which is a fact about the case and gets said before any comparison is drawn from it.
- **A competitor ahead.** Published as the first measured whole-repository lead by anyone, against us.
- **This corpus ahead.** Held to the second-advisory bar above before it leaves this file.
- **Checkout verification fails.** The round does not run, and that is reported instead of a number.

## Declared weaknesses

Four runs per arm, one advisory, one model scale. Three of the four comparable products. Both competitors run as followed-prompt pipelines, read-only and offline — their floor. A single external advisory cannot carry a general claim about external validity; it can only stop this bench from having none.
