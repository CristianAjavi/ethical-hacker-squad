# Pre-registration — the routing stage, before anybody runs it

Committed with the cases and the key, and before a single model call. **Nothing
in this directory has been run.** There is no score anywhere in this repository
for this eval.

## Registration in force

Every number below that `gate-routing-stage.sh` can derive lives here once, and
the gate compares this block against what it measures on the run. It is read by
`scripts/gates/lib/routing_stage.py`; a disagreement is a failure, not a note.

```json
{
  "registered_on": "2026-09-10",
  "supersedes": "2026-09-01, frozen in b8f08eb, kept below word for word",
  "superseded_because": "coverage.md gained seven routing rows in 4c1731f, 48 minutes after the seal",
  "coverage_md_at_registration": "4c1731f",
  "table_word_router": {"role": 14, "role_and_sections": 12, "total": 22},
  "primary_cases": ["RT-04", "RT-10", "RT-16", "RT-17", "RT-19", "RT-20", "RT-21", "RT-22"],
  "primary_metric": "proportion of primary_cases answered correctly on (role, sections)",
  "runs_per_arm": 6,
  "prediction_points": 25
}
```

The table-word router scores 14/22 on the role and 12/22 on role and sections
together. The primary set is the cases it gets wrong: `RT-04`, `RT-10`, `RT-16`,
`RT-17`, `RT-19`, `RT-20`, `RT-21`, `RT-22`.

**Why this registration replaced the first one, and what that costs.** The
router is built out of `references/coverage.md`, so its score is not a property
of the dataset alone — the table is free to change, and it did. The seal on
`cases.json` did not move and no case was touched. **No model has seen these
cases and no score for this eval exists anywhere in the repository**, which is
the only condition under which re-registering is free: there is no result to fit
a registration to, and the gate now refuses a supersession made once one exists.
The first registration is kept below word for word, including the count it got
backwards, because a pre-registration that can be quietly edited is not one.

## What is unresolved

`references/coverage.md` is the first file `SKILL.md` sends a leader to after the
inventory, and what it has been measured on is **internal consistency**: that
every pack section it cites exists, that no row points at a gap its own gap list
calls closed (`gate-coverage-gap-claims.sh`, added the day before this dataset).

None of that is evidence that the table changes a routing decision. A model that
has read a security corpus already knows that an `AndroidManifest.xml` means the
mobile specialist. The open question is narrow:

> **Does holding the table change the answer where general knowledge routes
> wrongly?** Not on the easy rows — on `.cursor/mcp.json`, which is MCP
> configuration and is routed by the row about what runs when a tree is opened;
> on a `package.json` whose real signal is a three-day-old dependency and not the
> manifest; on an impersonation route that is an abuse question rather than a
> route defect.

## The honest weaknesses, stated before the design

1. **Part of the set is answerable by matching the table's own words.** The
   counts are in the registration block above, where the gate can reach them; an
   arm holding `coverage.md` can string-match those cases, so they are **not**
   the primary metric.
2. **The cases were written here**, by the hand that owns the corpus. The
   mitigation is partial and mechanical: the key's two scored columns are cells
   of a file the case author does not reinterpret, and a gate proves it. Which
   row a case belongs to is still a judgement.
3. **This corpus leads nothing on detection, measured eighteen times.** A routing
   result does not transfer to the end-to-end question and will not be presented
   as though it does.
4. **Routing is upstream of everything and is scored on nothing else.** Naming
   the right role is not the same as the specialist then finding the defect, and
   this eval cannot see the difference.

## Design

- **Two arms, byte-identical prompts**, differing only in whether
  `references/coverage.md` is in context. The without arm receives a vocabulary
  file — the eight role names and the pack file names, with no signals, no
  sections and no notes — so both arms can produce an answer in the same shape
  and only one holds the table.
- **Six runs per arm.** Three cannot separate a mean at this scale; that is what
  withdrew a claim in `../../runs/2026-08-22-precision-replication/`.
- **Cases are presented from `cases.json` alone**, and `gate-routing-stage.sh` is
  the check that no case carries a role name, a pack file name, a section marker
  or a procedure id.
- **Case order is shuffled per run**, seed recorded.
- **Scoring is mechanical**, against the sealed key, on the pair
  `(role, sections)`. Sections match on the cell string after whitespace
  normalisation. No judge model.
