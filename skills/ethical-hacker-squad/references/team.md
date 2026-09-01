# Squad orders

The leader staffs only the relevant roles. Every specialist returns evidence, impact, confidence, severity, recommendation and a verification method. No specialist widens the scope or runs remote tests without authorization.

Status, severity, confidence and verification outcome are a **closed vocabulary**, defined once in [vocabulary.md](vocabulary.md). Every role uses those exact terms; a role that needs a term the vocabulary does not have reports that as a defect instead of coining one.

Each role owns exactly one knowledge pack. The pack is the role's procedural memory: the specialist loads it itself, reads only the sections its inventory justifies, and cites the procedure ID (`WEB-07`, `AI-01`, `SUP-14`) in every finding so the leader can trace it. Six packs are stored as **more than one file** for size reasons — `mobile`, `supply-chain` and `ai-safety` as three — and every file of a pack belongs to the same role and shares one procedure numbering; the first file names its siblings in its header.

| Role | Plugin subagent | Knowledge pack | Procedure IDs |
|---|---|---|---|
| Leader | — (main thread) | `traceability.md`, `tooling.md` | — |
| Web and API AppSec | `ehs-web-api` | `knowledge/web-api.md` + `knowledge/web-api-clientside-logic.md` + `knowledge/web-api-logging.md` | `WEB-01`..`WEB-28` |
| Mobile and APK | `ehs-mobile` | `knowledge/mobile.md` + `knowledge/mobile-runtime-trust.md` + `knowledge/mobile-ios.md` | `MOB-01`..`MOB-18` |
| Infrastructure and cloud | `ehs-infra-cloud` | `knowledge/infra-cloud.md` + `knowledge/infra-cloud-cicd-exposure.md` + `knowledge/infra-cloud-cicd-platforms.md` | `INF-01`..`INF-24` |
| Supply chain and secrets | `ehs-supply-chain` | `knowledge/supply-chain.md` + `knowledge/supply-chain-secrets-malware.md` + `knowledge/supply-chain-source-lifecycle.md` | `SUP-01`..`SUP-26` |
| AI, agents and chatbots | `ehs-ai-safety` | `knowledge/ai-safety.md` + `knowledge/ai-safety-data-output.md` + `knowledge/ai-safety-agent-runtime.md` | `AI-01`..`AI-29` |
| Privacy and abuse | `ehs-privacy-abuse` | `knowledge/privacy-abuse.md` | `PRV-01`..`PRV-13` |
| Local applications | `ehs-local-app` | `knowledge/local-app.md` + `knowledge/local-app-desktop-ipc.md` | `LOC-01`..`LOC-16` |
| Remediator | `ehs-remediator` | `knowledge/remediation.md` | `REM-01`..`REM-07` |
| Verifier | `ehs-verifier` | `knowledge/remediation-verification.md` | `VER-01`..`VER-09` |

## Dispatching through Claude Code

- **You are the leader** (the main thread). You inventory, select roles, split paths, deduplicate, and decide priorities. You do not delegate integration or judgement.
- **Each specialist runs through the `Agent` tool.** Send independent, non-colliding specialists in a single message so they run in parallel.

### Preferred path: the plugin's own subagents

When this skill is installed as a plugin, it ships dedicated subagents whose tool access is enforced by the harness, not merely requested in a prompt:

| `subagent_type` | Role | Write access |
|---|---|---|
| `ehs-web-api` | Web, backend and API | none (read-only tools) |
| `ehs-mobile` | Android, iOS, APK | none |
| `ehs-infra-cloud` | IaC, containers, Kubernetes, CI/CD | none |
| `ehs-supply-chain` | Dependencies, provenance, secrets | none |
| `ehs-ai-safety` | LLM applications, agents, MCP, RAG | none |
| `ehs-privacy-abuse` | Personal data and product abuse | none |
| `ehs-local-app` | CLI, desktop apps, published libraries, installers | none |
| `ehs-remediator` | Applies fixes (`harden` mode only) | `Edit`, `Write` |
| `ehs-verifier` | Independent verification | none |

Auditors have no `Edit` or `Write`. That is structural but incomplete: `Bash` can write through the shell, so in `audit` mode confirm with `git status --porcelain` that the tree is unchanged, and treat a modification as a contract breach worth reporting.

Each carries its own safety contract and loads its own pack, so your prompt supplies only: scope and paths, mode, target language, assigned components, and anything specific to this engagement.

### Fallback path: no plugin agents available

Copied into `~/.claude/skills/` rather than installed as a plugin, those subagents do not exist. `references/team.md` holds the fallback: what to copy into a `general-purpose` prompt, and why every constraint has to travel with it.

Never let the same agent both fix and verify.

## The order that comes before every pack

**Read your assigned files with your own judgement first, and write down what you would report with no corpus at all. Only then open your pack.**

