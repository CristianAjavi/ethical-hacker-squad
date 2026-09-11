# Gate requirements

The specification the CI gates implement. This file states **what must be true**; the executable checks live under `scripts/gates/` and the workflows under `.github/workflows/`.

Written as a contract on purpose: the corpus and the machinery that guards it are maintained separately, and this is the interface between them. If a gate and this document disagree, the disagreement is itself a bug — fix both in the same pull request.

> **Status.** Partly running, partly specification, and the table below says which is which. Forty-four gates exist. **Thirty-nine** execute on every push and pull request through `.github/workflows/ci.yml` — thirty-seven in its `gates` job, `gate-actions-lint.sh` in the `workflow-hardening` job that installs the tools it needs, and `gate-case-counts.sh` in a job of its own because it runs every battery it cites and costs 301 s; **two** run where they can only run — in a pull request — through `.github/workflows/issue-closure-gate.yml`; **one** runs where its input exists, in `.github/workflows/scorecard.yml`; and **two**, `gate-governance-drift.sh` and `gate-alert-live.sh`, read the live repository through the GitHub API with a scope a workflow token is not known to have, so they are deferred **by name with that reason** and a person runs them. Those last two are the only gates with no CI lane at all, and each is written down in `scripts/gates/data/deferred-lanes.json` with its reason and the command that does run it — an absence that is a decision with an owner rather than a silence that reads like coverage. Twenty-eight have their own self-test battery beside them; the other sixteen carry one inline. These figures are what `scripts/gates/run-all.sh --list` and the tree report; if they and this sentence disagree, the sentence is the one that is wrong. What has **not** landed: `stable`, a tagged release, and the knowledge loop. **Every gate in the table below is running.** Anything marked *specified* describes a control that is not running. See `docs/design-decisions.md`.

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
| `G10` a path that names one machine | running | `gate-machine-identity.sh` + self-test (25 cases <!-- cases: scripts/gates/gate-machine-identity.selftest.sh -->) |
| triage rules | running | `gate-triage-rules.sh` + self-test |
| triage-stage eval integrity | running | `gate-triage-stage.sh` + self-test (31 cases) <!-- cases: scripts/gates/gate-triage-stage.selftest.sh --> |
| findings artifact | running | `gate-findings-artifact.sh` + self-test |
| bench integrity | running | `gate-bench-integrity.sh` + self-test |
| bench index | running | `gate-bench-index.sh` + self-test |
| an outside tool's number still reproduces | running | `gate-external-crosscheck.sh` + self-test (24 cases) <!-- cases: scripts/gates/gate-external-crosscheck.selftest.sh --> |
| agent roster census | running | `gate-agent-roster.sh` + inline self-test (6 cases) |
| stage-eval separability floor | running | `gate-stage-eval-floor.sh` + inline self-test (8 cases) |
| routing stage dataset | running | `gate-routing-stage.sh` + inline self-test (13 fixtures) |
| coverage gap claims | running | `gate-coverage-gap-claims.sh` + inline self-test (5 cases) |
| reproduction cross-check | running | `gate-reproduction.sh` + self-test (33 cases) <!-- cases: scripts/gates/gate-reproduction.selftest.sh --> |
| served-tree delta | running | `gate-tree-delta.sh` + self-test |
| verdict vocabulary | running | `gate-verdict-vocabulary.sh` + self-test |
| promotion invariant | running | `gate-promotion-safepath.sh` + self-test |
| negative evidence | running | `gate-negative-evidence.sh` |
| benign control | running | `gate-benign-control.sh` + self-test |
| report contract | running | `gate-report-contract.sh` |
| workflow hardening | running | `gate-workflow-hardening.sh`, `gate-actions-lint.sh` + self-test |
| a capture of `$?` the shell never reaches | running | `gate-errexit-rc-capture.sh` + self-test (30 cases <!-- cases: scripts/gates/gate-errexit-rc-capture.selftest.sh -->, 8 of them mutants of the detector) |
| label taxonomy | running | `gate-labels-taxonomy.sh` |
| contract inventory: the gates, and the batteries this document names | running | `gate-contract-inventory.sh` + self-test |
| the case counts this document quotes about a battery | running | `gate-case-counts.sh` + self-test |
| negative proof | running | `gate-negative-proof.sh` + self-test |
| negative proof, its SIZE | running | `gate-negative-proof-census.sh` + self-test (6 cases) |
| budgets, and the figure behind each | running | `gate-budget-ledger.sh` + self-test (25 cases) <!-- cases: scripts/gates/gate-budget-ledger.sh --> |
| the alert surface, and what an alert on it means | running | `gate-alert-surface.sh` + self-test (16 cases) <!-- cases: scripts/gates/gate-alert-surface.sh --> |
| the alert surface of the live repository, alert by alert | running in a live repo | `gate-alert-live.sh` + self-test (8 cases) <!-- cases: scripts/gates/gate-alert-live.sh --> |
| the handover: the deliverable is named on screen when a run ends | running | `gate-handover-contract.sh` + self-test (21 cases) <!-- cases: scripts/gates/gate-handover-contract.sh --> |
| governance contract | running | `gate-governance-contract.sh` + self-test |
| `A1`/`A2`/`A3` corpus identifiers | running | `gate-corpus-identifiers.sh` + self-test (14 cases) <!-- cases: scripts/gates/gate-corpus-identifiers.selftest.sh --> |
| pooled-batch blinding | running | `gate-bench-blinding.sh` + self-test (9 cases) <!-- cases: scripts/gates/gate-bench-blinding.selftest.sh --> |
| tooling completeness | running | `gate-tooling-blindspot.sh` + self-test (12 cases <!-- cases: scripts/gates/gate-tooling-blindspot.selftest.sh -->) — a procedure that sends the auditor at a path `rg`/`fd` hide by default carries at least one invocation able to reach it |
| governance drift | running in a live repo | `gate-governance-drift.sh` + self-test |
| deferred controls have a lane | running | `gate-deferral-lane.sh` + self-test (19 cases <!-- cases: scripts/gates/gate-deferral-lane.selftest.sh -->) |
| the discovery sweep can see | running | `gate-discovery-controls.sh` + self-test (15 cases <!-- cases: scripts/gates/gate-discovery-controls.selftest.sh -->) |
| pack routing reachability | running | `gate-pack-routing.sh` + self-test (12 cases <!-- cases: scripts/gates/gate-pack-routing.selftest.sh -->) |

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

This document has asked, since it was written, that **every** gate be proved in the negative. Measured against `run-all.sh --list` **when this section was written, with seventeen gates in the tree**, four had no negative proof of any kind — no battery, no fixtures, no inline self-test. The tree has grown since; the standing count is in the Status note above, and this section records what that measurement found:

