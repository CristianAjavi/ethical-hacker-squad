# Ethical Hacker Squad

A skill and plugin for [Claude Code](https://claude.com/claude-code) that turns the main thread into the **leader of an adaptive squad of ethical offensive-security subagents**. It inventories the project, staffs the team from the artifacts that actually exist, investigates with reproducible evidence, fixes only what was confirmed, and verifies every change with an agent other than the one that fixed it.

> **Authorized use only.** This skill is for auditing systems you own or have explicit permission to test. Its safety contract forbids persistence, exfiltration, destruction, denial of service, real phishing, stealth evasion and lateral movement, and requires authorization before scanning remote targets, exploiting a vulnerability, or touching production.

## Start here

**Install** (Claude Code 2.1.275 or later):

```
/plugin install ethical-hacker-squad --marketplace CristianAjavi/ethical-hacker-squad
```

On an older Claude Code, add the marketplace first: `/plugin marketplace add CristianAjavi/ethical-hacker-squad`, then `/plugin install ethical-hacker-squad@ethical-hacker-squad`.

**Ask it what you would ask a security reviewer**, in your own language:

| You want | Say something like | What happens |
|---|---|---|
| to know whether your app is safe to launch | "I built this with an AI tool and launch next week. Is it safe?" | a **quick audit**: the leader alone runs an ordered checklist for your stack (secrets, database rules, Server Actions, payments, cron routes, your LLM key), capped at twelve procedures, and writes **Fix these first** in plain language |
| a full review | "Audit this repository without modifying files." | the leader staffs two to four specialists for what the repository actually contains and reports with evidence |
| fixes | "Fix the confirmed findings and verify them." | `harden` mode: a remediator patches, a different agent verifies |

**What you get**: `report.md` and `findings.json` in a folder whose absolute path the run prints at the end ([an example of a quick report](docs/examples/quick-report.md)). The report opens with the items to fix first; every finding names its file, its evidence and how to check the fix. `scripts/ehs sarif` turns `findings.json` into SARIF for GitHub code scanning if you want the findings in the Security tab.

**What it costs**: a quick audit reads only its checklist and dispatches no subagent. A full audit dispatches several, each capped at 60 turns, and costs several times what one reply of the model alone costs. It never starts paid tools, scanners against remote targets or anything that runs your code without asking first.

## What it is measured to do, and what it is not

The honest summary comes before the pitch.

- **The corpus, measured against the same model with no corpus: it leads on none of eighteen blinded measurements.** Recall on files and on whole repositories, precision at two model scales, reader utility, consistency: at frontier scale it is indistinguishable from an unaided competent reviewer. Whole-repository detection of the one advisory measured that way is the model's; the corpus adds nothing to it. Every number, prompt and retraction is in [`bench/`](bench/).
- **The product you install, measured once: no difference from the model alone.** In 13 of the 17 bench rounds that kept their prompts, the prompts told the model not to delegate to subagents, so the installed squad was never scored. [`evals/`](evals/) scores it against the same model with no plugin. [Its first run](evals/measured/2026-10-17-sonnet-5-5/) (Sonnet 5.5, one synthetic app with nine planted defects) gave **Δ 0.00** on both cases at about a fifth more cost: the model alone found every defect. The app is too easy to separate the arms; external targets and a smaller model are next. The comparison with `/security-review` could not run inside the macOS eval sandbox.
- **What is measured in its favour is narrower than "finds more"**: a findings format with a place to say *I could not decide this*, a coverage declaration that must resolve every surface as read or not read, and zero decoys reported on eleven constructs built to be mistaken for the defect beside them.
- **Against three comparable products** on two targets authored here, at one model scale, it is the only arm inside both the precision and the recall band on both targets — an absence of outliers, not a lead. The comparison is dated 2026-08-22 ([`docs/competitive-baseline.json`](docs/competitive-baseline.json)).

## What makes it different

Most "act as a security expert" prompts are adjectives. This one ships **procedural knowledge**: 4,870 lines of corpus across eight role packs, with 180 numbered procedures. Each procedure states where to look per stack, the vulnerable pattern, **what rules it out as a false positive**, a minimal non-destructive test, the standard identifiers it maps to, and the tool command plus what that tool's output does *not* prove.

- **An adaptive team, not a fixed checklist.** Two to four relevant specialists. No mobile agent without a mobile artifact.
- **Detection and verification are separate agents.** The verifier works from the finding and the diff, never from the fixer's conclusion, and tries to refute both.
- **False-positive criteria are a required field.** Half the value of a security review is knowing when not to report. A finding that skipped that field is untriaged.
- **Honest coverage.** The report must declare which standard families were exercised and which were not. It never claims a system is secure.
- **Evidence over noise.** A tool match is not a finding — and a clean scan is not evidence of absence, because measured per-tool recall on real vulnerabilities runs well under half.
- **Reports in your language.** The corpus is English so it stays aligned with the identifiers and scanner output it cites; findings are written in whatever language you are using. Identifiers are never translated.

## Modes

| Mode | What it does |
|---|---|
| `audit` | Detects and prioritizes **without modifying files** (the default when in doubt). |
| `harden` | Audits, fixes confirmed findings inside the repository, and verifies. |
| `verify` | Checks existing fixes or controls. |
| `quick` | An `audit` with a hard cap: the leader alone, the stack's ordered checklist, **Fix these first**. What a non-specialist asking "is it safe?" gets first. |

## The squad

`security-lead` (you) · `web-api` · `mobile` · `infra-cloud` · `supply-chain` · `ai-safety` · `privacy-abuse` · `local-app` · `remediator` · `verifier`

Installed as a plugin, each specialist is a real subagent with its own tool access: auditors ship without `Edit` and `Write`, and only the remediator can modify files. That closes the direct write path, not every write path — auditors keep `Bash`, so the working tree is checked after an `audit` run rather than assumed clean.

## Knowledge

Eight packs, one per role. Six of them are stored as **more than one file** (`web-api` as four; `mobile`, `supply-chain`, `ai-safety` and `infra-cloud` as three; `local-app` as two) so no single file exceeds the 32 KiB per-file budget that keeps selective loading possible; every file of a pack belongs to the same role and they share one procedure numbering.

| Pack | File(s) | Procedures | Covers |
|---|---|---|---|
| web-api | `web-api.md` | `WEB-01`..`WEB-12`, `WEB-24`..`WEB-25` | authn and sessions, object- and function-level authorization, injection, SSRF, deserialization and upload |
| | `web-api-clientside-logic.md` | `WEB-13`..`WEB-21`, `WEB-23`, `WEB-26`..`WEB-27` | XSS and client sinks, CSRF/CORS/caching, business logic and rate limiting, crypto, GraphQL and WebSocket, and a control that runs without being able to fail |
| | `web-api-logging.md` | `WEB-22`, `WEB-28` | what leaks out through the log, and what an attacker writes into it |
| | `web-api-baas.md` | `WEB-29`..`WEB-32` | a backend-as-a-service the browser reaches directly: Supabase row-level security and Firebase Security Rules as the only authorization there is, a privilege column the user can write, Edge Functions that skip the caller |
| | `web-api-fullstack.md` | `WEB-33`..`WEB-36` | full-stack frameworks: Server Actions and Route Handlers that trust the page, authorization only in the proxy, cron routes anyone can call, Stripe webhooks and prices |
| mobile | `mobile.md` | `MOB-01`..`MOB-12` | manifest and exported surface, storage and logs, WebViews and bridges, deep links and intents, TLS and pinning, crypto and embedded secrets |
| | `mobile-runtime-trust.md` | `MOB-13`, `MOB-16`..`MOB-18` | client-only controls, biometrics bound to a key, overlay and accessibility defenses on confirmation screens, code loaded after the store |
| | `mobile-ios.md` | `MOB-14`..`MOB-15` | iOS specifics: `Info.plist`, ATS, URL schemes, entitlements, Keychain, pasteboard |
| infra-cloud | `infra-cloud.md` | `INF-01`..`INF-12` | Terraform and IaC, containers, Kubernetes |
| | `infra-cloud-cicd-exposure.md` | `INF-13`..`INF-18`, `INF-24` | CI/CD and GitHub Actions, environment separation and deployment secrets, remote exposure |
| | `infra-cloud-cicd-platforms.md` | `INF-19`..`INF-23` | GitLab CI, Jenkins, Azure Pipelines, CircleCI and Bitbucket: untrusted-contributor pipelines, metadata in a shell step, credential scope, moving pipeline imports, the runner as a machine |
| supply-chain | `supply-chain.md` | `SUP-01`..`SUP-15` | manifests and locks, install scripts, dependency confusion, typosquatting and slopsquatting, pipeline integrity, provenance and SBOM, reachability-aware triage |
| | `supply-chain-secrets-malware.md` | `SUP-16`..`SUP-20`, `SUP-27` | secrets in tree, history and CI, a server secret shipped to the browser behind a public build prefix, malicious-package indicators |
| | `supply-chain-source-lifecycle.md` | `SUP-21`..`SUP-26` | release and tag integrity, signature verification that verifies nothing, binaries in the tree, end-of-life runtimes, suppression and VEX files |
| ai-safety | `ai-safety.md` | `AI-01`..`AI-11`, `AI-29` | the lethal-trifecta check, instruction/data boundary, tool authorization, MCP and tool poisoning |
| | `ai-safety-data-output.md` | `AI-12`..`AI-24` | RAG and memory poisoning, model output as a dangerous sink, context exposure, unbounded consumption, Unicode obfuscation, adversarial evaluation, and the squad's own self-protection |
| | `ai-safety-agent-runtime.md` | `AI-25`..`AI-28`, `AI-30` | an installable agent package, an agent that can write its own configuration, agent-to-agent delegation, attribution of an action |
| local-app | `local-app.md` | `LOC-01`..`LOC-10`, `LOC-15`..`LOC-16` | who the second principal is, path traversal and archive extraction, temporary files and races, argument injection and search paths, permissions and privileged helpers, insecure library defaults, secrets left on the machine, and undecodable bytes that abort or silently narrow the analysis |
| | `local-app-desktop-ipc.md` | `LOC-11`..`LOC-14` | Electron and WebView renderer isolation, protocol handlers and deep links, local IPC and loopback listeners, code that arrives at runtime |
| privacy-abuse | `privacy-abuse.md` | `PRV-01`..`PRV-13` | personal data mapping, minimization and retention, multitenancy, third-party SDKs, user data reaching models, export and deletion, log leakage, product abuse paths |
| remediation | `remediation.md` | `REM-01`..`REM-07` | minimum root-cause patching, regression tests that must fail without the patch, authorization limits, ordering |
| verification | `remediation-verification.md` | `VER-01`..`VER-09` | adversarial posture, negative checks, honest classification |

Navigation is progressive: `SKILL.md` is a router, `coverage.md` maps detected technology to roles and to the exact file and sections that hold them, and each specialist loads only its own pack — and only the sections its inventory justifies. Loading everything is a bug, not thoroughness.

Supporting references: [`traceability.md`](skills/ethical-hacker-squad/references/traceability.md) (standard-to-role matrix, citation policy, and a declared list of coverage gaps), [`tooling.md`](skills/ethical-hacker-squad/references/tooling.md) (non-destructive invocation, network posture, licence traps, per-tool false positives), [`bibliography.md`](skills/ethical-hacker-squad/references/bibliography.md).

## Standards it maps to

OWASP Top 10:2025 · API Security Top 10 2023 · WSTG v4.2 · ASVS 5.0.0 · MASVS 2.1.0 and MASTG 2.0.0 · Top 10 for LLM Applications 2026 · Top 10 for Agentic Applications 2026 · Top 10 CI/CD Security Risks · CWE and CWE Top 25 (2025) · CAPEC · ATT&CK v19 · ATLAS · NIST SSDF 800-218 v1.1, SP 800-115, SP 800-53 Rev.5, AI RMF · SLSA v1.2 · CIS Controls v8.1 · CSA CCM v4.1.

Identifiers are cited; **no standard text is reproduced**. Most of these are CC BY-SA or more restrictive, and copying their wording would contaminate this repository's MIT licence. See [`NOTICE.md`](NOTICE.md).

## Install, update and channels

The one-step install is under **Start here**. To update:

```
/plugin marketplace update ethical-hacker-squad
/plugin update ethical-hacker-squad
```

Claude Code also refreshes marketplaces in the background after startup, so updates usually arrive without being asked for. The repository is public, so no credentials are involved. What installs is the `dist` branch — the skill, the agents, the hook and the scripts they call, about 1 MB — not this repository with its bench and gates ([`docs/release-channels.md`](docs/release-channels.md)).

**Channels.** Today there is one: `main` is the `latest` channel, and every commit on it is a new version. A `stable` channel — a weekly, tagged, rested promotion — is specified in [`docs/release-channels.md`](docs/release-channels.md) and **has never been published**: the promotion has failed every week it has run. To pin a version today, add the marketplace at a specific `ref` or `sha`.

**As a personal or project skill** — works, but ships no subagents and no scripts; the skill falls back to `general-purpose` agents with the role prompt injected:

```bash
git clone https://github.com/CristianAjavi/ethical-hacker-squad.git /tmp/ehs
cp -R /tmp/ehs/skills/ethical-hacker-squad ~/.claude/skills/     # personal
cp -R /tmp/ehs/skills/ethical-hacker-squad .claude/skills/       # project
```

## Use

```
Use the ethical-hacker-squad skill to audit this repository without modifying files.
Use ethical-hacker-squad in harden mode on /path/project and fix the confirmed findings.
Use ethical-hacker-squad to review this local APK; do not test remote services.
Use ethical-hacker-squad on the chatbot, focusing on prompt injection, tool authorization and data leakage.
```

Every finding comes back with an ID, the procedure that produced it, status (confirmed / probable / hardening / discarded), severity, confidence, location, redacted evidence, impact, recommended fix, verification method and standard traceability.

The machine-readable half, `findings.json`, can be exported for GitHub code scanning with `scripts/ehs sarif findings.json -o ehs.sarif`. Writing the file is local; uploading it is a separate decision. See [`findings-artifact.md`](skills/ethical-hacker-squad/references/findings-artifact.md#exporting-it-to-github-code-scanning).

## How it stays current

Not automatically, today. A knowledge loop — a daily check of the pinned sources and a weekly review of a slice of the corpus, each opening a pull request — is designed in [`docs/knowledge-loop.md`](docs/knowledge-loop.md), including its threat model: a poisoned source would become an instruction inside the security agent of everyone who installed the plugin. **No workflow runs it yet.** What does run: the gates on every pull request, and scheduled checks for supply-chain hygiene, OpenSSF Scorecard, repository-protection and label drift, and the freshness of the competitive baseline. Corpus changes today are made by hand, through pull requests, against primary sources.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). The two first-class issue types are `false-positive` and `false-negative` — audit-quality errors, not crashes. And the closure rule: an issue is closed by the fix **plus the check that stops it recurring**, which CI enforces.

To report a vulnerability in this repository itself, do not open a public issue — see `SECURITY.md`.

## Licence

MIT — see [`LICENSE`](LICENSE). Third-party attributions and licence determinations for every source cited are in [`NOTICE.md`](NOTICE.md).
