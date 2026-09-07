# Gate requirements

The specification the CI gates implement. This file states **what must be true**; the executable checks live under `scripts/gates/` and the workflows under `.github/workflows/`.

Written as a contract on purpose: the corpus and the machinery that guards it are maintained separately, and this is the interface between them. If a gate and this document disagree, the disagreement is itself a bug — fix both in the same pull request.

> **Status.** Partly running, partly specification, and the table below says which is which. Seventeen gates execute on every push and pull request through `.github/workflows/ci.yml`; two more run where they can only run — in a pull request — through `.github/workflows/issue-closure-gate.yml`; and one runs where its input exists, in `.github/workflows/scorecard.yml`. Eight have their own self-test battery. What has **not** landed: `stable`, a tagged release, and the knowledge loop. **Every gate in the table below is running.** Anything marked *specified* describes a control that is not running. See `docs/design-decisions.md`.

## What runs today

| Requirement | Status | Implementation |
|---|---|---|
| `G1` manifest and structure | running | `gate-plugin-integrity.sh` + self-test, `gate-plugin-version.sh` + self-test |
| `G1b` audit-only posture | running | `gate-agent-tools.sh` + self-test |
| `G2` internal links | running | `gate-plugin-integrity.sh` (link resolution) · `gate-corpus-contract.sh` (routing to pack sections, and every pack file and section reachable from some route) |
| `G3` context budget | running | `gate-plugin-integrity.sh` (bytes, the authority) |
| `G3b` declared counts | running | `gate-corpus-contract.sh` + self-test |
| `G4` every item cited | running | `gate-corpus-contract.sh` (six fields, identifier families, no identifier written as prose) |
| `G5` licence hygiene | running | `gate-licence-hygiene.sh` + self-test |
| `G6` secret scanning | running | `gate-secret-scan.sh` + self-test |
| `G7` protected paths | running | `gate-protected-paths.sh` + self-test (PR context) |
| `G8` closure guard | running | `gate-issue-closure.sh` + self-test |
| `G9` repository quality | running | `.github/workflows/scorecard.yml` (measurement) + `gate-scorecard-threshold.sh` + self-test |
| triage rules | running | `gate-triage-rules.sh` + self-test |
| triage-stage eval integrity | running | `gate-triage-stage.sh` + self-test (31 cases) |
| findings artifact | running | `gate-findings-artifact.sh` + self-test |
| bench integrity | running | `gate-bench-integrity.sh` + self-test |
| bench index | running | `gate-bench-index.sh` + self-test |
| agent roster census | running | `gate-agent-roster.sh` + inline self-test (6 cases) |
| stage-eval separability floor | running | `gate-stage-eval-floor.sh` + inline self-test (8 cases) |
| routing stage dataset | running | `gate-routing-stage.sh` + inline self-test (6 fixtures) |
| coverage gap claims | running | `gate-coverage-gap-claims.sh` + inline self-test (5 cases) |
| reproduction cross-check | running | `gate-reproduction.sh` + self-test (33 cases) |
| served-tree delta | running | `gate-tree-delta.sh` + self-test |
| verdict vocabulary | running | `gate-verdict-vocabulary.sh` + self-test |
| promotion invariant | running | `gate-promotion-safepath.sh` + self-test |
| negative evidence | running | `gate-negative-evidence.sh` |
| benign control | running | `gate-benign-control.sh` + self-test |
| report contract | running | `gate-report-contract.sh` |
| workflow hardening | running | `gate-workflow-hardening.sh`, `gate-actions-lint.sh` + self-test |
| label taxonomy | running | `gate-labels-taxonomy.sh` |
| contract inventory | running | `gate-contract-inventory.sh` + self-test |
| negative proof | running | `gate-negative-proof.sh` + self-test |
| negative proof, its SIZE | running | `gate-negative-proof-census.sh` + self-test (6 cases) |
| budgets, and the figure behind each | running | `gate-budget-ledger.sh` + self-test (10 cases) |
| the alert surface, and what an alert on it means | running | `gate-alert-surface.sh` + self-test (13 cases) |
| the handover: the deliverable is named on screen when a run ends | running | `gate-handover-contract.sh` + self-test (16 cases) |
| governance contract | running | `gate-governance-contract.sh` + self-test |
| `A1`/`A2`/`A3` corpus identifiers | running | `gate-corpus-identifiers.sh` + self-test (14 cases) |
| pooled-batch blinding | running | `gate-bench-blinding.sh` + self-test (9 cases) |
| governance drift | running in a live repo | `gate-governance-drift.sh` + self-test |
| every rule in a gate library has a case | running weekly | `gate-coverage-sweep.sh` + `lib/coverage_sweep.py` + self-test (47 cases) · `.github/workflows/coverage-sweep.yml` |
| the case count this document promises | running | `gate-declared-case-counts.sh` + `lib/declared_case_counts.py` + self-test (27 cases) |

Run everything locally with `bash scripts/gates/run-all.sh`. `gate-actions-lint.sh` reports **unmeasurable** without `shellcheck` installed, which is a `2` and not a pass — install it before trusting a local green.

## Exit-code semantics — applies to every gate

Three outcomes, three exit codes. A gate that cannot tell "I measured and it is fine" from "I could not measure" is worse than no gate, because a tool that fails to run looks identical to a clean result.

| Exit code | Meaning | CI behaviour |
|---|---|---|
| `0` | Measured, within threshold | pass |
| `1` | Measured, outside threshold | fail with the offending items listed |
| `2` | Could not measure (tool missing, network unavailable, file unreadable, parse error) | fail, reported as **unmeasured**, never as pass |

Every gate must be **proved in the negative**: a fixture that makes it exit `1`, and a condition that makes it exit `2`, both exercised in CI. A gate never observed failing is a gate nobody knows works.

### The four that had never been observed failing

This document has asked, since it was written, that **every** gate be proved in the negative. Measured against `run-all.sh --list`, four of seventeen had no negative proof of any kind — no battery, no fixtures, no inline self-test:

| Gate | What goes wrong silently without it | Cases now |
|---|---|---|
| `gate-plugin-version.sh` | a frozen `version` in `plugin.json` makes `/plugin update` skip the plugin: commits merge for months and no installed user receives them, with no error | 13 |
| `gate-plugin-integrity.sh` | the shape of everything a user loads — frontmatter, links, symlinks, the execute bit, the size budget | 20 |
| `gate-verdict-vocabulary.sh` | the five-spellings drift this vocabulary was written to end, coming back | 12 |
| `gate-labels-taxonomy.sh` | GitHub **drops** an undeclared label without a word and the issue arrives unclassified | 12 |

Three of the four run on a throwaway tree built by the battery; `gate-verdict-vocabulary.selftest.sh` copies the real corpus instead, because a hand-written vocabulary would drift from the one the gate polices. `gate-labels-taxonomy.sh` resolves its root from its own location and takes no override, so its battery copies the gate into the throwaway tree rather than changing the gate to be testable.

Two of those 57 cases are worth naming. `gate-plugin-integrity.sh` states in a comment that a `grep '^allowed-tools:'` was *demonstrated evadable* — `"allowed-tools": Bash(*)` and `allowed-tools : Bash(*)` are the same key to any YAML parser and neither starts with the literal. All three spellings are now measured, plus the `EHS_ALLOW_TOOLS_FRONTMATTER=1` escape hatch that must still let a human say yes. And the only route into `gate-plugin-version.sh`'s base-ref lookup is channel `latest` *with* a version declared; on `stable` there is no diff to compute and on a versionless `latest` there is nothing to bump. Two drafts of that battery asserted `2` from those dead ends and were wrong about the gate, not the other way round.

### And the check that keeps it that way

The batteries above are the fix. `gate-negative-proof.sh` is the other half this repository's closure rule always asks for: it fails when a gate carries no negative proof at all.

**And a second half to that half.** `gate-negative-proof.sh` asks whether proof EXISTS. It cannot see proof that is gone, and its own docstring is honest that counting files cannot judge a battery. Measured on 2026-09-01 against `9ccd3ab`: moving one negative fixture and its `.expected` sidecar out of the tree took `gate-findings-artifact.sh` from 30 artifacts to 29 and it signed **`VERDICT: 0`**. Every gate in the repository stayed green while a negative proof was retired, and nothing recorded that the case had ever existed. Weakening a fixture in place IS caught — gut the defect and leave the file and the gate says *"a fixture under bad/ validated cleanly, so it proves nothing"* — so the shape that survived is precisely **deletion**, the one edit that removes the evidence along with the thing it proved. `gate-negative-proof-census.sh` compares the count on disk against `scripts/gates/data/negative-proof-census.json`, in both directions: fewer means a proof was retired, more means the baseline went stale and stopped being one. The file sits under `scripts/gates/**`, so lowering the number is an edit G7 puts in front of a reviewer.

A gate proves itself in exactly one of two shapes, and the gate accepts only those two:

| | Shape | Gates using it |
|---|---|---|
| sibling | a non-empty `<gate>.selftest.sh` beside it, which the CI step discovers | 14 |
| inline | the gate READS `${GATE_SELFTEST:-1}` — the switch whose only effect is to cap its verdict at `2` when the self-test is skipped, so a gate that has not measured itself can never sign a green | 4 |

**The marker is a parameter expansion, not a substring**, and a mutant is why: renaming the variable inside a gate to `GATE_SELFTEST_RENAMED` left the first version of this check green, because `grep GATE_SELFTEST` matches that too — as it matches a comment that merely mentions the switch. Both spellings are now negative fixtures.

An empty `<gate>.selftest.sh` fails on its own line: a battery in name only reads like a proof and is not one.

What this gate deliberately does **not** answer is whether the proof is any good — whether its cases are real, whether they cover the rules that matter, whether an assertion is strong. Counting files cannot answer that, and a gate implying otherwise would be worse than this one. It answers exactly one question, *does a negative proof exist*, and the reviewer answers the rest.

Proved in the negative by 9 fixtures run as its own self-test, and by a mutant bank over the real `scripts/gates/`: deleting a sibling battery, emptying one, and removing a gate's inline self-test each give `1`; the untouched tree gives `0`.

## G1 — Manifest and structure

- `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` parse as JSON, and `docs/sources-allowlist.json` parses as JSON.
- `plugin.json` contains a `name`.
- **`plugin.json` on `main` must NOT contain a `version` field.** Its presence is the defect that silently blocks updates for existing installs; see `docs/release-channels.md`. On `stable`, the semver lives in the marketplace entry, and it must not appear in both files.
- `skills/ethical-hacker-squad/SKILL.md` opens with YAML frontmatter delimited by `---`, containing `name` and `description`, with `name` matching the directory name.
- Every file under `agents/` has YAML frontmatter with `name` and `description`, `name` matches the filename, and every `tools` entry is a real tool name.
### G1b — Audit-only posture: tools, shell and claims

Implemented by `scripts/gates/gate-agent-tools.sh`. Until 2026-08-16 this section stated the auditor no-write rule and **no script checked it**: the rule was applied by the harness at run time and by nothing at review time, while this document read like a guarantee. That is the exact defect this repository criticises in others.

The region below is machine-read by the gate. Removing it fails the gate, on purpose: a check enforcing a rule its contract no longer states is as much of a bug as a rule nothing enforces.

<!-- gate:agent-tools spec-begin -->
**1. The tool list.** No agent under `agents/` may list `Edit`, `MultiEdit`, `Write` or `NotebookEdit` unless it declares write authority. An agent with **no `tools:` key at all** fails too: an omitted list inherits every tool of the main thread, `Write` included, so silence is the most permissive declaration a file can make, never a restriction. A wildcard entry fails for the same reason. A tool the gate cannot classify — a third-party MCP tool, for instance — is **unmeasurable (2)**, never a pass.

**2. Role is derived from a declaration, never from a file name.** A hard-coded list of auditor names goes blind the moment a file is renamed or added. So: an agent is write-authorised **only if its own text carries an explicit write-authority declaration** (the marker `<!-- role: write-authorised -->`, or the equivalent sentence the remediator already carries); a negated sentence never counts as one. Everything else defaults to auditor — the strict branch. At most **one** agent may declare write authority (`EHS_MAX_WRITE_AGENTS`), or the declaration would be a self-service permission. Conversely, an agent that declares write authority and lists no write tool also fails: harden mode would have no remediator, and the run would break at engagement time instead of at review time.

**3. The shell, which is the honest half.** Auditors keep `Bash`, and `Bash` writes. Removing `Edit` and `Write` therefore closes the direct write path and **not** the write path. `Bash` cannot be withdrawn — the auditors need a shell to measure anything — so the requirement is that the restriction lives where the model actually reads it: **every agent carrying `Bash` states its scope restriction in its own body.** For an auditor that means an explicit prohibition on writing through the shell (a sentence naming both the shell and the prohibition; "leave the tree as you found it" does not qualify, because it does not name the instrument). For the write-authorised agent it means the two bounds that make writing safe: writes limited to what the leader authorised, and the named operations it may not perform without explicit authorisation.

**4. The claim surface.** `README.md`, `CHANGELOG.md` and `CONTRIBUTING.md` may describe this control and may not oversell it. Any sentence there that mentions the auditors' tool restriction must carry, in its own window, the caveat that the shell survives and the working tree is verified afterwards rather than assumed clean. Absolute wording — "cannot write", "guarantees", "fully prevents" — fails outright. If one of those files is missing, the claim surface is unmeasurable (2).
<!-- gate:agent-tools spec-end -->

**What this contract does not buy.** All four checks read declarations, not behaviour. The gate proves the contract says the right thing; it cannot prove an agent obeyed it. The runtime half of the control is unchanged and stays where it was: after an `audit` run, confirm `git status --porcelain` is empty. Anyone quoting G1b as proof that auditors cannot write has quoted it wrong.

## G2 — Internal links resolve

Every relative Markdown link, and every path interpolated from the plugin-root variable, referenced in `SKILL.md`, `references/**` and `agents/**` points at a file that exists. Checked mechanically, not by eye. A broken reference in a progressive-disclosure skill is a silent capability loss: the model simply never reads the file.

## G3 — Context budget

Progressive disclosure only works if the entry point stays small.