| Gate | What goes wrong silently without it | Cases now |
|---|---|---|
| `gate-plugin-version.sh` | a frozen `version` in `plugin.json` makes `/plugin update` skip the plugin: commits merge for months and no installed user receives them, with no error | 13 <!-- cases: scripts/gates/gate-plugin-version.selftest.sh --> |
| `gate-plugin-integrity.sh` | the shape of everything a user loads — frontmatter, links, symlinks, the execute bit, the size budget | 22 <!-- cases: scripts/gates/gate-plugin-integrity.selftest.sh --> |
| `gate-verdict-vocabulary.sh` | the five-spellings drift this vocabulary was written to end, coming back | 12 <!-- cases: scripts/gates/gate-verdict-vocabulary.selftest.sh --> |
| `gate-labels-taxonomy.sh` | GitHub **drops** an undeclared label without a word and the issue arrives unclassified | 12 <!-- cases: scripts/gates/gate-labels-taxonomy.selftest.sh --> |

Three of the four run on a throwaway tree built by the battery; `gate-verdict-vocabulary.selftest.sh` copies the real corpus instead, because a hand-written vocabulary would drift from the one the gate polices. `gate-labels-taxonomy.sh` resolves its root from its own location and takes no override, so its battery copies the gate into the throwaway tree rather than changing the gate to be testable.

Two of those cases are worth naming. `gate-plugin-integrity.sh` states in a comment that a `grep '^allowed-tools:'` was *demonstrated evadable* — `"allowed-tools": Bash(*)` and `allowed-tools : Bash(*)` are the same key to any YAML parser and neither starts with the literal. All three spellings are now measured, plus the `EHS_ALLOW_TOOLS_FRONTMATTER=1` escape hatch that must still let a human say yes. And the only route into `gate-plugin-version.sh`'s base-ref lookup is channel `latest` *with* a version declared; on `stable` there is no diff to compute and on a versionless `latest` there is nothing to bump. Two drafts of that battery asserted `2` from those dead ends and were wrong about the gate, not the other way round.

### And the check that keeps it that way

The batteries above are the fix. `gate-negative-proof.sh` is the other half this repository's closure rule always asks for: it fails when a gate carries no negative proof at all.

**And a second half to that half.** `gate-negative-proof.sh` asks whether proof EXISTS. It cannot see proof that is gone, and its own docstring is honest that counting files cannot judge a battery. Measured on 2026-09-01 against `9ccd3ab`: moving one negative fixture and its `.expected` sidecar out of the tree took `gate-findings-artifact.sh` from 30 artifacts to 29 and it signed **`VERDICT: 0`**. Every gate in the repository stayed green while a negative proof was retired, and nothing recorded that the case had ever existed. Weakening a fixture in place IS caught — gut the defect and leave the file and the gate says *"a fixture under bad/ validated cleanly, so it proves nothing"* — so the shape that survived is precisely **deletion**, the one edit that removes the evidence along with the thing it proved. `gate-negative-proof-census.sh` compares the count on disk against `scripts/gates/data/negative-proof-census.json`, in both directions: fewer means a proof was retired, more means the baseline went stale and stopped being one. The file sits under `scripts/gates/**`, so lowering the number is an edit G7 puts in front of a reviewer.

A gate proves itself in exactly one of two shapes, and the gate accepts only those two:

| | Shape | Gates using it |
|---|---|---|
| sibling | a non-empty `<gate>.selftest.sh` beside it, which the CI step discovers | 25 |
| inline | the gate READS `${GATE_SELFTEST:-1}` — the switch whose only effect is to cap its verdict at `2` when the self-test is skipped, so a gate that has not measured itself can never sign a green | 15 |

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
| Whole served tree (`skills` + `agents`) | 768 KiB, 64 files | - | Security threshold: bounds the blast radius of the knowledge loop. Re-baselined 2026-08; see the gate's own comment for why, and for why a delta guard is the better instrument. |
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

Proved in the negative by `gate-corpus-contract.selftest.sh`: 26 cases <!-- cases: scripts/gates/gate-corpus-contract.selftest.sh -->, each breaking exactly one thing on a throwaway copy, asserting the exit code **and** the reason, including a control case on the untouched repository and two cases that must exit `2`.

## The triage rules

Half the value of this corpus is knowing when **not** to report, and until now that half was unenforced: every procedure carried a `What rules it out (false positive)` field written as free prose, with nothing naming the rules, nothing requiring an answer and nothing able to check that a specialist had worked through them. The competitive analysis is blunt about the consequence — the two most rigorous neighbouring products enforce a finite named triage list through a schema, and distributed hygiene beats a single final reviewer only when the distributed part is checked.

`references/triage.md` declares ten rules, `FP-01`..`FP-10`, read out of the 370 exculpation bullets the corpus already contained rather than invented. Each is answered with exactly one of `HOLDS`, `DOES_NOT_HOLD`, `UNKNOWN` or `NOT_APPLICABLE`, and three invariants make the answers load-bearing:

1. A finding reported `confirmed` has every invoked rule answered, none `HOLDS` and none `UNKNOWN` — the same doctrine as exit code `2`, applied to findings.
2. `HOLDS` and `UNKNOWN` require a reason naming the artifact.
3. Absence of evidence is never `HOLDS`. `FP-08` exists because "the platform handles it" is the most common way a real finding disappears.

`gate-triage-rules.sh` enforces the rule set (contiguous ids, no stubs, the four answers declared), that every `FP-` id cited anywhere resolves, that `team.md` and `report.md` point at the rules and use the vocabulary, and **conformance per pack, ratcheted**: a pack marked `required` in `scripts/gates/data/triage-conformance.json` cites rules in every procedure, and a pack still being converted may never fall below the count it has reached. **All eight packs are converted and all eight are `required`: 154 of 154 procedures.** It took one editorial pass per pack, because citing the right rules for a procedure is a judgement and a bulk substitution would have been false rigour. Four procedures declare `Rules: none (reason)` — `AI-22` and three `VER-*` — because their class genuinely admits no exculpation, and the gate counts and prints those rather than letting them pass as citations. The ratchet half of that sentence was a promise rather than a measurement until 2026-09-10: the floor test hung off an `elif` at the same indent as `if policy.get("required"):`, so it was evaluated only for packs whose `required` is false — and all eight are required, so it had never once fired. Its battery was green throughout because `ratchet-turned-backwards` sets a pack to `required: false` to reach the floor at all, which is to say it tested the one branch in which the broken code still worked. `ratchet-also-binds-a-required-pack` is the case that would have caught it.

Proved in the negative by 17 cases <!-- cases: scripts/gates/gate-triage-rules.selftest.sh -->, including a control run and three that must exit `2`.

## The served-tree delta

`gate-plugin-integrity.sh` caps the absolute size of the tree copied into every user's plugin cache, and its own header named the weakness: an absolute cap loosens as the corpus grows legitimately, until the only way to satisfy it is to delete knowledge. `gate-tree-delta.sh` is the control that keeps its meaning — the growth of `skills/` and `agents/` between the merge base and `HEAD`:

| Branch | Budget | Why |
|---|---|---|
| `bot/*` | 16 KiB | the knowledge loop adds procedures, not chapters |
| everything else | 64 KiB | the largest legitimate change observed — the `local-app` pack plus its wiring — measured 44,545 B, so it still fits |

