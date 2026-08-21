# Run 2026-08-21 — the corpus makes a weaker model **worse**

`PREREGISTRATION.md` was committed before anything ran. It predicted that on a weaker model the corpus arm would find strictly more of the two ground-truth defects than the unaided arm, and named what would refute it.

**The prediction is not merely refuted. It is reversed.**

| Arm, on Haiku 4.5 | D1 found | D2 found | Total |
|---|---|---|---|
| **with the corpus** | 2 of 3 runs | **0 of 3 runs** | **2 / 6** |
| **without it** | 2 of 3 runs | **3 of 3 runs** | **5 / 6** |

D1 is a buffer sized by an untrusted length and allocated before the payload is shown to exist. D2 is mutual recursion between decoders with nothing counting the depth. They are ground truth because **every frontier run, in both arms, across every previous round, found both of them every time.**

Scored by six independent blind judges, one per run. Each saw a single findings list with opaque ids, no arm label, no model label and no run label, plus mechanism descriptions written without any phrase either arm used, and had to quote verbatim from whatever finding it named.

## The mechanism is not a mystery, and it is measurable

The corpus arm did not fail because it looked and missed. It failed because it ran out of room to look.

| | tokens spent | tool calls | findings produced |
|---|---|---|---|
| corpus runs | 95k · 111k · 88k | 20 · 24 · 29 | 2 · 2 · 2 |
| unaided runs | 66k · 48k · 64k | 17 · 6 · 7 | 8 · 10 · 10 |

**The corpus arm spent roughly twice the budget to produce a fifth of the output.** On a weaker model, reading a 4,186-line procedural corpus and satisfying an artifact contract consumes the capacity that the unaided arm spends on the code. One corpus run reported deprecated `String` constructors and an end-of-life build dependency and stopped — inside the same file where a four-byte wire length sizes a two-gigabyte allocation.

**This is a context tax, not a transfer of expertise.** It is the opposite of what a skill is for.

## The contract fails too, and in the way that matters

Two of the three corpus runs produced artifacts that **do not validate**, and both failed on the same invariant: `engagement.coverage` inventoried the very files the run had just read and then resolved them as neither `read` nor `not_read`.

That invariant exists because a blinded reader test caught one of our own frontier reports doing it and concluded that *silence about SQL injection in this report is not evidence of its absence*. The weaker model produces exactly that silence, about the two files that were the entire engagement. The contract that makes the deliverable trustworthy is itself only affordable above some capability threshold.

## The counterweight, because it is real

One judge noted, unprompted, that the unaided lists carry filler: a hard-coded charset literal, a "reinvents the wheel" style note, a logging gap — observations with no attacker. The unaided arm on a weak model reports more of everything, including noise, and this round did not measure its precision. **5/6 against 2/6 says the defects are in the list, not that the list is good.** A separate precision pass on this arm would be the honest follow-up, and it has not been run.

## What this forces

Thirteen measurements. The corpus leads on none, is indistinguishable from unaided review at frontier scale, and is now measured as **actively harmful below it**. The remaining hypothesis for its value — that it transfers expertise downward — is the one this round was built to test, and it is dead in the direction it was pointed.

Three things follow, and none of them is "write another procedure":

1. **Loading is the defect, not the content.** The corpus is loaded far too eagerly for the capacity available. Progressive disclosure exists in `SKILL.md` and is evidently not aggressive enough to survive a smaller context.
2. **The artifact contract has a price and nobody had measured it.** It buys auditability that the blinded reader test showed is real, and it costs budget that a weaker model does not have. Both halves are now measured; only one of them was ever claimed.
3. **The honest product claim has to narrow.** Not "finds more". What is measured is an artifact with somewhere to say *I could not decide this*, and a coverage declaration that resolves every surface it inventories — on a model strong enough to afford them.

## Files

`PREREGISTRATION.md` is what was committed before anything ran. `groundtruth.json` holds the six blind verdicts joined back to their arms. `runs/` holds all six artifacts. `judging/` holds the batches exactly as the judges received them.
