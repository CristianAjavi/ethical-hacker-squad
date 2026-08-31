# 2026-08-25 — three arms on the vibecoding case


> **Scoring note, added 2026-08-26.** The reports in this directory were transcribed by the
> orchestrator from what each arm returned, not written by the arms themselves, so they carry
> no provenance block. `scripts/bench/score_blind.py` now refuses to score an untraced report
> by default; reproducing this round's numbers needs `--allow-untraced`. That flag is not a
> convenience — it is the record that these particular artefacts passed through a person's
> hands, and the reason it exists is on the scorer's own page.

**The round could not answer the question it was built for**, and the reason was
pre-registered as a refutation criterion before either competitor arm ran. The numbers that
*did* come out are favourable to this project and are reported as weak, because that is
what [the pre-registration](PREREGISTRATION.md) committed to calling them.

## The question, and why it has no answer here

`P-52` — `record_submission`, the deferred `%s` idiom — was matched in 0 of 6 runs by this
corpus, with all six naming it as the example of doing it right. A miss by one product is a
defect in that product. A miss by every product is a property of the class. The round
existed to decide which.

| arm | runs | `P-51` (the concatenated neighbour) | `P-52` |
|---|---|---|---|
| this corpus | 6 | **6 / 6** | 0 / 6 |
| `Tencent/AI-Infra-Guard` @ `32df94d` | 4 | **0 / 4** | 0 / 4 |
| `google/mantis` @ `56377ad` | 4 | **1 / 4** | 0 / 4 |

`P-52` is zero everywhere. **It does not follow that the class is a field-wide blind spot**,
because the pre-registration fixed the engagement test in advance:

> A competitor reports neither `P-51` nor `P-52` in a majority of runs. That arm did not
> reach the file and its zero on `P-52` is not evidence. The round reports the arm as not
> measuring rather than as agreeing.

Neither competitor arm reached `app/audit.py` in a majority of its runs. Both zeros are
therefore silence, not agreement, and **the question stays open.**

The one run that did reach the file is worth reading rather than counting: `mantis` run 3
reported `P-51` and named `record_export` — the `json.dumps` twin — as the safe contrast,
without mentioning that `record_submission`, two lines above it, carries the same defect.
That is the same reading this corpus's six runs made. **One run is an anecdote and it is
recorded as one.**

## What was measured, and it is weak on purpose

| arm | recall over 11 planted | hiding-class recall | decoy rate | runs returning nothing |
|---|---|---|---|---|
| this corpus | **0.83** | 1.00 (6/6 runs) | 0.02 | 0 of 6 |
| `AI-Infra-Guard` | 0.48 | 1.00 (4/4 runs) | 0.03 | 0 of 4 |
| `mantis` | 0.20 | 0.50 (2/4 runs) | 0.00 | **2 of 4** |

The pre-registration says what this is worth:

> A comparison of recall on a case this project planted is worth very little: the plant was
> written by the same hand that wrote the procedures.

So: **no claim of superiority is made from this table**, and none belongs in the README.
The eighteen prior measurements saying this corpus leads nothing on detection are untouched
— and the round that matters for that question ran against `Netflix/lemur`, code nobody
here wrote, where every arm scored 0 of 4.

Two of `mantis`'s four runs returned an empty array. A product that reports nothing has
perfect precision and no recall, which is why the decoy rate is never printed without
recall beside it.

## A defect in the scorer, found by running it

`scripts/bench/score_blind.py` had the previous round's floor — five valid runs — as a
module constant. This round pre-registered **three** per competitor arm, and the scorer
refused to measure four valid runs against a threshold that belonged to a different round.
The floor is now a parameter supplied per round.

This is not a threshold moved after seeing data: three was written in this round's
pre-registration, committed and pushed before either competitor ran. What changed is that
the script stopped overriding it.

## What this forces

- **The `P-52` question needs an arm that reaches the file.** Pointing a competitor at
  `app/audit.py` specifically would answer it, and would also destroy the blind. The next
  round has to solve that, and neither zero here counts until it does.
- **[Issue #53](https://github.com/CristianAjavi/ethical-hacker-squad/issues/53) stays open
  and its framing stands**: a false negative in this product, measured against a prediction
  that predates it. What this round removes is the temptation to call it the field's
  problem rather than ours.
- **Nothing in the README changes.** A favourable table on a case we planted is not a
  ranking, and this page does not pretend otherwise.