Deletions are never a failure: removing corpus is a decision a person makes, and this gate has no opinion on it. A shallow clone that cannot reach the merge base is exit `2`, which is why the `gates` job checks out with full history — an unmeasured delta is not a small one.

Proved in the negative by 7 cases <!-- cases: scripts/gates/gate-tree-delta.selftest.sh --> built on throwaway repositories, because a delta gate can only be exercised by making a delta.

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

**The negative fixtures carry their own reason.** Each file under `fixtures/findings/bad/` has an `.expected` sidecar naming the defect it stands for, and the gate fails if a fixture is rejected for an unrelated cause — a battery whose cases fail for the wrong reason proves that the validator runs, not that it catches anything. Ten negative fixtures, one conforming, and a self-test of 12 cases <!-- cases: scripts/gates/gate-findings-artifact.selftest.sh --> including four that must exit `2`.

## The evaluation bench

The competitive analysis has one row where every product in the field, including this one, is empty: **measured quality**. Five neighbours publish stars; none publishes a number for how much its tool actually finds. `bench/` is the machinery for filling that in, and `gate-bench-integrity.sh` is what stops it rotting into confident nonsense.

The bench holds small targets written to be read, and an answer key that names, for each: what was planted and which procedure should catch it, and which constructs were planted to **look** like findings with the triage rule that rules each one out. Ten planted defects, eleven decoys, across `web-api` and `local-app`.

**The rule that makes a run mean anything: the auditing context must never read `bench/ground-truth.json`.** An agent that has seen the key is transcribing, not detecting. The protocol in `bench/README.md` runs a fresh squad against `bench/cases/<name>` only, has it emit `findings.json`, validates the artifact, and only then scores it — in that order, because a malformed artifact scored anyway reports a low recall that is really a formatting bug.

`gate-bench-integrity.sh` checks that every case path exists, every planted and decoy entry points at a file and at a symbol that literally appears in it (with word boundaries, so `write_token` is not satisfied by the `write_token_privately` decoy beside it), every procedure id exists in the corpus, every `ruled_out_by` rule exists in `triage.md`, ids are unique, and **no case has planted defects without decoys** — a case with only defects measures the model's willingness to agree.

`scripts/bench/score.py` reports detected, missed, decoys reported (each a false positive with an id and the rule that should have caught it), and unlabelled findings, which are **not** counted against a run because the bench does not claim to be exhaustive. Thresholds are opt-in: without them the scorer measures and does not judge.

Both are proved in the negative: 23 cases <!-- cases: scripts/gates/gate-bench-integrity.selftest.sh --> for the gate, 6 <!-- cases: scripts/bench/score.selftest.sh --> for the scorer, including a near-miss case asserting that pointing at the decoy next door is not scored as a detection.

## The lane the comparison is drawn from

`competitive-freshness.sh` asks whether each measured pin is still its repository's tip. `competitive-discovery.sh` asks the prior question — whether the list is still the field — and exits `1` when a candidate is neither pinned nor declined. Both were answering honestly about products they could reach.

**Measured 2026-09-10.** The five text queries then declared in `docs/competitive-baseline.json` returned **39 distinct repositories, and none of them was `trailofbits/skills`** — 7,033 stars, a security firm's own Claude Code skills for vulnerability detection and audit workflows — **or `cloudflare/security-audit-skill`** — 3,267 stars, MIT, a multi-phase audit skill whose description states two of this repository's own axes. `gh search repos` ranks on name and description, so a product owned by an organisation and named `skills` is unreachable by every phrasing of this lane, at any star count. The previous run had exited `0` with the sentence *every candidate in the lane is named*. That sentence was true about the candidates it saw and false about the field, and nothing in the check could tell the difference.

Two repairs, and they only work together.

**A topic-qualified sweep.** `discovery.topic_queries` pairs a term with a GitHub topic — metadata the owner sets rather than prose a ranker reads. It orders by stars *inside one query's limit*, which is not a popularity bar creeping back in: every candidate it surfaces still has to carry a skill marker to count, a zero-star repository that carries one is a candidate exactly as before, and the text queries are not star-ordered, so the tail stays reachable. The sweep of 2026-09-10 surfaced 66 candidates and 18 unresolved names; all 18 are now pinned or declined in one line each.

**Known-positive controls.** `discovery.controls` names products the baseline has *already* resolved and that the sweep must therefore return. A control that comes back missing does not mean the product is gone — it means this instrument can no longer see a thing it is pointed at, and nothing it says about the rest of the lane survives that. The run prints `controls seen N of M` and exits `2`. Controls outrank an unresolved candidate: an unresolved name is a fact about the list, an unseen control is a fact about the instrument the list-fact came from, so the names are still printed and marked **provisional** while the verdict is `2`.

`gate-discovery-controls.sh` is what stops the repair from being emptied out later. Offline, from the baseline alone: at least one control exists; every control is already named in `products` or `declined` (an unresolved name is a candidate wearing a label, not a control); every control names a `found_by` that matches a declared query, so a red control says which query to repair; no control is this repository, which the sweep skips by design; no control is declared twice; and `max_candidates` is at least `sweeps × per_query`, because a run that stops at the cap never reaches its controls and a missing control then means nothing. Fifteen self-test cases, eleven of them mutants that must go red, and one that runs the gate against the **real** baseline — a rule nobody can satisfy is not a rule.

### Can anyone be sent to the procedure?

This corpus is reachable **only through prose**. A specialist opens the pack file its agent definition names, and opens a sibling only because the entry file's header says the sibling exists and says what is in it. Nothing scans `knowledge/` at runtime. That makes routing a load-bearing claim written in English, and English drifts silently.

It had. Measured 2026-09-10: six pack headers and two agent definitions still carried the ranges from before their pack was split, and **nine procedures** — `INF-19`..`INF-23`, `AI-23`, `SUP-26`, `LOC-11`..`LOC-14` among them — were defined, numbered, traced, counted, unique and unreachable. Every other gate was green and every one of them was right: the file was present, the identifiers were unique, the counts matched, the traceability row existed. None of them asks whether anyone is ever sent there.

`gate-pack-routing.sh` asks. For every pack with more than one file it reads both routers — the entry file's header and the agent's `First actions` — and compares what they name against the `### <ID>` headings the sibling files actually carry: a router that never names a sibling (`UNNAMED`), one that names it but not everything in it (`MISSING`), one that sends a reader for an id no file of the pack defines (`PHANTOM`), a router with no region to read or no file at all (`ROUTER`), a pack table naming a file that is gone (`TABLE`), and a pack whose entry cannot be identified (`SHAPE`).

