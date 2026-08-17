# Mapa de currículo — Certificaciones ofensivas + marco de competencias NICE

Cartógrafo: área "Objetivos de certificaciones ofensivas y marco de competencias".
Fecha de extracción: 2026-08-11.
Repo objetivo: `CristianAjavi/ethical-hacker-squad` (MIT) — **NO se tocó**. Todo este material vive solo en scratchpad.

**Regla de uso de este documento:** es material de investigación interna. Lo que puede viajar al repo MIT está
marcado explícitamente en la sección de licencias. Lo que está entre comillas de una plataforma comercial
**no se copia al repo**: se usa solo para decidir qué procedimiento nuevo escribir con redacción propia.

---

## BLOQUE A — OSCP / PEN-200 (OffSec)

- **Fuente abierta:** https://www.offsec.com/documentation/penetration-testing-with-kali.pdf (PDF del syllabus, 20 pp., extraído íntegro)
- **Fuente secundaria:** https://www.offsec.com/courses/pen-200/
- **Versión del documento:** "PWK v3.0"
- **Licencia declarada en el PDF:** `PWK v3.0 - Copyright ©2023 OffSec Ltd. All rights reserved.`
- **Licencia del sitio:** `© OffSec Services, LLC 2026 All rights reserved`
- **Qué se puede citar:** el código del curso (PEN-200/PWK), el nombre de la certificación (OSCP/OSCP+), los
  nombres de Learning Module y Learning Unit, y la **estructura** del temario como hecho verificable.
- **Qué NO:** la redacción de los Learning Objectives (viñetas). Están en `oscp_raw.txt` solo como evidencia.

### Estructura Learning Module → Learning Units (nombres literales, citados como estructura)

| # | Learning Module | Learning Units |
|---|---|---|
| 1 | Penetration Testing with Kali Linux: General Course Introduction | Welcome to PWK · How to Approach the Course · Summary of PWK Learning Modules |
| 2 | Introduction to Cybersecurity | The Practice of Cybersecurity · Threats and Threat Actors · The CIA Triad · Security Principles, Controls, and Strategies · Cybersecurity Laws, Regulations, Standards, and Frameworks · Career Opportunities in Cybersecurity |
| 3 | Effective Learning Strategies | Learning Theory · Unique Challenges to Learning Technical Skills · OffSec Methodology · Case Study: chmod -x chmod · Tactics and Common Methods · Advice and Suggestions on Exams · Practical Steps |
| 4 | **Report Writing for Penetration Testers** | Understanding Note-Taking · Writing Effective Technical Penetration Testing Reports |
| 5 | **Information Gathering** | The Penetration Testing Lifecycle · Passive Information Gathering · Active Information Gathering |
| 6 | **Vulnerability Scanning** | Vulnerability Scanning Theory · Vulnerability Scanning with Nessus · Vulnerability Scanning with Nmap |
| 7 | Introduction to Web Applications | Web Application Assessment Methodology · Web Application Assessment Tools · Web Application Enumeration · Cross-Site Scripting (XSS) |
| 8 | Common Web Application Attacks | Directory Traversal · File Inclusion Vulnerabilities · File Upload Vulnerabilities · Command Injection |
| 9 | SQL Injection Attacks | SQL Theory and Database Types · Manual SQL Exploitation · Manual and Automated Code Execution |
| 10 | Client-Side Attacks | Target Reconnaissance · Exploiting Microsoft Office · Abusing Windows Library Files |
| 11 | **Locating Public Exploits** | Getting Started · Online Exploit Resources · Offline Exploit Resources · Exploiting a Target |
| 12 | Fixing Exploits | Fixing Memory Corruption Exploits · Fixing Web Exploits |
| 13 | Antivirus Evasion | Antivirus Evasion Software Key Components and Operations · AV Evasion in Practice |
| 14 | Password Attacks | Attacking Network Services Logins · Password Cracking Fundamentals · Working with Password Hashes |
| 15 | Windows Privilege Escalation | Enumerating Windows · Leveraging Windows Services · Abusing other Windows Components |
| 16 | Linux Privilege Escalation | Enumerating Linux · Exposed Confidential Information · Insecure File Permissions · Insecure System Components |
| 17 | Port Redirection and SSH Tunneling | Port Forwarding with *NIX Tools · SSH Tunneling · Port Forwarding with Windows Tools |
| 18 | Advanced Tunneling | Tunneling Through Deep Packet Inspection |
| 19 | The Metasploit Framework | Getting Familiar with Metasploit · Using Metasploit Payloads · Performing Post-Exploitation with Metasploit · Automating Metasploit |
| 20 | Active Directory Introduction and Enumeration | Active Directory Manual Enumeration · Manual Enumeration Expanding our Repertoire · Active Directory Automated Enumeration |
| 21 | Attacking Active Directory Authentication | Understanding Active Directory Authentication · Performing Attacks on Active Directory Authentication |
| 22 | Lateral Movement in Active Directory | Active Directory Lateral Movement Techniques · Active Directory Persistence |
| 23 | Assembling the Pieces | Enumerating the Public Network · Attacking WEBSRV1 · Gaining Access to the Internal Network · Enumerating the Internal Network · Attacking the Web Application on INTERNALSRV1 · Gaining Access to the Domain Controller |
| 24 | Trying Harder: The Labs | PWK Challenge Lab Overview · Challenge Lab Details · The OSCP Exam Information |

