# Pre-registration — three arms on the vibecoding case, before the new ones run

Committed **before either competitor arm is run**. This corpus's six runs are already
published in [`../2026-08-25-vibecoding-blind/`](../2026-08-25-vibecoding-blind/) with their
own pre-registration, their reports and their score; nothing about them is re-judged here
and nothing about them is changed by what this round finds.

## What is unresolved

The previous round measured one arm and found something that only means anything if it is
compared: **`P-52` was matched in 0 of 6 runs, and all six cited it as the example of doing
it right.** It is `record_submission` — the deferred `%s` idiom every linter asks for —
and the probe shows one call still emits two lines in a line-oriented log.

A miss by one product is a defect in that product. A miss by every product is a property of
the class, and that is a different claim entirely. Nothing decides which without the other
arms.

## The question, and it is not recall

**Does any other product report `P-52`?**

Overall recall is reported because it must be, but it is not what this round is for. A
comparison of recall on a case this project planted is worth very little: the plant was
written by the same hand that wrote the procedures. `P-52` is different, because the miss
came with a *reason* — six auditors naming it as the safe pattern — and that reason has
nothing to do with who planted it.

## The honest weakness, stated before the design

1. **This project wrote the case.** Any arm-versus-arm number on recall inherits that, and
   a favourable one is weak evidence. This is why the round's question is a single defect
   and not a scoreboard.
2. **The corpus arm was run first, and with its own prompt.** The competitor arms follow
   their own pipelines, as the external rounds in this corpus have always done. The arms
   are therefore not prompt-matched, they are product-matched, and no arm's number here is
   a like-for-like of another's.
3. **A competitor finding `P-52` is the outcome that costs this project most**, and it is
   named here, before the run, as a live possibility rather than something to explain away
   afterwards.

## Design

- **The same blinded tree**, byte-identical to the one the first round used: the case copied
  out of the repository, `bench/ground-truth.json` unreachable, the `Bench case` line
  removed from its README.
- **Arms**
  - `this corpus` — six runs, already published, not re-run.
  - `Tencent/AI-Infra-Guard` at `32df94d`, running its own `skill-scan` three-stage
    pipeline from its own written instructions.
  - `google/mantis` at `56377ad`, running its own `mantis-advise` skill from its own
    written instructions.
- **Four runs per competitor arm**, matching the count the external rounds in this corpus
  used for competitor arms.
- Each arm is told what it audits and nothing else: not which file, not that anything was
  planted, not that a comparison exists.

## Scoring, unchanged from the first round

`scripts/bench/score_blind.py`, the same matching rule: a finding matches when it names the
same file AND either the same symbol or a line inside the planted range. No near-miss
handling. The decoy rate is printed beside recall and there is no way to print one without
the other.

## Prediction, with a band

**No competitor arm reports `P-52` in any run — 0 of 4 for both.** The reason the corpus
arm missed it is not a corpus property: the `%s` idiom reads as the remediation, and a
product that recognises the idiom stops there.

**Both competitor arms report the concatenated neighbour `P-51` in at least half their
runs.** If they do not report either half of the pair, the arm did not engage the file and
the `P-52` result from it says nothing.

## What refutes it

- **A competitor reports `P-52` in any run.** The miss is this project's, not the field's,
  and the round says so in those words. `WEB-28` is then measured as insufficient and the
  issue for it changes from "a field-wide blind spot" to "we are behind on this class".
- **A competitor reports neither `P-51` nor `P-52` in a majority of runs.** That arm did
  not reach the file and its zero on `P-52` is not evidence. The round reports the arm as
  not measuring rather than as agreeing.
- **Fewer than three runs per arm produce a parseable report.** That arm could not be
  measured, and no number is reported from what is left.

## What each outcome forces

- **Prediction holds.** The claim is exactly: *on one case planted here, no product tested
  reports a defect written in the shape of its own remediation.* That makes `P-52` a
  property of the class worth publishing as a bench instrument — and it still says nothing
  about which product detects better overall.
- **Prediction refutes.** The finding becomes a deficiency of this corpus, published as
  such, and the comparative table lands in `docs/competitive-analysis.md` with this project
  behind on the axis it chose to be measured on.
