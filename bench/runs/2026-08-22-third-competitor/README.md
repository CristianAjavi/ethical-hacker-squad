# Run 2026-08-22 — four arms, and the field's three comparable products each fall outside a band

| Arm | claims | refuted by **both** passes | ground-truth recall |
|---|---|---|---|
| `Tencent/AI-Infra-Guard` @ `4908db1` | 25 | **0 (0%)** | **4.17 / 5** |
| **this corpus** | 30 | 1 (3%) | 4.83 / 5 |
| `google/mantis` @ `5f76be0` | 36 | 3 (8%) | **5.00 / 5** |
| `0xSteph/pentest-ai-agents` @ `e5d7aa0` | 43 | **7 (16%)** | **5.00 / 5** |

Target `bench/cases/express-invoices`, six runs per arm, `claude-haiku-4-5`, **all 134 claims from all four arms re-pooled into one blinded batch and re-judged from scratch** — no number carried over. **Inter-pass agreement 132/134 (99%).**

## The prediction is refuted, and the half that bet against this project holds

It predicted the new arm **inside both bands**, and — explicitly against this project — that **at least one of the four arms would beat this corpus on precision**.

- **Bands: refuted.** Precision spread **16.3 points**, well outside 10, and the new arm is the outlier. Recall spread 0.83, outside 0.5, with `AI-Infra-Guard` the outlier as before.
- **The bet against us: holds.** `AI-Infra-Guard` refutes **nothing** at all here, against this corpus's one claim. **It is the more precise arm and this corpus is not the most precise product measured.**

**This corpus leads nothing.** Two arms out-recall it, one out-precisions it.

## What four arms and two targets support

| | precision band | recall band |
|---|---|---|
| `google/mantis` | **outside** on the AI-agent target (19 pts) | inside on both |
| `Tencent/AI-Infra-Guard` | inside on both | **outside** here (0.83) |
| `0xSteph/pentest-ai-agents` | **outside** here (16.3 pts) | inside |
| **this corpus** | **inside on both** | **inside on both** |

**Each of the field's three comparable products falls outside a band somewhere. This corpus falls outside none.** The denominator is no longer one competitor, and the claim is the same one it was: **not a lead, an absence of outliers.**

## The caveat about the other two products is retired, and half of it was a category error

All three previously-unrun products were cloned at pinned commits and classified by what they do:

| product | source-audit language | live-target language | verdict |
|---|---|---|---|
| `0xSteph/pentest-ai-agents` | 53 | 30 | **run here** — 50 Claude Code subagents; `agents/code-auditor.md` states *"Reviews source at rest"* |
| `vxcontrol/pentagi` | 52 | 82 | **not runnable in this environment** — an autonomous platform driving live targets through `docker compose` |
| `msoedov/agentic_security` | **0** | 14 | **not comparable at all** — an LLM/agent-workflow *fuzzer* firing jailbreak payloads at a running endpoint |

**`agentic_security` is not a slow arm, it is a different instrument.** It has no source-audit language anywhere. Running it against a static bench case and publishing a number would measure its ability to do something it never claimed to do, and that number would flatter this project by construction. It is scored **not applicable**.

So the honest denominator is now **three of the four comparable products measured; the fourth is out of scope for what it is; one more needs infrastructure this environment does not have.**

## The handicap this round carries, declared before it ran

The new arm's `code-auditor` asks for `model: sonnet`. It was run on `claude-haiku-4-5` to match the scale every other arm was measured at. **Matching the scale and following the spec were in direct conflict and comparability won**, so its 16% is measured against its own written intent as much as against the other arms. `mantis` and `AI-Infra-Guard` name no model and carry nothing comparable. This is its floor, like read-only and offline, and it was written down in `PREREGISTRATION.md` before the first run rather than explained afterwards.

## What this does not establish

- **One model scale, one target for three of the four arms.** Only this corpus and the two earlier competitors have two targets.
- 134 claims about **five** defects. Duplication is heavy in every arm and both passes said so.
- Both targets were authored in this repository.
- Every competitor ran as a followed-prompt pipeline, read-only and offline — each one's floor.
- Both passes let real errors stand inside claims they supported, in every arm: `;DROP TABLE` payloads that `$n` placeholders reject, `file://` as an SSRF target `node-fetch` v2 does not support, and line citations off by several lines. **Precision as measured here sees none of that.**
- Six claims are `undecidable` in both passes on the same ground — the target exports a bare router with no mounting app, so whether authentication middleware runs genuinely lives outside these files. Neither pass treated that as a polite `supported`.

## Files

`PREREGISTRATION.md` first, with the classification of all three products, the prediction that bet against this project, and the model handicap declared before the run. `runs/` holds the new arm's six artifacts; the other eighteen are in `../2026-08-22-second-target/runs/`. `verify/` holds the four-arm blinded batch and both fresh passes, `recall/` the fresh blind matching, `keys/` provenance and answer key where no verifier's prompt names them, `prompts/` all nine.
