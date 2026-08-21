# Run 2026-08-21 — what the corpus adds, measured

Every number in this directory so far answers "does the squad find things". None of them answers the question a buyer actually asks: **does the corpus do anything, or is the model doing all the work?**

This is an A/B. Same model, same two targets, same output contract, same blind judge. The only difference is what the auditor was given.

| Arm | What it received |
|---|---|
| **treatment** | the packs, `triage.md`, the routing table, the vocabulary — the squad as it ships |
| **control** | the target, the output schema, and one instruction: *you are a senior application security engineer, use your own judgement and your own method* |

## Result

| Advisory | With the corpus | Without it |
|---|---|---|
| `CVE-2026-53957` — LLM-controlled `host`/`proxy` carrying a management token | **found** | **found** |
| `CVE-2026-55090` — stored XSS in HTML export via unescaped attribute values | **found** | **missed** |

Both arms judged by a context that saw only the advisory text and the finding text. The control arm's judgement returned **1 `yes`, 6 `partial`, 4 `no`**, with the judge stating outright that **nothing** in the control arm described the Etherpad defect.

## What each half of that table means

**The MCP case is a tie, and the tie is the honest part.** A senior engineer with no corpus found the same defect, in the same lines, with the same consequence — the judge matched it on the same parameters and the same merge expression. On a small file set with a credential in plain sight, the corpus added nothing measurable. Anyone selling a knowledge pack should be able to say that out loud.

**The Etherpad case is where the difference showed.** The control arm read the same exporter and reported an unbounded list-level loop — plausible, real-looking, and not the advisory. The judge called it *the closest miss*: same file, same function, same attacker-controlled source, **different mechanism**. The corpus arm reported four unescaped sinks in that exporter, one of which was the advisory, because `web-api.md` §6 tells a reader to ask what escaping a value passed through **for the context it lands in**, and to treat an attribute as a different context from a text node. That is a procedure doing what a procedure is for.

## What this is not

- **Two cases.** One tie and one difference is a signal, not a rate. Nothing here supports a percentage.
- **One model.** Both arms are the same model at the same effort. This measures the corpus, not the model, and it says nothing about how a weaker or stronger model would do with the same packs.
- **A comparison against another product.** The control arm is *no corpus*, not a competitor. Running a neighbouring product on the same targets is the next thing this table needs, and it is not here.
- **Blind on both sides, arranged on both sides.** We wrote both prompts. The control prompt was written to be fair — same task, same scope, same output contract, no hints — but we wrote it, and a prompt is an instrument.

## Files

`control-findings-matching-advisory.json` holds the one control finding the judge matched. `judgements-control.json` and `judgements-treatment.json` hold every verdict with its reasoning. `withheld-summary.json` lists the other ten control findings by class and severity only: they are a third party's possible live defects.
