# Mapa de currículo — OpenSSF / Linux Foundation / cadena de suministro

Cartógrafo de currículo, área "OpenSSF, Linux Foundation y cadena de suministro".
Fecha de extracción: 2026-08-11.

## Reglas aplicadas a este documento

- **Solo lectura sobre el repo.** No se tocó nada dentro de `/Users/cristianajavi/ethical-hacker-squad`.
- **No se leyó el corpus** (`references/knowledge/*.md`) antes de escribir este mapa, por instrucción explícita: primero el temario, sin contaminación.
- **Nada de texto copiado.** Aquí sólo hay: nombres de curso, códigos de curso, nombres de módulo/capítulo, nombres de check/requisito e **IDs**. Eso es *estructura del temario como hecho*, no la redacción del vendor. Donde un título original era largo y descriptivo (S2C2F) se anota una **etiqueta corta parafraseada** y se marca como tal.
- Todo bloque lleva la **URL realmente abierta**.

---

## BLOQUE 1 — LFD121 "Developing Secure Software" (OpenSSF / LF Training)

**Fuentes abiertas:**
- Página de curso: https://training.linuxfoundation.org/training/developing-secure-software-lfd121/
- Página OpenSSF de cursos: https://openssf.org/training/courses/
- **Repo fuente del contenido** (el temario real, no el resumen de marketing): https://github.com/ossf/secure-sw-dev-fundamentals
- ToC completo, obtenido vía GitHub API `contents/toc.md`: https://raw.githubusercontent.com/ossf/secure-sw-dev-fundamentals/main/toc.md

**Ficha:** código LFD121 · 16-20 h (la página OpenSSF dice 14-18 h) · nivel principiante · gratis · certificado gratuito válido 2 años · prerrequisito declarado: saber programar.

**LICENCIA — VERIFICADA:** el repo de contenido declara `CC-BY-4.0` (`Creative Commons Attribution 4.0 International`, SPDX `CC-BY-4.0`, confirmado por la API de GitHub sobre `repos/ossf/secure-sw-dev-fundamentals`). El README lo reitera: el contenido informativo se publica bajo CC-BY 4.0, con **excepciones para material citado bajo otras licencias** (ej. imágenes de xkcd) y con **el material de evaluación deliberadamente excluido del repo**.
→ Consecuencia práctica: **es la única fuente de este mapa cuyo texto podríamos reutilizar** en un repo MIT, siempre con atribución (CC BY 4.0 es compatible con distribuir junto a MIT si se atribuye y se marca qué parte es CC BY). Aun así, para este encargo **no copiamos redacción**: usamos el mapa de competencias.

### Temario completo, 3 niveles (tal como lo nombra `toc.md`)

**Part I: Requirements, Design, and Reuse**

- **Course Introduction**
  - Introduction
  - A Note from the Author
  - Motivation
    - Motivation: Why Is It Important to Secure Software?
    - Motivation: Why Take This course?
- **Security Basics**
  - What Do We Need?
    - What Does "Security" Mean?
    - Security Requirements
    - What Is Privacy and Why It Is Important
    - Privacy Requirements
  - How Can We Get There?
    - Risk Management
    - Development Processes / Defense-in-Breadth
    - Protect, Detect, Respond
    - Vulnerabilities
- **Design**
  - Secure Design Basics
    - What Are Security Design Principles?
    - Widely-Recommended Secure Design Principles
    - Least Privilege
    - Complete Mediation (Non-Bypassability)
    - The Rest of the Saltzer & Schroeder Design Principles
    - Other Design Principles
- **Reusing External Software**  ← *núcleo cadena de suministro*
  - Supply Chain
    - Basics of Reusing Software
    - Selecting (Evaluating) Open Source Software
    - Downloading and Installing Reusable Software
    - Updating Reused Software

**Part II: Implementation**

- **Basics of Implementation**
  - Implementation Overview
- **Input Validation**
  - Input Validation Basics
    - Input Validation Basics Introduction
    - How Do You Validate Input?
  - Input Validation: Numbers and Text
    - Input Validation: A Few Simple Data Types
    - Sidequest: Text, Unicode, and Locales
    - Validating Text
    - Introduction to Regular Expressions
    - Using Regular Expressions for Text Input Validation
    - Countering ReDoS Attacks on Regular Expressions
  - Input Validation: Beyond Numbers and Text
    - Insecure Deserialization
    - Input Data Structures (XML, HTML, CSV, JSON, & File Uploads)
    - Minimizing Attack Surface, Identification, Authentication, and Authorization
    - Search Paths and Environment Variables (including setuid/setgid Programs)
    - Special Inputs: Secure Defaults and Secure Startup
  - Consider Availability on All Inputs
    - Consider Availability on All Inputs Introduction
