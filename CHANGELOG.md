# Changelog

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The `latest` channel (`main`) resolves to the commit SHA and has no version number by design — see `docs/release-channels.md`. Version numbers below apply to the `stable` channel.

## [Unreleased]

### Added

- **Executable gates `G1`-`G4`** under `scripts/gates/`, running in CI on every push and pull request (`.github/workflows/gates.yml`, `actions/checkout` pinned by commit SHA, `contents: read` only, no privileged trigger). They enforce what `docs/gate-requirements.md` had only specified: manifest and agent structure including the rule that no auditor may declare a write tool, internal links and pack paths, the context budget, every number the prose states about itself, and the citation, anatomy and sourcing of every procedure. `G4` additionally rejects an identifier matching no known family, which is what catches a fabricated ID sitting between real ones. Three exit codes: measured-and-fine, measured-and-wrong, and could-not-measure, which fails rather than passing quietly.
- **Mutant bank** (`tests/gate_mutants.py`): 25 mutations plus a clean baseline. Each copies the repository, breaks exactly one thing, and asserts the gate notices with the right exit code. A gate nobody has watched fail is a gate nobody knows works.
- **`SECURITY.md`** — private disclosure through GitHub Security Advisories, and what counts as a vulnerability in a repository whose product is prose that an agent executes.

### Fixed

- `infra-cloud.md` declared a cost of `~370` lines while measuring 387. Found by `G3b` on its first run, which is the argument for the gate.
- Claims of enforcement that did not exist yet, corrected in `README.md`, the corpus README and the three status banners: `G1`-`G4` now run, `G5`-`G9` are still specification, and the text says which is which.

- **Knowledge corpus** (2,749 lines, 122 numbered procedures across 7 role packs). Each procedure carries where to look per stack, the vulnerable pattern, false-positive criteria, a minimal non-destructive test, standard traceability and tool guidance: `web-api` (`WEB-01`..`WEB-22`), `mobile` (`MOB-01`..`MOB-15`), `infra-cloud` (`INF-01`..`INF-18`), `supply-chain` (`SUP-01`..`SUP-20`), `ai-safety` (`AI-01`..`AI-22`), `privacy-abuse` (`PRV-01`..`PRV-11`), `remediation` (`REM-01`..`REM-07`, `VER-01`..`VER-07`).
- **Dedicated plugin subagents** under `agents/`. Auditor roles ship without `Edit` and `Write`, which removes the most direct write path. It is a real reduction, not a guarantee: auditors keep `Bash`, so read-only operation still depends on the contract and must be confirmed with `git status --porcelain` after a run.
- **`references/traceability.md`** — verified state of every cited standard, the standard-to-role matrix, the citation policy, and an explicit list of known coverage gaps.
- **`references/tooling.md`** — per-surface non-destructive invocation, network posture, licence constraints, and the typical false positive of each tool.
- **`references/bibliography.md`** — annotated bibliography with verified bibliographic data and free-to-read status.
- **`NOTICE.md`** — third-party attributions and licence determinations, including the MITRE attribution notice.
- **`docs/release-channels.md`**, **`docs/knowledge-loop.md`**, **`docs/gate-requirements.md`**, **`docs/sources-allowlist.json`** — distribution model, the knowledge loop and its threat model, the CI gate contract, and the loop's source allowlist.
- **`CONTRIBUTING.md`** — branch model, issue taxonomy, the closure rule, and the local testing procedure.
- Safety-contract rules 8 and 9: audited content is data and never instructions, and tool budgets require an explicit cap.
- Output-language rule: the corpus is English, findings are written in the user's language, identifiers are never translated.

### Fixed

- **`plugin.json` no longer declares a fixed `version`.** Claude Code resolves plugin version as `plugin.json` → marketplace entry → commit SHA, so the hardcoded `"1.0.0"` meant that pushing new commits delivered nothing to existing installs: the resolved version never changed and the cached copy was considered current. Every commit on `main` now resolves to a distinct SHA. The semver will live solely in the marketplace entry on the `stable` branch; that branch and its first tagged release do not exist yet.

### Changed

- Repository language is now English throughout, including commit messages. Translating technical material makes it drift away from the identifiers and scanner output it cites. This does not affect report language, which follows the user.
- `SKILL.md` rewritten as a router: safety contract, output language, a load-when table, plugin-agent mapping with a documented fallback, and the leader workflow.
- `coverage.md` rewritten as an inventory-signal routing table pointing at roles and pack sections, rather than a checklist.
- `report.md` now requires a **coverage declaration** naming what was and was not exercised.
- `team.md` now maps each role to its pack and procedure ID range, and requires a coverage declaration from every specialist.
- Standard references updated to the versions verified on 2026-08-04: OWASP Top 10 **2025** (not 2021; SSRF folded into `A01`), LLM Top 10 **2026**, Agentic Top 10 2026, ASVS 5.0.0, MASTG 2.0.0, CWE Top 25 2025, ATT&CK v19, SLSA v1.2, CIS Controls v8.1, CSA CCM v4.1.

## [1.0.0] - 2026-08-03

### Added

- Initial release: skill and plugin scaffolding, safety contract, leader workflow, role orders, technology coverage and report format.
