# The evaluation bench

Five neighbouring products publish stars. **None of them publishes a number for how much it actually finds** — the competitive analysis checked, and the honest entry in that row is empty for every product in the field, this one included. This directory is the machinery for filling it in.

## The measured result so far

| Run | Detected | Decoys reported | Notes |
|---|---|---|---|
| [2026-08-21, blinded](runs/2026-08-21-blinded/) | 10/10 | **0/11** | Two specialists in fresh contexts; artifacts validated before scoring; two scorer defects found by the run and fixed after it, both disclosed in the run's README |
| [2026-08-21, six packs](runs/2026-08-21-six-packs/) | 32/32 | **0/31** | Six specialists, six packs; six scorer defects found by the run and fixed after it, all six listed with the effect each had on the number |
| [2026-08-21, CI platforms](runs/2026-08-21-ci-platforms/) | 5/5 | **0/5** | One specialist on the case built for the new `INF-19`..`INF-23`; **3/5 and one decoy against the key as authored**, both scores published, all three key defects listed |
| [2026-08-21, `WEB-23`](runs/2026-08-21-web23/) | 2/2 | **0/2** | The procedure written from the three-arm run's shared miss, measured on a case built for it; the two decoys imitate the finding at the place you first see it |

Read the second column before the first. Recall on a bench its own authors wrote is a weak signal; a decoy rate of zero on eleven constructs built to be mistaken for the defect beside them is the one that costs something to fake.

## The one that is not ours

| Run | Published advisories in scope | Found blind | Notes |
|---|---|---|---|
| [2026-08-21, external](runs/2026-08-21-external/) | 5, three unrelated projects | **4** | Ground truth from the GitHub Advisory Database and the upstream fix commits; the finding-to-advisory match judged by a context that saw only the advisory text and the finding text. 21 further findings are withheld pending a disclosure decision |

Read this one before the perfect scores below it. The benches measure that the corpus routes and matches on code shaped like the cases; this measures what happened when two specialists were pointed at code nobody here has touched, with a key nobody here wrote.

## What the corpus adds — and where it adds nothing

Two runs, and they do not agree. Read them together or not at all.

| Advisory | Case chosen by | With the corpus | Without it | `google/mantis` |
|---|---|---|---|---|
| `CVE-2026-53957` | us | found | found | found |
| `CVE-2026-55090` | us | **found** | missed | missed |
| `CVE-2026-55149` | a published rule | found | found | found |
| `CVE-2026-53657` | a published rule | found | found | found |
| `CVE-2026-64868` | a published rule | **missed** | missed | missed |

[The two-case A/B](runs/2026-08-21-ab-corpus/) found one advisory the other two arms missed. [The three-case run on rule-picked targets](runs/2026-08-21-three-arm-go/) found **no difference at all**: 2 of 3 for every arm, the same two found, the same one missed.

**The honest reading is the second one.** On cases this project chose, the corpus shows a difference; on cases a published rule chose, it does not. Anyone weighing this product should assume parity with a competent engineer until a larger rule-picked sample says otherwise, and the run that would say so does not exist yet.

The miss all three arms share is the most useful thing either run produced: a configured limit with no enforcer — `MaxRequestBodyMB` declared, assigned from the environment, and read by nothing — which nobody thought to check. It is now `WEB-23`, with a case, two decoys and [a measurement](runs/2026-08-21-web23/): 2 of 2 on the fresh construct, 0 decoys, and the advisory found on a second pass over the same target. **That second number does not amend the tie above.** The procedure was written from that case, so finding it again shows the lesson was encoded, not that it generalises — and the three-arm table stands exactly as it was measured.

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
2. Have it emit findings.json per references/findings-artifact.md, WRITING THE FILE
   AS SOON AS IT HAS ONE FINDING and rewriting it after each one.
3. Validate it:  scripts/gates/gate-findings-artifact.sh --deliverable findings.json
4. Score it:     python3 scripts/bench/score.py --findings findings.json
```

Step 3 before step 4 on purpose: a malformed artifact scored anyway would report a low recall that is really a formatting bug.

**Step 2's capital letters are paid for.** Eleven blinded runs in this bench's history have been killed mid-flight — the host sleeping, a stream watchdog giving up — and the ones that died between finishing the analysis and writing the file produced nothing at all, while the ones that had already written a partial artifact lost only the polish. An analysis nobody can read scores zero, and it scores zero in a way that looks like a low recall rather than like a lost run. Tell the auditor to write first and save often, in the prompt, every time.

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