- **Processing Data Securely**
  - General Issues
    - Prefer Trusted Data. Treat Untrusted Data as Dangerous
    - Avoid Default & Hardcoded Credentials
    - Avoid Incorrect Conversion or Cast
  - Undefined Behavior / Memory Safety
    - Countering Out-of-Bounds Reads and Writes (Buffer Overflow)
    - Double-free, Use-after-free, and Missing Release
    - Avoid Undefined Behavior
  - Calculate Correctly
    - Avoid Integer Overflow, Wraparound, and Underflow
- **Calling Other Programs**
  - Introduction to Securely Calling Programs - The Basics
  - Injection and Filenames
    - SQL Injection Vulnerability
    - SQL Injection: Parameterized Statements
    - SQL Injection: DBMS (Server) side vs. Application (client) side
    - SQL Injection: Alternatives to Parameterized Statements
    - OS Command (Shell) injection
    - Other Injection Attacks
    - Filenames (Including Path Traversal and Link Following)
  - Other Issues
    - Call APIs for Programs and Check What Is Returned
    - Handling Errors
    - Logging
    - Debug and Assertion Code
    - Countering Denial-of-Service (DoS) Attacks
- **Sending Output**
  - Introduction to Sending Output
  - Countering Cross-Site Scripting (XSS)
  - Content Security Policy (CSP)
  - Other HTTP Hardening Headers
  - Cookies & Login Sessions
  - CSRF / XSRF
  - Open Redirects and Forwards
  - HTML `target` and JavaScript `window.open()`
  - Using Inadequately Checked URLs / Server-Side Request Forgery (SSRF)
  - Same-Origin Policy and Cross-Origin Resource Sharing (CORS)
  - Format Strings and Templates
  - Minimize Feedback / Information Exposure
  - Avoid caching sensitive information
  - Side-Channel Attacks

**Part III: Verification and More Specialized Topics**

- **Verification**
  - Basics of Verification → Verification Overview
  - Static Analysis
    - Static Analysis Overview
    - Software Composition Analysis (SCA)/Dependency Analysis
  - Dynamic Analysis
    - Dynamic Analysis Overview
    - Fuzz Testing
    - Web Application Scanners
  - Other Verification Topics → Combining Verification Approaches
- **Threat Modeling**
  - Introduction to Threat Modeling
  - STRIDE
- **Cryptography**
  - Introduction to Cryptography
  - Symmetric/Shared Key Encryption Algorithms
  - Cryptographic Hashes (Digital Fingerprints)
  - Public-Key (Asymmetric) Cryptography
  - Cryptographically Secure Pseudo-Random Number Generator (CSPRNG)
  - Storing Passwords
  - Transport Layer Security (TLS)
  - Other Topics in Cryptography
- **Other Topics**
  - Vulnerability Disclosures
    - Receiving Vulnerability Reports
    - Respond To and Fix the Vulnerability in a Timely Way
    - Sending Vulnerability Reports to Others
  - Miscellaneous
    - Assurance Cases
    - **Harden the Development Environment (Including Build and CI/CD Pipeline) & Distribution Environment**
    - Distributing, Fielding/Deploying, Operations, and Disposal
    - Artificial Intelligence (AI), Machine Learning (ML), and Security
    - Formal Methods
  - Top Vulnerability Lists
    - OWASP Top 10
    - CWE Top 25
  - Concluding Notes → Conclusions

**Part IV (material de apoyo, fuera del curso):** Glossary · Further Reading · Old Mappings (OWASP Top 10 2017, CWE Top 25 2019) · References.

### Versión edX (mismo contenido, partido en 3)

Fuente: https://openssf.org/training/courses/ (los enlaces directos de edX **no** se abrieron; la URL edX que intenté devolvió 404 → ver "no verificado").

- **LFD104x** — Secure Software Development: Requirements, Design, and Reuse (= Part I)
- **LFD105x** — Secure Software Development: Implementation (= Part II)
- **LFD106x** — Secure Software Development: Verification and More Specialized Topics (= Part III)

Gratis en modo *audit*; certificado de pago.

---

