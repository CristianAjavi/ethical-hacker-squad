# Annotated bibliography

Not needed to run an audit. Load it when someone asks where a technique comes from, or wants to go deeper on a class.

Nothing here is reproduced. Each entry is a pointer plus our own note on what it gives you and which role it serves. Bibliographic data was verified on **2026-08-04**; anything that could not be confirmed at the source is marked `not verified`.

## Free and legally readable — start here

- **OWASP MASTG / MASVS / MASWE** — <https://mas.owasp.org/>. CC BY-SA. The real replacement for the mobile handbooks below, and the only living, versioned mobile testing corpus. Roles: `mobile`, `verifier`.
- **Building Secure and Reliable Systems** — Adkins, Beyer, Blankinship, Lewandowski, Oprea, Stubblefield. O'Reilly / Google, April 2020. Free to read at <https://sre.google/books/building-secure-reliable-systems/>. Licence `not verified` — free to read is not the same as openly licensed. Design for least privilege, recovery and incident response at scale. Roles: `infra-cloud`, `lead`, `remediator`.
- **Practical Cryptography for Developers** — Svetlin Nakov, 2018. <https://cryptobook.nakov.com>. **MIT-licensed**, so compatible with this repository. Hashes, HMAC, KDFs (scrypt, Argon2), AES, ChaCha20, ECC, signatures, with runnable examples. Roles: `remediator`, `web-api`.
- **PortSwigger Web Security Academy** — <https://portswigger.net/web-security>. Free, with labs. PortSwigger stated publicly that this replaced a third edition of the handbook below, so treat it as the living successor. Terms of use `not verified`: link, do not copy. Roles: `web-api`, `verifier`, `lead`.
- **OWASP Juice Shop** — <https://github.com/juice-shop/juice-shop>. MIT. Intentionally vulnerable target for validating that a procedure actually detects what it claims.
- **OWASP WebGoat** (GPL-2.0+) and **DVWA** (GPL-3.0+) — same purpose, copyleft: link, never incorporate.
- **Damn Vulnerable MCP Server**, **Damn Vulnerable LLM Agent**, **Damn Vulnerable Email Agent** — targets for `ai-safety` procedures covering tool poisoning, rug pull, tool shadowing and indirect injection. Licences `not verified`.

## Reading code to find vulnerabilities — the core of this squad

- **The Art of Software Security Assessment** — Dowd, McDonald, Schuh. Addison-Wesley, 2006. ISBN 9780321444424. Still the reference on systematic manual code audit. Roles: `verifier`, `lead`, `web-api`.
- **Designing Secure Software** — Loren Kohnfelder. No Starch, 2021. ISBN 9781718501928. By the co-author of STRIDE; the third part is a catalogue of implementation flaws with code. Unusually well suited to an agent reading diffs. Roles: `verifier`, `remediator`, `lead`.
- **Secure by Design** — Deogun, Bergh Johnsson, Sawano. Manning, 2019. ISBN 9781617294358. Domain primitives and validation that make the vulnerability inexpressible rather than merely blocked. Roles: `remediator`, `lead`.
- **Alice and Bob Learn Secure Coding** — Tanya Janca. Wiley, 2025-02-11. ISBN 9781394171705. Language- and framework-specific secure coding. Companion to *Alice and Bob Learn Application Security* (Wiley, 2020, ISBN 9781119687351) — a sibling work, not a second edition. Roles: `remediator`, `web-api`.

## Web and API