**Lectura de metodología (lo que exige el ciclo de trabajo OSCP, no la técnica):**
el syllabus ancla el trabajo en un **Penetration Testing Lifecycle** explícito, y coloca **Report Writing como
Módulo 4 — antes de cualquier módulo técnico**. Note-taking, portabilidad de notas, capturas de pantalla,
resumen ejecutivo, resumen técnico y apéndices son unidades formales del temario, no un anexo.
Módulo 11 ("Locating Public Exploits") dedica su primera unidad al **riesgo de ejecutar exploits no confiables
y a analizar el código del exploit antes de ejecutarlo** — control de cadena de suministro del propio tooling.

---

## BLOQUE B — CompTIA PenTest+ PT0-003

- **Fuente abierta:** https://www.comptia.org/en-us/certifications/pentest/
- **Código de examen vigente:** **PT0-003** (V3), lanzamiento declarado 17-dic-2024.
- **Formato declarado:** máx. 90 preguntas, opción múltiple + performance-based, aprobación 750 (escala 100–900).
- **Licencia:** `Copyright © 2026 CompTIA, Inc. All rights reserved.`
- **Qué se puede citar:** el código de examen, los nombres de dominio y sus ponderaciones (hechos verificables),
  y referencias tipo "PenTest+ PT0-003 dominio 4".
- **Qué NO:** el texto de los objetivos.

### Dominios y ponderación (literal de la página oficial)

| Dominio | Peso | Temas listados en la página |
|---|---|---|
| 1. Engagement management | 13% | Planning and scoping · Legal and ethical compliance · Collaboration and communication · Penetration test reports |
| 2. Reconnaissance and enumeration | 21% | Active and passive reconnaissance · Enumeration techniques · Reconnaissance tools · Script modification |
| 3. Vulnerability discovery and analysis | 17% | Vulnerability scans · Result analysis · Discovery tools |
| 4. Attacks and exploits | 35% | Network attacks · Authentication attacks · Host-based attacks · Web application attacks · **Cloud-based attacks** · **AI attacks** |
| 5. Post-exploitation and lateral movement | 14% | Post-exploitation activities · Documentation |

**Señal fuerte:** el dominio de mayor peso (35%) incluye **"AI attacks"** como categoría de primer nivel junto a
red, autenticación, host, web y cloud. Es la confirmación de que un temario profesional vigente ya trata la
seguridad de sistemas de IA como superficie de pentest estándar, no como especialidad exótica.
**Segunda señal:** el 13% completo del dominio 1 es **gestión del encargo** — alcance, cumplimiento legal y
ético, comunicación y reporte. Es competencia evaluada, no preámbulo.

---

## BLOQUE C — eCPPT (INE / ex-eLearnSecurity)

- **Fuente abierta:** https://ine.com/security/certifications/ecppt-certification/
  (la URL antigua `security.ine.com/certifications/ecppt-certification/` redirige 301 aquí)
- **Licencia:** `© 2026 INE. All Rights Reserved. All logos, trademarks and registered trademarks are the property of their respective owners.`
- **Qué se puede citar:** nombre de la certificación, nombres de dominio y ponderaciones.
- **Qué NO:** la redacción de los objetivos. Se transcriben abajo **solo como evidencia de investigación**;
  no se copian al repo.

