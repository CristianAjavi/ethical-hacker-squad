# Run 2026-08-21 — six packs, blinded

| | |
|---|---|
| Planted defects detected | **32 / 32** |
| Decoys reported | **0 / 31** |
| Unlabelled findings | 8 |
| Statuses of what was reported | 18 `confirmed`, 18 `probable`, 4 `hardening` |
| Packs exercised | `web-api`, `local-app`, `infra-cloud`, `supply-chain`, `ai-safety`, `privacy-abuse` |

`score.txt` is the full output, `score.json` the machine copy, and the six `findings-*.json` are the artifacts exactly as the specialists wrote them.

## How it was run

Six specialists, in **fresh contexts**, each pointed at a copy of one case in a scratch directory containing that case and the reference material **and nothing else**. No repository, no answer key, no path that reaches one. None was told how many defects existed, and the only hint that decoys existed at all was one sentence saying the target contains real defects and constructs that resist.

Each emitted `findings.json`. **All six validated with `gate-findings-artifact.sh` before anything was scored** — the order matters, because a malformed artifact scored anyway reports a low recall that is really a formatting bug.

## The corrections this run forced, all of them

The run found six defects in the **scoring machinery**, not in the audits. Every one was fixed afterwards and every one moved the number, so the list belongs next to the result rather than in a commit nobody reads. Detection went 26 → 32 and reported decoys went 4 → 0 as these landed:

1. **The path normaliser ate a leading character.** `app/serializers.py` became `pp/serializers.py`, so every privacy finding fell out of its file. Replaced with explicit steps.
2. **A bare filename matched a file in a subdirectory.** A finding at `main.tf` was scored against `modules/network/main.tf`, which turned a correct report into a reported decoy. File matching is now anchored on a separator.
3. **Only the first declared location of a defect was tried.** A defect with a helper and its caller in one file has two spans; taking the first scored a correct finding at the caller as a miss.
4. **Spans were computed by a fixed twelve-line window and overlapped.** Adjacent functions — the defect and the control beside it — claimed the same lines, so a finding could be attributed to either. Spans now end at the next definition, are tightened per file type, and the key is checked for overlaps.
5. **The start of a span was found by substring.** `sign` matched inside another word and moved a span onto the wrong function.
6. **`hardening` was not counted as reported.** It reaches the client's document, so a defect reported as hardening is detected — with the status recorded, not hidden. Only `discarded` and `withdrawn` do not count, and `candidate` may never ship.

**Why this is not tuning.** Every fix is a property of how findings are attributed to locations, not of these forty findings: each is covered by a case in `scripts/bench/score.selftest.sh`, including a near-miss case asserting that pointing at the decoy next door is **not** a detection. The artifacts were never edited — they are stored here as written and can be re-scored against any future version of the key. Anyone who thinks a fix was self-serving can check it against the six files.

## What the numbers are worth

**Recall is recall on this bench.** The cases were written by the same project that wrote the procedures. A perfect score says the routing works and the patterns match code shaped like the cases; it says nothing about code nobody here has seen.

**The decoy column is the one that costs something to fake.** Thirty-one constructs built to look exactly like the defect beside them — the scoped queryset, the escaped sink, the allowlist checked after parsing, `extractall(filter="data")`, `mkstemp`, `gpg --`, `0600`-in-`0700`, the `ResourceAccount` condition, the CloudFront origin identity, the pinned SHA-256, the `${VAR}` placeholder, the spotlighted prompt, the session-scoped tool, the closed-schema memory, the consent gate, the pseudonymising prompt builder. None was reported, and the `ruled_out` sections say which rule settled each one.

**The eight unlabelled findings are worth reading.** They are not counted against the run, and several are real: missing audit logging in the Terraform root, a root with no backend block leaving state local, `npm publish` without provenance, an ELF artifact tracked in the tree. The bench did not plant them and the specialists found them anyway.

**What is still silent.** `remediation` is the one pack with no case, and it is not a detection pack: `REM-*` and `VER-*` describe how a patch is made and verified, which a static target cannot exercise. Measuring it needs a different harness — a defect, a patch, and a verifier that must catch a patch that does not fix it. That is the next honest gap, and it is written here rather than left for a reader to notice.