## BLOQUE 2 — LFS182 "Securing Your Software Supply Chain with Sigstore"

**Fuente abierta:** https://training.linuxfoundation.org/training/securing-your-software-supply-chain-with-sigstore-lfs182x/
(la página OpenSSF lo lista como `LFS182`, la URL conserva el sufijo `x` de edX)

**Ficha:** 8 h · principiante · gratis · acceso 90 días.
**Prerrequisitos declarados:** Linux/macOS con acceso admin, ≥2 GB RAM, 64-bit; Docker Engine 25.1+ y Docker Compose 2.24.4+; Go 1.21.6+; terminal; nociones intermedias de cloud/DevOps; experiencia con contenedores y CI/CD tipo GitHub Actions.

**Temario:**

1. Course Introduction
2. Introduction to Sigstore
3. Cosign: Signing and Verifying Containers and Artifacts
4. Fulcio: The Trusted Digital Certificate Authority
5. Rekor: The Immutable and Secure Transparency Log
6. Policy Controller: The Kubernetes Cluster Gatekeeper
7. Gitsign: Keyless Signing for Git Commits and Tags
8. Sigstore TSA: Trusted Timestamping
9. Getting Involved with the Sigstore Community

**Licencia:** no hay declaración de licencia en la página de curso → el temario se cita como estructura/hecho; **no se puede reproducir texto**.

---

## BLOQUE 3 — LFEL1007 "Automating Supply Chain Security: SBOMs and Signatures"

**Fuente abierta:** https://training.linuxfoundation.org/express-learning/automating-supply-chain-security-sboms-and-signatures-lfel1007/

**Ficha:** 60-90 min · principiante · gratis · acceso 30 días · badge digital.
**Prerrequisitos declarados:** Git · herramientas de línea de comandos · integración continua · versionado semántico.
**Público:** desarrolladores, mantenedores open source, profesionales de seguridad IT.

**Temario:**

1. Course Introduction
2. Introduction to Software Provenance
3. The Role of Source Control
4. The Role of Dependency Tracking
5. The Role of Tags and Signatures
6. Automate Your Project's Provenance

**Competencias declaradas:** procedencia de software, papel del control de fuente, seguimiento de dependencias y creación de SBOM; herramientas de SBOM y de firma; aplicación de `cosign` y de flujos SLSA con GitHub Actions.

**Licencia:** sin declaración → estructura citable, texto no.

---

## BLOQUE 4 — LFEL1006 "Securing Projects with OpenSSF Scorecard"

**Fuente abierta (curso):** https://training.linuxfoundation.org/express-learning/securing-projects-with-openssf-scorecard-lfel1006/

**Ficha:** 60-90 min · principiante · gratis · acceso 30 días.
**Prerrequisitos:** SDLC · GitHub/GitLab/CLI · nociones de CI/CD.

**Temario:**

1. Course Introduction
2. Getting Started
3. Scorecard's Check
4. Integrate Scorecard with Your Project
5. View a Detailed Scorecard
6. Work with Your Scorecard

**Fuente abierta (el mapa de competencias real):** repo `ossf/scorecard`, `docs/checks.md` vía GitHub API.
**Licencia del repo Scorecard — VERIFICADA:** `Apache-2.0`.

**Los 20 checks (nombres exactos = los 20 controles auditables):**

`Binary-Artifacts` · `Branch-Protection` · `CI-Tests` · `CII-Best-Practices` · `Code-Review` · `Contributors` · `Dangerous-Workflow` · `Dependency-Update-Tool` · `Fuzzing` · `License` · `Maintained` · `Packaging` · `Pinned-Dependencies` · `SAST` · `SBOM` · `Security-Policy` · `Signed-Releases` · `Token-Permissions` · `Vulnerabilities` · `Webhooks`

---

## BLOQUE 5 — LFEL1005 "Security Self-Assessments for Open Source Projects"

**Fuente abierta:** https://training.linuxfoundation.org/express-learning/security-self-assessments-for-open-source-projects-lfel1005/

**Ficha:** 60-90 min · principiante · gratis · sin prerrequisitos.

**Temario:**

1. Chapter 1: Course Introduction
2. Chapter 2: Setting the Stage
3. Chapter 3: Create Your Self-Assessment

**Competencia declarada:** iniciar y articular el valor de una autoevaluación de seguridad del proyecto, como insumo para evaluaciones conjuntas o auditorías de seguridad.

---

## BLOQUE 6 — LFD125 "Security for Software Development Managers"