The two halves are deliberately of different strength, and the asymmetry is the honest part. `MISSING` reads the whole line and is generous. `PHANTOM` reports only an id that **no** file of the pack defines, so it catches a range that outlived its last procedure but **not** two siblings whose ranges are swapped with each other. Attribution was tried twice while this was being written — first by reading the whole line for each file named on it, then by reading from a file's name to the end of the line — and **both accused a correct router**, because the corpus's own headers name two siblings in one sentence and put the range before the name as often as after it. An instrument that invents a defect is worse than one that misses it, so the guess was dropped rather than shipped. That limit is written into the gate's header and into `lib/pack_routing.py`.

Twelve self-test cases: ten mutants that must go red (a router that stops naming the file, either router keeping the pre-split range, a range running past the last procedure, a renamed `First actions`, a deleted agent file, a table row pointing at nothing) including two that must exit `2` rather than pass — no pack table, and a table that parses to zero rows — plus a baseline built in the two shapes the real corpus uses, and the real repository itself, which passes. The baseline is also a control against this instrument: its header names two siblings on one line with both ranges and ends with a sentence about neither, which is exactly what the two discarded versions got wrong.

Four controls are declared today, chosen so the set cannot pass for the wrong reason: `trailofbits/skills` (the case that motivated it), `cloudflare/security-audit-skill`, `anthropics/claude-code-security-review` (which carries no skill marker at all — a control asks whether the *search* can see, and the marker test is a later question), and `maxgfr/ultrasec`, which has zero stars and is the control that proves the bar is not popularity.

### An outside tool's raw output, crossed against the key by file and line

The bench had been scored against this project's own runs and against rivals judged on prose. It had never taken the **raw output of a third-party scanner** and crossed it against the answer key the way our own runs are crossed. `bench/external/<tool>-<date>/` now holds one such run: the tool's output byte for byte, a `provenance.json` naming the tool, its repository, the **40-hex commit it was pinned at**, the version string as the tool reports it, the exact command line, the repo-relative scan roots, the date, the runner OS and **what was not exercised**, and a `scorecard.json` with the numbers `scripts/bench/score.py` produced from it.

`scripts/bench/adapt-external.py` is the only new piece of plumbing: it converts SARIF, or the native shape of a recorded tool, into the findings artifact the existing scorer reads. No second scorer was written — matching by path and span was already `score.py`'s job. Two rules govern the adapter and both are enforced by its self-test and by the gate: an input whose format it does not recognise exits **2**, never 0-with-nothing-found; and a finding whose path it cannot place in this checkout is **named on stderr**, never dropped in silence.

`gate-external-crosscheck.sh` re-derives every recorded number from the committed raw output on each run, verifies each raw file against its recorded sha256, counts the raw records **itself, without the adapter** — so an adapter that starts dropping findings is caught even when the record was regenerated to agree with it — checks provenance is complete and its pin is a sha rather than a movable tag, refuses any absolute path of the machine that produced the run, and probes on every run that the adapter can still say *one* and still refuses to say *zero* blind.

**What it does not measure, stated because the number is worth less without it:** file-and-line agreement is **location** agreement, not semantic agreement. A foreign finding that lands inside a planted span counts as a hit whatever it says about the code, and one that describes the right defect at the wrong line counts as a miss. Nothing here judges the recorded number against a threshold either — the gate keeps it honest, a reader decides what it is worth, which is why the raw output is committed rather than summarised.

24 cases <!-- cases: scripts/gates/gate-external-crosscheck.selftest.sh --> prove it in the negative: a raw file edited without moving a score, a recorded number changed, the answer key moved under the record, a raw file added or deleted, a provenance field removed, a pin replaced by a tag, a date that disagrees with the directory it is in, a scan root that no longer exists, **a case directory renamed while its raw output stays put** - which the first version of this gate answered with a 2, publishing as an instrument failure a defect it had already measured - a machine path planted in an artifact, an adapter that guesses instead of refusing, an adapter that reads a one-result SARIF as zero, an adapter that drops a finding it cannot place **without naming it** - which moves no number at all and is caught only because the gate reads the adapter's text as well as its counts - an adapter that drops one finding per file — and the same drop **baked into the record as well**, which only the independent count catches. Five more assert the difference between a defect and an instrument that cannot run, and three are controls, one of them a false-positive control writing `/tmp/report.csv` and `~/.cache` as ordinary prose, because a machine-path rule that fires on a legitimate file gets switched off within a week.

## G5 — Licence hygiene (anti-verbatim)

The repository is MIT. Most sources it cites are not: OWASP is CC BY-SA, CIS is non-commercial with no-derivatives on the Controls, the semgrep ruleset is proprietary. Copying their text would contaminate the licence.

The gate enforces what is mechanically enforceable:

- No quoted span longer than 15 words attributed to an external source anywhere in `skills/**` or `docs/**`.
- No match against a maintained denylist of known phrases from copyleft and proprietary sources.
- `NOTICE.md` exists and lists every source family cited in the corpus.
- Any new source cited in the corpus appears in `docs/sources-allowlist.json` with its licence recorded.

**Honest limitation:** this cannot prove absence of plagiarism. It catches the obvious failure mode — pasting a checklist or a control description — and nothing more. The real control is upstream: the corpus is written from scratch and cites identifiers rather than text, and the pull request template requires that assertion explicitly.

**Implemented 2026-08-21** as `gate-licence-hygiene.sh`. Four measurements, and two of them found something the first time they ran: **OpenSSF** was absent from `NOTICE.md` while the corpus cited `SLSA Build L2`/`L3`, and `docs/coverage/mapa-microsoft.md` carried five verbatim quotations of Microsoft, AWS and Google terms-of-use text while `NOTICE.md` stated in the present tense that the repository contains no copied text. The first is fixed with an attribution section; the second is a real exception and is now declared as one — a `licence:quoted-terms` region for the case where the wording of a licence **is** the evidence for a licence determination, counted and printed on every run, with `NOTICE.md` narrowed to say exactly that.

**The denylist is stored as hashes, not phrases.** A list built to stop us copying somebody's words should not itself be a copy of them, so `scripts/gates/data/verbatim-denylist.json` holds SHA-256 prefixes of normalised windows, and `scripts/licence/add-verbatim-phrase.py` turns a phrase into entries without ever writing it down. The list is empty today and its size is printed on every run, because an empty denylist that passes silently is decoration.

**The width of that window is declared once, in the list.** It used to be written down three times — `ngram: 8` in the data file, `NGRAM = 8` in `lib/licence_hygiene.py`, `NGRAM = 8` in `add-verbatim-phrase.py` — and compared nowhere. That disagreement is the quiet kind: a hash built over a window of one width is invisible to a sweep looking for another, so the list still parses, the gate still prints its size, the run is still green, and every phrase on the list has silently stopped being forbidden. Both consumers now read the window from the list and **neither carries a default**, because a default is how one number comes to live in three places without anyone deciding to. A fifth measurement checks the half that can still drift: the producer's window is measured by **running** it over a 24-word probe and counting the windows it emits, not by reading its source. Declared 8; the producer was measured cutting 8. Both numbers are printed on every run, beside the list's size.

