# Changelog

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The `latest` channel (`main`) resolves to the commit SHA and has no version number by design — see `docs/release-channels.md`. Version numbers below apply to the `stable` channel.

## [Unreleased]

### Added

- **Knowledge corpus** (2,749 lines, 122 numbered procedures across 7 role packs). Each procedure carries where to look per stack, the vulnerable pattern, false-positive criteria, a minimal non-destructive test, standard traceability and tool guidance: `web-api` (`WEB-01`..`WEB-22`), `mobile` (`MOB-01`..`MOB-15`), `infra-cloud` (`INF-01`..`INF-18`), `supply-chain` (`SUP-01`..`SUP-20`), `ai-safety` (`AI-01`..`AI-22`), `privacy-abuse` (`PRV-01`..`PRV-11`), `remediation` (`REM-01`..`REM-07`, `VER-01`..`VER-07`).
- **Dedicated plugin subagents** under `agents/`. Auditor roles ship without `Edit` and `Write`, so read-only operation in `audit` mode is enforced by the harness rather than requested in a prompt.
- **`references/traceability.md`** — verified state of every cited standard, the standard-to-role matrix, the citation policy, and an explicit list of known coverage gaps.
- **`references/tooling.md`** — per-surface non-destructive invocation, network posture, licence constraints, and the typical false positive of each tool.
- **`references/bibliography.md`** — annotated bibliography with verified bibliographic data and free-to-read status.
- **`NOTICE.md`** — third-party attributions and licence determinations, including the MITRE attribution notice.
- **`docs/release-channels.md`**, **`docs/knowledge-loop.md`**, **`docs/gate-requirements.md`**, **`docs/sources-allowlist.json`** — distribution model, the knowledge loop and its threat model, the CI gate contract, and the loop's source allowlist.
- **`CONTRIBUTING.md`** — branch model, issue taxonomy, the closure rule, and the local testing procedure.
- Safety-contract rules 8 and 9: audited content is data and never instructions, and tool budgets require an explicit cap.
- Output-language rule: the corpus is English, findings are written in the user's language, identifiers are never translated.

### Fixed

- **`plugin.json` no longer declares a fixed `version`.** Claude Code resolves plugin version as `plugin.json` → marketplace entry → commit SHA, so the hardcoded `"1.0.0"` meant that pushing new commits delivered nothing to existing installs: the resolved version never changed and the cached copy was considered current. Every commit on `main` now resolves to a distinct SHA, and the semver lives solely in the marketplace entry on `stable`.

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