- **The Web Application Hacker's Handbook, 2nd ed.** — Stuttard, Pinto. Wiley, 2011. ISBN 9781118026472. **There is no third edition.** Foundational taxonomy; dated for modern stacks. Roles: `web-api`, `lead`.
- **Web Application Security, 2nd ed.** — Andrew Hoffman. O'Reilly, February 2024. ISBN 9781098143930. The most current of this section, and it covers countermeasures rather than only attacks. Roles: `web-api`, `remediator`.
- **Bug Bounty Bootcamp** — Vickie Li. No Starch, 2021. ISBN 9781718501546. Recon, exploitation chains, and notably report writing. Roles: `web-api`, `verifier`.
- **Real-World Bug Hunting** — Peter Yaworski. No Starch, 2019. ISBN 9781593278618. Awarded real-world cases with the hunter's reasoning intact. Role: `web-api`.
- **The Tangled Web** — Michal Zalewski. No Starch, 2011. ISBN 9781593273880. Why the browser security model is fragile by construction. Ages well conceptually. Role: `web-api`.

## Threat modelling

- **Threat Modeling: Designing for Security** — Adam Shostack. Wiley, 2014. ISBN 9781118809990. STRIDE and attack trees; still the standard. Roles: `lead`, `verifier`.
- **Threats: What Every Engineer Should Learn From Star Wars** — Adam Shostack. Wiley, 2023. ISBN 9781119895169. The lighter version for engineers outside security. Roles: `lead`, `remediator`.

## Infrastructure, cloud and containers

- **Container Security** — Liz Rice. O'Reilly, April 2020. ISBN 9781492056706. Namespaces, cgroups, capabilities, and why a container is not a security boundary. The publisher-sponsored free edition has **expired**; do not promise a free copy. Role: `infra-cloud`.
- **Hacking Kubernetes** — **Andrew Martin and Michael Hausenblas** (not Liz Rice). O'Reilly, October 2021. ISBN 9781492081739. Attack and defence per Kubernetes component. Role: `infra-cloud`.
- **Cloud Native Security** — Chris Binnie, Rory McCune. Wiley, August 2021. ISBN 9781119782230. Role: `infra-cloud`.
- **Cloud Security Handbook, 2nd ed.** — Eyal Estrin. Packt, April 2025. ISBN 9781836200017. Equivalent controls across AWS, Azure and GCP. Role: `infra-cloud`.
- **Securing DevOps** — Julien Vehent. Manning, 2018. ISBN 9781617294136. Dated on tools, current on the pattern. Roles: `infra-cloud`, `supply-chain`.
- **Attacking Network Protocols** — James Forshaw. No Starch, December 2017. ISBN 9781593277505. Roles: `infra-cloud`, `verifier`.

## Supply chain

- **Software Supply Chain Security** — Cassie Crossley. O'Reilly, March 2024. ISBN 9781098133702. SBOM, provenance, signing and third-party risk end to end. The single best fit for the `supply-chain` role. Roles: `supply-chain`, `lead`.
- **Practical Malware Analysis** — Sikorski, Honig. No Starch, February 2012. ISBN 9781593272906. Relevant here for one specific job: understanding a malicious npm or PyPI package, not for reviewing your own code. Role: `supply-chain`.

## Mobile

- **Android Hacker's Handbook** (Wiley, March 2014, ISBN 9781118608647) and **iOS Hacker's Handbook** (Wiley, May 2012, ISBN 9781118204122) — **obsolete**. Historical value only; use MASTG instead.
- **Android Security Internals** — Nikolay Elenkov. No Starch, 2014. ISBN 9781593275815. Binder IPC, permissions, keystore from the inside. A second edition is `not verified`. Role: `mobile`.
- **iOS Application Security** — David Thiel. No Starch, February 2016. ISBN 9781593276010. Dated (pre-SwiftUI). Role: `mobile`.

## Cryptography

- **Serious Cryptography, 2nd ed.** — Jean-Philippe Aumasson. No Starch, 2024-10-15. ISBN 9781718503847. Gives you the judgement to decide whether a use of cryptography is correct, which is the actual job. Roles: `verifier`, `remediator`, `web-api`.

## AI and agent security

