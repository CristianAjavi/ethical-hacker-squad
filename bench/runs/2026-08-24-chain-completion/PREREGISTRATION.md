# Pre-registration — the adjacent finding that never closes the chain

Committed before any procedure is written and before any run.

## What is unresolved

Two published rounds record a miss of the same shape, and neither is a knowledge
gap:

- `../2026-08-22-second-target/` — **`CVE-2026-71417`, missed.** Two findings
  landed on the same upload endpoint the fix touched, an authorization gap on the
  owner field and a skipped validation hook. Neither describes the chain the
  advisory names: upload a certificate that duplicates an existing row, then
  revoke it, and the revocation reaches the CA. *"Adjacent is not the same as
  found, and this column says missed."*
- `../2026-08-22-third-competitor/` — the exporter XSS. The closest finding is
  *"the same file, the same function family, the same bug class and the same
  consequence"*, at `class="` rather than at the plugin-hook `data-` attribute
  the advisory names.

In both, the arm was **looking at the right code** and reported something true
about it. What it did not do was carry the finding forward one step: from a
reachable sink to the state transition that reaches it, or from one unescaped
attribute to the sibling the same helper does not cover.

The corpus contains no procedure for this. `grep` over
`skills/ethical-hacker-squad/` returns nothing for *adjacent*, *complete the
chain* or *state transition* as a review move.

## The honest weakness, stated before the design

**This project has already measured that adding procedures does not move
recall.** `../2026-08-21-rule-picked/`: three cases chosen by a rule, no
difference at all. `../2026-08-22-unaided-verified/`: three arms, nine runs, 3/3
each. A fourth procedure is a plausible story, and plausible stories are what
this bench exists to refuse.

So the hypothesis under test is **not** "more knowledge helps". It is narrower
and falsifiable: *a rule that forces one specific follow-up move converts a
class of near-miss into a find.* If it does not, it goes in the ledger as
another procedure with no measured effect, and the corpus does not keep it.

**I have read both misses above.** Any round scored on those two cases is
contaminated by that. They are therefore excluded from the primary comparison
and may appear only as a secondary, labelled.

## Design

- **Primary: cases neither the author of the procedure nor its judge has read.**
  Picked by the published rule in `bench/external/README.md`, not by us.
- Two arms, byte-identical prompts, same model scale as the rounds above:
  corpus **with** the chain-completion procedure, corpus **without** it. The
  competitor arms are not part of this question and are not run.
- Six runs per arm. Three cannot separate a mean on a small scale — that is what
  withdrew a claim in `../2026-08-22-precision-replication/`.
- Recall judged by the same blind defect-matching judge and prompt already
  archived; provenance in a directory no judge prompt names.
- The procedure text is **frozen in this directory before the first run** and its
  diff is part of this pre-registration.

## Prediction, with a band

**The with-procedure arm finds at least 0.5 more advisory defects per run, on
the mean over six runs**, where the defect was reachable from a finding the
other arm already reported. Half a defect of mean over six runs is three
defect-instances: a difference this design can see.

**Precision does not degrade by more than 5 points**, refuted-by-both, against
the without arm. A rule that manufactures chains out of nothing would show up
here, and that is the failure mode it is most likely to have.

## What refutes it

- **The means differ by less than 0.5.** The rule has no measured effect and
  does not stay in the corpus.
- **Precision drops more than 5 points.** The rule buys recall by inventing
  chains, which is worse than the miss it was written for.
- **Fewer than five runs per arm survive.** The round reports that it could not
  measure. It does not report a number from what is left.

## What each outcome forces

- **Recall holds and precision holds.** The procedure ships, and the claim
  written is exactly its scope: *one class of near-miss, at one model scale, on
  cases picked by a rule.* Not "the corpus finds more".
- **Recall refutes.** The procedure is deleted, not softened. The ledger records
  that the third attempt to move recall with knowledge also failed, and the
  `README.md` claim of parity stays as it is.
- **Precision refutes.** Deleted, and the round is cited wherever a future
  procedure proposes "look one step further" as a mechanism.
- **Both refute.** Both of the above, and the near-miss class is written up as a
  limitation of the approach rather than a gap in the corpus.

## What this round does not establish

Nothing about competitors: they are not run here. Nothing about scale: one model.
Nothing about the two cases that motivated it, which are excluded from the
primary and can only ever be an illustration.