| Dominio | Peso |
|---|---|
| Information Gathering & Reconnaissance | 10% |
| Initial Access | 15% |
| Web Application Penetration Testing | 15% |
| Exploitation & Post-Exploitation | 25% |
| Exploit Development | 5% |
| Active Directory Penetration Testing | 30% |

Objetivos publicados (evidencia interna, no redistribuible):
Host discovery/port scanning; enumeración de servicios; username enumeration; password spraying; brute-force a
servicios de acceso remoto; enumeración web; SQLi/XSS/command injection; brute-force a formularios de login;
componentes web desactualizados; exfiltración desde apps y BD comprometidas; explotación de servicios mal
configurados; escalada de privilegios; dump y crackeo de hashes; credenciales locales inseguras; desarrollo y
modificación de exploits; corrupción de memoria (stack/buffer overflow); enumeración de AD; cuentas de dominio
con contraseña débil o vacía; AS-REP roasting; movimiento lateral (Pass-the-Hash, Pass-the-Ticket); obtención
de Domain Admin.

**Lectura:** el 30% del examen es Active Directory y el 25% explotación/post-explotación. Es un temario
mayoritariamente de red interna Windows — el eje con menor solape útil con un escuadrón de auditoría de
código/app/cloud, y con la mayor proporción de material fuera de alcance.

---

## BLOQUE D — PNPT (TCM Security)

- **Fuente abierta:** https://certifications.tcm-sec.com/pnpt/
- **Licencia:** `Copyright TCM Security, INC © 2025`
- **Qué se puede citar:** nombre de la certificación, estructura del examen, nombres de los cursos asociados.

**Estructura del examen (hecho verificable, es el aporte principal de esta fuente):**
- 7 días en total: **5 días** de ejecución del pentest + **2 días** para redactar el informe profesional.
- **Debrief en vivo de 15 minutos** presentando los hallazgos ante evaluadores senior.
- Declarado explícitamente: sin banderas que capturar, sin preguntas de opción múltiple.

**Dominios de conocimiento declarados:** OSINT · explotación de Active Directory (movimiento lateral y vertical) ·
bypass de antivirus y de egress · compromiso del controlador de dominio · redacción de informe profesional ·
presentación en vivo.

**Cursos asociados:** Practical Ethical Hacking · Windows Privilege Escalation · Linux Privilege Escalation ·
Open-Source Intelligence (OSINT Fundamentals) · External Pentest Playbook.

**Lectura de metodología:** es la fuente que más peso pone en el **entregable**: 2 de 7 días (≈29% del tiempo del
examen) son exclusivamente redacción, más una defensa oral obligatoria. Un hallazgo que no se sabe explicar ni
defender no vale. Esto es directamente transferible a un escuadrón de subagentes.

---

## BLOQUE E — NICE Framework (NIST SP 800-181r1) — EL MAPA CANÓNICO

- **Publicación:** NIST SP 800-181 Rev. 1, *Workforce Framework for Cybersecurity (NICE Framework)*,
  noviembre 2020, 27 pp. https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-181r1.pdf
- **Componentes vigentes:** **v2.2.0 (28-abr-2025)**.
  - Página oficial: https://www.nist.gov/itl/applied-cybersecurity/nice/nice-framework-resource-center/current-version
  - Datos JSON completos (descargados y parseados): https://csrc.nist.gov/csrc/media/Projects/cprt/documents/nice/v2-2-0_nf_components.json
- **ESTADO DE DERECHOS — VERIFICADO, CITA LITERAL del PDF:**
  > "This publication may be used by nongovernmental organizations on a voluntary basis and **is not subject to
  > copyright in the United States**. Attribution would, however, be appreciated by NIST."

  **Consecuencia práctica: esta es la única fuente de las cinco cuyo texto SÍ se puede reproducir literalmente
  dentro del repo MIT.** Las declaraciones TKS (Task/Knowledge/Skill) pueden citarse verbatim con su ID
  (`T1234`, `K0674`, `S0123`) y atribución a NIST. Es el ancla de trazabilidad ideal.

### Estructura del marco
`Task / Knowledge / Skill (TKS)` son los bloques atómicos → se agrupan en **Work Roles** (42) y en
**Competency Areas** (11), organizados en **5 Categorías**.
En r1 los Work Roles y las listas KSA salieron del cuerpo del documento y se mantienen como componentes
versionados aparte (por eso v2.2.0 ≠ la fecha del SP).

