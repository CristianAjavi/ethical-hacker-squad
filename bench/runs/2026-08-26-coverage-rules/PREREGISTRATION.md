# Pre-registration — do the coverage rules close the eight points?

Written and pushed **before any arm runs, and before the author of this file has seen the
corpus**. Nothing below is edited afterwards.

## What is being tested

On 2026-08-26 this project lost to `google/mantis` by **8.3 points of recall** across eleven
vibecoded products. The loss was diagnosed mechanically, not by hypothesis:

- **3 defects** sat outside this project's reach across all four runs.
- The rest was **depth per file**: on the 14 files carrying more than one planted defect, this
  project reported **2.05 findings per file against 2.50**, reaching two or more findings in
  **8.8 of 14 files against 11.5**.

`references/coverage.md` was added in response — `COV-01` a file that produced a finding is not
done, `COV-02` manifests and configuration are enumerated key by key, `COV-03` declare per file
how many distinct defects you looked for. **Whether that works is unmeasured.**

## The corpus

Six services, 28–34 planted defects and 20–26 decoys, written **by an author with no access to
this project's procedures** and instructed not to read them. Defects derive from real CWE
classes rather than being invented, and the brief required **at least 8 files carrying more
than one independent defect, at least 3 carrying three or more**, several of them in manifests
and configuration.

That last requirement is the property under test, and it was specified **before the corpus was
written and before this file's author saw it**. The key lives outside the tree.

The eleven-product corpus is **not re-used**: it is retired for this question, and re-running it
after a change would be exactly the fishing these pages refuse.

## Arms

| arm | what it is | runs |
|---|---|---|
| **ours** | this project at the branch head, with `coverage.md` cited by all seven auditing roles | 4 |
| **`mantis`** | `google/mantis` @ `56377ad` through `mantis-meta-agent`, its own entry point | 4 |

## Band, and the fact that it is lower than last round's

Last round required this project to lead by **≥ 15 points** to be called the best. That band
asked *"are we so far ahead it is not close"*, and the answer was no — a competitor led.

This round asks the smaller question: **are we ahead at all.** So:

- **Supported** — this project is the better of the two on this corpus — if its recall exceeds
  `mantis`'s by **≥ 5 points** *and* its decoy rate is **not higher**.
- **Refuted** if `mantis`'s recall is **greater than or equal to** this project's.
- **Inconclusive** if this project leads by **less than 5 points**: ahead, but not by a margin
  this round can separate from run-to-run variation. Last round the arms ranged 78–81 and
  81–94, so five points is inside one arm's own spread.

**Lowering a threshold between rounds is how a goalpost moves, so it is stated rather than
performed.** A result meeting this band means *"ahead on this corpus"*, not *"far ahead"*, and
no sentence may upgrade it. If the band is met, the honest claim is the narrow one.

## The registered mechanism test — this is the one that matters

`COV-01`/`COV-02` predict a specific, measurable change, and it is registered **with** a band:

> On the files carrying more than one planted defect, this project's **findings per file** is
> **≥ `mantis`'s**, and it reaches two or more findings in **≥ as many** of those files.

If overall recall improves while *this* does not, the improvement came from something else and
the rules are not what fixed it. That is the outcome most worth catching, because it is the one
that would otherwise be quietly credited to the change.

## Registered secondaries, without bands

- **decoy rate** — the one column this project led (0.25 against 1.00). `coverage.md` says in
  its own text that it is not a licence to report more. If the decoy rate rises, the rules
  bought recall with noise and that trade is reported as a cost, not buried.
- **per-file density declarations** (`COV-03`) — whether the arm actually declares them.
- **cost** — `mantis`'s slowest run took 70 minutes and 682 tool calls. Wall time and tool
  calls per run are recorded for both arms. Winning by spending six times as much is not
  winning, and the number goes on the page either way.

## Scoring

`scripts/bench/score.py` against the corpus key, the same matching rule as every prior round,
with `adapt.py` supplying the `status` default over **every** arm with no per-arm branch.
Validity floor: **3 valid runs**. Fewer is `2`, could not measure.

## Multiplicity

One round. Whatever the outcome, this corpus is **retired for this question**. If the rules are
refuted they are refuted; if they are supported, the next step is a corpus this project's
author did not commission.
