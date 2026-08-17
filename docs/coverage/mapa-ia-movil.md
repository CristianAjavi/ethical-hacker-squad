# Mapa de currículo — Área "Seguridad de IA/agentes y móvil"

Cartografía de temarios profesionales de acceso público. **Temario crudo**: nombres de tema, IDs y
estructura tal como los nombra cada plataforma. No hay redacción copiada de ninguna fuente.
Extraído entre el 4 y el 14 de agosto de 2026.

Regla aplicada en todo el documento: se citan **IDs, nombres de tema/módulo/lab y la estructura**
(hechos no protegibles). No se reproduce la redacción de ninguna plataforma.

---

## BLOQUE A — Seguridad de aplicaciones de IA y agentes

### A.1 · OWASP GenAI Security Project — catálogo de publicaciones
Fuente: https://genai.owasp.org/resources/
Licencia declarada en el footer del sitio: **CC BY-SA 4.0**.

El "currículo" aquí no es un curso sino una **biblioteca de publicaciones fechadas**. Estructura
de la oferta (título exacto + fecha de publicación, tal como los lista la plataforma):

| Publicación | Fecha |
|---|---|
| OWASP GenAI LLM Top 10 2026 | 2026-08-03 |
| State of Agentic AI Security and Governance 2.01 | 2026-06-01 |
| AIUC-1: Crosswalks OWASP Top 10 For Agentic Applications | 2026-05-25 |
| AI Security Solutions Landscape For AI and Agentic Red Teaming Q2 2026 | 2026-04-09 |
| AI Security Solutions Landscape for Agentic AI Q2 2026 | 2026-03-17 |
| AI Security Solutions Landscape For LLM and Gen AI Apps Q2 2026 | 2026-03-17 |
| OWASP GenAI Data Security Risks & Mitigations 2026 | 2026-03-17 |
| A Practical Guide for Secure MCP Server Development | 2026-02-16 |
| OWASP Vendor Evaluation Criteria for AI Red Teaming Providers & Tooling v1.0 | 2026-02-04 |
| OWASP AIBOM Generator | 2025-12-17 |
| OWASP Top 10 for Agentic Applications for 2026 | 2025-12-09 |
| OWASP GenAI Security Project – Solutions Reference Guide Q2_Q3'25 | 2025-11-04 |
| CheatSheet – A Practical Guide for Securely Using Third-Party MCP Servers 1.0 | 2025-11-04 |
| OWASP GenAI Security Project Threat Defense COMPASS 1.0 (+ RunBook) | 2025-09-10 |
| FinBot Agentic AI Capture The Flag (CTF) Application | 2025-08-12 |
| GenAI Incident Response Guide 1.0 | 2025-07-28 |

**Lectura de cartógrafo**: el ritmo de publicación (trimestral) es el indicador de que aquí la
formación va por delante del estándar. Tres artefactos son formativos-ejecutables, no doctrinales:
*FinBot Agentic AI CTF*, *Threat Defense COMPASS RunBook* y el *AIBOM Generator*.

---

### A.2 · OWASP Top 10 for LLM Applications — edición 2025 (verificada)
Fuente: https://genai.owasp.org/llm-top-10/
Repo: https://github.com/OWASP/www-project-top-10-for-large-language-model-applications
Licencia del repo (LICENSE.md): **CC BY-SA 4.0** (uso comercial permitido, ShareAlike).

- LLM01:2025 Prompt Injection
- LLM02:2025 Sensitive Information Disclosure
- LLM03:2025 Supply Chain
- LLM04:2025 Data and Model Poisoning
- LLM05:2025 Improper Output Handling
- LLM06:2025 Excessive Agency
- LLM07:2025 System Prompt Leakage
- LLM08:2025 Vector and Embedding Weaknesses
- LLM09:2025 Misinformation
- LLM10:2025 Unbounded Consumption

Archivos fuente confirmados en `2_0_vulns/` del repo (uno por riesgo).

> **NO VERIFICADO**: la edición **2026** existe (publicada 2026-08-03) pero su listado de riesgos
> NO pudo abrirse; la página de recurso no enumera los IDs y el PDF no se descargó. No se
> reconstruye de memoria.

---

### A.3 · OWASP Agentic Security Initiative — Top 10 for Agentic Applications
Fuente (borrador público en repo): https://github.com/OWASP/www-project-top-10-for-large-language-model-applications/tree/main/initiatives/agent_security_initiative/agentic-top-10
Licencia: **CC BY-SA 4.0** (LICENSE.md del repo).

**Sprint 1 — first public draft expanded** (nombres de archivo = títulos de riesgo):

- ASI01 Agent Behaviour Hijack
- ASI02 Tool Misuse and Exploitation
- ASI03 Identity and Privilege Abuse
- ASI04 Agentic Supply Chain Vulnerabilities
- ASI05 Unexpected Code Execution (RCE)
- ASI06 Memory and Context Poisoning
- ASI07 Insecure Inter-Agent Communication
- ASI08 Cascading Failures
- ASI09 Human-Agent Trust Exploitation
- ASI10 Rogue Agents

**0.5 — initial candidates** (16 candidatos; muestra el espacio de temas que el Top 10 comprimió):
ASI01 Memory Poisoning · ASI02 Tool Misuse · ASI03 Privilege Compromise · ASI04 Resource Overload ·
ASI05 Cascading Hallucination Attacks · ASI06 Intent Breaking / Goal Manipulation ·
ASI07 Misaligned & Deceptive Behaviors · ASI08 Repudiation & Untraceability ·
ASI09 Identity Spoofing & Impersonation · ASI10 Overwhelming Human-in-the-Loop ·
ASI11 Unexpected RCE & Code Attacks · ASI12 Agent Communication Poisoning ·
ASI13 Rogue Agents in Multi-Agent Systems · ASI14 Human Attacks on Multi-Agent Systems ·
ASI15 Human Manipulation · ASI16 Insecure Inter-Agent Protocol Abuse
(+ documento suelto: Vulnerable Agentic Supply Chain)

> **NO VERIFICADO**: el PDF publicado *OWASP Top 10 for Agentic Applications for 2026*
> (genai.owasp.org, 2025-12-09) NO se abrió. Los títulos anteriores vienen del **borrador en
> GitHub**, no de la versión publicada; pueden diferir. La página de recurso no enumera IDs.

---

### A.4 · OWASP AI Testing Guide — currículo de pruebas (el más "de curso" de todos)
Fuente TOC: https://raw.githubusercontent.com/OWASP/www-project-ai-testing-guide/main/Document/README.md
Página de proyecto: https://owasp.org/www-project-ai-testing-guide/
Licencia (LICENSE.md del repo): **CC BY-SA 4.0**.

Estructura en 4 capas (AI Application / AI Model / AI Infrastructure / AI Data) con **32 pruebas
numeradas**. Esta es la fuente que más se parece a un temario de certificación:

**1. Introduction** — 1.1 Preface and Contributors · 1.2 Principles of AI Testing · 1.3 Objectives
**2. Threat Modeling AI Systems** — 2.1 Identify AI System Threats · 2.1.1 Map OWASP AI Threats To
AI Architectural Components · 2.1.2 Identify AI System Responsible AI (RAI)/Trustworthy AI Threats

**3.1 AI Application Testing**
- AITG-APP-01 Testing for Prompt Injection
- AITG-APP-02 Testing for Indirect Prompt Injection
- AITG-APP-03 Testing for Sensitive Data Leak
- AITG-APP-04 Testing for Input Leakage
- AITG-APP-05 Testing for Unsafe Outputs
- AITG-APP-06 Testing for Agentic Behavior Limits
- AITG-APP-07 Testing for Prompt Disclosure
- AITG-APP-08 Testing for Embedding Manipulation
- AITG-APP-09 Testing for Model Extraction
- AITG-APP-10 Testing for Content Bias
- AITG-APP-11 Testing for Hallucinations
- AITG-APP-12 Testing for Toxic Output
- AITG-APP-13 Testing for Over-Reliance on AI
- AITG-APP-14 Testing for Explainability and Interpretability