### Las 5 Categorías
`DD` DESIGN and DEVELOPMENT · `PD` PROTECTION and DEFENSE · `IN` INVESTIGATION ·
`IO` IMPLEMENTATION and OPERATION · `OG` OVERSIGHT and GOVERNANCE

### Los 42 Work Roles (lista completa, dominio público)
**DD:** Cybersecurity Architecture (DD-WRL-001) · Enterprise Architecture (002) · Secure Software Development (003) ·
Secure Systems Development (004) · **Software Security Assessment (005)** · Systems Requirements Planning (006) ·
**Systems Testing and Evaluation (007)** · Technology Research and Development (008) · OT Cybersecurity Engineering (009)
**PD:** Defensive Cybersecurity (PD-WRL-001) · Digital Forensics (002) · Incident Response (003) ·
Infrastructure Support (004) · Insider Threat Analysis (005) · Threat Analysis (006) · **Vulnerability Analysis (007)**
**IN:** Cybercrime Investigation (IN-WRL-001) · Digital Evidence Analysis (002)
**IO:** Data Analysis (IO-WRL-001) · Database Administration (002) · Knowledge Management (003) ·
Network Operations (004) · Systems Administration (005) · **Systems Security Analysis (006)** · Technical Support (007)
**OG:** COMSEC Management (OG-WRL-001) · Cybersecurity Policy and Planning (002) · Cybersecurity Workforce Management (003) ·
Cybersecurity Curriculum Development (004) · Cybersecurity Instruction (005) · Cybersecurity Legal Advice (006) ·
Executive Cybersecurity Leadership (007) · **Privacy Compliance (008)** · Product Support Management (009) ·
Program Management (010) · Secure Project Management (011) · **Security Control Assessment (012)** ·
Systems Authorization (013) · Systems Security Management (014) · Technology Portfolio Management (015) ·
**Technology Program Auditing (016)** · **Cybersecurity Supply Chain Risk Management (017)**

*(en negrita: los directamente aplicables a un escuadrón de auditoría autorizada)*

### Las 11 Competency Areas
`NF-COM-001` Access Controls · `002` **Artificial Intelligence (AI) Security** · `003` Asset Management ·
`004` Cloud Security · `005` Communications Security · `006` Cryptography · `007` Cyber Resiliency ·
`008` **DevSecOps** · `009` Operating Systems (OS) Security · `010` Operational Technology (OT) Security ·
`011` **Supply Chain Security**

> Nota de datos: en v2.2.0 solo 4 Competency Areas traen TKS poblado en el JSON
> (Cyber Resiliency 122, Cryptography 106, DevSecOps 96, AI Security 88). Las otras 7 están declaradas
> con nombre y descripción pero sin K/S asociados todavía. **No inventar su contenido.**

### Work Roles de auditoría — descripciones oficiales y volumen de TKS
(dump completo de Tasks y Skills en `nice_tks_relevant.txt`)

| Work Role | Descripción oficial (dominio público, verbatim) | Tasks | Skills |
|---|---|---|---|
| **PD-WRL-007 Vulnerability Analysis** | "Responsible for assessing systems and networks to identify deviations from acceptable configurations, enclave policy, or local policy. Measure effectiveness of defense-in-depth architecture against known vulnerabilities." | 15 | 18 |
| **DD-WRL-005 Software Security Assessment** | "Responsible for analyzing the security of new or existing computer applications, software, or specialized utility programs and delivering actionable results." | 38 | 18 |
| **DD-WRL-007 Systems Testing and Evaluation** | "Responsible for planning, preparing, and executing system tests; evaluating test results against specifications and requirements; and reporting test results and findings." | 22 | 21 |
| **DD-WRL-001 Cybersecurity Architecture** | "Responsible for ensuring that security requirements are adequately addressed in all aspects of enterprise architecture, including reference models, segment and solution architectures, and the resulting systems that protect and support organizational mission and business processes." | 50 | 48 |
| **OG-WRL-012 Security Control Assessment** | "Responsible for conducting independent comprehensive assessments of management, operational, and technical security controls and control enhancements employed within or inherited by a system to determine their overall effectiveness." | 52 | 122 |
| **OG-WRL-017 C-SCRM** | "Responsible for developing cybersecurity supply chain risk management (C-SCRM) policies, processes, and procedures to identify, assess, protect against, and respond to cybersecurity risks throughout the supply chain, and for advising other stakeholders within an enterprise about supply chain risks." | 38 | 44 |
| **OG-WRL-008 Privacy Compliance** | "Responsible for developing and overseeing an organization's privacy compliance program and staff, including establishing and managing privacy-related governance, policy, and incident response needs." | 78 | 21 |
| **IO-WRL-006 Systems Security Analysis** | "Responsible for developing and analyzing the integration, testing, operations, and maintenance of systems security. Prepares, performs, and manages the security aspects of implementing and operating a system." | 44 | 18 |
| **DD-WRL-003 Secure Software Development** | "Responsible for developing, creating, modifying, and maintaining computer applications, software, or specialized utility programs." | 48 | 24 |
| **OG-WRL-016 Technology Program Auditing** | "Responsible for conducting evaluations of technology programs or their individual components to determine compliance with published standards." | 19 | 7 |
| **DD-WRL-009 OT Cybersecurity Engineering** | "Responsible for working within the engineering department to design and create systems, processes, and procedures that maintain the safety, reliability, controllability and security of industrial systems in the face of intentional and incidental cyber events." | 38 | 26 |

