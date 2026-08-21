# Run 2026-08-21 — consistency, measured properly at the third attempt: the corpus is **less** consistent

> **This run published two numbers before this one and both were retracted.** A regex classifier reported 1.00 agreement with the corpus against 0.60 without it; a rewrite of the same classifier reversed it to 0.63 against 0.69; a hand-check showed both were mis-binning findings that a reader bins correctly at a glance. The classifier is kept below as evidence of that defect. **What follows is the third attempt, using the instrument this bench already knows works** — blind judging — and its answer is the opposite of the first one.

## Method, the version that works

Ten measurements of **capability** had come back at parity or worse. Consistency is the property a written procedure should confer by construction: a checklist does not make a surgeon cleverer, it makes the outcome less variable. Six runs, three per arm, one target, each in a fresh context that knew nothing of the others.

Comparing runs needs findings reduced to **the defect they are about** — and that reduction, done by pattern matching over prose, is what failed twice. So it was replaced with the protocol that already decides advisory matches here: **a blind judge is given two lists of findings with opaque ids, no arm label, no run label, and decides which pairs are the same defect, with a reason recorded for every call.** Six judges, one per pair of runs, 335 candidate pairs.

The instruction that carries the whole measurement: *two findings in the same method are not the same defect if what makes them exploitable differs*. An unbounded allocation and an uncapped recursion in one file are two defects. So are a missing bound and an exception of the wrong type on the same line.

## Result

| Arm | Run sizes | Pairwise agreement | Mean |
|---|---|---|---|
| with the corpus | 4, 5, 6 | 0.80 · 0.67 · 0.57 | **0.68** |
| without it | 9, 10, 9 | 0.73 · 0.80 · 0.90 | **0.81** |

**The unaided arm is the more consistent one.** Not by a hair inside the noise — by 13 points, in the direction opposite to the hypothesis and opposite to the number this file first published.

The corpus arm's three runs agreed on the same four defects and then each added a *different* fifth or sixth: one added the wrong-exception-type, one added the declared-length mismatch and the duplicate keys. Its variability is in what it reaches beyond its core. The unaided arm's eight findings paired one-to-one across runs on identical line anchors and identical mechanisms; what varies there is the tail, not the body.

## Why the judges are believable where the classifier was not

Every judge left its reasoning, and the calls are ones a person can check:

- Both sides repeatedly declined to merge the allocation finding with the wrong-exception finding, **even when one write-up literally quoted the other's mechanism in its evidence** — because the title, location and evidence were all the allocation, and the exception appeared only as context. That is the exact pair the first classifier folded together to manufacture 1.00.
- One judge merged two write-ups that led with opposite-sounding mechanisms — over-declared length swallowing following bytes, versus `available()` dropping trailing entries — after showing that each write-up names the other's half and both reduce to one construct: a declared length never reconciled against bytes consumed. A regex could not have reached that, in either direction.
- One judge kept an uncapped *element count* apart from an uncapped *recursion depth* in the same methods, on the grounds that a well-formed, correctly-lengthed table triggers the first and not the second.

## What this means

Eleven measurements now: recall on file subsets, recall on whole repositories, precision, reader utility, and consistency. **The corpus leads on none of them**, and on this one it is behind. The property it exists to provide, measured with the right instrument, is provided better by an unaided competent engineer on this target.

Two things this does not establish. It is **one target and three runs per arm** — a wider sample could move 13 points. And agreement is not quality: the unaided arm is more consistent *and* broader, but nothing here says its extra findings are worth acting on, only that a separate run showed they are true.

## The pattern, three times in one day

A published separation withdrawn when a case judged in two batches gave two verdicts. A published consistency win withdrawn when its classifier was hand-checked. And now the same question, answered by the instrument that was available the whole time and simply was not used first. **The failure was never the corpus — it was reaching for a cheap instrument and publishing before testing it.** That rule is now written where it will be read, and this file is the evidence for why.

## Files

`runs/` holds the six artifacts. `agreement-blind.json` holds the per-pair numbers from the blind judging. `classify.py` and `consistency.txt` are kept **as evidence of the retracted method**, not as tools.
