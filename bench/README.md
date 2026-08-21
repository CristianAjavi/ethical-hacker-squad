# The evaluation bench

Five neighbouring products publish stars. **None of them publishes a number for how much it actually finds** — the competitive analysis checked, and the honest entry in that row is empty for every product in the field, this one included. This directory is the machinery for filling it in.

## The measured result so far

| Run | Detected | Decoys reported | Notes |
|---|---|---|---|
| [2026-08-21, blinded](runs/2026-08-21-blinded/) | 10/10 | **0/11** | Two specialists in fresh contexts; artifacts validated before scoring; two scorer defects found by the run and fixed after it, both disclosed in the run's README |
| [2026-08-21, six packs](runs/2026-08-21-six-packs/) | 32/32 | **0/31** | Six specialists, six packs; six scorer defects found by the run and fixed after it, all six listed with the effect each had on the number |
| [2026-08-21, CI platforms](runs/2026-08-21-ci-platforms/) | 5/5 | **0/5** | One specialist on the case built for the new `INF-19`..`INF-23`; **3/5 and one decoy against the key as authored**, both scores published, all three key defects listed |

Read the second column before the first. Recall on a bench its own authors wrote is a weak signal; a decoy rate of zero on eleven constructs built to be mistaken for the defect beside them is the one that costs something to fake.

## The one that is not ours

| Run | Published advisories in scope | Found blind | Notes |
|---|---|---|---|
| [2026-08-21, external](runs/2026-08-21-external/) | 5, three unrelated projects | **4** | Ground truth from the GitHub Advisory Database and the upstream fix commits; the finding-to-advisory match judged by a context that saw only the advisory text and the finding text. 21 further findings are withheld pending a disclosure decision |

Read this one before the perfect scores below it. The benches measure that the corpus routes and matches on code shaped like the cases; this measures what happened when two specialists were pointed at code nobody here has touched, with a key nobody here wrote.

## What the corpus adds, and how a competitor did on the same two targets

| Advisory | With the corpus | Without it | `google/mantis` |
|---|---|---|---|
| `CVE-2026-53957` | found | found | found |
| `CVE-2026-55090` | found | **missed** | **missed** |

[The three-arm run](runs/2026-08-21-ab-corpus/): same model, same targets, same blind judge; the arms differ only in what the auditor was given — the packs, nothing, or a neighbouring product's own 33 skills followed as written. One tie and one difference, and the run's README says which is which, states the discount the competitor's own rubric applied for a reproduction stage **our** rules forbade, and refuses to call two advisories a ranking.

## Without a pointer

| Run | Target | Advisory in scope | Result |
|---|---|---|---|
| [2026-08-21, whole repository](runs/2026-08-21-whole-repo/) | 286 files, no module named, no hint that anything was wrong | `CVE-2026-53957` | **found**, judged blind |

The external run above it hands the auditor the affected module. This one does not, and it is the answer to the objection that follows from that. It is also one repository and one advisory, with a second target that never produced an artifact — the run's README says both.

## The patch bench

Detection is half the job. The other half is telling a fix from something that looks like one, and it has its own key, its own scorer and its own run:

| Run | Exact | Accepted a patch that does not fix | Notes |
|---|---|---|---|
| [2026-08-21, patches](runs/2026-08-21-patches/) | 6/8 as authored, 8/8 as corrected | **0** | The run corrected the key twice, both corrections argued in the run's README, and the pre-correction score is published beside the corrected one |

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

Anything the cases do not contain: mobile surfaces, remediation and verification, and every class in the corpus that has no case here. <!-- bench:packs -->
Today the bench exercises `web-api`, `local-app`, `infra-cloud`, `supply-chain`, `ai-safety` and `privacy-abuse`, and the score is silent about `mobile` and `remediation` — silent, not clean.
<!-- /bench:packs --> It also says nothing about how the squad behaves under a real repository's size, where the expensive failure is not missing a pattern but never reading the file.

## Growing it

A case is worth adding when it can carry both halves: a real defect and a construct that resists. A case with only planted defects measures nothing but the model's willingness to agree.
