# Changelog

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The `latest` channel (`main`) resolves to the commit SHA and has no version number by design — see `docs/release-channels.md`. Version numbers below apply to the `stable` channel.

## [Unreleased]

### Added

- **`AI-23`** — model, adapter and dataset artifacts loaded without provenance or safe deserialization. A checkpoint is executable content: `.pt`, `.pkl`, `.ckpt` and `.h5` deserialize into Python objects and run code while loading, before a single token is generated, and `trust_remote_code=True` executes modelling code from the repository. Pulling by tag instead of by digest means the artifact you audited is not the artifact production loads.
- **`PRV-12`** — where personal data physically lands and where it is replicated: the `region` argument of every store, its backups, replicas and the third parties that receive it, against the jurisdiction the product declares. States the technical fact and never rules on lawfulness.

- **Knowledge corpus** (3,331 lines, 139 numbered procedures across 7 role packs stored in 15 files). Each procedure carries where to look per stack, the vulnerable pattern, false-positive criteria, a minimal non-destructive test, standard traceability and tool guidance: `web-api` (`WEB-01`..`WEB-22`), `mobile` (`MOB-01`..`MOB-18`), `infra-cloud` (`INF-01`..`INF-18`), `supply-chain` (`SUP-01`..`SUP-25`), `ai-safety` (`AI-01`..`AI-28`), `privacy-abuse` (`PRV-01`..`PRV-13`), `remediation` (`REM-01`..`REM-07`, `VER-01`..`VER-08`). Five packs are split across more than one file — `web-api` and `infra-cloud` across two, `mobile`, `supply-chain` and `ai-safety` across three — so that no reference file exceeds the 32 KiB per-file budget enforced by `gate-plugin-integrity.sh`. `references/knowledge/README.md` is the loading map and names every file with its identifier range. The split is by section boundary only: procedure identifiers, their text and their six fields are unchanged, so every `WEB-*`, `MOB-*`, `INF-*`, `SUP-*` and `AI-*` reference in an existing report or issue still resolves.
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

- **Two holes in the procedure numbering.** `AI-23` and `PRV-12` were drafted in `docs/coverage/` and never landed, so the corpus jumped `AI-22`→`AI-24` and `PRV-11`→`PRV-13` while `team.md` and the packs declared unbroken ranges. Landing them closes both holes; the meter now reports `numbering gaps: none`.
- **A knowledge file that was in no count.** `ai-safety-agent-runtime.md` (`AI-25`..`AI-28`) existed on disk and was not declared in `scripts/meter/packs.json`, so four procedures were invisible to the corpus measurement and the file was missing from the loading map altogether.
- **Every declared count was stale.** `README.md` said 2,830 lines and 122 procedures, the corpus README said fourteen files and 132, `SKILL.md` said twelve files, `team.md` declared `AI-01`..`AI-22`, `PRV-01`..`PRV-11` and `VER-01`..`VER-07`, and the CHANGELOG repeated the old ranges. All refreshed from measurement.
- Two identifiers in the landed drafts were corrected before they shipped: ATLAS sub-technique suffixes that could not be verified today were coarsened to the technique that was (`AML.T0010`), and a Microsoft benchmark control was dropped because that source is not in the allowlist. Both are now stated in the citation policy and the gap list rather than left implicit.

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
