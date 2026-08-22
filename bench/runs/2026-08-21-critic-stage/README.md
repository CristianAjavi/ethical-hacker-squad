# Run 2026-08-21 — the critic stage: v1 deleted true findings, v2 blind to prose fixed it

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

> **That last sentence was written from the score, not from their text, and it is wrong.** Reading their stage afterwards showed it is *harsher* than v1, not gentler. The real mechanism is below, in the v2 section. This paragraph is left standing because being wrong in public is the point of writing the reasoning down.

## What the verifiers found in our own claims, unprompted

Both passes killed the same two, and they are ours:

- Two claims assert that a declared length sizes an allocation in `readTable`/`readArray`. It does not — those lines create an empty `HashMap`/`ArrayList` and a `TruncatedInputStream` that uses the length as a *remaining-bytes counter*. One claim's own evidence concedes it ("will eventually stop after reading that many bytes"), contradicting its title.
- Two of the six claims are **the same finding stated twice**. Our deduplication is no cleaner than the competitor's, which the previous round criticised.

So the arm both over-generalised the one real mechanism onto two places it does not apply, and repeated itself. Neither is what the critic stage was aimed at, and the critic stage removed neither.

## What was done about it

**The automatic invocation was reverted.** A change that fails its own pre-registered measurement does not stay in the shipping path, and this one cost a true defect per run at weak scale. *(It is wired again now — but only as v2, and only after v2 passed. See below.)*

`VER-09` v1 was then removed from the shipped corpus altogether: a procedure the corpus does not want a reviewer to run is not doctrine, it is a bench result.

The hypothesis written here at the time — *a kill must cost what a claim costs*, the critic naming the line where the bound is enforced — **was not the one that worked.** It had already been tried as an artifact field and the reviewer declined to write it. What worked was changing what the critic is allowed to *see*.

## v2 — the critic, blind to the finder's prose

`RETEST-PREREGISTRATION.md` was committed before these runs and after **reading** the competitor's stage instead of inferring it from its score. That reading disproved the diagnosis written above: `google/mantis`'s review stage is **harsher** than v1, not gentler — it instructs the reviewer to assume every finding is a false positive and disprove it. What it does that v1 did not is in the same paragraph: it judges **the claim and the code only, explicitly discarding the finder's prose reasoning as potentially hallucinated.**

v1 handed the critic the whole finding, narrative included. A reviewer short of budget, given a confident rationale, either believes it or finds a flaw in the *prose* and reports the finding dead. Neither is an assessment of the code. v2 gives it the assertion and its location and nothing else.

| | claims | refuted by both passes | ground-truth recall |
|---|---|---|---|
| no critic stage | 26 | 62% | 4 / 6 |
| **v1** — critic sees the whole finding | 6 | 33% | **3 / 6** |
| **v2** — critic blind to the prose | 6 | **0%** | **6 / 6** |
| competitor `google/mantis` | 17 | 53% | — |
| unaided, no method | 28 | 68% | 4 / 6 |

**Both halves of the prediction hold: recall at or above 4/6, refuted proportion below 62%.** It is the first change in this sequence to pass its pre-registered test on both metrics, and the only reason it could be published is that the test demanded both — v1 posted better precision than the competitor and was suppression.

**v1 against v2 is the clean comparison**: same target, same model, same run prompt, same instruments, same six claims. The only variable is whether the critic sees the prose. 3/6 → 6/6 and 33% → 0%.

### What this does not establish

- **Six claims cannot carry a proportion** against 17, 26 or 28. What is comparable is recall on identical slots, and v1-versus-v2 at equal N.
- The arm now reports **exactly the two ground-truth defects and nothing else**. On a target with only two known defects, this bench cannot tell a perfectly-calibrated critic from one that would also kill a true third finding. That needs a target with more ground truth, and it has not been run.
- Both verifiers, while refuting nothing, recorded **real errors inside the surviving claims**: one cites lines 147 and 241 as allocation sites when neither allocates anything proportional to the declared length, one says "client or server" for a client-side class, one overstates a thread-level crash as an application crash. Claims that survive attack can still be sloppy, and precision does not measure that.
- One target, one weak model, three runs.