**Bytes are the authority, lines are the sanity check.** Both units appear below because both were specified independently, and they disagreed: a 543-line table-dense pack weighed 44 KiB while the line budget said it was fine. Lines are a poor proxy for what a model actually pays; bytes are closer. Where the two conflict, the byte budget in `gate-plugin-integrity.sh` wins.

| Item | Byte limit | Line limit | Rationale |
|---|---|---|---|
| `SKILL.md` | 12 KiB | 500 | Loaded whole every time the skill fires; its cost is not amortisable. |
| Any single file under `references/` | 32 KiB | 600 | Loaded one at a time on demand. Beyond this, split the file - do not raise the limit. |
| Total corpus under `references/knowledge/` | - | 3,500 | Loading everything must remain obviously wrong. |
| Whole served tree (`skills` + `agents`) | 512 KiB, 64 files | - | Security threshold: bounds the blast radius of the knowledge loop. Re-baselined 2026-08; see the gate's own comment for why, and for why a delta guard is the better instrument. |
| Any single `agents/*.md` | - | 120 | An agent definition is a contract, not a manual. |

Exceeding a limit fails with the file and its line count.

### G3b — Declared counts match reality

The corpus line count and procedure count are stated in `SKILL.md`, `references/knowledge/README.md`, `README.md` and `CHANGELOG.md`. Nothing currently stops the first added procedure from making all four wrong at once.

Count procedures by matching the procedure heading pattern across `references/knowledge/*.md`, count corpus lines, and fail if either disagrees with any declared figure. Prose that repeats a number needs a check watching it, or it becomes a lie on the next commit.

## G4 — Every knowledge item is cited

Every procedure in `references/knowledge/*.md` carries a **Traceability** line with at least one identifier, and every quantitative claim names its source. An item the loop adds or modifies additionally carries a source URL from the allowlist and a consultation date.

Fails with the list of procedures missing traceability. This is what keeps the corpus falsifiable: an uncited claim cannot be checked, and cannot be corrected when it goes stale.

## G3c / G4b — The corpus contract

`gate-corpus-contract.sh` measures the corpus against every number and every name the repository states about it. It exists because all of the following were true on `main` on 2026-08-21, and nothing was watching any of them:

- two holes in the procedure numbering (`AI-23`, `PRV-12`), while `team.md` declared unbroken ranges;
- a knowledge file declared in no pack, so four procedures were in no count and the loading map did not list it;
- `README.md` claiming 2,830 lines and 122 procedures against a real 3,331 and 139;
- three identifier ranges in `team.md` short of what exists;
- two identifier families cited by the corpus and declared nowhere (`AST01`..`AST10`, `AML.M*`);
- twenty-odd identifiers written as bare prose, where no check and no reader grepping for coverage can see them.

What it enforces:

1. **Numbering.** Contiguous from `01`, no duplicates, per family. Renumbering is banned by `CONTRIBUTING.md`, so a hole means an identifier that reports and issues reference points at nothing.
2. **Declared counts.** Corpus lines, procedure count and file count, wherever prose states them, against measurement.
3. **Declared ranges.** The upper bound of `` `AI-01`..`AI-28` `` must be the highest identifier that exists.
4. **Pack headers and the loading map.** The `**Cost:** ~N lines` estimate and the per-file table, within 10 lines.
4b. **Every table row that names a pack file.** A row saying `` `ai-safety-data-output.md` | `AI-12`..`AI-24` `` is a claim about which procedures live in that file, and a file carrying such a table must carry a row for **every** pack file. Check 3 only looks at ranges starting at `01`, which is how three rows of `README.md` drifted and the whole `local-app` pack stayed missing from the front-page table while every other check was green.
5. **Anatomy and identifiers.** Every procedure carries the six mandatory fields from `scripts/meter/packs.json`; its `Traceability` line names at least one identifier or declares explicitly that none applies; every backticked token matches a family in `scripts/gates/data/identifier-families.json`; and no identifier appears outside backticks.
6. **The roster.** `references/team.md`, `agents/` and `packs.json` name the same roles, agents and files. A pack no role owns is never loaded; an agent absent from the roster is never dispatched.
7. **Routing.** Every `` `pack.md` §N `` in `coverage.md` names a section that exists.
8. **Reachability, which is check 7 turned around.** Every pack file is routed to by at least one row of `coverage.md`, and every section of a routed file is named by some row. Check 7 walks the routes outward and cannot see what no route mentions, and that silence reads exactly like coverage: `ai-safety-agent-runtime.md` held `AI-25`..`AI-28` while the one table the leader consults to decide what to open never named the file, and four more procedures — `AI-21`, `PRV-13`, `LOC-15`, `LOC-16` — sat in sections no row reached. A pack may be unrouted **on purpose** — `remediation` is staffed by mode, not by an inventory signal — and that is a third state written down as `unrouted_reason` in `packs.json`, never an absence. Declaring the exemption *and* routing to the file is itself a finding, so the two cannot silently disagree.

**Two declared exemptions, both visible in the output.** A `Traceability` line may state that no external identifier applies (`internal process`, `no external identifier`, `the one from the original finding`) — five procedures in `remediation.md` do. And text that quotes a superseded figure on purpose — a changelog entry saying what a file *used to* declare — is exempt only inside a `<!-- counts:historical -->` region, in the same idiom `gate-verdict-vocabulary.sh` uses. Both are counted and printed on every run rather than silently swallowed.

**What it does not measure.** Whether a procedure is correct, whether an identifier maps to what the standard actually says, and whether the traceability matrix lists every procedure that cites a family — 28 of 139 procedures are absent from that matrix today, which is open work, not a passing check.

Proved in the negative by `gate-corpus-contract.selftest.sh`: 26 cases, each breaking exactly one thing on a throwaway copy, asserting the exit code **and** the reason, including a control case on the untouched repository and two cases that must exit `2`.

## The triage rules

Half the value of this corpus is knowing when **not** to report, and until now that half was unenforced: every procedure carried a `What rules it out (false positive)` field written as free prose, with nothing naming the rules, nothing requiring an answer and nothing able to check that a specialist had worked through them. The competitive analysis is blunt about the consequence — the two most rigorous neighbouring products enforce a finite named triage list through a schema, and distributed hygiene beats a single final reviewer only when the distributed part is checked.

`references/triage.md` declares ten rules, `FP-01`..`FP-10`, read out of the 370 exculpation bullets the corpus already contained rather than invented. Each is answered with exactly one of `HOLDS`, `DOES_NOT_HOLD`, `UNKNOWN` or `NOT_APPLICABLE`, and three invariants make the answers load-bearing:

1. A finding reported `confirmed` has every invoked rule answered, none `HOLDS` and none `UNKNOWN` — the same doctrine as exit code `2`, applied to findings.
2. `HOLDS` and `UNKNOWN` require a reason naming the artifact.
3. Absence of evidence is never `HOLDS`. `FP-08` exists because "the platform handles it" is the most common way a real finding disappears.

`gate-triage-rules.sh` enforces the rule set (contiguous ids, no stubs, the four answers declared), that every `FP-` id cited anywhere resolves, that `team.md` and `report.md` point at the rules and use the vocabulary, and **conformance per pack, ratcheted**: a pack marked `required` in `scripts/gates/data/triage-conformance.json` cites rules in every procedure, and a pack still being converted may never fall below the count it has reached. **All eight packs are converted and all eight are `required`: 154 of 154 procedures.** It took one editorial pass per pack, because citing the right rules for a procedure is a judgement and a bulk substitution would have been false rigour. Four procedures declare `Rules: none (reason)` — `AI-22` and three `VER-*` — because their class genuinely admits no exculpation, and the gate counts and prints those rather than letting them pass as citations.

Proved in the negative by 11 cases, including a control run and two that must exit `2`.

## The served-tree delta

`gate-plugin-integrity.sh` caps the absolute size of the tree copied into every user's plugin cache, and its own header named the weakness: an absolute cap loosens as the corpus grows legitimately, until the only way to satisfy it is to delete knowledge. `gate-tree-delta.sh` is the control that keeps its meaning — the growth of `skills/` and `agents/` between the merge base and `HEAD`:

| Branch | Budget | Why |
|---|---|---|
| `bot/*` | 16 KiB | the knowledge loop adds procedures, not chapters |
| everything else | 64 KiB | the largest legitimate change observed — the `local-app` pack plus its wiring — measured 44,545 B, so it still fits |

Deletions are never a failure: removing corpus is a decision a person makes, and this gate has no opinion on it. A shallow clone that cannot reach the merge base is exit `2`, which is why the `gates` job checks out with full history — an unmeasured delta is not a small one.

Proved in the negative by 7 cases built on throwaway repositories, because a delta gate can only be exercised by making a delta.

## The promotion invariant — who judges is always main

The release `verify` job checks out **two** trees: `tools/` is the tip of `main`, the code that JUDGES; `source/` is the candidate commit, the content BEING JUDGED. `main`'s gates are copied over the candidate's own and run with `working-directory: source`.

That arrangement has one soft spot, and it is not in the copy: `python3 -c`, a heredoc on stdin and `python3 -` all put the **working directory** first on `sys.path`. A `yaml.py` or a `json.py` sitting in the candidate tree would be imported by the gates judging it, and the candidate would be approving itself through the back door. `PYTHONSAFEPATH: '1'` closes it, and has been set on that workflow since it was found.

`gate-promotion-safepath.sh` is the part the closure rule demands and the mitigation did not have: **the check that fails if the mitigation is removed.** Two triggers, either of which requires `PYTHONSAFEPATH` in scope:

| | Trigger | Scope that satisfies it |
|---|---|---|
| `T1` | a job that checks out **two or more trees** and then runs a step with a `working-directory:` — or a `cd` inside a `run:` block | the workflow or the job `env:` |
| `T2` | a step whose `run:` invokes python while its working directory is not the workspace root | the workflow, the job or the step `env:` |

**`T1` exists because `T2` alone was a measured false green.** Written first as "a step that runs python outside the root", this gate passed the real `release.yml` *and* passed a mutant with `PYTHONSAFEPATH` deleted — because the word `python` appears nowhere in that step. It runs `./scripts/gates/run-all.sh`; python is reached through the gates the runner invokes. A rule that greps for `python` reads the exposed release workflow as clean.

**A declared `PYTHONSAFEPATH` is not automatically a mitigation.** CPython acts on a **non-empty string**, so `'0'` and `'false'` switch it *on* — the value is not a boolean — and only an empty value leaves the interpreter prepending the working directory. `PYTHONSAFEPATH: ''` therefore mitigates nothing while reading in review exactly like a mitigation, and the gate reports that case with its own sentence.

Proved in the negative twice: 14 fixtures under `scripts/gates/fixtures/safepath/` run on every invocation as the gate's own self-test, and a 7-case mutant bank over the live `release.yml`, recorded in `scripts/gates/fixtures/safepath/README.md`.

## A run nobody can navigate to

`bench/runs/` holds every measurement this project publishes, and the project's one
**measured** advantage is not detection — eighteen blinded rounds say the corpus leads on
none of that. It is that a reader can *check* the numbers: six of six on a published
transparency rubric where no other product in the field exceeds one.

A result that exists in the tree and that no document points at sits outside that claim.
`gate-bench-index.sh` fails when a directory under `bench/runs/` is referenced by no
document a reader arrives at — `bench/README.md`, `README.md`, `CHANGELOG.md`, `docs/*.md` —
and when a `runs/` link in those points at a directory that is not there.

**A run citing another run is not an index.** Runs pointing at each other is a graph with
no entrance.

**What it deliberately does not decide** is which *kind* each run is — measurement,
pre-registration, retraction, patch bench. That taxonomy is what the project chooses to
claim; it is not derivable from the tree, and a gate that invented it would be enforcing
its author's opinion rather than the project's. So the top-level `README.md`'s *"eighteen
blinded measurements"* is **not** checked here, and the gate prints that limit on every run
— an unstated limit reads like coverage.

It found two on the run it was written for. One was a superseded pre-registration reachable
only from its own banner; the other had been added to this repository an hour earlier by
the person writing the gate.

## The findings artifact

Backlog item 7 of `docs/competitive-analysis.md`, and the one that unlocks the rest. Four of the five neighbouring products emit a machine-readable findings file and we did not — which is also why nobody, us included, has ever measured this squad's detection quality: there was nothing to count.

`references/findings.schema.json` owns the shape. It deliberately does **not** repeat the enumerations: `status`, `severity`, `confidence` and `verification` are validated against the declared regions of `vocabulary.md`, which is their single home, and the triage answers against `triage.md`. `references/findings-artifact.md` explains every field and why it is there.

`gate-findings-artifact.sh` validates the fixtures in CI and any real deliverable on demand (`--deliverable <path>`). Beyond shape, it enforces the invariants that are the reason the file exists:

1. `confirmed` demands a complete triage with nothing `UNKNOWN`, nothing `HOLDS`, and confidence above `low`. A finding cannot be promoted by writing a stronger word.
2. `probable` names the link it inferred; `withdrawn` names why the claim did not survive.
3. `candidate` never ships — `vocabulary.md` says it is internal working state.
4. Every `procedure` resolves to a real identifier in the corpus, or is exactly `ad-hoc`.
5. Every `traceability` identifier matches a known family, the same list `gate-corpus-contract.sh` uses.
6. No high-precision secret format travels inside the file, exactly as `gate-report-contract.sh` refuses them in the prose.

**The negative fixtures carry their own reason.** Each file under `fixtures/findings/bad/` has an `.expected` sidecar naming the defect it stands for, and the gate fails if a fixture is rejected for an unrelated cause — a battery whose cases fail for the wrong reason proves that the validator runs, not that it catches anything. Ten negative fixtures, one conforming, and a self-test of 10 cases including four that must exit `2`.

## The evaluation bench

The competitive analysis has one row where every product in the field, including this one, is empty: **measured quality**. Five neighbours publish stars; none publishes a number for how much its tool actually finds. `bench/` is the machinery for filling that in, and `gate-bench-integrity.sh` is what stops it rotting into confident nonsense.

The bench holds small targets written to be read, and an answer key that names, for each: what was planted and which procedure should catch it, and which constructs were planted to **look** like findings with the triage rule that rules each one out. Ten planted defects, eleven decoys, across `web-api` and `local-app`.

