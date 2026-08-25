# 2026-08-25 — the same advisory, with the step where the agent starts


> **Scoring note, added 2026-08-26.** The reports in this directory were transcribed by the
> orchestrator from what each arm returned, not written by the arms themselves, so they carry
> no provenance block. `scripts/bench/score_blind.py` now refuses to score an untraced report
> by default; reproducing this round's numbers needs `--allow-untraced`. That flag is not a
> convenience — it is the record that these particular artefacts passed through a person's
> hands, and the reason it exists is on the scorer's own page.

**Refuted. 0 of 4, against a band of 3 of 4.** Three rounds have now failed to move this,
and per the multiplicity commitment made before the run, **this target is retired for this
intervention.** The position published in
[`../2026-08-25-external-log-injection/`](../2026-08-25-external-log-injection/) stands: on
this class, on real code, this corpus does not lead.

## What was measured

| | the advisory | total claims |
|---|---|---|
| band, committed beforehand | ≥ 3 of 4 | > 15 |
| measured | **0 of 4** | 30 |

The second condition passed: 30 claims across four runs, against 25 and 24 in the two rounds
before. The step did not narrow the audit to buy one defect. It simply did not buy that one.

## The observation this round is not allowed to claim

Across the three variants, one number moves cleanly:

| variant | runs reporting **any** log-injection site | the advisory |
|---|---|---|
| no step 0 | 1 of 4 | 0 of 4 |
| step 0 inside the pack | 2 of 3 | 1 of 3 |
| step 0 at the agent's entry point | **4 of 4** | 0 of 4 |

Every run in this round found log injection. Three found the same pair the corpus had never
reported before: `X-Forwarded-For` logged raw in **both** login routes, on the same line where
the username beside it is explicitly stripped of `\r\n`. That is a real defect of exactly the
class, in real code, surfaced by the step.

**It is not this round's result and it does not go in the README.** Class-level detection was
never pre-registered — the advisory was — and reading a favourable unregistered number after
seeing it is the fitting these pages exist to refuse.

### Retired on 2026-08-26, and it took two corrections to get there

The observation was checked rather than carried, and it did not survive either check.

**The `4 of 4` was not 4 of 4.** It came from a pattern that counted any title containing
`Forwarded`. Under a stricter reading — a finding that names log injection, forging,
unsanitised or unneutralised output, or lands in a logging module — the same four runs give
**3 of 4**. The number moved because *an unregistered metric has no fixed definition*, so it
can be read favourably without anyone deciding to. That is not a hypothetical failure mode:
it happened here, in this repository, to the person writing this page.

**And it does not replicate.** The same variant, on Django, detects the class in **1 of 4**
runs — see [`../2026-08-26-ranking-hypothesis/`](../2026-08-26-ranking-hypothesis/). Whatever
the enumeration step does on a 569-file tree, it does not do it at 2,839 files.

So the observation is retired here rather than left as a promising lead for a round to
rediscover. Its only durable value is the lesson: **a number you did not pre-register is a
number whose definition you get to choose after seeing it.**

## What the three rounds together diagnose

The failure moved twice, and each move was measured rather than argued:

1. **First diagnosis — the procedure does not describe the defect.** Wrong: the same
   procedure found the class 6 of 6 on a seventeen-file tree.
2. **Second diagnosis — targeting; the auditor never opens the file.** Half right. Adding
   enumeration moved class detection from 1 of 4 to 2 of 3, and the advisory from 0 to 1.
3. **Third diagnosis — delivery; the step is prose the auditor may skip.** Also half right.
   Moving it to the entry point took class detection to 4 of 4 — and the advisory to zero.

What is left is **neither describing nor enumerating. It is ranking.** The list contains the
site; every arm, in every round, walks past it. All twelve runs in this round and the last
gravitate to the web UI — `cnl_blueprint`, `config.py`, the login routes — while the advisory
sits in the RPC layer, `core/api/__init__.py`, reachable with the base permission for adding
a download. An auditor that must choose among 218 named sites chooses the ones that look like
an attack surface, and an RPC method for adding a package does not.

That is a hypothesis with three rounds behind it and **no pre-registration**, so it is the
next round's question and not this one's answer. The next round also has to change the
target: retrying this one would be the fishing this page refused.

## What ships

All four reports in `runs/`. The key is a public commit. The target was copied out of the
repository with `.git` absent.
