# The prompts

`corpus-arm.txt` is byte-for-byte the prompt the previous corpus-arm rounds used. **Nothing about the critic stage is in it**: the stage came from the corpus, which is the only way this round could measure the corpus rather than the prompt.

`verifier.txt` is byte-for-byte the file `../../2026-08-21-weak-precision/prompts/verifier.txt`, which is also what the corpus-precision and three-way rounds used. Every arm compared here was judged by the same instrument.

## Outside information

The run prompt predates `../../../prompts/external-sources.txt` and does not carry the policy, exactly as the corpus-arm rounds it is compared against do not — see `../../2026-08-21-weaker-model/prompts/README.md`. The verifier prompt does carry it.

**What that costs this round is nothing, and the reason is specific.** The comparison that decides it is ground-truth recall, 3/6 against 4/6, between two sets of runs that received the *same* prompt with the same silence. The claim counts are compared as counts, not as a proportion. No recall claim is made against an arm that had different latitude.
