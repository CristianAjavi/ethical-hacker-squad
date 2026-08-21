# Run 2026-08-21 — third rule-picked round, a separation that did not survive, and the judge defect that produced it

> **Correction, same day.** An earlier version of this file reported **3/3 against 2/3** and called it the first time the corpus separated on a case nobody here selected. **That result does not hold.** It came from judging two arms in one batch and the third in another, and when the case was re-judged with all three arms in a single context — the protocol this bench is supposed to follow — the verdict on the disputed finding moved and the separation disappeared. The complete result is a **three-way tie**. The defect that produced the first version is written up below rather than quietly fixed, because it affects every number of this kind in this directory.


> **The run prompts for this round were not kept.** A later round measured the same unaided arm on the same target with the same blind instrument and a freshly written prompt, and scored 0.60 where this family of rounds scored 0.81 — twenty-one points from the prompt alone. **The numbers below are internally valid and are not comparable to numbers from another sitting.** See `../2026-08-21-unaided-pass/`, which archives every prompt it used.

## Result

| Advisory | With the corpus | Without it | Competitor |
|---|---|---|---|
| `CVE-2026-53966` — edit right escalated to script right | **found** | **found** | **found** |
| `CVE-2026-63337` — unvalidated `Class.forName` from a JSON service description | **found** | **found** | **found** |
| `CVE-2026-69219` — oversized declared length sizes an allocation before any payload is read | **found** | **found** | **found** |
| | **3 / 3** | **3 / 3** | **3 / 3** |

## The judge defect, measured

`livedata` was judged twice. Both judges received the same advisory text, the same prompt, opaque ids and an order fixed by a hash unrelated to the arm. The first saw the two arms that had finished (16 pairs); the second saw all three once the competitor's killed run recovered (26 pairs). **They agreed on 14 of the 16 findings the first one covered, and disagreed on two — the two that decide the case.**

| Finding | first batch | second batch |
|---|---|---|
| the corpus arm's `enforceRequiredRights` lever | `partial` | **`yes`** |
| the no-corpus arm's `enforceRequiredRights` lever | `partial` | **`yes`** |

The mechanism is the same in both readings: `doc.enforceRequiredRights`, the flag governing whether a page's declared required rights are enforced, is writable through the same untyped property path as the page title, behind nothing but `Right.EDIT`. The first judge called that *"re-enabling or disabling an existing author's scripts, not the caller granting themselves script right"* and scored it `partial`. The second called it the advisory's mechanism and scored it `yes`.

**Both readings are defensible, and that is the problem.** On a borderline mechanism a single blind judge is not a stable instrument, and one verdict is exactly the size of the difference this bench keeps trying to measure. Three consequences, now standing rules here:

1. **Every arm for one advisory is judged in one context, always.** Splitting a case across batches is what manufactured the separation.
2. **A separation of one advisory is inside the noise of this instrument.** Any future round that turns on a single verdict has to say so in the same sentence as the number.
3. **Both judgements stay published.** `judgements-deblinded.json` carries the superseded batch beside the one the result is computed from, marked as such.

## What the round does show

The corpus arm reached the `livedata` advisory **twice over, by two different routes**: the `enforceRequiredRights` lever (`WEB-06`) and, separately, the caller-named XClass (`WEB-25`) — the procedure written from round 2's shared miss. On the second, the blind judge wrote the procedure's own sentence back without ever having seen it: *"the only authorization on the chain is `checkAccess(Right.EDIT, documentReference)` on the document — nothing authorizes the class."*

That is real, and it is not a score. `WEB-25` fired on a target nobody here had seen and named a mechanism an independent judge accepted. It did not produce a lead, because the other arms reached the same advisory by the other route.

## Across all three rule-picked rounds

| | Corpus | No corpus | Competitor |
|---|---|---|---|
| round 1 — Go | 2/3 | 2/3 | 2/3 |
| round 2 — Python | 1/3 | 1/3 | 1/3 |
| round 3 — Java | 3/3 | 3/3 | 3/3 |
| **total** | **6 / 9** | **6 / 9** | **6 / 9** |

**Nine advisories chosen by a published rule, in three ecosystems and five projects, and the three arms are identical.** Not one advisory separates them once every arm is judged the same way.

The claim this repository was being weighed against — that it is the best of its kind currently available — is **not supported by its own measurements**. What they support is narrower and still worth having: the corpus reaches the same advisories as an unaided senior engineer and as a competing product, with roughly half the reported output, and it is the only one of the three that publishes the number at all.

## Files

`provenance.json` was written before any result: the selection rule with its six rejects, why the ecosystem changed, and the sentence *"if the round ties again, that is three rounds of parity and the honest reading is that the corpus does not lead"*. That sentence is now the finding.

`judgements-deblinded.json` holds every verdict with the batch it came from, superseded included. `arms/` holds all nine artifacts. `unfinished/` holds the two competitor indexes as they stood when the host killed those runs — both arms later recovered and finished, and the partial files are kept only as a record of what a killed run looks like: pre-review researcher output that would have overstated the arm had anyone scored it.
