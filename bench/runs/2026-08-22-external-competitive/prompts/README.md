Every prompt carries the same outside-information clause, and none names a module or a file:
the arms were given a 144-file Go repository and nothing else.

`corpus-run5-replacement.txt` is the run launched after EC3 died. It differs from the other
corpus prompts by one added sentence telling it to write its artifact after every finding,
because the run it replaced had stalled. That is a difference between it and its three
siblings and it is stated rather than hidden.

## What this directory does NOT contain

The per-arm **launch call**. Every `mantis` launch in this round carried *run the stages
inline rather than spawning sub-agents*, and no `ours` launch carried anything like it —
so the sentence above, that the arms differ only in which corpus the launch points at, is
**wrong**, and it names the smaller difference while omitting the larger.

A `prompts/` directory that ships the shared template and not the launch call is a
directory that can be complete and still mislead. `gate-bench-integrity.sh` checked that
prompts exist; it could not check that they were all of it.
See [`../../CORRECTION-inline-constraint.md`](../../CORRECTION-inline-constraint.md).
