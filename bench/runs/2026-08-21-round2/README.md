# Run 2026-08-21 — second rule-picked round, and the answer it gives


> **The run prompts for this round were not kept.** A later round measured the same unaided arm on the same target with the same blind instrument and a freshly written prompt, and scored 0.60 where this family of rounds scored 0.81 — twenty-one points from the prompt alone. **The numbers below are internally valid and are not comparable to numbers from another sitting.** See `../2026-08-21-unaided-pass/`, which archives every prompt it used.


> **Outside information was not settled in this round.** No prompt in this bench said whether consulting sources beyond the target — an advisory database, an upstream branch, a diff against another version — was allowed, and later rounds found that some runs did consult them. **Any recall number here measures review and library familiarity together and cannot separate them.** Consistency comparisons are unaffected: they compare runs of one arm, which had the same latitude. `../../prompts/external-sources.txt` is the clause that closes this for later rounds; it did not exist when this one ran.

The first rule-picked round tied at 2/3 for every arm, and its shared miss produced `WEB-23`. Finding that same advisory again afterwards proved only that the lesson had been encoded. This round is the open question: with everything the corpus learned that day already in it, does it beat the alternatives on cases nobody here had seen?

Three advisories chosen by the same published rule, recorded with their five rejects before any arm ran. Three arms, blind judging, 88 finding-to-advisory pairs with opaque ids and an order fixed by a hash unrelated to the arm.

## Result

| Advisory | With the corpus | Without it | Competitor |
|---|---|---|---|
| `CVE-2026-71417` — any user revokes any certificate at the CA via a duplicate record | **missed** | **missed** | **missed** |
| `CVE-2026-71308` — unchecked `replaces[]` hijacks auto-rotation | **missed** | **missed** | **missed** |
| `CVE-2026-71307` — low-privilege read of plaintext destination credentials | **found** | **found** | **found** |
| | **1 / 3** | **1 / 3** | **1 / 3** |

**A second flat tie, in the classes where this corpus is strongest.** That was written into `provenance.json` before the numbers existed, precisely so it could not be explained away afterwards: these are broken-authorization and credential-exposure defects, the core of `web-api.md`. If the corpus does not lead here, it does not lead where it is best.

## Both rule-picked rounds together

| | Corpus | No corpus | Competitor |
|---|---|---|---|
| round 1 (Go, three advisories) | 2/3 | 2/3 | 2/3 |
| round 2 (Python, three advisories) | 1/3 | 1/3 | 1/3 |
| **total** | **3 / 6** | **3 / 6** | **3 / 6** |

Six advisories, selected by a published rule, in two ecosystems and four projects. **Identical.** Not one advisory separates the three arms in either direction.

## The two misses, and whether they were findable

Neither miss can be blamed on the file subset, and it is worth saying so rather than leaving the excuse available.

- **`CVE-2026-71417`.** The advisory's chain needs the upload route to accept an `authority` with no `AuthorityPermission` check. That contrast is **visible in the file every arm was given**: `AuthorityPermission` is imported at `views.py:22` and enforced at `:529` inside the *create* handler, while the *upload* handler at `:558` does not use it. One gate present, its sibling absent, in one file — the exact shape `WEB-05` is written around. Eight findings across the arms landed `partial` on that route; none joined it to manufacturing creator status by uploading somebody else's certificate.
- **`CVE-2026-71308`.** `replaces` appears twelve times in `views.py` and twice in `service.py`, so the flow is visible; what is **not** in the subset is `schemas.py`, where the array is resolved into live ORM objects. That is a genuine limit of the scope, and it is the one place in this run where the target may be short of what the defect needs. It produced **0 `yes` and 0 `partial` from 35 findings** — nobody came near it.

## What separates the arms, since recall does not

| Arm | Findings reported across both targets | Advisories found |
|---|---|---|
| treatment | 12 | 1 |
| control | 23 | 1 |
| competitor | 18 | 1 |

Same recall, roughly half the output. Consistent with a triage discipline doing its job — every reported finding had to survive `FP-01`..`FP-10`, and the corpus arm capped findings at `probable` with `FP-08` answered `UNKNOWN` wherever the confirming code was outside the delivered files, while the control arm asserted several of the same things flatly. **This run cannot say which behaviour is better**: it has a key for three advisories and none for the other 50 findings, so calling the extra output noise would be exactly the self-flattery the decoy column exists to prevent. Measuring that is a different run, and it does not exist yet.

## What this settles

The claim under test was that this is the best thing of its kind currently available. **Six rule-picked advisories say it is not — it is level.** On code nobody here selected, the corpus performs the same as a competent engineer with no corpus and the same as a neighbouring product, and the one case in seven where it pulled ahead is one we chose ourselves.

What it can claim, and what none of the alternatives can, is the row above being here at all: a published, rule-selected, blind-judged number, with the ties and the misses in the same table as the win, and the arms' own artifacts stored beside it.

## Files

`provenance.json` was written before the results: the selection rule, the three declared limitations, and the host authentication failure that killed both competitor arms mid-run and how it was handled. `judgements-deblinded.json` is every verdict joined back to its arm. `arms/` holds the six artifacts as delivered. `withheld-summary.json` lists the 50 findings that match no published advisory by class and severity only — they are a live project's possible defects, and publishing their mechanisms here would be disclosure by us.