Proved in the negative by `gate-licence-hygiene.selftest.sh`: 13 cases <!-- cases: scripts/gates/gate-licence-hygiene.selftest.sh --> — a pasted attributed quotation, the same quotation inside the exempt region (which must stay green), an identifier owner nobody attributed, an allowlisted source with no licence recorded, a denylisted phrase present in the corpus, the declared window moving with the sweep following it, the producer cutting a window of its own, and four cases that must exit `2` — including `ngram` not declared at all and the producer missing from disk. The denylist case takes its window from the list, so the day the width legitimately moves it does not have to be re-typed, and the discriminating case derives its width as declared-minus-two rather than a literal, so it keeps discriminating whatever the repository declares.

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

It runs in the pull-request workflow rather than in the push suite, because a branch name and a diff against a base are things only a pull request has; `run-all.sh` defers it with a printed reason instead of running it against an empty diff and reporting a green that means nothing. Proved in the negative by `gate-protected-paths.selftest.sh`: 32 cases <!-- cases: scripts/gates/gate-protected-paths.selftest.sh --> — three automated branches touching three different protected patterns, an automated branch touching nothing, an unattributed change touching one, an agent trailer and a bot identity each caught on a branch named anything at all, a reserved prefix still failing with a perfectly clean commit range (the asymmetry, stated as a test), an unreadable range with and without a limit in the diff, the override letting a marked change through and failing to silence drift and being called out when it stands on nothing, the documented list and the enforced list drifting in each direction, seven on the fold — the real limit named in full above it, the count of what it folded, a finding and an override each still naming a folded path in full, the case where nothing *but* negative proof moved and the line says so rather than counting against zero, a `.expected` refusing to fold, and the declaration removed altogether so nothing folds — and three cases that must exit `2` (an unknown branch, a missing file list, an unusable data file). The commit range and the label are injected by the harness rather than read from git, because a battery that reads the same signal from the same place as the gate is testing nothing. The unknown-branch case earned its keep on the first CI run: `git rev-parse` inside a directory that is not a repository walks **up** and answers about an ancestor one, so on a runner the gate confidently reported the wrong branch where it should have reported that it could not tell. It now falls back to git only when the root it was given is itself the top level. And the battery itself was not hermetic: on a runner `GITHUB_HEAD_REF` is set, the gate reads it as a default, and the case meant to prove *I cannot tell whose branch this is* was quietly told. Every case now runs with those variables cleared — a battery that inherits the environment is not proving what it claims.

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
allowed to pass** (32 cases <!-- cases: scripts/gates/gate-protected-paths.selftest.sh --> in total, 0 failures). The other twenty-five were unchanged by the
work: with no diff there is no exemption, so every verdict written before exemptions existed still
holds.

## G7b — A bound may not move without the figure that moved it

G7 asks **who** moved a limit. It does not ask whether the number that moved still agrees with the sentence that states it — and on 2026-09-01, one of them did not.

Measured over the whole history: **15 budget constants moved, 13 of them tighter.** Exactly two loosened, and both were the same knob — `EHS_MAX_TREE_BYTES`, raised `524288 → 655360 → 786432`. The discipline around those raises is genuinely good; the third is written up in `gate-plugin-integrity.sh` with the figure that forced it (653,513 B served against a 655,360 B cap — **1,847 bytes of headroom**, less than a tenth of one procedure). This gate does not exist because the discipline is missing. It exists because **nothing enforced it**, and the practice already had one measured failure: the same file's environment table still read `default 524288` while `786432` was enforced — stale since the second of the three re-baselines, and the number a contributor gets from the usage block rather than the rationale. **One knob of eleven had drifted, and it was the only one that had ever been raised.** The fix that raises a number makes the note that states it false, and no test saw that.

`scripts/gates/data/budget-ledger.json` is the single home. Six checks:

1. **classification** — every `${EHS_*:-<number>}` any gate reads is named in the ledger, as a `budget` or explicitly as `not_a_budget`. A knob nobody classified **fails**: a ledger listing only what someone remembered cannot see what nothing points at, and 3 of the 11 knobs really are mode switches, which is a decision someone writes down rather than a gap.
2. **agreement** — the ledger's `value` equals the value the source enforces, in both directions, so raising a budget is an edit to a file under `scripts/gates/**` that G7 puts in front of a reviewer, with the justification on the next line. A declaration that outlives its knob fails too.
3. **no drift** — every comment stating `default <N>` for that knob names the same number. This is the check that was already red.
4. **justification** — every `budget` carries a non-empty `why` and `measured`.
5. **the address** — every `${EHS_*:-<number>}` is resolved back to the file that reads it and compared to the ledger's `enforced_in`. That column is what a reader consults to find the control behind a number, and until 2026-09-10 the only place the string appeared outside the JSON was inside a mutation in this gate's own self-test: nothing compared it to the source. So the declaration could name any file at all — repointing `EHS_MAX_TREE_BYTES` at `gate-tree-delta.sh`, a real gate that really does not read that knob, left the gate at `0`, and a reader following that address opens a file with no such bound in it. Check 2 proves the **number** agrees; this proves the **address** does. The comparison is JSON against source, never JSON against itself. The frame of reference — how the ledger spells the gates directory — is derived from `--gates-dir` and the repository root; an absolute or empty one is reported as could-not-measure rather than guessed, because a prefix this gate invented would either pass everything or fail everything. All 11 addresses resolve today. The derivation reduces **both** paths to one spelling before stripping, and that is not decoration: the root arrives the way git spells it, symlinks resolved, and the gates directory the way bash spells it, which keeps the logical path. Where the two differ — anything under `$TMPDIR` on macOS, and therefore every point of a `scripts/gh/merge-preview.sh --chain` run — a bare prefix strip matched nothing, the address stayed absolute, and this check reported 2 for the whole gate. It was reporting where the checkout happened to live as a verdict about the repository.
6. **the bite** — every `budget` is moved to its extremes and the gate its `enforced_in` names is re-run. Checks 1-5 all pass for a gate that reads `${EHS_*:-<number>}` into a variable and never compares anything with it: the ledger would agree with the source, the source would agree with its comments, the `why` would be eloquent, the address would resolve, and the bound would decide nothing. The bound is moved to `0`, then `999999999`, then `-1`, stopping at the first point that moves the verdict; `-1` is there because it was measured to be necessary, not for symmetry. Three verdicts, never two: **bites** (an extreme moved the verdict), **does NOT bite** (every extreme measured, none moved it, and the entry declares the `probe_env` that opens the path the knob guards) → `1`, and **NOT MEASURED** → `2` whenever the gate could not answer or nothing moved and no `probe_env` is declared, because a decorative bound and a comparison this run never reaches cannot be told apart. Never `0`: an unprobed bound is not a proved one. This is the only check that runs another gate, so it carries a recursion guard and a timeout, and it is out of scope for the three `not_a_budget` knobs, which are mode switches rather than bounds.

