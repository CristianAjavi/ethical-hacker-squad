# The prompts, archived because a round without them cannot be compared to anything

This round measured its own control arm at **0.60** where the previous round measured the same arm, on the same target, with the same blind instrument, at **0.81**. The only difference was the run prompt, which the previous round did not keep.

Twenty-one points is larger than any corpus-versus-no-corpus difference this bench has produced. So the prompt is not context for a run — it is part of the measurement, and a published number without it is not reproducible and not comparable.

Every file here is what an arm actually received, verbatim. `corpus-arm.txt` and `no-corpus-arm.txt` differ only in what the reviewer is allowed to reference; the deliverable path and the "write early, re-write often" instruction are identical.

`corpus-arm-no-delegation.txt` is the variant `treatment-7` received. It carries one extra sentence forbidding delegation to subagents, added after `treatment-6` was killed with its delegated child silent for seventeen minutes. Runs 4 and 5 never delegated, so the sentence forbids something neither did — but it is a difference between runs of one arm and it is archived as its own file rather than folded into the other one.

`judge.txt` is what all six blind judges received, identical for every batch.

## Outside information: unstated in this round

Neither run prompt here says whether consulting sources outside the target is allowed, and at least one run in this family did consult them — one unaided run diffed the target against upstream `main`, one corpus run cited CVE identifiers. **Recall numbers from this round therefore measure review and library familiarity together, and cannot separate them.** Consistency is unaffected: it compares runs of one arm, and both of them had the same latitude. `../../prompts/external-sources.txt` is the clause that closes this for later rounds; it did not exist when this one ran.

## What this directory does NOT contain

The per-arm **launch call**. Every `mantis` launch in this round carried *run the stages
inline rather than spawning sub-agents*, and no `ours` launch carried anything like it —
so the sentence above, that the arms differ only in which corpus the launch points at, is
**wrong**, and it names the smaller difference while omitting the larger.

A `prompts/` directory that ships the shared template and not the launch call is a
directory that can be complete and still mislead. `gate-bench-integrity.sh` checked that
prompts exist; it could not check that they were all of it.
See [`../../CORRECTION-inline-constraint.md`](../../CORRECTION-inline-constraint.md).