### What shipped

`VER-09` is in the corpus, wired as step 8 of the leader workflow, **after** it passed — not before. v1 shipped first and had to be reverted; that order is not repeated. The idea of where a critic should be blind came from reading `google/mantis` at its pinned commit; no text of theirs is in this repository.

## Head to head at comparable N — and the 6/6 was a small-N artefact

`HEADTOHEAD-PREREGISTRATION.md` refused to compare 6 claims against 17 and said the fix was more runs, not an argument. Six more v2 runs bring the pool to **19 claims from nine runs**, against the competitor's 17 from three.

| | runs | claims | refuted by both passes | ground-truth recall | inter-pass agreement |
|---|---|---|---|---|---|
| **v2, critic blind to prose** | 9 | 19 | **4 (21%)** | **14 / 18 (78%)** | 19/19 |
| competitor `google/mantis` | 3 | 17 | 9 (53%) | — | 16/17 |

All three pre-registered criteria hold: pooled N ≥ 15, refuted below 53%, recall at or above 4 of every 6 slots.

**And the first thing to say is that this round corrects the previous one.** v2's headline was **6/6 recall over three runs**. Over nine it is **14/18**. The 6/6 was not false, it was small — one run refuted the allocation outright, claiming the code "bounds byte array allocation to `Integer.MAX_VALUE`", which is the cast guard mistaken for a limit again. The pooled figure supersedes the headline, and the only reason the correction happened is that raising N was pre-registered **before** the 6/6 existed.

### Three asymmetries, declared before the number was known

1. **Nineteen claims from nine runs against seventeen from three.** The claim counts were matched, as pre-registered; the run counts were not. Pooling nine short runs is not the same act as pooling three long ones.
2. **Our nineteen claims are three distinct assertions.** Seven restatements of the allocation, seven of the recursion, four of the timestamp. The competitor's seventeen cover about nine. **Our deduplication is markedly worse than theirs** — and the previous round criticised theirs. This inflates our denominator, so the comparison as computed flatters us.
3. **The critic and the grader are the same kind of instrument** — adversarial refutation against code — for both arms. The number measures how well a product filters its own bad claims, not truth.

**On the second point, the direction is worth checking rather than assuming.** Deduplicated, ours is 3 assertions with 1 refuted (33%); theirs is about 9 with roughly 7 refuted (~78%). The gap widens rather than closes. That view is **not pre-registered** and is offered as an observation, not a result.

### What this licenses, and it is bounded by the pre-registration

**On precision, at weak scale, at comparable claim count, against the strongest published competitor in this field, this corpus is ahead.** One dimension, one scale, one target, one competitor.

It does not touch the eighteen capability measurements where this corpus leads on nothing. It does not make it better at finding defects — recall here is 78%, and the competitor was never measured for recall at this N. And the whole result rests on a critic stage that was measured harmful two rounds ago and only works because of where it is made blind.

## Caveats on v1

- **Six claims cannot carry a proportion.** 33% against 17, 26 and 28 claims is not a like-for-like comparison, and the count is the result rather than the denominator. Recall, at 3/6 against 4/6 on identical slots, **is** comparable.
- One target, one weak model, three runs.
- Inter-pass agreement was 6/6, on six claims, which is not evidence of anything.
- All three artifacts failed validation, one of them by crashing the validator itself — a defect in our validator, since fixed, that turned a shape violation into an unhandled `TypeError`. A crash is a gate that could not measure, not a verdict.

## Files

`PREREGISTRATION.md` names the suppression failure mode before any result existed. `groundtruth.json` holds the per-run recall. `verdicts-deblinded.json` holds both adversarial passes. `runs/` holds the three artifacts, including the invalid ones.
