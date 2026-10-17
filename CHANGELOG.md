# Changelog

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The `latest` channel (`main`) resolves to the commit SHA and has no version number by design — see `docs/release-channels.md`. Versions belong to the `stable` channel, whose own changelog is generated from commit subjects when a release is promoted (`scripts/gh/build-changelog.sh`).

Everything up to 2026-10-12 — the original release and two months of governance work, 154 KB that sat under `[Unreleased]` because no version was ever promoted — is in [`docs/changelog-history.md`](docs/changelog-history.md), unchanged. Each entry below is short; the pull request it names carries the evidence.

## [Unreleased]

Changes from an adversarial review of the whole repository (2026-10-15), whose verdict was that the plugin did not yet serve someone shipping an app built with AI tools, had never been measured as installed, shipped a broken agent, and had spent its effort on ceremony.

### Fixed

- **`ehs-local-app` loaded without its metadata, `tools` restriction included** (#128). Its description carried an unquoted `: ` since 2026-08-20; the CLI that `release.yml` pins reported *"At runtime this agent loads with empty metadata"* every week, which is also why `stable` was never created. `gate-agent-tools.sh` now parses every agent frontmatter as strict YAML and compares the `tools` it yields with what the gate checked.
- **A validator that never ran counted as a pass** (#129). `gate-plugin-version.sh` skipped `claude plugin validate` when the CLI was absent and still returned 0, and the PR check never installed it. A missing validator is now rc=2 and the `gates` job installs the pinned CLI.
- **SARIF export** (#124): `probable` and `hardening` carry `level: none` as SARIF 2.1.0 §3.27.10 requires; fingerprints ignore the line; rules carry help, CWE tags and a category. The findings validator, the export and the report contract share one list of secret formats, now including Stripe, Supabase, OpenAI project and Google keys and signed JWTs.
- **Descriptions that state counts** (#123): the GitHub description, `plugin.json` and the marketplace entry state none, and a gate keeps them that way.
- **The runtime pass** (#126): running the target's code needs authorization (safety rule 4); it runs from a disposable worktree without the target's `.env`, inside the Bash sandbox when the user enables it.
- **Four procedures stated something false, and two quoted figures said something else** (#140): `LOC-01` (Python's `zipfile` sanitizes names), `MOB-09` (defaults by `targetSdkVersion`), `SUP-16` (a valid checksum is not a live token; `sk_test_` is a real key prefix), `INF-13` (confirmation needs a step that runs the checkout); the EPSS efficiencies and the scanner-recall range were corrected against their papers, and every vendor figure was traced to a dated source in `bibliography.md`. `gate-reproduction.sh` passes on Python 3.14.
- **`scripts/ehs install`** (#133) installs nothing without a target, installs the plugin through `claude plugin` with `--claude`, and never deletes a real directory.
- **Validator paths** (#135) resolve from the plugin root, not from the audited repository; a session started inside the target is named as such, with how to start clean.
- **Issue #17** (#138): package installs in workflows carry `--ignore-scripts`, enforced by `gate-workflow-hardening.sh`.

### Added

- **Procedures for apps built with AI tools** (#125): Supabase row-level security, privilege columns and Edge Functions; Firebase rules; Server Actions and Route Handlers; authorization only in the proxy (CVE-2025-29927); cron routes; Stripe webhooks, fulfilment and prices; public build prefixes; the LLM route that spends your key. 180 procedures in twenty-two files.
- **A quick audit with a cost cap** (#130): the leader alone, an ordered checklist for the stack, procedures read one at a time, and a report that opens with **Fix these first** for a non-specialist. Every subagent carries `maxTurns`, `omitClaudeMd` and, for auditors, `disallowedTools`.
- **A shell guard for the auditors** (#134): a plugin hook refuses their shell repository changes, installs, in-place edits, deletes outside temp directories and non-local network. It reads command lines, not effects; `Bash` still writes, so the leader still compares `git status --porcelain --ignored`.
- **`evals/`** (#131): `claude plugin eval` cases that score the installed product against the model alone and against `/security-review`, on a synthetic app with nine planted defects.
- **`scripts/ehs prescan`, `compare` and `cost`** (#136): deterministic leads keyed to procedures, findings matched across runs with expiring suppressions, and the tokens a session spent per agent.
- **A pull-request mode** (#137): `docs/github-action.md` and a workflow to copy.

### Changed

- **The README puts install first** (#132) and says what does not exist yet: no `stable` release, no running knowledge loop.
- **`team.md` loads lighter** (#139): role orders move to `team-roles.md`, read only without the plugin's subagents.
- **The changelog** moved its history to `docs/changelog-history.md`.
- **The plugin installs 1 MB, not 10** (`dist.yml`): users receive a `dist` branch built from `scripts/dist/manifest.txt` and proved to run before it is pushed, without the bench — whose manifests name malicious packages on purpose — the evals or the gates. `stable` installs from `dist-stable`.
- **Fifteen gates block a pull request, not thirty-seven.** The ones whose failure would reach a user stay on every pull request (`scripts/gates/data/gate-sets.json`); the bench, governance and document-consistency gates run weekly in `gates-weekly.yml` and in full over every release candidate. Nothing stopped running.
