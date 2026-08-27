# Pre-registration — the negative search

Written and pushed **before the corpus exists and before its author has seen a line of it**.

## Where this comes from

The tenth round's post-hoc analysis, [labelled post-hoc on its own page](../2026-08-26-as-designed/),
found that the decoy excess is not concentrated in a component but in a **shape**:

| decoy shape | this project | `mantis` | excess |
|---|---|---|---|
| `constrained-elsewhere` | 2.33 | 0.33 | **+2.00** |
| `unreachable-earlier-layer` | 2.33 | 0.67 | **+1.67** |
| `coerced-upstream` | 1.33 | 0.00 | **+1.33** |
| `public-sample` | 0.33 | 0.67 | −0.33 |
| `dead-path` | 0.67 | 0.67 | 0.00 |

The three with the excess share one property: **what disqualifies them lives in a different file
or layer from the flagged line.** The two whose exculpation is visible at the flagged line show no
excess. The reading: the cross-file search that finds composition defects also manufactures the
false positives — it searches other files to build a case, never to kill one.

## The intervention

A required `scope.searched` array. Each entry names **a place the auditor went looking for
something that would disqualify the finding, and what it found there** — including, and especially,
"nothing". Two entries minimum for any finding whose construct spans more than one file.

This is deliberately not another descriptive field. `narrowed_by` already exists and is filled with
whatever the auditor happened to notice; **the ninth round proved a field beats a rule and the tenth
proved a descriptive field is not enough.** `searched` asks for an action taken, and its natural
answer is a negative result.

## What each outcome forces

- **The three shapes' excess falls to at or below `mantis`'s** — the negative search is the lever,
  and the generalisation becomes: a field that records an *action* moves a number where a field that
  records an *observation* does not.
- **The excess does not fall** — then two required fields have failed at the same target, the
  "field beats rule" generalisation is dead as a design principle for precision, and the next lever
  must be architectural rather than a contract term.
- **Recall falls while precision improves** — the trade is being paid, not broken, and this round
  will say so in those words rather than presenting the precision half alone.

## Band, unchanged for the eleventh time

Supported iff recall exceeds `mantis`'s by **≥ 5 points** *and* the decoy rate is **not higher**.
Refuted if `mantis`'s recall is greater or equal. Inconclusive if ahead by less than 5.

Failed ten times: five met the recall half, one met the decoy half, none met both. Lowered once
from 15, with the lowering declared. Never raised.

## Registered secondaries, without bands

- **Decoys per shape**, the cut that produced this hypothesis. The three targeted shapes are named
  in advance so a fall in the other three cannot be claimed as the intervention working.
- **Is `searched` an action or a sentence?** Distinct locations named per finding, and how often an
  entry records a *negative* result. A field satisfied by naming the file already cited in the
  evidence is a form filled in, which is exactly what the tenth round showed `narrowed_by` became.
- **Cost**, again beside recall: wall time and findings per run.

## Scoring and multiplicity

`../2026-08-26-coverage-rules/score.py`, unchanged, with `--sensitivity`; `adapt.py` over every arm
with **no per-arm branch**; floor of three valid runs per arm; **at most two arms concurrent**, four
sub-agents in flight each, and every arm instructed to write its report even if a stage never
returns — the three corrections the tenth round paid for. One round, then this corpus is retired.
