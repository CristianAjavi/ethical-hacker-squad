# Pre-registration — does refuting your own findings cost recall?

Written and pushed **before any arm runs, and before this file's author has seen the corpus**.

## What is being tested

The previous round was **not supported** on a conjunction: recall ahead by +5.9 points, decoy
rate **9.75 per run against `mantis`'s 5.25**. Depth generated candidates and nothing argued
against them.

The stage that does that argue existed. `SKILL.md` has said, since before `mantis` was ever
measured, that every `confirmed` and `probable` finding goes to `ehs-verifier` under `VER-09`
in a fresh context receiving *the assertion and its location and not the finder's narrative*.

Measured across those four runs: **`VER-09` zero times, `ehs-verifier` zero times, `ruled_out`
zero times.** `agents/ehs-web-api.md` mentioned neither, not once. The rule lived only in a
file the executing role never points at.

It is now the closing step of `First actions` in the seven auditing roles — the placement
already measured to work, where a step inside the pack was skipped by auditors who had read it
and, moved to the entry point, ran four times out of four.

## The band does not move

**Identical to the previous round**, deliberately:

- **Supported** — recall exceeds `mantis`'s by **≥ 5 points** *and* the decoy rate is **not
  higher**.
- **Refuted** if `mantis`'s recall is greater than or equal to ours.
- **Inconclusive** if ahead by less than 5 points.

This band was already lowered once, from 15 points, and that was written down as a lowering.
**Lowering it again after failing it would be moving the post after a loss**, so it stays
exactly where it was, including the conjunction that produced the failure.

## The registered prediction, with its own band

`VER-09` predicts a specific trade, and both halves are registered:

> **The decoy rate falls to at or below `mantis`'s**, *and* recall stays within **3 points** of
> the 97.8% the same procedures reached without it.

- If decoys fall and recall holds — the stage works, and the previous round's failure was a
  missing control rather than a defect in the coverage rules.
- **If decoys fall and recall falls more than 3 points** — the stage is not free. It bought
  precision by suppressing true findings, and that is reported as a trade, not a win. This is
  the outcome most worth catching.
- If decoys do not fall — `VER-09` at the entry point does not do what `SKILL.md` claimed for
  it, and the third instance of *a rule that lives where the executor does not look* was fixed
  in the wrong place.

## Corpus

Six services, different stacks from the previous corpus, 28–34 planted defects and **24–30
decoys deliberately made hard** — a value constrained by an allowlist in another file, integers
coerced upstream of a concatenated query, a permission narrowed by a condition elsewhere in the
same file, a documented public sample credential, a dead code path carrying a real defect.

Written by an author instructed not to read this project's procedures. The key sits outside the
tree. **The brief was still written here**, and it specified both properties under test, so
this measures whether the changes work and is a weak basis for any claim about the world.

Neither the eleven-product nor the six-service corpus is re-used: both are retired.

## Arms, scoring, multiplicity

Four runs each: this project at the branch head, and `google/mantis` @ `56377ad` through
`mantis-meta-agent`. Scored by
[`../2026-08-26-coverage-rules/score.py`](../2026-08-26-coverage-rules/score.py) — the same
file, already proved on synthetic fixtures — with `--sensitivity`, and `adapt.py` applied to
every arm with no per-arm branch. Floor: 3 valid runs, below which the answer is `2`.

One round. Whatever the outcome, this corpus is retired for this question.
