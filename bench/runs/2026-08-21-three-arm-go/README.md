# Run 2026-08-21 — three arms, three cases nobody here chose

The earlier A/B ran two advisories and produced one tie and one difference. Two cases cannot support a claim, and the claim being tested is a large one: that this is the best thing of its kind available. So this run widens it to three advisories picked by a **published rule** — recorded, with its rejects, before any arm was run against them — in classes this corpus does not obviously cover.

Same model, same targets, same output contract, same blind judging protocol, three arms:

| Arm | What it received |
|---|---|
| **treatment** | the corpus as it ships: `coverage.md` routes, the packs it names, `triage.md`, the artifact contract |
| **control** | the target, an output schema, and one instruction — *senior application security engineer, your own judgement, your own method* |
| **competitor** | [`google/mantis`](https://github.com/google/mantis) at `5f76be0`, Apache-2.0, followed as written. Nothing from it copied here |

## Result

| Advisory | With the corpus | Without it | Competitor |
|---|---|---|---|
| `CVE-2026-55149` — unbounded multipart cookie allocation | **found** | **found** | **found** |
| `CVE-2026-53657` — root privilege in a VM through the guest-agent socket | **found** | **found** | **found** |
| `CVE-2026-64868` — unauthenticated webhook body read with no limit | **missed** | **missed** | **missed** |
| | **2 / 3** | **2 / 3** | **2 / 3** |

**That is a flat tie, and it is the honest headline of this run.** On three cases nobody here selected, the corpus performed exactly as well as an unaided senior engineer and exactly as well as a neighbouring product: the same two found, the same one missed, by all three.

74 findings were judged. Each judge saw only the advisory text and one finding's text, with opaque ids and an order fixed by a hash unrelated to the arm; the mapping back to arms was joined in afterwards, from a file the judges never received. `judgements-deblinded.json` holds every verdict with its reasoning and its arm.

## What this does to the claim

The A/B in `../2026-08-21-ab-corpus/` shows the corpus finding a stored-XSS sink that the other two arms missed. That result stands and is reproducible from its artifacts. **This run says that result does not generalise.** Three cases chosen by a rule produced no difference at all, and a fair reading of both runs together is:

> On code shaped like the cases we wrote, and on one published advisory, the corpus adds something. On three published advisories nobody here chose, it adds nothing measurable. Anyone claiming this is the best available tool does not have the evidence for it, and this file is where that would have to come from.

## The miss all three share, and what it is worth

`CVE-2026-64868` is the interesting one, because the defect **is** visible in the files given, in the hardest possible shape: `constant/env.go` declares `MaxRequestBodyMB`, `common/init.go` assigns it from `MAX_REQUEST_BODY_MB`, and **nothing in the target reads it** — the consumer is one of the two files the fix creates. The vulnerable state, seen from what an auditor was handed, is *a configured limit with no enforcer* on a router that registers unauthenticated webhook POSTs.

Nobody asked who reads that constant. The no-corpus arm went further and asserted the opposite — "the request-body and stream-buffer caps are present with sane defaults" — reading the declaration as the control. That is a false negative produced by a plausible inference, and it is the exact failure a written procedure is supposed to prevent.

**The corpus has no procedure for it.** Dead configuration — a knob that is declared, documented, plumbed through the environment and consumed by nothing — is a control that does not exist while looking like one. That gap is now the most concrete improvement this bench has produced, and it came from losing.

## The one asymmetry worth noticing, and why it is not a win

| Arm | Findings reported across the three cases |
|---|---|
| treatment | 13 |
| control | 31 |
| competitor | 30 |

The corpus arm reached the same two advisories with **less than half the output** of either other arm. That is consistent with a triage discipline doing its job — every reported finding had to survive `FP-01`..`FP-10`, and the arm declared `UNKNOWN` rather than reporting where the chain left the files it was given. It is **not** a precision result: this run has no key for anything but the three advisories, so it cannot say whether the other 18 and 28 findings are true. Counting them as noise would be exactly the self-flattery the decoy column exists to prevent.

## What this is not

- **A benchmark of the competitor.** One product, one commit, three advisories, our prompt, and a pipeline missing the reproduction stage its own rubric expects — which its scores then discount it for.
- **A recall rate.** Three advisories. The rule that picked them still had a human typing an ecosystem and a severity.
- **A clean comparison.** The no-corpus arm settled two triage questions on `lima` by *running* shell constructs — it did not execute the target, but it took an experimental capability the corpus arm did not. That favours the control arm, and it is recorded in `provenance.json` with the rest.
- **The last word.** It is three cases. The right response to a flat tie is more cases and a procedure for what everyone missed, not a better-sounding sentence.

## Files

`provenance.json` was written **before** the results: the selection rule, how each target was fetched, which defects are visible in which files, and the deviations as they happened. `build-judge-pairs.py` builds the blind batch and refuses to write one that carries an arm label or a non-opaque id. `judgements-deblinded.json` is every verdict joined back to its arm. The per-arm artifacts are under `arms/`.
