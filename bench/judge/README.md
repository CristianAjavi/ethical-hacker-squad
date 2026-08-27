# The blind judge failed its own control, twice — and found a defect in the control

**Two negative results, neither of them convenient.** Nothing here is a round: it is instrument
work on the twelve reports already published, and it was built because
[the decoy rate was measured to see one finding in eight](../runs/2026-08-27-what-the-key-cannot-see/).

## What was built

`sample.py` pools every located finding from the tenth and eleventh rounds, strips the arm and the
run, orders by a digest of the finding itself so the set is reproducible, and emits sixty items of
three kinds, mixed and indistinguishable:

| kind | n | what it is |
|---|---|---|
| `outside` | 40 | a finding the key does not name — **the question** |
| `planted` | 10 | a finding sitting on a planted defect — a judge should rule **true** |
| `decoy` | 10 | a finding sitting on a planted decoy — a judge should rule **false** |

The last two are the negative control, and the answer file is written separately and shown to no
judge. Four judges ran, blind to the arm and to the key.

## Result 1 — the control fails, and forcing the search does not fix it

| judge | question | planted → true | decoy → false | separation |
|---|---|---|---|---|
| A | "does the assertion hold?" | 8/10 | **3/10** | 11/20 |
| B | same | 10/10 | **3/10** | 13/20 |
| C | **disqualifying search forced**, two places minimum, per item | 8/10 | **3/10** | 11/20 |
| D | same | 8/10 | **3/10** | 11/20 |

Judges A and B were run first; their prompt asked whether the assertion *holds*, which they
resolved as *is this description accurate* — and it usually is. So the question was rewritten to
force the negative search the eleventh round had just shown is not performed spontaneously, and
the same sealed answers were used.

**It changed nothing.** 3 of 10 either way. That is the third intervention in this ledger to hit
its stated target and move no number: a rule (`FP-11`), a shape-targeted field (`scope`), and now a
forced search in a judge's prompt.

On the forty that matter, all four judges rule `true` on 38 to 40. **A judge that says yes to
everything has measured nothing**, and the 95% agreement between A and B is two judges agreeing to
say yes, not corroboration.

## Result 2 — reading the failures, the control itself is ambiguous

The obvious reading is that the judges did not look. They did. In **4 of 4** cases examined, the
judge's own `searched` array or its stated reason **names the exact file the key says disqualifies
the finding**, and it ruled `true` anyway — on a narrower claim the exculpation does not touch.

- A decoy whose `ruled_out_by` is `tags: [never, troubleshoot]` on the next line: the judge read
  that line, and reported instead that the task prints a live credential with no `no_log`.
- A decoy ruled out because the principal it mints is confined to a public collection: the judge
  read that confinement, and reported instead that the key is the one setting in its file that
  cannot be rotated without a redeploy.

Both of those are defensible readings of the code. Neither is the claim the decoy was built to
bait.

**Which exposes how a decoy hit is actually scored: by location.** A finding within six lines of a
planted decoy counts as a decoy hit whatever it asserts. So the decoy rate — the half of the band
this project has failed ten times — **counts findings that are not the false positive the corpus
author planted**, and nobody has measured how many.

## What is and is not concluded

- **The judge is not validated and its verdicts are not used.** The forty outside-key findings
  remain undecided, so the question *is the extra volume value or noise* is exactly as open as it
  was this morning.
- **No score is revised, no verdict is touched.** This is an unregistered analysis and it does not
  get to rewrite a measured result — the same rule that kept the eleventh round's verdict standing.
- **The decoy metric now has a known defect** with an unmeasured size. It is not corrected here,
  because correcting a metric on the strength of four cases would be the trade this ledger refuses.

## What it forces

1. **Measure the location-scoring defect** — for every decoy hit in the published rounds, does the
   finding's text assert the baited claim or a different one? That is a judging task too, and it
   needs a control of its own.
2. **A judge that fails the same way its subjects do is a finding about the method, not a tool to
   fix.** Three interventions aimed at the disqualifying search have now moved nothing. The next
   attempt should not be a fourth phrasing.
3. Until 1 is answered, **every "decoy rate" figure in this ledger should be read as an upper
   bound**, and the pages that quote it say so.

## Addendum, measured mechanically: how often is a decoy hit not the baited claim?

The page above says the size of the location-scoring defect is unmeasured. Here is a **lower-effort
lower-confidence** attempt that needs no judge: compare the words of the finding's title and class
against the words of the decoy's own `looks_like`, which is the key's statement of what the decoy
is supposed to be mistaken for.

Across the 98 decoy hits in the twelve published runs:

| arm | decoy hits | sharing **no** vocabulary with the baited claim |
|---|---|---|
| this project | 66 | 21 (32%) |
| `mantis` | 32 | 6 (19%) |

Two of the four examples inspected are plainly different claims — a masking function that returns
its input unchanged, counted as walking into a **SQL-injection** decoy; a stored **XSS** in a print
sheet, counted as walking into a **remote-code-execution** decoy. Both were scored as false
positives for asserting something the decoy was not built to bait.

**And the third example refutes the measure.** "A hardcoded public demo API key" against "A
hard-coded API key in source" — the same claim, scored as sharing no vocabulary because the
tokeniser split on the hyphen. So the proxy has demonstrable false positives of its own and **32%
is an upper bound on the mismatch, not an estimate of it.**

What can be said: the defect is real, it is not rare, and it affects **both** arms. What cannot:
its size. Correcting it would move this project's decoy rate down more than `mantis`'s, which is
precisely why the correction does not get made on the strength of a word-overlap heuristic written
by the party it would favour.

## Second addendum: nine of ten decoy hits read the thing that disqualifies them

The word-overlap proxy above is weak. This one is not, and it needs no judge: the key states, for
every decoy, the artifact that rules it out, with a path and a line. So ask whether the finding's
own text — evidence, scope, searched, all of it — **mentions that artifact at all**.

Across the same 98 decoy hits:

| arm | decoy hits | cite the disqualifying **file** | cite the exact **file:line** |
|---|---|---|---|
| this project | 66 | **56 (85%)** | 26 (39%) |
| `mantis` | 32 | **29 (91%)** | 17 (53%) |

**The "walked into the trap blind" reading is false for roughly nine in ten**, in both arms, and it
is `mantis` that engages the exculpation slightly more often — so this is not a finding that
flatters the party measuring it.

What it does **not** settle, and the distinction is the whole remaining question:

- **A different claim.** The finder read the exculpation, accepted it, and reported something else
  the exculpation does not touch — a live credential printed regardless of a `never` tag. The
  scorer counts a false positive that was never asserted.
- **A dismissed exculpation.** The finder read it, judged it insufficient, and was wrong. The
  scorer counts correctly and the finder has a triage defect.

**Citing is not understanding, and this measure cannot tell the two apart.** What it establishes is
that the population is nearly all one or the other, and almost none of it is the naive case the
metric was designed around.

So the open question for the decoy metric is now precise rather than vague: *of the 85–91% that
engage the exculpation, how many assert something it does not cover?* That is the measurement to
build a control for, and the failed judge above is the evidence that it will not be built by asking
a model the question directly.

