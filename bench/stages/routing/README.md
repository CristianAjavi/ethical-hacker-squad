# The routing stage, measured on its own

`../triage` measures what the squad does with a finding somebody wants dropped.
This directory measures the step before any of that: given a fragment of a real
inventory, which specialist gets staffed and which part of its pack gets opened.

It is the second per-stage dataset in this repository. `google/mantis` ships
eight, and that half of the gap is still wide. What follows is the half we can
argue about.

## Why routing, and why the key can be checked

A per-stage eval is worth its cost when somebody other than the key's author can
check the key. `../triage` has that because `references/triage.md` forces the
consequence column from its own table. Routing has it for a different and
simpler reason:

> **The answer is a row of `references/coverage.md`.** The key names the row, and
> `../../../scripts/gates/gate-routing-stage.sh` re-reads the file and takes the
> `Role` and `Pack sections` cells itself. A key that drifts from the table is a
> failure, not a difference of opinion between two documents.

That is the whole reason this stage was chosen over, say, severity assignment,
where the key would be an opinion with a file name.

## What is in here

`cases.json` — twenty-two cases, no answers. One case is one routing step: a few
paths and excerpts, nothing else, and the step is to name the role and the pack
sections. `keys/routing-key.json` — the sealed key, one row per case, carrying a
digest of `cases.json` so a stale key announces itself.

Eight role classes: `ai-safety`, `web-api` and `privacy-abuse` with four cases
each, `mobile`, `local-app`, `supply-chain`, `infra-cloud` and
`` `infra-cloud` + `supply-chain` `` with two. The commonest class is 4 of 22, so
a stub that always answers the same thing scores 18%.

## The measurement that shaped the set, reported before anybody ran anything

A routing case whose text repeats the words of the row that routes it measures
string matching. So the gate builds a router out of the table's own vocabulary —
every backticked token in a `Signal` cell, plus the content words the table does
not spread over more than three rows — and reports what it scores:

| Instrument | Score |
|---|---|
| Table-word router, role only | **13 / 22** |
| Table-word router, role **and** sections | **11 / 22** |
| Generic separability floor (`gate-stage-eval-floor.sh`), bag of words over the case text | **18% of 22**, exactly the majority-class rate |

**The first draft held fifteen cases and the router scored 12 of 15 on the role.**
Nine of ten cases carrying signal is not a set; it is three cases and some
scaffolding. Seven cases were added from rows the set had not used, the router
was run once more, and the number that came back — 13 of 22 — is the one printed
above and by the gate on every run. Nothing was removed, no case was reworded to
move the number, and no model has seen any of it.

Only the degenerate outcome is enforced: a set the router answers **perfectly**
fails the gate, because it has nothing left to say. A threshold picked after
seeing the number would be the number.

## Two instruments that disagree, and why both are right

The generic floor says the case text carries no signal at all — 18%, which is
what always answering `ai-safety` would score. The table-word router says 13 of
22. Both are correct, and the gap between them is the point:

- The floor asks whether **the cases sort themselves**: pool every other case by
  answer, see which pool the held-out one shares vocabulary with. Routing cases
  do not, because two `web-api` cases are an upload handler and a link preview
  and share almost no words.
- The router asks whether **the table's vocabulary sorts them**, which is the
  actual shortcut available to anything holding `coverage.md`.

`../triage` needed the first and would learn nothing from the second, because
its answers are a closed verdict vocabulary rather than rows of a lookup table.
Routing is the reverse. A single instrument pointed at both stages would have
cleared this dataset without looking at the shortcut that matters to it.

## What has not happened

**This eval has not been run.** No model has seen these cases, no score exists,
and none is claimed anywhere in this repository. `PREREGISTRATION.md` in this
directory is what will be run, what counts as a result, and what refutes it,
written before the first model call.

## What this cannot measure

Whether a case is well chosen, and whether the row the key names is the row a
careful reader would name — both editorial, and the gate says so out loud.

It also cannot measure the thing routing is for. A squad that names the right
role on all twenty-two of these and then never opens the file holding the defect
scores full marks here and fails the only question `../../runs/` asks.
