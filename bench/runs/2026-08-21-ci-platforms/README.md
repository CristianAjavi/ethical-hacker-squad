# Run 2026-08-21 — the CI platforms that are not GitHub Actions

`INF-19`..`INF-23` were written in the same week as this run. A new pack is a claim, and this is the claim being measured on the case built for it: `bench/cases/pipelines-migration`, four CI platforms in one repository, a GitLab runner configuration, and an export of the provider settings in the tree.

One specialist, fresh context, given the three `infra-cloud` pack files, `triage.md` and the artifact contract. No answer key in its reach.

## Result

| | |
|---|---|
| planted defects on this case | **5 of 5 detected** |
| decoys on this case | **0 of 5 reported** |
| findings the key never planted | 4, none counted against the run |

| Planted | Procedure | Reported as |
|---|---|---|
| `P-33` unprotected token reachable from a merge-request pipeline | `INF-19` | `F-001` `confirmed` |
| `P-34` change title interpolated into a Groovy `sh` string | `INF-20` | `F-002` `confirmed` |
| `P-35` publish token in the environment of a vendored linter | `INF-21` | `F-003` `confirmed` |
| `P-36` build template included from a moving branch | `INF-22` | `F-004` `confirmed` |
| `P-37` privileged shared runner with the host Docker socket | `INF-23` | `F-005` `confirmed` |

The recall line in the score files reads **14% on the bench**, not 100%: the scorer measures against all 37 planted defects across seven cases, and this specialist audited one. The number that belongs to this run is 5 of 5 on the case it was given.

**The decoy column is the one that cost something.** Five constructs were built to be mistaken for the five above — a SHA-pinned `include` beside the moving one, an ephemeral protected-ref runner beside the privileged one, a single-quoted `sh` step one line below the double-quoted one, a CircleCI context the settings export shows restricted, an Azure pipeline with no PR trigger. None was reported. The specialist recorded eleven ruled-out constructs with the rule that ruled each one out, and the five decoys are among them.

## The four unlabelled findings

Not counted either way, and worth reading: Jenkins agents whose workspace is reused between builds (`INF-23`), container images pinned by moving tag in the GitLab pipeline (`INF-22`), the CircleCI orb declared as a version range (`INF-22`), and Jenkins fork discovery reported as `probable` — the only finding whose `FP-08` was answered `UNKNOWN`, because the settings export documents the fork posture for Azure and CircleCI and is silent about the Jenkins branch source. That last one is the pack working as written: the honest answer to a control that lives outside the repository, with no exported evidence, is `UNKNOWN`.

## What the run found in our own machinery

Both scores are published — `score-as-authored.*` against the key as it was written, `score-corrected.*` against the key after the corrections below — with the as-authored key stored as `key-as-authored.json`, because a key quietly fixed after seeing the answers is not a key.

**As authored: 3 of 5 detected and 1 decoy reported. Corrected: 5 of 5 and 0.** Every one of the three corrections is a defect in the key, none is a change to what any construct is, and none touched the artifact, which is stored exactly as the specialist wrote it.

1. **`P-33` was declared over lines 29–40; the `integration:` job is 28–37.** The range began one line inside the job and ran four lines past its end into the next one. The specialist pointed at line 28, the job header, and was scored as missing it.
2. **`P-37` was declared over lines 5–14; the first `[[runners]]` block is 4–11.** Same shape, and worse: lines 13–14 belong to the *second* runner, which is decoy `D-35`.
3. **`D-33` was declared over lines 6–13 of a file whose planted defect `P-34` sits at line 12.** A decoy whose range contains a planted defect cannot be told from it by any scorer: the one correct finding was counted as a detection and as a false positive at the same time. Three further ranges (`D-32`, `D-35`, `D-36`) ran past the end of their files and were corrected too.

The third one is now impossible to reintroduce: `gate-bench-integrity.sh` fails when a planted span and a decoy span overlap in the same file, with a self-test case that reinstates exactly this overlap and asserts the reason.

The artifact was also rejected by `gate-findings-artifact.sh` on its first emission — `ruled_out` inside each finding, ids as `F-01`, `schema_version: "1.0"`. All three were the reference document's fault, not the specialist's; it is fixed in the same branch and the field table now states the level of every field. The specialist re-serialised its own artifact with no change to any finding's substance.

## What this is not

- **One case, one specialist, one model.** Five planted defects is not a rate.
- **A bench this project wrote.** The cases and the procedures came from the same place, so a high score partly measures that the corpus describes the code it was written from. Say "5 of 5 on the case", never "detection rate".
- **A statement about real pipelines.** Nothing here was run. Every finding is static reading, and three of the five procedures depend on a provider setting that a real engagement would have to ask for.

## Files

`findings-pipelines-migration.json` is the artifact as delivered. `key-as-authored.json` is the answer key before the corrections; `score-as-authored.*` and `score-corrected.*` are the two scores.
