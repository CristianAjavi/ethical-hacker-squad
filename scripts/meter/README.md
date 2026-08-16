# The meter

`scripts/meter/meter.sh` prints the real state of this project as numbers, today,
from the files on disk. It is not a dashboard design and not a plan: run it and it
produces the figure.

```bash
scripts/meter/meter.sh              # human table
scripts/meter/meter.sh --json       # machine-readable, same numbers
scripts/meter/meter.sh --no-gates   # skip the slow part (declared as a hole, not a pass)
scripts/meter/meter.selftest.sh     # 21 negative cases; the meter measured against itself
```

It also runs on every push and pull request, in the `meter` job of
`.github/workflows/ci.yml`, which publishes the table to the run summary and
uploads the JSON. **That job is not a gate**: it is not in
`promotion.required_contexts`, and the meter's own verdict never fails it. Only
the self-test can turn it red, because a broken instrument makes every figure
below it worthless. Attaching a threshold to any of these numbers is a separate
decision to be made once we have seen how they drift.

## The one rule

**A measurement that cannot be taken is printed as NOT MEASURED. Never as zero,
never omitted.** A zero in this output always means "I counted, and the count was
zero". The exit code carries the same doctrine as the gates:

| exit | meaning |
|---|---|
| `0` | every metric MEASURED, nothing failing |
| `1` | every metric MEASURED, and at least one MEASURED FAILURE |
| `2` | at least one metric COULD NOT BE MEASURED |

A `2` is never a pass. If a gate returns `2`, the meter returns `2` as well: that
check never happened, so the state it covers is unknown. This is not theoretical —
the first working version of the meter printed `UNMEASURABLE 1` in the gates block
and still concluded `exit 0 - nothing failing`. Case `T07` of the self-test exists
to keep that regression dead.

What counts as a MEASURED FAILURE (exit `1`), and nothing else does:

- a procedure missing one of the six mandatory fields;
- two procedures sharing an ID;
- a **gap in a pack's numbering** — a missing number is a procedure a merge
  dropped until somebody proves otherwise (`T19`);
- a `Traceability` field that is empty;
- `baseline.json` contradicting its own arithmetic, or scoring a pack that does
  not exist;
- a workflow step using an action that is not pinned to a 40-character SHA;
- the gate suite reporting `FAIL`.

### Aggregates are only published over a corpus that was read whole

Every total is a claim about the corpus *as a whole*, so it is emitted only if the
whole corpus was actually read. If a declared pack file cannot be opened, or a
knowledge file on disk is not declared in `packs.json`, then `TOTAL`, the
six-field all-clear and the `duplicate IDs` / `numbering gaps` verdicts all become
NOT MEASURED — not just the affected pack's row. The list of duplicates and gaps
*found in the part that was read* is still printed, because a defect found is real
whatever else went unread; only the claim "there are none" needs a complete read.

This was a real defect, found by attacking the meter rather than by reading it.
With one pack file removed the table printed `TOTAL 112 2608 225597` — a partial
sum wearing the clothes of a complete one, and harder to catch than a zero because
nothing on screen invites you to doubt it. With the whole corpus removed it printed
`TOTAL 0 0 0 0` followed by *"every procedure carries the six mandatory fields"*:
an all-clear about a corpus that was not there. Cases `T17` and `T18` keep both
dead. The old `T14` only ever covered the easy branch — knowledge *directory*
absent — while naming itself "not 0 procedures".

### The gate summary is cross-checked against its own detail lines

The meter's verdict hangs off five integers in the runner's `GATE SUMMARY` line,
and it used to take them on trust. A runner whose summary said `FAIL: 0 |
UNMEASURABLE: 0` while its own detail lines said one gate had failed and another
could not be measured produced `exit 0 — everything measured, nothing failing`,
with both detail lines printed on the same screen.

The detail lines may now never assert **more** severity than the summary admits.
The check is directional on purpose: a runner may legitimately print fewer detail
lines than it counted, so "summary claims more than the detail shows" is not
evidence of anything. The reverse is a runner contradicting itself, we cannot tell
which half is wrong, and believing the summary is exactly how a broken gate gets
laundered into a green verdict — so it is a `2`. A summary that claims gates ran
while naming none of them is the same hole (`T16`, `T20`).

## What each number means

### 1. Corpus

| Figure | What it is |
|---|---|
| `procs` | headings matching `### <PREFIX>-<NN>` in the pack's files |
| `lines`, `bytes` | **whole-file** figures, including each file's loading index and prose, not just procedure bodies |
| `6-field` | procedures carrying all six mandatory fields |
| `id range` | first and last ID per prefix; `duplicate IDs` and `numbering gaps` are printed separately |

**Does not measure:** quality, accuracy or exploitability. A procedure whose six
fields are filled with nonsense counts as complete. `bytes` is disk size, not the
context cost of loading the file into a model.

### 2. Traceability

Counts how many procedures cite at least one standard identifier, how many
distinct identifiers appear and how many standard families they belong to. The
classifier lives in `standards-families.json` as data, one extraction regex per
family, evaluated in order.

