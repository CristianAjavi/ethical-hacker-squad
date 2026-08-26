These are the prompts of the pilot round, reused here byte for byte apart from the
output slot: `repl/c1` becomes `repl/c4`..`repl/c9`, `repl/m1` becomes `repl/m4`..`repl/m9`,
and `verify` becomes `verify2`. That was verified by diff with the slot normalised away
before any run was launched, and it is the reason this round is comparable to the pilot at all.

Both arms carry the same outside-information clause, in every file here.

## What this directory does NOT contain

The per-arm **launch call**. Every `mantis` launch in this round carried *run the stages
inline rather than spawning sub-agents*, and no `ours` launch carried anything like it —
so the sentence above, that the arms differ only in which corpus the launch points at, is
**wrong**, and it names the smaller difference while omitting the larger.

A `prompts/` directory that ships the shared template and not the launch call is a
directory that can be complete and still mislead. `gate-bench-integrity.sh` checked that
prompts exist; it could not check that they were all of it.
See [`../../CORRECTION-inline-constraint.md`](../../CORRECTION-inline-constraint.md).
