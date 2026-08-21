# Run 2026-08-21 — third rule-picked round, and the first separation

Two rule-picked rounds had ended level, and each had produced procedures from what every arm missed: `WEB-23` from the first, `WEB-24` and `WEB-25` from the second. Whether that compounds into a lead was an empirical question with two data points and no answer. This round is the answer, and it was pre-registered — ecosystem changed on purpose to fix the single-repository weakness round 2 had declared before its own results existed.

## Result

| Advisory | With the corpus | Without it | Competitor |
|---|---|---|---|
| `CVE-2026-53966` — edit right escalated to script right through a caller-named XClass | **found** | **missed** | *not measured* |
| `CVE-2026-63337` — unvalidated `Class.forName` from a JSON service description | **found** | **found** | **found** |
| `CVE-2026-69219` — oversized declared length sizes an allocation before any payload is read | **found** | **found** | *not measured* |
| | **3 / 3** | **2 / 3** | **1 of 1 measured** |

**This is the first time the corpus has separated on a case nobody here selected**, and the separating finding is the one that matters: it came from **`WEB-25`**, a procedure written from the *previous* round's shared miss, firing on a target no one here had seen.

The judge, who saw only the advisory text and the finding text, named the mechanism itself: the target XClass is caller-supplied, the object is created or overwritten through it, and *"the only authorization on the chain is `checkAccess(Right.EDIT, documentReference)` on the document — nothing authorizes the class."* That is `WEB-25`'s sentence — authorization checked on the object in the path, not on the objects in the body — reached independently.

The no-corpus arm was not far away and its two near misses are worth reading, because they show what the procedure adds. It scored `partial` twice on the same file: it developed the `enforceRequiredRights` flag, which re-enables or disables an existing author's scripts, and the stale content-author bookkeeping. Both are real; neither is the caller granting themselves script right by choosing the class. The corpus arm reported the `enforceRequiredRights` lever **too** — as `WEB-06`, its own first finding — and then kept going.

## The competitor column, and why two cells are empty rather than zero

The host slept three times during this round and killed the competitor arms twice, along with the parallel sub-auditors their own method spawns. One of the three recovered and finished its pipeline — 17 raw findings → 14 after dedupe → 12 after review — and **found the advisory**, twice over, from two independent trajectories. The other two never got past their researcher stage.

Their partial indexes are stored in `unfinished/` and are **not scored**. Both hold pre-review researcher output — one of the two arms said so itself in writing — and scoring that would overstate what its method reports. The doctrine this repository applies to its own gates applies here too, and it happens to cut against the rival: a check that could not be performed is never a pass, and it is never a zero either.

`jsonrpc` was therefore judged **twice**: once with the two arms that had finished, and again with all three once the competitor completed, so no arm is judged in a context the others were not. The two-arm verdicts agreed with the three-arm ones on both arms they covered, and only the three-arm batch is kept.

## Across all three rule-picked rounds

| | Corpus | No corpus | Competitor |
|---|---|---|---|
| round 1 — Go, 3 advisories | 2/3 | 2/3 | 2/3 |
| round 2 — Python, 3 advisories | 1/3 | 1/3 | 1/3 |
| round 3 — Java, 3 advisories | **3/3** | 2/3 | 1 of 1 measured |
| **total** | **6 / 9** | **5 / 9** | **4 of 7 measured** |

**One advisory separates the corpus from the same model without it, over nine.** That is a lead and it is a thin one. It is not a claim of dominance, it does not survive being restated as a percentage, and the honest sentence is the narrow one:

> On nine advisories selected by a published rule, the corpus found one more than the same model working without it. The one it found alone came from a procedure written after an earlier round's failure, which is the loop this repository claims to run, doing the thing it claims.

What would strengthen it is more rounds — and what would weaken it is the same thing, which is why the next round matters as much as this one.

## Files

`provenance.json` was written before any result: the selection rule with its six rejects, why the ecosystem changed, and the sentence *"if the round ties again, that is three rounds of parity and the honest reading is that the corpus does not lead"*. `judgements-deblinded.json` holds every verdict joined back to its arm, with the batch it came from. `arms/` holds the seven artifacts that were measured; `unfinished/` holds the two that were not, unscored.
