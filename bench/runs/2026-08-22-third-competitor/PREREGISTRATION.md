# Pre-registration — the third arm, and why the other two cannot be arms at all

Committed before the new arm runs.

## The caveat this closes, and it closes it in two different ways

Every competitive round so far ends with the same line: *three of the six surveyed products have never been run as arms at all.* Left there, it reads as unfinished work. It is partly unfinished work and partly a category error, and this round separates the two.

All three were cloned at pinned commits and classified by what they actually do:

| product | source-audit language | live-target language | verdict |
|---|---|---|---|
| `0xSteph/pentest-ai-agents` @ `e5d7aa0` | 53 | 30 | **runnable as an arm** — 50 Claude Code subagents including `agents/code-auditor.md` and `agents/web-hunter.md` |
| `vxcontrol/pentagi` @ `ea66530` | 52 | 82 | **not runnable here** — an autonomous platform driving live targets through `docker compose` with its own key material |
| `msoedov/agentic_security` @ `1ef1314` | **0** | 14 | **not comparable at all** — an LLM/agent-workflow *fuzzer* that sends jailbreak payloads at a running endpoint. It does not read source code |

**`agentic_security` is not a slow arm, it is a different instrument.** Running it against a static bench case and reporting a number would be measuring a fuzzer's ability to do something it does not claim to do, and any figure from it would flatter this project by construction. It is scored as *not applicable*, and that is the honest retirement of a third of the caveat.

## The new arm

`0xSteph/pentest-ai-agents` @ `e5d7aa0`, followed as written, nothing copied. Its `code-auditor` and `web-hunter` subagent definitions are the counterpart to this corpus's specialists, and the target — an ordinary Node HTTP API — is squarely what `web-hunter` is for.

**Its `code-auditor` definition asks for `model: sonnet`, and it is being run on `claude-haiku-4-5` anyway** — the scale every other arm was measured at. Matching the scale and following the spec are in direct conflict here and comparability wins, but this is a handicap against the product's own written intent and is declared as one rather than buried: like read-only and offline, it is this arm's floor and not its ceiling. `mantis` and `AI-Infra-Guard` name no model, so neither carries this.

Six runs, `claude-haiku-4-5`, target `bench/cases/express-invoices` unchanged, **all four arms re-pooled into one blinded batch and re-judged from scratch**, two independent adversarial passes plus the blind defect-matching judge. No number is carried over.

## Prediction

**The new arm lands inside both bands** — within 10 points of refuted-by-both of the other three, and within 0.5 defects of mean recall of the nearest arm. This bench has now measured three products and the same reading keeps arriving: at this scale these differences are the model's, not the products'.

**Specifically, and against this project: at least one of the four arms beats this corpus on precision**, as `AI-Infra-Guard` already does on this target.

## What refutes it

- **The new arm outside either band.** Then products do differ at this scale and the "it is the model" reading weakens.
- **This corpus alone at the top of both dimensions.** That has not happened once tonight and would be the first evidence for a lead rather than for consistency.

## What each outcome forces

- **Prediction holds.** The published claim stays *never the outlier* and gains its proper denominator: **three of the four comparable products measured, the fourth structurally out of scope, on two targets at one model scale.** The caveat stops being a debt and becomes a stated boundary.
- **The new arm falls outside a band.** Then this corpus is one of two arms that never does, not one of one, and the claim is re-counted rather than re-worded.
- **This corpus falls outside a band for the first time.** Then *never the outlier* dies with the round that produced it, and `README.md` loses its last capability sentence.

## Declared weaknesses, unchanged

One model scale. Both targets authored in this repository. Every competitor run as a followed-prompt pipeline, read-only and offline — their floor, not their ceiling. The verifier and the critic remain the same kind of instrument for all arms.