**Fuente abierta:** https://training.linuxfoundation.org/training/security-for-software-development-managers-lfd125

**Ficha:** 1-2 h · principiante · sin prerrequisitos técnicos (ayuda experiencia de gestión).

**Temario:**

1. Course Introduction
2. Why Security is Important in Software Development
3. Key Things Managers of Software Developers Must Do
4. Introduction to Security Concepts
5. Applying Security to Your Projects

---

## BLOQUE 7 — LFEL1001 "Understanding the EU Cyber Resilience Act (CRA)"

**Fuente abierta:** https://training.linuxfoundation.org/express-learning/understanding-the-eu-cyber-resilience-act-cra-lfel1001/

**Ficha:** 60-90 min (curso express en vídeo) · principiante.
**Público:** decisores, desarrolladores (open y closed source), *OSS stewards* con productos comercializados en la UE.

**Temario:**

1. Course Introduction
2. CRA Overview and Key Concepts
3. Requirements and Conformity Assessments
4. Adapting to the CRA

---

## BLOQUE 8 — LFEL1012 "Secure AI/ML-Driven Software Development"

**Fuente abierta:** https://training.linuxfoundation.org/express-learning/secure-ai-ml-driven-software-development-lfel1012/

**Ficha:** 60-90 min · principiante · requiere nociones de desarrollo.

**Temario:**

1. Course Introduction
2. Key AI Concepts for Secure Development
3. Security Risks of Using AI Assistants
4. Best Practices for Secure Assistant Use
5. Writing More Secure Code with AI
6. Reviewing Changes in a World with AI
7. Wrap-Up

*(Se anota aquí por pertenecer al catálogo OpenSSF; su explotación corresponde al pack AI, no al SUP.)*

---

## BLOQUE 9 — Resto del catálogo OpenSSF (listado verificado, temario NO abierto)

**Fuente abierta:** https://openssf.org/training/ (de aquí salen título, código y URL de cada curso)

| Curso | Código | URL listada |
|---|---|---|
| Cybersecurity Essentials | LFC108 | https://training.linuxfoundation.org/training/cybersecurity-essentials-lfc108/ |
| Introduction to DevSecOps for Managers | LFS180 | https://training.linuxfoundation.org/training/introduction-to-devsecops-for-managers-lfs180/ |
| Introduction to Zero Trust | LFS183 | https://training.linuxfoundation.org/training/introduction-to-zero-trust-lfs183/ |
| Understanding the OWASP® Top 10 Security Threats | SKF100 | https://training.linuxfoundation.org/training/owasp-top-ten-security-threats-skf100/ |

**Estado: el temario detallado de estos 4 NO se abrió.** No se reconstruye de memoria. Ver "no verificado".

---

## BLOQUE 10 — SLSA (el modelo pedagógico de procedencia)

**Fuentes abiertas:**
- https://slsa.dev/spec/v1.0/levels
- https://slsa.dev/spec/v1.1/levels
- https://slsa.dev/spec/  (índice de versiones)
- https://slsa.dev/spec/v1.2/  (navegación de la versión vigente)
- https://slsa.dev/spec/v1.2/source-requirements
- https://slsa.dev/spec/v1.2/threats

**Versión vigente: SLSA v1.2** (v1.1 marcada como no vigente; el pie de v1.1 remite a v1.2).
**LICENCIA — VERIFICADA:** pie de página: *"© 2026 The Linux Foundation, under the terms of the Community Specification License 1.0"*.
→ Community Specification License 1.0. **No es CC-BY.** Los nombres de nivel, de track y de amenaza son identificadores citables; la redacción normativa no se reproduce.

### Estructura de la navegación v1.2

- Understanding SLSA: What's new · About SLSA · Supply chain threats · Use cases · Guiding principles · FAQ · Future directions · Tracks
- **Build Track:** Basics · Terminology · Producing artifacts · Distributing provenance · **Verifying artifacts** · Assessing build platforms
- **Source Track:** Producing source · **Verifying source** · Assessing source control systems · Example controls
- Cross track / formatos de atestación: Threats & mitigations · Verified Properties · General model · Provenance · Build Provenance · Verification Summary

### Build track (niveles, verificados en v1.0/v1.1; v1.2 mantiene el track)