Those labels go into `engagement.unaided_pass.candidates`, and the validator enforces what happens to them: each one ends as a finding carrying its `unaided_label`, or in `dropped` with the reason your second reading overturned your first.

**A dismissal costs what an assertion costs.** Dropping a candidate as `refuted` requires `control_at` - the `path:line` where the control that makes it harmless is enforced, on the path that reaches the sink. Dropping it as `merged` requires the id of the finding that absorbed it. This is not bookkeeping: measured on a small-context model, a reviewer short of budget does not fall silent, it refutes confidently - two runs dismissed a real unbounded allocation, one asserting the bounds were correct and one citing the length cap of a different method. Confirming cost every triage rule and dismissing cost a sentence, and that price difference is a thumb on the scale. **If you cannot point at the control, you have not refuted anything - you have run out of time, and `probable` with `what_would_settle_it` is how you say so.** `no procedure covers it` is refused as a reason - that case is `procedure: ad-hoc`, which is a first-class value precisely so nothing has to be bent to fit.

The measurement behind this rule is in `bench/`: against the same model working with no corpus at all, the packs found the same defects and no more, missed a published advisory while the right file was open, and produced *less* agreement between repeated runs than unaided review did. A pack that is opened first stops being a checklist and starts being a boundary. Opened second, it can only add.

## Leader / security-lead

Order: inventory the project, model trust boundaries, select specialists, split paths without overlap, enforce the safety contract, deduplicate results and decide priorities. Challenge any claim without evidence. In `harden` mode, coordinate the remediator and keep a separate verifier. Declare coverage honestly against `traceability.md`, including what was not covered.

## Web and API AppSec / web-api

Order: review authentication, object- and function-level authorization, sessions, validation, injection, SSRF, traversal, file upload, XSS, CSRF, CORS, caching, rate limits, error handling, deserialization, GraphQL/WebSocket and business logic. Follow data from controllable inputs through to sensitive operations. Use minimal local tests.

Start from `knowledge/web-api.md` §0, which lists the classes tooling does not see — broken object-level authorization, business logic, deserialization, input validation, race conditions, mass assignment — because those are the ones that require reading code rather than running a scanner. XSS and client-side sinks, CSRF/CORS/caching, business logic, cryptography, GraphQL/WebSocket and error handling live in the second file, `knowledge/web-api-clientside-logic.md`.

## Mobile and APK / mobile

Order: review manifest and entitlements, exported components, permissions, deep links, WebViews, storage, logs, backups, TLS, network configuration, cryptography, embedded secrets, native libraries and backend communication. Always distinguish a compiled APK from its source: state what can and cannot be asserted from each. Do not attack discovered endpoints without specific authorization.

Two hard rules from `knowledge/mobile.md`: obfuscation never substitutes for a server-side control, and a secret shipped inside the app is compromised by definition — the finding is that the secret exists, not that it could be hidden better. The iOS-specific procedures are in `knowledge/mobile-ios.md`.

## Infrastructure and cloud / infra-cloud

Order: review IaC, Docker, Kubernetes, permissions, network exposure, identity, secrets, encryption, isolation, images, defaults, observability and environment separation. Do not apply changes to remote accounts or clusters; propose local patches unless explicitly authorized.

## Supply chain and secrets / supply-chain

Order: review manifests and locks, provenance, install scripts, CI actions, workflow permissions, version pinning, publishing, typosquatting and tracked secrets. Verify reachability and context before escalating a dependency vulnerability. Redact sensitive values.

The triage section (§7) of `knowledge/supply-chain.md` is mandatory before reporting any dependency finding: presence of a vulnerable version is not exploitability, and a finding without evidence that the vulnerable symbol is imported or called drops to informational. Secret scanning and malicious-package indicators are in the second file, `knowledge/supply-chain-secrets-malware.md`; §8 there applies to every repository.

## AI, agents and chatbots / ai-safety

Order: review the boundary between instructions, content and tools; direct and indirect prompt injection; tool authorization; cross-user leakage; retrieval; memory; isolation; output handling; SSRF through tools; resource consumption; and sensitive logging. Test with synthetic data and without triggering real external actions.

Run `AI-01` (the lethal trifecta check) first on every agent in scope. It is the cheapest procedure with the highest yield and it frames everything else.

## Privacy and abuse / privacy-abuse

Order: map personal data, retention, consent, minimization, access controls, multitenancy, export, deletion, telemetry and product abuse paths. Always separate a technical vulnerability from a privacy risk from a product decision. Describe the technical fact and the obligation it may touch; never rule on legal compliance.

## Local applications / local-app

Order: review command-line tools, desktop shells, published libraries, installers and local daemons — path handling and archive extraction, symlink following, temporary files and races, argument injection, search-path resolution, configuration discovered from the working directory, file permissions, privileged helpers, insecure library defaults, renderer isolation and protocol handlers, local IPC and loopback listeners, runtime code loading, and secrets at rest.

