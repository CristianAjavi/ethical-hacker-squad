# NOTICE — attributions and third-party licences

This repository is licensed under the MIT License (see `LICENSE`). It contains **no text copied from any third-party source.** Every procedure, description and recommendation is original writing.

What it does contain are **references**: identifiers, version numbers, test names, publication dates and measured figures, each attributed to the work it comes from. Identifiers and facts are not copyrightable expression; the wording around them here is ours.

If you fork, extend or redistribute this repository, keep this file.

---

## MITRE — attribution required

This work cites identifiers from MITRE CWE, MITRE ATT&CK, MITRE CAPEC and MITRE ATLAS. MITRE grants a non-exclusive, royalty-free licence to use these for research, development and commercial purposes, conditioned on reproducing its copyright designation. Accordingly:

> © 2026 The MITRE Corporation. This work is reproduced and distributed with the permission of The MITRE Corporation.

ATT&CK®, CWE™, CAPEC™ and ATLAS™ are trademarks of The MITRE Corporation.

---

## OWASP — CC BY-SA 4.0, cited by identifier only

The following are licensed **CC BY-SA 4.0**, a copyleft licence whose ShareAlike term is incompatible with redistributing derived text under MIT alone. This repository therefore cites their **identifiers and version numbers** and describes their concepts in original wording. No OWASP text is reproduced.

| Work | Version cited | Canonical URL |
|---|---|---|
| Web Security Testing Guide (WSTG) | v4.2 (2020-12-03) | <https://owasp.org/www-project-web-security-testing-guide/> |
| Application Security Verification Standard (ASVS) | 5.0.0 (2025-05-30) | <https://owasp.org/www-project-application-security-verification-standard/> |
| Mobile Application Security Verification Standard (MASVS) | 2.1.0 (2024-01-18) | <https://mas.owasp.org/MASVS/> |
| Mobile Application Security Testing Guide (MASTG) | 2.0.0 (2026-06-30) | <https://mas.owasp.org/MASTG/> |
| OWASP Top 10 | 2025 | <https://owasp.org/Top10/2025/> |
| API Security Top 10 | 2023 | <https://owasp.org/www-project-api-security/> |
| Top 10 for LLM Applications | 2026 (2026-08-03) | <https://genai.owasp.org/> |
| Top 10 for Agentic Applications | 2026 (v2.01) | <https://genai.owasp.org/> |
| Agentic Skills Top 10 (`AST01`..`AST10`) | v1.0 | <https://owasp.org/www-project-agentic-skills-top-10/> |
| Top 10 CI/CD Security Risks | current | <https://owasp.org/www-project-top-10-ci-cd-security-risks/> |
| Cheat Sheet Series | — | <https://cheatsheetseries.owasp.org> |
| SAMM | 2.x (core v2.2.0) | <https://owaspsamm.org/> |

The Cheat Sheet Series is cited by sheet name and site URL, as its maintainers request, rather than by repository file path.

---

## NIST — US Government works

NIST SP 800-115, SP 800-218 (SSDF v1.1), SP 800-218A, SP 800-53 Rev. 5, AI 100-1 (AI RMF 1.0), AI 600-1 and AI 100-2e2025 are works of the United States Government and are not subject to copyright protection within the United States; foreign rights are reserved. Republished courtesy of the National Institute of Standards and Technology.

---

## SLSA

Cited at v1.2 (2025-11-24). SLSA content is governed by the Community Specification License 1.0 for contributions made under that governance model, and Apache-2.0 for earlier portions. It is **not** Creative Commons. <https://slsa.dev/spec/v1.2/>

---

## Cited under stricter terms — identifiers only, no text

