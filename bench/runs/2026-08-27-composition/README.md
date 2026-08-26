# 2026-08-27 — a blind spot that belongs to the field, not to either product

> **The arms were not given the same instruction.** Every `mantis` launch in this round
> carried *run the stages inline rather than spawning sub-agents*, and no `ours` launch
> carried anything like it. `mantis` is a supervised nineteen-skill pipeline; told to run
> inline it becomes what this project already is. This round therefore compares two prose
> corpora executed by one agent each, **not two products as they ship**. The numbers stand;
> the claim narrows. See [`../CORRECTION-inline-constraint.md`](../CORRECTION-inline-constraint.md).

**The band is refuted.** And it is the least interesting thing on this page.

| arm | runs | recall | decoys / run | findings / run |
|---|---|---|---|---|
| this project | 4 | 72.9% | 5.00 | 51.8 |
| **`google/mantis`** @ `56377ad` | 4 | **73.6%** | 4.75 | 41.5 |

`mantis` ahead by 0.7 points — a quarter of a defect out of 36 — so *refuted if `mantis`'s
recall is greater than or equal to ours* applies. Refuted.

## The corpus discriminates, and the check for that was registered in advance

The previous round could not answer its question because both arms reached 32 of 33. This
round's pre-registration fixed the test **before the runs**:

> If either arm's reach exceeds 90% of the planted defects, this corpus does not discriminate
> and the round reports that instead of a comparison.

| arm | reach |
|---|---|
| this project | **83.3%** |
| `mantis` | **88.9%** |

Both under the line. Recall fell from ~95% on the previous corpus to ~73% here. **The corpus
works**, and that is what makes the next table mean something.

## What the split by kind found

Registered without a band, as the round's own question:

| arm | **composition** defects | **single-file** defects |
|---|---|---|
| this project | **62.5%** | 93.8% |
| `mantis` | **60.4%** | **100.0%** |

**Both arms find essentially every single-file defect and lose four in ten composition
defects.** A forty-point collapse, in the same place, for two products with entirely different
architectures — one a nine-role prose corpus, the other a fourteen-stage pipeline with its own
adversarial review.

And the three defects **neither** arm found in any run are **three out of three composition**:
`T-31`, `T-32`, `T-34`.

## Why this is the result and the band is not

Five rounds asked *which of these two is better*, and the answer has now been: behind, ahead
with noise, ahead with noise, level, level. Every intervention moved this project along a
curve; none moved it off. **This round says why.** The thing both products are good at —
reading a file and recognising a defect in it — is close to saturated. The thing neither is
good at is holding two or three files at once and noticing they do not line up:

- a guard whose config tests `/internal` while the blueprint mounts at `/api/internal`
- an auth plugin registered inside an encapsulation scope, with the admin routes as siblings
- an nginx edge carrying the only copy of every control, and a compose file publishing the app
  port beside it
- an invariant honoured by the ORM path and bypassed by the bulk importer that writes the same
  table

None of those files is wrong alone. **That is the class**, it is worth 40 points to whoever
solves it, and on this evidence **nobody has.**

## What this does not claim

- **Not a win.** 62.5% against 60.4% on composition is two points on 24 defects; the two arms
  are as indistinguishable here as everywhere else.
- **One corpus, commissioned by this project**, whose brief asked for exactly this property.
  That makes it a fair test of whether the property is hard and a weak basis for a claim about
  real code. The next step for this finding is a composition defect from a **published
  advisory**, not from a brief.
- **Not a field survey.** Two products. `AI-Infra-Guard` remains out of scope for this task and
  no third arm exists.

## Where the ledger stands after five rounds

| round | recall | decoys | band |
|---|---|---|---|
| eleven products | behind 8.3 | 0.25 / 1.00 | refuted |
| coverage rules | ahead 5.9 | 9.75 / 5.25 | not supported |
| refutation stage | ahead 11.8 | 9.50 / 3.75 | not supported |
| artifact contract | level (−1.5) | 6.00 / 7.75 | refuted |
| **composition** | **level (−0.7)** | 5.00 / 4.75 | **refuted** |

**No.** Five rounds, five failures to meet a band that has never been raised and was lowered
once, on the record. What changed today is not the answer — it is that the question *which of
us is better* now looks like the wrong one to keep asking, and *what neither of us can do* has
a number on it for the first time.

Per the multiplicity commitment, this corpus is retired for the ranking question. It is **not**
retired for the composition question, which it was built to open rather than to close.

## What ships

All eight reports in [`runs/`](runs/) with their `triage` answers and `ruled_out` lists, the
[key](key.json) — carrying `kind` and `requires_files` per defect so the split is checkable
rather than asserted — [`SCORE.txt`](SCORE.txt), and the
[pre-registration](PREREGISTRATION.md) written before its author saw the corpus, including the
discrimination check this round passed and the previous one failed.
