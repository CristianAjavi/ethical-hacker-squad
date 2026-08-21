# Knowledge corpus — loading map

Eight packs, one per role, 3,040 lines in total, 137 numbered procedures. **Never load all of them.** A pack you did not staff a role for is pure context cost, and a loaded pack that does not match the inventory produces confident findings about code that is not there.

## Loading rules

1. The **leader does not read the packs**. It reads `coverage.md` to decide who to staff, and `traceability.md` and `tooling.md` to integrate results.
2. The **specialist reads its own pack**, and only the sections its inventory justifies. Every pack opens with a selective-loading index for exactly this.
3. One role, one pack. A specialist that needs another pack's procedure is a sign the leader split the work wrong; report it instead of reading across.
4. `remediation.md` is the exception: it is shared by two roles, part A for the remediator and part B for the verifier. Each reads its own part.

## The packs

| Pack | Role | Lines | Procedures | Load when the inventory has |
|---|---|---|---|---|
| `web-api.md` | `ehs-web-api` | ~484 | `WEB-01`..`WEB-22` | HTTP routes, controllers, ORM, templates, browser-rendered output, GraphQL, WebSocket |
| `mobile.md` | `ehs-mobile` | ~347 | `MOB-01`..`MOB-15` | `AndroidManifest.xml`, `.apk`, `.aab`, `Info.plist`, `.ipa`, Swift/Kotlin app sources |
| `infra-cloud.md` | `ehs-infra-cloud` | ~387 | `INF-01`..`INF-18` | Terraform, Dockerfile, Kubernetes manifests, Helm, CI workflows, environment config |
| `supply-chain.md` | `ehs-supply-chain` | ~394 | `SUP-01`..`SUP-20` | Any manifest or lockfile, any git repository, any publishing pipeline |
| `ai-safety.md` | `ehs-ai-safety` | ~543 | `AI-01`..`AI-22` | LLM API calls, agent frameworks, MCP servers or config, vector stores, agent memory |
| `privacy-abuse.md` | `ehs-privacy-abuse` | ~268 | `PRV-01`..`PRV-11` | Personal data in models or events, third-party SDKs, telemetry, user data reaching a model |
| `local-app.md` | `ehs-local-app` | ~291 | `LOC-01`..`LOC-15` | A CLI, a desktop app or WebView shell, a published library, an installer or updater, a local daemon or loopback listener |
| `remediation.md` | `ehs-remediator`, `ehs-verifier` | ~326 | `REM-01`..`REM-07`, `VER-01`..`VER-07` | `harden` or `verify` mode |

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

Two consequences you should carry into any edit: **no item without a citation**, and **no text copied verbatim from a copyleft or proprietary source**. The first is enforced in CI by `G4`, which also rejects an identifier that matches no known family. The second is still a review rule: `G5` is specified and not yet running.
