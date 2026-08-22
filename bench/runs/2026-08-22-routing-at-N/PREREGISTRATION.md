# Pre-registration — routing on whole repositories, with enough N to mean something

**Written before any arm ran, and the targets were picked by a published rule before the prediction below.**

## The thinnest measurement in this bench, holding up its strongest conclusion

Twenty measurements support the sentence *this corpus leads on no capability dimension*. Almost all of them are on **one target of two files carrying two known defects**. The exception is the dimension the corpus is actually built for — deciding **what to read** in a repository nobody can read whole — and that dimension has **three advisories of evidence in total**, scored 0/2 and 0/1 against an unaided 1/2 and 0/1.

A one-advisory difference is inside this bench's own stated resolution of five in fifty-three. **The claim "leads on nothing" currently rests, on its most load-bearing dimension, on a sample too small to have detected a lead if one existed.** That is a defect in the evidence, not a result, and this round exists to fix it rather than to win.

## The targets, picked by rule before the prediction

`scripts/bench/pick-external-cases.py --ecosystem go --severity high --count 3`: the most recent reviewed high advisories for Go, in API order, keeping those with a fix commit. Population 30, kept 3, **rejected 0**. Written to `cases-picked.json` before this file was finished.

Two of the three land on the same repository, `getkin/kin-openapi`, and the third on `runatlantis/atlantis`. **That is declared, not fixed by re-picking** — choosing a different sample after seeing which repositories came up is exactly what the rule exists to prevent.

## Method, fixed in advance

- **Whole repository, no pointer.** No arm is told a module, a file, or that anything is wrong.
- Two arms: the corpus as it ships, and the same model with no corpus, an output schema and one instruction. Same model for both.
- Both prompts carry `bench/prompts/external-sources.txt` **identically** — the first whole-repository round in this bench where they do.
- Scoring is blind: a judge sees the advisory text and the finding text with opaque ids, no arm label, and decides whether the finding is that advisory.
- A run whose agent dies is **not measured**, never scored zero, and its partial output is preserved.

## The prediction

**Prediction: both arms score at or below 1 of 3, and the difference between them is one advisory or less.**

That is a prediction that the dimension is **hard for everyone**, consistent with the two rounds already run, and it is the honest expectation rather than a hopeful one.

**What refutes it:** either arm scoring 2 or 3 of 3, or a gap of two or more advisories.

## What each outcome forces

- **Prediction holds** — then whole-repository recall is near zero for both, on six advisories rather than three, and the honest published statement changes from *the corpus does not lead* to **the task is not solved by anyone, and no product in this field should claim otherwise without a number.** That is a stronger and more useful claim than the current one, and it still is not a lead.
- **The corpus scores higher by two or more** — then it leads on the dimension it was designed for, and eighteen measurements on one small target were the wrong evidence base for the conclusion this repository has been publishing all day. That would require rewriting the README's headline, and it is written here so that outcome cannot be quietly enjoyed without the rewrite.
- **The unaided arm scores higher by two or more** — then the corpus is worse where it claims to be best, and that goes in the README with the same prominence.

## Caveats fixed in advance

- Three advisories over two repositories; two of them share a repository, so the effective independence is closer to two.
- One model. Whole-repository runs in this bench have died mid-flight more often than any other kind, and each death costs an advisory.
- Finding a defect a CVE happens to name in a repository of thousands of files is close to a lottery for any method; that is the finding of the previous rounds and this one is powered to confirm or break it, not to flatter either arm.
