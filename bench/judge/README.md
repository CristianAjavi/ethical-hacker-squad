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