- **Build L0** — No guarantees (sin requisitos; builds de desarrollo/test)
- **Build L1** — Provenance exists (proceso de build consistente; la procedencia describe plataforma, proceso e inputs de nivel superior; puede ir **sin firmar**)
- **Build L2** — Hosted build platform (procedencia **firmada** por infraestructura dedicada; la verificación valida autenticidad; frena manipulación posterior al build)
- **Build L3** — Hardened builds (aislamiento entre ejecuciones, secretos de firma inaccesibles al build; defensa frente a insider y credenciales comprometidas)

### Source track (niveles, verificados en v1.2/source-requirements)

- **Source L0** — No attestation issued
- **Source L1** — fuente gestionada en un VCS moderno.
  Requisitos nombrados: Choose an appropriate Source Control System · Configure the SCS to control access and enforce history · Safe Expunging Process · Repositories are uniquely identifiable · Revisions are immutable and uniquely identifiable · Human readable changes · **Source Verification Summary Attestations** · Identity Management
- **Source L2** — historia de rama continua, inmutable y retenida; el SCS emite *Source Provenance Attestations* por revisión.
  Requisitos añadidos: History · Continuity · Source Provenance
- **Source L3** — el SCS aplica los controles técnicos de la organización sobre *Named References* concretas.
  Requisitos añadidos: Continuous technical controls · Protected Named References
- **Source L4** — revisión por **dos personas de confianza** en ramas protegidas.
  Requisito añadido: Two-party review

### Modelo de amenazas SLSA (taxonomía completa, IDs exactos) — **esto es el mapa de auditoría**

**Source threats**
- **(A) Producer** — el productor crea deliberadamente una revisión maliciosa
- **(B) Modifying the source**
  - **(B1) Submit change without review**: enviar sin revisión · un actor controla varias cuentas · usar cuenta robot para enviar el cambio · abuso de excepciones de reglas · actor muy privilegiado esquiva o desactiva controles
  - **(B2) Evade change management process**: alterar el histórico · reemplazar contenido etiquetado por contenido malicioso · saltar checks obligatorios · modificar código después de la revisión · enviar un cambio no revisable · copiar un cambio revisado a otro contexto · ataques al grafo de commits
  - **(B3) Render code review ineffective**: colusión con otra persona de confianza · engañar al revisor para que apruebe código malo · revisor aprueba a ciegas
  - **(B4) Render change metadata ineffective**: falsificar metadatos del cambio
- **(C) Source code management** — abuso de privilegios de administrador de plataforma · explotar vulnerabilidad del SCM

**Build threats**
- **(D) External build parameters** — build desde fork no oficial · desde rama/tag no oficial · con pasos de build no oficiales · con parámetros no oficiales · desde código modificado después del checkout
- **(E) Build process** — falsificar valores de la procedencia (distintos del digest de salida) · falsificar el digest de salida · comprometer al owner del proyecto · comprometer otro build · robar secretos criptográficos · envenenar la caché de build · comprometer al admin de la plataforma de build
- **(F) Artifact publication** — build con CI/CD no confiable · publicar paquete sin procedencia · manipular el artefacto después del CI/CD · manipular la procedencia
- **(G) Distribution channel** — build con CI/CD no confiable · emitir VSA desde intermediario no confiable · subir paquete sin procedencia ni VSA · sustituir paquete y VSA por otros · manipular artefacto tras la subida · manipular procedencia o VSA

**Usage threats**
- **(H) Package selection** — dependency confusion · typosquatting
- **(I) Usage** — uso indebido

**Dependency threats** — incluir una dependencia vulnerable · usar una herramienta de build comprometida · usar una dependencia de runtime comprometida durante el build · usar una dependencia comprometida en runtime

**Availability threats** — borrar el código · dependencia temporal o permanentemente no disponible · des-listar artefacto · des-listar procedencia

**Verification threats** — manipular las expectativas registradas · explotar colisiones de hash criptográfico

---

## BLOQUE 11 — S2C2F (Secure Supply Chain Consumption Framework, OpenSSF)

**Fuentes abiertas:** repo `ossf/s2c2f` vía GitHub API — `specification/framework.md` y `LICENSE.md`.
https://github.com/ossf/s2c2f

**LICENCIA — VERIFICADA:** `LICENSE.md` dice: especificaciones bajo **Community Specification License 1.0**; el código de ejemplo bajo MIT; en conflicto **manda la Community Specification License**. (La API de GitHub reporta `NOASSERTION` porque no reconoce esa licencia; hubo que leer el archivo.)
→ **No es CC-BY.** Se citan IDs y etiquetas cortas; **los títulos largos de requisito van parafraseados** y así se marca.

