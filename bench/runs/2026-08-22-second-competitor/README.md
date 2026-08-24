# Run 2026-08-22 — a second competitor, and this project is not ahead of the field

| Arm | claims | refuted by **both** passes | ground-truth recall | union |
|---|---|---|---|---|
| **this corpus** | 36 | **0 (0%)** | 4.67 / 7 | **7 / 7** |
| **`Tencent/AI-Infra-Guard`** @ `4908db1` | **31** | **1 (3%)** | 4.50 / 7 | 6 / 7 |
| `google/mantis` @ `5f76be0` | 47 | 9 (19%) | 4.50 / 7 | 6 / 7 |

Six runs per arm, `claude-haiku-4-5`, target `bench/cases/rag-agent`, **all 114 claims from all three arms re-pooled into one blinded batch and re-judged from scratch** — no arm's number is carried over. Inter-pass agreement 110/114 (96%).

## First, the thing that had to be checked before any comparison

**The corpus arm's 0% reproduced under a different verifier pair, on the same artifacts: 0 of 36 again.** The pre-registration said a number that moves with the instrument is a property of the judges, not of the arm, and that this would be reported ahead of any comparison. It did not move.

## The prediction bet against this project, and it half-landed

It predicted `AI-Infra-Guard` would land **at or below `mantis`** and **at or below this corpus**.

- **At or below `mantis`: holds, decisively.** 3% against 19%. The specialist is far cleaner than the general pipeline that beat this corpus the first time precision was ever measured.
- **At or below this corpus: refuted on the number** — 3% against 0%. But the refutation criterion for the round required this corpus to be **10 or more points ahead**, and the gap is **3.2 points, which is one claim out of 31.**

**So neither side of it is a result. This corpus and `AI-Infra-Guard` are indistinguishable on precision on this target**, and both are clearly ahead of `mantis`.

## What that forces, in the pre-registration's own words

> *The README stops saying `the strongest published competitor` and names the arm that is ahead… The precision claim narrows to what it actually is: ahead of `mantis`, not ahead of the field.*

**Done.** The claim in `README.md` is now *ahead of `google/mantis`, level with `Tencent/AI-Infra-Guard`* — and `AI-Infra-Guard` is the one product in this field that publishes its own detection quality, so being level with it is the strongest honest thing this project can say. **It is not the best that exists. It is level with the best that was measurable here, on one target, at one model scale.**

## The methodological result, which outlives the table

The recall judge was re-run from scratch on the **same twelve corpus and `mantis` artifacts** that `../2026-08-22-recall-resolution/` scored. Only the judge changed:

| arm | judge 1 | judge 2 | shift |
|---|---|---|---|
| this corpus | 4.50 / 7 | 4.67 / 7 | **+0.17** |
| `google/mantis` | 4.83 / 7 | 4.50 / 7 | **−0.33** |

**The sign of the difference flipped.** Judge 1 put this corpus 0.33 behind; judge 2 puts it 0.17 ahead. Identical artifacts.

That is the same 0.33 that withdrew the capability claim earlier tonight, and it means **a recall comparison at this N does not order the arms — it only says whether they sit inside the same band.** The 0.5 band was not caution, it was the instrument's resolution, and it was set before either number existed. Every recall figure in this directory should be read as *inside the band* and never as a ranking.

## The profile difference worth more than the ranking

`AI-Infra-Guard` produced **the fewest claims of any arm** — 31 against 36 and 47 — at the same recall and near-identical precision. It is the most economical of the three: fewer claims, same defects found, almost nothing refutable. That is a real characteristic of a purpose-built specialist and this bench should say so rather than bury it in a tie.

## What this does not establish

- **One target, one model scale.** This round bought a second competitor and nothing else, exactly as declared.
- 114 claims about roughly seven defects. Duplication is heavy in every arm, and both verifiers said so.
- `AI-Infra-Guard`'s `skill-scan` was run as a followed-prompt pipeline, read-only and offline, rather than through its own CLI — its floor, not its ceiling, the same handicap `mantis` carries.
- Three of the six field products have still never been run as arms.
- Both verifiers again reported that **the bench case's own hardened twin is not safe** (`answer.py:21` interpolates the ticket body unescaped), independently of the round that first found it. It is recorded in `bench/ground-truth.json`.

## Files

`PREREGISTRATION.md` first, with the prediction that bet against this project and all four outcomes. `runs/` holds the new arm's six artifacts; the corpus and `mantis` artifacts live in `../2026-08-22-recall-resolution/runs/` unchanged. `verify/` holds the pooled blinded batch of all three arms and both fresh passes, `recall/` the fresh blind matching, `keys/` provenance and answer key in a directory no verifier's prompt names, `prompts/` the nine prompts with a note on what was and was not re-run.
