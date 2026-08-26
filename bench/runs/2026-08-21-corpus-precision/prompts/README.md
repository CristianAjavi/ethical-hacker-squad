# The prompt both verifiers received

`verifier.txt` is copied **byte for byte** from `../../2026-08-21-weak-precision/prompts/verifier.txt`. That is the point: the two arms were verified by the same instrument, and any difference in their numbers cannot come from the wording.

Outside information: the verifier prompt names the target as the only code it may consult, which is the policy `../../../prompts/external-sources.txt` states. The claims being verified come from runs whose own prompts predate that policy — see `../../2026-08-21-weaker-model/prompts/README.md`.

## What this directory does NOT contain

The per-arm **launch call**. Every `mantis` launch in this round carried *run the stages
inline rather than spawning sub-agents*, and no `ours` launch carried anything like it —
so the sentence above, that the arms differ only in which corpus the launch points at, is
**wrong**, and it names the smaller difference while omitting the larger.

A `prompts/` directory that ships the shared template and not the launch call is a
directory that can be complete and still mislead. `gate-bench-integrity.sh` checked that
prompts exist; it could not check that they were all of it.
See [`../../CORRECTION-inline-constraint.md`](../../CORRECTION-inline-constraint.md).
