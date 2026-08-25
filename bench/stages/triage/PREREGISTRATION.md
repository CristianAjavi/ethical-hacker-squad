# Pre-registration — the triage stage, before anybody runs it

Committed with the cases and the key, and before a single model call. **Nothing
in this directory has been run.** There is no score anywhere in this repository
for this eval, and this file exists so that when one arrives, the reader can see
it was written against criteria that predate it.

## What is unresolved

`references/triage.md` has been in the corpus since it was written, and what it
has been measured on is **conformance**: `gate-triage-rules.sh` checks that every
procedure cites rules, that every cited id exists, and that no pack slips
backwards. All eight packs cite, 154 of 154 procedures.

None of that is evidence that the rules change an answer. A corpus can carry a
perfectly conformant discipline that no specialist actually applies, and this
project has measured exactly that failure once already: a dismissal rule landed
in the schema, the validator, `team.md` and all seven subagents, and **all three
runs failed validation because not one wrote the field.** Conformance was
complete and the intervention never ran.

So the open question is narrow: **does holding the rules file change what a
model does when somebody offers it a plausible reason not to report a finding?**

## The honest weakness, stated before the design

Three things could make a good result here mean nothing, and they are written
down now rather than after the number.

1. **The consequence column is derivable by lookup.** An arm holding `triage.md`
   can read the answer off the consequences table with no judgement at all. A
   difference on that column would measure whether an arm consulted a table, not
   whether it triaged. It is therefore a **secondary** metric and cannot support
   a claim on its own.
2. **The cases were written here.** Fifteen cases authored by the same hand that
   owns the corpus is the weakest kind of bench, and this repository has said so
   about its own rounds before. The mitigation is real but partial: the key's
   third column is forced by a file the case author does not get to reinterpret,
   and a gate proves it. The first two columns are still a judgement.
3. **This corpus leads nothing on detection, measured eighteen times.** A
   per-stage result does not transfer to the end-to-end question and will not be
   presented as though it does.

The hypothesis under test is therefore not "the corpus is better at triage". It
is: *a model given the rules file returns "could not be established" where the
evidence for an exculpation is absent, instead of accepting the exculpation.*
If it does not, the rules file is documentation and the ledger says so.

## Design

- **Two arms, byte-identical prompts**, differing only in whether
  `references/triage.md` is in context. The without arm gets `vocabulary.md`, so
  both arms know the status terms and only one knows the rules.
- **Six runs per arm.** Three cannot separate a mean on this scale; that is what
  withdrew a claim in `../../runs/2026-08-22-precision-replication/`.
- **The cases are presented from `cases.json` alone.** The key is never in the
  context of either arm, and `gate-triage-stage.sh` is the check that it did not
  leak into the cases themselves.
- **Case order is shuffled per run** with the seed recorded, so an arm cannot
  learn the shape of the set from its position in it.
- **Scoring is mechanical**, against the sealed key, on the triple
  `(rule, answer, consequence)`. No judge model, and no judgement about
  near-misses: an answer either matches the closed vocabulary token or it does
  not.
- **The author of the cases does not administer the run**, and the run records
  the commit of `cases.json` and its digest.

## What is measured

- **Primary — over-affirmation rate.** On the four cases where the honest answer
  is that the condition could not be established (`TS-04`, `TS-06`, `TS-11`, and
  `TS-13` as its contrast), the proportion of runs returning `HOLDS`.
- **Secondary — rule selection.** Proportion of cases where the rule named
  matches the key.
- **Secondary, weak by construction — consequence.** Proportion correct given
  the answer, which is a table lookup and is reported as such.

## Prediction, with a band

**The with-rules arm over-affirms on at most half as many of the four
could-not-establish cases, on the mean over six runs.** With four cases and six
runs the unit is 24 case-instances per arm, and a halving is a difference this
design can see.

**Rule selection does not degrade.** If naming a rule from a set of ten makes an
arm worse at answering, the file has bought a taxonomy and paid for it in
accuracy, and that is a result against the corpus.

## What refutes it

- **Over-affirmation differs by less than half.** The rules file does not change
  the answer at this scale, and the ledger records the second intervention in
  this corpus that was fully conformant and had no measured effect.
- **Rule selection is worse in the with arm by more than 10 points.** The file
  costs more than it returns.
- **Either arm scores near-perfectly.** Ceiling means the cases are too easy to
  separate anything, the round reports that it could not measure, and it does
  not report the difference it happened to see.
- **Fewer than five runs per arm survive validation.** The round reports that it
  could not measure. It does not report a number from what is left.

## What each outcome forces

- **Prediction holds.** The claim written is exactly its scope: *on fifteen
  cases written here, at one model scale, the rules file reduces acceptance of
  an unevidenced exculpation.* Not "the corpus triages better", and not anything
  about detection.
- **Prediction refutes.** `references/triage.md` stays — it is the vocabulary
  `gate-findings-artifact.sh` and the report contract are built on — but the
  ledger records that its effect on an answer is unmeasured and that two attempts
  to show one have now failed. No claim about triage quality is made anywhere in
  the repository.
- **Rule selection degrades.** The ten-rule taxonomy is reported as a cost, and
  the next question is whether a shorter set does the same work.
- **Ceiling on both arms.** The cases are rebuilt harder before anything is
  claimed, and this pre-registration is superseded rather than reinterpreted.

## What this round will not establish

Nothing about detection: no case here asks a model to find anything. Nothing
about scale: one model. Nothing about a competitor: none is run, and the
comparison in `README.md` is a leak measurement over a published file, not a
score against another product.
