# The evaluation bench

Five neighbouring products publish stars. **None of them publishes a number for how much it actually finds** — the competitive analysis checked, and the honest entry in that row is empty for every product in the field, this one included. This directory is the machinery for filling it in.

## The measured result so far

| Run | Detected | Decoys reported | Notes |
|---|---|---|---|
| [2026-08-21, blinded](runs/2026-08-21-blinded/) | 10/10 | **0/11** | Two specialists in fresh contexts; artifacts validated before scoring; two scorer defects found by the run and fixed after it, both disclosed in the run's README |
| [2026-08-21, six packs](runs/2026-08-21-six-packs/) | 32/32 | **0/31** | Six specialists, six packs; six scorer defects found by the run and fixed after it, all six listed with the effect each had on the number |
| [2026-08-21, CI platforms](runs/2026-08-21-ci-platforms/) | 5/5 | **0/5** | One specialist on the case built for the new `INF-19`..`INF-23`; **3/5 and one decoy against the key as authored**, both scores published, all three key defects listed |
| [2026-08-21, `WEB-23`](runs/2026-08-21-web23/) | 2/2 | **0/2** | The procedure written from the three-arm run's shared miss, measured on a case built for it; the two decoys imitate the finding at the place you first see it |
| [2026-08-21, `WEB-24`/`WEB-25`](runs/2026-08-21-authz/) | 2/2 | **0/2** | The two procedures written from the second round's shared misses; both decoys imitate the finding exactly where a reader meets it, and separating them needs the exculpation clause rather than the pattern |
| [2026-08-21, `WEB-26`](runs/2026-08-21-web26/) | 2/2 | **0/2** | Written from the whole-repository loss. The decoys are a correctly bounded twin and one that looks unguarded but is capped by its own field width; the distinction the procedure turns on is **a cast guard versus a limit** |

Read the second column before the first. Recall on a bench its own authors wrote is a weak signal; a decoy rate of zero on eleven constructs built to be mistaken for the defect beside them is the one that costs something to fake.

## The one that is not ours

| Run | Published advisories in scope | Found blind | Notes |
|---|---|---|---|
| [2026-08-21, external](runs/2026-08-21-external/) | 5, three unrelated projects | **4** | Ground truth from the GitHub Advisory Database and the upstream fix commits; the finding-to-advisory match judged by a context that saw only the advisory text and the finding text. 21 further findings are withheld pending a disclosure decision |

Read this one before the perfect scores below it. The benches measure that the corpus routes and matches on code shaped like the cases; this measures what happened when two specialists were pointed at code nobody here has touched, with a key nobody here wrote.

## The corpus makes a weaker model worse, and that is measured

[2026-08-21, weaker model](runs/2026-08-21-weaker-model/) — same target, same prompts verbatim, same blind judging, Haiku 4.5 instead of the frontier model every other round used. Ground truth is the two defects **every** frontier run in **both** arms found every time.

| Arm | D1 | D2 | total |
|---|---|---|---|
| with the corpus | 2/3 runs | **0/3 runs** | **2 / 6** |
| without it | 2/3 runs | 3/3 runs | **5 / 6** |

The pre-registration predicted the opposite and named what would refute it. The corpus arm spent roughly twice the budget (95k-111k tokens against 48k-66k) to produce a fifth of the output, and two of its three artifacts failed the coverage invariant on the very files the run had just read. **A context tax, not a transfer of expertise** — and the last untested hypothesis for the corpus's value, tested and dead.

**A second change was made and did NOT work, and the validator is what caught it.** Making a dismissal expensive — `refuted` must name the line of the control — was pre-registered, and its prediction (D1 back to 2/3, total ≥4/6) came out exactly right. It supports nothing: **all three runs failed validation because not one wrote the new field.** The rule was in the schema, the validator, `team.md` and all seven subagents, and the reviewer declined it; one run refuted D1 again with the same bad argument. A confirmed prediction whose intervention never ran is noise, and without the machine check it would have shipped as a second win. **A rule that only a validator enforces is a rule the reviewer can decline** — the loading rule changed what the reviewer does *first* and moved the number; the dismissal rule changed what it writes *last* and did not.

**The first fix, though, worked.** A loading rule — *read the target before you read this corpus, and stop loading before the code stops fitting* — took the corpus arm from **2/6 to 4/6**, with D2 going from zero of three runs to three of three. Nothing else changed and the unaided arm was not re-run. It is still one defect behind 5/6, which is inside this bench's resolution: the rule moved the weak-model result from **measurably harmful to indistinguishable**, not to good. And D1 fell from 2/3 to 1/3, with two runs *actively ruling it out* — a reviewer on a short budget produces confident refutations, which is worse than silence and is the next thing to measure.