**Estructura del documento:** Introduction · About the S2C2F · What is the S2C2F · **Common OSS Supply Chain Threats** · S2C2F Practices · Implementation Guide (niveles de madurez, autoevaluación, requisitos, disponibilidad de tooling, implementación por nivel) · Appendix: Relation to SCITT · Appendix: Mapping to Other Specifications.

### Las 8 prácticas (nombres exactos)

1. **Ingest It**
2. **Scan It**
3. **Inventory It**
4. **Update It**
5. **Audit It**
6. **Enforce It**
7. **Rebuild It**
8. **Fix It + Upstream**

### Modelo de madurez: 4 niveles

- **L1** — caché de paquetes, inventario de OSS, escaneo y actualización. Es "lo que hace hoy la industria".
- **L2** — desplazar a la izquierda: configuración de ingesta más segura, bajar el MTTR de parcheo, respuesta a incidentes, automatización de actualizaciones. Objetivo declarado: parchear más rápido de lo que opera el adversario.
- **L3** — análisis proactivo de seguridad sobre los OSS más usados + reducir el riesgo de consumir paquetes maliciosos (escaneo de malware **antes** de la descarga, espejo del código fuente para poder analizarlo, búsqueda de backdoors).
- **L4** — aspiracional: **reconstruir el OSS en infraestructura de build confiable** y/o validar que es **reproducible**, firmarlo, generar y firmar SBOMs, y arreglar 0-days aguas arriba. Caro; se aplica a las dependencias más críticas.

### Requisitos (ID + nivel + etiqueta corta **parafraseada**)

*Ingest it* — **ING-1** (L1) usar gestores de paquetes públicos aprobados por la organización · **ING-2** (L1) usar un gestor de repositorio de binarios que cachee copia local (protege ante retiradas tipo left-pad) · **ING-3** (L3) capacidad de *deny list* para bloquear OSS malicioso conocido · **ING-4** (L3) espejar todo el código fuente OSS a una ubicación interna (BCDR + análisis proactivo + capacidad de fix)

*Scan It* — **SCA-1** (L1) escanear vulnerabilidades conocidas (CVE, advisories) · **SCA-2** (L1) escanear licencias · **SCA-3** (L2) detectar componentes en fin de vida · **SCA-4** (L3) escanear malware · **SCA-5** (L3) análisis de seguridad proactivo del OSS (0-days, backdoors) con divulgación responsable aguas arriba

*Inventory It* — **INV-1** (L1) inventario automatizado de todo el OSS usado en desarrollo · **INV-2** (L2) plan de respuesta a incidentes específico de OSS

*Update It* — **UPD-1** (L1) actualizar OSS vulnerable manualmente · **UPD-2** (L2) actualizaciones automatizadas · **UPD-3** (L2) mostrar las vulnerabilidades del OSS dentro del flujo de contribución (pull requests); **prerrequisito declarado: revisión de PR por dos personas**

*Audit It* — **AUD-1** (L3) **verificar la procedencia del OSS** (que el paquete trace de vuelta a un repo) · **AUD-2** (L2) auditar que los desarrolladores consumen OSS por la vía de ingesta aprobada · **AUD-3** (L2) **validar integridad** (firma digital o coincidencia de hash) de cada componente que entra al build · **AUD-4** (L4) **validar los SBOM** del OSS consumido (datos de procedencia, dependencias y firma del propio SBOM)

*Enforce It* — **ENF-1** (L2) configurar de forma segura los ficheros de fuentes de paquetes (`nuget.config`, `.npmrc`, `pip.conf`, `pom.xml`…), p. ej. *package source mapping* o feed único aguas arriba · **ENF-2** (L3) forzar el uso de un feed OSS curado

*Rebuild It* — **REB-1** (L4) reconstruir el OSS en entorno de build confiable **o** validar que se construye reproduciblemente · **REB-2** (L4) firmar digitalmente el OSS reconstruido · **REB-3** (L4) generar SBOMs de lo reconstruido · **REB-4** (L4) firmar los SBOMs producidos

*Fix It + Upstream* — **FIX-1** (L4) parchear un 0-day, reconstruir, desplegar internamente y contribuir el fix de forma confidencial aguas arriba

*(Nota: la tabla de requisitos usa el prefijo `REB-` para "Rebuild It"; el resto de prefijos coincide con la inicial de la práctica.)*

---