**What it does not measure, and does not pretend to.** Whether a `measured` claim is *true*: a gate cannot re-run the reasoning that justified a number, and one that implied it could would be worse than this one. Nor the **direction** of a change — it has no history at gate time, so it does not claim to tell a raise from a tightening. Nor whether a bound that bites bites at the **right** number: check 6 proves the bound reaches a live comparison, and the figure itself is argued for in `measured`, which no gate can re-run. All three are printed on every run.

Proved in the negative by its inline self-test, 25 cases <!-- cases: scripts/gates/gate-budget-ledger.sh -->: the repository as it stands, the enforced value raised behind the ledger and the ledger lowered behind the code, the stated default disagreeing with the code (the defect this shipped with, reproduced), a new knob nobody classified, a declaration that outlived its knob, a budget with an empty `measured`, a budget relabelled `not_a_budget` still having its value checked, an address pointed at a different gate, one knob's address emptied, the same knob read in two gates, a bound moved to its extremes against a live floor and against a comparison sitting behind a declared context (both of which must stay green), the same bound with its comparison neutralised so that no value bites, and six that must exit `2` — a missing ledger, an unparseable one, nobody declaring where any bound is enforced, two with no frame of reference, and a bound whose comparison check 6 could not reach at all, which it refuses to call dead. The frame-of-reference pair exists because `run_case` always supplies a good frame, so the branch where the gate refuses to work without one is a branch `run_case` can never reach; it is driven separately. Five further cases measure the **derivation** of that frame rather than the branch that refuses a bad one, which nothing did until the address came back absolute in every worktree under a symlink: one directory spelled two ways with the gates directory reached through a link, the same with the root reached through a link, both spelled alike as the control that says the fix did not move the ordinary case, and a call with no root at all, which must come back exactly as it was handed in — `cd ""` returns 0 in bash, so without that guard the current directory quietly becomes the frame of reference. The symlink is built by the case rather than assumed from `$TMPDIR`, because on a Linux runner `$TMPDIR` is `/tmp` with nothing linked and a case that only bites on one operating system defends nothing on the other. The fifth runs this script through a symlinked root and reads whether check 5 got an address it could use: the other four call the derivation directly, so putting the old expansion back at the **call site** leaves all four green, and that case is the only one that goes red. The `enforced_in` mutations are `0 → 1` and `0 → 2` respectively, and the second is `2` rather than `1` on purpose: a ledger that stopped declaring where anything is enforced is a check that read nothing, and reading nothing is not finding nothing wrong. The self-test found one bug in the gate itself before it shipped: the scanner read a knob literal out of the gate's own mutation string, so the mutation is now assembled from parts.

## The measurement that dies mute exactly when there is something to measure

GitHub Actions runs every `run:` block under `bash --noprofile --norc -eo pipefail {0}`. So this,
which reads like careful code, is not:

```bash
bash scripts/run-batteries.sh --jobs 1 > one.out 2>&1; r1=$?
```

Under `-e` the command tears the step down the moment it returns non-zero. The capture never
executes, the comparison it was feeding never happens, and the step ends **with no error title**:
a reader of the run sees a job that stopped, not a measurement that failed. `set -e` does not care
that you were about to read `$?` — reading it is not a suppressor.

**Measured 2026-09-10 on branch `measure/battery-workers`.** `.github/workflows/battery-workers-ab.yml`
carried six of these. The arm whose entire job was to catch a disagreement between a serial and a
parallel run of the same suite died at ~295 s — exactly one serial pass — having caught nothing,
and the run reported no error. The timing arm, which could not fail this way, worked fine and
published its medians. One half of the experiment was silently missing and the other half looked
healthy.

This is the most expensive class of defect this repository can carry, because it is the instrument
going quiet in precisely the case it exists for. Two forms survive `-e`, and only two:

| Form | Why it survives |
|---|---|
| `cmd \|\| rc=$?` | `\|\|` suppresses errexit for that command |
| `set +e` … `cmd`; `rc=$?` … `set -e` | errexit is explicitly off for that stretch |

`gate-errexit-rc-capture.sh` reads every `run:` block under `.github/workflows/**`, tracks whether
errexit is on at each point — `set +e`/`set -e`, and a `shell:` template that drops `-e` — and
fails on a capture of `$?` that nothing suppressed. It recognises the two safe forms **as safe**
rather than merely not-flagging them, so the output says how many captures it examined, not just
how many it disliked. `release.yml:321` is the repository's live instance of the bracketed form and
the gate reports it as such.

**Scope, stated so it is not mistaken for a hole.** Shell scripts outside the workflows run under
`set -uo pipefail` *without* `-e`, where `cmd; rc=$?` is correct and idiomatic; a gate that flagged
them would be accusing the files that comply. Whether a correctly captured code is then read by
anything is a different defect and not this gate's. A workflow that sets `defaults.run.shell` for a
whole job is declared **unmeasurable** rather than measured against a shell nobody read.

**The control that runs every time.** Before the gate says anything about the tree, the checker
runs its detector over five strings embedded in its own source — two that must come out red, three
that must come out clean. A sweep reporting zero because it has gone blind is indistinguishable
from a clean tree, and this repository has already paid for that once, in the competitor sweep. If
a control case disagrees the verdict is `2` and no claim is made. On top of that, `run-all.sh`
parsing a workflow directory and finding not one `run:` block is reported as the extractor being
blind, never as the tree being clean.

**Reachability, both directions, measured 2026-09-10.** Over `origin/main`: 8 files, 33 `run:`
blocks, 11 captures — 10 written `|| rc=$?`, one bracketed by `set +e` — `VERDICT 0`. Over the
workflows of `origin/measure/battery-workers`, materialised read-only out of the object store:
`VERDICT 1`, naming `battery-workers-ab.yml` lines 143, 144, 145, 227, 229 and 231. The battery
adds eight mutants of the detector, each of which must make one of its fixture cases go red; a mutant
that survives fails the battery, because a bank whose cases cannot catch a sabotage is not a bank.

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

Self-test: 16 cases <!-- cases: scripts/gates/gate-alert-surface.sh -->, each proved in the negative against a synthetic tree, plus one that runs the
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

**Which two files those are comes from the contract, not from the gate.** `skill_md` and
`report_md` had been in the data file since the gate was written while the caller passed both
paths as literals: two independent statements of one fact, compared by nothing. The keys read
as the contract and were decoration — repointing `skill_md` at `references/report.md`, a file
that is really there and is really not `SKILL.md`, left the gate at `0`, and deleting
`report_md` outright left it at `0` too. The fix removes the literal rather than adding a
comparison, and there is deliberately **no fallback**: a default would put the truth back in
two places, which is the defect being removed. Missing or off-disk is `2`, not `1`. The
self-test seeds a small tree laid out the way the real repository is, so all twenty-one cases
exercise the resolution rather than one new case covering it — and the layout is spelled out
in the harness on purpose, because a seed that read the path back out of the data file would
follow every mutation of it and catch none. If `SKILL.md` legitimately moves, the harness is
the second place that has to say so, and it failing is the conversation.

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

## G7e — The search that reports an absence it never looked at

