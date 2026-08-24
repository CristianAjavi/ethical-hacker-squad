# The triage stage, measured on its own

Every round in `../../runs/` asks one question: did the squad find the defect. That
is the question that matters to a reader, and it is the reason this bench exists
end to end. It is also blunt. When a round misses, the number cannot say whether
the specialist never read the file, read it and reported nothing, or reported it
and then talked itself out of it in triage.

This directory measures the last of those three on its own.

## Why this stage and not another

`../../../skills/ethical-hacker-squad/references/triage.md` declares ten rules,
`FP-01`..`FP-10`, a closed set of four answers, and a table saying what each
answer does to the finding. It is the one stage of this corpus whose output is
already a small closed vocabulary, which makes it the one stage where a key can
be checked by something other than the person who wrote it.

That is the whole design, and it is worth stating plainly, because it is the
property a per-stage eval usually does not have:

> **The key is auditable by machine.** Nobody has to be trusted about the third
> column. `answer` comes from the four the rules file declares, and
> `consequence` is not an opinion at all — it is forced from that answer by the
> consequences table in the same file. `../../../scripts/gates/gate-triage-stage.sh`
> re-derives every one of them from `triage.md` and fails the case when the key
> and the table disagree. A key only its author can check is an opinion with a
> file name.

The derivation the gate performs, and prints on every run:

| Answer | Consequence | Where it comes from |
|---|---|---|
| `HOLDS` | `ruled-out` | *"The finding is ruled out"* |
| `HOLDS` on `FP-10` | `informational` | the same cell delegates — *"or drops to `informational` if the rule says so"* — and `FP-10` is the row that says so |
| `HOLDS` on `FP-05` | `moves` | the same delegation, exercised by the row that says *"the finding usually **moves** rather than disappearing"* |
| `DOES_NOT_HOLD` | `survives` | *"The finding survives this rule"* |
| `UNKNOWN` | `probable` | *"cannot be reported as `confirmed`; `probable` is its ceiling"* |
| `NOT_APPLICABLE` | `nothing` | *"Nothing"* |

Each override marker must appear in exactly **one** rule row. Two rows claiming
the same override is an ambiguity rather than a derivation, and the gate reports
`2` — could not measure — instead of picking one.

If somebody edits the consequences table, the gate does not quietly keep scoring
against the old one. It checks that each answer's row still contains the token
the derivation reads it for, and returns `2` when it does not.

## What is in here

`cases.json` — fifteen cases, no answers.
`keys/triage-key.json` — the sealed key: rule, answer, consequence and the
reason, one row per case, with a digest of `cases.json` so a stale key announces
itself.

One case is one triage step. A finding was raised, somebody offered a reason it
should not be reported, and the step is to name the rule that reason invokes,
answer it, and say what follows. The reason offered is always plausible — that is
the point — and in six of the fifteen it is wrong.

| Rule | Cases | Directions covered |
|---|---|---|
| `FP-01` compensating control | 1 | does not hold |
| `FP-02` value not attacker-controlled | 1 | holds |
| `FP-03` sink not dangerous as reached | 2 | does not hold · could not be established |
| `FP-04` **path not in what ships** | **3** | holds · **could not be established** · does not hold |
| `FP-05` exposure intended and bounded | 1 | holds, and the finding moves |
| `FP-06` no second principal | 1 | does not hold |
| `FP-07` data has no security value | 1 | does not apply to the class |
| `FP-08` **control outside the repository** | **3** | **could not be established** · holds · does not hold |
| `FP-09` construct is not what it looks like | 1 | holds |
| `FP-10` real but bounded | 1 | holds, downgraded rather than deleted |

Six answers are `HOLDS`, five `DOES_NOT_HOLD`, three `UNKNOWN`, one
`NOT_APPLICABLE`; all six reachable consequences are landed on at least once.

**`FP-04` and `FP-08` carry three cases each, and the gate requires that one of
each is the direction where the condition could not be established.** These are
the two rules where a model over-affirms:

- `FP-08` — *"the platform takes care of it"* is, in the rules file's own words,
  the most common way a real finding disappears. `TS-11` offers exactly that
  claim with nothing exported to support it, and the honest answer is that it
  could not be established, never that it holds. `TS-12` is the same claim with
  the ruleset export attached, and `TS-13` is the same claim with an export that
  reads against it.
- `FP-04` — the rule names the shipped artifact as the authority. `TS-06` gives a
  debug route, a default of off, and a sentence in a README saying production
  does not set the flag, and no artifact from any deployed environment. `TS-05`
  is the same shape with a listing of the published wheel that does not contain
  the module, and `TS-07` is the same listing with the module in it.

