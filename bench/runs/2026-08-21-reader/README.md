# Run 2026-08-21 — does the coverage declaration help a reader? Measured, and it does not help *more*


> **The run prompts for this round were not kept.** A later round measured the same unaided arm on the same target with the same blind instrument and a freshly written prompt, and scored 0.60 where this family of rounds scored 0.81 — twenty-one points from the prompt alone. **The numbers below are internally valid and are not comparable to numbers from another sitting.** See `../2026-08-21-unaided-pass/`, which archives every prompt it used.

By this point recall was at parity on file subsets, precision was at parity, and whole-repository recall against a named advisory was near zero for both methods. One claim was still standing, and it had been asserted all day without ever being measured: that this project's **coverage declaration** — and its ability to say *I could not decide this* — is worth something to whoever reads the report.

This measures it, on the only dimension that is objective: **how much of a repository a reader can account for using the document alone.**

## Method

Each whole-repository report from the previous round was handed to a fresh context as *the only thing it may use* — the coverage statement and the finding titles, no code, no arm label, no idea another report exists. Ten areas of the repository, and for each one exactly one answer:

`reported` · `examined-nothing-reported` · `not-examined` · `cannot-tell`

**Every answer except `cannot-tell` had to carry a verbatim quotation from the report.** That is what makes the score objective rather than a matter of taste: either the sentence is in the document or it is not. Both readers machine-checked their own quotations as exact substrings before returning.

## Result

| | Areas resolved with a quotation | `cannot-tell` |
|---|---|---|
| report written with the corpus | **8 / 10** | 2 |
| report written without it | **9 / 10** | 1 |

**The corpus's report was not easier to act on. On this measure it was marginally harder**, and one area is well inside the noise of every instrument in this directory. The last standing claim does not survive contact with a measurement either.

## The part worth keeping, which is not a score

The reader of the corpus report singled out one sentence, unprompted, as the thing that let it answer at all:

> *"unlike object-level authorization, where the author states plainly `the absence of an IDOR finding here means nobody looked`, there is no such disclosure here."*

That is the contract working exactly as designed — and the same reader was pointing out that the **same report failed to do it for the data-access layer**. `src/lib/db` and the `*-store.ts` files are named in the inventory, knex is named as the routing signal that selected the web-api sections, and then the layer appears in neither the *what I read* list nor the *what I did not* list. The reader's verdict is the one this project would want a customer to reach: *"Silence about SQL injection in this report is not evidence of its absence."*

So the differentiator is real, and the corpus arm executed it in one place and dropped it in another. That is a defect with a name and a fix: **a coverage declaration should be required to resolve every surface it inventories as read or not-read.** Inventorying `db/`, routing to it, and then never mentioning it again is the exact failure the declaration exists to prevent, committed by the document that exists to prevent it.

## What this is not

- **Ten areas, one repository, one pass per report.** A one-area difference is not a ranking, and this bench's own measured resolution is five in fifty-three.
- **Not a test of the findings.** It measures what a report lets a reader *account for*, not whether the findings in it are true — that was measured separately, and nothing was refuted in either arm.
- **The questions are ours.** They were written after reading neither report in full, but they were written here, and a different ten areas could move the number by one either way.

## Files

`report-with-corpus.json` and `report-without-corpus.json` are exactly what each reader received. `answers-*.json` hold the ten verdicts and their quotations.
