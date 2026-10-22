# Role orders, for dispatching without the plugin's subagents

Load this file **only** when the plugin's own subagents are not available — the skill was copied into `~/.claude/skills/` or `.claude/skills/` instead of installed as a plugin — and you dispatch `general-purpose` agents. A plugin subagent carries its role order, its safety contract and its pack in its own definition; pasting this file into its prompt adds tokens and nothing else.

Each section below is the role order to paste into a `general-purpose` prompt, together with the constraints listed under *Dispatching without the plugin subagents* at the end of this file.

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

If the skill was copied into `~/.claude/skills/` or `.claude/skills/` rather than installed as a plugin, the subagents listed in `team.md` do not exist. Use `general-purpose` and copy into the prompt, explicitly (a subagent inherits neither this skill nor its context): scope and exact path; mode; target language; the role order from this file; the path of the role's knowledge pack so the subagent reads it itself; the relevant rows of `references/coverage.md`; the full safety contract of `SKILL.md`; the return format from `references/team.md`; and in `audit` mode, the flat instruction not to edit any file. Use `general-purpose` for every role in this mode. If you happen to have your own equivalent specialist agents installed, they work too, but do not assume any particular agent exists.

Never let the same agent both fix and verify.
