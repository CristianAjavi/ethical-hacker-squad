# The prompt both arms received

`both-arms.md` is the single prompt template. The two arms differ only in which corpus the
launch instruction points at and in the `mantis` arm's stage-contract paragraph, which asks it
to map its own review constraints onto `FP-nn` labels — bookkeeping its pipeline already does,
as its own provenance shows.

Both carry the same outside-information clause: *report only what you establish by reading this
tree.*

## What this directory does NOT contain

The per-arm **launch call**. Every `mantis` launch in this round carried *run the stages
inline rather than spawning sub-agents*, and no `ours` launch carried anything like it —
so the sentence above, that the arms differ only in which corpus the launch points at, is
**wrong**, and it names the smaller difference while omitting the larger.

A `prompts/` directory that ships the shared template and not the launch call is a
directory that can be complete and still mislead. `gate-bench-integrity.sh` checked that
prompts exist; it could not check that they were all of it.
See [`../../CORRECTION-inline-constraint.md`](../../CORRECTION-inline-constraint.md).