Identifiers are extracted from the field payload **whether or not they are inside
backticks**, because the corpus does both (`` `CWE-347` `` in most packs, plain
`ASVS 5.0 V8` in `ai-safety`, `privacy-abuse` and `remediation`). Two consequences
are printed rather than hidden:

- `identifiers cited as plain text, not code-formatted` — a real formatting drift
  in the corpus, surfaced so it can be decided on rather than discovered later;
- `Traceability text carrying no identifier` — every fragment of that field that
  is prose instead of a citation, including the legitimate ones
  (`internal process; no external identifier` in `REM-07`, `VER-01`, `VER-02`,
  `VER-06`, `VER-07`, which inherit the finding's traceability by design).

Chapter-list abbreviations (`ASVS 5.0 V1, V2, V8`) are expanded into the three
identifiers they stand for, via `list_expanders` in the same data file.

**Does not measure:** whether the identifier is the *right* one, whether it exists
in the published standard, or whether the standard version is current. An invented
`CWE-99999` would be counted. A real identifier from a family nobody added to
`standards-families.json` is invisible, which is why prose segments are printed.

### 3. PCC — professional curriculum coverage

Read from `docs/coverage/baseline.json`, a versioned **data** file, never from the
prose of the report. The prose report stays the narrative; the numbers live in the
data file, and the meter re-derives `covered / (covered + gaps)` and checks it
against the value the source declared. A mismatch is a failure, not a rounding
note.

> **The PCC figure is a SELF-ASSESSED UPPER BOUND, not a measurement.** The
> `covered` column was scored by each of the five curriculum-mapping areas about
> its own work, and the source report documents at least one proven false positive
> in it (NICE `DD-WRL-005`, product end-of-life, declared covered by `SUP-02`,
> which in fact measures distance to the latest version). Every `covered` count is
> an over-count of unknown size. The meter prints this caveat every single run.

Two further caveats carried in `baseline.json` and worth repeating: the unit
"topic" is not homogeneous between curricula, which inflates the `web-api`
denominator and deflates `infra-cloud` (so 40% is probably generous, not harsh);
and `remediation` at n=8 is an anecdote, not a measurement.

**Does not measure:** anything about the corpus. Nothing in this section is
checked against the procedures on disk. Closing a gap in the corpus does not move
this number until somebody re-scores `baseline.json`. The only guard is
`pack_alignment`, which fails if the baseline scores a pack that does not exist or
a pack exists with no baseline row.

### 4. Gates

Runs `scripts/gates/run-all.sh` and reports how many gates returned `0`, `1` and
`2`, plus the ones declared as not runnable in this context (needs a PR, is a
self-test). A gate returning `2` propagates to the meter's own verdict, and the
summary counters are cross-checked against the runner's own per-gate lines (see
*The one rule* above).

**Does not measure:** whether the gates check the right things. Green gates mean
the checks that exist passed, not that the repository is correct.

### 5. Repo hygiene

Presence of the governance files GitHub and OpenSSF Scorecard look for, how many
workflows exist, and whether every action reference is pinned to a 40-character
commit SHA (`total_uses` splits into `pinned_by_sha`, `local_actions`,
`docker_refs`, `unpinned`).

**Does not measure:** the content of any of those files. A `LICENSE` with the
wrong licence or a `SECURITY.md` pointing at a dead mailbox counts as present.
Pinning is checked by shape — 40 hex characters after `@` — not by resolving the
SHA against the upstream repository, so a pin to a SHA on a fork's branch passes.

## What the meter does not cover at all

- **Skill and agent definitions.** The 8 files in `agents/**` and the skill body
  are not parsed. Whether an auditor agent still lacks `Edit`/`Write` is checked by
  `gate-plugin-integrity.sh`, not here.
- **Plugin size and marketplace metadata.** `gate-plugin-version.sh` and
  `gate-plugin-integrity.sh` own that.
- **Anything about the published product.** No network call is made: no release,
  no marketplace, no download count, no upstream SHA resolution.
- **Trend.** Every run is a snapshot. There is no history file and no ratchet; the
  meter reports today's numbers and refuses to guess yesterday's.

## Files

| File | Role |
|---|---|
| `meter.sh` | entry point: argument handling, gate execution with a portable watchdog, degradation when a dependency is missing |
| `lib/measure.py` | measurement core: reads the corpus, classifies identifiers, re-derives the PCC arithmetic, parses the gate output, renders table or JSON |
| `packs.json` | corpus layout as data: which files belong to which pack, the six mandatory field patterns, the hygiene artifacts to look for |
| `standards-families.json` | identifier classifier as data: one extraction regex per standard family, plus the list expanders |
| `meter.selftest.sh` | 21 negative cases; each breaks the fixture in one way and asserts the meter notices |
| `docs/coverage/baseline.json` | the PCC baseline extracted from the prose report, with its provenance and its caveats |

## Dependencies

`bash` (3.2 works — no associative arrays, no `mapfile`) and `python3` for the
core. `jq` is **optional** and is used only to validate the JSON before printing;
if it is absent the meter says so on stderr instead of pretending it validated.
A missing dependency degrades the affected section to NOT MEASURED and the run to
exit `2`. Case `T09` of the self-test builds a `python3`-free `PATH` and proves it.

No third-party Python package is imported, ever.
