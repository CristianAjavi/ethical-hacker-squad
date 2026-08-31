# 2026-08-27 — the decoy rate measures a fifth of what one arm reports

> **Decoy figures on this page are an upper bound.** The thirteenth round measured that a
> decoy hit was scored by LOCATION rather than by claim: **59% of this project's counted
> false positives asserted a different CWE from the one the decoy was built to provoke**,
> against 31% of `mantis`'s. Corpora before 2026-08-29 carry no `baits_cwe`, so their numbers
> cannot be recomputed and are **not** rewritten from a field invented afterwards. See
> [`../2026-08-29-baited-claim/`](../2026-08-29-baited-claim/).

**Not a round.** No arm was run for this: it is computed from the twelve reports already published
in [`2026-08-26-as-designed`](../2026-08-26-as-designed/) and
[`2026-08-27-negative-search`](../2026-08-27-negative-search/), and it was **not pre-registered.**
It is here because it changes how every band verdict in this ledger should be read.

## What was asked

The eleventh round concluded that the false-positive excess is not a property of a decoy shape,
because two rounds hit their named target and the total did not follow. The obvious next suspect
was **volume**: our arm reports far more findings, so it meets more decoys.

Across all twelve runs of both arms, findings against decoys: **r = 0.76**, slope **0.081 decoys
per additional finding**. So volume does explain most of it. But the same regression says an extra
finding brings **0.066 planted defects** — the marginal finding is likelier to be a decoy than a
defect.

That reading assumes a finding is worth nothing unless the key names it, and the next table is why
that assumption cannot stand.

## Every finding, classified

Mean per run, matched at ±6 lines:

| round | arm | on a planted defect | on a planted decoy | **outside the key entirely** |
|---|---|---|---|---|
| as designed | this project | 32.0 | 8.7 | **51.0** |
| as designed | `mantis` | 25.3 | 3.0 | 16.3 |
| negative search | this project | 27.7 | 10.0 | **30.3** |
| negative search | `mantis` | 26.3 | 5.0 | 9.0 |

Two things, and the second is the one that matters.

**The arms find nearly the same planted defects.** 27.7 against 26.3 in the eleventh round, from
68 findings against 40. The recall lead this ledger has recorded six times is real but small in
absolute terms.

**Our arm reports three times as many findings the key says nothing about** — 51.0 against 16.3,
then 30.3 against 9.0. That is the dominant difference between the two products, it is larger than
the recall gap and the decoy gap combined, and **the bench cannot say whether any of it is worth
having.**

## What this does to eleven verdicts

The band's decoy half counts findings that land on a **planted** decoy. On our arm's own numbers
that is 8.7 of 91.7 findings, and 10.0 of 68.0 — the measure sees roughly **one finding in eight**,
and is silent about the other seven.

So the decoy rate is not a precision measure. It is a measure of *how often an arm walks into a
trap the corpus author set*, which is a narrower and much easier thing to be good at. Eleven rounds
have been decided in part on it.

The verdicts are **not** revised. Every one was measured as registered, at the window fixed in
advance, and rewriting them now on an unregistered analysis is the move these pages exist to
refuse. What changes is what a reader should take them to mean.

## What it cannot conclude, said plainly

**"Outside the key" is not "false".** These corpora are plausible working services, so genuine
defects the author did not plant certainly exist in them, and a finding on one is a success the
scorer records as nothing. The 51 findings per run may be mostly value, mostly noise, or any mix.
Nothing here decides it, and any claim in either direction — including the flattering one, that our
arm is finding real defects the corpus author missed — is unsupported by this analysis.

The pooled slope also assumes the relationship is linear across two different corpora. It is
reported because the direction is consistent within each round separately; the coefficient itself
should not be quoted as a constant.

## What it forces

- **A verdict of "not supported on precision" now needs a caveat wherever it is quoted**, and the
  index carries one.
- **The next instrument change is not another triage rule.** It is a scorer that can judge a
  finding the key does not name — a second reader, blind to both the key and the arm, ruling each
  outside-the-key finding true, false, or unresolvable. Until then the bench measures a fifth of
  what one arm does and none of what makes it different.
- **The band itself may be measuring the wrong thing.** That is a product decision about who the
  squad is for, it belongs to a person, and it is recorded here rather than acted on.