`references/tooling.md:19` already says it: `rg` honours `.gitignore` and `.ignore` and
skips hidden files, `fd` does the same, and so a search that comes back empty has
searched a **filtered** view of the tree — "a false-negative source, not a
false-positive one, so nothing in the output warns you". Nothing read that rule back
against the procedures obliged to obey it.

Measured on 2026-09-10 against `origin/main @ 6066048`: **90** `rg`/`fd` invocations
across the knowledge corpus, **4** of them carrying any completeness flag, and
`grep -rlE 'no-ignore|--hidden|-uu' scripts/gates/` empty — not one of the gates was
watching. Seven procedures sent the auditor at a path the defaults hide with no
invocation able to reach it: `AI-25` at `.claude-plugin`, `AI-28` at `.cursor`, `AI-30`
and `INF-08` at `.env`, `LOC-07` at the dotfile layer it discovers by walking up,
`AI-22` at `.cursor/rules/**` with `-H` but without `-I`, and `SUP-23` at readers that
live in `vendor/`. Each returns zero findings on a tree where the file exists, and zero
findings is exactly what a clean audit looks like.

**The unit of judgement is the PROCEDURE, not the command.** One that sweeps source with
the defaults and then points a second, explicit invocation at the dotted file is
correct, and a per-command rule accused three of those (`INF-08`, `INF-20`, `INF-24`)
before it was calibrated. Two other accusations were withdrawn under measurement rather
than kept to round a number up: `LOC-01`'s only hidden token is
`../../.ssh/authorized_keys` inside a **archive entry name** — the attacker's payload,
not a path in the audited tree — and `AI-20`'s `.git` appears inside `-g '!.git'`, an
exclusion, because excluding a path is not visiting it.

Two properties the battery had to learn the hard way, and they are written into it:

- **The mutant runs against the COPY of the gate, not the installed one.** `core-crashes`
  survived its first draft because the gate resolves its core from `$HERE`: mutating
  `scripts/gates/lib/` in the working tree hit a file nobody executed. The battery now
  invokes `"$work/scripts/gates/gate-tooling-blindspot.sh"`. The neighbouring batteries
  do not have this problem because they only mutate data.
- **Red with no finding is a crash, not a failure.** The gate turns an `rc=1` carrying
  zero `FINDING` lines into a `2`.

`corrected-procedure-regressed` and `premise-no-longer-declared` assert their target
exists before mutating it, so a mutant whose subject was deleted says it no longer bites
instead of going quiet and reading as coverage.

**What it does not measure:** that `rg` and `fd` behave as their documentation says.
Neither is installed on the machine that wrote this, so the claim that those defaults are
blind comes from the tools' own documentation, not from an execution here. The gate says
so in its own header rather than letting the omission pass for a measurement.

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

It does not run in the offline suite, because its input needs the network and a repository token; `run-all.sh` names it in the deferred list with the workflow that does run it, since a gate that is quietly absent is indistinguishable from a gate that passed. Proved in the negative by `gate-scorecard-threshold.selftest.sh`: 16 cases <!-- cases: scripts/gates/gate-scorecard-threshold.selftest.sh -->, including a check below its minimum, a check absent from the results, a check that came back inconclusive, an aggregate falling just within the contract and one falling past it.

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

`*.selftest.sh` is excluded **from the gate comparison**. A self-test battery is not a gate and the runner does not list it as one, so the sentence above naming `gate-corpus-contract.selftest.sh` is correct prose. Counting it as a gate made this gate report a phantom on its first run against the repository, and the fixture `good/2-a-selftest-is-not-a-gate` is that mistake, kept.

It does, since 2026-09-10, check those batteries in **one** direction: a `*.selftest.sh` this document names as the negative proof behind a control has to be one `scripts/run-batteries.sh --list` discovers. A battery that is renamed or deleted otherwise leaves the sentence about it standing, and that sentence is what a reader trusts when they ask whether a claim was ever proved in the negative. The reverse is deliberately not required: the runner discovers several times as many batteries as this document names, so demanding that every battery appear here would be a rule with more reach than it is owed — it would go red on a repository that is behaving. Both counts are printed on every run rather than written down here, because a number in prose is the thing this section is about. A runner that does not answer, or a repository with no batteries at all, is `2`. Measured 2026-09-11: 33 discovered, 5 named, 5 found.

**The case counts this document quotes beside a battery are measured, since `gate-case-counts.sh` landed on this branch.** A figure carrying a `cases:` marker — an HTML comment naming the battery, written in this sentence without its angle brackets so that the sentence is not itself read as a marker with no figure to measure — is compared against what that battery prints when the gate runs it; a figure carrying none is counted against a ceiling declared in `scripts/gates/data/case-counts.json`, so a figure nobody measures cannot be added in silence. The ones still quoted without a marker here name gates whose self-test is inline and prints no total to read, and that file enumerates them one by one rather than leaving them to be found.

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

## G10 — A path that names one machine

A public repository publishes measurements so a stranger can re-run them. An absolute path that
exists on exactly one laptop publishes the opposite: a number nobody else can reproduce, and — when
the path is a home directory or a per-user temporary root — an operating-system account name, a
numeric uid and a session identifier, handed to everyone who clones an MIT repository.

Measured on 2026-09-11 over `origin/main` at `6066048`, sweeping every file `git ls-files` names:

The shapes are quoted below exactly as they appear in `scripts/gates/data/machine-identity.json`,
which is the only place they are defined. Four of the five do not match their own source text — the
character after the prefix is a bracket or a parenthesis, not a path — so this table can name them
without becoming a finding. The fifth, `/var/folders`, matches itself literally and is therefore
written here **without its trailing slash**, which the pattern requires. This document is not exempt
from the gate it specifies, and that is deliberate: the one file that is exempt is the data file,
by name.

| pattern | occurrences | where they are |
|---|---|---|
| `/private/(?:tmp\|var)/` | 617 | 203 files, nearly all recorded agent transcripts under `bench/runs/**` quoting one session scratchpad whose path carries a uid and two session UUIDs |
| `/Users/[A-Za-z0-9._-]+` | 7 | five prose files under `docs/coverage/**` saying where a read-only pass was run |
| `/var/folders` + `/` | 5 | the reference-frame note in `gate-negative-evidence.sh` and its battery, which are *about* the `/var` → `/private/var` divergence |
| `/home/[A-Za-z0-9._-]+` | 1 | `gate-bench-blinding.selftest.sh`, an invented lab account planted as a payload so the blinding check can be seen rejecting it |
| `[A-Za-z]:\\?Users\\?` | 0 | the Windows shape; nothing in this tree carries it, and the rule is forward-looking |

Three of those four rows are not defects, and that is the whole difficulty. Prose explaining the
mechanism has to *contain* the shape to explain it; a fixture that plants a machine path as payload
has to plant a machine path. A rule that hunted the shape and nothing else would convict the two
files in this repository that exist to defend against it. The requirement is therefore **not** "no
machine paths": it is that the number is **known, frozen per file, and only allowed to fall**.

