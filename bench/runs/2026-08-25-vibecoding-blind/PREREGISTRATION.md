# Pre-registration — a blinded audit of the vibecoding case, before anybody runs it

Committed **before a single model call**. Nothing in this directory has been run at the
time this file lands, and it exists so that when a number arrives the reader can see it was
written against criteria that predate it.

## What is unresolved

`intake-portal` was added to the corpus on 2026-08-25 as the case whose defects belong to
the generator rather than to the surface. Eleven planted, eight decoys. Six of the eleven
now carry an executable probe, so **it is established that those six reproduce**. Nothing
is established about whether an audit *finds* them, which is the only question a buyer
asks.

Four of the eleven — `P-44`, `P-48`, `P-49`, `P-50` — are one class: **a control that runs
and cannot fail**. The HMAC is imported, computed and assigned, and never compared; the
guard takes the caller id and returns `True`. On the same day, `WEB-27` entered the corpus
as the procedure written against exactly that class.

So the question is narrow and it is about the intervention that shipped today:
**does a blinded audit of this tree report the class that hides?**

## The honest weakness, stated before the design

1. **The cases were planted here.** Eleven defects authored by the same hand that owns the
   corpus is the weakest kind of bench, and this repository has said so about its own
   rounds before. Nothing about this round fixes that.
2. **One arm.** There is no competing product in this round, so nothing here supports a
   comparative claim. This measures whether the corpus finds its own plant, which is a
   floor and not a ranking.
3. **`WEB-27` was written by the same effort that planted the case.** A procedure written
   against a defect that the same day's work planted is the friendliest possible test of
   it. A pass here is weak evidence; a failure is strong evidence, and that asymmetry is
   declared now rather than discovered later.

## Design

- **The tree is copied OUT of the repository** before any run, into a directory that
  contains the case and nothing else. `bench/ground-truth.json` is not reachable from it.
  This is a structural blind rather than the declared one prior rounds used, and it is
  stronger; the OUTSIDE INFORMATION clause is carried as well.
- **Six runs.** Three cannot separate anything at this scale — that is what withdrew a
  claim in `../2026-08-22-precision-replication/`.
- **Each run is a fresh auditor** with no memory of the others and no access to this file.
- **The prompt does not name the corpus, the squad, the case, or that anything was
  planted.** It asks for a security review of a tree.

## Scoring, fixed before the run

A reported finding **matches** a planted defect when it names the same file AND either the
same symbol or a line inside the planted range. Nothing else counts: not a finding of the
right class in the wrong file, not a general remark about the file.

- **Recall** — planted defects matched, over 11.
- **Hiding-class recall** — matched among `P-44`, `P-48`, `P-49`, `P-50`, over 4. This is
  the primary.
- **Decoy rate** — of the 8 decoys, how many are reported as findings. A run that reports
  everything scores perfect recall and is worthless, so this is reported beside recall and
  never without it.

## Prediction, with a band

**The hiding class is reported in at least four of the six runs, and at least two of its
four members are matched on the mean.** The procedure that entered the corpus today names
this class explicitly, so anything less means the procedure did not change what an auditor
looks at.

**The decoy rate stays below half.** If an auditor reports four or more of the eight decoys
per run, the recall number is bought with noise and is not evidence of anything.

## What refutes it

- **The hiding class is reported in fewer than four runs.** `WEB-27` is documentation. The
  ledger records the third intervention in this corpus that was written, conformant, and
  had no measured effect on an answer.
- **The decoy rate reaches half.** The round reports precision as the finding and does not
  report recall as a success.
- **Fewer than five runs produce a parseable report.** The round reports that it could not
  measure. It does not report a number from what is left.

## What each outcome forces

- **Prediction holds.** The claim written is exactly its scope: *a blinded audit of one
  case planted here reports the class it was pointed at.* Not "the corpus detects better",
  and nothing about any other product. The eighteen prior measurements that say this corpus
  leads nothing on detection stay exactly where they are.
- **Prediction refutes.** `WEB-27` stays in the corpus — a procedure can be right and
  unread — but the ledger records that its effect is unmeasured, and the next round tests
  the procedure's *delivery* rather than its text.
