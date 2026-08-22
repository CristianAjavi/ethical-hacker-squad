# Run 2026-08-22 — both criteria met: the capability claim returns, with both halves

| | claims | refuted by **both** passes | ground-truth recall | union over its runs |
|---|---|---|---|---|
| **this corpus** | 36 | **0 (0%)** | 6, 7, 4, 4, 3, 3 → **mean 4.50 / 7** | **7 / 7** |
| `google/mantis` @ `5f76be0` | 47 | 8 (17%) | 6, 4, 4, 5, 4, 6 → **mean 4.83 / 7** | 6 / 7 |

**Six new runs per arm**, `claude-haiku-4-5`, target `bench/cases/rag-agent` unchanged, all 83 claims pooled into one blinded batch, two independent adversarial passes, blind defect matching against the 7 planted defects. **Inter-pass agreement 73/83 (88%)** — lower than the pilot's 95%, and that is this round's resolution.

## The verdict, against criteria committed before these runs

- **Precision: MET.** 0% against 17%, a **17-point** gap where 10 was required.
- **Recall: MET.** 4.50 against 4.83 is **0.33 below**, inside the pre-registered band of 0.5.

**The pilot's three runs are excluded from both numbers.** Their values were already known when this band was written, so they cannot be the evidence; they return only as the labelled secondary below.

The pre-registration said what this forces: *the capability claim returns to `README.md` — precision at weak scale against the strongest published competitor — with both halves stated together and the recall band named.* That is done.

## Why three runs could not have settled this, shown rather than argued

| | pilot, 3 runs | this round, 6 runs |
|---|---|---|
| corpus union of defects found | 6 / 7 | **7 / 7** |
| competitor union | 7 / 7 | 6 / 7 |

**The union flipped.** On three runs the competitor covered all seven and this corpus missed one; on six it is the reverse. Nothing changed but the number of runs. That is the clearest possible demonstration that the pilot's one-defect margin — the margin that withdrew the claim — was noise, and that withdrawing on it was the right call given what was known at the time.

## The competitor arm has one contaminated run, and it is reported both ways

**`m4` skipped the competitor's own filtering stages** — dedupe, review and critic — and delivered raw researcher output, while the other five ran them. Unfiltered claims inflate its refuted count, so the number is given both ways:

| | corpus | competitor, all six | competitor, `m4` excluded |
|---|---|---|---|
| refuted by both passes | 0% | 17% | **18%** |
| recall mean | 4.50 | 4.83 | 4.60 |

Both criteria hold either way, and **excluding `m4` moves both numbers in this project's favour** — which is exactly why it is stated rather than quietly adopted. The headline uses all six.

## What the verifiers found in our own bench case

**`build_prompt_marked`, the "hardened" twin the case ships as the safe control, is not safe.** It renders `origin` and `trust` through `!r` but interpolates `d['text']` raw, so a ticket body containing `</document>` closes the container and injects forged markup inside it. Both passes reached this independently, one verifying it by rendering.

**That claim came from the corpus arm** (`c8`, claim `R80`). A defect in the control half of a case written in this repository, found by the tool rather than by its authors. It is filed in `bench/ground-truth.json` under `case_defects` — the answer key, which a scorer reads and an arm never does — rather than in the case's own README, which **is** copied into the target and would have handed the vocabulary of the key to every future run. `gate-bench-integrity.sh` refused the first attempt to write it there. It is not a finding in this table: a case whose safe twin is unsafe cannot cleanly separate a false positive from a true one, and the six sibling claims that say "the marking does not prevent injection" are supported rather than refuted **because of it**.

**Six claims shipped with an empty `evidence` field, and all six are the competitor's** (`m7`). It did not cost them anything — both passes judged them on title and impact and supported all six — and it is recorded because the reverse would have been recorded too.

## What this does not establish

- **One target, one competitor, one model scale.** Unchanged, and it is the whole shape of the claim.
- **0 of 36 is a strong number and a small one.** Both arms' claim sets are heavily duplicated — the verifiers counted 14 claims on the same API key and 13 on the same `shell=True` across the pool — so these are 83 claims about roughly seven defects, not 83 independent tests.
- **Inter-pass agreement fell to 88% from the pilot's 95%.** A 17-point gap is well outside that, a 0.33 recall gap is not, which is why the recall criterion is a band and not a threshold.
- The verifier and the critic are the same kind of instrument for both arms: this measures how well a product filters its own bad claims, not truth.
- The competitor ran read-only and offline. Its floor, not its ceiling.

## Secondary: pooled with the pilot, nine runs per arm

| | claims | refuted by both | recall mean |
|---|---|---|---|
| this corpus | 52 | 1 (2%) | 4.44 / 7 |
| competitor | 70 | 15 (21%) | 4.78 / 7 |

Labelled secondary because the pilot's numbers were known when this round's band was set. It moves nothing: the same two criteria hold.

## Files

`PREREGISTRATION.md` first, with the band, the exclusion of the pilot, and all four outcomes. `runs/` holds all twelve artifacts, `verify/` the pooled blinded batch and both passes, `recall/` the blind matching, `keys/` the provenance and answer key in a directory no verifier's prompt names, `prompts/` the prompts with the note on how they were derived. `pool-claims.py` is the blinding — including the path normalisation that stops one arm's `target/`-prefixed and `file.py:48`-style locations from labelling it, both caught before any verifier ran.
