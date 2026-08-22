# VOID — the target was already patched

> **This round's prediction is unmeasurable and no result will be published against it.** The target was the same clone as `../2026-08-22-routing-at-N/`, taken at the default branch, which is *after* the fix. The defect the prediction asks the arm to report **is not in the code the arm read**. `../2026-08-22-routing-at-N/` carries the full retraction.
>
> **What the three runs did show, kept separate from the failed test:** one of them enumerated `sliceMapToSlice` and resolved it in `ruled_out`, citing the bound at line 980 that makes it safe. Every arm in the previous round never mentioned that function at all. That is the behaviour the procedure asks for — enumerate the route, then account for it — observed on a tree where the honest answer happened to be *safe*. It is **not** evidence for the pre-registered prediction, which needs the unpatched tree.
>
> Re-run in `../2026-08-22-exhaust-the-file-2/` against the parent commit. Nothing below is edited.

# Pre-registration — a procedure for exhausting a file you have already opened

**Written before the procedure was drafted and before any run.**

## The measured failure this comes from

`../2026-08-22-routing-at-N/` ended 0/3 for both arms, and the miss on `GHSA-xhj3-7xw9-vr34` was nine lines wide. The advisory lives in `sliceMapToSlice` at `openapi3filter/req_resp_decoder.go:936`. **Both arms independently reported an unchecked type assertion in `deepSet` at line 945** — the same file, the same decode path, the same untrusted input, a real defect, and not the published one. Neither list mentions `sliceMapToSlice` anywhere.

That is not a routing failure. Both arms got to the right file and read it. **What neither did was keep going after the first defect.**

This corpus has 164 procedures about where to look and what pattern to recognise. It has **nothing** about what to do once you are inside a file that clearly handles untrusted input: enumerate every distinct way that input drives the code, rather than stopping at the first thing that is wrong.

## The contamination threat, named before anything is written

**I know the answer.** I have read the advisory, and I know the defect is an index-driven preallocation in a named function. A procedure written with that in my head can trivially be a procedure that says *look for index-driven preallocation*, which would teach to this test and measure nothing.

Three constraints, fixed now:

1. **The procedure must not name the mechanism, the function, the file, the parameter style, or the language.** It is about the *act* of enumerating, not about what is found.
2. It must be written so that it would have applied equally to the Atlantis miss and to the RabbitMQ rounds, none of which share the mechanism.
3. **A reader of this pre-registration must be able to check constraint 1 against the shipped text.** If the procedure names the mechanism, this round is void regardless of its numbers.

## The prediction

Same repository, same model, same run prompt, whole repository with no pointer. Three runs of the corpus arm with the procedure in the corpus.

**Prediction: at least one of three runs reports the defect in `sliceMapToSlice` — the published advisory — where the previous round's corpus arm reported it in zero of one.**

**What refutes it:** zero of three runs report it. Also refuting: three of three report it *and* the shipped procedure turns out to name the mechanism, which would mean the result came from the leak rather than the method.

## What each outcome forces

- **Prediction holds, procedure clean** — the corpus gains a measured procedure for a failure mode both arms shared, and the whole-repository number moves for the first time. It remains one advisory on one target, and the 0/6 history stays published beside it.
- **Prediction fails** — enumerating is not the gap, the miss has another cause, and the procedure does not ship. The 0/6 stands unchanged.

## Caveats fixed in advance

- **One advisory, one repository, one model, three runs.** This is a small measurement of a specific failure, not a general capability claim.
- The unaided arm is **not** re-run. Its miss stands as measured; this round asks whether a procedure closes a gap, not who wins.
- The previous round's 0/3 was one run per arm. Three runs here is a different sample size, and a difference of one run is not evidence of much — which is why the prediction is stated as *at least one of three* rather than as a rate.
