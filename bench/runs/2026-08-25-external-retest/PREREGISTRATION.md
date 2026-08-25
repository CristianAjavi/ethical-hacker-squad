# Pre-registration — the same advisory, after the procedure was changed

Committed **before the re-run**. This is an A/B with one variable: the target, the key, the
scoring rule and the arm are identical to
[`../2026-08-25-external-log-injection/`](../2026-08-25-external-log-injection/), and the
only difference is that `WEB-28` now opens with a mandatory enumeration step.

## What the previous round established

Three arms, four runs each, on `pyload/pyload` at `6c52b198d`. **0 of 4 everywhere**,
including this corpus. The diagnosis was not that the procedure describes the defect badly —
it describes it well, and the same procedure found the neighbouring half of the pair in 6 of
6 runs on a seventeen-file tree. The diagnosis was **targeting**: at 569 files an auditor
budgets its reading and never opens the file the defect is in.

## The change under test

`WEB-28` now requires the auditor to enumerate every logging call whose message is not a
plain literal, mechanically, **before** reading anything, and gives the command. On this
target the query returns **218 sites**, one of which is the advisory. That number was
measured before this file was written and is not a prediction.

Nothing else about the corpus changed. No new procedure, no new rule, no change to the
target or the key.

## Design

- **Same target**, byte-identical, `.git` absent.
- **Same arm** — this corpus, following its own references — and **four runs**.
- **Same scoring**: a report matches when it names `src/pyload/core/api/__init__.py` AND
  either the symbol `add_package` or a line between 441 and 480.
- The prompt is unchanged from the previous round. The auditor is not told about the
  enumeration step, the file, or that a previous round exists: it reads the references, and
  the references now tell it to enumerate.

## Prediction, with a band

**At least 2 of 4 runs report the advisory.** Enumerating turns the task from *choose which
of 569 files to read* into *work through 218 named call sites*, and the file is in the list.
If a step that puts the answer on a reviewable list does not change the outcome, then the
corpus's problem is not targeting and this diagnosis was wrong.

**Total claims do not collapse.** The previous round's corpus arm produced 25 claims across
four runs. If enumeration narrows the audit so far that the arm stops finding the other
classes, the step has bought one defect and sold the rest.

## What refutes it

- **Fewer than 2 of 4.** Targeting was not the problem, or an instruction to enumerate is
  not enough to make an auditor enumerate. Either way the diagnosis in the previous round's
  page is wrong and gets corrected there, in its own words.
- **Claims fall below half of 25.** The step is reported as a trade rather than an
  improvement, with both numbers printed.
- **Fewer than 3 runs return a parseable report.** The round could not measure and no number
  is reported from what is left.

## What each outcome forces

- **Prediction holds.** The claim is exactly: *a mandatory enumeration step recovered a
  published advisory that the same procedure missed 4 times without it, in one repository.*
  One repository. It does not become a claim about detection generally, and the earlier
  round's `0 of 4` stays on its page as the measurement it was.
- **Prediction refutes.** `WEB-28` is documentation that does not change an answer at scale,
  the enumeration step is reverted or kept as unmeasured, and the honest position stays what
  the previous round already published: on this class, on real code, this corpus does not
  lead.
