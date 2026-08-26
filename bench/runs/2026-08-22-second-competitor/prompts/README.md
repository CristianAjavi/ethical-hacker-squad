The six `aig-*` prompts are this round's new arm. The corpus and `mantis` arms were not
re-run: their twelve artifacts come unchanged from `../2026-08-22-recall-resolution/`, whose
`prompts/` holds the prompts that produced them.

Every claim from all three arms was re-pooled and re-judged here by the two verifier passes
and the recall judge in this directory, so no arm's number is carried over from an earlier
judging. Both facts are what make the three columns comparable.

Every prompt carries the same outside-information clause.

## What this directory does NOT contain

The per-arm **launch call**. Every `mantis` launch in this round carried *run the stages
inline rather than spawning sub-agents*, and no `ours` launch carried anything like it —
so the sentence above, that the arms differ only in which corpus the launch points at, is
**wrong**, and it names the smaller difference while omitting the larger.

A `prompts/` directory that ships the shared template and not the launch call is a
directory that can be complete and still mislead. `gate-bench-integrity.sh` checked that
prompts exist; it could not check that they were all of it.
See [`../../CORRECTION-inline-constraint.md`](../../CORRECTION-inline-constraint.md).
