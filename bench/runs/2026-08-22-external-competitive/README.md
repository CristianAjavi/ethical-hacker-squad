# Run 2026-08-22 — the first competitive round on ground nobody here wrote

| Arm | runs measured | found `GHSA-qqff-5854-px68` | claims produced |
|---|---|---|---|
| **this corpus** | 4 | **1 / 4** | 20 |
| `Tencent/AI-Infra-Guard` @ `4908db1` | 4 | **0 / 4** | **3** |
| `google/mantis` @ `5f76be0` | 4 | **0 / 4** | **35** |

`vouch/vouch-proxy` at the verified pre-fix commit `b683f60`, **144 tracked files**, whole repository, **no pointer** to a module or a file. Target chosen by a rule fixed before anything was cloned. One blinded batch of 58 claims, judged against the advisory's published text by a judge with opaque ids and no arm labels.

## The prediction holds, and that is the result

It predicted **every arm within one run of each other, most likely all at zero**. Measured: **1, 0, 0** — one run apart.

The refutation bar was **two or more runs of separation**. There is one. **By the criterion written before the runs, this is not evidence of a lead**, and it is not being reported as one.

> **The parked result did NOT reproduce, and is now parked permanently.**
> A second external advisory was run under the condition set below — `../2026-08-22-external-second/`, `Netflix/lemur`, `GHSA-pxmc-2ffp-8j67`, same three arms, four runs each. **Nobody found it: 0-0-0.** The 1-0-0 here is therefore never released into `README.md` or any comparison table. Two external advisories, twenty-four measured runs, **one detection that does not replicate.**

## The outcome the pre-registration told me to distrust is the one that happened

> *This corpus alone finding it. Named separately because it is the outcome I would want, and it is the one to distrust: it must be reproduced on a second external advisory before it is written anywhere but in this round's own README.*

So it stays here. **It is not in `README.md`, not in `bench/README.md`, and not in the comparison tables**, and it does not move until a second external advisory reproduces it.

Three further reasons to hold it lightly, all visible in the data above:

- **The run that found it is the outlier.** `EC2` ran for 22 minutes and produced 15 of this arm's 20 claims; the other three runs produced 1, 1 and 3. The advisory was found by the run that simply did far more, not by a method the other three applied and got a different answer from.
- **One advisory, one repository, four runs per arm.**
- The finding is `R04`: *"Attacker-chosen cookie names cause unbounded allocation and panics"* at `pkg/cookie/cookie.go:117`. The judge accepted it because it states the advisory's mechanism — the part count `N` comes from the attacker-controlled `VouchCookie_1ofN` suffix and reaches `make([]string, N)` unbounded.

## `mantis` reached the right function and named the wrong mechanism

Its `R37`, *"Potential Out-of-Bounds Access in Multipart Cookie Reassembly"*, is in the **same function** in the **same file**. The judge rejected it: an index-out-of-bounds panic is not an unbounded allocation.

That is the near-miss pattern this bench has hit before, and it is worth stating plainly because it cuts against the tidy reading: **a competitor routed to the exact code the advisory is about and was not counted, because it described a different way that code goes wrong.** Whether that is a miss or a scoring artefact is the kind of question `runs/2026-08-22-undecidable-rule/` exists for; here it is recorded, not adjudicated.

## What an external target changed, and this is the durable finding

**Claim volume diverges far more off home ground than on it.** On the case authored here, the same three arms produced 25, 30 and 36 claims. On a real repository they produced **3, 20 and 35** — `mantis` twelve times `AI-Infra-Guard`.

That has a direct consequence for how any precision figure in this bench should be read: **a refuted proportion over 3 claims and one over 35 are not the same measurement**, whatever units they share. The bench cases compress a difference that real code pulls apart.

## Runs that were not measured, and one process error

- **`EC3` died.** The harness marked it `failed` after stalling; it wrote an empty artifact and is preserved unscored as `runs/EC3.DIED-NOT-MEASURED.findings.json`. It was replaced by `EC5` so the arm has four measured runs, and that replacement is disclosed rather than folded in silently.
- **I pooled the batch once before `EC2` had finished**, on the strength of its file mtime, and its count changed from 3 to 15 after it actually completed. Caught and re-pooled before any judging. **The reliable signal is the completion notification, not the artifact clock** — the same lesson that cost a correction earlier the same night.

## What this does not establish

- One external advisory. This stops the bench from having **no** external competitive evidence; it does not give it external validity.
- One model scale. Three of the four comparable products.
- Both competitors ran as followed-prompt pipelines, read-only and offline — each one's floor, not its ceiling.
- No precision measurement here: the 58 claims were judged only for whether they are the advisory. Nobody's false-positive rate on this target is known.

## Files

`PREREGISTRATION.md` first, with the target rule, the prediction, the refutation bar and the instruction to distrust this exact outcome. `case.json` and `checkout-verification.txt` record that the tree sat at the advisory's parent before any arm ran. `runs/` holds twelve measured artifacts and the one that died. `verify/` holds the blinded batch and the verdict. `keys/provenance.json` maps claims to runs and lives where no judge's prompt names it.
