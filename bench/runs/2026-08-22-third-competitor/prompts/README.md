The six `pentest-ai-run*` prompts are this round's new arm. The other three arms were not
re-run: their eighteen artifacts come unchanged from `../2026-08-22-second-target/runs/`.

**Every claim from all four arms was re-pooled and re-judged here** by the two verifier passes
and the recall judge in this directory, so no arm's number is carried over from an earlier
judging. That is what makes the four columns comparable.

Every prompt carries the same outside-information clause. The new arm's own `code-auditor`
definition asks for `model: sonnet` and was run on `claude-haiku-4-5` to match the scale every
other arm was measured at - declared in the pre-registration before the run, and a handicap
against the product's own written intent.

## What this directory does NOT contain

The per-arm **launch call**. Every `mantis` launch in this round carried *run the stages
inline rather than spawning sub-agents*, and no `ours` launch carried anything like it —
so the sentence above, that the arms differ only in which corpus the launch points at, is
**wrong**, and it names the smaller difference while omitting the larger.

A `prompts/` directory that ships the shared template and not the launch call is a
directory that can be complete and still mislead. `gate-bench-integrity.sh` checked that
prompts exist; it could not check that they were all of it.
See [`../../CORRECTION-inline-constraint.md`](../../CORRECTION-inline-constraint.md).
