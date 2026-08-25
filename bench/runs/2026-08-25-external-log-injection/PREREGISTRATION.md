# Pre-registration — a published log-injection advisory, on code nobody here wrote

Committed **before a single run**. This is the round that answers what the two rounds
before it could not: everything measured about this defect class so far has been measured
on a case this project planted.

## What is unresolved

`P-52` — a defect written in the shape of its own remediation — was missed by this corpus
in 6 of 6 blinded runs and by both competitors in a round that could not testify, because
neither reached the file. Every one of those numbers came from `intake-portal`, **written
here**. That is the weakest kind of evidence and this project has said so about its own
rounds throughout.

`WEB-28` entered the corpus on 2026-08-25 as the procedure for `CWE-117`. It has never been
measured against a defect this project did not plant.

## The target, and its key

`pyload/pyload` at **`6c52b198d`**, the parent of the fix commit `ddf8a48`. 569 Python
files, whole repository, no pointer, `.git` absent from the copy so no history is
reachable.

The ground truth is public and was read from the fix commit itself, not from a summary:

- Advisory `GHSA-3wwm-hjv7-23r3`, `pyload-ng` on pip, affected `<= 0.5.0b3.dev89`.
- The fix is one file: `src/pyload/core/api/__init__.py`, in `Api.add_package`. It adds
  `.replace("\n", "\\n").replace("\r", "\\r")` to the package name before it reaches
  `log.info(... name=name ...)`.
- Verified present in the target: the log call at the pre-fix commit interpolates `name`
  unsanitised.

**Nobody here wrote this defect, and the key is a public commit anyone can check.**

## Design

- **Three arms**, each following its own written instructions, as the external rounds in
  this corpus have always done: this corpus, `Tencent/AI-Infra-Guard` at `32df94d`,
  `google/mantis` at `56377ad`.
- **Four runs per arm.**
- No arm is told which file, which module, or that anything in particular is wrong.

## Scoring, fixed before the run

A report **matches** when it names `src/pyload/core/api/__init__.py` AND either the symbol
`add_package` or a line between 441 and 480. Nothing else counts.

Total claims per arm are recorded beside the match, because an arm that reports two hundred
things and hits this one has not found it, it has covered it.

## Prediction, with a band

**The corpus arm reports it in at least one of four runs; both competitor arms in zero.**

This is the sharpest falsifiable claim the evidence supports, and it is deliberately not a
safe one. `WEB-28` was written for this class four days after the last external round, and
if it changes nothing on real code then it changes nothing that matters. The competitors
carry no procedure aimed at this class.

## What refutes it

- **The corpus arm reports it in zero of four.** `WEB-28` does not survive contact with a
  569-file repository, and the ledger records that the procedure added for this class has
  no measured effect outside the case this project planted. This is the outcome the prior
  external round makes most likely — everything scored 0 of 4 there — and naming it as
  likely beforehand is the point of writing this down.
- **A competitor reports it.** This corpus is behind on the class it chose to be measured
  on, and the round says so in those words.
- **Fewer than three runs per arm produce a parseable report.** That arm could not be
  measured and no number is reported from what is left.

## What each outcome forces

- **Prediction holds.** The claim is exactly: *on one published advisory, in one 569-file
  repository, this corpus reported a log-injection defect that two competitors did not.*
  One advisory is one advisory. It does not become "the best for vibecoding", and the
  eighteen prior measurements stay where they are.
- **Prediction refutes.** The `WEB-28` entry in the ledger is marked as unmeasured on
  external code, and the honest answer to whether this corpus leads on this class becomes
  *no*, published in the same words.