**The requirement.**

1. **One definition.** The shapes live in `scripts/gates/data/machine-identity.json` and nowhere
   else. `scripts/gates/lib/external_crosscheck.py` already spells the same five shapes for its own
   purpose, on an open branch; the gate reconciles the two lists and fails when they disagree,
   because two spellings of one rule is two answers to one question. Where that file is not present
   the gate prints `n/a` and says so on screen — an absent consumer is not an agreeing one.
2. **A ratchet with a per-file ceiling.** A file absent from the inventory may carry none. A file in
   it may not exceed its own figure, so a deletion in one file cannot pay for an addition in
   another. An entry the tree no longer needs also fails: a paid debt left in the ledger is a
   ceiling nobody is under, and the next addition would hide beneath it. `--update` may only turn
   the ratchet **down** and refuses, with exit `2`, to write an entry that grows.
3. **Forward declarations, verified.** A file that legitimately carries a shape and lives on an open
   branch is declared in `expected_on_merge` with the branch it comes from and the reason, and the
   gate checks the branch actually has it. A checkout without that ref reports the declaration as
   **unverified**, never as passed — a shallow CI checkout is precisely where a false declaration
   would hide.
4. **Exemption by name, never by glob.** Exactly one path is exempt, the data file itself, which
   necessarily quotes the shapes it defines. The same bytes in a file next door go red.
5. **Unread is not clean.** A file that cannot be decoded is counted and reported as unread. A gate
   that silently treats what it could not read as fine is a gate that gets quieter as the tree gets
   worse.

**What it does not measure.** It does not judge whether a path is real, only whether it has the
shape of one machine; it does not remove the 623 occurrences already frozen, it stops them growing;
and it says nothing about paths that leak identity in some other form — an email address, a hostname
— which are other gates' business.

Implemented by `gate-machine-identity.sh` with `scripts/gates/lib/machine_identity.py`, proved in
the negative by a 25-case battery whose case 18 runs the gate against **this repository** rather
than a fixture, and by a mutation bank of ten mutants over the engine, each weakening exactly one
check at the real site: **10 killed, 0 survivors**, the engine restored byte-for-byte after each.
The tenth is the reason case 17 asserts a count and not a sentence — its first version grepped for
the words *"binary or undecodable and not read"*, which the gate prints on every run whatever the
number is, and it passed identically with the binary branch of the engine deleted.

## Branch naming

- `main` — channel `latest`. No direct pushes.
- `stable` — weekly promoted channel. No direct pushes.
- `feat/*`, `fix/*`, `docs/*` — human work.
- `bot/knowledge-YYYY-WW` — the knowledge loop. Stricter rules, per G7 and G4.

## A control declared to run somewhere else must have a somewhere else

This repository is careful about the difference between a control that is silenced and one that
runs on another path. `run-all.sh` prints `NOT RUN HERE (declared, not silenced)` with the name and
the reason; `ci.yml` takes `gate-actions-lint.sh` out of the `gates` job with `--skip` because the
`workflow-hardening` job runs it with `--only`. Both are the right design, and both rested on a
fact nothing in this repository measured: **that the other path exists**.

Measured on `origin/main` before `gate-deferral-lane.sh`: four controls are declared not to run
here, three of them are named by a workflow, and the `--skip`/`--only` pair in `ci.yml` is kept
honest by nothing except nobody having edited either line. Delete the second job, rename the gate,
or narrow the glob, and every runner goes on printing "declared, not silenced" about a lane that
runs nothing. A deferred control with no lane is not deferred, it is gone — and it is gone with an
alibi, which is worse than gone, because the output still reads like coverage.

The gate asks three questions, over the tree, with no git and no network:

1. **Declared, therefore run somewhere.** Every control this repository declares it is not running
   here — the `*_SCOPED` lists in `scripts/gates/run-all.sh`, every name in
   `scripts/gates/data/slow-scoped.txt` when that file exists, and every control a workflow removes
   with `--skip` — must be named by some **other** non-comment line under `.github/workflows/**`, or
   matched there by an `--only` glob. A `--skip` is never a lane: two workflows skipping the same
   control is not one workflow running it.
2. **The pattern resolves, and so does the path.** Every `--only` and `--skip` glob must match at
   least one control that exists; and every workflow line that invokes a control by path —
   `run: ./scripts/gates/gate-x.sh` — must name a file that is in the tree. A glob that matches
   nothing is a lane that runs nothing, and it reads exactly like one that works. The second half
   of this rule was missing until a run over the **real** tree went looking for it: rename a
   control and the job that calls it by path still *names* it, so question 1 is satisfied by a
   lane that cannot execute. The bank had eighteen cases on throwaway trees and every one of them
   passed; it took three edits a person could make on an ordinary day, applied to the delivered
   tree, to find the hole.
3. **The exemptions are honest.** A control whose lane is deliberately outside CI is named in
   `scripts/gates/data/deferred-lanes.json` with a written reason, and printed by name on every
   run. Today that is one entry: `gate-governance-drift.sh`, whose lane needs the `administration`
   scope that no workflow token can be granted. The list is checked in the other direction too — an
   entry for a control that no longer exists, that nothing defers any more, or that has since
   acquired a real lane is a failure, because an exemption nobody can be caught by is how a hole
   becomes permanent.

A lane is recognised **by name**, and the limit is stated rather than left for a reader to discover:
a job that re-runs a deferred control without naming it — `run-all.sh --pr-context` with no
`--only`, say — is a real lane this gate will not credit. That error accuses a lane that exists
instead of passing one that does not, which is the direction a control is allowed to be wrong in,
and the fix is one word in the step or one entry in the JSON.

Proved in the negative by 19 cases <!-- cases: scripts/gates/gate-deferral-lane.selftest.sh --> on throwaway trees — a gate about declarations can only be
exercised by writing declarations — of which 12 must come back `1` (a lane deleted, a lane that is
only a comment, a `--skip` standing in for a lane, a glob that resolves to nothing, a lane that
invokes a path that is gone, an exemption with no reason, an exemption nothing defers, an exemption
that has acquired a lane) and 6 must come back `2` rather than pass (a declaration shape the gate
does not recognise, no workflows at all, a data file that will not parse or has the wrong shape, a
runner that is gone, a declaration file that is there and cannot be read). The bank was then
checked against a weakened instrument: seven mutations of the gate's own engine — crediting a
`--skip` as a lane, reading comment lines as live, dropping the backwards check on exemptions,
treating an unrecognised declaration shape as "nothing deferred", ignoring a glob that resolves to
nothing, never reading `slow-scoped.txt`, crediting a path lane without resolving the path — were
each killed by the case that owns that rule, `7/7`.

And the bank was checked a second way, because a bank of throwaway trees only proves the gate can
go red on trees the bank itself wrote. Five edits over the **delivered** tree: one of two lanes
deleted (stays `0` — the other lane still runs it), both deleted (`1`), a named control renamed
(`1`, and this is the case that found the missing rule), and the exempted control deleted (`1`).
