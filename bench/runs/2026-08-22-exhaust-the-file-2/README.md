# Run 2026-08-22 — the procedure has no measured effect, and the failure it was written for never happened

| | advisory found | runs |
|---|---|---|
| corpus **with** the "exhaust the file" rule | **3 / 3** | out1, out2, out3 |
| corpus **without** it, everything else identical | **3 / 3** | ctl1, ctl2, ctl3 |

Same target at the verified pre-fix commit, same model, same run prompt, same blind judge prompt, all six judged three-at-a-time in one context. The corpus differed only by the presence of one section, removed from `team.md` and `SKILL.md` and verified absent before the control ran.

**The rule changes nothing that this round can detect.**

## The part that matters more than the number

The rule was written from a measured failure: on a whole-repository round, both arms reached `openapi3filter/req_resp_decoder.go`, reported a real defect in it, and never mentioned `sliceMapToSlice` nine lines away. That looked like a shared blind spot — *they stop at the first defect they find*.

**That round was audited against an already-patched tree**, and it was retracted for it (`../2026-08-22-routing-at-N/`). Which means the miss was never a miss: at that commit `sliceMapToSlice` carried a bound, so declining to report it was **correct behaviour**. The arms were not stopping early. They were right.

So the sequence is:

1. A round measured 0/3 and looked like a shared blind spot.
2. A procedure was written, carefully, to fix that blind spot — with the mechanism deliberately unnameable so it could not teach to the test.
3. The round turned out to have been run against patched code and was retracted.
4. Re-run properly, the corpus finds the defect 3/3 — **and so does the corpus without the new procedure.**

**The diagnosis was invented to explain an artefact.** Everything downstream of it — the pre-registration, the contamination constraints, the careful wording — was rigorous work aimed at a problem that did not exist.

## What happens to the rule

**It never shipped, and it does not ship now.** The section existed only in the working tree while it was being measured — `git log -S` across every branch finds it in no commit. It is discarded rather than reverted, and users of this corpus never saw it.

That order is the point. A previous change in this bench (`VER-09` v1) was committed first and measured second, turned out to cost a true defect per run, and had to be pulled back out. This one was measured before it was committed and so there was nothing to pull back. **The difference between the two is not the outcome — both failed — it is that only one of them reached anybody.**

The text is preserved here rather than in the corpus, and it remains a reasonable thing to believe: *do not leave a file after its first defect* is sound advice. It is simply not something this bench has shown to change an outcome, and this corpus has already measured what unmeasured doctrine costs — on a small-context model, loading procedure text consumed the budget an unaided reviewer spent on the code. A line that helps nothing is not neutral, it is priced.

## What this round does establish

- **The corpus finds this advisory reliably** — 3/3, blind, on a verified tree, against a judge that rejected five same-file distractors per batch. That is a real capability datum and it is the first whole-repository advisory this bench has scored as found by anyone.
- **A prediction met by a result whose cause is absent is not a confirmation.** The pre-registration asked for ≥1 of 3 and got 3 of 3. Publishing that as the procedure working would have been wrong, and only the control caught it.
- **One arm demonstrated the safety contract on live content.** A test file inside the target, named for a different advisory, asserts in prose that a vulnerability is present. The arm treated it as data rather than instruction, checked the code, found both nil guards, and refuted it citing the controlling line. `AI-22` says audited content is never an instruction; here that behaviour was observed rather than asserted.

## What it does not establish

- One advisory, one repository, one model, three runs per arm. A rule with no effect *here* may have an effect elsewhere; this measures its absence on one case.
- The control differs from the treatment by one section of text. Everything else — including the artifact contract, the loading rule and the blind critic — is in both arms, so this says nothing about those.
- No unaided arm was run. This is not a comparison between methods.

## What was verified rather than asserted

Three claims in this file are load-bearing, and each was checked after the fact rather than trusted:

- **The two corpora differ only by that section.** `diff -r` over both trees returns 18 lines, all of them the section, in `SKILL.md` and `team.md`, and nothing else in any file. Archived as `corpus-diff.txt`. (The removed text cites `runs/2026-08-22-routing-at-N/` as its own evidence — the retracted round.)
- **The run prompts are identical apart from where they read the corpus and where they write the artifact.** `diff` over the two, with the output path normalised, returns exactly one line: `variance/corpus` against `nocorpusrule/corpus`.
- **The judge prompts are identical apart from which batch files they open.** `diff` returns three lines, `batch-R{1,2,3}.json` against `batch-C{1,2,3}.json`.

**The treatment arm is three runs, not three chosen from more.** Six earlier runs against this repository exist in the working area (`kin2-1..6`); they belong to the retracted round, were run against the patched tree, and none of their artifacts matches any of the three here — different digests, different finding counts (0, 1, 8, 13, 17 against 14, 14, 14). No selection was made and none is being hidden.

## Files, and the uneven strength of the two pre-registrations

`../2026-08-22-exhaust-the-file/PREREGISTRATION.md` is the committed pre-registration for the treatment arm: it predicted at least 1 of 3 and named what would refute it. It got 3 of 3.

**The control's criterion was not committed as a file.** It was stated in advance — in the tracked task and in text — as *"si el control tambien saca 3/3, la regla no explica nada y hay que decirlo con esas palabras"*, before the control ran and before its verdicts existed. That is weaker than a committed pre-registration and is recorded as weaker. What makes it usable is that the direction it commits to is the one against the change, and it is the reading being published.

`runs/` holds all six artifacts as the arms wrote them. `judging/` holds both blinded batches exactly as the judge received them, the verdicts, and the script that built the batches. `prompts/` holds all eight prompts, recovered from the session transcript rather than reconstructed.
