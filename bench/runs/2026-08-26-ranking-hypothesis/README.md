# 2026-08-26 — is it ranking? Django, `CVE-2025-48432`


> **Scoring note, added 2026-08-26.** The reports in this directory were transcribed by the
> orchestrator from what each arm returned, not written by the arms themselves, so they carry
> no provenance block. `scripts/bench/score_blind.py` now refuses to score an untraced report
> by default; reproducing this round's numbers needs `--allow-untraced`. That flag is not a
> convenience — it is the record that these particular artefacts passed through a person's
> hands, and the reason it exists is on the scorer's own page.

**Refuted. 1 of 4, against a band of 2 of 4.** And the same round produced the first
recovery of a keyed defect on external code this project has measured — both of those are
true and the first one is the result.

## What was measured

Target: Django at `08187c94ed`, the parent of `a07ebec559` (*"Fixed CVE-2025-48432 — Escaped
formatting arguments in `log_response()`"*). 2,839 Python files, `.git` absent. Key pinned
from the diff: `django/utils/log.py`, `log_response`, lines 217–257, defect at 248.

| | corpus arm |
|---|---|
| band, committed beforehand | ≥ 2 of 4 |
| measured | **1 of 4** |
| total claims | 8 |

Only the corpus arm ran. The second prediction — that competitors would report it in fewer
runs — is vacuous against a corpus arm that scored 1, and the sequencing was declared before
the runs rather than chosen after them.

## The run that found it

Run 4 reported `django/utils/log.py:248` and traced the chain end to end: `request.path`
built in `get_bytes_from_wsgi()` with no CR/LF stripping, through
`getattr(logger, level)(message, *args)`, firing on every 4xx/5xx response via
`base.py:143-149`, and noted the CSRF reason string carrying raw `HTTP_ORIGIN`/`HTTP_REFERER`
into the same sink.

**This is the first time in any external round that any arm reported the keyed defect.** On
`pyload`, across three corpus rounds and two competitor arms, the count was 0, 1 of 3, 0, 0
and 0. That is worth recording. It is **not** worth calling a success: the band was 2, set
with Django's size already known, and one run in four is below it.

## An anecdote that did not replicate

The previous round noted that the single run which found the `pyload` advisory produced the
**fewest** claims of its three, and offered breadth-versus-depth as a hypothesis for a later
round to pre-register. Here the run that found it took **1,092 seconds and 130 tool calls**,
the longest and most expensive of the four, and produced 2 claims against another run's 4.

The pattern does not hold. It was labelled an anecdote when it was recorded and it is
retired as one now, rather than quietly carried forward until a round happens to fit it.

## What counting the list before the run already forced

The precondition on the pre-registration page — record the enumerated list's size *first* —
found that **the query shipped that morning did not list this defect at all**. Django selects
the level at runtime with `getattr(logger, level)(...)`, so the call is an `ast.Call` and not
an `ast.Attribute`, and 206 sites came back from 2,839 files with the vulnerable one absent.

The corrected query returns **207 — one more, and that one is the advisory.** Had the round
run against the broken query, `0 of 4` would have been recorded as a fact about ranking when
it was a fact about the query, and the empty result would have read as coverage.

The step is not a substitute for a reviewer who reads what the code does. It only decides
where that reviewer looks, and it can be wrong about that too.

## What this forces

- **Four interventions have now failed to move this class past its band.** Describing,
  enumerating, delivery, ranking. The honest position published in
  `../2026-08-25-external-log-injection/` stands unchanged.
- **The `1 of 4` goes in the ledger as the first external recovery**, with the band it missed
  printed beside it. It does not enter the README, and no claim about detection is made from
  it.
- **The next question is not another placement.** Four placements have been tried. What has
  not been tested is whether *any* instruction changes this, or whether the variance between
  runs simply dominates at this scale — which is a question about how many runs a claim at
  this size needs, not about where a sentence lives.

## Two claims about Django that this page does not make

Runs 1 and 3 reported findings in `flatpages` and `auth/middleware` that are **unverified
bench artifacts**, produced by a blinded audit and not checked against Django's own security
process. They ship in `runs/` as data about this corpus. They are not presented as
vulnerabilities in Django, and nobody should read them that way.
