# Run 2026-08-22 — a second target: each competitor falls outside a band, this corpus does not

> # CORRECTED — one run was wrongly excluded, and the correction costs this project its 0%
>
> **`C6` was published as NOT MEASURED and it had not died — it was slow.** It finished after 32 minutes with 6 findings. I declared it dead because its artifact had not been touched for seven minutes, which was not a measurement, it was impatience with a threshold on it. The bench's own rule — *a dead run is not a zero* — was written and followed; what did not exist was any criterion separating **dead** from **slow**, and the only reliable signal, the completion notification, had simply not arrived yet.
>
> Excluding a completed run because it was slow is a selection effect, so all **eighteen** runs were re-pooled into 91 claims and re-judged from scratch with the same instruments. **The corrected figures are in the table below and they supersede the five-run ones.** What changed:
>
> | | published (5 corpus runs) | **corrected (6)** |
> |---|---|---|
> | this corpus, refuted by both | 0 % | **3 % (1 of 30)** |
> | this corpus, recall | 4.80 / 5 | 4.83 / 5 |
> | inter-pass agreement | 98 % | **100 %** |
>
> **The excluded run contained the only corpus claim either target has ever had refuted**, so my error had been flattering this project. `C6`'s `R35` alleges broken object-level authorization on `/receipts/:id` — the one endpoint that *does* scope by `AND owner_id = $2`. It is a false positive fired at the safe twin, which is exactly what that decoy is in the case for. **`AI-Infra-Guard`, not this corpus, is the cleanest arm on this target.**
>
> The round's conclusion survives unchanged — each competitor still falls outside one band and this corpus outside none — and that is not a reason the correction was optional.
>
> `runs/C6.findings.json` is the artifact. `verify-corrected/` and `recall-corrected/` hold the re-judging; `verify/` and `recall/` hold the superseded five-run judging, kept rather than deleted.


| Arm | claims | refuted by **both** passes | ground-truth recall | union |
|---|---|---|---|---|
| **this corpus** | 30 | **1 (3%)** | 4, 5, 5, 5, 5, 5 → **4.83 / 5** | 5 / 5 |
| `Tencent/AI-Infra-Guard` | 25 | **0 (0%)** | 5, 3, 5, 4, 4, 4 → **4.17 / 5** | 5 / 5 |
| `google/mantis` | 36 | 3 (8%) | 5, 5, 5, 5, 5, 5 → **5.00 / 5** | 5 / 5 |

Target `bench/cases/express-invoices` — an ordinary Node HTTP API, 5 planted defects and 6 decoys, picked by a rule written before it was applied. Six runs per arm, `claude-haiku-4-5`, all 85 claims pooled into one blinded batch, two independent adversarial passes, blind defect matching. **Inter-pass agreement 91/91 (100%).**

**All six corpus runs are measured.** `C6` was briefly published as unmeasured and that was wrong; see the banner.

## The prediction split, and both halves matter

It predicted all three arms inside **10 points of precision** and **0.5 of recall**.

- **Precision: holds.** Spread 8.3 points — 3%, 0%, 8%. `AI-Infra-Guard` is the cleanest arm here.
- **Recall: refuted.** Spread 0.83 — `mantis` 5.00 against `AI-Infra-Guard` 4.17.

## What the two targets say together, and it is the only claim they support

| | precision band | recall band |
|---|---|---|
| `google/mantis` | **outside on `rag-agent`** (19 points) | inside on both |
| `Tencent/AI-Infra-Guard` | inside on both | **outside here** (0.83) |
| **this corpus** | **inside on both** | **inside on both** |

**Each competitor falls outside one band on one target. This corpus falls outside neither, on either.**

That is not a lead on any dimension — on this target `mantis` has better recall than this corpus and `AI-Infra-Guard` has better precision than it. **It is a claim about never being the outlier**, which is the strongest thing two targets and three arms will carry, and it is deliberately weaker than the sentence it replaces.

## Two readings that the first target could not have produced

**`AI-Infra-Guard`'s advantage was domain-bound.** On `rag-agent`, its own home ground, it tied this corpus on precision and matched it on recall. Off that ground it is **last on recall by a margin outside the band**, while still refuting nothing. It is the conservative arm: fewest claims, cleanest claims, most missed defects. That profile is consistent across both targets and is the most reproducible finding in either round.

**`mantis`'s precision deficit was target-specific.** It was 19 points behind on `rag-agent` and is 8 here — inside the band. Its earlier deficit cannot be described as a property of the product, and the round that measured it should be read with this beside it. **Here it found every planted defect in every one of its six runs**, which no other arm did.

## What this does not establish

- **One model scale**, still. Two targets, two competitors, six of the field's products surveyed and **three never run as arms at all**.
- Both targets were authored in this repository. The external-advisory rounds are the counterweight and they live elsewhere.
- Both competitors ran as followed-prompt pipelines, read-only and offline — their floor, not their ceiling.
- 85 claims about 5 defects. Duplication is heavy in every arm and both verifiers said so.
- Both passes recorded real errors *inside* claims they supported: line anchors off by up to seven lines, `DROP TABLE` payloads that a parameterised driver would reject, and `file://` listed as an SSRF target that `node-fetch` 2.7.0 does not support. **Precision as measured here does not see any of that**, in any arm.
- Two claims are `undecidable` in both passes for the same reason: the target exports a bare router with no mounting app, so whether an auth middleware runs genuinely lives outside these files. Neither pass called that a polite `supported`.

## Files

`PREREGISTRATION.md` first, including the sentence that this direction costs `AI-Infra-Guard` its domain advantage and costs this corpus nothing — so a win here means less than it looks and a loss means more. `runs/` holds all seventeen measured artifacts plus the unmeasured one, `verify/` the pooled blinded batch and both passes, `recall/` the blind matching, `keys/` provenance and answer key where no verifier's prompt names them, `prompts/` all twenty-one.
