# Correction — `mantis` is a direct competitor, and four rounds ran the wrong part of it

This supersedes the `google/mantis` half of [`AMENDMENT.md`](AMENDMENT.md), written twenty
minutes earlier. The amendment is left standing rather than edited, so the mistake and its
correction are both visible.

## What the amendment got wrong

It judged the whole product by one skill. `mantis-advise` does say *"Don't use for automated
multi-pass red-team exploitation"* — but `mantis-advise` is **one of nineteen skills**, and the
product's own entry point is a different one:

> **`mantis-meta-agent`** — *"Acts as the persistent supervisor, launching and monitoring the
> automated review campaign."*

Its `README_AGENTS.md` draws the pipeline it supervises: history → architecture → threat model
→ plan → **researcher** (*"Audits production source code files"*) → dedupe → review → critic →
chain → calibrate → reproduce → report → patch.

**That is exactly the job this project claims.** Sweep a repository, audit source, deduplicate,
filter false positives, verify by reproducer, score risk, report, patch. `mantis` is not out of
scope. It is the closest thing to a direct competitor this project has found, and it is a more
elaborate pipeline than this one.

## The part that cuts against this project

Four rounds in this repository ran the `mantis` arm through **`mantis-advise`** — the single
skill its own description excludes for this use — and reported the resulting numbers:

| round | what was published for `mantis` |
|---|---|
| `2026-08-25-vibecoding-comparative` | recall 0.20, `P-51` 1 of 4, **2 of 4 runs empty** |
| `2026-08-25-external-log-injection` | 0 of 4 on the advisory, 3 claims, **3 of 4 runs empty** |

Those numbers are what an advisor produces when asked to run a sweep. **They understate the
product and they should never have been published as its performance.** The pages carrying them
already refused to claim superiority — that refusal is the only reason this is a correction and
not a retraction — but the tables are wrong and are now marked so.

The mistake was not subtle and it was available to be caught at any point: it required reading
the other eighteen `SKILL.md` files, which is what picking a fair entry point means. It was
found only when this round went looking for a comparison set, which is late.

## What is *not* corrected

The `Tencent/AI-Infra-Guard` half of the amendment stands. All four of its skills were read.
`aig-scanner` submits tasks to a remote `taskapi` and requires `AIG_BASE_URL`; the other three
scope to the OpenClaw environment, to skills, and to red-teaming agents. None audits an
application codebase, and its mechanism cannot execute offline.

## What happens now

`mantis` is re-run on this round's eleven-product tree **through `mantis-meta-agent`**, its own
entry point, four runs, scored by the same key and the same rule as the `ours` arm. Whatever
that produces is what gets published.

Until it has run, **this repository has no valid competitor measurement of any kind**, and the
question *"are we the best"* has no supporting evidence in either direction.
