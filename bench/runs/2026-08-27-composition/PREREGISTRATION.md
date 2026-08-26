# Pre-registration — a corpus that can tell the two apart

Written and pushed **before any arm runs and before this file's author has seen the corpus**.

## Why this round exists

The previous round could not answer its own question. Diffing the arms defect by defect gave
**identical reach — 32 of 33 each**, zero defects found only by one side, one found by neither.
A band asking for a 5-point recall lead is unmeetable on a corpus where both arms already sit
at the ceiling, and that is a fact about the corpus rather than about either product.

The single defect both arms missed says what a discriminating one looks like. `S-26`: a Next.js
`config.matcher` excluding `/api`, while the route handlers under `app/api/` relied on that
middleware for their session check. **Neither file is wrong on its own.** The defect exists only
in the relationship between them.

## The property being built for

At least **20 of the planted defects are composition defects**: no single file looks wrong, and
seeing the defect requires holding two or three files at once and noticing they do not line up
— a guard whose config does not cover the routes another file declares, a validator bypassed by
a second entry point, an invariant enforced in the API and not in the job that writes the same
table, a check on the primary path with a fallback that skips it.

The key records, per defect, `kind` (`composition` or `single-file`) and the `requires_files`
that must be read together. That makes the property **checkable rather than claimed**, and it
lets this round report recall **split by kind** — the number that says whether the corpus
discriminates at all.

## Arms and band

Four runs each: this project at the branch head, and `google/mantis` @ `56377ad` through
`mantis-meta-agent`. Both under the artifact contract, every finding carrying an answered
`FP-nn` rule.

**The band is unchanged for the fifth time.** Supported iff recall exceeds `mantis`'s by
**≥ 5 points** *and* the decoy rate is **not higher**. Refuted if `mantis`'s recall is greater
or equal. Inconclusive if ahead by less than 5.

It has now been failed four times, twice on each half. **It has never been raised, and it is
not being lowered.** The one time it moved — from 15 points to 5 — that was declared on the
page as a lowering.

## Registered predictions

**Primary, with the band above.** No separate prediction: after four rounds this author has no
calibrated basis for one, and inventing a number to look confident is the opposite of what
these pages are for.

**Discrimination, registered as the round's own validity check:**

> If **either** arm's reach exceeds **90%** of the planted defects, this corpus does not
> discriminate either, and the round reports that instead of a comparison — exactly as the CKAN
> round did, and as the previous round had to admit after the fact.

Registering it in advance is the whole point: last time it was discovered after the verdict.

**Split by kind, registered without a band:**

> Recall on `composition` defects against recall on `single-file` defects, per arm. If both arms
> score far lower on composition, the class is hard for the field and the corpus works. If one
> arm holds up, that is the first real capability difference any of these five rounds will have
> found.

## Scoring and multiplicity

`../2026-08-26-coverage-rules/score.py`, unchanged, with `--sensitivity`; `adapt.py` over every
arm with no per-arm branch; floor of 3 valid runs. One round, then this corpus is retired for
this question.
