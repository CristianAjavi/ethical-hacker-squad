# The prompts

Both arms received `../../../prompts/external-sources.txt` **identically** — this is the first whole-repository round in this bench where they did, and the gap it closes is recorded in `../../2026-08-21-unaided-pass/ROUND-NOTES.md`.

The corpus arm was pointed at the corpus and told to follow it. The unaided arm was told there is no checklist and no methodology document. Neither was told a module, a file, or that anything was wrong; both were told that deciding what to read is part of the task. Both were told that recognising the project and remembering a published advisory is not evidence.

`verifier.txt` does not appear here because this round scores advisory matching, not claim precision. The judge prompt is reproduced in the round README's method section.

## What this directory does NOT contain

The per-arm **launch call**. Every `mantis` launch in this round carried *run the stages
inline rather than spawning sub-agents*, and no `ours` launch carried anything like it —
so the sentence above, that the arms differ only in which corpus the launch points at, is
**wrong**, and it names the smaller difference while omitting the larger.

A `prompts/` directory that ships the shared template and not the launch call is a
directory that can be complete and still mislead. `gate-bench-integrity.sh` checked that
prompts exist; it could not check that they were all of it.
See [`../../CORRECTION-inline-constraint.md`](../../CORRECTION-inline-constraint.md).
