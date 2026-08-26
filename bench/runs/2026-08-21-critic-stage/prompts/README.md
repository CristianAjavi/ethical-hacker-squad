# The prompts

`corpus-arm.txt` is byte-for-byte the prompt the previous corpus-arm rounds used. **Nothing about the critic stage is in it**: the stage came from the corpus, which is the only way this round could measure the corpus rather than the prompt.

`verifier.txt` is byte-for-byte the file `../../2026-08-21-weak-precision/prompts/verifier.txt`, which is also what the corpus-precision and three-way rounds used. Every arm compared here was judged by the same instrument.

## Outside information

The run prompt predates `../../../prompts/external-sources.txt` and does not carry the policy, exactly as the corpus-arm rounds it is compared against do not — see `../../2026-08-21-weaker-model/prompts/README.md`. The verifier prompt does carry it.

**What that costs this round is nothing, and the reason is specific.** The comparison that decides it is ground-truth recall, 3/6 against 4/6, between two sets of runs that received the *same* prompt with the same silence. The claim counts are compared as counts, not as a proportion. No recall claim is made against an arm that had different latitude.

## What this directory does NOT contain

The per-arm **launch call**. Every `mantis` launch in this round carried *run the stages
inline rather than spawning sub-agents*, and no `ours` launch carried anything like it —
so the sentence above, that the arms differ only in which corpus the launch points at, is
**wrong**, and it names the smaller difference while omitting the larger.

A `prompts/` directory that ships the shared template and not the launch call is a
directory that can be complete and still mislead. `gate-bench-integrity.sh` checked that
prompts exist; it could not check that they were all of it.
See [`../../CORRECTION-inline-constraint.md`](../../CORRECTION-inline-constraint.md).
