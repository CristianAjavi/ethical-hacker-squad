# Pre-registration — does the join move composition detection?

Written and pushed before any run.

## What this is, and what it deliberately is not

The composition round measured a forty-point collapse on defects where no single file is wrong:
both arms ~100% on single-file defects, **62.5% and 60.4% on composition**. `path_coverage.py`
was built for one shape of that gap — a control and its coverage declared in different places,
with nothing checking that the coverage covers.

**This is a within-arm measurement, not a ranking.** Same corpus, same key, this project's arm
only, with the tool against without it. It cannot and does not say anything about `mantis`, and
no sentence from it may be used to compare.

That distinction is what makes re-using the corpus legitimate. Its page said, before today's
outcome was known:

> this corpus is retired for the ranking question. It is **not** retired for the composition
> question, which it was built to open rather than to close.

Re-running it for the ranking question would be the fishing these pages refuse. Re-running it
for the question it was reserved for is what the reservation was for.

## Arms

| arm | what it is | runs |
|---|---|---|
| **without** | the four runs already published in `../2026-08-27-composition/runs/ours-*.json`, which ran before the tool existed | 4, stored |
| **with** | the branch head, where `path_coverage.py` ships and all seven auditing roles cite it | 4, new |

The stored arm is not re-run. It is the same corpus, the same prompt and the same procedure
minus one tool, which is exactly the comparison.

## Band, committed now

- **Supported** — composition recall rises by **≥ 8 points** (62.5% → ≥ 70.5%), **and** the decoy
  rate does not rise by more than 1.0 per run, **and** single-file recall does not fall.
- **Refuted** — composition recall does not rise, or rises while the decoy rate rises by more
  than 1.0.
- **Could not measure** — fewer than 3 valid runs.

Eight points is roughly two of the 24 composition defects. It is set there because the tool
names one shape of the class, not the class: three of six services in this corpus express their
guards in forms it cannot read — nginx `allow`/`deny`, Koa middleware, CDK policies — so a
ceiling well below the full 37.5-point gap is expected from the start, and pretending otherwise
would make the band unfalsifiable in the flattering direction.

## The outcome most worth catching

**Composition recall rises and the decoy rate rises with it.** The tool emits `DEAD GUARD` and
`UNGUARDED` as a *worklist*, and its own header says a dead guard can be dead on purpose. If
the arm reports the worklist rather than working it, this repeats the coverage-rules round —
recall bought with noise — and it must be called that, not a win.

Registered without a band: how many of the arm's findings cite a `DEAD GUARD` or `UNGUARDED`
line, and how many of those land on a keyed defect against a decoy. That is the tool's own
precision inside a real run, which no measurement so far has.

## Scoring

`../2026-08-26-coverage-rules/score.py`, unchanged, with the split by `kind` computed from the
key's own `kind` field. `adapt.py` over every report with no per-arm branch.

One round. Whatever the outcome, **this corpus is then retired for the composition question
too**, and the next measurement of it needs a composition defect from a published advisory.
