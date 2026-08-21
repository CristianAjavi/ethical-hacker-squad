# Knowledge corpus — loading map

Eight packs, one per role, spread over seventeen files, 4,106 lines in total, 160 numbered procedures. **Never load all of them.** A pack you did not staff a role for is pure context cost, and a loaded pack that does not match the inventory produces confident findings about code that is not there.

## Loading rules

1. The **leader does not read the packs**. It reads `coverage.md` to decide who to staff, and `traceability.md` and `tooling.md` to integrate results.
2. The **specialist reads its own pack**, and only the sections its inventory justifies. Every pack opens with a selective-loading index for exactly this.
3. One role, one pack. A specialist that needs another pack's procedure is a sign the leader split the work wrong; report it instead of reading across.
4. `remediation.md` is the exception: it is shared by two roles, part A for the remediator and part B for the verifier. Each reads its own part.
5. Five packs ship as **more than one file**, because a single file above 32 KiB stops being selectively loadable and blows the plugin size budget. The files of a pack are one pack: same role, same procedure numbering, disjoint sections. The first file is the entry point and names its siblings in its header; open a sibling only when the inventory reaches its sections. `mobile` ships as three (`mobile.md`, `mobile-runtime-trust.md`, `mobile-ios.md`), and so do `supply-chain` (`supply-chain.md`, `supply-chain-secrets-malware.md`, `supply-chain-source-lifecycle.md`), `ai-safety` (`ai-safety.md`, `ai-safety-data-output.md`, `ai-safety-agent-runtime.md`) and `infra-cloud` (`infra-cloud.md`, `infra-cloud-cicd-exposure.md`, `infra-cloud-cicd-platforms.md`).

## The packs

| Pack file | Role | Lines | Procedures | Load when the inventory has |
|---|---|---|---|---|
| `web-api.md` | `ehs-web-api` | ~303 | `WEB-01`..`WEB-12` | HTTP routes, controllers, sessions and tokens, ORM and raw SQL, outbound fetch, uploads and deserialization |
| `web-api-clientside-logic.md` | `ehs-web-api` | ~271 | `WEB-13`..`WEB-23` | Browser-rendered output, `Access-Control-*` and caching, payment or quota flows, crypto and secrets, GraphQL, WebSocket, error and log output |
| `mobile.md` | `ehs-mobile` | ~313 | `MOB-01`..`MOB-12` | `AndroidManifest.xml`, `.apk`, `.aab`, Kotlin/Java app sources |
| `mobile-runtime-trust.md` | `ehs-mobile` | ~119 | `MOB-13`, `MOB-16`..`MOB-18` | A screen that authorizes an effect, biometric or PIN unlock, CodePush/Expo/live updates, a backend whose only client is the app |
| `mobile-ios.md` | `ehs-mobile` | ~59 | `MOB-14`..`MOB-15` | `Info.plist`, `.xcodeproj`, entitlements, `.ipa`, Swift/Objective-C sources |
| `infra-cloud.md` | `ehs-infra-cloud` | ~287 | `INF-01`..`INF-12` | Terraform and other IaC, Dockerfiles and images, Kubernetes manifests, Helm |
| `infra-cloud-cicd-exposure.md` | `ehs-infra-cloud` | ~151 | `INF-13`..`INF-18` | CI workflows, several deployment environments, Terraform state, a live host or cluster in scope |
| `infra-cloud-cicd-platforms.md` | `ehs-infra-cloud` | ~146 | `INF-19`..`INF-23` | `.gitlab-ci.yml`, a `Jenkinsfile`, `azure-pipelines.yml`, `.circleci/config.yml` or `bitbucket-pipelines.yml` |
| `supply-chain.md` | `ehs-supply-chain` | ~333 | `SUP-01`..`SUP-15` | Any manifest or lockfile, any publishing pipeline, any SCA output to triage |
| `supply-chain-secrets-malware.md` | `ehs-supply-chain` | ~117 | `SUP-16`..`SUP-20` | Any git repository, a recently added dependency, a suspected incident |
| `supply-chain-source-lifecycle.md` | `ehs-supply-chain` | ~141 | `SUP-21`..`SUP-25` | A repository whose releases you audit, any signature-verification command, binaries tracked in the tree, any runtime or engine version, any suppression or VEX file |
| `ai-safety.md` | `ehs-ai-safety` | ~308 | `AI-01`..`AI-11` | LLM API calls, agent frameworks, tool dispatchers, MCP servers or config |
| `ai-safety-data-output.md` | `ehs-ai-safety` | ~350 | `AI-12`..`AI-24` | Vector stores, agent memory, model output reaching a sink, system prompts with rules or credentials, agentic loops |
| `ai-safety-agent-runtime.md` | `ehs-ai-safety` | ~136 | `AI-25`..`AI-28` | An installable agent package (skill, plugin, MCP server), an agent that can write to its own configuration, several agents handing work to each other, or an action that must be attributable |
| `privacy-abuse.md` | `ehs-privacy-abuse` | ~354 | `PRV-01`..`PRV-13` | Personal data in models or events, third-party SDKs, telemetry, user data reaching a model, who reads personal records |
| `local-app.md` | `ehs-local-app` | ~321 | `LOC-01`..`LOC-15` | A command-line tool, a desktop or WebView shell, a published library or SDK, an installer or updater, a local daemon or a loopback listener |
| `remediation.md` | `ehs-remediator`, `ehs-verifier` | ~397 | `REM-01`..`REM-07`, `VER-01`..`VER-08` | `harden` or `verify` mode |

## Procedure anatomy

Every procedure carries the same six fields, and each has a job:

- **Where to look** — paths, globs and symbols per stack. Turns a class of bug into a search.
- **Vulnerable pattern** — the construct that makes it exploitable, with a minimal illustrative snippet. Not every occurrence of the symbol is a bug; this field says which one is.
- **What rules it out (false positive)** — the compensating controls that drop it to informational. **Not optional.** A finding reported without working through this field has not been triaged.
- **Minimal test** — how to demonstrate impact locally and non-destructively. Anything touching a remote target is marked `REQUIRES AUTHORIZATION`.
- **Traceability** — standard identifiers, verbatim and untranslated, per the citation policy in `traceability.md`.
- **Tooling** — the command, and explicitly what its output does not prove.

The two highest-yield entry points are `web-api.md` §0, which lists the classes scanners systematically miss, and `ai-safety.md` `AI-01`, the lethal-trifecta check.

## Provenance and maintenance

Every factual claim in the corpus — a standard version, a measured percentage, an incident — carries its source. The corpus is to be refreshed by an automated loop specified in `docs/knowledge-loop.md` (not yet running), which may only draw from the source allowlist in `docs/sources-allowlist.json`, must attach provenance to every item it changes, and can never modify the safety contract, the plugin manifest, the allowlist or the workflows.

Two consequences you should carry into any edit: **no item without a citation**, and **no text copied verbatim from a copyleft or proprietary source**. Both are enforced in CI, not left to good intentions.
