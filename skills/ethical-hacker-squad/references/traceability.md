# Traceability and citation policy

**Why the corpus is in English.** The source material - standard identifiers, CWE names, scanner output, advisory text - is English, and translating the procedures makes them drift away from the IDs they cite. Findings and the report are written in the user's language; identifiers never are.

Two jobs: tell you which identifier a finding maps to, and let the report declare coverage honestly — "session management was exercised, weak cryptography was not".

All facts below were verified against primary sources on **2026-08-04**. Where a version or date could not be confirmed at the source it is marked `not verified`.

## Citation policy

This repository is MIT-licensed and public. The standards it cites are not.

1. **Identifiers, version numbers and test names are facts.** Cite them freely: `WSTG-INPV-05`, `ASVS 5.0 V8`, `CWE-89`, `A01:2025`, `LLM01:2026`, `ASI06`, `MASVS-STORAGE-1`, `MASTG-TEST-0001`, `CAPEC-66`, `AML.T0051.001`, `CICD-SEC-4`, `PS.1.1`, `SLSA Build L2`.
2. **Standard text is not copied, ever.** OWASP material is CC BY-SA 4.0: reproducing its wording would force the derivative under ShareAlike and break MIT. Every procedure in this corpus is written from scratch.
3. **Cite at the granularity you actually verified.** Where an individual test ID was not confirmed at the source, this corpus cites the category with a wildcard (`WSTG-ATHN-*`) or the chapter (`ASVS 5.0 V6`). That is deliberate. Inventing a plausible-looking ID is a fabrication, and a fabricated identifier is worse than no identifier because it survives review by looking correct.
4. **CIS is the strictest case.** CIS Benchmarks are CC BY-NC-SA and CIS Controls are CC BY-NC-**ND**, and CIS does not publish explicit permission to quote recommendation text. This corpus names benchmarks by existence and cites `CIS v8.1 Control N` at control level only, with criteria written in our own words.
5. **MITRE requires an attribution notice**, reproduced in `NOTICE.md` at the repository root. NIST publications are US-Government works and are in the public domain in the United States.

Apply the same policy when writing a report: cite the ID, describe the requirement in your own words.

## Verified state of each standard