**The rule that makes a run mean anything: the auditing context must never read `bench/ground-truth.json`.** An agent that has seen the key is transcribing, not detecting. The protocol in `bench/README.md` runs a fresh squad against `bench/cases/<name>` only, has it emit `findings.json`, validates the artifact, and only then scores it — in that order, because a malformed artifact scored anyway reports a low recall that is really a formatting bug.

`gate-bench-integrity.sh` checks that every case path exists, every planted and decoy entry points at a file and at a symbol that literally appears in it (with word boundaries, so `write_token` is not satisfied by the `write_token_privately` decoy beside it), every procedure id exists in the corpus, every `ruled_out_by` rule exists in `triage.md`, ids are unique, and **no case has planted defects without decoys** — a case with only defects measures the model's willingness to agree.

`scripts/bench/score.py` reports detected, missed, decoys reported (each a false positive with an id and the rule that should have caught it), and unlabelled findings, which are **not** counted against a run because the bench does not claim to be exhaustive. Thresholds are opt-in: without them the scorer measures and does not judge.

Both are proved in the negative: 9 cases for the gate, 6 for the scorer, including a near-miss case asserting that pointing at the decoy next door is not scored as a detection.

## G5 — Licence hygiene (anti-verbatim)

The repository is MIT. Most sources it cites are not: OWASP is CC BY-SA, CIS is non-commercial with no-derivatives on the Controls, the semgrep ruleset is proprietary. Copying their text would contaminate the licence.

The gate enforces what is mechanically enforceable:

- No quoted span longer than 15 words attributed to an external source anywhere in `skills/**` or `docs/**`.
- No match against a maintained denylist of known phrases from copyleft and proprietary sources.
- `NOTICE.md` exists and lists every source family cited in the corpus.
- Any new source cited in the corpus appears in `docs/sources-allowlist.json` with its licence recorded.

**Honest limitation:** this cannot prove absence of plagiarism. It catches the obvious failure mode — pasting a checklist or a control description — and nothing more. The real control is upstream: the corpus is written from scratch and cites identifiers rather than text, and the pull request template requires that assertion explicitly.

**Implemented 2026-08-21** as `gate-licence-hygiene.sh`. Four measurements, and two of them found something the first time they ran: **OpenSSF** was absent from `NOTICE.md` while the corpus cited `SLSA Build L2`/`L3`, and `docs/coverage/mapa-microsoft.md` carried five verbatim quotations of Microsoft, AWS and Google terms-of-use text while `NOTICE.md` stated in the present tense that the repository contains no copied text. The first is fixed with an attribution section; the second is a real exception and is now declared as one — a `licence:quoted-terms` region for the case where the wording of a licence **is** the evidence for a licence determination, counted and printed on every run, with `NOTICE.md` narrowed to say exactly that.

**The denylist is stored as hashes, not phrases.** A list built to stop us copying somebody's words should not itself be a copy of them, so `scripts/gates/data/verbatim-denylist.json` holds SHA-256 prefixes of normalised eight-word windows, and `scripts/licence/add-verbatim-phrase.py` turns a phrase into entries without ever writing it down. The list is empty today and its size is printed on every run, because an empty denylist that passes silently is decoration.

Proved in the negative by `gate-licence-hygiene.selftest.sh`: 9 cases — a pasted attributed quotation, the same quotation inside the exempt region (which must stay green), an identifier owner nobody attributed, an allowlisted source with no licence recorded, a denylisted phrase present in the corpus, and three cases that must exit `2`.

## G6 — Secret scanning

No credential in the working tree or in history. Detection uses distinctive-format patterns before entropy, since entropy alone is a poor primary detector and format patterns reach far higher precision. Exit `2` if the scanner is unavailable — an absent scanner is not a clean repository.

**Implemented 2026-08-21** as `gate-secret-scan.sh`: ten published formats, never entropy, with GitHub tokens settled offline by their CRC32 checksum so a hit there is a fact rather than a guess. Inert markers (`sk_test_`, `changeme`, `replace-me`, an all-zero body) are excluded before anything is reported, because a scanner that fires on `.env.example` gets switched off within a week.

**The bench exclusion, and why it is not a hole.** `bench/cases/` ships planted secrets on purpose — that is what an evaluation bench is — so the tree scan skips it. The second scope is what makes the first honest: every secret-shaped string under `bench/cases/` is checked against `bench/ground-truth.json`, and one the key does not declare fails the gate. A planted secret nobody planted is a real secret hiding behind the exclusion.

**Stated on every run rather than implied: git history is not scanned.** Rewriting a history is a different operation with its own authorization conversation. The gate prints that as an out-of-scope line, so nobody reads a green as "clean back to the first commit".

## G7 — Protected paths

A pull request **fails** if its diff carries any mark of automation and touches any of:

```
skills/ethical-hacker-squad/SKILL.md
.claude-plugin/**
agents/**
.github/workflows/**
.github/CODEOWNERS
docs/sources-allowlist.json
docs/gate-requirements.md
scripts/gates/**
LICENSE
NOTICE.md
```

These define what the system may do and what it may read. An automation that can edit its own limits has none.

**The classifier no longer asks the editor.** Until 2026-09-01 the single question *is this an automation?* was answered by the branch prefix — and the branch is named by whoever is editing. In PR #72 an agent raised `MAX_TREE_BYTES` from 655,360 to 786,432 B inside `scripts/gates/**`, which is this rule's own example of the thing it forbids, and the gate signed it green because the branch was called `loop/…` and the reserved prefix is `bot/`. A longer prefix list does not fix that; every list of chosen names has the same hole.

What fixes it is reading a self-declaration in one direction only:

> **an admission incriminates, a denial exculpates nothing.**

So the prefix stays, demoted from *the* classifier to one signal among several, and it is joined by the marks an agent's harness writes into the commit range rather than into a name: a `Claude-Session:` trailer, an `@anthropic.com` or `[bot]` identity. `scripts/gates/data/protected-paths.json` holds both lists. Measured on the four commits merged as PR #72: all four carry the trailer, and replaying that exact diff turns the gate from `0` to `1`.

**Nothing is called a human change any more.** There is no signal available when this gate runs that proves a person made a change: a pull-request approval does not exist yet when CI fires, and every other signal is written by the editor. A change with no mark is reported as `UNATTRIBUTED` — allowed, listed, and never described as something it was not. And in a single-maintainer repository the separation stops there on purpose, because the maintainer and the maintainer's agent commit with the same account and the same email. The property this gate guarantees is not *an automation cannot move a limit*; it is **an automation cannot move a limit unnoticed**, which is the one that was actually missing.

**If the commit range cannot be read and a protected path was touched, the verdict is `2`.** Half the classifier did not run and the diff is in the half that matters; reporting that as the old *human branch, allowed* would repeat the original mistake one level down. Where no limit was touched the range is moot and the run stays `0`, because a gate that goes amber on every ordinary pull request is a gate people learn to skip.

**The way out is a label, `override/g7-reviewed`.** A label is not in the diff, not in the branch and not in a commit, so granting one is a separate act on GitHub and shows up in the pull-request timeline rather than in the change it waves through; the workflow resolves its presence to one of two literals before anything reaches a shell, and `labeled`/`unlabeled` are trigger types so applying it re-runs the gate. When it is used the run prints every path that moved, in capitals, with consent — an override that reads like a pass is a pass. It does not silence the drift check: no label makes the rule disagreeing with its own documentation acceptable, and a label standing on a change that carries no mark is called out as worth removing.
**Two limits of the override, measured rather than assumed.** The label is out of reach of the branch, of the diff and of the workflow's own token, which has `contents: read` and cannot write anything. It is **not** out of reach of an agent running with the maintainer's `gh` credentials on the maintainer's machine — to GitHub, that agent *is* the maintainer, and no control living inside this repository can change that. The honest boundary of G7 is the CI surface, and it is stated here rather than left to be discovered. Second: as of 2026-09-01 the protected-paths job is **not** among `main`'s required status checks (`gates` and `workflow-hardening` are), so a red G7 is visible and does not block a merge. That is a deliberate open question, not an oversight — making it required turns the override from a loud annotation into a gate key, and a gate key an agent can turn is not a key.

**Implemented 2026-08-21** as `gate-protected-paths.sh`, and the list above is no longer prose: it is checked, line for line and in order, against `scripts/gates/data/protected-paths.json`, so the rule and the sentence documenting it cannot drift apart. Two self-test cases exist for exactly that drift, one in each direction.

**A human branch touching a protected path is printed, never silently allowed.** The maintainer reviews it, and can only review what the run tells them is there — so the gate lists every protected path in the diff and says which pattern caught it. What it does not judge is whether the change is a good one: it asks who is changing the limits.

**And that list was burying the lines that mattered.** Measured on 2026-09-01 across the 28 merged changes that tripped G7: of the 150 paths it named, **38 were fixture inputs** — the `bad/` and `unmeasurable/` files a gate is supposed to fail on — and on the worst change **2 genuine limits sat under 19 lines of them**. A reviewer asked to find two lines in twenty-one finds neither. So the `UNATTRIBUTED` listing now folds that material into one counted line, grouped by family, naming what watches it. Folding is a display decision and the battery is what keeps it one: when G7 **fails**, and when a maintainer waves a marked change through with the label, every path is named in full. A `.expected` assertion never folds, because the input is the proof and the assertion is what says the proof proved anything, and nothing else watches an assertion being weakened.

**The exemption this replaced was measured and refused.** A task stood open to take those fixture inputs *out* of `scripts/gates/**` altogether, on the argument that they are negative proof rather than limits. Half of that argument holds — the three ways such a fixture can be weakened are all watched: deletion by `gate-negative-proof-census.sh`, neutering in place by the family's own self-test, which names the rule the fixture stopped tripping and caps the verdict at `2`. The other half does not. In **0 of those 28 changes** did G7 fire on fixtures alone, so the exemption would have cost 38 paths their protection and prevented not one firing. And the gates that do watch them answer a different question: the census asks whether the proof is still *there*, the self-test whether it still *trips*, and neither asks **who moved it**, which is the only question G7 asks. *Covered by another gate* is not *covered*. The refusal is recorded in `protected-paths.json` next to the list it declined to shorten, because the next reader will ask.

It runs in the pull-request workflow rather than in the push suite, because a branch name and a diff against a base are things only a pull request has; `run-all.sh` defers it with a printed reason instead of running it against an empty diff and reporting a green that means nothing. Proved in the negative by `gate-protected-paths.selftest.sh`: 25 cases — three automated branches touching three different protected patterns, an automated branch touching nothing, an unattributed change touching one, an agent trailer and a bot identity each caught on a branch named anything at all, a reserved prefix still failing with a perfectly clean commit range (the asymmetry, stated as a test), an unreadable range with and without a limit in the diff, the override letting a marked change through and failing to silence drift and being called out when it stands on nothing, the documented list and the enforced list drifting in each direction, seven on the fold — the real limit named in full above it, the count of what it folded, a finding and an override each still naming a folded path in full, the case where nothing *but* negative proof moved and the line says so rather than counting against zero, a `.expected` refusing to fold, and the declaration removed altogether so nothing folds — and three cases that must exit `2` (an unknown branch, a missing file list, an unusable data file). The commit range and the label are injected by the harness rather than read from git, because a battery that reads the same signal from the same place as the gate is testing nothing. The unknown-branch case earned its keep on the first CI run: `git rev-parse` inside a directory that is not a repository walks **up** and answers about an ancestor one, so on a runner the gate confidently reported the wrong branch where it should have reported that it could not tell. It now falls back to git only when the root it was given is itself the top level. And the battery itself was not hermetic: on a runner `GITHUB_HEAD_REF` is set, the gate reads it as a default, and the case meant to prove *I cannot tell whose branch this is* was quietly told. Every case now runs with those variables cleared — a battery that inherits the environment is not proving what it claims.

**The control went green because its input went missing, 2026-09-01.** The first push of the
`alert-surface` branch had G7 **passing** on a diff that moved three protected paths. Nothing was
overridden and nothing was narrowed: the commit had simply been written without its
`Claude-Session:` trailer, which is one of the two signals this gate reads. G7 behaved exactly as
specified — it prints *an absent mark is not a human* on every run — but a reader sees a green
check, not that sentence. **A signal that can go missing by omission produces a silence that looks
like a pass**, and the only reason it was caught is that a claim in the pull-request body predicted
red and the check said green.

`automation_branch_prefixes` holds only `bot/`. The `loop/` branches this repository's own
continuous-improvement work runs on are not covered, so the trailer is the *only* signal on them,
and it is the one a harness can drop. Closing that is tracked separately; it is recorded here
because the gap is in this gate's inputs and a reader of this section should not have to find it
in a pull request.


### The rule that could never be satisfied, 2026-09-01

G7 failed on **every** Dependabot pull request in the `github_actions` ecosystem, and could never
have passed one. Two changes, each right on its own, cross:

