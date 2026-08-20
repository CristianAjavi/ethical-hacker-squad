# Gate requirements

The specification the CI gates implement. This file states **what must be true**; the executable checks live under `scripts/gates/` and the workflows under `.github/workflows/`.

Written as a contract on purpose: the corpus and the machinery that guards it are maintained separately, and this is the interface between them. If a gate and this document disagree, the disagreement is itself a bug — fix both in the same pull request.

> **Status.** Partially implemented. `G1`, `G2`, `G3`/`G3b` and `G4` run in CI on every push and pull request (`.github/workflows/gates.yml`), and each is proved in the negative by the mutant bank in `tests/gate_mutants.py`. `G5` to `G9` are still specification, and there is still no `stable` branch and no tagged release. The table below marks which is which; anything marked *specified* describes a control that is **not** running yet. See `docs/design-decisions.md`.

## What runs today

| Gate | Status | Implementation |
|---|---|---|
| `G1` manifest and structure | running | `scripts/gates/g1_manifest.py` |
| `G2` internal links | running | `scripts/gates/g2_links.py` |
| `G3` context budget · `G3b` declared counts | running | `scripts/gates/g3_budget.py` |
| `G4` citation, anatomy and sourced claims | running | `scripts/gates/g4_citations.py` |
| `G5` licence hygiene | specified | — |
| `G6` secret scanning | specified | — |
| `G7` protected paths | specified | — |
| `G8` regression guard | specified | — |
| `G9` repository quality metric | specified | — |

Run them locally with `python3 scripts/gates/run_all.py`, and the negative proofs with `python3 tests/gate_mutants.py`. Both need only a Python 3 interpreter; a gate that needed an install would be a gate nobody runs before pushing.

## Exit-code semantics — applies to every gate

Three outcomes, three exit codes. A gate that cannot tell "I measured and it is fine" from "I could not measure" is worse than no gate, because a tool that fails to run looks identical to a clean result.

| Exit code | Meaning | CI behaviour |
|---|---|---|
| `0` | Measured, within threshold | pass |
| `1` | Measured, outside threshold | fail with the offending items listed |
| `2` | Could not measure (tool missing, network unavailable, file unreadable, parse error) | fail, reported as **unmeasured**, never as pass |

Every gate must be **proved in the negative**: a case that makes it exit `1`, and a condition that makes it exit `2`, both exercised in CI. A gate never observed failing is a gate nobody knows works. `tests/gate_mutants.py` is where that proof lives: it copies the repository, breaks exactly one thing, and asserts the gate notices — 25 mutants across the four running gates, plus a baseline asserting the untouched repository passes.

**Which of `1` and `2` applies to a parse error depends on the gate.** A gate that *asserts* a file parses reports a syntax error as its finding: `G1` exists to say `plugin.json` is valid JSON, so a broken manifest is exit `1`. Every other gate that opens the same file to reach some other property exits `2`, because it never got to measure the thing it was asked about. The distinction is made at the call site, in `lib.Gate.read_json`.

## G1 — Manifest and structure

- `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` parse as JSON, and `docs/sources-allowlist.json` parses as JSON.
- `plugin.json` contains a `name`.
- **`plugin.json` on `main` must NOT contain a `version` field.** Its presence is the defect that silently blocks updates for existing installs; see `docs/release-channels.md`. On `stable`, the semver lives in the marketplace entry, and it must not appear in both files.
- `skills/ethical-hacker-squad/SKILL.md` opens with YAML frontmatter delimited by `---`, containing `name` and `description`, with `name` matching the directory name.
- Every file under `agents/` has YAML frontmatter with `name` and `description`, `name` matches the filename, and every `tools` entry is a real tool name.
- Auditor agents (`ehs-web-api`, `ehs-mobile`, `ehs-infra-cloud`, `ehs-supply-chain`, `ehs-ai-safety`, `ehs-privacy-abuse`, `ehs-verifier`) must **not** list `Edit`, `Write` or `NotebookEdit`. Only `ehs-remediator` may.

## G2 — Internal links resolve

Every relative Markdown link, and every path interpolated from the plugin-root variable, referenced in `SKILL.md`, `references/**` and `agents/**` points at a file that exists. Checked mechanically, not by eye. A broken reference in a progressive-disclosure skill is a silent capability loss: the model simply never reads the file.

## G3 — Context budget

Progressive disclosure only works if the entry point stays small.

| Item | Limit | Rationale |
|---|---|---|
| `SKILL.md` | 500 lines | Official guidance for skill entry points; it stays in context for the whole session. |
| Any single file under `references/` | 600 lines | Above this a specialist cannot load selectively. |
| Total corpus under `references/knowledge/` | 3,500 lines | Loading everything must remain obviously wrong. |
| Any single `agents/*.md` | 120 lines | An agent definition is a contract, not a manual. |

Exceeding a limit fails with the file and its line count.

### G3b — Declared counts match reality

The corpus line count and procedure count are stated in `SKILL.md`, `references/knowledge/README.md`, `README.md` and `CHANGELOG.md`. Nothing currently stops the first added procedure from making all four wrong at once.

Count procedures by matching the procedure heading pattern across `references/knowledge/*.md`, count corpus lines, and fail if either disagrees with any declared figure. Prose that repeats a number needs a check watching it, or it becomes a lie on the next commit.

Four numbers are watched, not one:

- **Corpus lines and procedure count**, compared exactly against every declaration in `README.md`, `CHANGELOG.md`, `SKILL.md` and `references/knowledge/README.md`.
- **Declared identifier ranges** (`` `AI-01`..`AI-22` ``): the upper bound must be the highest identifier that actually exists. A range that overstates the corpus promises procedures a reader will look for and not find.
- **Identifier contiguity**: each family runs from `01` with no gaps and no duplicates. `WEB-07` is referenced from `traceability.md`, from findings and from issues, so a hole means a reference points at nothing.
- **Per-pack cost estimates**, both the `**Cost:** ~N lines` header in each pack and the `Lines` column of the corpus README table, within **10 lines** of the real count. The estimate is what a specialist budgets context against; `~` allows for rounding, not for drift. This tolerance caught `infra-cloud.md` declaring `~370` when it was `387`.

## G4 — Every knowledge item is cited and usable

Three checks, one script. This is what keeps the corpus falsifiable: an uncited claim cannot be checked, and cannot be corrected when it goes stale.

**`G4a` — cited, and cited with real identifiers.** Every procedure carries a `Traceability` line naming at least one identifier, **and every identifier it names matches a known family** listed in `scripts/gates/data/identifier-families.json`. The second half is the one that earns its keep: a fabricated `OWASP-MOBILE-TOP-99` sitting between four real IDs is exactly the error that survives human review, because it looks correct. Adding a standard means adding its family there, to `docs/sources-allowlist.json` and to `NOTICE.md` — three deliberate steps, on purpose.

A procedure with no external identifier may declare that explicitly (`internal process`, `no external identifier`, `the one from the original finding`). Those are counted and printed on every run rather than silently accepted, so the escape hatch stays visible. Five procedures in `remediation.md` use it today.

**`G4b` — the six fields exist.** Every procedure carries `Where to look`, `Vulnerable pattern`, `What rules it out (false positive)`, `Minimal test`, `Traceability` and `Tooling`. The third is the one that matters most: a procedure without false-positive criteria manufactures this repository's first-class defect.

**`G4c` — quantitative claims name a source.** A prose line stating a percentage must carry a citation marker inside its own paragraph.

**Honest limits.** A family match proves an identifier is well-formed, never that the standard says what the procedure claims. Fenced blocks are not scanned by `G4c`, so a figure appearing only inside an illustrative example is not measured. And a citation marker proves a source is named, not that it supports the sentence. All three are jobs for a reviewer; the gate removes the mechanical failures so the reviewer can spend attention on the rest.

An item the loop adds or modifies additionally carries a source URL from the allowlist and a consultation date. **Not yet implemented** — the loop does not run.

## G5 — Licence hygiene (anti-verbatim)

The repository is MIT. Most sources it cites are not: OWASP is CC BY-SA, CIS is non-commercial with no-derivatives on the Controls, the semgrep ruleset is proprietary. Copying their text would contaminate the licence.

The gate enforces what is mechanically enforceable:

- No quoted span longer than 15 words attributed to an external source anywhere in `skills/**` or `docs/**`.
- No match against a maintained denylist of known phrases from copyleft and proprietary sources.
- `NOTICE.md` exists and lists every source family cited in the corpus.
- Any new source cited in the corpus appears in `docs/sources-allowlist.json` with its licence recorded.

**Honest limitation:** this cannot prove absence of plagiarism. It catches the obvious failure mode — pasting a checklist or a control description — and nothing more. The real control is upstream: the corpus is written from scratch and cites identifiers rather than text, and the pull request template requires that assertion explicitly.

## G6 — Secret scanning

No credential in the working tree or in history. Detection uses distinctive-format patterns before entropy, since entropy alone is a poor primary detector and format patterns reach far higher precision. Exit `2` if the scanner is unavailable — an absent scanner is not a clean repository.

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

## Label taxonomy

Labels are English, matching the repository language. Anyone wiring automation should use exactly these strings.

**Type — the two first-class types are audit-quality errors, not crashes:**

| Label | Meaning |
|---|---|
| `false-positive` | The squad reported something that is not exploitable. |
| `false-negative` | The squad missed a real finding. |
| `knowledge-gap` | A surface, stack or class with no procedure covering it. |
| `licensing` | A licence, attribution or `NOTICE` problem. |
| `tooling` | A tool invocation, output interpretation or availability problem. |
| `bug` | The skill, plugin or automation malfunctions mechanically. |
| `docs` | Documentation only. |

**Area — one per role:** `area/web-api`, `area/mobile`, `area/infra-cloud`, `area/supply-chain`, `area/ai-safety`, `area/privacy-abuse`, `area/remediation`, `area/lead`, `area/plugin`, `area/ci`.

**Severity:** `severity/critical`, `severity/high`, `severity/medium`, `severity/low`, `severity/info`.

**Origin:** `origin/loop` (opened by automation) and `origin/human`. Provenance, not decoration — it decides which review rules apply.

**Status:** `status/needs-repro`, `status/needs-gate`, `status/blocked`, `good-first-issue`, `help-wanted`.

Applying labels to externally submitted issues must be **deterministic**, derived from the structured fields of the issue form. It must never come from a model's reading of free prose: that would be a language model taking a write action based on untrusted text, which is the exact chain this repository is built to avoid. If a routing decision cannot be made from the form's fields, the correct fix is to add a field to the form.

## Branch naming

- `main` — channel `latest`. No direct pushes.
- `stable` — weekly promoted channel. No direct pushes.
- `feat/*`, `fix/*`, `docs/*` — human work.
- `bot/knowledge-YYYY-WW` — the knowledge loop. Stricter rules, per G7 and G4.
