# Traceability and citation policy

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
| OWASP MASVS | 2.1.0 | 2024-01-18 | `MASVS-<GROUP>-<N>`, 8 groups, 24 controls, no L1/L2/R levels | CC BY-SA 4.0 |
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

| Standard family | Role | Pack | Procedures |
|---|---|---|---|
| `WSTG-INFO-*`, `WSTG-CONF-*` | web-api | `web-api.md` §11, infra-cloud §5 | `WEB-22`, `INF-17` |
| `WSTG-IDNT-*`, `WSTG-ATHN-*`, `WSTG-SESS-*` | web-api | §1 | `WEB-01`..`WEB-03` |
| `WSTG-ATHZ-*` | web-api | §2 | `WEB-04`..`WEB-06` |
| `WSTG-INPV-*` | web-api | §3, §4, §5, §6 | `WEB-07`..`WEB-14` |
| `WSTG-ERRH-*` | web-api | §11 | `WEB-22` |
| `WSTG-CRYP-*` | web-api | §9 | `WEB-19` |
| `WSTG-BUSL-*` | web-api | §8 | `WEB-17`, `WEB-18` |
| `WSTG-CLNT-*` | web-api | §6, §7 | `WEB-13`..`WEB-16` |
| `WSTG-APIT-*` | web-api | §10 | `WEB-20`, `WEB-21` |
| `API1:2023`..`API5:2023` | web-api | §1, §2 | `WEB-01`..`WEB-06` |
| `API6:2023`, `API4:2023` | web-api | §8 | `WEB-17`, `WEB-18` |
| `API7:2023` | web-api | §4 | `WEB-10` |
| `API8:2023`, `API9:2023`, `API10:2023` | web-api / supply-chain | §7, §11 / §7 | `WEB-15`, `WEB-16`, `WEB-22`, `SUP-13`..`SUP-15` |
| `ASVS 5.0 V1`, `V2`, `V5` | web-api | §3, §5 | `WEB-07`..`WEB-12` |
| `ASVS 5.0 V3` | web-api | §6, §7 | `WEB-13`..`WEB-16` |
| `ASVS 5.0 V4` | web-api | §10 | `WEB-20`, `WEB-21` |
| `ASVS 5.0 V6`, `V7`, `V9`, `V10` | web-api | §1 | `WEB-01`..`WEB-03` |
| `ASVS 5.0 V8` | web-api | §2 | `WEB-04`..`WEB-06` |
| `ASVS 5.0 V11`, `V12` | web-api / infra-cloud | §9 / §1 | `WEB-19`, `INF-03` |
| `ASVS 5.0 V13`, `V14` | infra-cloud / privacy-abuse | §1, §5 / §1..§3 | `INF-01`..`INF-06`, `PRV-01`..`PRV-04` |
| `ASVS 5.0 V16` | web-api / infra-cloud | §11 / §1 | `WEB-22`, `INF-06` |
| `MASVS-STORAGE-*`, `MASVS-CRYPTO-*` | mobile | §2, §6 | `MOB-03`, `MOB-04`, `MOB-11`, `MOB-12` |
| `MASVS-AUTH-*`, `MASVS-NETWORK-*` | mobile | §5, §7 | `MOB-09`, `MOB-10`, `MOB-13` |
| `MASVS-PLATFORM-*` | mobile | §1, §3, §4, §8 | `MOB-01`, `MOB-02`, `MOB-05`..`MOB-08`, `MOB-14`, `MOB-15` |
| `MASVS-CODE-*`, `MASVS-RESILIENCE-*` | mobile | §6, §7 | `MOB-11`..`MOB-13` |
| `MASVS-PRIVACY-*` | privacy-abuse / mobile | §4 | `PRV-07`, `MOB-04` |
| `A01:2025` | web-api | §2, §4 | `WEB-04`..`WEB-06`, `WEB-10` |
| `A02:2025` | infra-cloud | §1..§3, §5 | `INF-01`..`INF-12`, `INF-17` |
| `A03:2025` | supply-chain | §1..§6 | `SUP-01`..`SUP-12`, `SUP-16`..`SUP-20` |
| `A04:2025` | web-api / infra-cloud | §9 / §1 | `WEB-19`, `INF-03` |
| `A05:2025` | web-api | §3 | `WEB-07`..`WEB-09` |
| `A06:2025` | leader | design review across packs | — |
| `A07:2025` | web-api | §1 | `WEB-01`..`WEB-03` |
| `A08:2025` | supply-chain | §5, §6 | `SUP-09`..`SUP-12` |
| `A09:2025` | infra-cloud / web-api | §1 / §11 | `INF-06`, `WEB-22` |
| `A10:2025` | web-api | §11 | `WEB-22` |
| `CICD-SEC-1`..`CICD-SEC-10` | infra-cloud + supply-chain | §4 / §5 | `INF-13`..`INF-16`, `SUP-09`..`SUP-12` |
| `SLSA Build L1`..`L3`, `Source L1`..`L4` | supply-chain | §5, §6 | `SUP-09`..`SUP-12` |
| `SSDF PO`/`PS`/`PW`/`RV` | supply-chain + remediator | §5..§7 / part A | `SUP-13`..`SUP-16`, `REM-*` |
| `LLM01:2026`, `AML.T0051` | ai-safety | §0, §1 | `AI-01`..`AI-04` |
| `LLM02:2026`, `LLM08:2026` | ai-safety | §6 | `AI-17`, `AI-18` |
| `LLM03:2026` | ai-safety | §2 | `AI-05`..`AI-07` |
| `LLM04:2026`, `ASI04` | ai-safety + supply-chain | §3 | `AI-08`..`AI-11` |
| `LLM05:2026`, `ASI06` | ai-safety | §4 | `AI-12`..`AI-14` |
| `LLM06:2026` | ai-safety | §7 | `AI-19` |
| `LLM09:2026` | ai-safety | §4 | `AI-12`..`AI-14` |
| `LLM10:2026` | ai-safety | §5 | `AI-15`, `AI-16` |
| `ASI01`, `ASI09` | ai-safety | §0, §1 | `AI-01`..`AI-04` |
| `ASI02`, `ASI03`, `ASI05` | ai-safety | §2 | `AI-05`..`AI-07` |
| `ASI07`, `ASI08`, `ASI10` | ai-safety | §2, §3 | `AI-05`..`AI-11` |
| `AML.T0068` | ai-safety | §8 | `AI-20` |
| `CIS v8.1 Control *`, `CCM *`, `NIST 800-53 *` | infra-cloud | §1..§5 | `INF-01`..`INF-17` |

## Known coverage gaps

Declare these rather than implying they are covered:

- **`WSTG-CRYP-*` beyond `WEB-19`** — protocol-level cryptographic testing (cipher suites, padding oracles) is not covered by a procedure. TLS posture is a remote test that requires authorization.
- **`MASTG-TEST-NNNN` individual IDs** — the corpus cites MASVS controls and MASTG test groups, not individual test numbers, because those numbers were not verified one by one.
- **`ASVS 5.0 V17` (WebRTC)** — no procedure.
- **`CIS Benchmark` numeric recommendations** — cited by existence only, for licence reasons.
- **Binary exploitation, firmware, embedded, ICS, smart contracts** — out of scope of every pack.
- **`ATT&CK` technique mapping** — used sparingly and only where the technique was verified. Absence of an ATT&CK ID on a finding means it was not verified, not that no technique applies.