| Work | Licence / terms | How it is used here |
|---|---|---|
| **CIS Benchmarks** | CC BY-NC-SA 4.0; CIS prohibits hosting a Benchmark in any format on a non-CIS site and directs citation questions to CIS Legal | Existence of a benchmark for a technology is mentioned. No recommendation text, audit step or remediation step is reproduced. Numeric recommendation IDs are avoided. |
| **CIS Controls v8.1** | CC BY-NC-**ND** 4.0 — no derivatives | Cited as `CIS v8.1 Control N`, at control level, with criteria written in our own words. |
| **Cloud Security Alliance** (CCM v4.1, Top Threats) | May be used, copied, printed or linked; may not be modified or translated without prior written CSA consent | Cited by domain prefix (`CCM IAM`). No control text reproduced. |
| **OSSTMM 3.02** | CC BY-NC-ND + Open Methodology License 3.0; no derivatives, and packaging its content into a sold tool or checklist requires explicit ISECOM permission | Referenced as a historical methodology only. No content incorporated. |
| **PTES** | Licence intent unconfirmed; project inactive since 2014-2017 | Referenced as historical context only. |
| **PCI DSS v4.0.1** | PCI SSC terms | Version referenced for mapping purposes only. |

---

## Tools and knowledge repositories referenced

Licences below were read from each project's own licence file. This repository **vendors none of them**; it documents how to invoke them and how to interpret their output. Invoking a tool as a subprocess is distinct from redistributing it, and only the former happens here.

**Permissively licensed** — PayloadsAllTheThings (MIT), SecLists (MIT), nuclei and nuclei-templates (MIT), LOLDrivers (Apache-2.0), gitleaks (MIT), tfsec (MIT), actionlint (MIT), zizmor (MIT), gh CLI (MIT), promptfoo (MIT), PyRIT (MIT), detect-secrets (Apache-2.0), osv-scanner / trivy / grype / syft / checkov / kubescape / kube-bench / dockle / conftest / OPA / bandit / gosec / apktool / jadx / apkleaks / dependency-check / pip-audit / garak / deepteam (Apache-2.0), cargo-audit (Apache-2.0 OR MIT), govulncheck (BSD-3-Clause), npm CLI (Artistic-2.0), OWASP ZAP (Apache-2.0), OWASP Juice Shop (MIT).

**Copyleft — invoke, never vendor:** TruffleHog (AGPL-3.0), sslyze (AGPL-3.0), MobSF (GPL-3.0), hadolint (GPL-3.0), GTFOBins (GPL-3.0), LOLBAS (GPL-3.0), nikto (GPL-3.0), testssl.sh (GPL-2.0), njsscan (LGPL-3.0), semgrep engine (LGPL-2.1), WebGoat (GPL-2.0+), DVWA (GPL-3.0+), frida (wxWindows Library Licence 3.1), objection (GPL-3.0).

**Non-permissive, with real restrictions:**

- **semgrep rules** — the ruleset (distinct from the LGPL engine) is under the Semgrep Rules License v1.0, which forbids distributing the rules or offering them as a service. Run semgrep; do not vendor its rules.
- **brakeman** — Brakeman Public Use License; commercial use requires a paid licence.
- **CodeQL CLI** — GitHub CodeQL Terms and Conditions permit analysis of open-source codebases; analyzing a private or commercial codebase without GitHub Advanced Security is outside them. The queries in `github/codeql` are MIT.
- **HackTricks** — its own licence, not Creative Commons, restricting commercial use. Linked and described only.
- **Android SDK tools** (`aapt2`, `apksigner`) — SDK EULA. Invoked, never redistributed.
- **Sonatype OSS Index** — a service whose API terms changed in 2026 and could not be verified.
- **StepSecurity harden-runner** — the wrapper action is Apache-2.0, but the enterprise agent and the Windows and macOS agents are closed source, and telemetry is opt-out.

**Awesome lists** — a common assumption is that these are CC0. It is false for most: `awesome-security` (sbilly) is MIT; `awesome-web-security` has no licence file despite a CC0 badge; `awesome-mobile-security` and `awesome-llm-security` have **no licence at all**, meaning all rights reserved. They are linked, never redistributed.

---

## Reports and academic work

Figures attributed in this repository to Verizon, Sonatype, ReversingLabs, Veracode, Checkmarx, Wiz, Orca, Datadog, Google Cloud, HiddenLayer, GitGuardian, Endor Labs, FIRST.org (EPSS) and CISA (KEV) are cited as facts with their publisher named, without reproducing report text. Academic papers are cited by author, title, venue and arXiv identifier. All remain the property of their authors and publishers.
