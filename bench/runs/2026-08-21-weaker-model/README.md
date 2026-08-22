# Run 2026-08-21 — the corpus made a weaker model worse, and one loading rule fixed most of it


> **Outside information was not settled in this round.** No prompt in this bench said whether consulting sources beyond the target — an advisory database, an upstream branch, a diff against another version — was allowed, and later rounds found that some runs did consult them. **Any recall number here measures review and library familiarity together and cannot separate them.** Consistency comparisons are unaffected: they compare runs of one arm, which had the same latitude. `../../prompts/external-sources.txt` is the clause that closes this for later rounds; it did not exist when this one ran.

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

## The retest, after the fix: 2/6 → 4/6, and the prediction held

`RETEST-PREREGISTRATION.md` was committed before the retest ran. It predicted that a corpus carrying a **loading rule** — *read the target before you read this corpus, and stop loading before the code stops fitting; if a pack would leave you without room to read the code, do not load it, audit what you can read, and declare that no procedure was consulted* — would score strictly better than 2/6 and find D2 in at least one run. Nothing else changed: same target, same model, same run prompts, same blind judge prompt, same mechanism descriptions.

| | D1 | D2 | total |
|---|---|---|---|
| with the corpus, **before** | 2 of 3 runs | **0 of 3** | **2 / 6** |
| with the corpus, **after** | 1 of 3 runs | **3 of 3** | **4 / 6** |
| without it | 2 of 3 runs | 3 of 3 | **5 / 6** |

**D2 went from zero of three to three of three.** The defect the corpus arm could never reach is now the one it never misses. That is the loading rule doing exactly what it was written to do, and it is the first change in this whole sequence that produced its predicted effect.

The unaided arm was **not** re-run. Its 5/6 stands as measured; re-running it to chase a better comparison would be selection.

### What got worse, and it is not a rounding error

**D1 fell from 2 of 3 runs to 1 of 3.** Worse than absent: two retest runs *actively ruled it out*. One wrote that the array allocation bounds "are actually correct"; the other argued the length was bounded because short strings cap at 255 bytes — an argument about a different method than the one the defect lives in.

A reviewer that reads less reaches conclusions faster, and some of them are wrong in a way that silence is not. **Triage that runs on a budget it does not have produces confident refutations**, and the corpus gives a `ruled_out` section for exactly that to be recorded in. This round measured recall; it did not measure how often the weak arm refutes something true, and that is now the sharper question.

### Where it actually leaves the corpus

Fourteen measurements. **The corpus still does not lead.** 4/6 against 5/6 is one defect, inside this bench's own resolution of five in fifty-three, so the honest statement is that the loading rule moved the weak-model result **from measurably harmful to indistinguishable** — not that it made it good.

What it does establish, and this is the first thing in this directory that is both positive and load-bearing: **the tax was the loading, and the loading is fixable.** The content was never the problem, and the fix cost one paragraph plus moving a table out of the router.

## The second retest: the prediction was met, and it proves nothing

`RETEST2-PREREGISTRATION.md` targeted the one thing that got worse: D1 had fallen from 2/3 to 1/3 because two runs *actively refuted* it. The diagnosis was an asymmetry in the contract — `confirmed` costs every triage rule, a dismissal cost one sentence — so a dismissal was made to pay: `refuted` must name `control_at`, the `path:line` of the control on the path to the sink; `merged` must name a finding that exists.

The prediction was **D1 in at least 2 of 3 runs and a total of at least 4/6**.

| | D1 | D2 | total |
|---|---|---|---|
| before the loading rule | 2/3 | 0/3 | 2/6 |
| after the loading rule | 1/3 | 3/3 | 4/6 |
| after making dismissal expensive | **2/3** | 2/3 | **4/6** |
| unaided (not re-run) | 2/3 | 3/3 | 5/6 |

Both conditions are met. **And the result is worthless as evidence, because the intervention never ran.**

**All three artifacts failed validation, and all three failed the same way: not one wrote the `resolution` field.** Every dropped candidate came back in the previous `{label, reason}` shape. The rule was in the schema, in the validator, in `team.md` and at the top of all seven auditor subagents, and the reviewer did not apply it. One run refuted D1 again with *"the bounds check at line 87 is intentional and correct"* — the exact failure the change was written to prevent, produced by a run that never saw the field it was supposed to fill.

So: **the outcome was predicted correctly and supports nothing.** D1 moving 1/3 → 2/3 while D2 moved 3/3 → 2/3, with the total unchanged at 4/6, on three runs of a two-defect ground truth, is what noise looks like. Had the artifact contract not been machine-checked, this would have been published as a second confirmed prediction and a second win. It is neither.

### What this actually teaches, which is worth more than the number

**A rule that only a validator enforces is a rule the reviewer can decline.** The loading rule changed behaviour because it changed what the reviewer *does* before it starts. The dismissal rule tried to change what the reviewer *writes* at the end, and a reviewer that has run short of budget skips the ceremony and writes the shape it remembers. Contract fields govern deliverables; they do not govern reasoning.

**And the rule was too weak even on paper.** Requiring a location is cheap. The run that refuted D1 already cited line 87 in prose; with the new field it would have written `control_at: ValueReader.java:87`, passed the validator, and been exactly as wrong — because line 87 is a cast guard, not a bound. A field that asks *where* cannot tell a control that bounds the quantity that matters from one that does not. That distinction is the whole of the finding, and no schema can carry it.

Both of those are recorded here rather than fixed by adding a third field.

## Files

`PREREGISTRATION.md` is what was committed before anything ran. `groundtruth.json` holds the six blind verdicts joined back to their arms. `runs/` holds all six artifacts. `judging/` holds the batches exactly as the judges received them.