## BLOQUE 12 — Reproducible Builds (currículo de compilación reproducible)

**Fuente abierta:** https://reproducible-builds.org/docs/
**LICENCIA — VERIFICADA:** contenido del sitio bajo **CC BY-SA 4.0** (las hojas de estilo bajo MIT).
→ CC BY-SA es **copyleft fuerte para el texto**: si copiáramos redacción, el derivado tendría que ir bajo BY-SA, lo que choca con un repo MIT. **Sólo estructura y nombres de tema.**

**Índice de temas (nombres exactos):**

- **Introduction:** Which problems do Reproducible Builds Solve? · Definitions · History · Why reproducible builds? · Making plans · Academic publications
- **Achieve deterministic builds:** Commandments of reproducible builds · Reproducibility Quickstart Guide
- **Managing variance:** Variations in the build environment · **SOURCE_DATE_EPOCH** · Deterministic build systems · Volatile inputs can disappear · Stable order for inputs · Stripping of unreproducible information · Value initialization · Version information · Timestamps · Timezones · Locales · Archive metadata · Stable order for outputs · Randomness · **Build path** · System images · Rust · JVM · Helm
- **Define a build environment:** What's in a build environment? · Recording the build environment · Definition strategies · Proprietary operating systems
- **Distribute the environment:** Building from source · Virtual machine drivers · Formal definition
- **Verification:** Cryptographic checksums · Embedded signatures · Sharing certifications
- **Specifications:** SOURCE_DATE_EPOCH · BUILD_PATH_PREFIX_MAP (WIP)

---

## BLOQUE 13 — OWASP Top 10 CI/CD Security Risks (complemento CI/CD)

**Fuente abierta:** https://owasp.org/www-project-top-10-ci-cd-security-risks/
**LICENCIA — VERIFICADA:** el sitio declara **Creative Commons Attribution-ShareAlike v4.0** salvo indicación distinta.
→ Igual que arriba: **BY-SA, no copiar redacción**. IDs y títulos de riesgo son citables como identificadores.

1. **CICD-SEC-1** Insufficient Flow Control Mechanisms
2. **CICD-SEC-2** Inadequate Identity and Access Management
3. **CICD-SEC-3** Dependency Chain Abuse
4. **CICD-SEC-4** Poisoned Pipeline Execution (PPE)
5. **CICD-SEC-5** Insufficient PBAC (Pipeline-Based Access Controls)
6. **CICD-SEC-6** Insufficient Credential Hygiene
7. **CICD-SEC-7** Insecure System Configuration
8. **CICD-SEC-8** Ungoverned Usage of 3rd Party Services
9. **CICD-SEC-9** Improper Artifact Integrity Validation
10. **CICD-SEC-10** Insufficient Logging and Visibility

---

## BLOQUE 14 — OpenSSF Best Practices Badge (criterios)

**Fuentes abiertas:** https://www.bestpractices.dev/en/criteria/0 · repo `ossf/best-practices-badge` vía GitHub API.
**LICENCIA — VERIFICADA:** el README del repo lleva `SPDX-License-Identifier: (MIT OR CC-BY-3.0+)`; la API reporta `MIT`.
→ El doble licenciamiento **permite reutilizar bajo MIT**. Aun así aquí sólo se mapea estructura.

**Categorías y subsecciones (nivel *passing*):**

- **Basics:** Basic project website content · FLOSS license · Documentation · Other
- **Change Control:** Public version-controlled source repository · Unique version numbering · Release notes
- **Reporting:** Bug-reporting process · Vulnerability report process
- **Quality:** Working build system · Automated test suite · New functionality testing · Warning flags
- **Security:** Secure development knowledge · Use basic good cryptographic practices · Secured delivery against man-in-the-middle (MITM) attacks · Publicly known vulnerabilities fixed · Other security issues
- **Analysis:** Static code analysis · Dynamic code analysis

*(El check `CII-Best-Practices` de Scorecard, bloque 4, es exactamente el puente entre este badge y la medición automática.)*

---

## Tabla de licencias verificadas

