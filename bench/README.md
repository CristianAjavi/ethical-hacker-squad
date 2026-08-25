# The evaluation bench

Five neighbouring products publish stars. **None of them publishes a number for how much it actually finds** — the competitive analysis checked, and the honest entry in that row is empty for every product in the field, this one included. This directory is the machinery for filling it in.

## The triage stage, run and unmeasured

[2026-08-24, triage stage](runs/2026-08-24-triage-stage/) — twelve runs, six per arm,
against a pre-registration written before the first model call. **The primary metric could
not measure**: over-affirmation was defined as answering `HOLDS` where nothing could be
established, and that happened zero times in both arms. The pre-registration's own rule for
a ceiling was followed and no difference is reported. What the round did establish is a
hole in the metric — `HOLDS` is one of two ways to conclude past the evidence, and the
other one is what both arms actually did.

## Reproduction

Five of the planted defects now carry an executable probe, and the probes are cross-checked
against both keys this corpus holds — see [reproduction/](reproduction/). Ten of the 43
planted defects are reproducible without installing anything; five ship today. A green
there is five defects proved, not a bench reproduced.

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

**And then it was fixed, by reading the competitor instead of guessing.** The diagnosis behind the failed attempt — that `mantis` must have a critic calibrated to let things live — was wrong: its stage is *harsher* than ours. What it does differently is judge the claim and the code only, **discarding the finder's prose as potentially hallucinated**. With the critic blind to the prose, on the same target, model and instruments: **ground-truth recall 6/6 and nothing refuted by two adversarial passes**, against v1's 3/6 and 33%. First change in this sequence to pass its pre-registered test on both metrics, and it shipped only after passing.

**Then it was compared at comparable N, because 6 claims against 17 is not a comparison** — this bench refused that arithmetic and ran six more times instead. Pooled over nine runs: **19 claims, 21% refuted by both passes, recall 14/18**, against the competitor's 17 claims and 53%. All three pre-registered criteria hold, and **on precision at weak scale this corpus is ahead of the strongest published competitor** — one dimension, one scale, one target.

Three asymmetries travel with it, declared before the number was known: our 19 claims come from nine runs against their 17 from three; our 19 collapse into **three** distinct assertions against their nine, so our deduplication is markedly worse and inflates our own denominator; and the critic and the grader are the same kind of instrument for both arms. That round also **corrected its own predecessor**: v2's headline 6/6 recall over three runs is 14/18 over nine.

**The failed attempt, kept because it is the reason the passing one is trustworthy.** Making a dismissal expensive — `refuted` must name the line of the control — was pre-registered, and its prediction (D1 back to 2/3, total ≥4/6) came out exactly right. It supports nothing: **all three runs failed validation because not one wrote the new field.** The rule was in the schema, the validator, `team.md` and all seven subagents, and the reviewer declined it; one run refuted D1 again with the same bad argument. A confirmed prediction whose intervention never ran is noise, and without the machine check it would have shipped as a second win. **A rule that only a validator enforces is a rule the reviewer can decline** — the loading rule changed what the reviewer does *first* and moved the number; the dismissal rule changed what it writes *last* and did not.

**The first fix, though, worked.** A loading rule — *read the target before you read this corpus, and stop loading before the code stops fitting* — took the corpus arm from **2/6 to 4/6**, with D2 going from zero of three runs to three of three. Nothing else changed and the unaided arm was not re-run. It is still one defect behind 5/6, which is inside this bench's resolution: the rule moved the weak-model result from **measurably harmful to indistinguishable**, not to good. And D1 fell from 2/3 to 1/3, with two runs *actively ruling it out* — a reviewer on a short budget produces confident refutations, which is worse than silence and is the next thing to measure.

