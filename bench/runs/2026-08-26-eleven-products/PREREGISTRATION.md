# Pre-registration — eleven vibecoded products, three arms, one question

Written and pushed **before any arm runs**. Nothing below is edited afterwards.

## The question, in the words it was asked

*"Is this already the best hacker repo for different products or services built with
vibecoding?"*

Every prior round measured **one** target. This is the first that measures **eleven distinct
products** against **two competitors at their current HEADs**, which is what the question
actually asks and what no page in this repository can currently answer.

## The corpus under audit

`bench/cases/` — eleven products, 73 files, written as vibecoded services would be:

`analytics-service` · `certs-authz` · `cli-packer` · `express-invoices` · `gateway-limits` ·
`intake-portal` · `node-supply` · `pipelines-migration` · `rag-agent` · `terraform-platform` ·
`wire-decoder`

**54 planted defects and 50 decoys**, keyed in `bench/ground-truth.json`. The tree is copied
out so the key is not reachable from it, and `gate-bench-blinding.sh` passes on the case tree.

## Arms

| arm | corpus | commit |
|---|---|---|
| **ours** | this repository | the branch head under test |
| **AI-Infra-Guard** | `Tencent/AI-Infra-Guard`, its own `skill-scan` | `32df94d` |
| **mantis** | `google/mantis`, its own `mantis-advise` | `56377ad` |

Both competitor commits were checked on the day of the round and are each project's **current
HEAD**, not a stale snapshot. Measuring a "we are best" claim against an old version of someone
else's work would be worthless, and this is written down so the check can be re-run.

**4 runs per arm, 12 runs.** Each run audits the whole eleven-product tree, because that is how
a user points a squad at a repository — not at a curated file.

## Band, committed now

**Supported** — this project is the best of the three on this corpus — only if **all** hold:

1. our recall over the 54 planted exceeds **each** competitor's by **≥ 0.15 absolute**, and
2. our decoy rate is **not more than 0.05 above** the best competitor's, and
3. **≥ 3 valid runs** in every arm.

**Refuted** if any competitor's recall is within 0.05 of ours or higher.
**Could not measure (2)** if any arm has fewer than 3 valid runs.

Condition 2 is not decoration. Recall bought by reporting everything is not detection, and a
product that reports nothing has perfect precision and no recall — which is why the two numbers
are only ever read together, and why an arm's empty runs are counted and printed.

## The limit this round cannot escape, stated before the numbers exist

**This project wrote the cases, planted the defects and wrote the key.** Every prior page that
reported a favourable number on this corpus said the same thing, and it is not weakened by
being repeated:

> A comparison of recall on a case this project planted is worth very little: the plant was
> written by the same hand that wrote the procedures.

So the strongest sentence this round can license, if the band is met, is bounded to exactly
this: *on an eleven-product corpus this project wrote, keyed by this project, against these two
competitors at their current HEADs, on this date.* **It is not "the best" without those
qualifiers**, and no README line may drop them.

The independent evidence points the other way and is not superseded by anything here: on
`pyload`, Django and `Netflix/lemur` — code nobody here wrote — every arm including ours scored
at or near zero. A favourable result here does not overturn those pages; it sits beside them,
and the honest reading of the pair is that this project leads on corpora it authored and has
not shown it leads anywhere else.

## Secondary, registered now so reading it later is not fitting

- **empty runs** per arm — an arm returning nothing has perfect precision and no recall.
- **per-product recall** — whether any arm is strong on some products and blind on others.
  Registered without a band; it may be reported and may not be used to rescue a refuted primary.

## Scoring

`scripts/bench/score.py` against `bench/ground-truth.json`, the same scorer and the same
matching rule as every prior round, with the validity floor set to 3. Every arm writes a
`provenance` block; nothing is hand-transcribed.

## Multiplicity

One round. Whatever the outcome, **this corpus is retired for the "are we the best" question**
and will not be re-run to move a number. If the answer is favourable, the next step is not
another run here — it is a corpus this project did not write.
