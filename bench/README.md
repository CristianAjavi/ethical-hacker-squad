# The evaluation bench

Five neighbouring products publish stars. **None of them publishes a number for how much it actually finds** — the competitive analysis checked, and the honest entry in that row is empty for every product in the field, this one included. This directory is the machinery for filling it in.

## What is here

| Path | What it is |
|---|---|
| `cases/` | Small targets written to be **read**, not run. Each contains planted defects and, deliberately, constructs that look like defects and are ruled out. |
| `ground-truth.json` | The answer key: what was planted, which procedure should catch it, which decoys exist and which triage rule rules each one out. |
| `../scripts/bench/score.py` | Scores a `findings.json` against the key. |
| `../scripts/gates/gate-bench-integrity.sh` | Checks the bench itself: a rotting answer key produces confident nonsense. |

## The protocol, and the one rule that makes a run mean anything

**The auditing context must never read `ground-truth.json`.** An agent that has seen the key is not measuring detection, it is transcribing. This is why the run is a *fresh* context — the plugin's own subagents, or a session that was pointed only at `bench/cases/<name>` — and why the key lives in a file the case directories do not reference.

```
1. Point a fresh squad at bench/cases/<case>, in audit mode, with no other context.
2. Have it emit findings.json per references/findings-artifact.md.
3. Validate it:  scripts/gates/gate-findings-artifact.sh --deliverable findings.json
4. Score it:     python3 scripts/bench/score.py --findings findings.json
```

Step 3 before step 4 on purpose: a malformed artifact scored anyway would report a low recall that is really a formatting bug.

## What the numbers are worth

**Recall here is recall on this bench.** The cases were written by the same project that wrote the procedures, so a high score partly measures that the corpus describes the code it was written from. That is not nothing — it proves the routing and the patterns hold on code shaped like this — but it is not evidence about code nobody here has seen. Say "recall on the bench", never "detection rate".

**The decoys are the part that resists self-flattery.** Every construct in the decoy list looks like a finding and is ruled out by a named triage rule. Reporting one is a false positive with an id, a location and the rule that should have caught it — this repository's first-class defect, measured instead of asserted. A bench author cannot make decoys easy without making them useless, because the decoy list is published next to the score.

**Unlabelled findings are not counted against a run.** The bench does not claim to have planted everything a case contains. A finding that matches nothing in the key is reported separately and is worth reading: it is either a real defect the key missed, or a false positive the key cannot name yet. Both are follow-up work, not a number.

## What it cannot measure

Anything the cases do not contain: infrastructure, mobile, agent runtimes, supply chain, privacy surfaces, and every class in the corpus that has no case here. Today the bench exercises `web-api` and `local-app` only, and the score is silent about the other six packs — silent, not clean. It also says nothing about how the squad behaves under a real repository's size, where the expensive failure is not missing a pattern but never reading the file.

## Growing it

A case is worth adding when it can carry both halves: a real defect and a construct that resists. A case with only planted defects measures nothing but the model's willingness to agree.