**Lectura del marco como mapa de competencias:**
el NICE es el único de los cinco que mide **el ciclo completo de la auditoría** y no solo la técnica de ataque.
Tres ejes que ningún temario de certificación ofensiva cubre con este peso:
1. **OG-WRL-012 Security Control Assessment** (52 tasks / 122 skills) — evaluación *independiente* de la
   efectividad de controles, no búsqueda de vulnerabilidades. Es el marco natural para el rol de verificación.
2. **OG-WRL-016 Technology Program Auditing** — evaluación de conformidad contra estándares publicados.
   Es exactamente la función de una matriz de trazabilidad estándar↔hallazgo.
3. **OG-WRL-008 Privacy Compliance** (78 tasks) — el bloque de gobierno de privacidad más grande de todo el
   marco; ninguna cert ofensiva de las cuatro lo toca.

Además, **DD-WRL-009 OT Cybersecurity Engineering** y la Competency Area **OT Security** abren una superficie
(ICS/SCADA, seguridad y controlabilidad de sistemas industriales) ausente en las cuatro certificaciones.

---

## BLOQUE F — FUERA DE ALCANCE (mapeado, deliberadamente NO incorporado)

El producto es auditoría autorizada. Estos bloques del temario profesional se registran para que el mapa esté
completo y para dejar constancia de que la omisión es **una decisión, no un hueco**:

| Bloque del currículo | Fuente | Razón |
|---|---|---|
| Antivirus Evasion (módulo 13 completo) | PEN-200 | Evasión de detección: degrada los controles del cliente y no produce hallazgo auditable |
| Advanced Tunneling / Tunneling Through Deep Packet Inspection (módulo 18) | PEN-200 | Evasión de controles de red (HTTP/DNS tunneling) |
| Antivirus & Egress Bypassing | PNPT | Evasión de detección |
| Lateral Movement in Active Directory (módulo 22) | PEN-200 · eCPPT 30% · PT0-003 dom. 5 | Movimiento lateral |
| Active Directory Persistence (golden tickets, shadow copies) | PEN-200 | Persistencia: deja artefactos en el cliente |
| Performing Post-Exploitation with Metasploit / Meterpreter / pivoting (módulo 19) | PEN-200 · PT0-003 dom. 5 | Post-explotación |
| Impersonar un DC para extraer credenciales de dominio (DCSync) · obtención de Domain Admin | PEN-200 · eCPPT · PNPT | Post-explotación destructiva sobre identidad |
| Client-Side Attacks: macros de Office, Windows library files, LNK (módulo 10) · phishing para acceso interno | PEN-200 | Ingeniería social armada contra personas |
| Fixing Memory Corruption Exploits (módulo 12) · Exploit Development (eCPPT 5%) | PEN-200 · eCPPT | Weaponización de exploits |
| Crackeo de hashes exfiltrados · Pass-the-Hash / Overpass-the-Hash / relay NTLM | PEN-200 módulo 14 · eCPPT | Post-explotación de credenciales |
| Exfiltración de datos y credenciales desde sistemas comprometidos | eCPPT | Acción destructiva sobre datos del cliente |

