# Pre-registration — the corpus arm's claims, verified the same way

**Written before any verifier saw a claim.** This is the follow-up `../2026-08-21-weak-precision/` named, run as its own round rather than as a quiet reversal of the decision recorded there.

## Why the earlier decision is being revisited, and on what grounds

The weak-precision round deliberately did **not** verify the corpus arm, and said why: that arm had produced 2, 2 and 2 findings, and putting six claims against twenty-eight yields a ratio nobody should trust.

That objection was about **sample size, not about fairness**, and it has dissolved. Three separate weak-scale rounds have now run — before the loading rule, after it, and after the dismissal rule — for **nine corpus-arm runs carrying 26 claims in total**, against the 28 unaided claims already verified. The comparison can now be made at comparable N, which is exactly the condition the earlier decision was waiting on.

Pooling across the three rounds is stated here rather than discovered later: the nine runs did **not** all use the same corpus. Three predate the loading rule, three carry it, three carry it plus the dismissal rule. **This measures the corpus arm's precision as a family, not any one version of it**, and no per-version precision claim may be drawn from it.

## What is being decided

Fifteen measurements; the corpus leads on none. Precision at weak scale is the one place left where it plausibly could, because it is the only dimension where the corpus carries machinery the unaided arm has none of — `FP-01`..`FP-10`, a `ruled_out` section, a status short of `confirmed`, and an inference that must name what would settle it.

The unaided arm's number is already on the board: **4 of 28 supported by both passes, 19 refuted by both.**

## The prediction

**Prediction: the corpus arm's proportion refuted by both passes is lower than the unaided arm's 19/28 (68%), by more than ten points.**

**What refutes it:** a refuted proportion within ten points of 68%, or higher.

**What each outcome forces.**
- If the corpus arm is markedly more precise, then **for the first time in this bench the corpus leads on a dimension**, and the honest product claim becomes a precision-recall trade with numbers on both sides — not "finds more".
- If it is not, the corpus leads on nothing at any scale on any dimension measured here, and the documentation has to say that in those words.

## Method, fixed in advance

- All 26 claims from the nine weak corpus-arm runs, stripped of anything naming arm, model, run or corpus version, opaque ids, order fixed by a digest of the claim's own text.
- **The same verifier prompt, byte for byte**, as `../2026-08-21-weak-precision/prompts/verifier.txt`. Two independent passes. `undecidable` is not a polite `supported`.
- Inter-pass agreement reported as the resolution of the instrument, as before.
- The unaided arm is **not** re-verified. Its 19/28 stands as measured.

## Caveats stated in advance

- The corpus arm's claims are drawn from three corpus versions; the unaided arm's from one prompt. The pooling is disclosed above and is a real asymmetry.
- Both arms' claims come from runs whose prompts predate `../../prompts/external-sources.txt`.
- A precision comparison says nothing about recall. Recall is already measured and the corpus arm is behind by one defect, which is inside this bench's resolution.
- Two files. A verifier can reach every line, which makes verification unusually easy here and not representative of a repository.
