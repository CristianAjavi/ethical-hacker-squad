# Run 2026-08-21 — three-way precision: the competitor is the most precise, and we predicted it

`PREREGISTRATION.md` predicted the competitor's refuted proportion would come in **below** ours, because `mantis` ships explicit `critic`, `dedupe` and `review` stages that this corpus does not have as separate stages. It named what would refute that: the competitor landing at or above 62%.

**Measured: 53%. The prediction is confirmed, against us.**

| Arm | claims | refuted by both passes | supported by both | inter-pass agreement |
|---|---|---|---|---|
| **competitor** — `google/mantis` @ `5f76be0` | **17** | **9 (53%)** | 4 | 16/17 (94%) |
| **with the corpus** | 26 | 16 (62%) | 9 | 26/26 (100%) |
| **without any corpus** | 28 | 19 (68%) | 4 | 25/28 (89%) |

Same target, same weak model, same verifier prompt byte for byte, two independent adversarial passes per arm, every arm blinded to arm, model and run. All three arms carried the same outside-information policy.

**The claim counts differ — 17, 26, 28 — and that is in this table rather than in a footnote**, as the pre-registration required. Each arm was pooled over three or nine runs; the competitor's three runs returned 7, 7 and 3.

## The result that all three arms now agree on

**Every claim that survived, in every arm, is one of the two ground-truth defects.**

The competitor's four survivors are `M06`/`M07` (the allocation) and `M12`/`M15` (the recursion). Ours were the same two. The unaided arm's were the same two.

**Three arms, seventy-one claims, and the only true findings anywhere are the two the ground truth already named.** Everything else — forty-four claims refuted twice over — is refutable from the file the reviewer had open. That is the strongest evidence this bench has produced for the reading its rounds keep arriving at: **detection is the model's, not the product's**, and at weak scale no pipeline rescues it.

## Where the competitor is genuinely better, and where its filtering failed

Nine points of precision, and it is a real margin: its refuted claims are fewer in proportion than either of ours.

But the same verifiers recorded, unprompted, that its **17 claims cover roughly 9 distinct assertions** — `M01`/`M05`, `M06`/`M07`, `M12`/`M15`, `M03`/`M04`/`M08` and `M10`/`M11` are duplicate pairs or triples — and that **within two of those pairs the duplicates contradict each other on the facts**. `M05` says the `*1000` at line 269 is a thousand-fold bug; `M01`, about the same line, says it is unchecked arithmetic with no attacker gain. Both cannot be right, and a `dedupe` stage ran.

So the competitor wins on the proportion of claims that survive attack, and its deduplication did not do what it says on the box. Both are published because both are measured.

## What this forces, in the words the pre-registration committed to

> *Competitor better — we are not the best on precision either. The documentation stays exactly as honest as it now is, and the finding becomes a concrete thing to adopt: an explicit critic stage, measured before and after.*

That is the outcome. **Seventeen measurements; the corpus leads on none of them**, and this is the first one that puts a named competing product ahead rather than level.

The concrete thing to adopt is now specific rather than aspirational: this corpus has triage rules a specialist applies *while writing a finding*, and no separate stage whose only job is to attack the finished list. The competitor has one. **The next change is that stage, and it gets measured with this exact instrument, before and after, on this exact target.**

## Caveats, all stated in the pre-registration

- One target, one weak model, one competitor, and a target of two files a verifier can read entirely.
- Unequal claim counts, shown in the table.
- The corpus arm's 26 claims pool three corpus versions; disclosed in `../2026-08-21-corpus-precision/`.
- Precision says nothing about recall, where every arm that has been measured against another has tied — including here, where the competitor's three runs found the two defects in one run and neither in another.
- The competitor was run read-only and offline, so its `reproduce`, `patch`, `chain` and `calibrate` stages did not run. Its `researcher`, `dedupe` and `review` stages did. A fuller run might filter more, and this is the arm's floor rather than its ceiling.

## Files

`PREREGISTRATION.md`, including the amendment that pooled the competitor's runs — written knowing only the first run's claim *count* and none of its content. `claims.json` is the blinded batch exactly as both verifiers received it. `verdicts-deblinded.json` holds both passes for all three arms.
