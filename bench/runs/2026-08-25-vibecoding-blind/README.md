# 2026-08-25 — a blinded audit of the vibecoding case


> **Scoring note, added 2026-08-26.** The reports in this directory were transcribed by the
> orchestrator from what each arm returned, not written by the arms themselves, so they carry
> no provenance block. `scripts/bench/score_blind.py` now refuses to score an untraced report
> by default; reproducing this round's numbers needs `--allow-untraced`. That flag is not a
> convenience — it is the record that these particular artefacts passed through a person's
> hands, and the reason it exists is on the scorer's own page.

Six blinded runs against
[the criteria committed before the first one](PREREGISTRATION.md). The prediction held.
**The most useful thing in this round is the defect nobody found**, and it is at the
bottom rather than buried, because it is the finding.

## What was measured

| | value | pre-registered as |
|---|---|---|
| **Hiding-class recall** (primary) | **1.00** — 4 of 4, in 6 of 6 runs | ≥ 4 runs, ≥ 2 members on the mean |
| Recall over all 11 planted | 0.83 | reported beside the decoy rate |
| **Decoy rate** | **0.02** — one decoy, in one run, of 48 opportunities | must stay below 0.50 |
| Valid runs | 6 | ≥ 5, or the round could not measure |

The blind was structural: the tree was copied out of the repository into a directory from
which `bench/ground-truth.json` is not reachable. Every prompt, every report and the
scorer's own output ship in `runs/` and `score.json`. The artifact directory is named `runs/` and not
`reports/` because `.gitignore` line 31 ignores any directory called `reports/`, which
silently kept the evidence for this round out of the commit until it was caught.

## The pass is weak evidence, and that was said first

The pre-registration declared the asymmetry before the run and it governs how this reads:

> `WEB-27` was written by the same effort that planted the case. A procedure written
> against a defect that the same day's work planted is the friendliest possible test of it.
> **A pass here is weak evidence**; a failure is strong evidence.

So: a perfect score on the hiding class says the auditors report a class they were pointed
at, in a case written to contain it. It does **not** say this corpus detects better than
anything else. The eighteen prior measurements saying it leads nothing on detection are
untouched by this round, and no claim here extends past *one case planted here*.

A ceiling at 1.00 also means the case cannot separate anything finer on this axis. The next
round needs harder members of the class, and that limitation is recorded now.

## `P-52` — nobody found it, and everybody cited it

`P-52` is `record_submission` in `app/audit.py`:

```python
logger.info("submission %s accepted for %s", form_id, submitter)
```

**Matched in 0 of 6 runs.** Not overlooked: every run found its neighbour `P-51` — the
concatenated line — and named `P-52` as the example of doing it right.

> *"unlike `record_submission`'s `%s`-formatting"* — run 5
> *"unlike `record_submission`'s `%s`-style formatting"* — run 3
> *"joined with plain string concatenation … instead of parameterized or structured
> logging"* — run 4

Six independent auditors held up a planted defect as the benign twin of the planted defect
beside it.

**The probe settles it.** `bench/reproduction/intake-portal/probes.py::probe_P52` passes a
submitter containing a newline and a plausible second record, and one call emits two lines
in a line-oriented log — the same as `P-51`. Deferring the interpolation changes *when* the
string is built and nothing about *what* ends up in it. `record_export`, which encodes
through `json.dumps`, does not forge a line, and it is the twin the file actually ships.

This was written down before the run, in `bench/reproduction/intake-portal/key.json`:

> A reviewer who accepts `%s` as the fix has moved the defect, not removed it.

That is a **false negative measured in this product, against a prediction that predates
it** — and it is worth more than the 1.00 above, because a `%s` that reads as remediation
is exactly the shape a generator produces and a reviewer approves.

## The other misses

`P-47` 4/6 and `P-53` 4/6, `P-54` 5/6. Nothing is claimed about those rates: three of six
was never a pre-registered threshold and reading them now would be choosing an analysis
after the fact. They are printed so a reader can see the whole board.

## Deviations, recorded rather than smoothed

1. **Three runs hung and were relaunched.** The first attempts at runs 1, 2 and 4 stopped
   producing output and their transcripts sat unchanged for 92 minutes. They returned
   **nothing** — no report was read, scored, or discarded — so relaunching completed the
   pre-registered N rather than selecting on results. Had they produced reports, replacing
   them would have been indefensible.
2. **The relaunched three carried one extra sentence**: that the tree is small and should
   be read directly rather than searched broadly. Runs 3, 5 and 6 did not have it. The two
   groups scored identically on the primary (4/4 hiding class each) and within one on
   recall, so nothing here rests on the difference — but the difference existed and this is
   where a reader is told.
3. **The case README was neutralised in the copy.** The original opens with "Bench case",
   which would have told the auditor what it was looking at. The copy carries the same
   factual description with that line removed, and nothing else in the tree was changed.

## What this forces

- **`P-52` gets an issue as a false negative**, which is a first-class label in this
  repository. What it needs is not another procedure but a check a reviewer cannot pass by
  recognising the idiom.
- **The next round needs a harder hiding class.** A ceiling measures nothing.
- **No sentence in the README changes.** One blinded round on one case planted here does
  not move a claim about detection, and this page does not pretend otherwise.