- The run records the commit of `cases.json` and its digest, and the author of
  the cases does not administer it.

## What is measured

- **Primary — the cases the table-word router gets wrong**, listed as
  `primary_cases` in the registration block: proportion answered correctly on
  `(role, sections)`. That set by six runs is the case-instance count per arm.
- **Secondary — the whole set**, every case in `cases.json`, reported alongside
  so a reader can see how much of any difference lives in the easy half.
- **Secondary, weak by construction — role alone.** Most of the set is reachable
  by matching the table, so a difference here is largely a difference in whether
  an arm had the table to match.

## Prediction, with a band

**On the primary cases the with-table arm is at least 25 points better on
`(role, sections)`, on the mean over six runs.** Below that the table is not
changing the routing decision on the cases where routing is hard, and a corpus
whose first routing artifact does not do that has a problem worth writing down.

**The whole-set difference is smaller than the primary difference.** If it is
larger, the table is helping most where a reader needed it least, and the
headline number would be measuring the easy half.

## What refutes it

- **Primary difference under 25 points.** The table does not change the answer at
  this scale, and the ledger records it.
- **Either arm above 85% on the primary set.** Ceiling: the cases are too easy
  to separate anything. The round reports that it could not measure and does not
  report the difference it happened to see.
- **The without arm is better.** The table is costing accuracy, and the next
  question is which rows.
- **Fewer than five runs per arm survive validation.** The round reports that it
  could not measure. It does not report a number from what is left.

## What each outcome forces

- **Prediction holds.** The claim written is exactly its scope: *on the cases in
  `cases.json`, written here, at one model scale, holding the routing table
  improves role and section selection on the cases general knowledge routes
  wrongly.* Not "the
  corpus routes better", and nothing about detection.
- **Prediction refutes.** `references/coverage.md` stays — it is what keeps a
  specialist from opening 4,450 lines — but the ledger records that its effect on
  a routing decision is unmeasured, and no claim about routing quality appears
  anywhere in the repository.
- **The without arm wins.** The rows it wins on are named, and the fix is to the
  rows, not to the eval.
- **Ceiling on both arms.** The cases are rebuilt harder before anything is
  claimed, and this file is superseded rather than reinterpreted.

## What this round will not establish

Nothing about detection: no case here asks a model to find anything. Nothing
about scale: one model. Nothing about a competitor: none is run. Nothing about
whether the sections a row names are the right sections — that is the corpus's
own editorial judgement and this eval takes it as given.

## Superseded registrations

Kept word for word. `gate-routing-stage.sh` reads everything in this file except
this section, so what is recorded here stays recorded and is never compared with
a later measurement.

### Registered 2026-09-01, sealed in `b8f08eb`; superseded 2026-09-10

> 1. **Nine of the twenty-two are answerable by matching the table's own words.**
>    `gate-routing-stage.sh` reports 13/22 on the role and 11/22 on role and
>    sections. An arm holding `coverage.md` can string-match those. They are
>    therefore **not** the primary metric.
>
> - **Primary — the nine cases the table-word router gets wrong** (`RT-03`,
>   `RT-10`, `RT-14`, `RT-16`, `RT-17`, `RT-19`, `RT-20`, `RT-21`, `RT-22`):
>   proportion answered correctly on `(role, sections)`. Nine cases by six runs is
>   54 case-instances per arm.
> - **Secondary, weak by construction — role alone.** Thirteen of twenty-two are
>   reachable by matching the table.

**What invalidated it.** The dataset was sealed at `b8f08eb`, 2026-09-01
09:13:34 -0500. `coverage.md` gained seven routing rows and a changed header
line at `4c1731f`, 2026-09-01 10:01:01 -0500 — 48 minutes later. The table-word
router is built out of that table, so the rows it can now match moved: the role
score rose by one, the role-and-sections score rose by one, two cases stopped
being hard and one started. The seal on `cases.json` did not move; no case was
edited; and the key still matches the table cell for cell, which is what the
first three checks of the gate had been saying all along.

**And a count it had backwards from the day it was written.** Its first
weakness said *nine of the twenty-two are answerable by matching the table* over
a line reporting 13/22 on the role. Thirteen were answerable and nine were not.
The nine it meant were the hard ones — the same nine its primary metric then
named — so the list was right and the sentence describing it was inverted. No
gate read either.
