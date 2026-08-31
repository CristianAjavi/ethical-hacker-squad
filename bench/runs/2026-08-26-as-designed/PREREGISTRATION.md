# Pre-registration — both products as they ship, for the first time

Written and pushed **before any arm runs and before this file's author has seen the corpus**.

## Why the previous nine rounds do not answer the question they asked

Neither product ran as designed in any of them, and the suppression was symmetric:

- Every `mantis` launch from the refutation round onward carried *run the stages inline rather
  than spawning sub-agents*. `mantis` is nineteen skills under a persistent supervisor; told to
  run inline it becomes a single agent reading a procedure.
- Every `ours` launch pointed at **one** role file. `SKILL.md` §3 is called *Form the adaptive
  squad* and says to staff two to four specialists, run them in parallel, and reserve capacity
  for `ehs-remediator` and `ehs-verifier`. **This project never formed a squad either.**

So nine rounds compared two prose corpora executed by one agent each. The full account is in
[`../CORRECTION-inline-constraint.md`](../CORRECTION-inline-constraint.md).

## This round

Each arm is launched with its own entry point and **no architectural constraint**:

| arm | launched as |
|---|---|
| **ours** | `SKILL.md`, told to form the squad its §3 prescribes — staff the specialists the tree calls for, run them in parallel, reserve `ehs-verifier` |
| **`mantis`** | `mantis-meta-agent`, its supervisor, free to fan out as its pipeline defines |

Four runs each. If the harness's concurrency cap forces either to fall back, **that is a fact
about running it here and it is recorded, not corrected** — it applies to both equally and it is
the environment a user would meet.

## The risk this round carries, named before it runs

Nine rounds of "level on detection" were measured against `mantis` with its architecture off.
**This round can show that against the product as shipped, this project is behind** — and that
is the outcome its author has the most reason to dislike and the least right to soften. If it
happens, the ledger's summary line changes from *level* to *behind*, and every page that said
level gets the same pointer this one will.

## Band, unchanged for the tenth time

Supported iff recall exceeds `mantis`'s by **≥ 5 points** *and* the decoy rate is **not higher**.
Refuted if `mantis`'s recall is greater or equal. Inconclusive if ahead by less than 5.

Failed nine times: four met the recall half, one met the decoy half, none met both. Lowered once
from 15, with the lowering declared. Never raised.

## Registered secondaries, without bands

- **Cost.** Wall time, tool calls and sub-agents spawned, per run, per arm. A pipeline that buys
  its result with six times the work has bought it, and the ledger has never printed that number
  beside the recall.
- **Did the squad form?** How many distinct specialists each `ours` run actually staffed, and
  whether `ehs-verifier` ran as a separate context. If it is still one agent, the round measures
  the same thing as the last nine and says so instead of pretending otherwise.
- **Decoys per shape**, the cut that made the last two rounds legible.

## Scoring and multiplicity

`../2026-08-26-coverage-rules/score.py`, unchanged, with `--sensitivity`; `adapt.py` over every
arm with no per-arm branch; floor of 3 valid runs; both arms under the artifact contract. One
round, then this corpus is retired.
