# The prompts both arms received

`without-join.md` is the composition round's prompt, used by the four stored runs.
`with-join.md` is this round's, used by the four new ones.

**They are byte-identical.** That is the point of keeping them: the only difference between the
arms is the corpus the prompt points at — one where `path_coverage.py` ships and the roles cite
it, one from before it existed. Nothing in the wording changed, and a reader can check that
rather than take it on trust.

## Outside information

Both prompts carry the same clause: *"Report only what you establish by reading this tree."*
Neither arm was given a framework hint the other lacked, and the target's stacks are named
identically in both launch instructions.

This disclosure exists because `gate-bench-integrity.sh` refused the round without it, and it
was right to: **this bench has measured prompt wording at 21 points.** A comparison that does
not keep its prompts cannot tell the arms apart from the sentences.

## What this directory does NOT contain

The per-arm **launch call**. Every `mantis` launch in this round carried *run the stages
inline rather than spawning sub-agents*, and no `ours` launch carried anything like it —
so the sentence above, that the arms differ only in which corpus the launch points at, is
**wrong**, and it names the smaller difference while omitting the larger.

A `prompts/` directory that ships the shared template and not the launch call is a
directory that can be complete and still mislead. `gate-bench-integrity.sh` checked that
prompts exist; it could not check that they were all of it.
See [`../../CORRECTION-inline-constraint.md`](../../CORRECTION-inline-constraint.md).