**3.2 AI Model Testing**
- AITG-MOD-01 Testing for Evasion Attacks
- AITG-MOD-02 Testing for Runtime Model Poisoning
- AITG-MOD-03 Testing for Poisoned Training Sets
- AITG-MOD-04 Testing for Membership Inference
- AITG-MOD-05 Testing for Inversion Attacks
- AITG-MOD-06 Testing for Robustness to New Data
- AITG-MOD-07 Testing for Goal Alignment

**3.3 AI Infrastructure Testing**
- AITG-INF-01 Testing for Supply Chain Tampering
- AITG-INF-02 Testing for Resource Exhaustion
- AITG-INF-03 Testing for Plugin Boundary Violations
- AITG-INF-04 Testing for Capability Misuse
- AITG-INF-05 Testing for Fine-tuning Poisoning
- AITG-INF-06 Testing for Dev-Time Model Theft

**3.4 AI Data Testing**
- AITG-DAT-01 Testing for Training Data Exposure
- AITG-DAT-02 Testing for Runtime Exfiltration
- AITG-DAT-03 Testing for Dataset Diversity & Coverage
- AITG-DAT-04 Testing for Harmful Content in Data
- AITG-DAT-05 Testing for Data Minimization & Consent

**4. Apéndices** — A: Rationale For Using SAIF · B: Distributed, Immutable, Ephemeral (DIE) Threat
Identification · C: Risk Lifecycle for Secure AI Systems · D: Threat Enumeration to AI Architecture
Components · E: Mapping AI Threats Against AI Systems Vulnerabilities (CVEs & CWEs) · 4.6 References

---

### A.5 · OWASP MCP Top 10
Fuente: https://github.com/OWASP/www-project-mcp-top-10
Licencia declarada en el README: **CC BY-NC-SA 4.0** ← ⚠ **NO COMERCIAL**. Ver sección de licencias.

- MCP01:2025 Token Mismanagement & Secret Exposure
- MCP02:2025 Privilege Escalation via Scope Creep
- MCP03:2025 Tool Poisoning
- MCP04:2025 Software Supply Chain Attacks & Dependency Tampering
- MCP05:2025 Command Injection & Execution
- MCP06:2025 Prompt Injection via Contextual Payloads
- MCP07:2025 Insufficient Authentication & Authorization
- MCP08:2025 Lack of Audit and Telemetry
- MCP09:2025 Shadow MCP Servers
- MCP10:2025 Context Injection & Over-Sharing

---

### A.6 · OWASP Agentic Skills Top 10 (AST10) — v1.0, edición 2026
Fuente: https://github.com/OWASP/www-project-agentic-skills-top-10
Sitio: https://owasp.github.io/www-project-agentic-skills-top-10/
Licencia (LICENSE.md): **CC BY-SA 4.0**. Estado OWASP: Incubator.

Cubre explícitamente los ecosistemas de **skills de agente**: OpenClaw (SKILL.md YAML),
Claude Code (skill.json), Cursor/Codex (manifest.json) y VS Code (package.json).

| ID | Riesgo | Severidad declarada |
|---|---|---|
| AST01 | Malicious Skills | Critical |
| AST02 | Supply Chain Compromise | Critical |
| AST03 | Over-Privileged Skills | High |
| AST04 | Insecure Metadata | High |
| AST05 | Untrusted External Instructions | High |
| AST06 | Weak Isolation | High |
| AST07 | Update Drift | Medium |
| AST08 | Poor Scanning | Medium |
| AST09 | No Governance | Medium |
| AST10 | Cross-Platform Reuse | Medium |

Artefactos formativos del proyecto (nombres de archivo del repo): `checklist.md`,
`universal-skill-format.md`, `case-studies.md`, `threat-intelligence.md`, `risk-assessment.md`,
`skill-scanner-integration.md`, `api-documentation.md`, `skill-development-guide.md`,
`platform-comparison.md`, `incident-response.md`, `metrics-monitoring.md`. Además hay
**vídeos tutoriales por riesgo** (`/videos?video=ast01`).
Mapeo declarado: **CSA MAESTRO** (modelo de amenazas de 7 capas).

**Lectura de cartógrafo**: AST10 es el ejemplo canónico de *formación que llega antes que el
estándar*. Es el único currículo que trata la **capa de comportamiento** (skills) como superficie
de ataque propia, distinta del modelo y de MCP. Y es directamente aplicable a `ethical-hacker-squad`,
que ES un skill de Claude Code.

---

### A.7 · OWASP Secure Agent Playbook — currículo ejecutable (17 skills / 6 agentes)
Fuente: https://github.com/OWASP/secure-agent-playbook
Licencia (LICENSE.md): **CC BY 4.0** (solo atribución, sin ShareAlike) ← la más permisiva del bloque.

Es un proyecto casi idéntico en forma a `ethical-hacker-squad`: plugin de Claude Code con skills
y subagentes. Su catálogo es, de facto, un temario de competencias:

**code-security-skills** (nombre de skill → referencia OWASP declarada)
`code-review-security` (Top 10, ASVS) · `sca-audit` (A06:2021) · `secrets-scan` (CWE-798) ·
`api-security-review` (API Top 10 2023) · `web-security-review` (Top 10 2021) ·
`mobile-code-review` (**MASVS v2.1.0**) · `iac-security-review` (CIS Benchmarks) ·
`securability-engineering` (FIASSE v1.0.4) · `securability-engineering-review` (SSEM 0-10) ·
`prd-securability-enhancement` (ASVS + FIASSE SSEM) · `security-guidance` (ASVS 5.0)

**ai-security-skills**
`agent-security-audit` (LLM Top 10) · `llm-risk-assess` (LLM Top 10 2025) ·
`agentic-ai-risk-assess` (**Agentic Top 10 2026**) · `mcp-server-review` ·
`prompt-injection-test` (**Arcanum PI Taxonomy**) · `multi-agentic-threat-model` (**CSA MAESTRO**)

**Agentes**: `code-security-reviewer` · `dependency-auditor` · `api-security-reviewer` ·
`mobile-security-reviewer` · `ai-security-assessor` · `security-team-lead`.
Trazabilidad declarada: CWE, ASVS, WSTG y NIST 800-53 vía **OpenCRE** (opencre.org).

---

### A.8 · OWASP Agent Observability Standard (AOS)
Fuente: https://github.com/OWASP/www-project-agent-observability-standard · https://aos.owasp.org
Licencia: **Apache 2.0** (badge y LICENSE.txt del repo).

Tres propiedades verificables que el estándar exige a un agente: **inspectable**, **traceable**,
**instrumentable**. Componentes:
1. Interacción Observed Agent ↔ Guardian Agent.
2. Trazado de eventos AOS con **OpenTelemetry** y **OCSF**.
3. **AgBOM** (Agent Bill of Materials) vía **CycloneDX / SWID / SPDX**.

---

### A.9 · MITRE ATLAS — matriz de tácticas/técnicas/mitigaciones para sistemas de IA
Fuente de datos: https://github.com/mitre-atlas/atlas-data (`dist/ATLAS-latest.yaml`,
`format-version 6.0.0`, `collection version 2026.07`, modified-date 2026-05-27)
Licencia (archivo LICENSE del repo): **Apache License 2.0**, "Copyright 2021-2026 MITRE".
⚠ El sitio https://atlas.mitre.org/ y `/matrices/ATLAS` devolvieron 404 / página vacía a WebFetch
(render por JS). Todo lo de abajo viene del repo de datos, no de la web.

**16 tácticas**
AML.TA0002 Reconnaissance · AML.TA0003 Resource Development · AML.TA0004 Initial Access ·
AML.TA0000 AI Model Access · AML.TA0005 Execution · AML.TA0006 Persistence ·
AML.TA0012 Privilege Escalation · AML.TA0007 Defense Evasion · AML.TA0013 Credential Access ·
AML.TA0008 Discovery · AML.TA0015 Lateral Movement · AML.TA0009 Collection ·
AML.TA0001 AI Attack Staging · AML.TA0014 Command and Control · AML.TA0010 Exfiltration ·
AML.TA0011 Impact

**178 técnicas y subtécnicas.** Subconjunto **agéntico/LLM** (el que no existe en ningún estándar
clásico y donde la formación va por delante):

