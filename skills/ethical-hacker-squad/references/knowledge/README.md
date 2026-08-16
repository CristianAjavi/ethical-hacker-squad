# Knowledge corpus — loading map

Seven packs, one per role, spread over twelve files, 2,830 lines in total, 122 numbered procedures. **Never load all of them.** A pack you did not staff a role for is pure context cost, and a loaded pack that does not match the inventory produces confident findings about code that is not there.

## Loading rules

1. The **leader does not read the packs**. It reads `coverage.md` to decide who to staff, and `traceability.md` and `tooling.md` to integrate results.
2. The **specialist reads its own pack**, and only the sections its inventory justifies. Every pack opens with a selective-loading index for exactly this.
3. One role, one pack. A specialist that needs another pack's procedure is a sign the leader split the work wrong; report it instead of reading across.
4. `remediation.md` is the exception: it is shared by two roles, part A for the remediator and part B for the verifier. Each reads its own part.
5. Five packs ship as **two files each**, because a single file above 32 KiB stops being selectively loadable and blows the plugin size budget. The two files of a pack are one pack: same role, same procedure numbering, disjoint sections. The first file is the entry point and names its sibling in its header; open the sibling only when the inventory reaches its sections.

## The packs

| Pack file | Role | Lines | Procedures | Load when the inventory has |
|---|---|---|---|---|
| `web-api.md` | `ehs-web-api` | ~280 | `WEB-01`..`WEB-12` | HTTP routes, controllers, sessions and tokens, ORM and raw SQL, outbound fetch, uploads and deserialization |
| `web-api-clientside-logic.md` | `ehs-web-api` | ~220 | `WEB-13`..`WEB-22` | Browser-rendered output, `Access-Control-*` and caching, payment or quota flows, crypto and secrets, GraphQL, WebSocket, error and log output |
| `mobile.md` | `ehs-mobile` | ~310 | `MOB-01`..`MOB-13` | `AndroidManifest.xml`, `.apk`, `.aab`, Kotlin/Java app sources, a backend whose only client is the app |
| `mobile-ios.md` | `ehs-mobile` | ~55 | `MOB-14`..`MOB-15` | `Info.plist`, `.xcodeproj`, entitlements, `.ipa`, Swift/Objective-C sources |
| `infra-cloud.md` | `ehs-infra-cloud` | ~265 | `INF-01`..`INF-12` | Terraform and other IaC, Dockerfiles and images, Kubernetes manifests, Helm |
| `infra-cloud-cicd-exposure.md` | `ehs-infra-cloud` | ~140 | `INF-13`..`INF-18` | CI workflows, several deployment environments, Terraform state, a live host or cluster in scope |
| `supply-chain.md` | `ehs-supply-chain` | ~300 | `SUP-01`..`SUP-15` | Any manifest or lockfile, any publishing pipeline, any SCA output to triage |
| `supply-chain-secrets-malware.md` | `ehs-supply-chain` | ~105 | `SUP-16`..`SUP-20` | Any git repository, a recently added dependency, a suspected incident |
| `ai-safety.md` | `ehs-ai-safety` | ~285 | `AI-01`..`AI-11` | LLM API calls, agent frameworks, tool dispatchers, MCP servers or config |
| `ai-safety-data-output.md` | `ehs-ai-safety` | ~275 | `AI-12`..`AI-22` | Vector stores, agent memory, model output reaching a sink, system prompts with rules or credentials, agentic loops |
| `privacy-abuse.md` | `ehs-privacy-abuse` | ~270 | `PRV-01`..`PRV-11` | Personal data in models or events, third-party SDKs, telemetry, user data reaching a model |
| `remediation.md` | `ehs-remediator`, `ehs-verifier` | ~325 | `REM-01`..`REM-07`, `VER-01`..`VER-07` | `harden` or `verify` mode |

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