**And the counterweight turned out to be the story.** [The weak unaided arm's 28 claims were verified adversarially, twice](runs/2026-08-21-weak-precision/): **19 refuted by both passes, 4 supported — and those 4 are D1 and D2 themselves.** Beyond the two defects the ground truth already names, that arm produced nothing that survived being attacked: the code read backwards, a premise inverted by a strict `<`, three claims needing a scale outside the range a `readUnsignedByte()` can return, and a missing log line. **The recall comparison was substantially measuring output volume.**

**[Then the corpus arm was verified too, and it is not more precise either.](runs/2026-08-21-corpus-precision/)** Pooling nine weak runs gave 26 claims against the 28 already done; same verifier prompt byte for byte, two adversarial passes each. **62% refuted against 68% — six points, where the pre-registration required more than ten.** And the finding underneath is bigger than the comparison: **every claim that survived, in either arm, is one of the two ground-truth defects.** Across twelve weak runs and 54 claims, neither arm produced a single true finding beyond the two already named. One asymmetry did appear and is recorded as an observation rather than a result: inter-pass agreement was 26/26 on the corpus arm's claims against 25/28 on the unaided arm's, which 26-versus-28 claims cannot settle. What is now measured is that **both arms make confident wrong statements on a weak model**: the unaided arm as findings, the corpus arm as refutations of a real defect. Which failure a reader would rather receive is unanswered.

## The number that governs every other number in this file

The unaided arm was measured at **0.81** agreement in one sitting and **0.60** in the next — same arm, same target, same blind instrument, same judging rule, and a run prompt rewritten because the first one was never stored. **Twenty-one points, from the prompt alone.**

That is larger than any corpus-versus-no-corpus difference this bench has ever produced. So: **a comparison whose prompt was not archived cannot be compared to a comparison from another sitting.** [The 2026-08-21 unaided-pass round](runs/2026-08-21-unaided-pass/) archives every prompt it used under `prompts/`. The rounds published before it do not, and each now says so in its own file. Read within-sitting differences; distrust across-sitting ones.

## Consistency: measured twice, and the corpus does not lead either time

A run measured whether two independent reviews of the same target agree with each other — the property a written procedure should confer by construction, and the one dimension left after capability came back at parity everywhere. Two numbers were published and retracted before a third instrument settled it: a classifier written here to reduce findings to the defect they are about mis-bins findings a reader bins correctly at a glance, and a rewrite of it reversed the answer and was equally broken. **[Judged blind instead](runs/2026-08-21-consistency/) — every pair of findings across two runs, decided by a context that knows neither the arm nor the run — the corpus arm scores 0.68 and the unaided arm 0.81.** The corpus is the less consistent of the two, on the one dimension it was built to win.

| Round | with the corpus | without it | prompts archived |
|---|---|---|---|
| [first](runs/2026-08-21-consistency/) — blind judging, after two retracted classifier numbers | 0.68 | **0.81** | no |
| [second](runs/2026-08-21-unaided-pass/) — both arms re-run in one sitting, after the corpus was changed | 0.55 | **0.60** | **yes** |

The second round is the one to read, because it is the only one whose two arms were measured under the same conditions. Its five-point gap is this bench's own stated resolution, so it says the arms are **indistinguishable**, not that one wins. The first round's thirteen-point gap is not comparable to it and the two must not be averaged.

The second round also **refuted a registered prediction of ours.** `engagement.unaided_pass` was added to stop the corpus substituting for the reviewer's own judgement; the pre-registration said the corpus arm's agreement should rise and reach the unaided arm's. It did not. What did change is the output: the corpus arm reported 4-6 findings per run before the change and 7-10 after, against the unaided arm's 7-9, so the half-the-output gap that ran through every earlier measurement is gone.

All six runs, both arms, report the same two main defects every time; what separates them is the tail. The corpus arm's three runs share four defects and each adds a *different* fifth or sixth, while the unaided arm's eight pair one-to-one on identical line anchors. Caveats in the table rather than in a footnote: one target, three runs per arm, agreement is easier over a smaller set (4–6 findings against 9–10), and agreement is not quality.

## What the corpus adds — and where it adds nothing

Two runs, and they do not agree. Read them together or not at all.

| Advisory | Case chosen by | With the corpus | Without it | `google/mantis` |
|---|---|---|---|---|
| `CVE-2026-53957` | us | found | found | found |
| `CVE-2026-55090` | us | **found** | missed | missed |
| `CVE-2026-55149` | a published rule | found | found | found |
| `CVE-2026-53657` | a published rule | found | found | found |
| `CVE-2026-64868` | a published rule | **missed** | missed | missed |

[The two-case A/B](runs/2026-08-21-ab-corpus/) found one advisory the other two arms missed. Then two rounds on targets a **published rule** selected, six advisories in two ecosystems and four projects:

| | Corpus | No corpus | Competitor |
|---|---|---|---|
| [round 1](runs/2026-08-21-three-arm-go/) — Go | 2/3 | 2/3 | 2/3 |
| [round 2](runs/2026-08-21-round2/) — Python, in the classes this corpus is strongest at | 1/3 | 1/3 | 1/3 |
| [round 3](runs/2026-08-21-round3/) — Java | 3/3 | 3/3 | 3/3 |
| **total** | **6 / 9** | **6 / 9** | **6 / 9** |

**Nine advisories chosen by a published rule, in three ecosystems and five projects. The three arms are identical.** Not one advisory separates them.

And [precision does not separate them either](runs/2026-08-21-precision/): all 53 findings from round 3 that match no advisory were verified twice, adversarially, against the code — **nothing was refuted by both passes**. The corpus arm's smaller output (7 claims where the others had 20 and 26) is *selection, not accuracy*: what the other arms report on top is true. The one thing that is measurably different is that its artifact has somewhere to say **I could not decide this**, and theirs does not.

Round 3 briefly read **3/3 against 2/3**, and that result was published and then withdrawn the same day. It came from judging two arms in one batch and the third in another; re-judged with all three in one context, the verdict on the disputed finding moved from `partial` to `yes` and the separation disappeared. [The run's README](runs/2026-08-21-round3/) carries the correction, both judgements, and the rule that follows from it: **a separation of one advisory is inside the noise of this instrument**, and every arm for one advisory is judged in one context, always.

Every round was pre-registered before its numbers existed, including round 2's *"if the corpus does not lead here, it does not lead where it is best"* and round 3's *"if the round ties again, that is three rounds of parity and the honest reading is that the corpus does not lead"*.

Both rule-picked rounds ended level **and** produced procedures from what every arm missed: `WEB-23` from the first, [`WEB-24` and `WEB-25`](runs/2026-08-21-authz/) from the second. Whether that compounds into a lead is an empirical question with two data points and no answer — the round that would settle it has not been run.

The miss all three arms share is the most useful thing either run produced: a configured limit with no enforcer — `MaxRequestBodyMB` declared, assigned from the environment, and read by nothing — which nobody thought to check. It is now `WEB-23`, with a case, two decoys and [a measurement](runs/2026-08-21-web23/): 2 of 2 on the fresh construct, 0 decoys, and the advisory found on a second pass over the same target. **That second number does not amend the tie above.** The procedure was written from that case, so finding it again shows the lesson was encoded, not that it generalises — and the three-arm table stands exactly as it was measured.

## Without a pointer — and this is where the corpus loses

| Run | Target | Advisories | With the corpus | Without it |
|---|---|---|---|---|
| [2026-08-21, whole repository, one arm](runs/2026-08-21-whole-repo/) | 286 files, no module named | `CVE-2026-53957` | **found** | not run |
| [2026-08-21, whole repository, three arms](runs/2026-08-21-whole-repo-3arm/) | 461 files, 409 Java | two at once | **0 / 2** | **1 / 2** |
| [2026-08-21, a second whole repository](runs/2026-08-21-whole-repo-2/) | 6,490 files, 3,954 TypeScript | one | **0 / 1** | **0 / 1** |
| | | **total** | **0 / 3** | **1 / 3** |

**The headline is the zero, not the gap.** Whole-repository recall against a *specific published defect* is near zero for both methods: three advisories, two methods, one hit between them, and a 1–0 difference that sits inside this bench's own resolution of five in fifty-three. On a repository nobody can read in full, landing on the one file a CVE names is close to a lottery — both arms opened 45–50 files out of thousands and both produced substantial, largely accurate findings about other things.

That is the strongest argument here for what a **coverage declaration** is worth: if recall against a named defect is near zero, what a reader can rely on is knowing what was looked at and what was not.

**And that argument was then measured too, on [the only objective version of it](runs/2026-08-21-reader/): how many areas of the repository a reader can account for using the document alone, with a verbatim quotation required for every answer. With the corpus, 8 of 10. Without it, 9 of 10.** The corpus's report was not easier to act on. What the reader did single out, unprompted, was one sentence — *"the absence of an IDOR finding here means nobody looked"* — while pointing out that the same report never resolved the SQL layer it had inventoried. The differentiator is real and was executed in one place and dropped in another.

The file-subset rounds are saturated: every arm finds the same advisories, and nothing is refuted. So the second run above changed the task to the one a written method is actually for — routing across a repository nobody can read in full — and **the corpus arm lost**: the unaided engineer found an advisory it did not.

Routing was not the failure. Both arms read a comparable slice, and the corpus arm **had the right file open** and reported the neighbouring defect in it. The class it missed had been declared uncovered *by one of our own arms, in writing, earlier the same day*, and the write-up was deliberately deferred so it could not contaminate a round then in flight. This run is the cost of that decision, paid in the open.

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