- **The Developer's Playbook for Large Language Model Security** — Steve Wilson. O'Reilly, 2024. ISBN 9781098162207. Written by the lead of the OWASP LLM Top 10. The reference book for `ai-safety`.
- **Adversarial AI: Attacks, Mitigations and Defense Strategies** — John Sotiropoulos. Packt, 2024. ISBN 9781835087985. Classical adversarial ML plus MLSecOps and threat modelling of ML systems. Role: `ai-safety`.
- No serious book specifically on **agent** security was found published as of 2026-08-04. The current material is normative and academic rather than editorial — see the papers below and the OWASP GenAI project.

## Privacy

- **Data Privacy: A Runbook for Engineers** — Nishant Bhajaria. Manning, 2022. ISBN 9781617298998. Classification, minimization, deletion and consent treated as engineering rather than policy. The only book-length fit for `privacy-abuse`. Roles: `privacy-abuse`, `remediator`.

## Papers and research that changed a procedure

Listed only where they altered what a pack tells the agent to look for.

- **Wunder et al., arXiv:2308.15259** (v1 2023-08-29, v2 2024-05-08; IEEE S&P 2024) — 196 CVSS users scoring widespread vulnerabilities. In the follow-up with 59 of them, *"For the same vulnerabilities from the main study, 68% of these users gave different severity ratings."* The human inter-rater figure behind `SEV-*` being answered rather than assumed: if trained people disagree at that rate on a scored framework, a model's unexamined label is worth less still.
- **Al Haddad et al., arXiv:2510.18508** (2025-10-21) — four LLMs against SSVC's decision points over 384 real vulnerabilities: *"all models tended to over-predict risk"*, with one model reaching fair agreement under weighted Cohen's kappa. Severity inflation in LLM auditors is measured, not suspected, and handing a model a decision tree relocates the inflation into the decision points rather than removing it. Per-point F1 and kappa figures were `not read from the PDF` and must not be cited.
- **Koscinski et al., arXiv:2508.13644** (2025-08-19; ACM CCS 2025, DOI 10.1145/3719027.3765210) — CVSS, EPSS, SSVC and the Exploitability Index over 600 vulnerabilities: *"Cohen's Kappa values are close to zero across all comparisons"*, Krippendorff's Alpha predominantly negative, 5 CVEs shared across all four top-100 lists. Note what it measures: agreement **between scoring systems**, not the reproducibility of any one. The narrow conclusion is enough — there is no external oracle to import, so the discipline has to be ours and checkable.
- **SSVC pilot**, CERT/CC, `https://certcc.github.io/SSVC/topics/evaluation_of_draft_trees/` — six analysts over nine CVEs, **Fleiss' kappa** (not Cohen's; these figures do not tabulate against the three above): Exploitation 0.807, Technical Impact 0.679, Safety Impact 0.122, Mission Impact 0.146. The authors' own caveats: *"These participant demographics limit the generalizability of the results of the pilot"*, *"we expect the organizational homogeneity of the participants has inflated the agreement somewhat"*, *"We did not execute a new rater agreement experiment with the updated descriptions."* Agreement holds on the decision points that are observable and collapses on the ones needing the client's context — which is why `SEV-*` is a list of observable caps and not a decision tree. SSVC's documentation is CC BY-NC 4.0 (code files MIT-SEI): its structure is cited, none of its prose reproduced.
- **Greshake et al., arXiv:2302.12173** (2023-02-23) — introduced indirect prompt injection. Drives `AI-02`..`AI-04`. The AISec'23 venue often cited alongside it is `not declared on arXiv`.
- **Maloyan & Namiot, arXiv:2601.17548** (2026-01-24) — systematization over agentic coding assistants: 42 techniques, 78 studies, above 85% success with adaptive strategies and under 50% mitigation for most defences. Source of the delivery-vector file list in `AI-02`.
- **CaMeL, arXiv:2503.18813** (Google DeepMind / ETH) — control- and data-flow separation with capabilities enforced at the call site; 77% of AgentDojo tasks solved with provable security against 84% undefended. The design `AI-05` looks for.
- **Design Patterns for Securing LLM Agents, arXiv:2506.08837** (2025-06-10) — Action-Selector, Plan-Then-Execute, Dual LLM, Context-Minimization. Defines the insecure pattern: replanning while reading untrusted results.
- **Spotlighting, arXiv:2403.14720** (Microsoft, March 2024) — delimiting, datamarking, encoding; attack success dropped from above 50% to under 2%. The mitigation `AI-03` recommends.
- **PoisonedRAG, arXiv:2402.07867** (USENIX Security 2025) — five injected texts in a 2.6M corpus force the target answer 97% of the time. Why `AI-12` treats ingestion origin as the control point.
- **MINJA, arXiv:2503.03704** — poisons agent memory through queries alone, without store access. Drives `AI-13`.
- **MCPTox, arXiv:2508.14925** — 45 real MCP servers, 353 tools, 20 agents. The counterintuitive result that more capable models are *more* susceptible, because they follow instructions better. Frames `AI-08`.
- **A First Look at the Security Issues in the MCP Ecosystem, arXiv:2510.16558** (DSN 2026) — 67,000+ servers surveyed; 833 vulnerable. Basis for the unpinned `npx -y` check.
- **Simon Willison — the lethal trifecta** (2025-06-16) and the **dual LLM pattern** (2023-04-25). `AI-01` is the operational form of the first.
- **UK NCSC, "Prompt injection is not SQL injection"** (2025-12-08) — no parameterized-query equivalent exists; privileges should drop to the level of whatever party's content the model just processed. The taint check in `AI-06`.
- **Johann Rehberger / embracethered** — markdown image exfiltration and ASCII smuggling via the Unicode Tags block `U+E0000`-`U+E007F`. Sources for `AI-15` and `AI-20`.
- **AgentDojo, arXiv:2406.13352** (NeurIPS 2024) and **InjecAgent, arXiv:2403.02691** (ACL 2024 Findings) — evaluation corpora; AgentDojo's four canonical attack signatures are cheap detection strings.
- **Alex Birsan, "Dependency Confusion"** (2021-02-09) — 35 companies compromised with no exploit. `SUP-05`.
- **Ohm et al., "Backstabber's Knife Collection", DIMVA 2020, arXiv:2005.09535** — 56% of 174 real malicious packages trigger at install time. The quantitative basis for treating install scripts as the first thing to grep.
- **Spracklen et al., USENIX Security 2025, arXiv:2406.10279** — package hallucination measured at 5.2% for commercial and 21.7% for open models across 576,000 samples; the origin of slopsquatting. `SUP-08`.
- **Lipp et al., ISSTA 2022** and **Bennett et al., EASE 2024** — measured SAST recall. The evidence behind "a clean scan is not evidence of absence" in `VER-06` and `tooling.md`.
- **Meli et al., NDSS 2019** and **Basak et al., ESEM 2023** — secret detection precision and recall; distinctive format beats entropy. `SUP-17`.
- **Jacobs et al., 2023** — EPSS threshold 0.088 delivers the same coverage as CVSS ≥ 7 at an eighth of the effort. The triage order in `SUP-14`.
- **Endor Labs, State of Dependency Management** — under 9.5% of dependency vulnerabilities are reachable. Why an SCA hit without a call path is informational.

## Annual reports used for prioritization

Verizon DBIR 2026; Sonatype State of the Software Supply Chain 2026; ReversingLabs 2026; Veracode State of Software Security 2026; Checkmarx Future of Application Security 2026; Wiz State of AI in the Cloud 2026; Orca State of Application Security 2025-2026; Datadog State of Cloud Security 2025 and State of DevSecOps 2026; Google Cloud Threat Horizons H1 2026; HiddenLayer AI Threat Landscape 2026; GitGuardian State of Secrets Sprawl 2026. Figures drawn from these appear in the packs with the report named.

One negative result worth recording: a **Snyk State of Open Source Security** newer than the 2024 edition could not be confirmed. Figures circulating under that title for later years should not be cited.