**Matiz importante que sí se conserva:** la *detección* de la condición explotable sigue siendo alcance legítimo.
Ejemplo: "SPN kerberoasteable configurado con cifrado débil" es un hallazgo auditable; "forjar el ticket y moverse
lateralmente" no lo es. La frontera es **evidenciar la condición sin ejercer el impacto**.

---

## BLOQUE G — NO VERIFICADO (declarado, no reconstruido)

1. **Sub-objetivos numerados de PT0-003** (1.1, 1.2, 2.1…). La página oficial expone dominios, pesos y viñetas
   de tema, pero **no** la numeración fina. Los dos PDFs candidatos de objetivos devolvieron **HTTP 404**
   (`comptia.org/docs/default-source/exam-objectives/comptia-pentest-pt0-003-exam-objectives.pdf`) y la ruta
   `comptia.org/en-us/certifications/pentest/pt0-003/` también 404. CompTIA entrega el PDF completo tras
   formulario. **No se reconstruyeron de memoria.**
2. **Vigencia de PWK v3.0.** El PDF servido en `offsec.com/documentation/` se identifica como v3.0 ©2023,
   mientras el sitio ya comercializa OSCP+. No se verificó si existe un syllabus más reciente publicado.
   La página del curso solo dice "20+ módulos" y no enumera; el PDF sí enumera 24.
3. **niccs.cisa.gov devolvió HTTP 403** en `/workforce-development/nice-framework/work-roles`. Se rodeó usando
   el JSON oficial de NIST/CSRC, que es la fuente primaria — no hay pérdida de información.
4. **TKS de 7 de las 11 Competency Areas** (Access Controls, Asset Management, Cloud Security,
   Communications Security, OS Security, OT Security, Supply Chain Security): declaradas con nombre y
   descripción en v2.2.0, sin K/S poblados en el JSON. No se infirió su contenido.
5. **Niveles de responsabilidad NICE** (Entry/Intermediate/Advanced por work role): referenciados por NIST pero
   no extraídos ni asignados. Los niveles usados en el entregable estructurado son **clasificación propia**,
   no una afirmación sobre lo que publica cada plataforma.
6. **eJPT** (nivel junior de INE) no se consultó: presupuesto priorizado a eCPPT, que es el nivel practitioner.

---

## BLOQUE E-2 — Declaraciones NICE citables verbatim (dominio público, atribuir a NIST)

Estas son las Task statements textuales más directamente convertibles en procedimientos de auditoría.
**Se pueden copiar literalmente al repo MIT con su ID y atribución a NIST SP 800-181r1 / NICE v2.2.0.**

**PD-WRL-007 Vulnerability Analysis** — las 15 tasks completas:
Determine the operational and safety impacts of cybersecurity lapses · Determine impact of software
configurations · Evaluate organizational cybersecurity policy regulatory compliance · Evaluate organizational
cybersecurity policy alignment with organizational directives · Develop cybersecurity risk profiles · Identify
anomalous network activity · **Perform authorized penetration testing on enterprise network assets** ·
Identify vulnerabilities · Recommend vulnerability remediation strategies · Maintain deployable cyber defense
audit toolkits · Prepare audit reports · Perform required reviews · Correlate incident data · Perform risk and
vulnerability assessments · Recommend cost-effective security controls.

> Nótese que el marco canónico dice literalmente **"authorized"** en la única task de pentest del rol.
> Es respaldo normativo directo para el encuadre ético del escuadrón.

**DD-WRL-005 Software Security Assessment** — selección de alto valor:
Perform code reviews · Identify common coding flaws · Identify programming flaws · Conduct threat modeling ·
Develop threat models · **Document software attack surface elements** · Integrate black-box security testing
tools into quality assurance processes · **Conduct vulnerability analysis of software patches and updates** ·
Prepare vulnerability analysis reports · Conduct risk analysis of applications and systems undergoing major
changes · Address security implications in the software acceptance phase · **Incorporate product end-of-life
cybersecurity measures** · Determine special needs of cyber-physical systems · Evaluate interfaces between
hardware and software · Determine security requirements for new operational technologies.

