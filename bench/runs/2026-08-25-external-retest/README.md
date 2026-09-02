# 2026-08-25 — the same advisory, after the procedure changed


> **Scoring note, added 2026-08-26.** The reports in this directory were transcribed by the
> orchestrator from what each arm returned, not written by the arms themselves, so they carry
> no provenance block. `scripts/bench/score_blind.py` now refuses to score an untraced report
> by default; reproducing this round's numbers needs `--allow-untraced`. That flag is not a
> convenience — it is the record that these particular artefacts passed through a person's
> hands, and the reason it exists is on the scorer's own page.

**The prediction is refuted.** One of three valid runs recovered the advisory, and the band
committed beforehand was at least two of four.

## What was measured

Same target, same key, same scoring, same arm. One variable: `WEB-28` now opens with a
mandatory enumeration step that lists every logging call whose message is not a plain
literal. On this target that query returns 218 sites and the advisory is one of them.

| | runs | reported the advisory | total claims |
|---|---|---|---|
| before the change | 4 | **0** | 25 |
| after the change | 3 valid | **1** | 24 |

The second pre-registered condition held: claims did not collapse. The step did not buy one
defect by narrowing the audit away from everything else.

## Why this is refuted and not a success

The band was two of four, written before the run. One of three is below it, and reading
`0 of 4 → 1 of 3` as a win after seeing it is the fitting this apparatus exists to prevent.

What the previous round's page said — *targeting is the problem* — is **corrected here, in
its own words**: an instruction to enumerate does not reliably make an auditor enumerate.
Two of the three runs read the reference material, had the mandatory step in front of them,
and did not do it. The step changed the outcome once, which is not nothing and is not the
claim.

## The run that found it was the shortest

| run | claims | found it |
|---|---|---|
| 1 | 9 | no |
| 3 | 11 | no |
| 4 | **4** | **yes** |

The one run that recovered the advisory produced the fewest claims of the three, and its
reasoning traced the whole chain: the `add_name` form field, only `.strip()`ed; the
`log.info` sink; and **the consumer** — the `/logs` viewer's line-by-line regex — plus a
check that Python's `logging.Formatter` does not escape control characters.

That is a pattern worth a hypothesis and it is **not** one this round tested: breadth and
depth may trade against each other here. The next round pre-registers it or it stays an
anecdote.

## The fourth run, and why it was not replaced

Run 2 hung. Its transcript sat unchanged for 24 minutes while the others finished in 9 to
13, and it was stopped.

**It was not relaunched, and the reason matters.** Earlier today three hung runs were
relaunched on the principle that a run returning *nothing* can be replaced without selecting
on results. This one is different: a sub-agent it had spawned routed its slice to the
orchestrator when it could not reach its parent, so part of its work was seen — a pass over
extractors, containers and decrypters that contained **no** match for the advisory.

Relaunching a run whose partial output was already known not to contain the answer is
selecting on results, however unintentionally. So the round reports three runs and the
prediction fails on three, rather than four runs and a cleaner number.

The leaked slice is not in `runs/` and was not scored. It is described here because a
sub-agent's output reaching the orchestrator instead of its parent is a real methodological
event, and a reader deciding how much to trust this page should know it happened.

**It arrived in full after the parent was stopped, and it confirms the decision rather than
merely justifying it.** Fourteen findings, none matching. It did report
`src/pyload/core/api/__init__.py` — but at `parse_urls`, line 496, for server-side request
forgery: a different symbol, outside the keyed range, and not this advisory. So the run that
was not relaunched is now known not to have contained the answer, which is what was assumed
when the decision was taken and is the only reason the decision was safe.

## What this forces

- **The enumeration step stays**, marked as *changed the outcome once in three, below the
  pre-registered band*. It is not reverted: the claim count held and one recovery is not
  evidence against it either.
- **The next round tests delivery, not text.** The failure is not that the procedure is
  wrong; it is that two auditors holding it did not execute the step it marks as mandatory.
  A procedure a reader can skip is a procedure that does not run.
- **The honest position is unchanged from the previous round.** On this class, on real code,
  this corpus does not lead. One recovery in three does not move that sentence.