- AML.T0051 LLM Prompt Injection → .000 Direct · .001 Indirect · .002 Triggered
- AML.T0054 LLM Jailbreak · AML.T0056 Extract LLM System Prompt · AML.T0057 LLM Data Leakage
- AML.T0065 LLM Prompt Crafting · AML.T0068 LLM Prompt Obfuscation
- AML.T0069 Discover LLM System Information → .000 Special Character Sets · .001 System Instruction
  Keywords · .002 System Prompt
- AML.T0067 LLM Trusted Output Components Manipulation → .000 Citations
- AML.T0077 LLM Response Rendering · AML.T0061 LLM Prompt Self-Replication
- AML.T0094 Delay Execution of LLM Instructions · AML.T0092 Manipulate User LLM Chat History
- AML.T0093 Prompt Infiltration via Public-Facing Application
- AML.T0062 Discover LLM Hallucinations · AML.T0060 Publish Hallucinated Entities
- AML.T0064 Gather RAG-Indexed Targets · AML.T0066 Retrieval Content Crafting
- AML.T0070 RAG Poisoning · AML.T0071 False RAG Entry Injection · AML.T0082 RAG Credential Harvesting
- AML.T0085 Data from AI Services → .000 RAG Databases · .001 AI Agent Tools
- AML.T0053 AI Agent Tool Invocation · AML.T0086 Exfiltration via AI Agent Tool Invocation
- AML.T0080 AI Agent Context Poisoning → .000 Memory · .001 Thread
- AML.T0081 Modify AI Agent Configuration · AML.T0083 Credentials from AI Agent Configuration
- AML.T0084 Discover AI Agent Configuration → .000 Embedded Knowledge · .001 Tool Definitions ·
  .002 Activation Triggers · .003 Call Chains
- AML.T0098 AI Agent Tool Credential Harvesting · AML.T0099 AI Agent Tool Data Poisoning
- AML.T0100 AI Agent Clickbait · AML.T0103 Deploy AI Agent · AML.T0108 AI Agent
- AML.T0110 AI Agent Tool Poisoning → .000 Definition and Instructions · .001 Implementation ·
  .002 Runtime Response
- AML.T0034 Cost Harvesting → .000 Excessive Queries · .001 Resource-Intensive Queries ·
  .002 Agentic Resource Consumption
- AML.T0112 Machine Compromise → .000 Local AI Agent · .001 AI Artifacts
- AML.T0018 Manipulate AI Model → .000 Poison AI Model · .001 Modify AI Model Architecture ·
  .003 Modify Prompt Construction Logic
- AML.T0002 Acquire Public AI Artifacts → .002 AI Agent Configuration
- AML.T0010 AI Supply Chain Compromise → .000 Hardware · .001 AI Software · .002 Data · .003 Model ·
  .004 Container Registry · .005 AI Agent Tool
- AML.T0011 User Execution → .000 Unsafe AI Artifacts · .001 Malicious Package ·
  .002 Poisoned AI Agent Tool · .003 Malicious Link
- AML.T0109 AI Supply Chain Rug Pull · AML.T0111 AI Supply Chain Reputation Inflation
- AML.T0115 Publish Poisoned AI Artifacts → .000 Datasets · .001 Models · .002 AI Agent Tools
- AML.T0024 Exfiltration via AI Inference API → .000 Infer Training Data Membership ·
  .001 Invert AI Model · .002 Extract AI Model
- AML.T0043 Craft Adversarial Data → .000 White-Box Optimization · .001 Black-Box Optimization ·
  .002 Black-Box Transfer · .003 Manual Modification · .004 Insert Backdoor Trigger
- AML.T0096 AI Service API · AML.T0114 AI Service Web Interface · AML.T0047 AI-Enabled Product/Service
- AML.T0029 Denial of AI Service · AML.T0031 Erode AI Model Integrity · AML.T0059 Erode Dataset Integrity
- AML.T0046 Spamming AI System with Chaff Data · AML.T0076 Corrupt AI Model
- AML.T0048 External Harms → .000 Financial · .001 Reputational · .002 Societal · .003 User ·
  .004 AI Intellectual Property Theft

**37 mitigaciones (AML.M00xx)** — la mitad final es puramente agéntica y es lo que un auditor
debería exigir como control:
M0000 Limit Public Release of Information · M0001 Limit Model Artifact Release ·
M0002 Predictive AI Output Obfuscation · M0003 Predictive AI Model Hardening ·
M0004 Limit AI Service Query Volume and Rate · M0005 Control Access to AI Models and Data at Rest ·
M0006 Predictive AI Ensembles · M0007 Sanitize Training Data · M0008 Validate AI Model ·
M0009 Predictive AI Multi-Sensor Fusion · M0010 Predictive AI Input Restoration ·
M0011 Restrict Library Loading · M0012 Encrypt Sensitive Information · M0013 Code Signing ·
M0014 Verify AI Artifacts · M0015 Predictive AI Adversarial Input Detection ·
M0016 Vulnerability Scanning · M0017 AI Model Distribution Methods · M0018 User Training ·
M0019 Control Access to AI Models and Data in Production · M0020 Generative AI Guardrails ·
M0021 Generative AI Guidelines · M0022 Generative AI Model Alignment · **M0023 AI Bill of Materials** ·
**M0024 AI Telemetry Logging** · M0025 Maintain AI Dataset Provenance ·
**M0026 Privileged AI Agent Permissions Configuration** ·
**M0027 Single-User AI Agent Permissions Configuration** ·
**M0028 AI Agent Tools Permissions Configuration** · **M0029 Human In-the-Loop for AI Agent Actions** ·
**M0030 Restrict AI Agent Tool Invocation on Untrusted Data** · **M0031 Memory Hardening** ·
**M0032 Segmentation of AI Agent Components** ·
**M0033 Input and Output Validation for AI Agent Components** · M0034 Deepfake Detection ·
**M0035 AI Red Team** · M0036 Limit AI Workload Resource Consumption

---

### A.10 · NIST AI RMF 1.0 + Playbook
Fuentes:
- Playbook (índice): https://airc.nist.gov/AI_RMF_Knowledge_Base/Playbook
- MEASURE: https://airc.nist.gov/AI_RMF_Knowledge_Base/Playbook/Measure
- MANAGE: https://airc.nist.gov/AI_RMF_Knowledge_Base/Playbook/Manage
- MAP: https://airc.nist.gov/AI_RMF_Knowledge_Base/Playbook/Map
- Política de derechos: https://www.nist.gov/oism/copyrights
Licencia: **obra del Gobierno de EE.UU. — información pública, se puede distribuir o copiar**
(nist.gov/oism/copyrights); se solicita crédito de autoría. Reutilizable sin copyleft.

Cuatro funciones: **GOVERN · MAP · MEASURE · MANAGE**. Cada subcategoría del Playbook trae siempre
los mismos 4 artefactos: *About* | *Suggested Actions* | *Transparency and Documentation* | *References*.
Recurso vivo, actualizado ~2 veces al año.

**MEASURE 1 — métodos y métricas**
- MEASURE 1.1 Enumeración de enfoques y métricas para los riesgos identificados en Map
- MEASURE 1.2 Idoneidad de métricas y eficacia de controles, evaluadas periódicamente
- MEASURE 1.3 Participación de expertos internos y/o evaluadores independientes

**MEASURE 2 — evaluación de características de confiabilidad**
- MEASURE 2.1 Documentación de conjuntos de prueba, métricas y herramientas TEVV
- MEASURE 2.2 Evaluaciones con sujetos humanos: requisitos aplicables y representatividad
- MEASURE 2.3 Criterios de rendimiento/garantía medidos para el entorno de despliegue
- MEASURE 2.4 Monitorización de funcionalidad y comportamiento en producción
- MEASURE 2.5 Validez, fiabilidad y límites documentados de generalización
- MEASURE 2.6 Evaluación periódica de riesgos de seguridad (safety) y riesgo residual aceptable
- **MEASURE 2.7 Seguridad y resiliencia del sistema de IA, evaluadas y documentadas** ← ancla del pentest
- MEASURE 2.8 Riesgos de transparencia y rendición de cuentas
- MEASURE 2.9 Explicación, validación y documentación del modelo
- MEASURE 2.10 Riesgo de privacidad examinado y documentado
- MEASURE 2.11 Equidad y sesgo evaluados y documentados

