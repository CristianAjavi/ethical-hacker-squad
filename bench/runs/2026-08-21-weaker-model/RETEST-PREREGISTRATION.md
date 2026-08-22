# Pre-registration — the retest, after the fix

**Written before the retest was launched, and after the first result was published.** The first round is not amended; this is a second measurement of a changed corpus against the same ground truth.

## What was changed, and why exactly this

The first round measured the corpus arm at 2/6 against 5/6 unaided on Haiku 4.5, while spending roughly twice the budget for a fifth of the output. The mechanism it exposed was not that the procedures are wrong — it is that **nothing in the corpus told a reviewer what to do when it cannot afford the corpus**. It loaded the packs, ran out of room, and reported deprecated `String` constructors inside the file where four wire bytes size a two-gigabyte allocation.

So the change is a loading rule, not a procedure:

- **`SKILL.md`** now carries, at the top of the loading section where the decision is actually made: *read the target before you read this corpus, and stop loading before the code stops fitting. If loading a pack would leave you without room to read the code, do not load it — audit what you can read, and say in the coverage declaration that no procedure was consulted.*
- **The seven auditor subagents** carry the same rule above their pack-loading step.
- To pay for it inside a router that was 4 bytes under its ceiling, the nine-row subagent table and the non-plugin fallback moved to `references/team.md`, which is where the role orders they describe already live. `SKILL.md` went from 12,284 B to 11,271 B.

## The prediction

Same target, same ground truth (**D1** a buffer sized by an untrusted length and allocated before the payload exists; **D2** mutual recursion with nothing counting depth), same blind judging, same model, same prompts — three fresh corpus-arm runs against the changed corpus.

**Prediction:** the corpus arm scores strictly better than 2/6, and finds D2 in at least one run. It found D2 in **zero** of three before.

**What refutes it:** 2/6 or worse, or D2 still absent from all three runs.

**What a refutation would mean.** That the loading rule is not the lever, and the tax is the corpus's mere existence in the context rather than how much of it gets read. At that point the honest conclusion is that this corpus has no use below frontier scale and the documentation must say so in those words, rather than being tuned again.

## Fixed in advance

- The unaided arm is **not** re-run. Its 5/6 stands as measured; nothing about it changed, and re-running it to chase a better comparison would be selection.
- Three runs, one target, one model. The ground truth is two defects, so this is a coarse instrument by construction and only a clear move is reportable.
- The prompts are unchanged and already archived in `prompts/`.
