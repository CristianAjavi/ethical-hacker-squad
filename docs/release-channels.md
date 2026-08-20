# Release channels, versioning and distribution

How a user gets this plugin, how they get updates, and why the branches are arranged the way they are.

> **Status.** This is a specification. The automation it describes has not landed yet: there is no `stable` branch, no tagged release and no promotion pipeline. What does run today is the deterministic gate set `G1`–`G4` on every push and pull request; see the status table in `docs/gate-requirements.md`. Read the rest as the contract the machinery is built to satisfy, not as a description of controls already running. See `docs/design-decisions.md`.

## For the user

Install:

```
/plugin marketplace add CristianAjavi/ethical-hacker-squad
/plugin install ethical-hacker-squad@ethical-hacker-squad
```

Update:

```
/plugin marketplace update ethical-hacker-squad
/plugin update ethical-hacker-squad
```

Claude Code also refreshes marketplaces in the background after startup, so in practice an installed plugin picks up new versions without being asked. This repository is public, so updates involve no credentials.

## Two channels

| Channel | Branch | Version resolves to | Who it is for |
|---|---|---|---|
| `latest` | `main` | the commit SHA | anyone who wants corrections as they land |
| `stable` | `stable` | a semver in the marketplace entry | anyone who prefers a reviewed, rested snapshot |

A consumer who wants to pin harder can add the marketplace at a specific `ref` or `sha` and stop receiving updates entirely.

## The versioning bug this design fixes

Claude Code resolves a plugin's version in this order: `version` in `plugin.json`, then `version` in the marketplace entry, then the commit SHA.

The original `plugin.json` declared `"version": "1.0.0"` as a fixed string. That is a silent trap: pushing new commits changes nothing for anyone who already installed the plugin, because the resolved version stays `1.0.0` and the cached copy is considered current. The knowledge corpus could be corrected weekly and no user would ever receive it.

The fix has two parts:

1. **`plugin.json` on `main` declares no `version` field at all**, so every commit resolves to a distinct SHA and `latest` genuinely updates.
2. **The semver lives only in the marketplace entry on the `stable` branch.** Declaring a version in both files is documented as unsafe — `plugin.json` wins silently — so it is declared in exactly one place.

The channels must also resolve to *different* versions, or Claude Code treats them as the same plugin and skips the update. A rolling SHA on one side and a semver on the other satisfies that by construction.

A side effect worth knowing: because `main` never sets a version, merging `main` into `stable` never conflicts on that line. The promotion commit is the only thing that touches it.

## Promotion to `stable`

Promotion is automated. The design intent is that **no step waits on a human being available**, while still refusing to promote anything that has not survived scrutiny.

A change reaches `stable` only when all of the following hold:

1. **Deterministic gates are green** on `main` — see `docs/gate-requirements.md`. No language model participates in this step.
2. **An independent verifier passed it.** A second agent, distinct from whichever agent proposed the change, with no web access, whose only input is the diff. Its job is to find lines that are instructions disguised as knowledge, and claims with no source. It cannot approve its own work because it never wrote any.
3. **A rest period of about seven days has elapsed** since the change landed on `main`, with gates still green and no open issue disputing it. Time is doing real work here: it is the window in which a user of `latest` notices a wrong procedure and opens an issue, and it is the cheapest reviewer available.
4. The promotion bumps the semver, updates `CHANGELOG.md`, and tags the release.

### Kill switch and rollback

- **Kill switch:** disable the scheduled workflows. Nothing else is required — every automated path runs on `schedule` or `workflow_dispatch` only, so with the schedule off, nothing moves. `latest` freezes at its current commit and `stable` stays where it is.
- **Rollback:** point `stable` back at the previous release tag in one command and let the marketplace resolve the older semver. Consumers pinned to `stable` return to the previous snapshot on their next refresh; consumers on `latest` are unaffected.

### Residual risk, unvarnished

Automated promotion means a bad change can reach `stable` without a human ever having read it. The gates catch structural damage, licence contamination and missing provenance; the verifier catches injected instructions and unsourced claims; the rest period catches whatever users notice. None of that catches a **plausible, well-cited, correctly formatted procedure that is simply wrong** — a detection pattern that does not match real code, a false-positive criterion that discards true findings, a standard identifier that is real but mismapped.

That class of error will reach users. The mitigations are the `false-positive` and `false-negative` issue types, which exist precisely to collect it, and the closure doctrine that turns each report into a check. The honest statement is that this system converges on correctness through use, rather than guaranteeing it before release. Anyone who needs a guarantee before release should pin to a `sha` and review it themselves.

## What is deliberately not automated

Changing the safety contract in `SKILL.md`, the plugin manifest, the workflows, the source allowlist, the licence or the `NOTICE`. Those paths are protected: a bot pull request touching them fails CI by design. They define what the system is allowed to do, and a system that can rewrite its own limits has none.
