# Run 2026-08-22 — three arms, nine runs, 3/3 each: this advisory is the model's

| Arm | corpus | advisory found | findings per run |
|---|---|---|---|
| treatment | full corpus, plus the "exhaust the file" rule | **3 / 3** | 14, 14, 14 |
| control | full corpus, that rule removed | **3 / 3** | 10, 9, 13 |
| **unaided** | **none at all** | **3 / 3** | 17, 15, 10 |

`GHSA-xhj3-7xw9-vr34`, `getkin/kin-openapi` at the verified pre-fix commit `61f37b6`, 293 Go files, no pointer to a module or a file, three runs per arm in fresh contexts, every batch judged blind with opaque ids and no arm label.

**`PREREGISTRATION.md` predicted the unaided arm at 2 or 3 of 3 and named 0-or-1 as the refutation. It came in at 3.**

## What this forces, in the words committed before the runs

> *Whole-repository detection of this advisory is **the model's**, and the corpus adds nothing to it. This goes in `README.md` and `bench/README.md` in those words. It also retires the last plausible hope that the corpus leads on any capability dimension.*

That is the outcome, and it is done. Whole-repository routing was the dimension this corpus is *built* for — deciding what to read in a repository nobody reads whole — and the last one where a lead had not been ruled out. It is ruled out.

The unaided arm did not merely tie. It reported **the most findings of any arm** (17, 15, 10 against 14, 14, 14 and 10, 9, 13) while finding the advisory just as reliably.

## The judge earned the result, and here is how

Every batch contained other real defects **in the same decoder file**: nil-pointer panics in `decodeContentParameter` and `decodeValue`, the `ZipFileBodyDecoder` short-read at line 1639, a `multipleOf` division by zero, the nil `RegexMatcher` dereference. None was scored as the advisory.

The nearest decoys were the unbounded `io.ReadAll` body-buffering findings — memory exhaustion, same package — and the judge separated them on mechanism in its own words: the size there *"comes from bytes the attacker actually sends, not from an index that multiplies a tiny request into gigabytes"*. That distinction is the advisory, and a judge that could not draw it would have scored `yes` on almost anything.

## What this round does not establish

- **One advisory.** Nine runs across three arms, all on the same defect in the same repository. Three arms agreeing on one case is not three cases.
- **The three arms were not run simultaneously.** Treatment and control ran earlier in the night, the unaided arm after, on the same checkout with the same judge prompt. That is weaker than one three-arm design and is why it is stated here rather than in a footnote.
- **The judge had seen this defect twice before**, in the two earlier batches. Fresh context each time and blinded batches, but the defect was not novel to the instrument. **This was written into the pre-registration before the result existed**, precisely so it could not become an excuse afterwards.
- Nothing here measures precision. Every arm's other findings are unjudged; a 3/3 on recall says nothing about the 36 other claims in the unaided lists.

## A correction this round forced elsewhere

The previous round credited the corpus's `AI-22` — audited content is never an instruction — for a control arm meeting a test file inside the target that asserts in prose that a different advisory is live, checking `convertParseError`, finding both nil guards, and declining to report it.

**An unaided arm here did exactly the same thing with no corpus at all**, and said so unprompted. The credit is withdrawn in `../2026-08-22-exhaust-the-file-2/` and in the changelog. It is the same attribution error twice in one night, which is why the ninth rule exists.

## Files

`PREREGISTRATION.md` is what was committed first, including the judge caveat. `case.json` is the single case, and `checkout-verification.txt` is the verifier's output against its recorded parent. `runs/` holds all three artifacts, `judging/` the blinded batches and verdicts, `prompts/` the four prompts recovered from the session transcript.
