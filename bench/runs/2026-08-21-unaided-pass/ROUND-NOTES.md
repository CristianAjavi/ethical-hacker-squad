# Round notes — things that happened while the round ran

Kept apart from `PREREGISTRATION.md` on purpose. That file was written before any run returned and does not change. This one is dated observation, written as it happened, including the parts that weaken the round.

## The control arm moved 21 points on a prompt rewrite, and that is the largest effect in this bench

| | Pairwise agreement | Mean |
|---|---|---|
| no corpus, **this round** | 0.55 · 0.67 · 0.60 | **0.60** |
| no corpus, previous round | 0.73 · 0.80 · 0.90 | 0.81 |

Same arm, same target, same blind same-defect instrument, same judging rule. What differs is the run prompt, which the previous round did not store and this one had to write fresh.

**Twenty-one points is larger than any corpus-versus-no-corpus difference this bench has ever measured.** The consequence is blunt: no number in `bench/` may be compared against a number from a different sitting unless the run prompt travelled with it. The decision to re-run both arms today — taken in the pre-registration, before any result existed — is the only reason this round has a control at all.

It also means every published comparison here needs its prompt archived beside it. That is now a defect in the bench, not a footnote.

## One run died and is not scored

`treatment-6` delegated part of its work to a specialist subagent. That child went silent at 17:57 and the parent stopped writing at 18:05; at 18:14 neither had moved. It was stopped by hand and **is not a run**.

Its partial artifact is preserved unscored in `unfinished/treatment-6-partial.json` — 11 findings, 16 unaided candidates — and it did **not** validate at the moment it died: a label declared `reported` that no finding carried, a `confirmed` while a triage rule answered `HOLDS`, and CVE identifiers in `traceability`, which matches no declared family. Whether it would have fixed those before finishing is unknowable, so none of it counts in either direction.

This is the same rule the competitor arm got when it died in the whole-repository round, and it cut against us then. Applying it the same way when it cuts the other way is the whole point of having a rule.

## The replacement run carries a prompt difference, and here it is

`treatment-7` was launched with one sentence runs 4 and 5 did not have: **do not delegate to subagents.** It was added to remove the failure mode that killed run 6.

Runs 4 and 5 did their work in one context and never spawned a specialist, so the sentence forbids something neither of them did. That makes it a removed risk rather than a changed method — but it is still a prompt difference between runs of the same arm, in a round whose headline finding is that the prompt matters more than the corpus. It is written here rather than left out.

## The arms did not compete under the same rules about outside information

At least one no-corpus run reports that it **diffed the target against the upstream `main` branch** and identified two hardening controls that exist upstream and are absent here. At least one corpus run cites **CVE identifiers** for the defects it found.

Neither was authorized or forbidden by the protocol, because the protocol never said anything about it. Finding a defect by diffing against a fixed upstream is not the same act as finding it by reading the code, and an arm that does it is not doing the task the other arm is doing.

This does **not** touch consistency, which is agreement between runs of one arm and is unaffected by what both of them consulted. It does invalidate any recall reading from this round, and it casts a shadow over the earlier recall rounds, which had the same silence in their protocol. Recorded as work to do: the permission to consult outside sources has to be stated in the run prompt, identically for every arm, and each finding has to say where it came from.
