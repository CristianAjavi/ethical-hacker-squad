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

## The check that validated nothing, and the three hollow things beside it

`corpus_contract.py` §7 asks whether a sentence routing a reader to `pack.md §N` names a
section that exists. It read one file, `coverage.md`. On 2026-08-28 that file was measured to
hold **zero** routes — the eleven-products round had rewritten it into the COV rules and the
routing had moved into the packs. So the check validated **0 of the 113 routes in the skill**,
reported nothing, and its nothing was folded into a count of 1,741 checks. Pointed at every
served file, it found six dangling routes on its first run: five rows of the traceability matrix
still sent a reader to `web-api-clientside-logic.md §11` for `WEB-22`, which moved to
`web-api-logging.md` when the web pack was split into three.

Beside it, in one day, the mutant bank caught three things that looked like measurement:

| what looked measured | what it actually did | how it was caught |
|---|---|---|
| a mutant flattening a page's headline verdict | left the same word standing in the table below, so the check was right not to fire | the pair: its blinded twin behaved identically |
| a battery blinding a checker in a throwaway copy | ran the gate from the **source** tree, which loads the source checkers — 14 of 15 batteries | the blinded twins came back red |
| a blinding that rewrote a finding's message | `findings.append` still ran, so the gate stayed red | the twin failed its own expectation |

The shape is one shape: **a green that was never at risk.** A mutant that does not mutate, a
harness that cannot remove the mechanism, and a blinding that hides the words rather than the
detection all produce the same reassuring output as work that was actually checked. None of the
three was found by reading the code; each was found by requiring the negative case to exist and
then watching it misbehave.

## A battery that could not tell its own mechanism from a coincidence

On 2026-08-28 three checks written that week were given a mutant bank, each defect run twice: once
with the checker intact, which must fail, and once with the checker **blinded**, which must pass.
The blinded twins came back red. The cause was in the harness, not the checks:
`gate-bench-integrity.selftest.sh` copied the repository to a throwaway tree, mutated *the copy*,
and then ran **the gate from the source tree** — which resolves its `lib/*.py` from its own
`BASH_SOURCE` and therefore always loaded the source checkers.

So no case in that battery, including the twenty it already had, could distinguish *this check
caught it* from *some other section of the gate caught it*. Every case was still red for a real
reason; none of them proved which reason. Fixed by running the copied gate.

Two things this earns:

- **A check proved only in the negative is proved halfway.** Removing the defect and watching the
  red go away shows the gate reacts to the data. It does not show *which* check reacted. The pair —
  defect with the mechanism, defect without it — is what separates them, and it needs a harness
  where the mechanism can actually be removed.
- **The first mutant written for the new check was hollow, and the bank caught that too.** It
  flattened a page's headline verdict but left the same word standing in the table below, so the
  check was right not to fire. A mutant that does not mutate measures nothing, and it reads exactly
  like a passing case.

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