**OG-WRL-016 Technology Program Auditing** — selección:
Conduct technology program and project audits · **Develop independent cybersecurity audit processes for
application software, networks, and systems** · Implement independent cybersecurity audit processes… ·
Oversee independent cybersecurity audits · Develop risk, compliance, and assurance monitoring strategies ·
Develop risk, compliance, and assurance measurement strategies · **Determine if cybersecurity requirements
included in contracts are delivered** · Determine if procurement activities sufficiently address supply chain
risks · Develop supply chain, system, network, and operational security contract language · Conduct
import/export reviews for acquiring systems and software · Examine service performance reports for issues and
variances · Initiate corrective actions to service performance issues and variances.

**OG-WRL-017 C-SCRM** — selección:
**Validate that procured systems and system components are genuine and unaltered** · Conduct supplier risk
assessments · Identify supply chain risks for critical system elements · Monitor supply chain risk exposure ·
**Integrate C-SCRM activities throughout the software development life cycle (SDLC)** · Determine if products
comply with cybersecurity requirements · Communicate cybersecurity requirements to suppliers · Inventory
technology resources · Prepare supply chain security reports · Evaluate offers to ensure conformance with
C-SCRM requirements · Establish internal checks and balances to ensure compliance with C-SCRM security and
quality requirements · Integrate C-SCRM into incident response functions · Recommend cost-effective supply
chain security controls or control enhancements.

**OG-WRL-012 Security Control Assessment** — selección:
**Assess the effectiveness of security controls** · Perform security reviews · **Identify gaps in security
architecture** · **Verify implementation of software, network, and system cybersecurity postures** ·
**Document software, network, and system deviations from implemented security postures** · Recommend required
actions to correct… deviations · Determine if cybersecurity requirements have been successfully implemented ·
Determine if vulnerability remediation plans are in place · Develop vulnerability remediation plans ·
Determine the effectiveness of organizational cybersecurity policies and procedures · **Determine effectiveness
of configuration management processes** · Develop cybersecurity audit processes for external services ·
Develop cybersecurity compliance processes for external services · Manage Accreditation Packages (e.g.,
ISO/IEC 15026-2) · Advise on Risk Management Framework process activities and documentation · Update security
documentation to reflect current application and system security design features · Evaluate locally developed
tools · Scope analysis reports to various audiences that accounts for data sharing classification restrictions.

> **Aviso de alcance dentro del propio NICE:** OG-WRL-012 incluye además las tasks
> *"Expand network access"*, *"Conduct technical exploitation of a target"* y *"Estimate the impact of
> collateral damage"*. Aunque vengan de un rol de auditoría del marco canónico, caen del lado ofensivo/
> post-explotación y **se declaran FUERA DE ALCANCE** igual que el material equivalente de las certificaciones.
> El marco no es una autorización automática.

**NF-COM-002 AI Security** — Competency Area completa (88 K/S), selección literal:
*Knowledge:* common AI security risks · data poisoning cyberattacks · AI bias types · AI model development
processes · training, validation, and test data sets · **agentic AI principles and practices** · misinformation
and disinformation vulnerabilities in AI systems · human-AI interaction principles and practices · NIST AI Risk
Management Framework · ethical responsibilities of AI system users and providers · legal responsibilities of AI
system users · uncertainty measurement principles and practices · cognitive biases.
*Skill:* developing prompts for generative AI systems · evaluating machine learning models · **identifying
possible mistakes or hallucinations in AI-generated outputs** · **measuring non-explainable risk** · dividing
data into training, validation, and test data sets · mitigating cognitive biases.

> Convergencia entre las dos mitades del encargo: PT0-003 mete **"AI attacks"** en su dominio de mayor peso
> (35%) y NICE dedica una Competency Area entera a **AI Security** con 88 declaraciones, incluyendo IA agéntica
> y riesgo no explicable. Dos currículos independientes — uno comercial, uno gubernamental — coinciden en que
> esto ya es competencia profesional estándar.

---

## Archivos de evidencia en este directorio

| Archivo | Qué es |
|---|---|
| `oscp_raw.txt` | Texto íntegro extraído del PDF del syllabus PEN-200 (20 pp.) |
| `nist181r1_raw.txt` | Texto íntegro de NIST SP 800-181r1 (incluye la declaración de derechos, línea 73) |
| `nice_v220.json` | Componentes NICE v2.2.0 completos (2,6 MB; 2.356 elementos) |
| `nice_tks_relevant.txt` | Tasks y Skills de los 11 work roles de auditoría + K/S de las Competency Areas pobladas |
