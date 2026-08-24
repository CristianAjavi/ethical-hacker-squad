# Run 2026-08-21 — what the field publishes about itself, and a correction to our own analysis

`PREREGISTRATION.md` fixed a six-question rubric before any competing product was opened. Every `yes` needs a URL or a file path.

| | detection number | method behind it | vs not using it | negative result | retraction | pre-registration | |
|---|---|---|---|---|---|---|---|
| **this project** | yes | yes | yes | yes | yes | yes | **6/6** |
| `Tencent/AI-Infra-Guard` | **yes** | *could not settle* | no | no | no | no | **1/6 + 1 unsettled** |
| `vxcontrol/pentagi` | no | no | no | no | no | no | 0/6 |
| `0xSteph/pentest-ai-agents` | no | no | no | no | no | no | 0/6 |
| `msoedov/agentic_security` | no | no | no | no | no | no | 0/6 |
| `google/mantis` | no | no | no | no | no | no | 0/6 |

**The prediction holds**: this project answers `yes` to all six, no other exceeds two, and four answer none. It was refutable — any product matching on four, or this project failing one, would have killed it — and the rubric was committed before anything was opened.

## The correction, which is the most useful thing here

**This repository's own `docs/competitive-analysis.md` says no competitor publishes detection quality. That is wrong, and `Tencent/AI-Infra-Guard` is the counter-example.** Its README carries, verbatim:

| # | Model | F1 | Precision | Recall | FPR |
|---|---|---|---|---|---|
| 1 | Claude Opus 4.6 | **0.9848** | 0.9725 | **0.9974** | 0.0663 |
| 3 | Gemini 3.5 Flash | 0.9792 | **0.9947** | 0.9641 | **0.0120** |

F1, precision, recall and false-positive rate for a detector on a named benchmark (`SkillTrustBench`). That is a detection number by any reading, including the strict one this rubric applies. The prior claim in our analysis is corrected there.

Two things about it are also true. **The method is not published where the number is** — the README links a leaderboard for "full leaderboard and details", and that page is a client-rendered application whose content could not be extracted, so question 2 is recorded as **could not settle**, which in this repository is neither a pass nor a fail. And the table compares **models to each other**, not the product against not using it, so question 3 is `no`.

## The near-misses, quoted so a reader can disagree

**`vxcontrol/pentagi`** publishes, verbatim: *"Quality Improvement: 2x better results compared to baseline execution without supervision"* and *"Result quality: 2x improvement in completeness, accuracy, and attack coverage"*. It is scored `no` on both question 1 and question 3, and the reasoning is worth stating because it is close: the ratio has no target, no absolute values and no scoring rule, and the comparison is an ablation of two of its own features rather than the product against not using it. A reader who thinks that deserves a `yes` has the quote to argue from.

**`msoedov/agentic_security`** publishes a `24.8%` figure. It is scored `no` because that number is the *target's* failure rate, and it is produced against a mock endpoint the same README defines as `refuse = random.random() < 0.2` — the figure describes a random number generator.

**`google/mantis`** publishes a careful, three-tier evaluation *methodology* — how you should evaluate its stages, in the imperative — and no number of its own. That distinction was flagged in the pre-registration precisely so it could not be scored generously, and it was checked by reading the pinned checkout rather than trusting a summary.

## What this claim is, and firmly what it is not

**This is a claim about checkability, not about quality.** It says a buyer can verify more here than anywhere else in this field. It says nothing whatever about finding more bugs — and the eighteen measurements in this same directory say this corpus leads on **none** of the capability dimensions, including one where `google/mantis` is measurably ahead of it.

The caveat was written into the pre-registration before any result existed, and it stands: **publishing your own failures is not the same as being good.** A product that measures nothing and works well beats one that measures everything and does not. What this round establishes is narrow and real — that in a field where four of five products publish no measurement of what they find, and the fifth publishes a number without a reachable method, this one publishes its numbers, its methods, its prompts, its retractions and its refuted predictions.

## How it was run, including what went wrong

Six independent surveyors, one per product, each blind to the others and each given the same rubric verbatim. The survey of **this** repository was given an explicitly adversarial brief — verify commit timestamps, and flag anything resembling self-flattery — and it returned three caveats of its own, all published: the decoy bench is one this project wrote, rounds before the evening of 2026-08-21 did not archive their prompts, and the commit clock is the author's. That last one is answered in `timestamps.md` with GitHub's own clock.

**Three surveyors hung and were killed**, twice, on the two products whose repositories needed the heaviest fetching. Those two were then done by hand. And one `WebFetch` summary **echoed a sentence from the prompt back as though it were a quotation from the source**; it was caught by reading a local checkout instead of trusting the summary, and every subsequent extraction demanded verbatim text with that failure named in the instruction.

## Files

`PREREGISTRATION.md` is the rubric, fixed first. `timestamps.md` verifies the pre-registration ordering on a clock this project does not control, and states what that still cannot prove.
