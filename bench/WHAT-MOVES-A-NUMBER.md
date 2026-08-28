# What moved a number, and what did not

Every row links to the page that measured it. Nothing here is asserted from memory, and the
aggregate claim at the bottom is only as strong as the rows above it.

## Interventions that asked someone to reason better

| intervention | what it targeted | what it did |
|---|---|---|
| **`FP-11`**, a triage rule for the `narrowed-sibling` shape | that shape's decoy excess | [moved nothing](runs/2026-08-26-fp11/) |
| **`scope`**, a required descriptive field | the same shape | [moved the total, not the target](runs/2026-08-26-scope-field/) |
| **`searched`**, a required field recording an action | three named decoy shapes | [target excess to exactly 0.00 — and the total did not follow](runs/2026-08-27-negative-search/) |
| **blind judge, open question** | ruling outside-key findings | [failed its sealed control, 3/10 decoys](judge/) |
| **blind judge, disqualifying search forced** | the same, with the lever the previous round found | [failed identically, 3/10](judge/) |
| **severity floor**, dropping `low` from scoring | the decoy rate | [refuted and withdrawn by its own pre-registered rule](runs/2026-08-28-severity-floor/) |

Six attempts. One hit its named target exactly and the total moved against it anyway; the other
five moved nothing they were aimed at.

## Measurements taken before building the thing they justified

| what was going to be built | what the measurement said | outcome |
|---|---|---|
| a word-overlap check for decoy-claim mismatch | its own fourth example was a hyphenation artefact | [refused; number published as an upper bound](judge/) |
| a claim-divergence measure across runs | its control mislabels 30% of same-defect descriptions | [refused; number not reported as a finding](judge/) |
| a scope-versus-evidence mismatch flag | the signal runs **backwards** — 14% against 30% | [refused before shipping](runs/2026-08-28-severity-floor/) |

Three attempts, three designs killed by their own control **before** they shipped. Two of the
three would have flattered this project had they shipped unmeasured.

## And one row about how a number gets published wrong

| what happened | how it was caught | what it earned |
|---|---|---|
| a run was **scored while its agent was still writing** — 68 findings at the copy, 41 when it finished — and the intermediate favoured this project, so the round published +4.4 and "not supported" when the truth was −6.1 and **refuted** | a scheduler notice that the agent was still running, read **after** the page was committed and pushed | [a rule](runs/2026-08-29-baited-claim/): a report may not be scored until its agent has reported completion |

No gate caught this one. It is listed beside the others because the same page argues that measuring
before building kills bad designs — and this is the case where measuring *too early* published a
wrong number in this project's favour.

## The pattern, stated no more strongly than the rows support

**Asking a reader — human, model, or specialist — to reason more carefully has not moved a target
number in this ledger.** Six tries, including two that this ledger's own findings recommended.

**Measuring a proposed check before building it has killed three designs**, which is the only
reason none of them shipped.

What has moved numbers is narrower and duller: a deterministic check that answers a mechanical
question, a required field that records an **action** rather than an observation, and a gate that
fails closed. What has not moved numbers is every attempt to improve judgement by asking for it.

This is a claim about twelve rounds on this bench, by one author, against one competitor. It is
not a claim about security review in general, and the rows are linked so a reader can disagree
with each one separately.