**And the counterweight turned out to be the story.** [The weak unaided arm's 28 claims were verified adversarially, twice](runs/2026-08-21-weak-precision/): **19 refuted by both passes, 4 supported — and those 4 are D1 and D2 themselves.** Beyond the two defects the ground truth already names, that arm produced nothing that survived being attacked: the code read backwards, a premise inverted by a strict `<`, three claims needing a scale outside the range a `readUnsignedByte()` can return, and a missing log line. **The recall comparison was substantially measuring output volume.**

**[Then the corpus arm was verified too, and it is not more precise either.](runs/2026-08-21-corpus-precision/)** Pooling nine weak runs gave 26 claims against the 28 already done; same verifier prompt byte for byte, two adversarial passes each. **62% refuted against 68% — six points, where the pre-registration required more than ten.** And the finding underneath is bigger than the comparison: **every claim that survived, in either arm, is one of the two ground-truth defects.** Across twelve weak runs and 54 claims, neither arm produced a single true finding beyond the two already named. One asymmetry did appear and is recorded as an observation rather than a result: inter-pass agreement was 26/26 on the corpus arm's claims against 25/28 on the unaided arm's, which 26-versus-28 claims cannot settle. What is now measured is that **both arms make confident wrong statements on a weak model**: the unaided arm as findings, the corpus arm as refutations of a real defect. Which failure a reader would rather receive is unanswered.

## Three arms, seventy-one claims, and only two true findings anywhere

[2026-08-21, three-way precision](runs/2026-08-21-three-way-precision/) — us, the same model unaided, and `google/mantis` @ `5f76be0`, on the same target at the same weak model, judged by the same verifier prompt byte for byte in two independent adversarial passes each.

| Arm | claims | refuted by both passes | supported by both |
|---|---|---|---|
| **competitor** | 17 | **9 (53%)** | 4 |
| with the corpus | 26 | 16 (62%) | 9 |
| without any corpus | 28 | 19 (68%) | 4 |

**The competitor is the most precise, and the pre-registration predicted exactly that** — it ships explicit `critic`, `dedupe` and `review` stages this corpus does not have as separate stages. Seventeen measurements now, and this is the first that puts a named competing product **ahead** rather than level.

**And every claim that survived, in every arm, is one of the two ground-truth defects.** Seventy-one claims between the three; forty-four refuted twice over; the only true findings anywhere are the two already named. That is this bench's strongest evidence that **detection is the model's, not the product's.**

The competitor's own filtering is not clean either: its 17 claims cover about 9 distinct assertions, and two duplicate pairs **contradict each other on the facts** — one says the `*1000` at line 269 is a thousand-fold bug, the other says the same line is unchecked arithmetic with no attacker gain. A `dedupe` stage ran.

## External code: one detection in twenty-four runs, and it does not replicate

Two published advisories, two real repositories, three products, four runs each — [`vouch-proxy`](runs/2026-08-22-external-competitive/) and [`Netflix/lemur`](runs/2026-08-22-external-second/), both at checkouts verified to sit before the fix.

| | `vouch-proxy` (Go, 144 files) | `Netflix/lemur` (Python, 575 files) |
|---|---|---|
| this corpus | 1 / 4 | **0 / 4** |
| `Tencent/AI-Infra-Guard` | 0 / 4 | 0 / 4 |
| `google/mantis` | 0 / 4 | 0 / 4 |

**One detection in twenty-four measured runs, and the round designed to reproduce it did not.** The `vouch-proxy` result was parked under exactly that condition and is now parked permanently. **Nothing in this bench supports a claim that any of these products finds published advisories in unfamiliar code without a pointer** — this project included, and that is the honest state of external validity here.

**Both misses are one link short, not lost.** On `vouch-proxy` `mantis` reached the advisory's exact function and named an out-of-bounds access instead of the unbounded allocation. On `lemur` this corpus reached the advisory's exact endpoint and named the missing authorization gate — a precondition of the chain — without ever reaching the revoke step that makes it exploitable. Across 56 claims from three products on `lemur`, **one mentions revocation at all**.

**`AI-Infra-Guard` produced zero claims in four runs on `lemur`**, concluding "SAFE FOR DEPLOYMENT". Reported with its reason, because the bare number misrepresents it: its taxonomy asks *is this code malicious*, and it answers correctly — `lemur` has no backdoor. The defect is authorization wired wrongly, which is not the question that pipeline was built to ask. **A tool answering its own question is not a tool failing**, and one of these three arms was not built for this test.

## Reading the two dimensions jointly — an observation, not a result

The bands treat precision and recall separately. Reading them **together** asks a different question: does any arm beat another on **both** at once? That is arithmetic over numbers already published, not a new metric — but **it was not pre-registered**, so it is offered as an observation and labelled as one.

| target | this corpus dominates | dominated by |
|---|---|---|
| `rag-agent` (AI-agent surface) | `AI-Infra-Guard` **and** `google/mantis` | — |
| `express-invoices` (HTTP API) | — | — |

**No arm has ever dominated this corpus on either target.** And immediately the qualification that removes most of the weight from that sentence:

- **The dominance over `AI-Infra-Guard` on `rag-agent` is one refuted claim and 0.17 of recall.** This bench has *measured* that the same artifacts under a different blind judge move recall by up to **0.33, with the sign of the difference flipping**. That margin is below the instrument's own resolution and **is not a durable ordering**.
- **The dominance over `mantis` on the same target is 19 points of precision**, which is outside that resolution and does survive as a real difference.
- On `express-invoices` there is no dominance in either direction involving this corpus, and `mantis` dominates `pentest-ai-agents`.

So the durable version is smaller than the table: **on one target this corpus is measurably ahead of one competitor on both dimensions at once; nowhere has any arm been ahead of it on both.** That is still not "best" — it is an absence of anyone clearly better, on two targets at one model scale, against three of the four comparable products in this field.

## Four arms: the field's three comparable products each fall outside a band

[2026-08-22, third competitor](runs/2026-08-22-third-competitor/) — `0xSteph/pentest-ai-agents` @ `e5d7aa0`, six runs, **all 134 claims from four arms re-pooled and re-judged from scratch**, inter-pass agreement 99%.

| Arm | claims | refuted by both | recall |
|---|---|---|---|
| `AI-Infra-Guard` | 25 | **0 (0%)** | **4.17 / 5** |
| this corpus | 30 | 1 (3%) | 4.83 / 5 |
| `google/mantis` | 36 | 3 (8%) | **5.00 / 5** |
| `pentest-ai-agents` | 43 | **7 (16%)** | **5.00 / 5** |

**The prediction is refuted** — precision spread 16.3 points, well outside the 10-point band, with the new arm as the outlier — **and the half of it that bet against this project holds**: `AI-Infra-Guard` refutes nothing at all and is the more precise arm. **This corpus leads nothing here.** Two arms out-recall it, one out-precisions it, and it remains the only arm inside every band on both targets.

**Half the "three never run" caveat was a category error.** `msoedov/agentic_security` has **zero** source-audit language: it is a jailbreak fuzzer against a live endpoint, so a number for it would measure what it never claimed to do and would flatter this project by construction. Scored **not applicable**. `vxcontrol/pentagi` needs live infrastructure. **Three of the four comparable products are now measured.**

Declared before the run: the new arm's own `code-auditor` asks for `model: sonnet` and was run at `haiku-4-5` to match the scale — a handicap against its written intent, and its floor rather than its ceiling.

## A second target: each competitor falls outside a band, this corpus does not

[2026-08-22, second target](runs/2026-08-22-second-target/) — `express-invoices`, an ordinary Node HTTP API, 5 planted defects and 6 decoys, picked by a rule written before it was applied. The same three arms, six runs each, 85 claims in one blinded batch, inter-pass agreement 98%.

| Arm | claims | refuted by both | recall |
|---|---|---|---|
| this corpus | 30 | **1 (3%)** | 4.83 / 5 |
| `AI-Infra-Guard` | 25 | **0 (0%)** | **4.17 / 5** |
| `google/mantis` | 36 | 3 (8%) | **5.00 / 5** |

**Precision held its band (8.3 points of spread); recall did not (0.83).** `AI-Infra-Guard` is the cleanest arm here at 0%. Across both targets: `mantis` falls outside the precision band on one, `AI-Infra-Guard` outside the recall band on the other, **and this corpus falls outside neither on either**. That is not a lead on any axis — `mantis` out-recalls it here and `AI-Infra-Guard` ties its precision on both — it is a claim about never being the outlier, and it is the strongest thing two targets will carry.

Two readings the first target could not produce. **`AI-Infra-Guard`'s advantage was domain-bound**: level on its own ground, last on recall off it, still refuting nothing — the conservative arm on both targets, which is the most reproducible finding in either round. **`mantis`'s 19-point deficit was target-specific**: 8 points here, and it found every planted defect in every one of its six runs.

**One correction, and it cost this project its 0%.** A corpus run was published as *not measured* on the strength of a seven-minute stale artifact; it had not died, it was slow, and it finished with six findings. All eighteen runs were re-pooled and re-judged: the corpus arm goes from 0% to **3%**, because **the excluded run held the only corpus claim either target has ever had refuted** — a false positive fired at the one endpoint that *does* scope by owner. The error had been flattering this project. The bench had a rule for *a dead run is not a zero* and no criterion at all for telling **dead** from **slow**.

## A second competitor, and the ranking dissolves

[2026-08-22, second competitor](runs/2026-08-22-second-competitor/) — `Tencent/AI-Infra-Guard` @ `4908db1`, the only product in this field that publishes its own detection quality, on its home ground. All 114 claims from three arms re-pooled and **re-judged from scratch**, so no number is carried over. Inter-pass agreement 96%.

| Arm | claims | refuted by both passes | recall | union |
|---|---|---|---|---|
| this corpus | 36 | **0 (0%)** | 4.67 / 7 | **7 / 7** |
| `AI-Infra-Guard` | **31** | 1 (3%) | 4.50 / 7 | 6 / 7 |
| `google/mantis` | 47 | 9 (19%) | 4.50 / 7 | 6 / 7 |

**The corpus arm's 0% reproduced under a fresh verifier pair** — that was pre-registered to be reported ahead of any comparison, and it did not move. **`AI-Infra-Guard` is far cleaner than `mantis` and indistinguishable from this corpus**: 3% against 0% is one claim out of 31, where the refutation criterion needed ten points. This project is **level with the best measurable competitor, ahead of the other one** — not ahead of the field, and three of six surveyed products have still never been run.

**The lasting result is about the instrument, not the table.** The same twelve artifacts, scored by two different blind judges, moved by up to 0.33 of a defect **and the difference flipped sign**: judge one put this corpus behind `mantis`, judge two put it ahead. That is the same 0.33 that withdrew the claim earlier the same night. **A recall comparison at this N does not order the arms; it only says whether they sit inside one band** — which is why the band was declared before the numbers existed, and why every recall figure here must be read that way.

One profile difference is worth more than the ranking: `AI-Infra-Guard` produced **the fewest claims of any arm** at the same recall and near-identical precision. The specialist is the most economical of the three.

## The capability claim, withdrawn and then restored on evidence

[2026-08-22, recall resolution](runs/2026-08-22-recall-resolution/) — six NEW runs per arm, the pilot's three excluded because their numbers were known when the band was written.

| | claims | refuted by both passes | recall mean | union over its runs |
|---|---|---|---|---|
| this corpus | 36 | **0 (0%)** | 4.50 / 7 | **7 / 7** |
| `google/mantis` | 47 | 8 (17%) | 4.83 / 7 | 6 / 7 |

**Both pre-registered criteria hold**: precision 17 points where 10 was required, recall 0.33 below inside a band of 0.5 declared in advance. Inter-pass agreement 88%.

**The clearest thing this round produced is not the verdict, it is why three runs could not reach one.** On three runs the defect coverage was corpus 6/7 against competitor 7/7. On six it is 7/7 against 6/7. Same arms, same target, same instrument — the comparison flipped with nothing changed but the run count, which is what a one-defect margin is worth.

It also carries two facts against the tidy version. One competitor run skipped that product's own filtering stages and is reported both in and out, and excluding it moves both numbers **in this project's favour**, which is why it is stated. And the bench case's own hardened twin turned out **not to be safe** — found by an arm under audit, recorded in the answer key rather than in the case's own README, which is copied into the target, and it changes how a whole family of claims must be scored.

## The precision claim was replicated, and it did not clear its own criteria

[2026-08-22, precision replication](runs/2026-08-22-precision-replication/) — a second target, `rag-agent`, **7 planted defects and 6 decoys** rather than `wire-decoder`'s 2, picked by a rule written before it was applied.

| | claims | refuted by both passes | recall | claims per defect |
|---|---|---|---|---|
| this corpus | 16 | **1 (6%)** | 4.33 / 7 | 2.2 |
| `google/mantis` | 23 | 7 (30%) | **4.67 / 7** | 2.0 |

**The precision half came back stronger than the original** — 24 points where the pre-registration required 10. **The recall criterion was not met**, and the pre-registration said either failure drops the claim, so the claim is withdrawn from the top-level `README.md`.

The margin is one defect in one of three runs, inside the resolution below, and the criterion had no noise band — an absolute threshold on a 7-item scale. **Both are recorded in the round; neither was used to keep the claim.** What would settle it is named there: more than three runs per arm.

It also corrects a caveat this bench had been carrying: **our deduplication is not worse than the competitor's** — 2.2 claims per defect against 2.0, where the earlier round reported a large gap against us.

## The one dimension where this project does lead, and it is not capability

[2026-08-21, field transparency](runs/2026-08-21-field-transparency/) — six products, a six-question rubric fixed before any of them was opened, every `yes` needing a URL or a path.

**This project 6/6. `AI-Infra-Guard` 1/6 with one unsettled. The other four: 0/6.**

The prediction was refutable and held. And the most useful thing in it is a **correction to this repository's own competitive analysis**, which claimed no competitor publishes detection quality: `AI-Infra-Guard` does, with F1, precision, recall and FPR on a named benchmark. That document now says so.

**Read this next to everything above it.** It is a claim about what a buyer can *check*, not about what anyone finds. On capability this corpus leads on none of eighteen measurements, and `google/mantis` is measurably ahead of it on precision.

## Whole repositories: the round that claimed this is RETRACTED

[2026-08-22, routing at N](runs/2026-08-22-routing-at-N/) — the thinnest evidence in this bench was also the one holding up its strongest conclusion. The dimension the corpus is *built* for, deciding what to read in a repository nobody reads whole, had three advisories of evidence. It now has six.

| | corpus | unaided |
|---|---|---|
| earlier rounds | 0/3 | 1/3 |
| 2026-08-22, rule-picked Go targets | 0/3 | 0/3 |
| **total** | **0 / 6** | **1 / 6** |

> **Retracted.** The 2026-08-22 targets were cloned at the default branch, which is **after** each fix commit, so both arms audited code the defects had already been removed from. 0/3 against absent defects measures nothing, and the conclusion drawn from it is withdrawn. Whole-repository evidence is back to the earlier rounds alone: **0/3 with the corpus, 1/3 without**, three advisories, which is too thin to conclude anything and is exactly what the retracted round set out to fix. It is re-run properly in `runs/2026-08-22-exhaust-the-file-2/`.
>
> It was caught by an arm applying this corpus's own rule that a refutation must cite the line of the control: it named the bound that makes the defect impossible. A silent non-finding would have shipped as a result.

**The "missed by nine lines" reading is withdrawn with the round.** It said both arms reached `req_resp_decoder.go`, reported a real defect at line 945, and never mentioned `sliceMapToSlice` nine lines away. On a patched tree `sliceMapToSlice` carried its bound, so **not reporting it was correct**. There was no blind spot. A procedure was written to fix it anyway, and measured to have no effect: [2026-08-22, exhaust the file](runs/2026-08-22-exhaust-the-file-2/). Its [superseded pre-registration](runs/2026-08-22-exhaust-the-file/) is kept unedited beside it, linked here rather than only from its own banner: an artifact preserved and unreachable is preserved for nobody.

**Re-run on the verified pre-fix commit, all three arms find it 3/3** — [2026-08-22, unaided on the verified tree](runs/2026-08-22-unaided-verified/):

| arm | corpus | found | findings per run |
|---|---|---|---|
| treatment | full, plus the "exhaust the file" rule | 3/3 | 14, 14, 14 |
| control | full, that rule removed | 3/3 | 10, 9, 13 |
| **unaided** | **none at all** | **3/3** | 17, 15, 10 |

Nine runs, blind, against a judge that rejected the same-file decoys in every batch and separated the nearest one on mechanism in its own words. **Whole-repository detection of this advisory is the model's, and the corpus adds nothing to it.** That dimension — deciding what to read in a repository nobody reads whole — is what this corpus is built for, and it was the last one where a lead had not been ruled out. The unaided arm also reported the most findings of any arm.

One advisory, one repository, three arms not run simultaneously. It does not restore the retracted round.

**No product in this field should claim whole-repository detection without publishing a number**, and four of five publish none.

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

## `undecidable` versus `refuted` — the rule the verifiers were already using

Checked in [2026-08-22, undecidable rule](runs/2026-08-22-undecidable-rule/) after the two looked inconsistent. They were not.

1. **refuted** — the claim locates its defect **inside** the target and the code there contradicts it, or it describes something with **no attacker and no impact**.
2. **undecidable** — the claim's defect is the **absence** of code that, if it exists, lives **outside** the target. Nothing inside settles it.
3. **Documented behaviour of a named dependency is not "outside".** It is general knowledge, so a claim contradicted by it is refuted — otherwise every claim about a library is unfalsifiable.

A claim may **argue** from outside the target while **locating** its defect inside it; the rule looks at where the defect is said to be.

An independent classifier, blind to the existing verdicts and to which claim was whose, reproduced **125 of 132** both-pass verdicts. **It is a description, not a mechanism** — 125 of 132 says the verifiers were drawing this line, not that one could be replaced by it. Its seven divergences all belong to competitors and all move in their favour, which is the evidence that it was not written to win.

## A comparison this bench must never publish, and why

There is an obvious-looking dimension where this project would win outright: **does a product's output let a reader tell *not looked at* from *looked at and clean*?** This corpus's artifact carries a coverage declaration that must resolve every surface it inventories. The competitor artifacts in these rounds are flat lists.

**That comparison is rigged, and it is rigged by this bench.** Every competitor prompt in `runs/*/prompts/` specifies the deliverable shape — `{"findings": [{"id", "title", "file", "line", "severity", "impact", "evidence", "recommendation"}]}` — because a common shape is what makes the claims poolable and blindable at all. So a competitor's artifact has no coverage declaration **because this bench told it not to have one**, not because the product cannot produce one.

Measuring it anyway would produce a real number, a favourable one, and a false conclusion. It is written down here so that nobody — including whoever reads this next — reaches for it as the dimension that finally settles the question.

**What a fair version would need**: every arm emitting its own native report format, and a reader test over those, with the pooling and blinding rebuilt to survive four different shapes. That is a different bench, not a further round of this one.

## The nine rules that came out of being wrong

None of these was designed. Each one is what a retraction or a near-miss cost, and several are enforced by `gate-bench-integrity.sh` rather than by good intentions.

1. **Pre-register before the result exists** — the prediction, what would refute it, *and what each outcome forces you to write*. Two rounds in this directory came out exactly as predicted and are published as worthless; without the criterion committed first, both would have shipped as wins.
2. **Archive the prompt.** The same arm scored 0.81 and 0.60 in two sittings on one target with one instrument, because the run prompt was rewritten. Twenty-one points from wording is larger than any effect this bench has measured. A comparison without its prompt is not comparable to anything, and the gate refuses one that neither carries its prompts nor says it does not.
3. **State the outside-information policy, identically for every arm.** One run diffed the target against upstream; another cited CVE ids. Finding a defect by diff is not the act of finding it by reading. Also gated.
4. **A dead run is not a zero.** A run whose agent died is *not measured*, and its partial output is preserved unscored. This rule was first applied when it cost us and has since been applied when it favoured us.
5. **Never report precision without recall.** An arm that reports nothing is never refuted. A drop in refuted claims that arrives with a drop in ground-truth recall is suppression, and gets that word.
6. **Two passes, or it is not an instrument.** A single blind judge disagreed with a second one on the two verdicts that decided a case, and a published result had to be withdrawn. Inter-pass agreement is reported as the resolution of the instrument, and no difference smaller than it is reportable.
8. **Verify the defect is in the checkout before any arm runs.** A whole-repository round was published and retracted the same night: the targets were cloned at the default branch, which is *after* each fix, so both arms audited code the defects had been removed from and 0/3 was reported as detection. The case file recorded the pre-fix `parent` commit and it was ignored. `scripts/bench/verify-target-checkout.py` now refuses a case whose checkout is not at its parent, or whose files carry a marker the fix introduces — five negative cases, including the exact mistake. **It was caught only because one arm named the control that made the defect impossible; a silent non-finding looks identical to a miss, and a bench cannot depend on luck.**

7. **Check the artifact before you believe the number.** A pre-registered prediction landed exactly on target while *all three runs failed validation* — the intervention had never been applied. Only the machine-checked contract caught it.
9. **A prediction met by a result whose cause is absent is not a confirmation — run the control.** A procedure was written from a diagnosed blind spot, pre-registered at ≥1 of 3, and scored 3 of 3. Removing the procedure and changing nothing else also scored 3 of 3. The prediction was met and the explanation was false. Worse, the blind spot itself was an artefact of rule 8: the round that diagnosed it had audited patched code, so the "miss" was correct behaviour. **A change ships as an improvement only against an arm that lacks it**, and one that cannot be shown to do anything is discarded *before* it ships rather than kept for being reasonable. This one never reached a commit; `VER-09` v1 did, and had to be pulled back out after it cost a true defect per run.

## What the numbers are worth

**Recall here is recall on this bench.** The cases were written by the same project that wrote the procedures, so a high score partly measures that the corpus describes the code it was written from. That is not nothing — it proves the routing and the patterns hold on code shaped like this — but it is not evidence about code nobody here has seen. Say "recall on the bench", never "detection rate".

**The decoys are the part that resists self-flattery.** Every construct in the decoy list looks like a finding and is ruled out by a named triage rule. Reporting one is a false positive with an id, a location and the rule that should have caught it — this repository's first-class defect, measured instead of asserted. A bench author cannot make decoys easy without making them useless, because the decoy list is published next to the score.

**Unlabelled findings are not counted against a run.** The bench does not claim to have planted everything a case contains. A finding that matches nothing in the key is reported separately and is worth reading: it is either a real defect the key missed, or a false positive the key cannot name yet. Both are follow-up work, not a number.

## What it cannot measure

Anything the cases do not contain: mobile surfaces, remediation and verification, and every class in the corpus that has no case here. <!-- bench:packs -->
Today the bench exercises `web-api`, `local-app`, `infra-cloud`, `supply-chain`, `ai-safety` and `privacy-abuse`, and the score is silent about `mobile` and `remediation` — silent, not clean.
<!-- /bench:packs --> It also says nothing about how the squad behaves under a real repository's size, where the expensive failure is not missing a pattern but never reading the file.

## Pre-registered, not yet run

A round whose criteria are committed and whose numbers do not exist. It is listed here from the moment it is written, because a pre-registration a reader cannot find before the result arrives proves nothing about the order the two were written in — which is the whole point of writing it first.

- [2026-08-24, the near-miss round](runs/2026-08-24-chain-completion/) — three rounds record the same shape of miss: the right file open, something true reported, and the defect beside it missed. The candidate procedure is **frozen in the run directory and is not in the corpus**, and moves into `references/` only if the pre-registered band is met.
- [2026-08-24, the triage stage on its own](stages/triage/) — fifteen cases that ask one stage of the squad, not the whole of it, and whose **key is auditable by machine**: the consequence of every answer is forced by the table in `references/triage.md`, and `gate-triage-stage.sh` re-derives all of them and fails the case when the key and the table disagree. Nothing has been run; the criteria are frozen beside the cases.

## Measuring one stage instead of the whole squad

Every round above asks whether the squad found the defect, which is the question a reader cares about and is blunt about where a miss happened. `stages/` holds evals that ask a single stage. The first is [the triage stage](stages/triage/), and it carries a check the rounds do not need: a gate that rejects any case whose statement contains the rule id, the answer token or the consequence terms its own key declares, or that prescribes the remedy. **That second family is not hypothetical** — pointed at the eight per-stage eval sets a neighbouring product publishes, it finds one row of twenty-five that names the fix inside the field naming the defect, and that row is the whole of that stage's dataset. The measurement, its limits and how to reproduce it are in that directory's `README.md`.

## Growing it

A case is worth adding when it can carry both halves: a real defect and a construct that resists. A case with only planted defects measures nothing but the model's willingness to agree.
