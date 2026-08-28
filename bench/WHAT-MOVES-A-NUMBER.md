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
| a run was **scored three times while its agent was still writing** — the file passed through 68 findings, then 41, then 69, and two intermediates were published as verdicts | the agent's own completion notice, which also disclosed that the 68-finding state was contaminated with an unrelated run's lane files | [a rule](runs/2026-08-29-baited-claim/): a report may not be scored until its agent has reported completion — **written and broken in the same commit**, since the correction that carried it was itself scored early |

No gate caught this one. It is listed beside the others because the same page argues that measuring
before building kills bad designs — and this is the case where measuring *too early* published a
wrong number in this project's favour.

## An impression this author stated twice, and the measurement that refused it

Two rounds showed this project's recall swinging where `mantis`'s held — 45–97% against 79–84% in
the thirteenth, 12.0 points of spread against 3.5 in the tenth — and it was asserted in those pages
that the squad is *inconsistent* where the competitor is *stable*.

Measured across every round where three runs per arm exist and the matcher resolves (**8 of 11**;
three older corpora return zero for both arms, so their rows say nothing and are excluded rather
than averaged in):

| | this project | `mantis` |
|---|---|---|
| mean coefficient of variation on recall | **5.4%** | **5.3%** |
| worst round | 16.6% | 11.1% |
| rounds where this arm was the more variable | **4 of 8** | 4 of 8 |

**The claim does not survive its own ledger.** The two rounds that suggested it are real, and so are
the four where this project is the steadier of the two. Neither arm is consistently more variable,
and an impression formed from the rounds one happens to be looking at is exactly what a ledger of
thirteen is for.

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
