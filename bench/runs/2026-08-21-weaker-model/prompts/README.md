# The prompts, verbatim

`corpus-arm.txt` and `no-corpus-arm.txt` are taken **unchanged** from `../../2026-08-21-unaided-pass/prompts/`, which is what the pre-registration committed to: the only variable in this round is the model. The corpus-arm file is the no-delegation variant, because both arms carried that sentence here.

`judge.txt` is what all six blind ground-truth judges received, identical for every run. The two defect descriptions are inside each batch file rather than the prompt; they were written to name the mechanism using no phrase that appears in either arm's output, so a judge cannot match on vocabulary.

One asymmetry this round inherits and does not fix: neither prompt says whether consulting sources outside the target is allowed. That gap is recorded in `../2026-08-21-unaided-pass/ROUND-NOTES.md` and is open work.

## Outside information: unstated in this round

Neither run prompt here says whether consulting sources outside the target is allowed, and at least one run in this family did consult them — one unaided run diffed the target against upstream `main`, one corpus run cited CVE identifiers. **Recall numbers from this round therefore measure review and library familiarity together, and cannot separate them.** Consistency is unaffected: it compares runs of one arm, and both of them had the same latitude. `../../prompts/external-sources.txt` is the clause that closes this for later rounds; it did not exist when this one ran.
