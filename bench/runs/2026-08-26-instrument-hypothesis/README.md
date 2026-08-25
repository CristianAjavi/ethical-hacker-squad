# 2026-08-26 — the round cannot answer its question, and the reason was written down first

**Arm A: 4 of 4. Arm B: 4 of 4.** The band required arm B at ≥ 3 of 4 **and arm A at ≤ 1 of
4**. Arm A found the advisory in every run without the instrument, so per
[the pre-registration](PREREGISTRATION.md) this is **the target failing to discriminate**, not
a result about the hypothesis.

> **A ≥ 2 of 4** — the target does not discriminate. The site is findable without the
> instrument, so this round cannot separate the arms. The target is then spent, the hypothesis
> is untouched, and the next round needs a different one. This outcome is not written up as a
> success for arm A.

So that is what this page does.

## What was measured

| arm | what it got | advisory | class-level | claims |
|---|---|---|---|---|
| **A — procedure** | the corpus as of `main` | **4 / 4** | 4 / 4 | 59 |
| **B — instrument** | the same corpus, step 0 running `log_escaper.py` | **4 / 4** | 4 / 4 | 66 |

Every run in both arms matched `CKAN-01` — `ckan/views/user.py`, `RequestResetView.post`, the
`log.info(...format(id))` the fix commit replaces with `repr_untrusted`. Eight runs, eight hits.

## The failure mode was predicted before the arms ran

From the pre-registration, written before any run and pushed before any arm started:

> One property is recorded now because it cuts against the hypothesis and must not be
> discovered later as a convenience: the defect sits in an **authentication route**
> (`/user/reset`), which is where auditors gravitate. On `pyload` the advisory sat in the RPC
> layer, and three rounds diagnosed that as why it was walked past. So this target is, if
> anything, *easier* for the arm without the instrument.

It was. That is the whole result. **The target was chosen badly, and the pre-registration says
so in its own words rather than the results page discovering it afterwards.**

## What this does and does not license

- **The instrument hypothesis is untouched.** Not supported, not refuted. A round where both
  arms saturate measures nothing about the difference between them.
- **This is not a favourable result for arm A**, and the pre-registration forbids reading it as
  one. Arm A's 4 of 4 was the registered quantity, so reporting it is not fishing — but a rate
  on a target that both arms saturate says the target was easy, not that the procedure is good.
- **No ranking.** No competitor arm ran. Nothing here compares this product to any other.
- **CKAN is retired for this intervention**, per the multiplicity commitment, whatever anyone
  would like a second run to show.

## What it is consistent with, and what that is worth

Three rounds diagnosed the residual failure as **ranking** — the auditor holds a list
containing the site and walks past it because an RPC method for adding a package does not look
like an attack surface. On a target where the defect sits exactly where auditors already look,
both arms found it in every run.

That is **consistent** with the ranking diagnosis and is **not a test of it**. It was not
pre-registered as a prediction, no arm was constructed to vary location, and one target cannot
separate *where the defect sits* from *everything else different about CKAN*. It is written
here so the next round can register it, and it is worth exactly what an unregistered
consistency is worth.

## What the next round has to change

A target whose defect of this class sits **away from** the surfaces an auditor gravitates to —
a background worker, an RPC layer, an admin path, an import routine. `pyload` was exactly that
and is retired. Finding another is the work, and the round is not worth running until one
exists: repeating this design on another auth-route advisory would produce another 4/4 and
another page saying nothing.

## What ships

All eight reports in `reports/`, each with the `provenance` block the scorer requires. The key
is [derived from the public fix commit](key.json) and was committed while the arms ran. The
[scorer](score.py) was exercised on synthetic reports — including a hit by symbol, a hit by
line range, a same-class miss in another file, and a report with no provenance — and committed
before it saw a real one. The round's [limits](LIMITS.md), including the fact that the blind is
structural rather than perfect, were committed before the scorer ran.
