# Pre-registration — the same procedures, measured with their own control switched on

Written and pushed **before any arm runs and before this file's author has seen the corpus**.

## What is being corrected

Three rounds measured this project's decoy rate with a harness that asked each arm for
`{title, location, class, severity, evidence, impact, recommendation}`. The shipped artifact
contract — `findings.schema.json`, enforced by `gate-findings-artifact.sh` — requires every
finding to also carry a `triage` array naming at least one `FP-nn` rule and answering it
`HOLDS` / `DOES_NOT_HOLD` / `UNKNOWN` / `NOT_APPLICABLE`.

**That is this project's false-positive control, and the measurement removed it at the door.**
The full account is in
[`../2026-08-26-refutation-stage/HARNESS-DEFECT.md`](../2026-08-26-refutation-stage/HARNESS-DEFECT.md).

## The trap this round is walking into, named before it runs

Re-measuring after three unfavourable results, with a change expected to help, is the shape of
motivated re-analysis. Three things are fixed in advance so the result can be read against it:

1. **A fourth corpus.** The retired ones stay retired; no prior target is re-run.
2. **The band does not move.** Identical for the fourth time: recall ahead by **≥ 5 points**
   *and* decoy rate **not higher**. It has been failed twice on the same half and stays.
3. **A favourable result here is worth less than an unfavourable one**, and the page must say
   so. Three rounds of unfavourable numbers were produced by a harness this author wrote; a
   favourable number produced by the same author fixing his own harness is exactly the
   sequence that should be distrusted.

## The arms

| arm | change | runs |
|---|---|---|
| **ours** | branch head, reporting under the **shipped schema**: every finding carries `procedure`, `confidence`, `traceability` and a `triage` array with at least one answered `FP-nn` | 4 |
| **`mantis`** @ `56377ad` | unchanged, through `mantis-meta-agent`, **same required shape** | 4 |

The schema applies to **both** arms. `mantis` filters false positives inside its own stages and
does not need the artifact shape to trigger it, so this asks it for bookkeeping it already
does — that is a cost to them of the correction and it is stated rather than hidden.

## Registered prediction, with its band

> With the triage field required, this project's decoy rate falls **to at or below `mantis`'s**,
> and recall stays within **3 points** of the 96.3% the same procedures reached without it.

- **Decoys fall and recall holds** — the false-positive control works, and the previous three
  pages measured a configuration nobody ships. Even then it is one round, on a corpus this
  project commissioned, by the author who found the defect.
- **Decoys fall and recall drops more than 3 points** — the control buys precision by
  suppressing true findings. A trade, reported as a trade.
- **Decoys do not fall** — the artifact contract is bookkeeping rather than a control, and the
  precision gap is a property of these procedures and not of the harness. **This is the outcome
  that would most change what this project believes about itself**, and it is named here so it
  cannot be quietly reframed later.

## Secondary, registered without bands

- **Answered rules per finding** — how many distinct `FP-nn` rules each arm actually answers,
  and how often the answer is `UNKNOWN`. A contract satisfied by writing `NOT_APPLICABLE`
  everywhere is a form filled in, not a control exercised, and that is checkable.
- **Cost** — tool calls and wall time per run, both arms.

## Corpus

A fourth corpus: six services, stacks distinct from both previous ones, 28–34 planted defects
and 24–30 **hard** decoys of the same shapes — constrained elsewhere, coerced upstream, narrowed
by a sibling condition, public sample credentials, unreachable behind an earlier layer, dead
paths carrying real defects. Written by an author instructed not to read this project's
procedures; the key lives outside the tree; the brief is still written here.

## Scoring and multiplicity

`../2026-08-26-coverage-rules/score.py`, unchanged, with `--sensitivity`; `adapt.py` over every
arm with no per-arm branch; floor of 3 valid runs. One round, then this corpus is retired.
