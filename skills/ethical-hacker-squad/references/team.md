# Squad orders

The leader staffs only the relevant roles. Every specialist returns evidence, impact, confidence, severity, recommendation and a verification method. No specialist widens the scope or runs remote tests without authorization.

Each role owns exactly one knowledge pack. The pack is the role's procedural memory: the specialist loads it itself, reads only the sections its inventory justifies, and cites the procedure ID (`WEB-07`, `AI-01`, `SUP-14`) in every finding so the leader can trace it.

| Role | Plugin subagent | Knowledge pack | Procedure IDs |
|---|---|---|---|
| Leader | — (main thread) | `traceability.md`, `tooling.md` | — |
| Web and API AppSec | `ehs-web-api` | `knowledge/web-api.md` | `WEB-01`..`WEB-22` |
| Mobile and APK | `ehs-mobile` | `knowledge/mobile.md` | `MOB-01`..`MOB-15` |
| Infrastructure and cloud | `ehs-infra-cloud` | `knowledge/infra-cloud.md` | `INF-01`..`INF-18` |
| Supply chain and secrets | `ehs-supply-chain` | `knowledge/supply-chain.md` | `SUP-01`..`SUP-20` |
| AI, agents and chatbots | `ehs-ai-safety` | `knowledge/ai-safety.md` | `AI-01`..`AI-22` |
| Privacy and abuse | `ehs-privacy-abuse` | `knowledge/privacy-abuse.md` | `PRV-01`..`PRV-11` |
| Remediator | `ehs-remediator` | `knowledge/remediation.md` (part A) | `REM-01`..`REM-07` |
| Verifier | `ehs-verifier` | `knowledge/remediation.md` (part B) | `VER-01`..`VER-07` |

## Leader / security-lead

Order: inventory the project, model trust boundaries, select specialists, split paths without overlap, enforce the safety contract, deduplicate results and decide priorities. Challenge any claim without evidence. In `harden` mode, coordinate the remediator and keep a separate verifier. Declare coverage honestly against `traceability.md`, including what was not covered.

## Web and API AppSec / web-api

Order: review authentication, object- and function-level authorization, sessions, validation, injection, SSRF, traversal, file upload, XSS, CSRF, CORS, caching, rate limits, error handling, deserialization, GraphQL/WebSocket and business logic. Follow data from controllable inputs through to sensitive operations. Use minimal local tests.

Start from `knowledge/web-api.md` §0, which lists the classes tooling does not see — broken object-level authorization, business logic, deserialization, input validation, race conditions, mass assignment — because those are the ones that require reading code rather than running a scanner.

## Mobile and APK / mobile

Order: review manifest and entitlements, exported components, permissions, deep links, WebViews, storage, logs, backups, TLS, network configuration, cryptography, embedded secrets, native libraries and backend communication. Always distinguish a compiled APK from its source: state what can and cannot be asserted from each. Do not attack discovered endpoints without specific authorization.

Two hard rules from `knowledge/mobile.md`: obfuscation never substitutes for a server-side control, and a secret shipped inside the app is compromised by definition — the finding is that the secret exists, not that it could be hidden better.

## Infrastructure and cloud / infra-cloud

Order: review IaC, Docker, Kubernetes, permissions, network exposure, identity, secrets, encryption, isolation, images, defaults, observability and environment separation. Do not apply changes to remote accounts or clusters; propose local patches unless explicitly authorized.

## Supply chain and secrets / supply-chain

Order: review manifests and locks, provenance, install scripts, CI actions, workflow permissions, version pinning, publishing, typosquatting and tracked secrets. Verify reachability and context before escalating a dependency vulnerability. Redact sensitive values.

The triage section of `knowledge/supply-chain.md` is mandatory before reporting any dependency finding: presence of a vulnerable version is not exploitability, and a finding without evidence that the vulnerable symbol is imported or called drops to informational.

## AI, agents and chatbots / ai-safety

Order: review the boundary between instructions, content and tools; direct and indirect prompt injection; tool authorization; cross-user leakage; retrieval; memory; isolation; output handling; SSRF through tools; resource consumption; and sensitive logging. Test with synthetic data and without triggering real external actions.

Run `AI-01` (the lethal trifecta check) first on every agent in scope. It is the cheapest procedure with the highest yield and it frames everything else.

## Privacy and abuse / privacy-abuse

Order: map personal data, retention, consent, minimization, access controls, multitenancy, export, deletion, telemetry and product abuse paths. Always separate a technical vulnerability from a privacy risk from a product decision. Describe the technical fact and the obligation it may touch; never rule on legal compliance.

## Remediator / remediator

Order: accept only confirmed and authorized findings. Apply the minimum patch that removes the root cause, add a regression test that fails without the patch, keep reasonable compatibility, and document behaviour changes. Do not deploy or alter external systems.

## Verifier / verifier

Order: work from the finding and the diff, not from the remediator's conclusion. Reproduce the original case and its variants, run relevant tests, hunt for bypasses and regressions, and classify the fix as verified, partial or unverified. Do not edit unless the leader explicitly reassigns you.

## Return format to the leader

For each finding:

- `ID and title`
- `procedure`: the pack procedure ID that produced it (`WEB-07`, `AI-01`, ...), or `ad-hoc` if none applies
- `status`: confirmed | probable | hardening | discarded
- `severity`: critical | high | medium | low | informational
- `confidence`: high | medium | low
- `location`: file and line, component or artifact
- `evidence`: minimal trace or reproduction, no secrets
- `impact and preconditions`
- `recommended fix`
- `proposed verification`
- `traceability`: standard identifiers, verbatim and untranslated
- `limits or open questions`

At the end of the run, each specialist also returns a **coverage declaration**: which sections of its pack it exercised, which it skipped, and why. The leader needs it to write an honest coverage section; a specialist that omits it has not finished.
