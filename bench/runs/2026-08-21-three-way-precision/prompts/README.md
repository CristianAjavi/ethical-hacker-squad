# The prompts

`verifier.txt` is copied **byte for byte** from `../../2026-08-21-weak-precision/prompts/verifier.txt`, which is the same file `../../2026-08-21-corpus-precision/` used. All three arms were judged by the same instrument, so no difference in their numbers can come from the wording.

`competitor-arm.txt` is what the competitor arm received. It points at the third-party pipeline's own instructions and states that those instructions govern. It carries the outside-information policy from `../../../prompts/external-sources.txt`, as did the runs of the other two arms in this comparison's source rounds — except that those rounds predate the policy, which is disclosed in each of them.

Nothing from the competitor's repository is copied into this one. It was read at its pinned commit and followed as written.

## What this directory does NOT contain

The per-arm **launch call**. Every `mantis` launch in this round carried *run the stages
inline rather than spawning sub-agents*, and no `ours` launch carried anything like it —
so the sentence above, that the arms differ only in which corpus the launch points at, is
**wrong**, and it names the smaller difference while omitting the larger.

A `prompts/` directory that ships the shared template and not the launch call is a
directory that can be complete and still mislead. `gate-bench-integrity.sh` checked that
prompts exist; it could not check that they were all of it.
See [`../../CORRECTION-inline-constraint.md`](../../CORRECTION-inline-constraint.md).
