# The prompts

`verifier.txt` is copied **byte for byte** from `../../2026-08-21-weak-precision/prompts/verifier.txt`, which is the same file `../../2026-08-21-corpus-precision/` used. All three arms were judged by the same instrument, so no difference in their numbers can come from the wording.

`competitor-arm.txt` is what the competitor arm received. It points at the third-party pipeline's own instructions and states that those instructions govern. It carries the outside-information policy from `../../../prompts/external-sources.txt`, as did the runs of the other two arms in this comparison's source rounds — except that those rounds predate the policy, which is disclosed in each of them.

Nothing from the competitor's repository is copied into this one. It was read at its pinned commit and followed as written.