**MANAGE 1 — priorización y respuesta**
1.1 ¿Cumple el sistema su propósito? · 1.2 Priorización del tratamiento por impacto/probabilidad/recursos ·
1.3 Respuestas a riesgos de alta prioridad desarrolladas, planificadas y documentadas ·
1.4 Riesgo residual negativo documentado para adquirentes y usuarios finales

**MANAGE 2 — estrategias**
2.1 Recursos necesarios y alternativas no-IA · 2.2 Mecanismos para sostener el valor desplegado ·
2.3 Procedimientos de respuesta/recuperación ante riesgo previamente desconocido ·
**2.4 Mecanismos para sustituir, desconectar o desactivar sistemas de IA** ← kill-switch auditable

**MANAGE 3 — terceros**
3.1 Riesgos de recursos de terceros monitorizados; controles aplicados y documentados ·
**3.2 Modelos preentrenados monitorizados como parte del mantenimiento regular**

**MANAGE 4 — tratamiento, comunicación, mejora**
4.1 Planes de monitorización post-despliegue con captura de input de usuarios ·
4.2 Actividades medibles de mejora continua integradas en las actualizaciones ·
4.3 Incidentes y errores comunicados a los actores relevantes, incluidas comunidades afectadas

**MAP 1 — contexto**: 1.1 propósito y contexto · 1.2 actores interdisciplinares · 1.3 misión y metas
tecnológicas · 1.4 valor de negocio · 1.5 tolerancias al riesgo · 1.6 requisitos socio-técnicos
**MAP 2 — categorización**: 2.1 tarea y métodos · 2.2 límites de conocimiento y supervisión humana ·
2.3 integridad científica y consideraciones TEVV
**MAP 3 — capacidades, uso, beneficios y costes**: 3.1 beneficios · 3.2 costes de errores ·
3.3 alcance de aplicación · 3.4 competencia de operadores · 3.5 procesos de supervisión humana
**MAP 4 — riesgos por componente**: 4.1 mapeo de riesgos tecnológicos y legales · 4.2 controles
internos de riesgo por componente

> **NO VERIFICADO**: la función **GOVERN** completa no se abrió. MEASURE quedó truncada tras 2.11
> (faltan 2.12/2.13 si existen, y MEASURE 3.x y 4.x). MAP quedó truncada tras 4.2 (falta MAP 5.x).

---

### A.11 · NIST AI 600-1 — Generative AI Profile (julio 2024)
Fuente: https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.600-1.pdf (DOI 10.6028/NIST.AI.600-1)
Licencia: obra del Gobierno de EE.UU., información pública.

Estructura verificada del índice: **1. Introduction** (p.1) · **2. Overview of Risks Unique to or
Exacerbated by GAI** (p.2) · **3. Suggested Actions to Manage GAI Risks** (p.12) ·
**Appendix A. Primary GAI Considerations** (p.47) · **Appendix B. References** (p.54).

Los riesgos se agrupan en tres familias declaradas: (1) técnicos/del modelo, (2) **misuse by humans
(uso malicioso)**, (3) **ecosystem / societal risks (riesgos sistémicos)**.

Nombres de riesgo extraídos del PDF (secciones 2.1–2.12). Seis se leyeron literalmente; seis no
salieron del PDF por subsetting de fuentes en los títulos en negrita:

| § | Nombre | Estado |
|---|---|---|
| 2.1 | CBRN Information or Capabilities | verificado (parcial: "CBRN") |
| 2.2 | — | **NO VERIFICADO** (contenido: generación de información errónea/falsa ante prompts) |
| 2.3 | Dangerous, Violent Content | verificado |
| 2.4 | Data Privacy | verificado |
| 2.5 | Environmental Impacts | verificado |
| 2.6 | — | **NO VERIFICADO** (contenido: sesgo y homogeneización) |
| 2.7 | — | **NO VERIFICADO** (contenido: configuración humano-IA, aversión algorítmica / sobre-confianza) |
| 2.8 | — | **NO VERIFICADO** (contenido: integridad de la información, des/misinformación a escala) |
| 2.9 | — | **NO VERIFICADO** (contenido: seguridad de la información; menciona prompt injection y poisoning) |
| 2.10 | Intellectual Property | verificado |
| 2.11 | Obscene, Degrading, and/or Abusive Content | verificado |
| 2.12 | — | **NO VERIFICADO** (contenido: cadena de valor y componentes de terceros) |

No se reconstruyen los nombres faltantes de memoria.

---

### A.12 · OWASP GenAI Red Teaming Guide
Fuente: https://genai.owasp.org/resource/genai-red-teaming-guide/ — licencia del sitio: CC BY-SA 4.0.

Único dato estructural verificado en la página: el enfoque holístico en **cuatro áreas**:
*model evaluation*, *implementation testing*, *infrastructure assessment*, *runtime behavior analysis*.

> **NO VERIFICADO**: el índice de capítulos del PDF. La landing no lo enumera y el PDF no se abrió.

Complemento verificado — **GenAI Red Team Handbook** (repo, entorno de laboratorio real):
https://github.com/OWASP/www-project-top-10-for-large-language-model-applications/tree/main/initiatives/genai_red_team_handbook
Estructura: `exploitation/` + `sandboxes/RAG_local` + `sandboxes/llm_local` + `tools/`.
Stack declarado: Podman, Ollama, Python 3.10+, uv, Make, Gradio (:7860), FastAPI (:8000),
Node 18+/npx para **Promptfoo**. Licencia: CC BY-SA 4.0 (LICENSE.md del repo).

---

### A.13 · OWASP AI Exchange
Fuente: https://owaspai.org/ — ⚠ **licencia NO declarada en la página** (ver sección de licencias).

Ocho secciones declaradas: 1) AI Security Overview · 2) General Controls ·
3) Input Threats and Controls · 4) Development-time Threats and Controls ·
5) Runtime Conventional Security Threats · 6) AI Security Testing · 7) AI Privacy · 8) References.
Categorías de amenaza nombradas: evasion, prompt injection, sensitive data disclosure,
model exfiltration, resource exhaustion, culture-sensitivity.

> **NO VERIFICADO**: IDs de controles y licencia. No se reutiliza nada de esta fuente hasta aclararlo.

---

### A.14 · Microsoft Learn — AI Red Teaming Agent (Microsoft Foundry)
Fuente: https://learn.microsoft.com/en-us/azure/ai-foundry/concepts/ai-red-teaming-agent
Repo de docs: https://github.com/MicrosoftDocs/azure-ai-docs → licencia **CC BY 4.0**.
Fecha del artículo: 2026-04-22 (actualizado 2026-05-18).

Es el currículo profesional "tipo Microsoft Learn" del área. Encuadre declarado: se apoya en
**NIST AI RMF (Govern/Map/Measure/Manage)** y en **PyRIT** (github.com/microsoft/PyRIT).
Métrica central: **Attack Success Rate (ASR)**.

