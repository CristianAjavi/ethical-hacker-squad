# 2026-08-26 — the join moves composition detection by a third of what was asked

**Not supported.** The band asked for **≥ 8 points** of composition recall. It moved **+3.1**.

| arm | composition | single-file | overall | decoys / run | findings / run |
|---|---|---|---|---|---|
| **without** the join (4 stored runs) | 62.5% | 93.8% | 72.9% | 5.00 | 51.8 |
| **with** it (4 new runs) | **65.6%** | 93.8% | 75.0% | 5.50 | 54.8 |

**+3.1 points is 0.75 defects out of 24.** Single-file recall did not move at all, and the decoy
rate rose 0.50 — inside the 1.0 the band allowed, so the outcome named in advance as most worth
catching, *recall bought with noise*, did not happen.

The tool does what it claims. It does not do enough of it.

## What this is and is not

A **within-arm** measurement: same corpus, same key, same prompt, this project's arm with the
tool against the same arm without it. **It says nothing about `mantis`** and no sentence here
compares. The corpus was reserved for this question in writing, on its own page, before today's
outcome was known.

## The ceiling was declared before the runs, and it held

From [the pre-registration](PREREGISTRATION.md):

> Eight points is roughly two of the 24 composition defects. It is set there because the tool
> names one shape of the class, not the class: three of six services in this corpus express
> their guards in forms it cannot read — nginx `allow`/`deny`, Koa middleware, CDK policies —
> so a ceiling well below the full 37.5-point gap is expected from the start.

That is what happened, and 8 points turned out to be optimistic rather than conservative. The
band was not met and it is not being reinterpreted.

## A defect in the tool, found by a real run rather than by its battery

Run 1's provenance records something no fixture had shown:

> `path_coverage.py` whole-tree — **32 UNGUARDED siblings**, but every line joined against one
> guard string because the tree holds six independent services; treated as a worklist.
> `path_coverage.py` per directory (my addition, to remove that noise) — isolated the real one:
> **ledger-flow DEAD GUARD, `'/internal'` guards nothing.**

Pointed at a tree of independent services, the join puts every route in one namespace, so
almost everything reads as *unguarded while a sibling is protected*. **32 false signals**, and
the run only found the real defect because it re-ran the tool per directory on its own
initiative.

The tool was **not** changed while the remaining three runs were in flight — changing the
instrument mid-arm invalidates the measurement. The fix is filed: partition by top-level
directory, and say in the output why it partitioned.

Whether that fix would have carried the +3.1 to the band is a **hypothesis**, and this corpus is
now retired for the composition question by the same pre-registration, so it cannot be answered
here. That is the cost of having committed to the retirement, and it is the right cost.

## What ships

The four new reports in [`runs/`](runs/), each with `tools_run` and `from_tool` — the first
time any round can say which findings came from a tool rather than from a reading. The
`without` arm is not copied: it is the four already published in
[`../2026-08-27-composition/runs/`](../2026-08-27-composition/runs/), unmodified.