`knowledge/local-app.md` §0 is mandatory and is what separates this role from the rest: on a local surface there is no anonymous internet attacker, so every finding names the second principal and the boundary crossed — another local user, a hostile input file, a hostile working directory, a web origin reaching a listener, or the consumer of a library. A finding that cannot name one is a hardening note, not a vulnerability. Tests create files only inside a temporary directory the specialist made for the run: a symlink or race test pointed at a real path is destruction, not evidence.

## Remediator / remediator

Order: accept only `confirmed` and authorized findings; a `probable` one goes back to the leader with the missing link named. Apply the minimum patch that removes the root cause, add a regression test that fails without the patch, keep reasonable compatibility, and document behaviour changes. Do not deploy or alter external systems.

## Verifier / verifier

**In `audit` mode you also run, under `VER-09`, and you run BLIND to the finder's prose.** You are handed each assertion and its location - not the evidence narrative, not the impact narrative - and you decide against the code. If you cannot point at the line that makes an assertion false, it stands.


**In `audit` mode you run too, under `VER-09`.** There is no patch and no fix to check: you are handed the finished list of `confirmed` and `probable` findings and your only job is to kill them. Attack first, concede last. A finding you kill goes to `ruled_out` with the line you relied on, never quietly out of the report. A finding you cannot decide inside the scope is `probable` with `what_would_settle_it`, never a polite pass.

This exists because it was measured missing: three arms on one target, every claim attacked twice by independent verifiers, and a competing product carrying this stage refuted 53% of its own claims where this corpus refuted 62% and unaided review 68%. The adversarial posture was already written; nothing invoked it when there was no patch.
Order: work from the finding and the diff, not from the remediator's conclusion. Reproduce the original case and its variants, run relevant tests, hunt for bypasses and regressions, and give every result one verification outcome from `vocabulary.md`. A check that could not settle the question is `inconclusive`, `not executed` or `blocked` according to why — never a soft version of `verified`. Do not edit unless the leader explicitly reassigns you.

## Dispatching without the plugin subagents

If the skill was copied into `~/.claude/skills/` or `.claude/skills/` rather than installed as a plugin, the subagents above do not exist. Use `general-purpose` and copy into the prompt, explicitly (a subagent inherits neither this skill nor its context): scope and exact path; mode; target language; the role order from `references/team.md`; the path of the role's knowledge pack so the subagent reads it itself; the relevant rows of `references/coverage.md`; the full safety contract above; the return format from `references/team.md`; and in `audit` mode, the flat instruction not to edit any file. Use `general-purpose` for every role in this mode. If you happen to have your own equivalent specialist agents installed, they work too, but do not assume any particular agent exists.

Never let the same agent both fix and verify.

## Return format to the leader

For each finding. The three verdict fields are closed lists from [vocabulary.md](vocabulary.md); the rest is free text.

- `ID and title`
- `procedure`: the pack procedure ID that produced it (`WEB-07`, `AI-01`, ...), or `ad-hoc` if none applies

<!-- vocabulary:use status -->
- status: `confirmed` | `probable` | `hardening` | `discarded` | `withdrawn`
<!-- /vocabulary:use -->
<!-- vocabulary:use severity -->
- severity: `critical` | `high` | `medium` | `low` | `informational`
<!-- /vocabulary:use -->
<!-- vocabulary:use confidence -->
- confidence: `high` | `medium` | `low`
<!-- /vocabulary:use -->

  A `candidate` is what you have before triage, and it is never returned as a finding. `confirmed` requires demonstrated impact and `confidence: high`; if one link is inferred, the status is `probable` and you name the link.

- `location`: file and line, component or artifact
- `evidence`: minimal trace or reproduction, no secrets
- `impact and preconditions`
- `recommended fix`
- `proposed verification`
- `traceability`: standard identifiers, verbatim and untranslated
- `triage`: every rule from `references/triage.md` that the procedure invokes, with its answer — `HOLDS`, `DOES_NOT_HOLD`, `UNKNOWN` or `NOT_APPLICABLE` — and a reason naming the artifact whenever the answer is not `DOES_NOT_HOLD`. A finding returned as `confirmed` has every invoked rule answered, none `HOLDS` and none `UNKNOWN`; an unanswered rule is not a silent pass, exactly as exit code `2` is not a green gate.
- `limits or open questions`

The leader assembles these returns into `findings.json` as specified in `references/findings-artifact.md`, and validates it before anything is delivered. A specialist returns prose; the artifact is the leader's job, because only the leader has deduplicated across specialists.

At the end of the run, each specialist also returns a **coverage declaration**: which sections of its pack it exercised, which it skipped, and why. The leader needs it to write an honest coverage section; a specialist that omits it has not finished.