Remove either direction and the gate fails, naming the rule. That is checked by
the case `over-affirm-direction-quietly-dropped` in the battery, which mutates
the key into a row that is otherwise entirely legal — nothing but the coverage
rule can catch it.

## The other half: the answer stays out of the question

A case that contains its own answer measures whether a model can copy. The gate
rejects two families of that, and both are mechanical.

**Tokens the key declares.** A presented field may not carry the rule id, an
answer token, or the consequence terms that answer's own row names. The terms
are read out of the table rather than listed in the checker, so the gate forbids
what the key actually declares: a `HOLDS` case may not say `informational` or
"ruled out", an `UNKNOWN` case may not say `confirmed` or `probable`, and the two
rows that name no term contribute none — which the gate prints, rather than
passing them silently.

Rule ids and the underscored tokens are matched in any case. `HOLDS` and
`UNKNOWN` are matched in upper case only, and that is a decision with a
measurement behind it: `TS-02` says *"schedule.py, which **holds** the only call
sites in the tree"*, which is English. Making the match case-insensitive turns
the untouched dataset red — the battery has a case that proves it, and a rule
that fires on ordinary prose is noise rather than a control.

**A prescribed remedy.** A presented field may not tell the reader what to do
about the defect. This is not a hypothetical failure mode; see below.

Neither family is a clearance. The first catches a token and the second catches
an imperative construction. A case that gives its answer away in a paraphrase —
"the platform team confirmed it in writing", in a case whose answer turns on
nothing having arrived — passes both and needs a reader.

## Measured on somebody else's data

`google/mantis` at `56377ad9ded66e9109383ed48ddaf9c5fe150ec4` ships eight
per-stage eval sets under `reference/evals/` — calibrate, critic, deduplication,
patch, reflect, report, reproduce and review — holding **25 cases between them**,
alongside four sandbox backends under `reference/core/environments/`. That is a
finer instrument than this bench had, and it is why this directory exists.

The same leak scan this gate runs on our own cases was pointed at those eight
sets. **One row of the twenty-five would not pass it**, and it is the only one in
`patch_dataset.json`:

```
case_id                   patch_sql_interpolation
vulnerability_description "SQL string interpolation in fetch_user. Fix by using
                          parameterized query: cursor.execute("SELECT * FROM users
                          WHERE name = ?", (username,))."
```

The field naming the defect also names the fix. What that case scores is whether
a patcher applies a repair it was handed, not whether it works one out — and the
set has exactly one case, so it is the whole of that stage's dataset.

Reproduce it, with the same instrument and no copy of their data in this tree:

```
git clone --depth 1 https://github.com/google/mantis.git /tmp/mantis
EHS_MANTIS_SNAPSHOT=/tmp/mantis bash scripts/gates/gate-triage-stage.sh
```

Four things must be said about that number rather than left for the reader to
discover.

1. **Only the remedy family fires.** The token family found nothing anywhere in
   the eight sets, and could not have: their keys are not drawn from a closed
   verdict vocabulary that also appears in prose. A green from that half here is
   an inapplicable check, not a clean result.
2. **A naive version of the token family would have produced a false hit.**
   Matching every ground-truth string rather than the declared key fields flags
   `reflect_dataset.json` on the words `database` and `environment`, which are
   ordinary English. The shipped map declares which fields are the key
   (`ground_truth.expected_status`, `ground_truth.invariant`) for that reason.
3. **It is reported, never enforced.** A gate in this repository that failed
   because somebody else's file changed is a gate nobody could keep green. With
   `EHS_MANTIS_SNAPSHOT` unset the gate says the measurement was not taken, which
   is not the same as saying it was clean.
4. **Their datasets are small and so is this one.** Twenty-five cases across
   eight stages, one of them a single case; fifteen here across one stage.
   Neither number supports a claim about which product triages better, and none
   is made.

## What has not happened

**This eval has not been run.** No model has seen these cases, no score exists,
and none is claimed anywhere in this repository. Building an instrument is not
using it: running it costs model calls, and that is a spending decision for the
owner of the repository, not something a construction pass gets to make.

The procedure is written down first and frozen, in `PREREGISTRATION.md` in this
directory — what will be run, what counts as a result, what refutes it, and what
each outcome forces. A pre-registration a reader can only find after the numbers
arrive proves nothing about the order the two were written in.

## What this cannot measure

Whether a case is well chosen, and whether the rule the key names is the one a
careful reviewer would name. Both are editorial judgements; the gate checks that
the key is internally forced and honestly presented, which is a different and
smaller claim.

It also measures one stage. A squad that answers all fifteen of these correctly
and never opens the file that holds the defect scores nothing here and fails the
only question that matters, which is still the one `../../runs/` asks.
