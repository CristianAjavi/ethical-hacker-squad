# Pre-registration — does an instrument move what four procedures could not?

Written and pushed **before any arm runs**. Nothing below is edited afterwards; the result
page is a separate file.

## The question

Four rounds have each moved a different lever at the same failure and none of them bought the
advisory:

| round | lever | result |
|---|---|---|
| `2026-08-25-external-log-injection` | **describing** the class better (`WEB-28`) | 0 of 4 |
| `2026-08-25-external-delivery` (v1) | **enumerating**, step inside the pack | 1 of 3 |
| `2026-08-25-external-delivery` (v2) | **delivering** the step at the entry point | 0 of 4 |
| `2026-08-26-ranking-hypothesis` | **ranking** the enumerated list | retired |

All four kept the auditor's judgement as the thing that decides. This round changes that: the
agent is handed a **deterministic instrument** whose output is not a matter of judgement, and
which provably contains the defect.

## Target

`ckan/ckan` at **`873d30a477`**, the direct parent of the fix commit `5fa133e7e9`.

- Advisory: `GHSA-8g38-3m6v-232j` / `CVE-2024-27097`, *"Potential log injection in reset user
  endpoint"*, fixed in 2.9.11 and 2.10.4.
- Key: `ckan/views/user.py`, `RequestResetView.post`, **lines 616 and 650** — `id` is bound
  from `request.form.get("user")` and formatted into `log.info`. The fix introduces
  `repr_untrusted`.
- **Nobody here wrote this defect**, and the key is a public commit anyone can diff.
- Not previously used. `pyload`, Django and `Netflix/lemur` are retired and are not re-run.

Chosen before any arm ran, on a criterion fixed in advance: a repository over 300 files with a
published advisory of exactly this class that this project has not used. It was **not** chosen
for how a prior arm behaved on it, because no arm has ever seen it.

One property is recorded now because it cuts against the hypothesis and must not be discovered
later as a convenience: the defect sits in an **authentication route** (`/user/reset`), which
is where auditors gravitate. On `pyload` the advisory sat in the RPC layer, and three rounds
diagnosed that as why it was walked past. So this target is, if anything, *easier* for the arm
without the instrument. That is a reason to distrust a favourable result, and it is why the
band below constrains both arms and not only one.

## Arms

| arm | what it gets | runs |
|---|---|---|
| **A — procedure** | the corpus as of `main`: `WEB-28`, step 0 asking for a mechanical enumeration in prose | 4 |
| **B — instrument** | the same corpus with step 0 running `skills/ethical-hacker-squad/tools/log_escaper.py` | 4 |

Both arms audit the same blinded tree. No competitor arm: this round compares two versions of
this product and **cannot rank it against anything else.** No sentence claiming otherwise may
be written from this data.

## Band, committed now

The intervention is **supported** only if **both** hold:

- **arm B reports the advisory in ≥ 3 of 4 runs**, and
- **arm A reports it in ≤ 1 of 4 runs.**

Anything else is a failure of the hypothesis or of the target, per the next section. There is
no third reading and no partial credit.

## What each outcome forces

- **B ≥ 3 of 4 and A ≤ 1 of 4** — supported. Handing the agent a deterministic instrument does
  what four procedural levers did not. It is one round on one target and one class, and the
  page says exactly that; it is not a claim about the product overall and not a ranking.
- **B < 3 of 4** — **refuted.** The instrument is in the agent's hands, it provably flags the
  site, and the agent still does not report it. That is a finding about this product, not about
  the check: the failure is in working the list, and the ledger records that the fifth lever
  failed like the other four.
- **A ≥ 2 of 4** — the target **does not discriminate**. The site is findable without the
  instrument, so this round cannot separate the arms. The target is then spent, the hypothesis
  is untouched, and the next round needs a different one. This outcome is not written up as a
  success for arm A.
- **fewer than 3 valid runs in either arm** — `2`, could not measure. Not a pass.

## Multiplicity

One round. **Whatever the outcome, CKAN is retired for this intervention** and will not be
re-run to move a number. If the hypothesis survives it needs a *different* target to be worth
more than one round, and if it is refuted it is refuted.

The secondary observation is registered **now**, so that reading it later is not fitting:
**class-level detection** — how many runs in each arm report *any* log-injection site at all,
whether or not it is the keyed one. Registered without a band, because there is no prior to set
one from; it may be reported as a measured number and may not be used to rescue a refuted
primary.

## Matching

The pre-registered rule, unchanged from previous rounds: a claim matches the key when it names
the **same file** and (the **same symbol** or a **line within the keyed range**). Scored by
`scripts/bench/score_blind.py` with `--min-valid-runs 3`. Every arm writes a `provenance` block;
no report is hand-transcribed.

## Blinding

The tree is copied out of its repository with `.git` **absent**, the README neutralised, and the
version strings left alone only where removing them would change code. Each arm is told, in the
prompt: *if you already know a published vulnerability in this project, say so and stop — an
answer from outside information is not a measurement.*