| Standard | Current version | Date | ID scheme | Licence / terms |
|---|---|---|---|---|
| OWASP WSTG | v4.2 | 2020-12-03 | `WSTG-<CAT>-<NN>`, 12 categories, 97 tests | CC BY-SA 4.0 |
| OWASP ASVS | 5.0.0 | 2025-05-30 | chapters `V1`..`V17`; requirements numeric `X.Y.Z` | CC BY-SA 4.0 |
| OWASP MASVS | 2.1.0 | 2024-01-18 | `MASVS-<GROUP>-<N>`, 8 groups, 24 controls, no L1/L2/R **control** levels; `MAS-L1`/`MAS-L2`/`MAS-R`/`MAS-P` exist, but as MAS **testing profiles** (the engagement's adversary model), never as a level on a control | CC BY-SA 4.0 |
| OWASP MASTG | 2.0.0 | 2026-06-30 | `MASTG-TEST-NNNN` (193 tests), `MASWE-NNNN` | CC BY-SA 4.0 |
| OWASP Top 10 | **2025** | released; exact final date not verified | `A01:2025`..`A10:2025` | CC BY-SA 4.0 |
| OWASP API Security Top 10 | 2023 | 2023-06-05 | `API1:2023`..`API10:2023` | CC BY-SA 4.0 |
| OWASP Top 10 for LLM Applications | **2026** | 2026-08-03 | `LLM01:2026`..`LLM10:2026` | CC BY-SA 4.0 |
| OWASP Top 10 for Agentic Applications | 2026 (v2.01) | announced 2025-12-09; v2.01 2026-06-01 | `ASI01`..`ASI10` | CC BY-SA 4.0 |
| OWASP Top 10 CI/CD Security Risks | current | — | `CICD-SEC-1`..`CICD-SEC-10` | CC BY-SA 4.0 |
| MITRE CWE | 4.20 | release date not verified | `CWE-NNN`; Top 25 edition 2025, published 2025-12-15 | Royalty-free incl. commercial, attribution required |
| MITRE ATT&CK | v19 (site serves v19.1) | 2026-04-28 | `TAxxxx`, `Txxxx`, `Txxxx.yyy` | Royalty-free incl. commercial, attribution required |
| MITRE CAPEC | 3.9, 559 patterns | announced 2023-01-24 | `CAPEC-NNN` | Same MITRE terms |
| MITRE ATLAS | data v2026.06 | 2026-06-30 | `AML.Txxxx`, sub-techniques `.00x` | See NOTICE |
| NIST SP 800-218 (SSDF) | **v1.1** | 2022-02 | `PO`/`PS`/`PW`/`RV` → `XX.n` → `XX.n.m` | Public domain in the US |
| NIST SP 800-115 | final | 2008-09-30 | — | Public domain in the US |
| NIST SP 800-53 | Rev. 5, catalog release 5.2.0 | 2025-08-27 | families `AC`, `AU`, `SC`, ... | Public domain in the US |
| NIST AI RMF (AI 100-1) | 1.0, under revision | 2023-01-26 | — | Public domain in the US |
| NIST AI 600-1 (GenAI Profile) | 1.0 | 2024-07-26 | — | Public domain in the US |
| NIST AI 100-2e2025 (Adversarial ML) | e2025 | 2025-03-24 | — | Public domain in the US |
| SLSA | **v1.2** | 2025-11-24 | Build `L0`..`L3`; Source `L1`..`L4` | Community Specification License 1.0 + Apache-2.0 |
| CSA CCM | v4.1, 17 domains, 207 controls | 2026-01 | `PREFIX-NN`, e.g. `IAM-01` | No modification or translation without CSA consent |
| CIS Controls | v8.1, 18 controls, 153 safeguards | 2024-06 | `Control N`, `Safeguard N.M` | CC BY-NC-ND 4.0 |
| CIS Benchmarks | per technology | — | hierarchical decimal | CC BY-NC-SA 4.0; hosting off CIS sites prohibited |
| PCI DSS | v4.0.1, only active version | 2024-06-11 | — | PCI SSC terms |
| PTES | v1.0, abandoned (wiki idle since 2014-2017) | — | 7 phases | Licence intent unconfirmed |
| OSSTMM | 3.02, latest public | 2010-12-14 | — | CC BY-NC-ND + OML 3.0: no derivatives, no packaging into a sold tool |

Corrections worth carrying, because getting these wrong is common: the current OWASP Top 10 is **2025**, not 2021, and SSRF folded into `A01:2025`. The current LLM Top 10 is the **2026** edition, in which `LLM03` is Excessive Agency and `LLM08` is Hidden Context Exposure. WSTG is still on v4.2 from 2020 — the checklist on the repository default branch contains v5 draft IDs that do not exist in the stable release. ASVS 5.0 requirement IDs are numeric, without the `V`. SLSA is v1.2 and is not Creative Commons.

## Standard family to role and pack

Five packs ship as more than one file (`mobile` and `supply-chain` as three). The `Pack` column names the file that holds the section, so a row citing several files means all of them are opened. The shorthands used below are `web-api.md` / `web-api-clientside-logic.md`, `mobile.md` / `mobile-runtime-trust.md` / `mobile-ios.md`, `infra-cloud.md` / `infra-cloud-cicd-exposure.md` / `infra-cloud-cicd-platforms.md`, `supply-chain.md` / `supply-chain-secrets-malware.md` / `supply-chain-source-lifecycle.md`, `ai-safety.md` / `ai-safety-data-output.md`.

| Standard family | Role | Pack | Procedures |
|---|---|---|---|
| `WSTG-INFO-*`, `WSTG-CONF-*` | web-api | `web-api-clientside-logic.md` §11, `infra-cloud-cicd-exposure.md` §5 | `WEB-22`, `INF-17` |
| `WSTG-IDNT-*`, `WSTG-ATHN-*`, `WSTG-SESS-*` | web-api | `web-api.md` §1 | `WEB-01`..`WEB-03` |
| `WSTG-ATHZ-*` | web-api | `web-api.md` §2 | `WEB-04`..`WEB-06` |
| `WSTG-INPV-*` | web-api | `web-api.md` §3, §4, §5 + `web-api-clientside-logic.md` §6 | `WEB-07`..`WEB-14` |
| `WSTG-ERRH-*` | web-api | `web-api-clientside-logic.md` §11 | `WEB-22` |
| `WSTG-CRYP-*` | web-api | `web-api-clientside-logic.md` §9 | `WEB-19` |
| `WSTG-BUSL-*` | web-api | `web-api-clientside-logic.md` §8 | `WEB-17`, `WEB-18` |
| `WSTG-CLNT-*` | web-api | `web-api-clientside-logic.md` §6, §7 | `WEB-13`..`WEB-16` |
| `WSTG-APIT-*` | web-api | `web-api-clientside-logic.md` §10 | `WEB-20`, `WEB-21` |
| `API1:2023`..`API5:2023` | web-api | `web-api.md` §1, §2 | `WEB-01`..`WEB-06` |
| `API6:2023`, `API4:2023` | web-api | `web-api-clientside-logic.md` §8 | `WEB-17`, `WEB-18` |
| `API7:2023` | web-api | `web-api.md` §4 | `WEB-10` |
| `API8:2023`, `API9:2023`, `API10:2023` | web-api / supply-chain | `web-api-clientside-logic.md` §7, §11 / `supply-chain.md` §7 | `WEB-15`, `WEB-16`, `WEB-22`, `SUP-13`..`SUP-15` |
| `ASVS 5.0 V1`, `V2`, `V5` | web-api | `web-api.md` §3, §4, §5 | `WEB-07`..`WEB-12` |
| `ASVS 5.0 V3` | web-api | `web-api-clientside-logic.md` §6, §7 | `WEB-13`..`WEB-16` |
| `ASVS 5.0 V4` | web-api | `web-api-clientside-logic.md` §10 | `WEB-20`, `WEB-21` |
| `ASVS 5.0 V6`, `V7`, `V9`, `V10` | web-api | `web-api.md` §1 | `WEB-01`..`WEB-03` |
| `ASVS 5.0 V8` | web-api | `web-api.md` §2 | `WEB-04`..`WEB-06` |
| `ASVS 5.0 V11`, `V12` | web-api / infra-cloud | `web-api-clientside-logic.md` §9 / `infra-cloud.md` §1 | `WEB-19`, `INF-03` |
| `ASVS 5.0 V13`, `V14` | infra-cloud / privacy-abuse | `infra-cloud.md` §1 + `infra-cloud-cicd-exposure.md` §5 / `privacy-abuse.md` §1..§3, §5 | `INF-01`..`INF-06`, `INF-17`, `PRV-01`..`PRV-05` |
| `ASVS 5.0 V15` | web-api / remediator / ai-safety | `web-api-clientside-logic.md` §9 / part A / `ai-safety-data-output.md` §5 | `WEB-19`, `REM-01`..`REM-03`, `AI-15` |
| `ASVS 5.0 V16` | web-api / infra-cloud | `web-api-clientside-logic.md` §11 / `infra-cloud.md` §1 | `WEB-22`, `INF-06` |
| `MASVS-STORAGE-*`, `MASVS-CRYPTO-*` | mobile | `mobile.md` §2, §6 + `mobile-runtime-trust.md` §9 | `MOB-03`, `MOB-04`, `MOB-11`, `MOB-12`, `MOB-16` |
| `MASVS-AUTH-*`, `MASVS-NETWORK-*` | mobile | `mobile.md` §5 + `mobile-runtime-trust.md` §7, §9 | `MOB-09`, `MOB-10`, `MOB-13`, `MOB-16` |
| `MASVS-PLATFORM-*` | mobile | `mobile.md` §1, §3, §4 + `mobile-runtime-trust.md` §10 + `mobile-ios.md` §8 | `MOB-01`, `MOB-02`, `MOB-05`..`MOB-08`, `MOB-14`, `MOB-15`, `MOB-17` |
| `MASVS-CODE-*`, `MASVS-RESILIENCE-*` | mobile | `mobile.md` §6 + `mobile-runtime-trust.md` §7, §11 | `MOB-11`..`MOB-13`, `MOB-18` |
| `MASVS-PRIVACY-*` | privacy-abuse / mobile | `privacy-abuse.md` §5 / `mobile.md` §2 | `PRV-07`, `MOB-04` |
| `A01:2025` | web-api | `web-api.md` §2, §4 | `WEB-04`..`WEB-06`, `WEB-10` |
| `A02:2025` | infra-cloud | `infra-cloud.md` §1..§3 + `infra-cloud-cicd-exposure.md` §5 | `INF-01`..`INF-12`, `INF-17` |
| `A03:2025` | supply-chain | `supply-chain.md` §1..§6 + `supply-chain-secrets-malware.md` §8, §9 | `SUP-01`..`SUP-12`, `SUP-16`..`SUP-20` |
| `A04:2025` | web-api / infra-cloud | `web-api-clientside-logic.md` §9 / `infra-cloud.md` §1 | `WEB-19`, `INF-03` |
| `A05:2025` | web-api | `web-api.md` §3 | `WEB-07`..`WEB-09` |
| `A06:2025` | leader | design review across packs | — |
| `A07:2025` | web-api | `web-api.md` §1 | `WEB-01`..`WEB-03` |
| `A08:2025` | supply-chain | `supply-chain.md` §5, §6 | `SUP-09`..`SUP-12` |
| `A09:2025` | infra-cloud / web-api | `infra-cloud.md` §1 / `web-api-clientside-logic.md` §11 | `INF-06`, `WEB-22` |
| `A10:2025` | web-api | `web-api-clientside-logic.md` §11 | `WEB-22` |
| `CICD-SEC-1`..`CICD-SEC-10` | infra-cloud + supply-chain | `infra-cloud-cicd-exposure.md` §4 + `infra-cloud-cicd-platforms.md` §7 / `supply-chain.md` §5, §6 + `supply-chain-source-lifecycle.md` §10 | `INF-13`..`INF-16`, `INF-19`..`INF-23`, `SUP-09`..`SUP-12`, `SUP-21`, `SUP-22` |
| `SLSA Build L1`..`L3`, `Source L1`..`L4` | supply-chain | `supply-chain.md` §5, §6 + `supply-chain-source-lifecycle.md` §10 | `SUP-09`..`SUP-12`, `SUP-21`..`SUP-23` |
| `SSDF PO`/`PS`/`PW`/`RV` | supply-chain + remediator | `supply-chain.md` §5..§7 + `supply-chain-secrets-malware.md` §8 + `supply-chain-source-lifecycle.md` §10, §11 / part A | `SUP-13`..`SUP-16`, `SUP-21`..`SUP-25`, `REM-*` |
| `LLM01:2026`, `AML.T0051` | ai-safety | `ai-safety.md` §0, §1 | `AI-01`..`AI-04` |
| `LLM02:2026`, `LLM08:2026` | ai-safety | `ai-safety-data-output.md` §6 | `AI-17`, `AI-18` |
| `LLM03:2026` | ai-safety | `ai-safety.md` §2 | `AI-05`..`AI-07` |
| `LLM04:2026`, `ASI04` | ai-safety + supply-chain | `ai-safety.md` §3 | `AI-08`..`AI-11` |
| `LLM05:2026`, `ASI06` | ai-safety | `ai-safety-data-output.md` §4 | `AI-12`..`AI-14` |
| `LLM06:2026` | ai-safety | `ai-safety-data-output.md` §7 | `AI-19` |
| `LLM09:2026` | ai-safety | `ai-safety-data-output.md` §4 | `AI-12`..`AI-14` |
| `LLM10:2026` | ai-safety | `ai-safety-data-output.md` §5 | `AI-15`, `AI-16` |
| `ASI01`, `ASI09` | ai-safety | `ai-safety.md` §0, §1 | `AI-01`..`AI-04` |
| `ASI02`, `ASI03`, `ASI05` | ai-safety | `ai-safety.md` §2 | `AI-05`..`AI-07` |
| `ASI07`, `ASI08`, `ASI10` | ai-safety | `ai-safety.md` §2, §3 | `AI-05`..`AI-11` |
| `AML.T0010`, `LLM04:2026` (model artifacts) | ai-safety | `ai-safety-data-output.md` §4 | `AI-23` |
| `AML.T0068` | ai-safety | `ai-safety-data-output.md` §8 | `AI-20` |
| `CCM DSP` (where the data lands) | privacy-abuse | `privacy-abuse.md` §10 | `PRV-12` |
| `CIS v8.1 Control *`, `CCM *`, `NIST 800-53 *` | infra-cloud + supply-chain | `infra-cloud.md` §1..§3 + `infra-cloud-cicd-exposure.md` §4, §5 / `supply-chain.md` §1, §7 + `supply-chain-source-lifecycle.md` §10, §11 | `INF-01`..`INF-17`, `SUP-02`, `SUP-13`..`SUP-15`, `SUP-21`..`SUP-25` |

| `CWE-22`, `CWE-59`, `CWE-61`, `CAPEC-126`, `CAPEC-27` | local-app | `local-app.md` §1 | `LOC-01`, `LOC-02` |
| `CWE-367`, `CWE-377`..`CWE-379`, `CAPEC-29` | local-app | `local-app.md` §2 | `LOC-03`, `LOC-04` |
| `CWE-88`, `CWE-426`, `CWE-427`, `CAPEC-6`, `CAPEC-38`, `CAPEC-471`, `ATT&CK T1574` | local-app | `local-app.md` §3 | `LOC-05`..`LOC-07` |
| `CWE-250`, `CWE-269`, `CWE-276`, `CWE-732` | local-app | `local-app.md` §4 | `LOC-08`, `LOC-09` |
| `CWE-1188`, `CWE-665` | local-app | `local-app.md` §5 | `LOC-10` |
| `CWE-829`, `CWE-79` (desktop renderer) | local-app | `local-app.md` §6 | `LOC-11`, `LOC-12` |
| `CWE-346`, `CWE-1385` | local-app | `local-app.md` §7 | `LOC-13` |
| `CWE-494` (code arriving at runtime) | local-app / supply-chain | `local-app.md` §8 / `supply-chain.md` §6 | `LOC-14`, `SUP-09`..`SUP-12` |
| `CWE-214`, `CWE-312`, `CWE-522`, `CWE-532` (on the local machine) | local-app | `local-app.md` §9 | `LOC-15` |

## Known coverage gaps

Declare these rather than implying they are covered:

- **`WSTG-CRYP-*` beyond `WEB-19`** — protocol-level cryptographic testing (cipher suites, padding oracles) is not covered by a procedure. TLS posture is a remote test that requires authorization.
- **`MASTG-TEST-NNNN` and `MASWE-NNNN` individual IDs** — the corpus cites MASVS controls, MASTG test groups and MASWE weakness groups (`MASWE AUTH group`), not individual numbers, because those numbers were not verified one by one. The MAS testing profiles are cited as a concept; their requirement lists were not read one by one either.
- **`ASVS 5.0 V17` (WebRTC)** — no procedure.
- **`CIS Benchmark` numeric recommendations** — cited by existence only, for licence reasons.
- **Microsoft's cloud security benchmark** — consulted while drafting `PRV-12` and **not** cited: it is not in `docs/sources-allowlist.json` and its licence was not verified. Its control identifiers therefore appear nowhere in the corpus, and cloud-provider-specific control ids are not claimed as coverage.
- **CI platforms other than GitHub Actions** — closed for GitLab CI, Jenkins, Azure Pipelines, CircleCI and Bitbucket Pipelines by `INF-19`..`INF-23`, which carry each platform's own symbols. What remains open is narrower and is stated inside those procedures: `INF-19`, `INF-21` and `INF-23` each depend on a setting that lives in the platform rather than in the repository — variable protection and fork-secret exposure, credential scope, runner configuration — so without the exported setting the answer is `UNKNOWN`, not "covered". Platforms with no procedure at all: Tekton, Argo Workflows, Drone, Buildkite, TeamCity.
- **CLI, desktop and library surfaces** — now covered by `local-app.md` (`LOC-01`..`LOC-15`). What remains uncovered inside that surface: native memory safety, anything needing a debugger or a fuzzer, Windows mechanisms beyond DLL search order and registry protocol handlers (services, COM, scheduled tasks, ACL inheritance), and macOS TCC and entitlement analysis. Declare those as not exercised.
- **A finding verified while its identical siblings go unmeasured** — no `VER-*` procedure requires re-running the reproduction against every other place that shares the broken property. `REM-01` instructs the repairer to search for them; `VER-02` measures the original case, `VER-03` variants of the same control and `VER-08` the three runs over that one finding. A patch applied to one of nine identical handlers passes all of them. Until a procedure closes this, **a verification whose family was never enumerated is reported as `partially verified`, with the count**, never as `verified`. The candidate identifier is held by a pre-registered round (`bench/runs/2026-08-24-chain-completion/`), which is why this is a declaration and not a procedure.
- **Deprecated API idioms that are not yet a vulnerability** — a superseded authentication helper, a call a library deprecated but nobody has filed a CVE against. No procedure, and deliberately so: static analysis has no vulnerability to match and composition analysis finds the package version fine, because what is stale is the *call*. Closing it needs a currency oracle from outside the repository — a deprecation map, a release feed — and without one every answer would be `UNKNOWN` under `FP-08`, which is prose rather than a procedure. Declare it as not exercised when the target's dependencies are old.
- **Binary exploitation, firmware, embedded, ICS, smart contracts** — out of scope of every pack.
- **`ATT&CK` technique mapping** — used sparingly and only where the technique was verified. Absence of an ATT&CK ID on a finding means it was not verified, not that no technique applies.
