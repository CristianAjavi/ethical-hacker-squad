# Report format

This file is a reference consumed by the skill: it defines the shape of the deliverable the squad leader produces.

## Language

Write the report in the language the user is using. Every label below describes what a section must contain, not a heading to copy verbatim: translate the headings, keep the content.

Never translate: standard identifiers (`WSTG-INPV-05`, `ASVS 5.0 V8`, `CWE-89`, `A01:2025`, `API1:2023`, `LLM01:2026`, `ASI06`, `MASVS-STORAGE-1`, `MASTG-TEST-0001`, `CAPEC-66`, `CICD-SEC-4`, `SSDF PW`, `SLSA Build L2`), procedure IDs from the packs (`WEB-07`, `AI-01`, `SUP-14`), tool names, command lines, file paths, code symbols, and CVE identifiers.

## Executive summary

State scope, mode, components reviewed, overall result and the most important risks. Avoid absolute guarantees. If nothing significant was found, say the review found nothing significant **at the depth reached** - not that the system is secure.

## Scope and methodology

Record:

- folder, repository, artifact or authorized endpoint;
- commit or version when available;
- techniques and tools used, with the exact invocation;
- active tests actually performed, and against what;
- exclusions and limitations.

## Findings

Order by severity, then by confidence. For each finding:

1. ID and title.
2. Status, severity and confidence.
3. Precise location.
4. Minimal redacted evidence.
5. Impact scenario and preconditions.
6. Root cause.
7. Recommended or applied fix.
8. Verification status.
9. Traceability: the pack procedure ID it came from, plus the standard identifiers it maps to.

Do not pad with generic recommendations. Keep discarded candidates only as a short note, and only when it saves someone repeating the work.

Severity is a judgement about **this** system, not a copy of a scanner label. A dependency advisory rated critical whose vulnerable symbol is never reached is not a critical finding here; say so and explain why, rather than inheriting the number.

## Coverage declaration

Mandatory. This is what separates an honest report from a reassuring one. Using `traceability.md`, state:

- which standard families were exercised, at the granularity you can defend - for example, session management and authorization were covered, weak cryptography was not;
- which pack sections each specialist opened, and which it skipped;
- which surfaces present in the inventory had no matching pack;
- which checks were impossible in this environment.

Claiming coverage you did not exercise is worse than declaring a gap. A reader who knows what was not looked at can act on it; a reader who believes everything was looked at cannot.

## Changes made

In `harden` mode, list modified files, the objective of each change, and any relevant compatibility impact. Separate rotations, deployments or operations that still require the user to act, and say plainly that they have **not** been done.

## Verification

List the commands or tests executed and their result. Distinguish clearly:

- verified;
- partially verified;
- not executed;
- blocked by authorization or environment.

"Tests pass" is not the same as "the vulnerability no longer reproduces". State which one you actually established. A clean static-analysis run belongs here as a fact about the tool, never as evidence that a class of bug is absent.

## Residual risk and next steps

Prioritize concrete actions. Point out unreviewed surfaces, environment dependencies, and remote tests that need further authorization. Where a fix was deliberately not applied, record the reason and who has to decide.
