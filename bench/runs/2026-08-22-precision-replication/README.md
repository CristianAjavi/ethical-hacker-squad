# Run 2026-08-22 — the precision half replicated, the recall criterion did not, and the pre-registration is honoured

| | claims | refuted by **both** passes | supported by both | ground-truth recall | claims per defect |
|---|---|---|---|---|---|
| **this corpus** | 16 | **1 (6%)** | 14 (88%) | 4, 4, 5 → **mean 4.33 / 7** | 2.2 |
| `google/mantis` @ `5f76be0` | 23 | 7 (30%) | 15 (65%) | 4, 5, 5 → **mean 4.67 / 7** | 2.0 |

Target `bench/cases/rag-agent`, 7 planted defects and 6 decoys, picked by a rule written before it was applied. `claude-haiku-4-5` for both arms, three runs each, all 39 claims pooled into one blinded batch, two independent adversarial passes, **inter-pass agreement 37/39 (95%)** — that is this instrument's resolution and no smaller difference is reportable.

## The verdict, by the criteria committed before the runs

**Criterion 1 — precision — is met, and by more than it needed.** 6% against 30% is a **24-point** gap where 10 was required. The original round measured 21% against 53%. The direction and the rough size both replicate on a second target, a different language, a different defect class, and a target with 7 planted defects rather than 2.

**Criterion 2 — recall — is not met. The corpus arm's ground-truth recall is below the competitor's.** The pre-registration says what that forces, and it is being honoured rather than argued with:

> *Does not replicate, on either criterion. The README drops to ONE dimension in this project's favour, transparency, which is a claim about checkability and not about finding anything.*

**That is done.** The README's precision claim is withdrawn as a claim. The number stands as a measurement, published above; what does not stand is this project asserting a capability lead on the strength of it.

## Why that is the right call even though it looks harsh

The recall margin is **one defect, found in one of the competitor's three runs**: `P-28`, ingestion with no origin or trust metadata, which `m2` reported and no corpus run did. One item is inside this bench's own stated resolution, and by that standard the honest reading of recall is a **tie**, not suppression.

So the criterion is worse than the result. **It was mis-specified**: an absolute "at or above" on a 7-item scale, where a single item moves the number by 14 points, on three runs. It has no noise band, and this bench has told itself repeatedly that a one-item difference is not evidence. That is a defect in the pre-registration, written by the same hand that wrote the prediction.

**And it is not a licence to ignore the outcome.** The move available here — *the failing criterion was badly built, so keep the claim* — is precisely the move the whole apparatus exists to prevent, and it would be indistinguishable from motivated reasoning to any reader who was not in the room. A pre-registration that can be reinterpreted after the result is not a pre-registration. So the claim drops, the criterion's defect is recorded, and **what would settle it is named instead of assumed**: enough runs per arm to resolve a one-defect difference on this scale, which is more than three.

## Two standing caveats that this round corrects

**Our deduplication is not worse than the competitor's here.** The earlier round found our 19 claims covering 3 distinct assertions against their 17 covering about 9, and published that as inflating our denominator and flattering us. On this target it is **2.2 claims per defect for us against 2.0 for them** — near-identical, and the caveat does not transfer. It is corrected rather than carried forward unexamined.

**The competitor's extra claims are where its refutations live.** Of its 23 claims, **9 matched no planted defect at all** against 3 of ours. That is the same fact the precision number reports, seen from the answer key rather than from the verifiers.

## What the verifiers found in our own bench case, unprompted

Both passes independently reported that `rag-agent` is built as **matched pairs — a vulnerable function beside its hardened twin** (`build_prompt`/`build_prompt_marked`, `run_tool`/`run_tool_scoped`, `remember_from_reply`/`remember_preference`, `ingest_ticket`/`ingest_ticket_marked`), with **no call sites anywhere**, and both used that pairing as their sharpest instrument: a claim that fires on the *safe* twin is a false positive by the case's own construction. Six of pass B's eight kills are exactly that.

Both also declined to blanket-refute on unreachability, judging each claim on the function's own contract instead. That is the correct call for a library case and neither was told to make it.

**Three of the corpus arm's own supported claims carry false sub-assertions** that both passes named while still supporting the headline: a key described as matching the Anthropic pattern when the prefix is `sk-acme-` and the Anthropic key is read from the environment; a "lethal trifecta" whose outbound leg is asserted of a function that returns an f-string and makes no call; and a world-readable store whose file mode is never set anywhere in the target. Precision as measured here does not see any of that, and this bench should stop pretending it does.

## What this round does not establish

- One competitor, one model scale — unchanged from the round it replicates.
- **16 claims against 23**, in the table rather than a footnote.
- Three runs per arm, which is why the recall criterion could not be resolved.
- The verifier and the critic are the same kind of instrument for both arms. This measures how well a product filters its own bad claims, not truth.
- The competitor ran read-only and offline, so `reproduce`, `patch`, `chain` and `calibrate` did not run. Its floor, not its ceiling.

## Outside information, and how the two arms were kept level

**Both arms carried the same clause, and it is in every archived prompt:** *only the files under the target path and your own reasoning. Do not consult an advisory database, an upstream repository, a diff against another version, an issue tracker, or a web search.* The two verifier passes carried the same restriction. The target is a bench case authored in this repository and has no upstream, no advisory and no published fix, so there is nothing outside it to recognise — but the clause is stated identically anyway, because a recall number from a pair of arms with different information rules measures familiarity as much as review.

**This section exists because `gate-bench-integrity.sh` refused the round without it**, and refused it again for shipping no `prompts/` directory. That gate was built in this repository to catch exactly this, and the first thing it caught was this round.

## Files

`PREREGISTRATION.md` is what was committed first, including both refutation criteria and the sentence that is being honoured. `runs/` holds all six artifacts, `verify/` the pooled blinded batch and both passes, `recall/` the blind defect matching, `keys/` the provenance map and the answer key — kept in a directory no verifier's prompt names, after the map was first written beside the claims where a verifier could have read it. `pool-claims.py` is the blinding, including the path-normalisation that stops one arm's absolute paths from labelling it.