| Piece | When | What it did |
|---|---|---|
| `23c240f` | 2026-08-21 | protects `.github/workflows/**` |
| `9e17a07` (PR #73) | 2026-09-01 | adds `dependabot`, `[bot]`, `github-actions` to `identity_substrings` |

Their intersection is unsatisfiable, because **editing workflow files is the work of that
ecosystem**. It is a regression rather than a design decision, and the runs prove it: the same
branch `dependabot/github_actions/github-actions-0856f00088` went green on 31 August and red four
times on 1 September. Over the last 100 `PR-context gates` runs, 86 passed and 14 failed; four of
the fourteen were that one branch. G7 is not a required check, so nothing was blocked — which is
worse, not better: a control that shouts on every change and blocks nothing is a control people
stop reading, and PR #63, a **one-line bump of `github/codeql-action/upload-sarif`, a security
action**, sat red from 31 August.

**The fix is not an exemption for Dependabot.** Exempting the bot would open a real hole — a bot
pull request that widens `permissions:`, injects a `run:` step or adds a job is a supply-chain
vector, and a bot identity is exactly what an attacker would forge. So `content_exemptions` in
`scripts/gates/data/protected-paths.json` asks **what changed**, never who changed it: for a file
under `.github/workflows/**`, every added and removed line must be a `uses:` pinned to a 40-hex
commit SHA. One line that is not — anywhere in that file — and the file stays protected.

Three properties are worth stating because each has a case in the battery:

- **It can only make a pinned repository more pinned.** A bump to `@v4` or `@main` is a mutable
  reference and is not exempt. Pinning is the reason this repository holds SHAs at all.
- **It clears a file, not a pull request.** A clean bump travelling beside another protected path
  does not carry that path through.
- **It fails closed.** The exemption needs the *diff*, not the file list, and the gate prints
  `NOT MEASURED: no diff was supplied` when it has none. Without a diff nothing is exempt. A rule
  that turns into a pass when its input goes missing is the false green recorded in G7b and G7d,
  and it would have been trivial to build it that way here.

Seven cases in `gate-protected-paths.selftest.sh` fence this in, and **exactly one of them is
allowed to pass** (32 cases in total, 0 failures). The other twenty-five were unchanged by the
work: with no diff there is no exemption, so every verdict written before exemptions existed still
holds.

## G7b — A bound may not move without the figure that moved it

G7 asks **who** moved a limit. It does not ask whether the number that moved still agrees with the sentence that states it — and on 2026-09-01, one of them did not.

Measured over the whole history: **15 budget constants moved, 13 of them tighter.** Exactly two loosened, and both were the same knob — `EHS_MAX_TREE_BYTES`, raised `524288 → 655360 → 786432`. The discipline around those raises is genuinely good; the third is written up in `gate-plugin-integrity.sh` with the figure that forced it (653,513 B served against a 655,360 B cap — **1,847 bytes of headroom**, less than a tenth of one procedure). This gate does not exist because the discipline is missing. It exists because **nothing enforced it**, and the practice already had one measured failure: the same file's environment table still read `default 524288` while `786432` was enforced — stale since the second of the three re-baselines, and the number a contributor gets from the usage block rather than the rationale. **One knob of eleven had drifted, and it was the only one that had ever been raised.** The fix that raises a number makes the note that states it false, and no test saw that.

`scripts/gates/data/budget-ledger.json` is the single home. Four checks:

1. **classification** — every `${EHS_*:-<number>}` any gate reads is named in the ledger, as a `budget` or explicitly as `not_a_budget`. A knob nobody classified **fails**: a ledger listing only what someone remembered cannot see what nothing points at, and 3 of the 11 knobs really are mode switches, which is a decision someone writes down rather than a gap.
2. **agreement** — the ledger's `value` equals the value the source enforces, in both directions, so raising a budget is an edit to a file under `scripts/gates/**` that G7 puts in front of a reviewer, with the justification on the next line. A declaration that outlives its knob fails too.
3. **no drift** — every comment stating `default <N>` for that knob names the same number. This is the check that was already red.
4. **justification** — every `budget` carries a non-empty `why` and `measured`.

**What it does not measure, and does not pretend to.** Whether a `measured` claim is *true*: a gate cannot re-run the reasoning that justified a number, and one that implied it could would be worse than this one. Nor the **direction** of a change — it has no history at gate time, so it does not claim to tell a raise from a tightening. Both are printed on every run.

Proved in the negative by its inline self-test, 10 cases: the repository as it stands, the enforced value raised behind the ledger and the ledger lowered behind the code, the stated default disagreeing with the code (the defect this shipped with, reproduced), a new knob nobody classified, a declaration that outlived its knob, a budget with an empty `measured`, a budget relabelled `not_a_budget` still having its value checked, and two that must exit `2` — a missing ledger and an unparseable one. The self-test found one bug in the gate itself before it shipped: the scanner read a knob literal out of the gate's own mutation string, so the mutation is now assembled from parts.

## G7c — The file that tells you how to read an alert has to be right

`.github/dependabot.yml` carries the comment a triager reads before deciding whether a red
alert matters. Its whole purpose was one sentence: *do not let a real alert hide behind the
assumption that every npm finding here is a fixture.*

**Measured 2026-09-01, against the five open alerts on the default branch: every factual claim
in that comment was false.** It said there was no `requirements.txt` — one had been added under
`bench/cases/intake-portal` and produces three of the five alerts. It said enabling alerts would
report *those two — one high, one low* — the figure is five: one high, two medium, two low. It
said *the express pin is deliberately old* — `express` appears in no planted entry and no decoy
in `bench/ground-truth.json`, so that alert is incidental, not ground truth. And it said there
was no `Dockerfile` — `bench/cases/intake-portal/Dockerfile` exists. **One alert of five is a
plant.** The document written to stop a real alert hiding behind a fixture had become the hiding
place, and nothing read it.

This is `G7b` one level up: not a number that moved behind the sentence that states it, an
**inventory** that did. A claim of absence never ages; the tree does.

`gate-alert-surface.sh` enumerates the **manifests on disk** — the source, not the declaration —
and checks six things against `scripts/gates/data/alert-surface.json`: every manifest found is
declared and its ecosystem matches its filename; every declared path still exists; `managed: true`
holds **iff** an `updates` block covers it, in both directions, so a bot pointed at a bench fixture
is a finding; every unmanaged manifest states why; every absence the config's prose asserts is
genuinely absent; and the `planted`/`decoys` symbols declared for a fixture are **exactly** what
the answer key plants there, in both directions.

**It found three more defects on its first two runs, all of them mine**: the undeclared
`Dockerfile`, my own transcription of the false `Dockerfile` absence claim, and a `planted` list
written from a grep that held `lodahs` and missed `preinstall` (P-19) and the decoy `left-pad`
(D-20). A list built from memory cannot see what nothing points at.

Two things it deliberately does not measure. **The alert count**, because that number moves when
an upstream advisory is published and no change here caused it — a gate that cries at the world
gets ignored the same way this alert channel did. And the **prose** of `dependabot.yml`: a gate
cannot read English, only the absence claims transcribed into the data file, so a claim added to
the comment and not copied across stays invisible. That hole is named in the data file rather
than left for someone to find.

Fixed in the same change: `tooling/claude-cli` — the one manifest in this repository where an
alert would be **real**, installed with `npm ci` by `release.yml` — had no `updates` block. The
argument this config already makes for keeping action SHAs current applies to it, and nobody had
made it.

Self-test: 13 cases, each proved in the negative against a synthetic tree, plus one that runs the
gate against this repository as it stands.


## G7d — The report was written and nothing said where it landed

`references/report.md` specifies the deliverable in 180 lines: which sections are mandatory,
which vocabulary each verdict must use, which rule kills which claim. Every line is about the
**file**. Not one of them said the leader must tell the user where the file is once the run is
over, and `SKILL.md` step 9 — three sentences, the smallest step in the workflow — did not
either.

**Measured 2026-09-01, from a user who had run the squad several times:** *"nunca entiendo como
entrega los resultados o pareciera que nunca los da"*. The artifact was being produced. The
handover was not, because nothing in the corpus asked for one.

Why no existing control could see it is the part worth keeping. Two gates already guard the
deliverable — `gate-report-contract.sh --deliverable` and `gate-findings-artifact.sh
--deliverable` — and both correctly answer `2` when the directory is missing or empty; that was
verified before this gate was written, and it is the reason no third deliverable-scanner was
built. But **both are invoked with an explicit path.** A run that produced nothing never reaches
either of them. A gate that fires only once someone remembered to point it at a directory
protects the case that already went right.

So `gate-handover-contract.sh` looks at no deliverable at all. It checks that the *instruction*
is wired: present in step 9, naming both files and the word **absolute**, pointing at a
specification, and that specification complete in both directions against
`scripts/gates/data/handover-contract.json`. Its sixth check runs each named validator against
an absent deliverable and requires the answer `2` — because the handover block tells the leader
to print those exit codes, and a named script that answered `0` on nothing would make the
printed number mean the opposite of what the block says it means.

**Step 9 grew by moving something out, not by raising a cap.** `SKILL.md` was 12,281 B against
a 12,288 B ceiling — seven bytes — and that is the real reason delivery was the shortest step in
the file: it was the section that lost. `EHS_MAX_SKILL_MD_BYTES` was not touched; its own
justification in the ledger forbids it (*"The answer to needing more is references/, not a
higher number"*). The room came from deleting `## Example invocations`, whose four lines are in
`README.md:143-146` verbatim — documentation about how to invoke the skill, paid for on every
fire, by a reader who has already invoked it.

What this gate does **not** measure, and says so on every run: whether the leader actually prints
the block. No static check makes a model obey an instruction. That is a `bench/` question, and
calling this gate's `0` "the handover works" would be exactly the substitution the block itself
forbids.

## G8 — Regression guard on quality issues

A pull request whose body closes an issue labelled `false-positive` or `false-negative` **must** also modify at least one file under `scripts/gates/`, `tests/`, or `references/knowledge/**`. Prose-only closure fails.

This encodes the closure doctrine: an issue is closed by the fix **plus the check that stops it recurring**. A false positive corrected by rewording a paragraph has not been fixed, because prose does not execute and nothing watches it. If a case genuinely cannot be guarded, the pull request must say so explicitly and the gate is overridden by the maintainer in the open, not silently.

### What counts as a test here

This repository is prose, so "add a test" needs a definition or `G8` is satisfiable with an empty file. Exactly one of these counts:

- **A corpus case.** A concrete, named example added to a procedure's `Vulnerable pattern` or `What rules it out` field that would have produced the correct verdict for the reported issue. It must name the stack and the construct, not restate the rule.
- **A gate fixture.** A file under `tests/fixtures/` that an existing gate scans, plus the expected verdict, so the gate exits `1` if the regression returns.
- **A new or tightened gate** under `scripts/gates/`, itself proved in the negative.

A paragraph explaining the mistake is none of these. `G8` should check that the changed file is one of the three kinds above and is non-trivial, not merely that some path was touched.

## G9 — Repository quality metric

Track OpenSSF Scorecard, but **do not gate on the aggregate score.** The aggregate is dominated by checks built for compiled software — packaging, fuzzing, binary artifacts, CI test suites — and for a knowledge repository it would mostly measure irrelevance while masking regressions in the checks that matter.

Gate on the subset that reflects real risk here:

<!-- g9:gated -->

| Check | Threshold | Why it matters here |
|---|---|---|
| `Dangerous-Workflow` | must be `10` | A single `pull_request_target` with untrusted checkout is the exact CSA-documented chain. |
| `Token-Permissions` | `>= 9` | An over-permissioned `GITHUB_TOKEN` is what turns an injection into a compromise. |
| `Pinned-Dependencies` | `>= 8` | Tags are mutable and have been repointed at malicious commits in the wild. |
| `Binary-Artifacts` | must be `10` | A knowledge repository has no reason to contain binaries. |
| `License` | must be `10` | |
| `Security-Policy` | must be `10` | A security tool without a disclosure policy is a contradiction. |

<!-- /g9:gated -->

### Measured, published, and deliberately not gated on this number

A check leaves the table above by being written into the one below, never by being deleted. `gate-scorecard-threshold.sh` reads both, refuses to run if a check appears in neither or in both, prints the live score of every check in this table on every run, and fails if the file named as the real check does not exist. A control that is retired in silence is the failure this whole document is written against; a control that is *relocated in writing*, with its live number still on screen, is a different thing.

<!-- g9:not-gated -->

| Check | Really checked by | Why not this number |
|---|---|---|
| `Branch-Protection` | `scripts/gh/governance.json`, `scripts/gh/protection-check.sh`, `scripts/gh/apply-governance.sh` | Scorecard reads the protection block through an API call needing administration scope. The workflow token does not have it, and `.github/workflows/protection-drift.yml` already refused the alternative — a personal access token as a secret in a public security repository — as a larger surface than the problem it solves. So from CI the check is `-1` on every run, and `-1` is COULD NOT MEASURE, which is how G9 exited `2` on every push from the day it started gating. Measured once with a maintainer token it is `3`, not the `8` that was declared: the threshold was never reachable either, so resolving the `-1` would have turned a permanent `2` into a permanent `1`. The property the threshold was written for — *nobody pushes directly to `main`* — holds and is enforced: force pushes and deletions disabled, linear history required, pull requests required, two required status checks. |

<!-- /g9:not-gated -->

The aggregate is recorded as informational with a **no-regression** rule: it may not drop more than 0.5 below the previous recorded value without failing. Exit `2` if Scorecard could not run.

**Implemented 2026-08-21** as `gate-scorecard-threshold.sh`, run by the `threshold` job of `scorecard.yml` over a second, unpublished run in JSON — the SARIF the measurement job produces carries findings, not per-check scores. Three things it does that a threshold check usually does not:

- **A check Scorecard could not run comes back as `-1`, and that is `2`, not a pass.** The exit-code doctrine of this repository, applied to somebody else's tool: a subset gate that silently skips the check it could not read is worse than no gate, because it reports green.
- **The aggregate is judged by movement, and the baseline lives in `docs/scorecard-baseline.json`, edited by hand in a pull request.** A workflow that can rewrite its own baseline can ratchet itself down one run at a time. No baseline recorded yet is printed as *nothing to compare*, never treated as fine.
- **The table above is the gate.** It is parsed and compared, check for check and number for number, against `scripts/gates/data/scorecard-thresholds.json`, with a self-test case for the drift.

It does not run in the offline suite, because its input needs the network and a repository token; `run-all.sh` names it in the deferred list with the workflow that does run it, since a gate that is quietly absent is indistinguishable from a gate that passed. Proved in the negative by `gate-scorecard-threshold.selftest.sh`: 11 cases, including a check below its minimum, a check absent from the results, a check that came back inconclusive, an aggregate falling just within the contract and one falling past it.

## Label taxonomy

Labels are English, matching the repository language. Anyone wiring automation should use exactly these strings.

Every label is prefixed. The single source of truth is `scripts/gh/labels.sh`; `gate-labels-taxonomy.sh` fails if an issue form, a gate or `governance.json` references a label that does not exist there. 35 labels.

**Type — the two first-class types are audit-quality errors, not crashes:**

| Label | Meaning |
|---|---|
| `type/false-positive` | The squad reported something that is not exploitable. |
| `type/false-negative` | The squad missed a real finding. |
| `type/knowledge-gap` | A surface, stack or class with no procedure covering it. |
| `type/bug` | The plugin does not do what it says (install, flow, format). |
| `type/enhancement` | Improvement to an existing capability. |
| `type/documentation` | Documentation or skill text only. |
| `type/maintenance` | Repository infrastructure, CI, dependencies. |

**Area — one per role:** `area/security-lead`, `area/web-api`, `area/mobile`, `area/infra-cloud`, `area/supply-chain`, `area/ai-safety`, `area/privacy-abuse`, `area/remediator`, `area/verifier`, `area/plugin`, `area/ci`.

**Severity:** `severity/critical`, `severity/high`, `severity/medium`, `severity/low`, `severity/info`.

**Origin:** `origin/loop` (opened by automation) and `origin/human`. Provenance, not decoration - it decides which review rules apply.

**Status:** `status/needs-triage`, `status/confirmed`, `status/not-reproducible`, `status/needs-info`, `status/rejected`, `status/resting`, `status/blocked`.

**Channel:** `channel/latest`, `channel/stable`, `channel/stable-blocked` (the last one blocks promotion while open).

Renaming a label moves historical issues, so `labels.sh` never deletes: surplus labels are listed as a warning. The Spanish-to-English rename was free because no taxonomy label had been created on GitHub yet - verified by a dry run reporting `create=35 update=0`.

Applying labels to externally submitted issues must be **deterministic**, derived from the structured fields of the issue form. It must never come from a model's reading of free prose: that would be a language model taking a write action based on untrusted text, which is the exact chain this repository is built to avoid. If a routing decision cannot be made from the form's fields, the correct fix is to add a field to the form.

## The contract and the inventory name the same set

This document opens with a rule about itself: *if a gate and this document disagree, the disagreement is itself a bug — fix both in the same pull request.* Nothing executed that sentence, which is the shape issue #16 was about — a rule the repository states and does not enforce.

`gate-contract-inventory.sh` enforces the half that is machine-checkable in both directions:

- a gate the runner discovers and this document names nowhere is **a control nobody can find from the contract**;
- a name this document carries that the runner does not discover is **a control the document promises and nobody runs**;
- unless the same name plus `.sh` **is** in the inventory, and then nothing is missing: the document wrote the gate without its extension, and that is what the message says.

The third case was added because the gate found it and then misnamed it. A
paragraph in this document wrote *gate-bench-integrity*, with no suffix, where it
meant `gate-bench-integrity.selftest.sh`, and `gate-contract-inventory.sh` reported *a control the document
promises and nobody runs* - which sent the reader looking for a gate that was
never missing, while `gate-bench-integrity.sh` sat in the inventory two lines
away. The mismatch was real and the verdict was right; the diagnosis was not,
and a wrong diagnosis on a true failure costs the same time as a false alarm.

The inventory comes from `run-all.sh --list`, never from a glob of `scripts/gates/`. The runner is the authority on what counts as a gate — it discovers recursively and is not filtered by extension — so the two cannot disagree about what exists. A gate the runner declares it will not run in this context still counts: *not run here* is not *does not exist*.

Three things are deliberately **not** checked, because all three are a person's judgement: which row a gate belongs to, whether the row's status word is accurate, and whether the requirement text describes what the gate actually does.

`*.selftest.sh` is excluded. A self-test battery is not a gate and the runner does not list it as one, so the sentence above naming `gate-corpus-contract.selftest.sh` is correct prose. Counting it made this gate report a phantom on its first run against the repository, and the fixture `good/2-a-selftest-is-not-a-gate` is that mistake, kept.

Proved in the negative by 7 fixtures — 3 negative, 2 positive, 2 unmeasurable — run as the gate's own self-test on every invocation. The third negative fixture carries a `phrase.expected`: exiting 1 does not distinguish a promised-and-unrun control from a name missing its suffix, so that case asserts the sentence and not only the code. Without the assertion it passes against a gate that cannot tell the two apart — measured, not assumed.
## The contract inside governance.json

`scripts/gh/governance.json` carries two lists that describe the same thing from two sides:

| | Field | What it means |
|---|---|---|
| declared | `promotion.required_contexts` | the checks the weekly promotion verifies on the candidate commit |
| enforced | `branches.<source_branch>.protection.required_status_checks.checks` | the checks GitHub actually requires before a merge |

They must name the same contexts. They did not: `workflow-hardening` was in the first and absent from the second, so the job ran on every pull request and its red gated nothing — required by prose. That is `F-005` of the blinded self-audit, issue #16.

`gate-governance-contract.sh` fails while the two disagree. It is a **separate gate rather than a block inside `apply-governance.sh`** because that script needs `gh`, admin credentials and a live repository, so it runs when a person runs it; comparing two lists inside one file needs no network and therefore runs on every pull request like everything else. `apply-governance.sh --check` folds the gate's exit code into its own verdict, the same way it delegates the label taxonomy to `labels.sh`.

A context enforced by the protection and **not** declared as required is reported and does not fail: that direction is stricter than declared, not a hole.

Editing the JSON changes what is *declared*. Nothing changes on GitHub until `scripts/gh/apply-governance.sh --apply` runs, which is a credentialed action a person takes; the gate deliberately has no opinion on the live state, and `gate-governance-drift.sh` is the one that reads it.

Proved in the negative by 7 fixtures — 2 negative, 2 positive, 3 unmeasurable — run as the gate's own self-test on every invocation, and on the real file: before the fix in this change, the gate exits `1` on `scripts/gh/governance.json` naming `workflow-hardening`.

## A green battery is not yet a tested rule

Every battery in this repository is green. That is a fact about the batteries.
Whether it is also a fact about the *rules* is a different question, and until
this control existed nothing here could answer it: a case is green when the rule
works, and a case is also green when the case never exercised the rule and would
have passed with the rule deleted. Rendered identically. Chosen between by
nobody.

`gate-coverage-sweep.sh` chooses. For every statement in `scripts/gates/lib/*.py`
that RECORDS a problem, it replaces that statement with `pass`, runs that
library's battery, and asks whether anything went red. A battery still green over
a silenced rule was never testing it.

### The operator is narrow on purpose

Flipping a comparison or negating a condition produces mutants that crash, and a
crash is caught by anything — it scores as coverage the battery does not have. A
silenced report changes nothing except the verdict, which is the one thing a
battery exists to check.

Spans come from `ast` and not from a regex. `findings.append(` routinely opens a
call that closes three lines later; replacing only its first line leaves a
`SyntaxError`, the battery dies of the parser, and the mutant is scored as
covered. The self-test case `multi-line-report-is-replaced-whole` exists for
exactly that, over a fixture whose third rule spans four lines.

Receivers named `info`, `note`, `notes` and `summary` are skipped: they carry a
printed count, not a failure, and silencing one changes what a run prints rather
than what it concludes.

### The denominator, which is the part that was a fiction

This sweep was written three times in three sessions, in three throwaway scripts,
and each of those versions looked for one thing only: a sibling
`gate-<lib>.selftest.sh`. Six of the sixteen gate libraries do not have one. They
were **skipped in silence**, so the sweep's headline — "24 survivors" — was never
a statement about this repository. It was a statement about ten sixteenths of it,
and nothing in the output said which ten.

There are three ways a library is proved here, and the sweep now knows all three:

```
gate-<lib>.selftest.sh          a sibling battery            10 libraries
gate-<lib>.sh --self-test       the inline form               4 libraries
the gate that imports it        a fixture with no gate        2 libraries
```

A library that matches none of them is **printed as `NOT MEASURED` and forces
exit code 2**, per the doctrine at the top of this document. A denominator with a
hole in it is not a denominator. The self-test proves both halves:
`unresolvable-library-is-declared-not-skipped` and
`inline-self-test-counts-as-a-battery`.

The sweep also prints, per library, the battery it resolved. An instrument that
does not name what it measured with cannot be checked by the person reading its
output — and resolving the battery is the exact step the three earlier versions
got wrong without saying a word.

### The file of survivors is a ratchet, not an amnesty

`scripts/gates/data/coverage-sweep-accepted.json` holds every survivor, each with
its reason and a `kind`:

```
open     a real coverage hole, ticketed, waiting for somebody to write the case
accepted a survivor somebody looked at and decided to keep, with the reason
```

Both suppress the *new hole* failure and the run prints the two counts apart, so
a file of twenty-seven open holes cannot read as twenty-seven things anybody is
happy about. The teeth are in the other direction: **an entry that no longer
survives fails too**. Closing a hole obliges you to delete its line, so the list
can only shrink, and nobody can quietly bank a fix without recording it. This is
the same shape `gate-tree-delta.sh` and `gate-scorecard-threshold.sh` already
use here — judge the movement, not the level.

### Survivors are recorded by anchor, not by line

Entries are keyed `library::qualified.function#ordinal`, the ordinal counting
report sites inside that function.

Line numbers were tried first and rot on contact: an edit anywhere above a site
moves it, and the acceptance silently transfers to whatever rule inherited the
number. An edit above an anchor moves nothing
(`anchor-survives-an-edit-above-it`). **Renaming the function does** move it, and
that is correct rather than unfortunate — the acceptance was granted to a rule
that no longer answers to that name, so it goes stale and the run fails
(`renaming-the-function-invalidates-the-acceptance`). An acceptance naming a site
that no longer exists is a failure too, never a silence: the reason was written
for a rule that has moved or gone, and a green run would never mention it.

### Why it is not in `gates`, and how it is paid for instead

Not scope: **cost**. Measured on 2026-09-06, one 10-core machine, four mutants at
a time — 125 report sites, 9845 s of battery time, 2695 s of wall clock — and it
is nowhere near evenly spread:

| library | sites | battery time | share |
|---|---:|---:|---:|
| `corpus_contract.py` | 31 | 4352 s | 44% |
| `protected_paths.py` | 11 | 1825 s | 19% |
| `triage_rules.py` | 14 | 1114 s | 11% |
| the other ten | 69 | 2554 s | 26% |

`run-all.sh` finishes in under a minute and is what people wait on before a
merge; three quarters of an hour inside it is how a suite gets switched off. So
it is declared in `SLOW_SCOPED` — with the reason and the workflow that does run
it — which keeps it in `run-all.sh --list`, keeps it required by
`gate-contract-inventory.sh`, and stops it being quietly absent. A gate that is
silently missing is indistinguishable from a gate that passed. Run it here with
`EHS_SWEEP=1`.

In CI it is **one job per library**. The work divides perfectly, a library's
mutants only ever run that library's battery, and the table says the total is
dominated by one library — so sharding makes the critical path
`corpus_contract.py` alone rather than the sum, on a runner it does not share.
Measured on the first clean run, and the two causes are separable, because
attributing all of it to sharding would be false:

| | wall clock |
|---|---:|
| this Mac, 10 cores, one job, 4 workers | 2695 s |
| one `ubuntu-latest` runner, 4 workers (sum of the 13 shard sweeps) | 284 s |
| sharded across 13 runners, end to end, plan and verdict included | **111 s** |

Sharding, machine held constant: **2.6x**, and the critical path is
`corpus_contract.py`'s 82 s exactly as the cost table predicted. That is the
figure this workflow is responsible for.

**The 2695 s is one run, and no ratio is drawn from it.** It was taken on a box
that was also running actionlint and `gh`. An earlier version of this section
divided it by the CI figure and called the remainder "9.5x, the machine"; that
was noise wearing a decimal point. Measured the way the next section says to —
five runs, nothing else on the machine — the same battery is **35.2 s median over
a 30.1–36.4 s range**, an 18% spread, against the runner's 9.3 s per mutant *with
four-way contention*. About **3.8x**, with the Mac given the easier condition.

The counts are identical on both machines, which is the part that says the runner
really did the work: 125 sites, 27 survive, 98 die.

### A death is not a catch

Those 98 deaths were all scored as coverage, and they are not the same thing. The
engine recorded `caught_by` — the cases the battery named when it went red — and
never read it. The verdict was `survived = rc == 0`, so any mutant that turned a
battery red counted as covered, **including one that turned it red by breaking
something**. The header of `coverage_sweep.py` says the operator was kept narrow
precisely so that would not happen, and then the verdict threw the distinction
away.

Two things were wrong, and the second hid the first:

1. A mutant that dies with **no case naming it** was not caught by a case. It was
   caught by a crash, and a crash is caught by anything.
2. The expression that reads case names accepted `FAIL`, which is not a battery's
   case line at all — it is `lib/common.sh`'s `gate_fail`, the **gate's own
   verdict**. Its first word was being read as a case name, so "the gate refused"
   rendered as "a case caught it". On the first three-library sample this alone
   invented a case called `self-test:` and hid a crash behind it.

Measured over the same 125 sites, one machine, four workers, 2055 s:

| | before | after |
|---|---:|---:|
| caught by a case that names it | 98 (assumed) | **91 (measured)** |
| dead with no case naming them | not measured | **7** |
| surviving | 27 | 27 |

The seven were not scattered. All of them sat in the three libraries proved by
the **inline `--self-test` form**, which reports through `gate_fail` and never
names a case, so the sweep could see the gate go red and never which rule the red
belonged to:

| library | sites that only crashed | after giving the self-test a case line |
|---|---:|---:|
| `routing_stage.py` | 5 | 0 |
| `governance_contract.py` | 1 | 0 |
| `stage_eval_floor.py` | 1 | 0 |

The fix is one line per failure — `echo "FAILED  <case>"` beside the `gate_fail`
that already knew the name — and it takes the repository to **zero report sites
covered only by a crash**.

### A zero from a blind instrument is not a zero

Absence of a case name is only evidence where a name has been **seen**. A battery
this sweep never watched name a failing case has an unproven detector, and
calling its silence a hole would be the sweep doing to others exactly what it
exists to catch. Those batteries are declared by name under `detector_unproven`
in the acceptance file, on the same ratchet as the survivors: **listed with a
reason, or the sweep exits 2** — and an entry the run refutes, because it did
watch that battery name a case, is a failure too, so the excuse cannot outlive
the defect. The list is empty today, and that is a measurement rather than a
default: it had three entries when it was written.

Proved in the negative by seven cases
(`a-death-no-case-named-is-not-a-catch`, `gate_fail-is-not-read-as-a-case-name`,
`a-crash-only-site-is-a-failure`, `an-accepted-crash-only-site-is-not-a-failure`,
`an-unproven-detector-is-unmeasurable-not-a-hole`,
`a-declared-blind-battery-is-not-a-refusal`,
`a-refuted-unproven-declaration-is-a-failure`) and by a hand mutation of each new
rule — five of five caught by the case written for it. It is a hand mutation
because **`coverage_sweep.py` excludes itself from its own sweep**. That
exclusion was written up here as a hole, and the next section is what happened
when somebody measured it: the hole is real, and it was not the one described.

### The engine's own report site is a refusal

`coverage_sweep.py` excludes itself from the libraries it mutates, and the
backlog called that a hole in the SUBJECT list. Measured, that reading is wrong,
and it is worth writing down because the correction is the finding.

The sweep's operator is `X.append(...)` as a statement. The engine has seven of
those — `plan`, `results`, `seen`, `found`, `named_by`, `unresolved`, `aborted` —
and **none of them is a report site**. They are all plumbing. Putting the engine
in the subject list would manufacture seven mutants that crash, and, since the
previous section stopped counting a crash as a catch, report seven holes that do
not exist.

The engine does not report through a findings list. It reports by REFUSING: a
`print`, then `return 1` (measured, fails) or `return 2` (could not measure).
Those are its report sites, and the sweep's own question, asked in the engine's
own vocabulary, is: **if this refusal silently became a pass, would any case
notice?** `scripts/coverage-sweep.mutants.py` is the bank that asks it — one
`return 1`/`return 2` rewritten to `return 0` per mutant, in a copy of the tree,
judged by the battery, with the unmutated original as the judge.

| | before | after |
|---|---:|---:|
| refusals in the engine | 14, unmeasured | 14 |
| caught by a case that names them | not measured | **14** |
| **survive: a refusal becomes a pass and nobody notices** | not measured → **3** | **0** |
| red with no case naming them | not measured | 0 |

All three survivors were `except` blocks, and that is the shape of the gap: the
cases covered the CHECKS and left the CATCHES uncovered.

| site | refusal | why it matters |
|---|---|---|
| `:433` | `--list-libraries` over a selection that matches nothing | CI builds the shard matrix from that output |
| `:477` | `--verdict-from` unable to build the plan | the verdict skips its own coverage check |
| `:498` | **`the sweep itself failed`** | a library that does not parse crashes the sweep, and a crashed sweep reads GREEN |

The third is the one that matters most. The deepest scanner in the repository
falling over and reporting clean is the exact failure this file exists to
prevent. Cases 33–35 close all three, and each of the three is the **only** case
that catches its site, so the closure is attributable to the case rather than to
a coincidence.

The bank lives at `scripts/coverage-sweep.mutants.py` with
`scripts/coverage-sweep.mutants.selftest.sh` beside it, so `run-batteries.sh` picks
it up on its own: 14 mutants, four workers, 12 s, 13 MiB of peak disk. It sits
deliberately OUTSIDE `scripts/gates/lib/` — every `.py` in that directory is a
subject of the sweep, and this bank's own `.append` calls are plumbing that would
be read as holes.

It runs the unmutated tree first and exits 2 if that does not come back green.
That baseline is not ceremony. The first version of this bank copied `scripts/`
and not `.github/`, so the case that reads the workflow file failed for want of a
file in all fourteen mutants — and the bank counted that failure as the case
catching the mutant. Fourteen of fourteen caught, zero survivors, and the number
was coverage that did not exist: the defect of the previous section, committed by
the bank written to audit it.

### 32 cases tarring 259 MB each

`gate-protected-paths.selftest.sh` gives each case a work tree by tarring the
repository into `"$TMP/$name"` — a new directory per case. The `rm -rf "$work"`
at the top of the function therefore only ever removed a directory that did not
exist yet, and all 32 copies piled up until the EXIT trap fired. Each copy
included `tooling/claude-cli/node_modules`, 259 MB of the repository's 321 MB,
which this gate reads none of.

| | before | after |
|---|---:|---:|
| peak disk | 7855 MiB | **41 MiB** |
| wall clock | 57 s | **25 s** |
| cases green | 28 of 32 | **32 of 32** |
| `No space left on device` write errors | 2013 | **0** |

Four cases were red for a reason with nothing to do with protected paths. Note
what that means and what it does not: the disk pressure is gone, but the battery
still renders a failed write as a case FAILURE where the exit-code doctrine says
COULD NOT MEASURE. That is a separate defect, it is still open, and removing the
pressure only made it rarer.

### The same defect, in nine more batteries

`gate-protected-paths.selftest.sh` was not special. Nine other batteries carried
the identical pair of mistakes - the unexcluded `node_modules`, and a `work`
that is `"$TMP/$name"` so the leading `rm -rf` deletes a directory that does not
exist yet - and none of them reads a byte of `tooling/`, which was checked
before the exclusion went in rather than after.

| battery | peak before | peak after | |
|---|---:|---:|---:|
| `gate-bench-integrity.selftest.sh` | 6170.3 MiB | **10.1 MiB** | 611x |
| `gate-scorecard-threshold.selftest.sh` | 4292.5 MiB | **10.1 MiB** | 425x |
| `gate-triage-rules.selftest.sh` | 4292.5 MiB | **10.1 MiB** | 425x |
| `gate-corpus-identifiers.selftest.sh` | 3755.9 MiB | **10.1 MiB** | 372x |
| `gate-findings-artifact.selftest.sh` | 3219.3 MiB | **10.1 MiB** | 319x |
| `gate-licence-hygiene.selftest.sh` | 2414.5 MiB | **10.1 MiB** | 239x |
| `gate-bench-blinding.selftest.sh` | 2414.3 MiB | **10.1 MiB** | 239x |
| `gate-secret-scan.selftest.sh` | 2143.9 MiB | **10.1 MiB** | 212x |
| `gate-corpus-contract.selftest.sh` | 536.6 MiB | **20.3 MiB** | 26x |
| **the nine together** | **29240 MiB** | **101 MiB** | **289x** |

Freeing each case's copy when the case ends is the half of the fix that matters
for a battery whose cases outnumber its cores; excluding `node_modules` is the
half that matters for every single copy. The gate under test never sees a
difference: the same tree, minus 259 MB it does not open.

### The instrument that reported a regression that had not happened

The first version of this table was measured by sampling the machine's FREE DISK
while each battery ran. It reported that `gate-corpus-contract.selftest.sh` had
got **worse** - 290 MiB before, 601 MiB after - and that `gate-bench-integrity.selftest.sh`
still held 1727 MiB after the fix. Both were artefacts. Free space is a
machine-wide number: every neighbouring process moves it, so what that
instrument measured was the laptop, not the job. It is the same defect the disk
floor above was fixed for, one level up, committed this time into the ruler
rather than into the rule.

Measured instead on the tree the battery itself creates under `TMPDIR`, the two
cells read 536.6 MiB -> 20.3 MiB and 6170.3 MiB -> 10.1 MiB. Nothing regressed.

The two instruments can be told apart without trusting either one, and without
any argument about which is right, by pointing both at something that did not
change. 12 batteries were left untouched by this commit. Here is what free-disk
sampling said about their peaks on two consecutive runs of the same suite over
the same code:

| untouched battery | run A | run B | |
|---|---:|---:|---:|
| `meter.selftest.sh` | 534.2 MiB | 1.1 MiB | 486x |
| `time-repeat.selftest.sh` | 148.4 MiB | 0.6 MiB | 247x |
| `run-batteries.selftest.sh` | 9.8 MiB | 0.0 MiB | 98x |
| `verify-target-checkout.selftest.sh` | 0.8 MiB | 13.8 MiB | 17x |
| `gate-agent-tools.selftest.sh` | 126.1 MiB | 1570.3 MiB | 12x |
| `gate-benign-control.selftest.sh` | 18.9 MiB | 142.6 MiB | 8x |
| `gate-protected-paths.selftest.sh` | 36.7 MiB | 158.1 MiB | 4x |
| `coverage-sweep.mutants.selftest.sh` | 129.1 MiB | 495.9 MiB | 4x |
| `gate-coverage-sweep.selftest.sh` | 9.4 MiB | 22.9 MiB | 2x |
| `gate-verdict-vocabulary.selftest.sh` | 8.8 MiB | 8.4 MiB | 1x |
| `gate-reproduction.selftest.sh` | 270.5 MiB | 277.8 MiB | 1x |
| `gh.selftest.sh` | 325.0 MiB | 328.2 MiB | 1x |

The instrument disagrees with ITSELF by up to 486x on work that did not change
by a byte. `meter.selftest.sh` alone reads 534.2 MiB and then 1.1 MiB. Measured on the
batteries' own trees, the same repeat moves the largest before arm by 5.8 MiB
out of 6170 (0.09%) and every after arm by 0.0 MiB.

A number whose repeats disagree by more than the effect being claimed is not
evidence for that effect in either direction, and that is as true of the cell
that flatters the change as of the one that accuses it. It was the accusing cell
that cost the time here: half an hour looking for a regression that had never
happened.

The sampler also has to stay out of its own way. Walking a 6 GiB tree every
0.15 s costs more than the battery being measured, and the first attempt at it
inflated the wall clock of exactly the arm it was meant to accuse - the one with
the most tree to walk. It now sleeps three times the cost of the previous walk,
which bounds it near a fifth of the run whatever it is pointed at. The wall
clock it prints is still not publishable for that reason; it says the battery
ran, and `scripts/time-repeat.py` says how long anything takes.

### A disk floor that never looked at the tree

The sweep stopped launching clones when free disk fell under a flat 3 GiB. That
number measures the machine, not the job. `run_mutant` deletes each clone in its
`finally`, so the most a sweep ever holds at once is `jobs` copies of the tree it
is sweeping.

| | |
|---|---:|
| the repository's tree, as the sweep copies it | 10.1 MiB |
| clones held at once, at the default `--jobs 4` | 4 |
| peak the run can reach | 40.3 MiB |
| free disk the guard demanded | 3072 MiB |
| ratio | **76x** |

The consequence arrived on its own, which is the only reason this section
exists. The refusal bank above sweeps toy trees of a few hundred bytes, fifteen
times over, and inside `run-batteries.sh` it came back COULD NOT MEASURE: 25 of
44 cases red, `free disk fell below 3.2 GB` under every one of them, on a machine
with 4.6 GiB free. Nothing about those trees had changed. Another battery's
temporary files had moved a number the job in front of it did not depend on. The
bank was right to refuse rather than publish a coverage figure it could not stand
behind, and it was still an outage: a guard that refuses work 76x smaller than
its own threshold is not protecting the disk, it is manufacturing NOT MEASURED.

The floor is now the tree times the clones times eight, never under 256 MiB, and
it is printed before the baseline runs so you learn it without waiting:

```
disk floor: 322 MiB applied (4 job(s) x 10314.5 KiB of tree x 8 = 322.3 MiB, never under 256 MiB)
```

| | before | after |
|---|---:|---:|
| floor for this repository | 3072 MiB | **322 MiB**, 8x the peak |
| floor for the battery's toy tree | 3072 MiB | **256 MiB**, the minimum |
| ballast the ballasted case writes | - | 8 MiB, paid 15x by the refusal bank |
| battery cases | 44 | **47** |

It is deliberately not capped at the top. A tree big enough to want more than
3 GiB is precisely the case where the old constant was too SMALL, and it was too
small there for the same reason it was too large here: it never looked at the
tree.

A control was made weaker, so the weaker control was proved to still bite.
`a-floor-it-cannot-meet-stops-the-clones` raises the demand to 953 TiB through
`EHS_SWEEP_MIN_FREE_MIB` and requires rc 2 with the mutants unrun. That branch
existed for the whole life of the constant and no case had ever entered it. All
three new cases were checked in the negative: with the constant put back, exactly
those three turn red and nothing else does, so each is the only case that catches
its rule.

The knob deserves its own paragraph, because the first version of that case did
not have one and was wrong. It reached the branch by arithmetic - 16 MiB of
ballast times 256 clones times eight, a demand of 32 GiB - on the reasoning that
no machine here has 32 GiB free. This laptop does not. The runner has 65 GiB, met
the floor without noticing, and the case came back green locally and **red in
CI**. That is the same defect the floor itself had just been fixed for, one level
up: a verdict that depends on the machine it runs on rather than on the rule it
claims to measure. `EHS_SWEEP_MIN_FREE_MIB` only ever takes the MAXIMUM of the
computed floor and itself, so it can raise the bar and never lower it - a test
hook able to weaken the guard it exercises would be worth less than no hook.

What is still NOT measured: nothing exercises the abort at a threshold a machine
could plausibly meet, because making free disk fall on demand means filling the
disk. The case reaches the branch by asking for an impossible number, which proves
the branch runs, not that the derived threshold is the right one.

Sharding opens exactly one hole, and it is the same hole as before: a library
nobody put in the matrix would be skipped in silence. Two things close it. The
matrix is generated from the tree by `--list-libraries` rather than typed by
hand, and the verdict job re-derives every report site the tree has and exits 2
if the shards between them do not cover all of it
(`a-library-in-no-shard-is-refused-not-ignored`). A shard never judges itself —
measured alone against the whole acceptance file, every shard would fail over the
other twelve shards' entries — so shards MEASURE and `--verdict-from` JUDGES.

### Proved in the negative

`scripts/gates/gate-coverage-sweep.selftest.sh`, 47 cases, over a toy repository
whose answers are decided by construction: one rule with a case, two without, one
of them spanning four lines. The sweep exists to find batteries that are green
for the wrong reason, so a sweep green for the wrong reason would be the joke
writing itself.

Its own first run found a defect in the instrument: the sweep did not say which
battery it had used for each library, so `inline-self-test-counts-as-a-battery`
could not tell a correct resolution from a lucky one. The engine now prints it.

Then the battery was itself swept by hand, by breaking the engine fourteen ways
and asking not *did anything go red* but **did the case written for this defect
go red**. Twelve did. Two were green for a reason other than the one they claim,
and both times the fault was the same: the needle was a fixed string, so
`check#1` matched inside `check#10`. `multi-line-report-is-replaced-whole` was
the worse of the two — with a line-wise operator its four-line site dies of
`SyntaxError` instead of surviving, and the case passed anyway, because the
anchor it looked for also appears on the line saying the mutant died. Needles
prefixed `re:` are now regular expressions and every anchor assertion is bounded,
and the case asserts the site **survives** rather than merely appearing. Fourteen
of fourteen.

Then the workflow's own first run found a thirty-second: GitHub runs every
`run:` block with `bash -e`, and `set -uo pipefail` does not turn that off. With
pipefail, the sweep's rc 1 — a rule survived, which the verdict job exists to
judge — killed the step before the line that reads `PIPESTATUS` to decide what
that 1 meant. Eight shards red in fifteen seconds for a reason with nothing to do
with coverage. Nothing local could have seen it: the step exists only in the
workflow and the gate is deferred. `workflow-reads-an-exit-code-it-can-reach`
sees it now — it walks every `PIPESTATUS` read in the file and fails if the
nearest `set` above it has not turned `-e` off.

Three further cases are refusals rather than verdicts, because an unread result
is not a clean one: a battery already red before anything was mutated
(`red-baseline-refuses-instead-of-reporting`), a selection matching no library,
and a library with no report site at all. All three exit 2.

## The number in the table, run

Every row above that carries a self-test declares how many cases it runs. Until
2026-09-07 nothing compared that number to anything, and the number was wrong
more often than it was checked:

| row | said | ran | what happened |
|---|---|---|---|
| `gate-coverage-sweep.sh` | 31 | **47** | sixteen cases added over four commits; the row was never touched |
| `gate-triage-stage.sh` | 32 | **31** | never true: written wrong in `dc441f0`, and the battery has not changed since `a95347f` (#39) |
| gate-portable-shell | 22 | **25** | found by hand the same week, on another branch |

Two of twelve wrong, and four more that could not be compared to anything at
all, because their self-test ran its cases as straight-line assertions and
finished with a sentence instead of a count. A battery that cannot say how many
cases it ran cannot tell five from zero, so `6 cases` in this table was not a
claim anyone could check — it was decoration. Those four now keep a counter and
print it (`gate-agent-roster.sh`, `gate-coverage-gap-claims.sh`,
`gate-negative-proof-census.sh`, `gate-stage-eval-floor.sh`), and all four turned out
to have been telling the truth. They simply had no way to prove it.

`gate-declared-case-counts.sh` runs every self-test this table names and reads
the count off it. One summary line, `N passed, M failed`, and the total is
`N + M`. Two spellings of that line existed before this gate; the second
spelling (`N PASS / M FAIL`) was rewritten into the first, because a parser that
accepts two forms is a parser that will one day accept a third that means
something else.

### The battery that shrank by platform

CI found this on the gate's first run: `gate-reproduction.sh` runs **33 cases on
macOS and 32 on Linux**. One of them asserts that the sandbox denies the network,
which needs `sandbox-exec`; on a machine without it the case prints `skip` and,
in the branch as written, counted toward neither `pass` nor `fail`. So the tally
shrank silently and the row was right only on a Mac — a number measured on the
machine that happened to write it.

A skipped case is not a case that proved anything, and it is not counted as one.
It is still a case OF THE FILE, and that is what the row counts, so the battery
now prints three numbers, `N passed, M failed, K skipped`, and the sum of the
three is compared against the row. The third group is optional, so the other
eleven batteries are unaffected. When a battery does skip, the gate says so on
that row (`33, and 33 ran (sibling battery, 1 skipped)`) rather than letting the
skip disappear into a matching total.

**Three invocation conventions live in this repository** and the gate finds each
rather than assuming one: a sibling `<gate>.selftest.sh`, a `--self-test` flag on
the gate itself, or a self-test that runs inline on a normal run. Where a gate
offers both a sibling and a flag, the sibling wins — a gate that grew a battery
should not go on being read through its older inline path.

### What it refuses to call a pass

- a self-test that prints no count: the row cannot be checked against anything,
  which is a `2`, not a green
- a self-test that came back red: a count read off a failing battery is not a
  measurement of a passing one
- a row naming a gate that is not there
- a table with no `self-test (N cases)` row at all: a zero here is a blind zero
- the core exiting `1` with no row named — Python exits `1` when it dies, and a
  verdict of "it FAILS" that names nothing is a crash wearing the exit code of
  one

### What it does not measure

Whether the cases are any good, whether `N` is the *right* number of cases for
that gate, or whether a green case measures its rule. That is what the mutant
banks are for. This decides one thing: whether the document tells the truth
about how many there are.

It is also blind to a gate whose row carries no case count at all — twelve rows
declare one and the rest do not, and those are invisible here.
`gate-negative-proof.sh` is the one that refuses a gate with no battery.

### The one row it will not run

Its own. This gate's battery ends with a control case that invokes the gate over
the real tree, so a gate that ran that battery would recurse without a floor.
The row is not left unchecked, and it is not quietly skipped either: the gate
prints which row it did not run and why, and the battery closes its own number
with two assertions that pin each other — the document has to say 19, and the
run has to reach 19. Raising one without the other leaves the file red.

### The tally ledger, and why the job stopped doing the same work twice

Counted with a shim on `bash` that logs each invocation's argv and `exec`s the
real binary, so it changes nothing. One turn of
`run-all.sh --skip gate-actions-lint.sh` — rc 0, 61 s, **228 bash invocations** —
had seven gates running **twice**: `gate-agent-roster.sh`,
`gate-alert-surface.sh`, `gate-budget-ledger.sh`, `gate-coverage-gap-claims.sh`,
`gate-handover-contract.sh`, `gate-negative-proof-census.sh` and
`gate-stage-eval-floor.sh`. Once as themselves, once
because this gate ran their self-test — and under the inline convention that
means running the gate. Measured cost of that half: **8.0 s, median of 5,
spread 2%**.

And the five rows with a sibling battery ran theirs **twice per CI job**: once
here, once in `run-batteries.sh`. Measured: **59.3 s, median of 3, spread 2%**.

So `run-batteries.sh` now leaves a ledger when `EHS_TALLY_LEDGER` names a file —
one line per battery that exited 0, `<sha256 of the file> <path> <its tally>` —
and this gate answers those rows from it. In CI the batteries step runs first
and both steps share the file. Alternating, five runs each:

| arm | runs |
|---|---|
| the gate reading the ledger | median **3.9 s**, range 3.9–4.0 s, spread 3% |
| the gate as before | median **40.4 s**, range 39.6–43.6 s, spread 10% |

The ranges do not overlap. The verdict is identical either way — same rc, same
twelve rows, same counts — and the transcript differs only in the provenance it
prints, which is the point of printing it:

```
checked 12 self-test(s) ... : 7 run here, 5 read off the ledger
  gate-reproduction    33, and 33 ran (earlier in this job, by run-batteries.sh)
```

**The key is the content of the battery file, never its name**, and the ledger
is consulted only for an invocation shaped exactly `bash <something>.selftest.sh`
— what `run-batteries.sh` records. Edit a case, rename the file, check out
another branch, or point a row at a gate rather than a battery, and the hash
misses and it runs. There is no staleness window to reason about because there
is no window, and every miss costs exactly what the check cost before. Only
batteries that exited 0 are recorded: a count read off a red one is not a
measurement, and both sides refuse it independently.

### Cost

Without a ledger it runs twelve self-tests, eight at a time. Measured on a
ten-core box: **67.1 s sequential, 39.7 s at eight threads**, and the floor is
one battery (`gate-reproduction.sh`, 33.4 s) that no number of threads divides.
That is why `run-all.sh` went from 21.5 s to 60.9 s the day this gate landed —
both measured back to back on the same machine. With the ledger the gate itself
is 3.9 s.

The figure that matters to CI is not the gate in isolation but the job around
it. Alternating run for run, three each, `run-all.sh --skip
'gate-actions-lint.sh'` — the exact command the `gates` job runs:

| arm | median | range | spread |
|---|---|---|---|
| with the ledger | **25.3 s** | 25.2-25.5 s | 1% |
| as it stood | **62.0 s** | 62.0-63.8 s | 3% |

The ranges do not overlap, which is what makes this a difference between the two
commands rather than a difference between two moments of the same box. **36.7 s
off every push**, and the gate still checks all twelve rows: seven it runs, five
it reads.

A note on the inline convention: for a gate with neither a sibling battery nor a
`--self-test` flag, "run its self-test" means running the gate itself. If such a
gate were ever also expensive — a weekly sweep, say — this would launch it. The
per-self-test ceiling is 900 s and the run says which convention it used, so the
cost is visible rather than mysterious, but the shape is worth knowing before
adding a gate of that kind.

### Negative proof

`scripts/gates/gate-declared-case-counts.selftest.sh`, 27 cases. Twenty-five
build a toy repository — a table with the rows the case needs and fake gates that
print a count and nothing else — so each costs milliseconds and can assert a
shape the real tree does not currently contain. Both directions of drift, all
three invocation conventions, the sibling beating the flag, `N + M` rather than
`N`, a skipped case counting toward the row and a skip the row did not count,
the last summary line rather than the first, one drifted row among four good
ones, and every refusal listed above. Six are the ledger's: a hit that is not
re-run, an entry whose file changed being ignored, a ledger that cannot answer
for a gate run inline, a ledger that is absent, one that is rubbish, and drift
still caught when it comes off the ledger. In each of those the battery under
the toy prints a count that DISAGREES with the ledger line, so the case can only
pass if the gate read the source it was meant to. The twenty-sixth checks this
file's own row against its own tally. The twenty-seventh is the control: the
real tree, all twelve real batteries, no mutation.

The writer's side is `scripts/run-batteries.selftest.sh`, 20 cases, six of them
the ledger's: a green battery leaves one line keyed by a 64-character hash, a red
one leaves nothing, a battery that prints no tally leaves nothing, no
`EHS_TALLY_LEDGER` means no file is written at all, and editing the battery moves
the key. The sixth is the positive control for the fifth, and it exists because
the fifth was green for the wrong reason: run inside `run-batteries.sh`, this
file inherited the ledger the caller was using, and the toy battery its
"no ledger written" case launched wrote a line into the REAL one. Nothing in the
file noticed — the toy directory stays clean either way and the line lands
somewhere else. So the file now unsets the variable at the top, and a case puts
a probe ledger in the environment to prove the probe can see a write at all. A
"nothing was written" that has never seen a write is not a measurement.

Mutant bank: `scripts/declared-case-counts.mutants.py`, twenty-two mutations of
the core, the wrapper and the runner that writes the ledger, each declaring in
advance which case has to go red. **22 of 22 caught**, in 6 s. Two notes on how
it had to be built. The bank points the control case at a faithful toy repository
rather than the real one, because a mutation of how the invocation is resolved
can make that control launch the real weekly sweep — the first version died
exactly that way, at 900 s. And one mutant is a PAIR of edits: `PIPESTATUS[0]`
and `set -o pipefail` cover the same hole in the runner, so neither is provable
alone and only removing both is a test. A protection that cannot be mutated on
its own is worth saying out loud rather than counting as proven.

And one the suite caught rather than the author: run standalone the bank was
**22 of 22**, and the first time it ran inside `run-batteries.sh` — which
exports `EHS_TALLY_LEDGER` — **one mutant survived**. That mutant changes what
happens when the variable is UNSET, and it was set. The bank now strips it from
the environment of every battery it launches; each case that wants a ledger
builds its own. A mutant whose effect depends on the environment it inherits is
not a measurement, it is a coincidence — and a bank that only ever ran one way
had no way to know which it had.

## A single timing is not a measurement

Wall-clock figures were being published off a single run. Then the same battery,
three times back to back on a quiet machine with nothing changed, came back
30 s, 45 s, 38 s — a spread wider than most of the improvements those figures
were used to claim. Nothing carried an error bar, so nothing could be told apart
from noise, and one conclusion drawn that way ("the Mac is 9.5x slower than the
runner") had to be withdrawn.

Not every figure was blind: "the battery suite went 364.7 s to 141.5 s" was taken
twice per arm, **alternated**, with ranges that do not overlap. That one is under
the bar set here and above the one that matters, and the difference is the whole
subject of this section.

```bash
scripts/time-repeat.py --runs 5 --label "the battery" -- bash scripts/gates/gate-corpus-contract.selftest.sh
```

It prints every run, then the median **with its range and the spread as a
percentage**, and it will not print a median alone. What it refuses matters more
than what it prints:

| | |
|---|---|
| `--runs 1` | refused. One sample cannot show a spread, and that is the whole point |
| the command exits non-zero | exit 2, NOT MEASURED. A command that failed is not a slow command |
| `--warmup` | runs are dropped only after being printed, never silently |
| `--max-spread` | judges the **spread**, not the speed: a box too noisy to measure on says so instead of handing back a median |
| `--against CMD` | runs a second command **alternately** with the first and answers the only question an A/B has: do the two ranges overlap? |
| `--contenders N` | runs N more copies of the same command alongside each timed run, so a figure taken under load can be compared with one that was |

Quote the range whenever the spread is over 10%. A change smaller than the spread
is not an improvement you measured; it is the box.

### A block against a block is not an A/B

One afternoon, the same battery, unchanged, five runs a block:

| block | median | range | internal spread |
|---|---:|---|---:|
| A | 28.3 s | 26.2–29.3 s | 11% |
| B, twenty minutes later | 40.4 s | 35.3–41.1 s | 14% |
| C, twenty minutes after that | 43.6 s | 40.7–47.6 s | 16% |

Each block is tight. **No two blocks overlap.** Timing the old code in one block
and the new code in the next would have "measured" a 54% regression that was
nothing but the afternoon — and in the other direction it would have signed a 35%
improvement just as confidently. That is what `--against` exists for: it
interleaves the arms run for run, so whatever drifts drifts through both, and it
ends on the only verdict worth printing —

```
The two ranges do not overlap. That is a difference between the commands, not
the box under them.
```

or the refusal that is the same sentence turned around, `the two ranges OVERLAP`.

### The number a figure was taken under travels with it

`35 s` and `140 s` of the same battery do not contradict each other; one was
taken alone and the other with four copies running. A median without its load is
as misleading as a median without its range, so `--contenders` prints the
condition against the number itself and not only in the header.

That flag found something the moment it was pointed at this repository:
`gate-corpus-contract.selftest.sh` still `tar`red the whole tree **once per case**
and freed none of them until the battery exited — the two savings of earlier work
had never reached it. Four copies at once could not run at all: 22.9 GB of free
disk gone and `No space left on device`, which the instrument correctly reported
as NOT MEASURED rather than as a slow run. Measured and fixed, alternated arms:

| | before | after |
|---|---|---|
| wall clock | 40.5 s (28.8–51.9) | **15.1 s (10.2–16.1)**, ranges disjoint |
| disk peak, one copy | 7,083 MB | **275 MB** |
| four copies at once | did not fit on the machine | 50.7 s (46.8–72.0), 2,238 MB |

The last row is what a mutant in the local sweep actually costs, and it is the
figure the "140.4 s per mutant" of an earlier single run should be read against.

Proved in the negative: `scripts/time-repeat.selftest.sh`, 28 cases, and
`scripts/time-repeat.mutants.py`, which silences one rule of the instrument at a
time and demands that the case written for it goes red — **twenty of twenty**. A
stale anchor there exits 2, NOT MEASURED, rather than reporting a smaller total:
four anchors went stale during this very refactor, and a bank that quietly shrank
would have called that progress.

### The bank that said 0 while reporting a rule nobody measures

Wiring that bank to a runner turned out to be the smaller half of T-ehs-55. Its
docstring promised the usual three exit codes — 0 every mutant caught, 1 one was
not, 2 could not measure — and the file contained no `sys.exit(1)` at all. It
printed `SOBREVIVE  <- nadie lo caza` and then exited **0**. Any runner would
have read that as a pass, which makes it the exact defect the bank exists to
find, sitting in the bank: a green that means nothing. The refusal had the
matching problem one level up — a battery it could not measure was announced as
`la bateria ya esta roja` and exited 1, a measured failure, when no baseline had
been established at all.

Each row was run, before and after, with a bank reduced to one mutant so the
control costs one battery instead of twenty-one:

| control | before | after |
|---|---|---|
| a mutant nobody catches | **rc 0**, `SOBREVIVE` | rc 1, and it names the battery to write the case in |
| red, but not by the case that claims it | rc 0 (same path; `sys.exit(1)` appears 0 times in the file) | rc 1 |
| an anchor that no longer matches | rc 2 | rc 2, unchanged |
| the baseline could not be measured (battery rc 2) | **rc 1**, "la bateria ya esta roja" | rc 2, "no se pudo medir sin mutar" |
| the baseline is red (battery rc 1) | rc 1 | rc 2 — without a green baseline, a red under a mutant proves nothing |

Then the wiring, and it is not a gate. `scripts/time-repeat.mutants.selftest.sh`
execs the bank, which is what `run-batteries.sh` discovers — the same shape as
`coverage-sweep.mutants.selftest.sh`, and deliberately not under
`scripts/gates/`, where `run-all.sh` takes anything that is not documentation,
data, fixtures or `lib/` for a gate. Batteries: **32 → 33**.

The cost is 174 s measured, twenty mutants at one whole battery each plus the
baseline, twice giving twenty of twenty. Whether that is visible in the suite's
wall clock is a question this machine cannot answer: the sequential runner
disagrees with itself by 174 s over identical code, so the added work is
declared here as work rather than defended with a stopwatch reading that does
not exist.

#### The fallback that could never run

Wiring it turned CI red on the first push, and the failure was Linux-only. The
bank copied the pristine tree per mutant with

```python
subprocess.run(["cp", "-Rc", pristine, work], capture_output=True) \
    or subprocess.run(["cp", "-R", pristine, work], check=True)
```

which is the shell idiom `cp -Rc … || cp -R …` transliterated into Python. It
is not a fallback. **`CompletedProcess` is always truthy**, so the second call
could never run — not on a bad day, not ever. And `cp -c` asks for an APFS
clonefile that GNU coreutils does not have, so on the runner the first call
exited at option parsing, nothing was copied, and the next `read_text()` raised
`FileNotFoundError`. On this Mac the first call always worked, which is why the
defect shipped: the arm that was broken was the one macOS never takes.

The second defect was in how that arrived. A Python traceback exits 1, so
`run-batteries.sh` filed a crash as `did not behave as specified` — a measured
failure — and pointed the reader at the mutant instead of at the copy. Under
`scripts/gates/lib/common.sh` a run that never reached a judgement is 2.

Both were run in the negative on macOS by rejecting `-Rc` the way GNU coreutils
rejects it, with the bank reduced to one mutant so a control costs one battery
instead of twenty-one:

| control | result |
|---|---|
| old code, `cp -Rc` rejected | rc 1, `FileNotFoundError … /cnt-*/una-sola-vuelta-deja-de-rechazarse/scripts/time-repeat.py` — the CI failure, reproduced locally |
| new code, `cp -Rc` rejected | rc 0, `cazado por one-run-is-refused` — the fallback copied and the bank judged |
| new code, both copies rejected | rc 2, `NO MEDIDO: el banco se cayo antes de juzgar` |

The control that should have caught this is written and does not run, and would
not have caught it either. `origin/loop/portable-shell-gate` carries a
catalogue rule `cp-c` whose remedy field says, verbatim, `cp -R, or cp -Rc ...
|| cp -R ... so the clone is tried and never assumed`. That branch is unmerged,
and `lib/portable_shell.py` scans `SUFFIXES = (".sh", ".bash")` — this defect
lived in a `.py`, in a `subprocess` argv list, where the catalogue's shell
regex has nothing to match. Extending it to Python argv lists is the ticket;
merging that branch alone would not have helped.

### The intermittent that turned out to be three defects

The red that surfaced beside it was the documented intermittent in
`a-dead-contender-is-unmeasurable`, whose header said in as many words that the
cause was NOT established after 600 controlled repetitions. It is established
now, and the thing that established it was fixing the diagnostic written to
explain it.

**One.** That diagnostic read `ls -l /dev/fd/2 2>&1`, and the `2>&1` points the
process's own fd 2 at the substitution pipe *before* `ls` resolves the path. It
described the redirection, not the state under test, so it reported `p-w--w----`
— a pipe — one line after `[ -p /dev/fd/2 ]` had said no. Read at face value it
accuses `test` of a defect that lives in the diagnostic. `ls` now keeps the
original fd 2, and case 27 pins the property: with fd 2 on a regular file, a
line that names fd 2 must describe a regular file.

**Two.** With an honest diagnostic the next occurrence answered the question on
sight: `-p said no 1 time(s); on one more look: yes`, beside an `ls` that read
the real descriptor and printed `p-w--w----`. What is transient is the
`/dev/fd` lookup, not the descriptor — the fd was a pipe throughout. One probe
is not an answer, so the probe is now bounded at five. Bounded, because a
contender's stderr is genuinely not a pipe and a probe allowed to spin until it
likes the answer is not a probe.

**Three, and it was ours.** The classifier added for `overlapping-ranges-are-
the-box` recomputed overlap from the ranges the tool printed. Printing rounds to
`%.1f`, and the two directions are not symmetric: printed apart means apart,
because rounding moves each end by at most 0.05 s and a visible gap is at least
0.1 s. Printed *touching* means nothing on its own — two ranges 0.1 s apart can
print the same boundary. The case failed on exactly that: `0.4-0.6` and
`0.4-0.4`, which touch only where the rounding put them. An overlap is now read
as one only when it clears the rounding that produced it, and the band between
is a third answer.

That correction then exposed the case's own dead end. Two 0.4 s arms print
`0.4-0.4` and `0.4-0.4`; a range 0.0 s wide can never clear 0.1 s, so the case
reported COULD NOT MEASURE on 4 of 4 runs — sound, and useless. **A case that
cannot create its own condition does not measure the rule, whatever colour it
prints.** The arms now carry a spread wider than the rounding and the *same*
one: `wide.sh` keys its sleep on invocation number in pairs (0.2, 0.2, 0.6,
0.6), so `--against`, which alternates A,B,A,B, hands 0.2/0.6/0.2 to both arms
rather than the fast one to A and the slow one to B. Keying on parity is how
this was got wrong once before: it separates the arms instead of widening them.
Both arms print 0.2-0.6, the overlap clears the rounding by 0.3 s, and the case
costs 2.0 s instead of 2.4 s.

| control | result |
|---|---|
| the diagnostic put back to `2>&1`, fd 2 on a regular file | 26 PASS / 1 FAILED — case 27, saying `ls described it as: p-w--w----` |
| the rounding band signed green instead of unmeasured | 27 PASS / 1 FAILED — case 28, and nothing else |
| the battery as it stands | 28 PASS / 0 FAILED / 0 COULD NOT MEASURE, rc 0, on 4 of 4 runs |

Cases: **26 → 28**.

#### And the case itself was only true on one platform

Case 27 went green on macOS and red on the runner on its first push, which is
the second Linux-only defect in two commits and the same shape as the first: a
control written and proved on the arm that cannot fail. It asked `ls -l
/dev/fd/2` and required a regular file. On macOS `/dev/fd/N` is an fdesc node
and stats as the open file itself, so that holds. On Linux it is a symlink into
`/proc/self/fd`, so a bare `ls -l` describes the LINK: `l-wx------ 1 runner
runner 64 … /dev/fd/2 -> /tmp/…/fd2.target`.

`ls -lL` follows it, and that single letter is what makes the question portable:
a regular file answers `-` on both, and the pipe a redirection would have
substituted answers `p` on both. Measured rather than argued — this Mac cannot
run the Linux arm, so the Linux SHAPE was built here instead, a `mkfifo` with a
symlink to it:

| probe on a symlink to a fifo | answer | would the case have caught it? |
|---|---|---|
| `ls -l` (what case 27 shipped with) | `lrwxr-xr-x … -> …/f` | no — `l`, not `p`: blind on Linux |
| `ls -lL` | `prw-r--r-- … ` | yes |

Both the diagnostic and the case now use `-L`. The macOS half of the control was
re-run with the lying `2>&1` restored: 27 PASS / 1 FAILED, case 27, saying `ls
described it as: p-w--w----`.

### The battery that answers differently on a busy machine

Two cases of `scripts/time-repeat.selftest.sh` were caught going red on work
that had not changed, and only while the machine was loaded. Counted, not
guessed:

| condition | runs | red |
|---|---:|---:|
| the battery alone, idle box | 12 | 0 |
| the battery alone, 14 spinning processes beside it | 8 | 1 (`overlapping-ranges-are-the-box`) |
| inside a full suite run of 519.7 s | 1 | 1 (`a-dead-contender-is-unmeasurable`) |

`overlapping-ranges-are-the-box` asserted that two runs of the SAME command
produce ranges that overlap. Under contention they need not, and when they did
not the case said FAILED — a verdict about the box, delivered as a verdict about
the tool. By this repository's own doctrine that is a **2, could not measure**,
and the battery had no way to say it. Both halves are now fixed, and the second
one is the one that matters:

- The arms are `slow.sh` (0.4 s) and no longer a command that finishes under the
  0.1 s the report prints. Two ranges of rounded zeros carry no signal at all, so
  a neighbouring process could pull them apart with nothing in the transcript to
  show that it had.
- The case no longer reads the verdict line as evidence about itself. A
  classifier reads the two ranges the tool PRINTED and decides on its own whether
  they touch. Ranges that touch under a verdict of "difference" is a defect in
  the tool and is still a FAILURE. Ranges that genuinely do not touch, for two
  runs of one command, is the box moving under the case: COULD NOT MEASURE,
  counted apart from pass and fail, and the battery exits 2. Rounding cannot
  invent that gap — it is monotone, so ranges that are apart at 0.1 s were apart
  before they were printed.

| the battery under 14 spinning processes | runs | red | could not measure |
|---|---:|---:|---:|
| before | 8 | 1 | — |
| after | 8 | 0 | 0 |

A third answer is also a way to make any red disappear, so it arrives with the
measurement that it did not:

| control | wanted | measured |
|---|---|---|
| the mutant `todo-par-de-rangos-es-una-diferencia` (`if True:`) | still caught | case 20 FAILED, battery rc 1 |
| the real tool on arms that genuinely separate, 0.2-0.5 s against 0.9-0.9 s | could not measure | `COULD NOT MEASURE`, battery rc 2, nothing FAILED |
| the classifier's own box branch mutated to `pass` | case 26 goes red | case 26 red |

The first and the last of those three live in the battery as cases 25 and 26,
reading canned transcripts, so they run on every commit instead of only when
somebody loads the machine on purpose.

`a-dead-contender-is-unmeasurable` is the one that was made readable. Its
fixture tells the measured run from a contender by asking whether its own stderr
is the pipe the tool captures, and every other answer - including *I could not
tell* - was filed as "I am a contender". 600 controlled repetitions of that
discriminator under load did not reproduce the failure and **the cause is not
established**; what is fixed is that the next occurrence will name itself. A
stderr that is neither the captured pipe nor a contender's sink now says so and
exits 9. Proved in the negative directly: with fd 2 closed the old fixture exits
7 and the new one exits 9, and the new case demands the 9.

### Running the batteries at the same time, and why it is not in yet

`scripts/run-batteries.sh` is sequential on a ten-core laptop, and after the
disk peaks came down (29240 MiB to 101 MiB across nine batteries) running them
together stopped being a way to fill the disk. A parallel candidate was written
and checked where the answer is not noisy: `--list` is identical (32 batteries
at the time of that comparison),
and against a sequential transcript it differs by the three lines the sequential
runner already differs from ITSELF by - one mutant timer and two temporary paths
- plus exactly one declared line, `batteries run: 32 (up to 4 at a time)`. Order
is preserved and every verdict matches.

It is not merged, because the number that would justify it **could not be
measured here**. Four alternated suite runs:

| arm | runs |
|---|---|
| sequential, unchanged | 309.5 s and 483.6 s |
| candidate, 4 workers | 331.4 s and 249.0 s |

The sequential runner disagrees with itself by 174.1 s, 56% of its own faster
run, over identical code. That range swallows the whole effect in both
directions, so neither "it is faster" nor "it is slower" is a reading this
machine can support. A merge would be argued, not measured.

## Branch naming

- `main` — channel `latest`. No direct pushes.
- `stable` — weekly promoted channel. No direct pushes.
- `feat/*`, `fix/*`, `docs/*` — human work.
- `bot/knowledge-YYYY-WW` — the knowledge loop. Stricter rules, per G7 and G4.
