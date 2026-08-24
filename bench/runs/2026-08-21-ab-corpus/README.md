# Run 2026-08-21 — what the corpus adds, measured against nothing and against a competitor


> **The run prompts for this round were not kept.** A later round measured the same unaided arm on the same target with the same blind instrument and a freshly written prompt, and scored 0.60 where this family of rounds scored 0.81 — twenty-one points from the prompt alone. **The numbers below are internally valid and are not comparable to numbers from another sitting.** See `../2026-08-21-unaided-pass/`, which archives every prompt it used.


> **Outside information was not settled in this round.** No prompt in this bench said whether consulting sources beyond the target — an advisory database, an upstream branch, a diff against another version — was allowed, and later rounds found that some runs did consult them. **Any recall number here measures review and library familiarity together and cannot separate them.** Consistency comparisons are unaffected: they compare runs of one arm, which had the same latitude. `../../prompts/external-sources.txt` is the clause that closes this for later rounds; it did not exist when this one ran.

Every number in this directory so far answers "does the squad find things". None of them answers the question a buyer actually asks: **does the corpus do anything, or is the model doing all the work — and does a neighbouring product do it better?**

Three arms, same two targets, same output contract, same blind judge.

| Arm | What it received |
|---|---|
| **treatment** | the packs, `triage.md`, the routing table, the vocabulary — the squad as it ships |
| **control** | the target, the output schema, and one instruction: *you are a senior application security engineer, use your own judgement and your own method* |
| **competitor** | [`google/mantis`](https://github.com/google/mantis) at `5f76be0`, Apache-2.0 — 33 skills, run by following its own pipeline, with nothing from it copied into this repository. Provenance in `competitor-provenance.json` |

## Result

| Advisory | With the corpus | Without it | Competitor |
|---|---|---|---|
| `CVE-2026-53957` — LLM-controlled `host`/`proxy` carrying a management token | **found** | **found** | **found** |
| `CVE-2026-55090` — stored XSS in HTML export via unescaped attribute values | **found** | **missed** | **missed** |

All three arms judged by a context that saw only the advisory text and the finding text, with no idea which arm produced which finding. The control arm's judgement returned **1 `yes`, 6 `partial`, 4 `no`**; the competitor's, over nineteen findings, returned **2 `yes`, 11 `partial`, 6 `no`** — both `yes` on the MCP advisory, from the export and the import path of the same defect.

## The competitor arm, and what it is fair to conclude from it

**On the MCP target it found the defect, in both files, and named the mechanism exactly.** Its pipeline is serious: an architecture pass, a threat model, a plan, parallel research trajectories with deliberately different lenses, a dedupe stage, a negative-constraint review that killed 2 of 13 candidates, a critic and a 27-rule calibration. 11 findings survived on MCP, 8 on the exporter.

**On the exporter it missed, and the way it missed is the interesting part.** Its closest finding is in the same file, the same function family, the same bug class and the same consequence — an unescaped author-derived value reaching the exported HTML — but at `class="` rather than at the plugin-hook `data-` attribute the advisory names, and its own report says the escaping helper exists 109 lines away and simply is not applied there. The judge called it a different source and a different sink. Then its rubric rated that finding **LOW, 2.0/10**, after stacking four discounts, one of which is *no reproduction evidence* — and reproduction is a stage of its pipeline that **our engagement rules forbade**, because the target is a file subset with no build. That discount is our constraint showing up in their score, and it is only fair to say so.

**What this does not license.** It is one product, at one commit, on two advisories, driven by an agent that had never used it before, with a prompt we wrote. It is not a benchmark of that product, and it is not evidence that this corpus beats it in general. What the table supports is narrower and still worth having: on the one case where a corpus procedure did the work — `web-api.md` §6, asking what escaping a value gets *for the context it lands in* and treating an attribute as a different context from a text node — neither an unaided senior engineer nor a competing pipeline reached the same sink.

## What each half of that table means

**The MCP case is a tie, and the tie is the honest part.** A senior engineer with no corpus found the same defect, in the same lines, with the same consequence — the judge matched it on the same parameters and the same merge expression. On a small file set with a credential in plain sight, the corpus added nothing measurable. Anyone selling a knowledge pack should be able to say that out loud.

**The Etherpad case is where the difference showed.** The control arm read the same exporter and reported an unbounded list-level loop — plausible, real-looking, and not the advisory. The judge called it *the closest miss*: same file, same function, same attacker-controlled source, **different mechanism**. The corpus arm reported four unescaped sinks in that exporter, one of which was the advisory, because `web-api.md` §6 tells a reader to ask what escaping a value passed through **for the context it lands in**, and to treat an attribute as a different context from a text node. That is a procedure doing what a procedure is for.

## This result did not generalise, and the run that showed it is next door

Three further advisories, picked by a published rule instead of by us, were put through the same three arms with the same blind protocol: `../2026-08-21-three-arm-go/`. **Every arm scored 2 of 3, finding the same two and missing the same one.** No difference between the corpus, an unaided senior engineer, and the competitor.

So the Etherpad row below is real and reproducible from the artifacts in this directory, and it is also the only case in five where the corpus pulled ahead. Read the two runs together: on cases this project wrote or chose, the corpus shows a difference; on cases a rule chose, it does not.

## What this is not

- **Two cases.** One tie and one difference is a signal, not a rate. Nothing here supports a percentage.
- **One model.** Both arms are the same model at the same effort. This measures the corpus, not the model, and it says nothing about how a weaker or stronger model would do with the same packs.
- **A benchmark of the competitor.** One product, one commit, two advisories, our prompt, and a pipeline missing the reproduction stage its own rubric expects. It is one honest data point, not a ranking.
- **Blind on both sides, arranged on both sides.** We wrote both prompts. The control prompt was written to be fair — same task, same scope, same output contract, no hints — but we wrote it, and a prompt is an instrument.

## Files

`control-findings-matching-advisory.json` holds the one control finding the judge matched. `judgements-control.json`, `judgements-treatment.json` and `judgements-competitor.json` hold every verdict with its reasoning. `findings-competitor-mcp.json` and `findings-competitor-etherpad.json` are the competitor's own findings, transcribed by `adapt-competitor-findings.py`, whose two conversion decisions are both made in its favour and stated in the file. `competitor-provenance.json` records what was fetched and how it was run. `withheld-summary.json` lists the 27 findings across all three arms that match no published advisory — class and severity only, no mechanism: they are a third party's possible live defects, and publishing how they work would be disclosure by us.
