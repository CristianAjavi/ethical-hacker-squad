# Gate requirements

The specification the CI gates implement. This file states **what must be true**; the executable checks live under `scripts/gates/` and the workflows under `.github/workflows/`.

Written as a contract on purpose: the corpus and the machinery that guards it are maintained separately, and this is the interface between them. If a gate and this document disagree, the disagreement is itself a bug — fix both in the same pull request.

## Exit-code semantics — applies to every gate

Three outcomes, three exit codes. A gate that cannot tell "I measured and it is fine" from "I could not measure" is worse than no gate, because a tool that fails to run looks identical to a clean result.

| Exit code | Meaning | CI behaviour |
|---|---|---|
| `0` | Measured, within threshold | pass |
| `1` | Measured, outside threshold | fail with the offending items listed |
| `2` | Could not measure (tool missing, network unavailable, file unreadable, parse error) | fail, reported as **unmeasured**, never as pass |

Every gate must be **proved in the negative**: a fixture that makes it exit `1`, and a condition that makes it exit `2`, both exercised in CI. A gate never observed failing is a gate nobody knows works.

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

## G4 — Every knowledge item is cited

Every procedure in `references/knowledge/*.md` carries a **Traceability** line with at least one identifier, and every quantitative claim names its source. An item the loop adds or modifies additionally carries a source URL from the allowlist and a consultation date.

Fails with the list of procedures missing traceability. This is what keeps the corpus falsifiable: an uncited claim cannot be checked, and cannot be corrected when it goes stale.

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