**Categorías de riesgo soportadas** (y si aplican a modelo o a agente):
- Hateful and Unfair Content — modelo y agentes
- Sexual Content — modelo y agentes
- Violent Content — modelo y agentes
- Self-Harm-Related Content — modelo y agentes
- Protected Materials — modelo y agentes
- **Code vulnerability** — modelo y agentes (código generado con inyección, tar-slip, SQLi, exposición
  de stack traces; Python, Java, C++, C#, Go, JavaScript, SQL)
- **Ungrounded attributes** — inferencias no fundamentadas sobre atributos personales
- **Prohibited actions** — solo agentes, solo cloud
- **Sensitive data leakage** — solo agentes, solo cloud
- **Task adherence** — solo agentes, solo cloud

**Riesgos agénticos** (tres dimensiones evaluadas en *task adherence*): goal achievement ·
rule compliance · procedural discipline.
**Taxonomía de acciones** en *prohibited actions*: Prohibited Actions (nunca permitidas) ·
High-Risk Actions (con human-in-the-loop) · Irreversible Actions (con divulgación + confirmación).
**XPIA** — Indirect Prompt Injected Attacks / Cross-Domain Prompt Injected Attacks: inyección en
salidas de herramientas y contexto recuperado.
Recomendación operativa declarada: ejecutar en un ***purple environment*** (entorno no productivo
con recursos equivalentes a producción).

**Estrategias de ataque soportadas (de PyRIT)** — nombres exactos:
AnsiAttack · AsciiArt · AsciiSmuggler · Atbash · Base64 · Binary · Caesar · CharacterSpace ·
CharSwap · Diacritic · Flip · Leetspeak · Morse · ROT13 · SuffixAppend · StringJoin ·
UnicodeConfusable · UnicodeSubstitution · Url · Jailbreak (UPIA) · Indirect Jailbreak (XPIA) ·
Tense · Multi turn · Crescendo

**Limitaciones declaradas** (útiles como "qué descarta un falso positivo"): datos sintéticos no
representativos de distribuciones reales; mock tools no simulan comportamientos; sin sandbox
totalmente aislado; solo población adversaria, sin población observacional; el evaluador es
generativo → **no determinista**, con falsos positivos, revisión humana recomendada.
Cobertura de agentes: soportados agentes hospedados en Foundry (prompt y contenedor) y llamadas a
herramientas Azure; **no soportados** workflow agents, agentes no-Foundry, herramientas no-Azure,
function calls, browser automation, connected agents, computer use.

---

### A.15 · Cursos de red teaming de LLM de acceso público — estado real
- **DeepLearning.AI — "Red Teaming LLM Applications"**
  https://learn.deeplearning.ai/courses/red-teaming-llm-applications
  Lecciones (en orden): 1 Introduction · 2 Overview of LLM Vulnerabilities · 3 Red Teaming LLMs ·
  4 Red Teaming at Scale · 5 Red Teaming LLMs with LLMs · 6 A Full Red Teaming Assessment ·
  7 Conclusion · 8 Quiz.
  ⚠ **Ya no es simplemente gratuito**: la página ofrece prueba de 7 días y después ~1 USD/mes
  (existe modo "Audit"). Términos de uso propietarios → solo se citan títulos de lección como hecho.
- **OWASP GenAI Red Team Handbook** (A.12) — este sí es gratuito, abierto y ejecutable. Es el
  sustituto recomendado de un "curso" de red teaming de LLM.
- **FinBot Agentic AI CTF** (A.1) — laboratorio agéntico gratuito publicado por OWASP.

> **NO VERIFICADO**: no se buscaron ni abrieron otros cursos (NVIDIA DLI, Learn Prompting/HackAPrompt,
> UK AISI Inspect). Presupuesto de búsqueda conservado; no se afirma nada sobre ellos.

---

## BLOQUE B — Seguridad móvil

### B.0 · Licencia del proyecto OWASP MAS
Repos verificados por API: `OWASP/owasp-mastg` → **CC-BY-SA-4.0** · `OWASP/masvs` → **CC-BY-SA-4.0**.
Sitio: https://mas.owasp.org

### B.1 · MASVS v2 — 8 categorías, 24 controles
Fuente: https://mas.owasp.org/MASVS/

- **MASVS-STORAGE** (Storage): STORAGE-1, STORAGE-2
- **MASVS-CRYPTO** (Cryptography): CRYPTO-1, CRYPTO-2
- **MASVS-AUTH** (Authentication and Authorization): AUTH-1, AUTH-2, AUTH-3
- **MASVS-NETWORK** (Network Communication): NETWORK-1, NETWORK-2
- **MASVS-PLATFORM** (Platform Interaction): PLATFORM-1, PLATFORM-2, PLATFORM-3
- **MASVS-CODE** (Code Quality): CODE-1..CODE-4
- **MASVS-RESILIENCE** (Resilience Against Reverse Engineering and Tampering): RESILIENCE-1..4
- **MASVS-PRIVACY** (Privacy): PRIVACY-1..PRIVACY-4

> **NO VERIFICADO**: los títulos textuales de cada control MASVS-*-n. La web renderiza solo los IDs
> en el índice. Se usa MASWE (B.2) como mapa temático, que sí está completo.

### B.2 · MAS Testing Profiles — los "niveles" del currículo móvil
Fuente: https://github.com/OWASP/owasp-mastg/blob/master/Document/0x03b-Testing-Profiles.md

Dos grupos: **seguridad (L1, L2, R)** y **privacidad (P)**.
- **MAS-L1 — Essential Security**. Línea base para todas las apps. Asume: los controles del SO son
  confiables (dispositivo no rooteado/jailbroken); el usuario principal NO es adversario; **las otras
  apps del dispositivo SÍ son adversarias**. Para apps con datos de bajo riesgo y sin funcionalidad sensible.
- **MAS-L2 — Advanced Security**. Extiende L1. Asume: **los controles del SO NO son confiables**
  (dispositivo rooteado/jailbroken); usuario principal no adversario; otras apps adversarias;
  **un tercero con o sin acceso físico es adversario**. Para apps con datos de alto riesgo y
  funcionalidad sensible.
- **MAS-R — Resilient Security**.
- **MAS-P — Baseline Privacy profile**.
Uso declarado: assessment, secure-by-design, cumplimiento/gestión de riesgo y **app vetting**
(referencia cruzada: NIST SP 800-163r1, *Vetting the Security of Mobile Applications*).

### B.3 · MASWE — catálogo de 78 debilidades (el mapa temático real)
Fuente: https://mas.owasp.org/MASWE/

**MASVS-STORAGE** — 0001 Sensitive Data Stored Unencrypted in Private Storage · 0002 …Outside of
Private Storage · 0003 Cryptographic Keys Stored Outside of Platform Keystore · 0004 Sensitive Data
Hardcoded in the App Package · 0005 Insertion of Sensitive Data into Logs · 0006 Sensitive Data Not
Excluded From Backup

**MASVS-CRYPTO** — 0007 Improper Encryption · 0008 Improper Hashing · 0009 Improper Use of MAC ·
0010 Improper Generation of Cryptographic Signatures · 0011 Improper Verification of Cryptographic
Signature · 0012 Improper Random Number Generation · 0013 Improper Cryptographic Key Generation ·
0014 Improper Cryptographic Key Derivation · 0015 Cryptographic Key Rotation Not Implemented ·
0016 Cryptographic Key Access Not Restricted · 0017 Device Secure Lock Not Enforced

**MASVS-AUTH** — 0018 Lack of Authentication or Authorization on App Components · 0019 Lack of
Auto-fill Support for Credential Providers · 0020 Local Authentication Can Be Bypassed ·
0021 Fallback to Non-biometric Credentials Allowed for Sensitive Transactions · 0022 Crypto Keys Not
Invalidated on New Biometric Enrollment · 0023 Step-Up Authentication Not Implemented for Sensitive
Actions · 0024 Sensitive Data Accessible After Session Termination · 0025 Lack of Non-Repudiation
for Critical Actions

**MASVS-NETWORK** — 0026 Network Traffic Not Encrypted · 0027 Insecure Certificate Validation ·
0028 Insecure Identity Pinning

**MASVS-PLATFORM** — 0029 Insecure Deep Links · 0030 Improper Use of the Clipboard ·
0031 Allowing Untrusted App Extensions · 0032 Insecure Intents · 0033 Sensitive Native Functionality
Exposed in WebViews · 0034 WebViews Allow Access to Local Resources with Untrusted Content ·
0035 WebViews Loading Untrusted Content · 0036 Unnecessary Exposure of Sensitive Data via the UI ·
0037 …via Notifications · 0038 Insufficient Protection of Sensitive Data from Screenshots or Screen
Recordings · 0039 App Vulnerable to Overlay Attacks · 0040 Sensitive Data Leaked via Accessibility Services

**MASVS-CODE** — 0041 Running on a Recent Platform Version Not Ensured · 0042 Latest Platform Version
Not Targeted · 0043 Enforced Updating Not Implemented · 0044 Dependencies with Known Vulnerabilities ·
0045 Compiler-Provided Security Features Not Used · 0046 Use of Deprecated APIs or Functionality ·
0047 Using Non-Standard APIs for Security-Critical Functionality · 0048 Malicious Code Included in
the App · 0049 Unsafe Dynamic Code Loading · 0050 Unsafe Handling of Untrusted Data

**MASVS-RESILIENCE** — 0051 Root/Jailbreak Detection Not Implemented · 0052 App Virtualization
Environment Detection Not Implemented · 0053 Emulated or Virtual Device Detection Not Implemented ·
0054 Device Attestation Not Implemented · 0055 Malware Detection Not Implemented · 0056 App
Attestation Not Implemented · 0057 App Resources Integrity Not Verified · 0058 Runtime Code Integrity
Not Verified · 0059 Code Obfuscation Not Implemented · 0060 Resource Obfuscation Not Implemented ·
0061 Debug Artifacts Not Removed · 0062 No Application-Level Payload Encryption · 0063 Debug
Mechanisms Not Disabled · 0064 Debugger Detection Not Implemented · 0065 Dynamic Analysis Tools
Detection Not Implemented

**MASVS-PRIVACY** — 0066 Inadequate Permission Management · 0067 Lack of Anonymization or
Pseudonymisation Measures · 0068 Incorrect Use of Identifiers for User Tracking · 0069 Usage of
Non-Privacy-Preserving Functionality · 0070 Inadequate Awareness for Privacy Relevant Actions ·
0071 Inadequate Defaults for Privacy Relevant Actions · 0072 Inadequate Privacy Policy ·
0073 Inadequate Data Collection Declarations · 0074 Inadequate Tracking Domains Declarations ·
0075 Non-Reproducible Builds · 0076 Lack of Proper Data Management Controls · 0077 Inadequate Data
Visibility Controls · 0078 Inadequate or Ambiguous User Consent Mechanisms

### B.4 · MASTG — estructura del cuerpo formativo
Fuente: https://mas.owasp.org/MASTG/ y repo https://github.com/OWASP/owasp-mastg

Secciones: Intro · General Concepts · Android Security Testing · iOS Security Testing ·
Best Practices · Knowledge · Tests · Demos.
Tipos de contenido e IDs: **MASTG-TEST** (pruebas) · **MASTG-KNOW** (conocimiento, 141 archivos) ·
**MASTG-BEST** (buenas prácticas, 74) · **MASTG-DEMO** (demos con herramientas) ·
**MASTG-TECH** (técnicas, 167).

Volumen medido en el repo (clon disperso, agosto 2026):
- `techniques/`: 78 Android + 76 iOS + 13 genéricas = **167 técnicas**
- `tests/` (v1): **92 pruebas** (51 Android + 41 iOS)
- `tests-beta/` (**v2, en construcción**): **200 pruebas**, cada una con campo `weakness:` que la
  ata a un MASWE
- `best-practices/`: **74**

### B.5 · MASTG-TECH — técnicas de testing (currículo de "cómo se hace")
Genéricas: 0047 Reverse Engineering · 0048 Static Analysis · 0049 Dynamic Analysis ·
0050 Binary Analysis · 0051 Tampering and Runtime Instrumentation · 0071 Retrieving Strings ·
0119 Intercepting HTTP Traffic by Hooking Network APIs at the Application Layer ·
0120 Intercepting HTTP Traffic Using an Interception Proxy · 0121 Intercepting Non-HTTP Traffic
Using an Interception Proxy · 0122 Passive Eavesdropping · 0123 Achieving a MITM Position via ARP
Spoofing · 0124 Achieving a MITM Position Using a Rogue Access Point · 0125 Intercepting Xamarin Traffic

Android (selección de las que marcan nivel experto o son recientes): 0012 Bypassing Certificate
Pinning · 0016 Disassembling Code to Smali · 0018 Disassembling Native Code · 0026 Dynamic Analysis
on Non-Rooted Devices · 0031-0035 Debugging / Execution, Method, Native Code y JNI Tracing ·
0036 Emulation-based Analysis · 0037 Symbolic Execution · 0038 Patching · 0039 Repackaging &
Re-Signing · 0041 Library Injection · 0043 Method Hooking · 0044 Process Exploration ·
0045 Runtime Reverse Engineering · **0108 Taint Analysis** · **0109 Intercepting Flutter HTTPS
Traffic** · 0115 Obtaining Compiler-Provided Security Features · 0116 APK Signature Info ·
0117/0141/0150 AndroidManifest (obtener / merged / analizar) · 0126 App Permissions ·
0127/0128 Backup data · **0129 Verifying Android Dependencies at Runtime** ·
**0130 SCA creando un SBOM** · **0131 SCA en build time** · 0140 Debugging Information and Symbols ·
0142 Inspecting WebView Storage · 0143 Monitor File System Operations in WebViews ·
0144 Bypassing Root Detection · **0145 Working with XAPK Files** · 0148 Interacting with
ContentProviders · 0151 Analyzing the Network Security Configuration · **0156 Reverse Engineering
Flutter Applications** · 0157 Extracting Bundled Native Libraries · 0159 File-Based Content Providers ·
0160-0163 Enumerating Activities/Services/Broadcast Receivers/Content Providers ·
0164 Sniffing Implicit Intents and Broadcasts · **0165 Identifying Compilers, Obfuscators, and
Packers** · **0172 Listing Deep Links** · **0173 Monitoring Deep Link Handlers at Runtime with
Frida** · **0174 Verifying App Link Website Association**

iOS (idem): 0061 Dumping KeyChain Data · 0064 Bypassing Certificate Pinning · 0079 Developer
Provisioning Profile · 0088 Emulation-based Analysis · 0089 Symbolic Execution ·
0090 Injecting Frida Gadget into an IPA Automatically · 0091 Injecting Libraries into an IPA
Manually · 0092 Signing IPA files · 0098 Patching React Native Apps · 0110 Intercepting Flutter
HTTPS Traffic · 0111 Extracting Entitlements from MachO Binaries · 0112 Code Signature Format
Version · 0113/0114 Debugging Symbols / Demangling · **0132 SCA creando un SBOM** ·
**0133 SCA escaneando artefactos de gestores de paquetes** · 0134 Monitoring the Pasteboard ·
**0135 Bypassing Biometric Authentication** · **0136/0137 Retrieving y Analyzing
PrivacyInfo.xcprivacy Files** · 0139 Attach to WKWebView · 0146 Dynamic Analysis on Non-Jailbroken
Devices · **0149 Validating ATS TLS Settings at Runtime Using nscurl** · 0152 Bypassing Jailbreak
Detection · 0153/0154/0155 Info.plist y ATS · 0158 Extracting Loaded Libraries ·
**0166 Identifying Custom URL Scheme Registrations** · **0167/0168 Monitoring UIActivity Data
Sharing / Receiving** · 0169 Opening Deep Links · **0170 Enumerating App Extensions** ·
**0171 Monitoring Data Sharing Between App Extensions and Containing Apps** ·
**0175 Verifying Universal Link Domain Association** · **0176 Monitoring Universal Link Handlers at
Runtime with Frida**

### B.6 · MASTG v2 (tests-beta) — dónde la formación va por delante del estándar
200 pruebas nuevas, cada una atada a un MASWE, con un patrón declarativo repetido que es en sí una
metodología: **"References to <API>"** (estático) vs **"Runtime Use of <API>"** (dinámico) vs
**"<observación> in Network Traffic"** (red). Ese triple es el andamio del currículo v2.

Bloques temáticos que solo existen en v2 (muestra de IDs reales):
- **Biometría fina (Android)**: 0326 fallback a no-biométrico · 0327 event-bound · 0328 detección de
  cambios de enrolamiento · 0329 auth sin acción explícita del usuario · 0330 claves con validez extendida
- **WebView bridges iOS**: 0376 native bridge APIs · 0377 `evaluateJavaScript` como respuesta de
  bridge en `WKScriptMessageHandler` · 0378 campos de contraseña en HTML cargado en WebView ·
  0379 `evaluateJavaScript` sin aislamiento de content world · 0380 escritura de datos sensibles en
  el DOM del WebView
- **Pasteboard iOS**: 0276-0280 (uso del general pasteboard, contenido en runtime, no borrado, sin
  expiración, no restringido al dispositivo local)
- **Deep links / App Links / Universal Links**: 0393 app links no verificados · 0394 (Android) y
  0370/0371 (iOS) validación de entrada y de la app origen en custom URL schemes ·
  0395 universal link handlers
- **SBOM y dependencias**: 0272/0274 (Android), 0273/0275 (iOS)
- **Privacidad declarativa**: 0206 PII no declarada en captura de tráfico · 0281 dominios de tracking
  no declarados (iOS) · 0318/0319 SDKs que manejan datos sensibles ·
  0360/0361 exactitud de purpose strings · 0362/0363 entitlements con capacidades injustificadas ·
  0390 teclado personalizado con full access
- **TLS moderno iOS**: 0342 excepciones débiles de ATS · 0343 URLSession · 0344 Network.framework ·
  0345 pila TLS embebida o de terceros
- **Hooking/anti-tamper**: 0341/0354 detección de hooks · 0387/0338 storage integrity ·
  0368/0369/0391 suficiencia de la ofuscación

### B.7 · MASTG-BEST — remediación (74 buenas prácticas)
Muestra representativa, agrupada por lo que resuelve:
- Anti-captura: 0014 Preventing Screenshots and Screen Recording · 0015 `setRecentsScreenshotEnabled` ·
  0016 `SECURE_FLAG` · 0017 `setSecure` en SurfaceViews · 0018 `SecureFlagPolicy.SecureOn` en Compose
- Biometría: 0031 Enforce Strong Biometrics · 0036 Cryptographic Binding · 0037 Invalidate Biometric
  Keys on Enrollment Changes · 0038 Require Explicit User Confirmation
- IPC Android: 0039 Prevent SQL Injection in ContentProviders · 0049 Restrict and Validate Access to
  Exported Content Providers · 0052 Restrict Access to App Components · 0056 Use Explicit Intents ·
  0063 Use Immutable PendingIntents · 0057 Sanitize Data Coming from External Components
- WebViews: 0011/0033 Securely Load File Content · 0012 Disable JavaScript · 0013 Disable Content
  Provider Access · 0028 Cache Cleanup · 0032 Migrate from UIWebView to WKWebView · 0034 Validate
  WebView Input · 0035 Prefer Origin Scoped Messaging Over Legacy JavaScript Bridges ·
  0058 Restrict Native Functionality Exposed Through WebView Bridges · 0059/0060 Render Sensitive
  UI/entrada como vistas nativas sobre el WebView · 0061 `WKContentWorld` Isolation ·
  0062 `WKScriptMessageHandlerWithReply`
- Enlaces: 0070 Verify Android App Links with autoVerify and Digital Asset Links ·
  0071/0072 Validate Input Parameters in Deep Link / Universal Link Handlers ·
  0054/0055 Validate Input Parameters y Source Application en Custom URL Scheme Handlers
- Resiliencia: 0029 Implementing Resilience and RASP Signals · 0030 Implementing Root Detection ·
  0041 Hardening Against Runtime Hooking · 0046 Hardening Against Emulation ·
  0047 Continuous Anti-Debugging Checks · 0048 Hardening Against Reverse Engineering Tools ·
  0053 Hardening Against Virtual Devices · 0065/0066 Storage Integrity Checks ·
  0067 Source Code Integrity Checks (iOS) · 0074 Anti-Debugging Checks (iOS)
- Red iOS: 0042 Strong TLS Settings in ATS · 0043 Enforce Strong TLS When ATS Doesn't Apply ·
  0073 Properly Validate Server Trust in `URLSessionDelegate` y `WKNavigationDelegate`
- Otros: 0021 Ensure Proper Error and Exception Handling · 0040 Preventing Overlay Attacks ·
  0045 Limit Sensitive Data Exposure Through iOS IPC Channels · 0051 Minimize iOS Permissions and
  Entitlements · 0064 Use Safe APIs for Object Deserialization · 0068 Secure Data Sharing Between
  App Extensions and Containing Apps · 0069 Keep Sensitive Input on the System Keyboard

### B.8 · OWASP Mobile Top 10 — 2024
Fuente: https://owasp.org/www-project-mobile-top-10/ — licencia del sitio: CC BY-SA 4.0
(el repo `OWASP/www-project-mobile-top-10` no tiene archivo LICENSE; rige el footer del sitio).

M1 Improper Credential Usage · M2 Inadequate Supply Chain Security ·
M3 Insecure Authentication/Authorization · M4 Insufficient Input/Output Validation ·
M5 Insecure Communication · M6 Inadequate Privacy Controls · M7 Insufficient Binary Protections ·
M8 Security Misconfiguration · M9 Insecure Data Storage · M10 Insufficient Cryptography

### B.9 · Ruta de aprendizaje pública Android (oficial)
Fuente: https://developer.android.com/privacy-and-security/security-tips
Licencia (https://developer.android.com/license): documentación y ejemplos de código bajo
**Apache 2.0**; el resto del contenido del sitio bajo **CC BY 2.5**.

Temario, en el orden de la página: 1 Authentication · 2 App integrity · 3 Data storage
(internal / external / content providers) · 4 Permissions (requests / definitions) ·
5 Networking (IP / telephony) · 6 Input validation · 7 User data · 8 WebView ·
9 Credential requests (minimize credential exposure / use secure authentication / practice secure
account management / stay vigilant) · **10 API key management (generation and storage / usage and
access control / key rotation and expiration / general best practices)** · 11 Cryptography ·
12 Interprocess communication (intents / services / binder and messenger interfaces / broadcast
receivers) · 13 Security with dynamically loaded code · 14 Security in a virtual machine ·
15 Security in native code

> **NO VERIFICADO**: no se abrió ninguna ruta oficial de Apple (Apple Platform Security). No se
> afirma nada sobre el temario de iOS del lado del fabricante.

---

## Dónde la formación va por delante del estándar (síntesis del área)

1. **Skills de agente como superficie de ataque propia** — AST01..AST10. No existe en LLM Top 10,
   ni en MCP Top 10, ni en NIST. Es la capa de *comportamiento*, entre el modelo y las herramientas.
2. **Envenenamiento de herramientas en tres puntos distintos** — ATLAS AML.T0110 separa
   *definition and instructions* / *implementation* / *runtime response*. MCP03 "Tool Poisoning" los
   trata como uno solo.
3. **Memoria y contexto como estado persistente atacable** — ATLAS AML.T0080 (.000 Memory / .001
   Thread), AML.T0092 (historial de chat), ASI06. Mitigación M0031 "Memory Hardening". Ningún
   estándar clásico modela estado persistente de agente.
4. **Rug pull y reputación inflada en el suministro de IA** — AML.T0109 y AML.T0111. Es supply chain
   con dimensión temporal y social, no un CVE.
5. **AgBOM / AIBOM** — AOS + M0023 + OWASP AIBOM Generator. El SBOM tradicional no describe modelos,
   herramientas ni permisos de un agente.
6. **ASR como métrica y su no-determinismo** — Microsoft Learn documenta explícitamente que el
   evaluador es generativo y produce falsos positivos. Es la regla de descarte que un procedimiento
   de auditoría necesita.
7. **Móvil v2: el triple estático / runtime / red** — MASTG tests-beta convierte cada debilidad en
   tres pruebas independientes. Es una metodología de verificación, no una checklist.
8. **Privacidad declarativa móvil verificable** — `PrivacyInfo.xcprivacy`, dominios de tracking
   declarados, exactitud de purpose strings, entitlements injustificados. El estándar habla de
   "privacidad"; la formación ya sabe qué archivo abrir.
9. **Bridges de WebView modernos** — content worlds, `WKScriptMessageHandlerWithReply`, mensajería
   con scope de origen. MASVS-PLATFORM-3 lo cubre en una frase; MASTG v2 en ~10 pruebas.
10. **Deep links verificados criptográficamente** — Digital Asset Links / autoVerify y asociación de
    dominio de Universal Links, con técnica de verificación en runtime con Frida.

---

## Fuera de alcance (auditoría autorizada, no armamento)

Se registran, con su razón, para que nadie los reintroduzca por descuido:

- **AML.T0101 Data Destruction via AI Agent Tool Invocation** — destructivo. Un audit no borra datos
  del cliente. Se sustituye por verificación de que existe confirmación humana (M0029) y de que la
  acción es reversible/auditable.
- **Táctica AML.TA0007 Defense Evasion** y AML.T0107 Exploitation for Defense Evasion,
  AML.T0097 Virtualization/Sandbox Evasion — evasión de defensas. Un auditor no oculta su rastro:
  al contrario, deja traza.
- **AML.T0072 Reverse Shell**, **AML.T0090 OS Credential Dumping**, **AML.T0113 Steal Web Session
  Cookie**, **AML.T0106 Exploitation for Credential Access**, **AML.T0105 Escape to Host** —
  post-explotación real sobre infraestructura. Fuera del alcance de un audit de aplicación/agente.
- **AML.T0088 Generate Deepfakes** y **AML.T0052.001 Deepfake-Assisted Phishing** — producción de
  material de suplantación. Solo se admite el lado defensivo (M0034 Deepfake Detection).
- **AML.T0102 Generate Malicious Commands**, **AML.T0018.002 Embed Malware**,
  **AML.T0115 Publish Poisoned AI Artifacts**, **AML.T0011.001 Malicious Package** — creación y
  publicación de artefactos maliciosos. Se audita la *detección*, nunca la autoría.
- **NIST AI 600-1 §2.1 CBRN Information or Capabilities** — uplift de capacidades químicas,
  biológicas, radiológicas o nucleares. Se verifica que el sistema rechaza; jamás se genera el contenido.
- **Categorías de contenido dañino de Microsoft Learn** (Hateful and Unfair, Sexual, Violent,
  Self-Harm-Related, Obscene/Degrading/Abusive de NIST §2.11) — son categorías de *evaluación de
  guardarraíles*. Se comprueba que el sistema rehúsa; no se produce ni se almacena el contenido.
- **Estrategias PyRIT como generadores de contenido dañino** (Jailbreak, Crescendo, Multi turn,
  y los codificadores Base64/ROT13/Morse/UnicodeConfusable…) — se admiten únicamente como
  *transformaciones de payload de prueba* contra un sistema propio y autorizado, para medir robustez
  de filtros. No como receta para extraer contenido prohibido de sistemas de terceros.
- **MASWE-0048 Malicious Code Included in the App** — se audita la presencia; no se escribe.
- **Bypass de root/jailbreak/pinning/biometría de MASTG** (TECH-0012, 0064, 0135, 0144, 0152) —
  **SÍ están dentro de alcance** cuando el objetivo es la app del cliente bajo autorización escrita:
  son la forma canónica de verificar MASVS-RESILIENCE. Quedan **fuera** cuando el objetivo es una app
  de terceros. La distinción es el alcance autorizado, no la técnica.
- **AST10 / ClawHavoc: autoría de skills maliciosas** — el proyecto documenta 1.184 skills maliciosas
  y payloads confirmados. Se usa como inteligencia para *escanear*; nunca como plantilla para escribir.

---

## Registro de licencias (verificado fuente por fuente)

| Fuente | Licencia verificada | Cómo se verificó | Qué se puede citar | Qué NO |
|---|---|---|---|---|
| genai.owasp.org (todo el sitio) | CC BY-SA 4.0 | footer de la página | IDs, títulos, fechas, estructura | reproducir redacción (ShareAlike contaminaría el repo MIT) |
| OWASP LLM Top 10 (repo) | CC BY-SA 4.0 | `LICENSE.md` del repo | LLM01..LLM10, nombres de archivo | copiar el texto de los riesgos |
| OWASP Agentic Top 10 / ASI (mismo repo) | CC BY-SA 4.0 | `LICENSE.md` del repo | ASI01..ASI10 y los 16 candidatos | contenido de los .md |
| OWASP AI Testing Guide | CC BY-SA 4.0 | `LICENSE.md` del repo | AITG-APP/MOD/INF/DAT-nn y sus títulos | el cuerpo de cada test |
| OWASP Agentic Skills Top 10 | CC BY-SA 4.0 | `LICENSE.md` + badge | AST01..AST10, severidades, nombres de artefactos | texto de ast01..ast10 |
| **OWASP MCP Top 10** | **CC BY-NC-SA 4.0** | README del repo | MCP01..MCP10 (IDs+títulos) y enlace | ⚠ **NO comercial + ShareAlike**: no se copia NADA de su texto ni se deriva. Incompatible con un repo MIT de uso libre |
| OWASP Secure Agent Playbook | **CC BY 4.0** | `LICENSE.md` del repo | todo, con atribución | (la más permisiva; aun así conviene citar y no copiar) |
| OWASP Agent Observability Standard | Apache 2.0 | badge + `LICENSE.txt` | todo, con atribución + NOTICE | — |
| OWASP MASTG | CC-BY-SA-4.0 | GitHub API `repos/OWASP/owasp-mastg/license` | MASTG-TEST/TECH/BEST/KNOW IDs y títulos | el cuerpo de las pruebas |
| OWASP MASVS | CC-BY-SA-4.0 | GitHub API `repos/OWASP/masvs/license` | IDs de categoría y control | texto de los controles |
| OWASP MASWE | CC-BY-SA-4.0 (proyecto MAS) | licencia del proyecto MAS | MASWE-0001..0078 IDs+títulos | descripciones |
| OWASP Mobile Top 10 | CC BY-SA 4.0 (footer del sitio) | footer owasp.org; el repo NO tiene LICENSE | M1..M10 | descripciones |
| **MITRE ATLAS (atlas-data)** | **Apache License 2.0**, © 2021-2026 MITRE | archivo `LICENSE` del repo leído íntegro | tácticas, técnicas, mitigaciones: IDs, nombres **y descripciones**, con atribución + NOTICE | nada relevante; es la fuente más reutilizable del área |
| **NIST** (AI RMF Playbook, AI 600-1) | Obra del Gobierno de EE.UU.; información pública, distribuible y copiable | https://www.nist.gov/oism/copyrights | todo; se solicita crédito de autoría | material marcado explícitamente como copyrighted dentro del documento |
| **Microsoft Learn** (azure-ai-docs) | **CC BY 4.0** | GitHub API `repos/MicrosoftDocs/azure-ai-docs/license` | categorías de riesgo, estrategias PyRIT, métricas, limitaciones — con atribución | marcas, logos y nombres de producto de Microsoft (trademark, no copyright) |
| developer.android.com | Documentación y código: **Apache 2.0**; resto del sitio: **CC BY 2.5** | https://developer.android.com/license | encabezados de sección, estructura | — |
| **DeepLearning.AI** | **Términos de uso propietarios**; ya no es gratis (prueba 7 días, ~1 USD/mes, modo Audit) | pie de la página del curso | títulos de lección como hecho | cualquier material del curso |
| **OWASP AI Exchange** | **NO VERIFICADA** | la página no declara licencia y no se localizó el repo | nada por ahora, salvo el nombre de las 8 secciones como hecho | todo lo demás, hasta aclarar |

**Regla operativa derivada**: para un repo **MIT**, las fuentes seguras de las que *derivar* texto
son **MITRE ATLAS (Apache 2.0)**, **NIST (dominio público)**, **Microsoft Learn (CC BY 4.0)**,
**OWASP Secure Agent Playbook (CC BY 4.0)**, **AOS (Apache 2.0)** y **developer.android.com
(Apache 2.0)**. De todo lo **CC BY-SA** (la mayor parte de OWASP, incluido MAS) se citan **IDs,
nombres y estructura** como hechos, con enlace y atribución, y se escribe redacción propia. De
**MCP Top 10 (BY-NC-SA)** solo IDs, títulos y enlace, nunca derivación.

---

## Ficheros de trabajo generados

- `ATLAS-latest.yaml` — MITRE ATLAS, `format-version 6.0.0`, colección `2026.07` (Apache 2.0)
- `ATLAS.yaml` — versión legacy 5.6.0 (marcada como deprecada por MITRE)
- `nist600-1.txt` — texto extraído del PDF NIST AI 600-1 (extracción parcial; títulos en negrita perdidos)
- `mastg/` — clon disperso y superficial de `OWASP/owasp-mastg` (techniques, tests, tests-beta,
  best-practices, knowledge, rules, demos)
