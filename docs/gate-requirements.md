# Gate requirements

The specification the CI gates implement. This file states **what must be true**; the executable checks live under `scripts/gates/` and the workflows under `.github/workflows/`.

Written as a contract on purpose: the corpus and the machinery that guards it are maintained separately, and this is the interface between them. If a gate and this document disagree, the disagreement is itself a bug — fix both in the same pull request.

> **Status.** Partly running, partly specification, and the table below says which is which. Seventeen gates execute on every push and pull request through `.github/workflows/ci.yml`; two more run where they can only run — in a pull request — through `.github/workflows/issue-closure-gate.yml`; and one runs where its input exists, in `.github/workflows/scorecard.yml`. Eight have their own self-test battery. What has **not** landed: `stable`, a tagged release, and the knowledge loop. **Every gate in the table below is running.** Anything marked *specified* describes a control that is not running. See `docs/design-decisions.md`.

## What runs today

| Requirement | Status | Implementation |
|---|---|---|
| `G1` manifest and structure | running | `gate-plugin-integrity.sh` + self-test, `gate-plugin-version.sh` + self-test |
| `G1b` audit-only posture | running | `gate-agent-tools.sh` + self-test |
| `G2` internal links | running | `gate-plugin-integrity.sh` (link resolution) · `gate-corpus-contract.sh` (routing to pack sections) |
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
| governance contract | running | `gate-governance-contract.sh` + self-test |
| `A1`/`A2`/`A3` corpus identifiers | running | `gate-corpus-identifiers.sh` + self-test (14 cases) |
| pooled-batch blinding | running | `gate-bench-blinding.sh` + self-test (9 cases) |
| governance drift | running in a live repo | `gate-governance-drift.sh` + self-test |

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

**Two declared exemptions, both visible in the output.** A `Traceability` line may state that no external identifier applies (`internal process`, `no external identifier`, `the one from the original finding`) — five procedures in `remediation.md` do. And text that quotes a superseded figure on purpose — a changelog entry saying what a file *used to* declare — is exempt only inside a `<!-- counts:historical -->` region, in the same idiom `gate-verdict-vocabulary.sh` uses. Both are counted and printed on every run rather than silently swallowed.

**What it does not measure.** Whether a procedure is correct, whether an identifier maps to what the standard actually says, and whether the traceability matrix lists every procedure that cites a family — 28 of 139 procedures are absent from that matrix today, which is open work, not a passing check.

Proved in the negative by `gate-corpus-contract.selftest.sh`: 20 cases, each breaking exactly one thing on a throwaway copy, asserting the exit code **and** the reason, including a control case on the untouched repository and two cases that must exit `2`.

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

A pull request from a `bot/` branch **fails** if its diff touches any of:

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

These define what the system may do and what it may read. An automation that can edit its own limits has none. Human branches may touch them; the maintainer reviews.

**Implemented 2026-08-21** as `gate-protected-paths.sh`, and the list above is no longer prose: it is checked, line for line and in order, against `scripts/gates/data/protected-paths.json`, so the rule and the sentence documenting it cannot drift apart. Two self-test cases exist for exactly that drift, one in each direction.

**A human branch touching a protected path is printed, never silently allowed.** The maintainer reviews it, and can only review what the run tells them is there — so the gate lists every protected path in the diff and says which pattern caught it. What it does not judge is whether the change is a good one: it asks who is changing the limits.

It runs in the pull-request workflow rather than in the push suite, because a branch name and a diff against a base are things only a pull request has; `run-all.sh` defers it with a printed reason instead of running it against an empty diff and reporting a green that means nothing. Proved in the negative by `gate-protected-paths.selftest.sh`: 10 cases — three automated branches touching three different protected patterns, an automated branch touching nothing, a human branch touching one, the documented list and the enforced list drifting in each direction, and three cases that must exit `2` (an unknown branch, a missing file list, an unusable data file). The unknown-branch case earned its keep on the first CI run: `git rev-parse` inside a directory that is not a repository walks **up** and answers about an ancestor one, so on a runner the gate confidently reported the wrong branch where it should have reported that it could not tell. It now falls back to git only when the root it was given is itself the top level. And the battery itself was not hermetic: on a runner `GITHUB_HEAD_REF` is set, the gate reads it as a default, and the case meant to prove *I cannot tell whose branch this is* was quietly told. Every case now runs with those variables cleared — a battery that inherits the environment is not proving what it claims.

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

| Check | Threshold | Why it matters here |
|---|---|---|
| `Dangerous-Workflow` | must be `10` | A single `pull_request_target` with untrusted checkout is the exact CSA-documented chain. |
| `Token-Permissions` | `>= 9` | An over-permissioned `GITHUB_TOKEN` is what turns an injection into a compromise. |
| `Pinned-Dependencies` | `>= 8` | Tags are mutable and have been repointed at malicious commits in the wild. |
| `Branch-Protection` | `>= 8` | The whole promotion model assumes nobody pushes directly. |
| `Binary-Artifacts` | must be `10` | A knowledge repository has no reason to contain binaries. |
| `License` | must be `10` | |
| `Security-Policy` | must be `10` | A security tool without a disclosure policy is a contradiction. |

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
- a name this document carries that the runner does not discover is **a control the document promises and nobody runs**.

The inventory comes from `run-all.sh --list`, never from a glob of `scripts/gates/`. The runner is the authority on what counts as a gate — it discovers recursively and is not filtered by extension — so the two cannot disagree about what exists. A gate the runner declares it will not run in this context still counts: *not run here* is not *does not exist*.

Three things are deliberately **not** checked, because all three are a person's judgement: which row a gate belongs to, whether the row's status word is accurate, and whether the requirement text describes what the gate actually does.

`*.selftest.sh` is excluded. A self-test battery is not a gate and the runner does not list it as one, so the sentence above naming `gate-corpus-contract.selftest.sh` is correct prose. Counting it made this gate report a phantom on its first run against the repository, and the fixture `good/2-a-selftest-is-not-a-gate` is that mistake, kept.

Proved in the negative by 6 fixtures — 2 negative, 2 positive, 2 unmeasurable — run as the gate's own self-test on every invocation.
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

## Branch naming

- `main` — channel `latest`. No direct pushes.
- `stable` — weekly promoted channel. No direct pushes.
- `feat/*`, `fix/*`, `docs/*` — human work.
- `bot/knowledge-YYYY-WW` — the knowledge loop. Stricter rules, per G7 and G4.
