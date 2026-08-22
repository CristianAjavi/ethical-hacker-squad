# Run 2026-08-21 — the critic stage bought the best precision in this directory by deleting true findings

`PREREGISTRATION.md` was committed before any run. It predicted the refuted proportion would fall **and** ground-truth recall would hold at 4/6, and it named the failure mode by name: *a drop in refuted claims that arrives with a drop in ground-truth recall is suppression, not precision, and will be reported as such.*

**That is what happened.**

| Arm | claims | refuted by both passes | ground-truth recall |
|---|---|---|---|
| **with the critic stage** | **6** | **2 (33%)** | **3 / 6** |
| with the corpus, no stage | 26 | 16 (62%) | 4 / 6 |
| competitor `google/mantis` | 17 | 9 (53%) | — |
| unaided, no method | 28 | 19 (68%) | 4 / 6 |

**Read the first column and the last one together, because either alone lies.**

On precision it is the best number in this directory — 33% refuted, twenty points better than the competing product that beat us a round ago. Reported alone, it would read as this corpus overtaking the field on the one dimension where it was behind.

It is not that. **Recall fell from 4/6 to 3/6, and every one of the three runs scored exactly 1/2.** The stage killed one true defect in each. One run refuted the uncapped recursion *"with evidence"* — a defect every frontier run of every arm has found every time. The claim count fell from 8 to 6. Precision improved because the arm stopped saying things, and some of what it stopped saying was true.

**Had this round measured precision alone, it would have shipped today as a win.** It was pre-registered not to.

## What actually goes wrong, and it is the same failure twice

`VER-09` institutionalised a step this corpus had already measured going wrong. Two rounds earlier, a weak reviewer short of budget was found producing **confident refutations** of a real defect — asserting the allocation bounds were correct, citing the length cap of a different method. The diagnosis then was that dismissing was cheap and confirming was expensive.

Giving that reviewer a dedicated stage whose stated job is to kill claims did not fix the asymmetry. It **industrialised** it. A reviewer that has run short of room treats *"I found an argument"* as *"I killed it"*, and a stage that asks for arguments gets them.

The competitor's advantage is therefore **not** "has a critic stage". It is having one calibrated so that failing to kill something is the default outcome. Copying the box without the calibration reproduces the box and not the result.

## What the verifiers found in our own claims, unprompted

Both passes killed the same two, and they are ours:

- Two claims assert that a declared length sizes an allocation in `readTable`/`readArray`. It does not — those lines create an empty `HashMap`/`ArrayList` and a `TruncatedInputStream` that uses the length as a *remaining-bytes counter*. One claim's own evidence concedes it ("will eventually stop after reading that many bytes"), contradicting its title.
- Two of the six claims are **the same finding stated twice**. Our deduplication is no cleaner than the competitor's, which the previous round criticised.

So the arm both over-generalised the one real mechanism onto two places it does not apply, and repeated itself. Neither is what the critic stage was aimed at, and the critic stage removed neither.

## What was done about it

**The automatic invocation is reverted.** A change that fails its own pre-registered measurement does not stay in the shipping path, and this one costs a true defect per run at weak scale.

`VER-09` stays written, with this measurement inside the procedure itself so the cost is the first thing a reader meets, and it is invoked deliberately rather than by default. That is not dead configuration: it is a documented tool with a measured price, for the case where a reader's triage cost genuinely outweighs recall — and this bench has never measured a case where it does.

The next hypothesis, unmeasured and stated as such: **a kill must cost what a claim costs** — the critic must name the line where the bound is enforced on the path to the sink, and failing to find it must leave the finding standing. That was tried once as an artifact field and the reviewer simply declined to write it. Making it the *direction of the default* rather than a field to fill is the untested variant.

## Caveats

- **Six claims cannot carry a proportion.** 33% against 17, 26 and 28 claims is not a like-for-like comparison, and the count is the result rather than the denominator. Recall, at 3/6 against 4/6 on identical slots, **is** comparable.
- One target, one weak model, three runs.
- Inter-pass agreement was 6/6, on six claims, which is not evidence of anything.
- All three artifacts failed validation, one of them by crashing the validator itself — a defect in our validator, since fixed, that turned a shape violation into an unhandled `TypeError`. A crash is a gate that could not measure, not a verdict.

## Files

`PREREGISTRATION.md` names the suppression failure mode before any result existed. `groundtruth.json` holds the per-run recall. `verdicts-deblinded.json` holds both adversarial passes. `runs/` holds the three artifacts, including the invalid ones.
