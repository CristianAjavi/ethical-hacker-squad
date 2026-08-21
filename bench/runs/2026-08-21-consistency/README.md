# Run 2026-08-21 — consistency, and the first separation that survives its own caveats

Nine measurements had come back at parity or worse: recall on file subsets, recall on whole repositories, precision, and how much of a repository a reader can account for from the report. Every one of them measures **capability**, and capability on this task is saturated — a competent model finds these defects with a corpus or without one.

One property had never been measured, and it is the one a written procedure should confer by construction. A checklist does not make a surgeon cleverer; it makes the outcome less variable. **Do two independent runs of the same review produce the same result?**

## Method

One target, six runs, three per arm, every one in a fresh context that knew nothing of the others. Same target as round 3's `valuereader` case, chosen because both arms had already found its advisory there — so the question is not *can they* but *do they agree with themselves*.

Findings were reduced to the **defect they are about** before comparison. Two runs word the same defect differently, so matching on prose would measure style; matching on file and line would split one defect reported at two lines. The classifier is `classify.py`, in this directory, in full: ordered patterns, first match wins, and **a finding that matches nothing keeps its own location as a class of its own** — a fallback that can only lower measured agreement, never raise it.

## Result

| Arm | Run sizes | Pairwise agreement | In every run | Union across runs |
|---|---|---|---|---|
| **with the corpus** | 4, 5, 6 findings | **1.00, 1.00, 1.00** | 4 classes | 4 |
| **without it** | 9, 10, 9 findings | 0.71, 0.43, 0.67 — mean **0.60** | 3 classes | 7 |

**Three independent runs with the corpus produced the identical set of defect classes. Three without it agreed on 60% of theirs.**

This is the first difference measured today that is not one item inside the noise. It is a 40-point gap on the property the corpus exists to provide, and it is the property nobody in this field publishes.

## The caveats, and one of them is serious

**Fewer findings makes agreement easier, and that confound is real.** The corpus arm reported 4–6 findings per run against 9–10; agreement over a smaller set is a lower bar. Two things bound the objection rather than dismiss it: the corpus arm's *core* — classes present in all three runs — is **larger** (4 against 3), and its variable part is **zero**. The unaided arm did not simply report more; it reported a different extra each time.

**The unaided arm's union is bigger: 7 classes against 4.** Across three runs it surfaced more distinct defects — duplicate-key smuggling, an unchecked exception escaping the decoder, end-of-life dependency lines — that the corpus arm never reported in any run. If you can afford three passes and someone to merge them, that breadth is worth something the consistency number does not capture. **Consistency is not superiority; it is a different property, and this table measures only the one.**

**Everything else that limits it.** One target, one model, three runs per arm, and a classifier this project wrote — disagree with it in `classify.py` and re-run. A different reduction could move the control's mean by a few points; it would have to be a strange one to close a 40-point gap, and anyone who thinks it can has the file and the artifacts.

## What it is fair to say now

Not that this is the best thing available — nine measurements say otherwise, and they are all published in this directory. What is fair is narrower and, for the first time today, favours the corpus:

> On the same target, a written procedure made the result **reproducible** where unaided judgement did not. It found no more than the unaided engineer — it found somewhat less — but it found the same thing every time.

Whether that is what a buyer wants is their decision, not a measurement. An audit you cannot reproduce is an anecdote; an audit that reliably covers a narrower band is a different product from one that covers a wider band unreliably. This bench can now say which is which, which is more than it could say this morning.

## Files

`runs/` holds all six artifacts as delivered. `classify.py` is the reduction, and `consistency.txt` is its output.
