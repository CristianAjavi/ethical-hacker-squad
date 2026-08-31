# Pre-registration — make the corpus carry the answer

Written before the corpus exists. It addresses the defect
[the judge work found](../../judge/) and could not resolve: **a decoy hit is scored by location,
so a finding within six lines of a planted decoy counts as one whatever it asserts.**

## Why this is a different kind of attempt

Four methods have already failed at the semantic question *is this the claim the decoy baited*: a
blind judge with an open question, the same judge with the disqualifying search forced, a
word-overlap proxy, and a claim-divergence measure. Three of the four were killed by their own
control. [The ledger's own summary](../../WHAT-MOVES-A-NUMBER.md) says asking a reader to reason
better has moved no target number in twelve rounds.

So this attempt does not ask anyone anything. **The corpus author already knows what claim each
decoy baits**, and the scorer can compare identifiers rather than meanings.

## The change, in three parts

1. **Each decoy declares `baits_cwe`** — the CWE it is built to be mistaken for.
2. **Every finding carries `cwe`**, required of **both arms** in the same prompt.
3. **A decoy hit counts only when the finding's `cwe` matches the decoy's `baits_cwe`.** A hit whose
   CWE differs is reported in a separate `off-claim` bucket and scored as neither.

## What was measured before proposing it, and what it killed

The obvious version — compare whatever CWE a finding happens to mention — **was measured and
rejected**. Citation rates are uneven and asymmetric: in the twelfth round this project cited a CWE
in 94% of findings and `mantis` in 46%; in the eleventh, 58% and 56%. A rule keyed on a voluntary
field would have scored a reporting-style difference as a semantic one, and would have penalised
whichever arm writes fewer identifiers. That is why part 2 exists and why it applies to both arms.

## What each outcome forces

- **The off-claim bucket is small.** Then the location-scoring defect is minor, eleven rounds of
  decoy figures stand roughly as published, and the upper-bound caveat can be narrowed.
- **The off-claim bucket is large.** Then the decoy half of the band has been measuring something
  other than what it claimed for twelve rounds, and every published decoy rate needs restating —
  including the ones that favoured this project.
- **The arms differ in how often they land off-claim.** That is a finding about report discipline,
  not detection, and it is reported as such rather than folded into the band.

## The band, unchanged for the thirteenth time

Supported iff recall exceeds `mantis`'s by **≥ 5 points** *and* the decoy rate is **not higher**.
Failed twelve times: seven met the recall half, one met the decoy half, none met both.

**The band is scored on the old definition as well as the new one, and both are published.** A
metric change that only ever appears alongside the number it improves is not a measurement.

## Scoring and multiplicity

Registered scorer with `--sensitivity`; `adapt.py` with no per-arm branch; floor of three valid
runs per arm; at most two concurrent arms, four sub-agents each, report written even if a stage
never returns. One round, then the corpus is retired.