| Fuente | Licencia verificada | Cómo se verificó | Qué se puede usar |
|---|---|---|---|
| LFD121 / `ossf/secure-sw-dev-fundamentals` | **CC-BY-4.0** | GitHub API `.license.spdx_id` + README | Único caso donde se podría reutilizar redacción, con atribución. Aun así aquí sólo estructura. Ojo: imágenes citadas (xkcd) con licencia propia; el material de examen no está en el repo. |
| Páginas de curso LF Training (LFD121, LFD125, LFS182, LFEL1001/1005/1006/1007/1012) | **Sin declaración → todos los derechos reservados** | Se abrió cada página; no hay nota de licencia | Sólo nombres de curso, códigos y nombres de módulo (hechos). Nada de redacción. |
| SLSA v1.0/v1.1/v1.2 | **Community Specification License 1.0** | Pie de página de slsa.dev | IDs de nivel, track y amenaza como identificadores. No reproducir texto normativo. |
| S2C2F (`ossf/s2c2f`) | **Community Specification License 1.0** (código de ejemplo MIT) | `LICENSE.md` leído (la API decía `NOASSERTION`) | IDs de práctica y requisito. Títulos largos aquí van **parafraseados**. |
| OpenSSF Scorecard (`ossf/scorecard`) | **Apache-2.0** | GitHub API | Nombres de check reutilizables (con aviso de licencia si se copiara código/texto). |
| OpenSSF Best Practices Badge | **MIT OR CC-BY-3.0+** | SPDX en README | Reutilizable bajo MIT. |
| Reproducible Builds | **CC BY-SA 4.0** | Nota del propio sitio | **Copyleft fuerte**: no copiar texto en un repo MIT. Sólo nombres de tema. |
| OWASP Top 10 CI/CD | **CC BY-SA 4.0** | Nota del pie de owasp.org | Igual: sólo IDs y títulos de riesgo. |

---

## Fuera de alcance (temas del currículo que NO se incorporan)

- **Poisoned Pipeline Execution (CICD-SEC-4) como técnica de ejecución.** El *hallazgo* auditable (un pipeline ejecuta código controlable desde un PR no confiable) sí entra; el procedimiento para **lograr ejecución** en el runner ajeno no. Razón: es ejecución remota destructiva sobre infraestructura, no evidencia de auditoría.
- **SLSA (E) "steal cryptographic secrets" / "poison the build cache" como procedimiento ofensivo.** Se auditará la *ausencia de aislamiento* que lo permite, no el robo ni el envenenamiento.
- **S2C2F FIX-1 / ING-3 vueltas del revés** (crear y distribuir paquetes maliciosos, deny-list evasion, typosquatting activo). Razón: publicar un paquete typosquat en un registro público daña a terceros no consentidos, fuera de cualquier alcance autorizado.
- **SLSA (B) "collude with another trusted person" / "trick reviewer into approving bad code".** Ingeniería social sobre personas concretas del proyecto auditado. Se audita el *control* (revisión de dos personas, protección de rama), no se ejecuta el engaño.
- **Sigstore/Fulcio: forjar identidad OIDC para obtener certificados efímeros.** Se verifica que la identidad de firma sea la esperada; no se suplanta.

---

## No verificado (declarado, no reconstruido)

1. **Páginas edX de LFD104x / LFD105x / LFD106x.** La URL edX que intenté devolvió **404** y el presupuesto de WebSearch estaba agotado. Los tres códigos y sus títulos **sí** están verificados (desde openssf.org/training/courses/), y el contenido es el mismo de LFD121 partido en tres, pero **el desglose de módulos tal como lo presenta edX no se abrió**.
2. **Temarios de LFC108, LFS180, LFS183 y SKF100.** Título, código y URL verificados desde openssf.org/training/; el temario **no se abrió**.
3. **Cambios de SLSA en v1.2 respecto al Build track.** El Build track L0-L3 está verificado en las páginas v1.0 y v1.1; en v1.2 verifiqué la existencia del track y su navegación, pero **la página de niveles v1.2 (`/spec/v1.2/levels`) devolvió 404** y `/spec/v1.2/tracks` no enumera niveles. Si v1.2 renombró o añadió niveles de Build, no lo sé.
4. **Track "Build Environment".** Aparece en discusiones de SLSA pero **no lo vi definido** en v1.2; **no se afirma que exista**.
5. **Licencia explícita del contenido interno de los cursos LFEL/LFS.** Ninguna de esas páginas declara licencia. Asumo "todos los derechos reservados" por defecto; no lo confirmé con LF Training.
6. **El contenido dentro de los cursos LFEL/LFS/LFD125.** Sólo tengo el índice público de módulos. No hay matrícula, así que **el detalle de cada módulo no está verificado**.
7. **Criterios del badge en niveles "silver" y "gold".** Sólo abrí `/criteria/0` (nivel *passing*).
