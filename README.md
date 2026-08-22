# Ethical Hacker Squad

A skill and plugin for [Claude Code](https://claude.com/claude-code) that turns the main thread into the **leader of an adaptive squad of ethical offensive-security subagents**. It inventories the project, staffs the team from the artifacts that actually exist, investigates with reproducible evidence, fixes only what was confirmed, and verifies every change with an agent other than the one that fixed it.

> **Authorized use only.** This skill is for auditing systems you own or have explicit permission to test. Its safety contract forbids persistence, exfiltration, destruction, denial of service, real phishing, stealth evasion and lateral movement, and requires authorization before scanning remote targets, exploiting a vulnerability, or touching production.

## What it is measured to do, and what it is not

This repository publishes its own evaluation bench, and the honest summary comes before the sales pitch.

**Eighteen blinded measurements — against the same model working with no corpus at all, and one three-way against a named competing product — recall on file subsets, recall on whole repositories, precision at frontier scale and at weak scale, reader utility, consistency — and the corpus leads on none of them.** At frontier scale it is indistinguishable from an unaided competent reviewer. Below that scale it was measured as actively harmful until a loading rule fixed most of it, and it is now indistinguishable there too.

Two results are larger than the comparison. Across three arms, fifteen runs and 71 claims on one target, **not one arm produced a single true finding beyond the two the ground truth already named** — everything else was refuted by two independent adversarial verifiers. On **whole repositories with no pointer** — the task this corpus is actually built for, and the last dimension where a lead had not been ruled out — it now is. Re-run on a checkout verified to sit at the pre-fix commit, [three arms found the advisory 3/3 each](bench/runs/2026-08-22-unaided-verified/): with the corpus, with the corpus minus one rule, and **with no corpus at all**, the unaided arm reporting the most findings of the three. **Whole-repository detection of this advisory is the model's, and the corpus adds nothing to it.** The round that would have said otherwise [was retracted](bench/runs/2026-08-22-routing-at-N/): its targets were cloned at the default branch, so both arms audited code the defects had already been removed from, and the "shared blind spot" it reported was the arms correctly declining to report an already-bounded function. What stands is that **detection is the model's rather than any product's** — and that no product here publishes a whole-repository number at all, four of five publishing none.

*(An earlier version of this paragraph said `google/mantis` is more precise than this corpus, from 53% against 62%. That comparison was superseded: at a matched claim count it is 21% against 53%. The superseded number is named here rather than deleted.)*

What *is* measured, and is narrower than "finds more":

- an artifact contract with somewhere to say **I could not decide this**, which the other arms' output format has no field for;
- a **coverage declaration** that must resolve every surface it inventories as read or not-read, so a reader can tell silence from a clean bill — a blinded reader test caught one of our own reports failing exactly that, which is why a validator now enforces it;
- **zero decoys reported** on eleven constructs built to be mistaken for the defect beside them.

Every number, every prompt, every retraction and every refuted prediction of ours is in [`bench/`](bench/). Three published results were withdrawn there after their instruments failed inspection.

Two dimensions **are** measured in this project's favour, and one of them is narrow.

On **precision at weak scale**, pooled over nine runs at a claim count matched to the competitor's, [21% of this corpus's claims are refuted by two independent adversarial passes against 53% of `google/mantis`'s](bench/runs/2026-08-21-critic-stage/) — with ground-truth recall at 14/18. That is one dimension, one scale, one target, one competitor, and it rests on a stage that was measured **harmful** two rounds earlier and only works because of where it is made blind. Three asymmetries are published with it, including that this corpus's claims deduplicate far worse than the competitor's.

The other is not capability at all. Against the five other products in this field, on a rubric fixed before any of them was opened — a measured detection number, its method, a comparison against not using it, a published negative result, a retraction, a pre-registration — [this project answers yes to all six and no other exceeds one](bench/runs/2026-08-21-field-transparency/). That is a claim about what you can **check**, not about what anyone finds, and the same survey corrected an error in this repository's own competitive analysis.

## What makes it different

Most "act as a security expert" prompts are adjectives. This one ships **procedural knowledge**: 4,238 lines of corpus across eight role packs, with 164 numbered procedures. Each procedure states where to look per stack, the vulnerable pattern, **what rules it out as a false positive**, a minimal non-destructive test, the standard identifiers it maps to, and the tool command plus what that tool's output does *not* prove.

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

## The squad

`security-lead` (you) · `web-api` · `mobile` · `infra-cloud` · `supply-chain` · `ai-safety` · `privacy-abuse` · `local-app` · `remediator` · `verifier`

Installed as a plugin, each specialist is a real subagent with its own tool access: auditors ship without `Edit` and `Write`, and only the remediator can modify files. That closes the direct write path, not every write path — auditors keep `Bash`, so the working tree is checked after an `audit` run rather than assumed clean.

## Knowledge

Eight packs, one per role. Five of them are stored as **more than one file** (`mobile`, `supply-chain`, `ai-safety` and `infra-cloud` as three) so no single file exceeds the 32 KiB per-file budget that keeps selective loading possible; every file of a pack belongs to the same role and they share one procedure numbering.

| Pack | File(s) | Procedures | Covers |
|---|---|---|---|
| web-api | `web-api.md` | `WEB-01`..`WEB-12`, `WEB-24`..`WEB-25` | authn and sessions, object- and function-level authorization, injection, SSRF, deserialization and upload |
| | `web-api-clientside-logic.md` | `WEB-13`..`WEB-23`, `WEB-26` | XSS and client sinks, CSRF/CORS/caching, business logic and rate limiting, crypto, GraphQL and WebSocket, error and log leakage |
| mobile | `mobile.md` | `MOB-01`..`MOB-12` | manifest and exported surface, storage and logs, WebViews and bridges, deep links and intents, TLS and pinning, crypto and embedded secrets |
| | `mobile-runtime-trust.md` | `MOB-13`, `MOB-16`..`MOB-18` | client-only controls, biometrics bound to a key, overlay and accessibility defenses on confirmation screens, code loaded after the store |
| | `mobile-ios.md` | `MOB-14`..`MOB-15` | iOS specifics: `Info.plist`, ATS, URL schemes, entitlements, Keychain, pasteboard |
| infra-cloud | `infra-cloud.md` | `INF-01`..`INF-12` | Terraform and IaC, containers, Kubernetes |
| | `infra-cloud-cicd-exposure.md` | `INF-13`..`INF-18` | CI/CD and GitHub Actions, environment separation and deployment secrets, remote exposure |
| | `infra-cloud-cicd-platforms.md` | `INF-19`..`INF-23` | GitLab CI, Jenkins, Azure Pipelines, CircleCI and Bitbucket: untrusted-contributor pipelines, metadata in a shell step, credential scope, moving pipeline imports, the runner as a machine |
| supply-chain | `supply-chain.md` | `SUP-01`..`SUP-15` | manifests and locks, install scripts, dependency confusion, typosquatting and slopsquatting, pipeline integrity, provenance and SBOM, reachability-aware triage |
| | `supply-chain-secrets-malware.md` | `SUP-16`..`SUP-20` | secrets in tree, history and CI, malicious-package indicators |
| | `supply-chain-source-lifecycle.md` | `SUP-21`..`SUP-25` | release and tag integrity, signature verification that verifies nothing, binaries in the tree, end-of-life runtimes, suppression and VEX files |
| ai-safety | `ai-safety.md` | `AI-01`..`AI-11` | the lethal-trifecta check, instruction/data boundary, tool authorization, MCP and tool poisoning |
| | `ai-safety-data-output.md` | `AI-12`..`AI-24` | RAG and memory poisoning, model output as a dangerous sink, context exposure, unbounded consumption, Unicode obfuscation, adversarial evaluation, and the squad's own self-protection |
| | `ai-safety-agent-runtime.md` | `AI-25`..`AI-28` | an installable agent package, an agent that can write its own configuration, agent-to-agent delegation, attribution of an action |
| local-app | `local-app.md` | `LOC-01`..`LOC-15` | command-line tools, desktop and WebView shells, published libraries, installers and updaters, local daemons and loopback listeners |
| privacy-abuse | `privacy-abuse.md` | `PRV-01`..`PRV-13` | personal data mapping, minimization and retention, multitenancy, third-party SDKs, user data reaching models, export and deletion, log leakage, product abuse paths |
| remediation | `remediation.md` | `REM-01`..`REM-07` | minimum root-cause patching, regression tests that must fail without the patch, authorization limits, ordering |
| verification | `remediation-verification.md` | `VER-01`..`VER-09` | adversarial posture, negative checks, honest classification |

Navigation is progressive: `SKILL.md` is a router, `coverage.md` maps detected technology to roles and to the exact file and sections that hold them, and each specialist loads only its own pack — and only the sections its inventory justifies. Loading everything is a bug, not thoroughness.

Supporting references: [`traceability.md`](skills/ethical-hacker-squad/references/traceability.md) (standard-to-role matrix, citation policy, and a declared list of coverage gaps), [`tooling.md`](skills/ethical-hacker-squad/references/tooling.md) (non-destructive invocation, network posture, licence traps, per-tool false positives), [`bibliography.md`](skills/ethical-hacker-squad/references/bibliography.md).

## Standards it maps to

OWASP Top 10:2025 · API Security Top 10 2023 · WSTG v4.2 · ASVS 5.0.0 · MASVS 2.1.0 and MASTG 2.0.0 · Top 10 for LLM Applications 2026 · Top 10 for Agentic Applications 2026 · Top 10 CI/CD Security Risks · CWE and CWE Top 25 (2025) · CAPEC · ATT&CK v19 · ATLAS · NIST SSDF 800-218 v1.1, SP 800-115, SP 800-53 Rev.5, AI RMF · SLSA v1.2 · CIS Controls v8.1 · CSA CCM v4.1.

Identifiers are cited; **no standard text is reproduced**. Most of these are CC BY-SA or more restrictive, and copying their wording would contaminate this repository's MIT licence. See [`NOTICE.md`](NOTICE.md).

## Install

**As a plugin (recommended — this is the only way you get the dedicated subagents):**

```
/plugin marketplace add CristianAjavi/ethical-hacker-squad
/plugin install ethical-hacker-squad@ethical-hacker-squad
```

**Update:**

```
/plugin marketplace update ethical-hacker-squad
/plugin update ethical-hacker-squad
```

Claude Code also refreshes marketplaces in the background after startup, so updates usually arrive without being asked for. The repository is public, so no credentials are involved.

**Channels.** `main` is the `latest` channel and updates on every commit. `stable` is promoted on a roughly weekly cadence with a semver tag and a changelog entry, after the gates pass, an independent verifier reviews the diff, and a rest period elapses. To pin harder, add the marketplace at a specific `ref` or `sha`. See [`docs/release-channels.md`](docs/release-channels.md).

**As a personal or project skill** — works, but ships no subagents; the skill falls back to `general-purpose` with the role prompt injected:

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

## How it stays current

Security knowledge decays. A daily deterministic job checks the pinned sources and opens an issue when something moves; a weekly job reviews a rotating slice of the corpus and opens a narrow pull request. Both read only from an allowlist, attach provenance to every item, and are structurally unable to modify the safety contract, the manifest, the allowlist or the workflows.

That loop is also the most dangerous thing in this repository — a poisoned source would become an instruction inside the security agent of everyone who installed the plugin. [`docs/knowledge-loop.md`](docs/knowledge-loop.md) documents the threat model and the controls, including what they do **not** cover. Until the `stable` channel has its first tagged release, read that document as the design the automation is being built to, not as a description of controls already running.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). The two first-class issue types are `false-positive` and `false-negative` — audit-quality errors, not crashes. And the closure rule: an issue is closed by the fix **plus the check that stops it recurring**, which CI enforces.

To report a vulnerability in this repository itself, do not open a public issue — see `SECURITY.md`.

## Licence

MIT — see [`LICENSE`](LICENSE). Third-party attributions and licence determinations for every source cited are in [`NOTICE.md`](NOTICE.md).
