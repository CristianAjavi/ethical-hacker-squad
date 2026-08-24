# Pre-registration — the second external advisory, which is what the first one is waiting on

Committed before any arm runs.

## Why this round exists, in the previous round's own words

> *This corpus alone finding it… is the one to distrust: it must be reproduced on a second external advisory before it is written anywhere but in this round's own README.*

`../2026-08-22-external-competitive/` measured **1 of 4 for this corpus, 0 of 4 for `AI-Infra-Guard`, 0 of 4 for `google/mantis`** on `vouch/vouch-proxy`. That result is parked. This round is the condition it was parked under, and it can only do one of two things: release it, or leave it parked permanently.

## The target, and an amendment stated before anything runs

The rule was *fewest tracked files among external cases whose fix touches one file*. Applied again, the next smallest is **`rabbitmq/rabbitmq-java-client`** at 460 files.

**It is excluded, and the rule is amended to add: exclude any repository already audited in a published round.** `rabbitmq-java-client` is the target of `runs/2026-08-21-weaker-model/` and `runs/2026-08-21-whole-repo-3arm/`; its `ValueReader` is the code those rounds are about. Running it again would measure familiarity — mine with the repository, and the prompts' — rather than detection.

**The amendment is made before any arm runs, for a reason that has nothing to do with results, and it moves the target to a larger repository rather than a smaller one.** That direction is the harder one, which is the only reason it is safe to make an amendment at all.

That gives **`Netflix/lemur`, 575 files, Python**, advisory **`GHSA-pxmc-2ffp-8j67`**, parent `e9ade7d`. Different language and different ecosystem from the first external round, which is a difference this round did not choose and should not claim credit for.

## Setup, identical to the round it is testing

Checkout verified first with `scripts/bench/verify-target-checkout.py`; **if verification fails, the round does not run.** Three arms — this corpus, `AI-Infra-Guard` @ `4908db1`, `google/mantis` @ `5f76be0` — four runs each, `claude-haiku-4-5`, whole repository, no pointer, same outside-information clause. One blinded batch, one judge, advisory matched on mechanism.

## Prediction

**All three arms within one run of each other, and most likely all at zero.** This is the same prediction as last time and it held; nothing measured since gives a reason to change it.

**Specifically on the parked result: this corpus does NOT reproduce a 1-and-others-0.** The single find last time came from the arm's outlier run — 22 minutes and 15 of its 20 claims, against siblings that produced 1, 1 and 3 — which is better explained by that run doing far more than by a method the other three shared.

## What refutes it

- **Any arm two or more runs ahead of another**, the same bar as before.
- **This corpus at 1 or more while both competitors are at 0, again.** That is the pattern the parked result needs, and predicting against it is the point of this round.

## What each outcome forces

- **Prediction holds — all level, most likely all zero.** The parked result stays parked **permanently**, and `../2026-08-22-external-competitive/` gains a line saying its 1-0-0 did not reproduce. Two external advisories, no product detects either reliably, and that goes in `bench/README.md` as the external-validity finding — unfavourable to everyone, this project included.
- **The pattern reproduces.** Then this corpus has found **two** external advisories that two competing products found neither of, across two languages. That is released from the round's README into `bench/README.md` **with both counts and the fact that each is 1 of 4**, and it still is not "the best" — it is the first repeated signal that anything here transfers to unfamiliar code.
- **A competitor ahead on this one.** Published as such, and the parked result is read afterwards as noise in both directions rather than as ours.
- **Checkout verification fails.** The round does not run, and that is reported instead of a number.

## Declared weaknesses

Two advisories is not external validity, it is two advisories. Four runs per arm, one model scale, three of the four comparable products, both competitors at their read-only offline floor. `lemur` is Python where `vouch-proxy` was Go — a difference in the arms' favour or against it is unmeasurable at this N and no claim is drawn from it either way.
