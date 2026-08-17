# Análisis de cobertura — área OpenSSF / Linux Foundation / cadena de suministro

**Fecha:** 2026-08-11 · **Modo:** solo lectura sobre el repo · **Pack auditado:** `supply-chain.md` (SUP-01..SUP-20), con contraste contra `web-api.md`, `infra-cloud.md`, `ai-safety.md`, `remediation.md` y `traceability.md`.

**Qué es este documento.** No es un resumen del temario. Es la respuesta a una sola pregunta: *qué espera un currículo profesional de OpenSSF/LF que un profesional sepa HACER, que un agente siguiendo nuestros 122 procedimientos NO encontraría hoy.*

**Regla de cobertura que apliqué.** Un tema está cubierto si un agente que ejecuta el procedimiento **encontraría el fallo**. Que el pack *mencione* el concepto en un campo "What rules it out" no es cobertura: es vocabulario. Tres ejemplos de la diferencia, todos reales en este corpus:

- `SUP-19` menciona "reproducible build" como criterio para descartar un falso positivo, pero **ningún procedimiento dice cómo comprobar si el build es reproducible**. No es cobertura.
- `SUP-12` detecta "el artefacto no está firmado". **No detecta que el artefacto sí está firmado y la verificación acepta a cualquier firmante**, que es el caso peor: hay control aparente y no hay control.
- `SUP-10` audita quién puede disparar el workflow de publicación. **No audita quién puede escribir el commit que ese workflow construye**, que es la mitad de arriba de la misma cadena (todo el Source track de SLSA).

---

## 1. Mapa tema → veredicto

Leyenda: **C** cubierto · **P** parcial (el agente encuentra una parte y se le escapa la otra) · **H** hueco · **R** ruido (teoría, gobernanza o formación, no procedimiento).

### LFD121 / LFD104x-106x (OpenSSF Secure Software Development Fundamentals)

| Bloque del temario | Veredicto | Dónde queda |
|---|---|---|
| Security Basics (qué es seguridad, requisitos, riesgo, protect/detect/respond) | R | Teoría. El corpus ya arranca de una postura operativa (`web-api.md` §0, `VER-05`, `VER-06`). |
| Privacy y Privacy Requirements | C | `PRV-01`..`PRV-11`, pack entero. El currículo se queda muy por debajo de lo que ya tenemos. |
| Secure Design Principles (Saltzer & Schroeder, least privilege, complete mediation) | R/C | Teoría como módulo; operativamente ya está encarnado en `INF-01`, `INF-11`, `INF-15`, `AI-05`, `REM-02`. No merece procedimiento propio. |
| Reusing External Software: *Selecting* OSS | P | `SUP-02` (mantenimiento, actividad) y `SUP-07` (señales de registro: edad, descargas, mantenedor). Falta el criterio de salud del proyecto que el currículo formaliza vía Scorecard/Badge → ver hueco **H-01** y **H-07**. |
| Reusing External Software: *Downloading and installing* | C | `SUP-01` (lock + hashes), `SUP-04` (`curl \| sh`), `SUP-05`/`SUP-06` (resolución de registro). |
| Reusing External Software: *Updating* | P | `SUP-02` mide la distancia a la última versión. No hay procedimiento sobre el **mecanismo** de actualización (bot de dependencias, auto-merge, MTTR) → hueco **H-09**, severidad media. |
| Input Validation (tipos, texto, ficheros, deserialización, XML/CSV/JSON) | C | `WEB-11`, `WEB-12`, `WEB-06`, `WEB-10`. Fuera de mi pack, cubierto. |
| Input Validation: **ReDoS** y Unicode/locales | H | Sin procedimiento en ningún pack. Ver **H-13** (dueño: `web-api`, no `supply-chain`). |
| Input Validation: search paths, variables de entorno, setuid/setgid, arranque seguro | H | Ya está **declarado** como hueco en `traceability.md` ("CLI, desktop y library surfaces"). Confirmo la declaración; no la duplico. |
| Processing Data Securely: buffer overflow, use-after-free, integer overflow, undefined behavior | H | Sin procedimiento. `traceability.md` declara "binary exploitation" fuera de alcance, pero **revisar C/C++/Rust `unsafe` en fuente no es explotación binaria**. Ver **H-13**. |
| Processing Data: credenciales por defecto y hardcodeadas | C | `SUP-16`, `SUP-17`, `SUP-18`, `WEB-19`, `INF-08`. |
| Calling Other Programs: SQLi, OS command, otras inyecciones, path traversal, logging, errores | C | `WEB-07`, `WEB-08`, `WEB-09`, `WEB-12`, `WEB-22`, `PRV-09`. |
| Calling Other Programs: DoS / disponibilidad en toda entrada | P | `WEB-18` (rate limiting), `WEB-20` (coste de query), `AI-19` (bucles). Falta la clase algorítmica (ReDoS, zip bomb, parser cuadrático) → **H-13**. |
| Sending Output: XSS, CSP, cabeceras, cookies, CSRF, open redirect, SSRF, CORS, caching | C | `WEB-13`..`WEB-16`, `WEB-10`, `WEB-02`, `WEB-22`. |
| Sending Output: side-channel attacks | H | Sin procedimiento (comparación de secretos no constante-tiempo, oráculos de tiempo en login). Severidad baja para auditoría de repo; lo dejo en **H-15**. |
| Verification: SAST, SCA, DAST, fuzzing, web scanners, combinación | P | El corpus tiene la **postura crítica** sobre herramientas (`tooling.md`, `VER-06`) y el triaje (`SUP-13`..`SUP-15`), que es más que el currículo. Lo que no tiene es auditar **el programa de verificación del objetivo** (¿el proyecto fuzz-ea? ¿corre SAST en CI?) → **H-10**, media. |
| Threat Modeling / STRIDE | R | Metodología del líder, no procedimiento de hallazgo. La bibliografía ya cita Shostack y Kohnfelder. |
| Cryptography (simétrica, hashes, asimétrica, CSPRNG, almacenamiento de contraseñas, TLS) | C | `WEB-19`, `WEB-03` (CSPRNG en tokens), `MOB-11`, `INF-03`. Cripto a nivel protocolo ya está declarado como hueco en `traceability.md`. |
| Other Topics: **Receiving vulnerability reports / responder a tiempo / VDP** | H | Sin procedimiento en ningún pack. Ver **H-06**, media. |
| Other Topics: Assurance cases, Formal methods | R | Fuera del alcance de una auditoría ofensiva. |
| Other Topics: **Harden the development environment (build y CI/CD) y el entorno de distribución** | P | `INF-13`..`INF-16` (GitHub Actions), `SUP-09`, `SUP-10`. Falta el lado fuente (**H-02**) y el envenenamiento de caché de CI (**H-11**). |
| Other Topics: AI/ML y seguridad | C | Pack `ai-safety.md` completo, muy por encima del módulo. |
| OWASP Top 10 / CWE Top 25 como módulos | R | Son la capa de trazabilidad del corpus, no contenido a incorporar. |

### LFS182 Sigstore

| Bloque | Veredicto | Dónde queda |
|---|---|---|
| Introduction to Sigstore, comunidad | R | Divulgación. |
| **Cosign: firmar y verificar** | P | `SUP-12` cubre *no hay firma*. No cubre *la verificación no restringe identidad, no falla cerrada, o verifica un digest distinto del que despliega* → **H-03**, ALTA. |
| **Fulcio (CA efímera) y Rekor (log de transparencia)** | H | El corpus nombra `cosign` como herramienta y nunca la raíz de confianza: TUF root, `--insecure-ignore-tlog`, instancia privada de Fulcio/Rekor. Entra dentro de **H-03**. |
| Policy Controller (admisión en Kubernetes) | H | `INF-10`/`INF-11` no miran admisión por política de firma. Entra en **H-03** (campo *Where to look*) y se solapa con `infra-cloud`. |
| **Gitsign (firma de commits y tags)** | H | Ningún procedimiento mira si los commits/tags están firmados ni qué identidad los firmó → entra en **H-02**. |
| Sigstore TSA (timestamping) | R | Detalle de implementación; sin hallazgo auditable propio hoy. |

### LFEL1007 (SBOM y firmas) · LFEL1006 (Scorecard) · LFEL1005 (self-assessment) · LFD125 · LFEL1001 (CRA) · LFEL1012 (AI/ML)

| Bloque | Veredicto | Dónde queda |
|---|---|---|
| LFEL1007: procedencia, control de fuente, tracking de dependencias, tags y firmas, automatizar | P | `SUP-01`, `SUP-11`, `SUP-12`. El eslabón *control de fuente* es exactamente **H-02**. |
| Scorecard: `Pinned-Dependencies` | C | `SUP-09` + `INF-16`. |
| Scorecard: `Dangerous-Workflow`, `Token-Permissions` | C | `INF-13`, `INF-14`, `INF-15`. |
| Scorecard: `Signed-Releases`, `SBOM` | C/P | `SUP-11`, `SUP-12` (generación y existencia). La *verificación* es **H-03**. |
| Scorecard: `Vulnerabilities` | C | `SUP-13`..`SUP-15`, con mejor criterio que el check. |
| Scorecard: **`Branch-Protection`, `Code-Review`** | H | **H-02**, ALTA. |
| Scorecard: **`Binary-Artifacts`** | H | **H-04**, ALTA. |
| Scorecard: **`Security-Policy`** | H | **H-06**, media. |
| Scorecard: **`Webhooks`** | H | **H-08**, media (apps y webhooks con escritura sobre el repo). |
| Scorecard: **`Dependency-Update-Tool`** | H | **H-09**, media. |
| Scorecard: **`Fuzzing`, `SAST`, `CI-Tests`** | H | **H-10**, media. |
| Scorecard: **`License`** | H | **H-12**, media (riesgo legal, no de seguridad). |
| Scorecard: `Maintained`, `Contributors`, `Packaging`, `CII-Best-Practices` | P/R | `SUP-02` cubre mantenimiento. El resto es puntuación de madurez, no hallazgo. |
| LFEL1005 self-assessment | R | Gobernanza. |
| LFD125 (managers) | R | Formación de mando. |
| LFEL1001 CRA | R/P | Cumplimiento regulatorio = consultoría, no pentest. Lo único con filo auditable es la obligación de canal de reporte y de SBOM, que ya recojo en **H-06** y `SUP-11`. |
| LFEL1012 (asistentes de IA, revisar cambios generados por IA) | C | `SUP-08` (slopsquatting, con la evidencia USENIX 2025) y `AI-15`, `AI-22`. Es el bloque donde el corpus va por delante del currículo. |

### SLSA v1.2

| Bloque | Veredicto | Dónde queda |
|---|---|---|
| Build track L0-L3 | C | `SUP-12` nombra los niveles y exige comparar nivel actual contra requerido. Bien resuelto. |
| **Source track L1-L4** (history, continuity, protected named references, two-party review, source provenance) | H | Citado en la trazabilidad de `SUP-10` **como etiqueta**, sin ningún procedimiento que lo verifique. Es el mayor hueco del área → **H-02**, ALTA. |
| Amenazas (A), (B1)-(B4): revisión evadida, historial alterado, tag reemplazado, checks saltados | H | **H-02** cubre B1/B2/B4. B3 (engañar al revisor) queda fuera de alcance por ser ingeniería social. |
| Amenaza (C) SCM, (E) build platform admin | R/fuera | Escalada contra administradores de plataforma: fuera de alcance declarado. |
| Amenaza (D) parámetros externos de build, código modificado tras checkout | C | `INF-13`, `INF-14`. |
| Amenaza (E) envenenar caché de build | H | **H-11**, media, dueño `infra-cloud` §4. |
| Amenaza (F)/(G) publicación y canal de distribución, VSA de intermediario no confiable | P | `SUP-12` en el lado emisor. El lado consumidor (verificar VSA/attestation antes de desplegar) es **H-03**. |
| Amenaza (H) dependency confusion, typosquatting | C | `SUP-05`, `SUP-06`, `SUP-07`. Cobertura fuerte. |
| Amenazas de dependencia (vulnerable, herramienta de build comprometida, dependencia de runtime) | C/P | `SUP-13`..`SUP-15`, `SUP-19`. La herramienta de build comprometida entra por `SUP-04` y **H-04**. |
| Amenazas de disponibilidad (borrar código, de-list) | H | **H-14**, media-baja: sin espejo/caché interno, la cadena se rompe sin que nadie ataque nada. |
| Amenazas de verificación (manipular las expectativas registradas, colisiones de hash) | H | "Manipular las expectativas" es exactamente la supresión de CVE sin justificar y el VEX aceptado a ciegas → **H-05**, ALTA. |

### S2C2F (8 prácticas)

| Requisito | Veredicto | Dónde queda |
|---|---|---|
| ING-1, ING-2 (gestores aprobados, caché/repo local de binarios) | P | `SUP-06` mira la resolución. No mira si existe caché/espejo → **H-14**. |
| ING-3 (deny list de OSS malicioso), ING-4 (espejo de fuente) | H | **H-14**. La cara ofensiva (publicar señuelos) está declarada fuera de alcance. |
| SCA-1 (CVE), SCA-4/SCA-5 (malware, análisis proactivo) | C | `SUP-13`..`SUP-15`, `SUP-19`. |
| **SCA-2 (licencias)** | H | **H-12**, media. |
| **SCA-3 (end-of-life)** | H | **H-01**, ALTA. Es el hueco con mejor relación hallazgo/esfuerzo de toda la lista. |
| INV-1 (inventario automatizado), INV-2 (plan de respuesta) | P/R | `SUP-11` genera SBOM. El plan de respuesta es gobernanza. |
| UPD-1..UPD-3 (actualización manual, automatizada, visible en PR) | H | **H-09**, media. |
| **AUD-1 (verificar procedencia), AUD-3 (validar integridad al ingerir)** | H | **H-03**. |
| **AUD-4 (validar SBOMs consumidos: procedencia, dependencias y firma)** | H | **H-05**. |
| AUD-2 (auditar que se consume por la vía aprobada) | P | `SUP-06` parcialmente. |
| ENF-1 (config segura de `.npmrc`, `pip.conf`, `NuGet.config`, `pom.xml`) | C | `SUP-06`, con el matiz correcto de `index-url` vs `extra-index-url`. |
| ENF-2 (feed curado obligatorio) | P | **H-14**. |
| REB-1..REB-4 (reconstruir, reproducibilidad, firmar lo reconstruido) | H | **H-07**, media. |
| FIX-1 (parchear 0-day y contribuir aguas arriba) | R | Operativa de respuesta, no auditoría. |

### Reproducible Builds · OWASP CI/CD Top 10 · Best Practices Badge

| Bloque | Veredicto | Dónde queda |
|---|---|---|
| Reproducible Builds (varianza, `SOURCE_DATE_EPOCH`, build path, orden estable, verificación) | H | **H-07**, media. `SUP-20` compara *tarball contra tag*; nadie reconstruye. |
| CICD-SEC-1 Insufficient Flow Control | P | `SUP-10` en publicación. Falta el lado fuente → **H-02**. |
| CICD-SEC-2 IAM inadecuado | C | `INF-15`, `SUP-10`. |
| CICD-SEC-3 Dependency chain abuse | C | `SUP-01`, `SUP-05`..`SUP-09`. |
| CICD-SEC-4 Poisoned Pipeline Execution | C | `INF-13`, `INF-14`. |
| CICD-SEC-5 PBAC insuficiente | C | `INF-15`. |
| CICD-SEC-6 Higiene de credenciales | C | `SUP-16`..`SUP-18`, `INF-05`. |
| CICD-SEC-7 Configuración insegura del sistema | P | `INF-16` (runners). Caché compartida → **H-11**. |
| **CICD-SEC-8 Uso no gobernado de servicios de terceros** | H | **H-08**, media. |
| CICD-SEC-9 Validación impropia de integridad de artefactos | P | `SUP-12` emisor; verificación consumidora → **H-03**. |
| CICD-SEC-10 Logging y visibilidad insuficientes | C | `INF-06`, `SUP-18`, `PRV-09`. |
| Badge `passing`: licencia FLOSS, documentación, versionado único, release notes | R/P | Higiene de proyecto. Lo auditable de verdad: licencia (**H-12**) y proceso de reporte (**H-06**). |
| Badge `passing`: proceso de reporte de bugs y de vulnerabilidades | H | **H-06**. |
| Badge `passing`: entrega asegurada contra MITM, cripto básica | C | `SUP-04`, `SUP-12`, `WEB-19`, `INF-03`. |
| Badge `passing`: análisis estático y dinámico | H | **H-10**. |

---

## 2. Huecos, ordenados por lo que el escuadrón deja de encontrar HOY

### Severidad ALTA (procedimiento redactado en §3)

**H-01 · Componentes y runtimes fuera de soporte (EOL).** *(S2C2F SCA-3)*
Hoy el escuadrón corre `osv-scanner`/`trivy`, no ve avisos para una rama sin soporte —porque nadie publica avisos de una rama sin soporte— y escribe "sin vulnerabilidades conocidas". Un runtime EOL invierte el significado de todo el §7: la ausencia de hallazgos deja de ser una medición y pasa a ser un estado no medido, y además garantiza que **nunca existirá versión corregida** para los CVE que sí aparezcan. `SUP-02` mide distancia a la última versión, que es otra cosa: una dependencia puede estar al día dentro de una rama muerta. → **SUP-24**.

**H-02 · Controles de flujo en la fuente: rama sin protección, auto-aprobación, tags movibles, bypass de administrador.** *(SLSA Source L2-L4, amenazas B1/B2/B4; Scorecard `Branch-Protection` y `Code-Review`; CICD-SEC-1)*
Hoy `SUP-10` pregunta quién puede *disparar* la publicación. Nadie pregunta quién puede *escribir el commit que se publica*. Con una sola cuenta de mantenedor comprometida —el vector real de `chalk`/`debug` en septiembre de 2025— se empuja a `main`, se mueve el tag `v1.4.2` al commit nuevo y el pipeline firma y publica el resultado con toda la ceremonia intacta: firma válida, procedencia válida, SBOM válido, código de otro. El escuadrón hoy no encuentra nada. → **SUP-21**.

**H-03 · La verificación de firma no verifica nada.** *(LFS182 Sigstore completo; S2C2F AUD-1/AUD-3; SLSA amenazas F/G; CICD-SEC-9)*
`SUP-12` distingue "hay firma" de "no hay firma". El fallo caro es el tercer estado: hay firma, hay comando de verificación, y la verificación no restringe la identidad del firmante ni el emisor OIDC, o corre en un paso que no bloquea el despliegue, o verifica por tag y despliega por tag (el digest puede cambiar entre ambos). Es la clase de hallazgo de mayor valor de toda la auditoría —control aparente, control nulo— y el escuadrón hoy pasa de largo porque ve un `cosign verify` en el script y lo cuenta como control presente. → **SUP-22**.

**H-04 · Binarios en el árbol de fuentes consumidos por el build.** *(Scorecard `Binary-Artifacts`; caso xz)*
`SUP-20` compara el tarball publicado contra el tag. No mira lo que ya está commiteado: un ELF en `tools/`, un `.jar` sin receta, un `.min.js` sin fuente, un "fixture" binario que nadie lee salvo el `Makefile`. Ningún SCA lo ve —no hay entrada en el manifiesto, no hay CVE que casar— así que un escaneo limpio es exactamente el resultado esperado y no significa nada. Es código no revisable ejecutándose dentro del build, que es la lección literal de xz. → **SUP-23**.

**H-05 · VEX y supresiones aceptadas sin justificación; SBOM de terceros sin validar.** *(S2C2F AUD-4; SLSA "manipular las expectativas registradas")*
El corpus es excelente bajando severidad por alcanzabilidad (`SUP-13`), y no tiene **ningún** procedimiento para el artefacto donde esa decisión se registra ni para la afirmación equivalente de un proveedor. Hoy el escuadrón lee `.trivyignore`, `osv-scanner.toml` o el VEX del proveedor y da por bueno lo que dicen: cada línea suprimida es un CVE que desaparece del informe sin que nadie haya re-derivado la razón, y una supresión sin fecha ni dueño es el escondite perfecto para el CVE que sí importa. → **SUP-25**.

### Severidad MEDIA

**H-06 · Sin canal de reporte de vulnerabilidades ni proceso de divulgación.** *(LFD121 "Receiving Vulnerability Reports"; Scorecard `Security-Policy`; Badge; CRA)*
Sin `SECURITY.md`, sin contacto, sin reporte privado habilitado y sin ventana de embargo, el propio entregable de esta auditoría no tiene destino: la única vía queda ser pública. Además, para producto comercial en la UE es obligación regulatoria, no higiene. No lo subo a alta porque el hallazgo es documental y su impacto es de gobernanza, no explotable.

**H-07 · El build no es reproducible y nadie lo ha comprobado.** *(Reproducible Builds; S2C2F REB-1..REB-4; SLSA Build L3/L4)*
`SUP-19` usa "hay build reproducible" como criterio para descartar un falso positivo sobre un bundle minificado, sin decir cómo comprobarlo. Sin reproducibilidad no se puede afirmar que el binario publicado corresponde a la fuente auditada, que es el supuesto sobre el que descansa **todo** el pack. Media y no alta porque un doble build con `diffoscope` es caro en tiempo y falla por causas triviales (timestamps, rutas, orden), lo que produce mucho ruido si se convierte en check obligatorio.

**H-08 · Apps, integraciones y webhooks de terceros con escritura sobre el repositorio.** *(CICD-SEC-8; Scorecard `Webhooks`)*
Una GitHub App con permiso de escritura o un webhook sin secreto es una puerta trasera de cadena de suministro que no aparece en ningún fichero del repo. Media porque normalmente exige visibilidad de organización que una auditoría de repositorio no tiene: el entregable sería una petición de evidencia, no un escaneo.

**H-09 · Mecanismo de actualización de dependencias: bot, auto-merge y MTTR.** *(S2C2F UPD-1..UPD-3; Scorecard `Dependency-Update-Tool`)*
Sin bot, la deuda de `SUP-02` no se cierra nunca. Con bot y auto-merge sin revisión —y con la cuenta del bot exenta de la revisión de dos personas— se convierte en un canal de entrada automático para la versión maliciosa. Media: el hallazgo real es una variante de H-02 sobre la cuenta del bot.

**H-10 · El proyecto auditado no tiene programa de verificación propio.** *(LFD121 Verification; Scorecard `SAST`, `Fuzzing`, `CI-Tests`; Badge análisis estático/dinámico)*
Sin SAST ni fuzzing ni tests en CI, todo lo que esta auditoría encuentre volverá a aparecer en tres meses. Media: es un hallazgo de madurez, y `VER-06` ya nos obliga a no confundirlo con seguridad.

**H-11 · Envenenamiento de caché de CI a través de fronteras de confianza.** *(SLSA amenaza E "poison the build cache"; CICD-SEC-7)*
Una caché escrita desde un workflow de PR y restaurada por un workflow de confianza es ejecución de código del atacante en el pipeline privilegiado, y `INF-13`..`INF-16` no la miran. Dueño natural: `infra-cloud` §4, no `supply-chain`. La cara ofensiva (envenenar de verdad) queda fuera de alcance; lo auditable es la clave de caché y quién puede escribirla.

**H-12 · Licencias de las dependencias del objetivo.** *(S2C2F SCA-2; Scorecard `License`)*
El corpus es rigurosísimo con las licencias de **sus propias herramientas** (`tooling.md`, `NOTICE.md`) y no tiene ningún procedimiento para auditar las del objetivo: copyleft entrando en un producto distribuido, ausencia de `LICENSE`, licencia incompatible con el modelo de distribución. Media, y con la etiqueta honesta: es riesgo legal, no de seguridad.

**H-13 · Seguridad de memoria, aritmética y complejidad algorítmica.** *(LFD121 Processing Data Securely; ReDoS; Unicode/locales)*
Buffer overflow, use-after-free, doble free, integer overflow, comportamiento indefinido, ReDoS y validación de texto Unicode no tienen procedimiento en ningún pack. `traceability.md` declara "binary exploitation" fuera de alcance, pero **revisar un `unsafe` de Rust, un `strcpy` o un regex catastrófico en el código fuente no es explotación binaria**: es revisión de código y es exactamente lo que el currículo profesional espera. **No es hueco de mi área**: el dueño sería `web-api.md` o un pack nuevo de código nativo. Lo dejo señalado y no propongo procedimiento SUP para no meter en el pack equivocado un tema de otro rol.

**H-14 · Disponibilidad de la cadena: sin espejo, sin caché interno, dependencia que puede desaparecer.** *(S2C2F ING-2/ING-4/ENF-2; SLSA availability threats)*
Un `left-pad` o un mantenedor que borra el repo rompe el build sin que haya ataque. Media-baja para un pentest, alta para un cliente con requisitos de continuidad; lo correcto es reportarlo como riesgo operativo con esa etiqueta.

### Severidad BAJA

**H-15 · Canales laterales (comparación no constante en tiempo, oráculos de temporización).** Auditable en fuente (`==` sobre un HMAC, comparación de tokens), pero de impacto normalmente bajo y con altísimo ruido. Dueño: `web-api`.

**H-16 · Metadatos de cambio forjables (commits sin firmar, `user.email` arbitrario).** Queda absorbido por el campo *Where to look* de **SUP-21**; no merece procedimiento propio.

**H-17 · Plataformas de CI distintas de GitHub Actions.** Ya declarado en `traceability.md` y en `coverage.md`. El currículo no aporta nada nuevo aquí; lo menciono solo para confirmar que sigue vigente.

---

## 3. Borradores de procedimientos nuevos (inglés, estilo del corpus)

> Numeración: continúan el pack `supply-chain.md`. Implican dos secciones nuevas (§10 Source integrity and verification, §11 Component support lifecycle) o su reparto entre §5, §6 y §7; esa decisión es de quien integre.
>
> **Tres cosas que quien los escriba debe verificar antes de publicar** (yo no las verifiqué contra fuente en esta sesión y no las doy por ciertas): (a) qué banderas exige exactamente la versión mayor de `cosign` que se cite; (b) la ortografía literal de los valores de estado y justificación de OpenVEX; (c) si se quiere citar `S2C2F` o los nombres de check de Scorecard en el campo *Traceability*, hace falta añadir su fila a `traceability.md` con su licencia (Community Specification License 1.0 y Apache-2.0 respectivamente) — por eso, en estos borradores, esos identificadores viven en *Tooling*, no en *Traceability*.

### SUP-21 Source-side flow control: unprotected branches, self-approval and movable release tags

**Where to look**
- Protection of the default branch and of any branch a release is built from: number of required approving reviews, dismissal of stale approvals, required review from `CODEOWNERS`, required status checks, `allow_force_pushes`, `allow_deletions`, and whether administrators can bypass all of it.
- Tag protection: whether the tag the release workflow builds from (`on: push: tags:`) can be moved or deleted, and whether tags and commits are required to be signed.
- `.github/CODEOWNERS` present but with no rule making it mandatory; bot and machine accounts exempted from review; auto-merge enabled on dependency pull requests.
- In the tree, offline: `git log --format='%h %an <%ae> %G? %s'` on the released range, merge commits authored and approved by the same identity, and commits whose author email is not in any protected domain.

**Vulnerable pattern**
```text
main            0 required reviewers · force-push allowed · admins bypass
tags 'v*'       not protected
release.yml     on: { push: { tags: ['v*'] } }
# whoever can move the tag chooses the source code of the next signed release
```
**What rules it out (false positive)**
- The controls are enforced by an organization-level ruleset that is not visible from the repository. Absence of evidence in the tree is not evidence of absence of the control: ask for the ruleset export before writing the finding, and record it if you do not get it.
- The project is a single-maintainer repository with no external contributors: two-party review is unattainable by construction, so report the achievable level (history, continuity, protected references) rather than a review requirement nobody can meet.

**Minimal test**: pick one published release and reconstruct the chain tag → commit → author → reviewer. If a single identity — human, bot or CI token — could have produced that commit and moved that tag without a second party, the finding is confirmed. Report the SLSA Source level the project actually meets, not "there is no branch protection".\
**Traceability**: `CWE-284` · `CWE-732` · `CWE-345` · `CWE-494` · `A03:2025` · `A08:2025` · `CICD-SEC-1` · `CICD-SEC-2` · `SLSA Source L2` · `SLSA Source L3` · `SLSA Source L4` · `SSDF PO` · `NIST 800-53 CM` · `CCM CCC`
**Tooling**: offline, `git log --show-signature` and `git for-each-ref --format='%(refname) %(objecttype)'` tell you what was signed and whether a tag points at a commit or at an annotated object. Everything else — protection rules, rulesets, review settings — lives outside the tree and is an **evidence request**, not a scan: `gh api` needs network and a token, and reading it with an under-privileged token silently returns "no protection" for a protected branch, which is a false positive you would be generating yourself. OpenSSF Scorecard covers this ground with its `Branch-Protection` and `Code-Review` checks and has the same limitation: without an administrative token its verdict is partial, so never quote its score as if it were a measurement of the repository.

### SUP-22 Signature verification that accepts any signer, or that gates nothing

**Where to look**
- Every `cosign verify`, `cosign verify-attestation`, `cosign verify-blob`, `gh attestation verify`, `slsa-verifier` or `gpg --verify` invocation in install scripts, deployment jobs, Dockerfiles and documentation: does it constrain **who** signed (identity and OIDC issuer, or a specific key) or only **that** something signed?
- Whether the result blocks anything: verification in a step followed by `|| true`, in a job whose failure does not fail the workflow, or after the artifact has already been pulled and run.
- Whether the verified reference is the deployed reference: verifying a mutable tag and then deploying that same tag is verifying one artifact and running another.
- Trust root and transparency log: a custom Fulcio/Rekor instance, `--insecure-ignore-tlog`, `--insecure-ignore-sct`, an unpinned TUF root, or a GPG keyring downloaded from the same host that serves the artifact.
- Admission-time enforcement in clusters (policy controller, Kyverno) versus verification that only ever runs on a developer laptop.

**Vulnerable pattern**
```bash
cosign verify --certificate-identity-regexp '.*' \
              --certificate-oidc-issuer-regexp '.*' \
              ghcr.io/org/app:1.4.2 || true
# any workflow in any repository on that issuer produces a certificate this accepts,
# and the '|| true' means even a hard failure does not stop the deploy
```
**What rules it out (false positive)**
- The invocation pins both the signer identity (or the exact public key) and the issuer, the artifact is referenced by immutable digest, and the check runs where it can deny — admission control or a release gate — not as an advisory step.
- Verification is key-based against a key distributed out of band; then the identity *is* the key, and what you audit instead is where that key lives, how it rotates and how it would be revoked.

**Minimal test**: read the project's own documented verification command and answer three questions in writing — which identities it accepts, whether a failure stops the deployment, and whether the digest it verified is the digest that runs. Then re-run that exact command against a real published artifact. Verifying a public signature is reading, not intrusion; **do not sign anything, do not impersonate a signing identity, and do not push to any transparency log.**\
**Traceability**: `CWE-347` · `CWE-345` · `CWE-295` · `CWE-494` · `A03:2025` · `A08:2025` · `CICD-SEC-9` · `SLSA Build L2` · `SLSA Build L3` · `SSDF PS` · `NIST 800-53 SR` · `CCM CEK`
**Tooling**: `cosign` (Apache-2.0). **Check which major version the pipeline pins before you judge the invocation**: the flags a keyless verification requires changed between major versions, so an older command carried into a newer pipeline, or a wildcard regexp, reproduces the permissive behaviour — read the pinned version's own documentation rather than assuming. This is the counterpart of `SUP-12`: that procedure finds the missing signature, this one finds the signature that proves nothing, which is the more expensive of the two because the project already believes it has the control.

### SUP-23 Binary artifacts committed to the source tree and consumed by the build

**Where to look**
- Tracked files that are not text: executables, `.jar`, `.dll`, `.so`, `.dylib`, `.wasm`, `.class`, `.pyc`, archives, and minified bundles with no corresponding source — especially under `tools/`, `scripts/`, `vendor/`, `third_party/`, `test/`, `fixtures/`.
- The build steps that read them: `java -jar tools/*.jar`, a wrapper JAR, a checked-in compiler plugin, an `LD_PRELOAD`, a shared object loaded by a native extension.
- History for each blob: `git log --diff-filter=A -- <path>` — who added it, when, and whether that same commit also touched build machinery.

**Vulnerable pattern**
```text
tools/protoc-gen-x          ELF, added 2021, no build recipe in the repo, invoked by `make build`
tests/fixtures/payload.bin  binary "fixture" that no test reads — the Makefile does
```
**What rules it out (false positive)**
- The binary is the declared output of a recipe that lives in the same repository and you can regenerate it, or it is a vendored artifact pinned by digest whose upstream source you can diff.
- It is genuinely inert data — an image, a font, a fuzzing corpus — and no build step reads it. Prove it by finding the reader, not by the file's location.

**Minimal test**: list every tracked non-text file, subtract the documented assets, and for each survivor find what reads it. A binary nobody reads is dead weight; a binary the build reads is unreviewable code executing inside your build. Read it as data if you must (`strings`, a disassembler); **never execute it to find out what it does.**\
**Traceability**: `CWE-506` · `CWE-494` · `CWE-829` · `CWE-1357` · `A03:2025` · `A08:2025` · `SLSA Source L2` · `SLSA Build L3` · `SSDF PS` · `NIST 800-53 SR`
**Tooling**: `git ls-files -z | xargs -0 file --mime-type` plus `git log --diff-filter=A`. Every dependency scanner in this pack is **structurally blind** here: there is no manifest entry and no version to match, so a clean `osv-scanner`, `trivy` or `grype` run is the expected output over a repository full of committed binaries and says nothing at all — state that explicitly instead of letting the clean run imply coverage. OpenSSF Scorecard exposes the same class through its `Binary-Artifacts` check. This is the half of **xz utils, CVE-2024-3094** that `SUP-20` does not reach: `SUP-20` compares the release against the tag, while the malicious object there was a precompiled blob sitting among binary test files.

### SUP-24 Components and runtimes past their end of support

**Where to look**
- Runtime and platform majors: `engines` in `package.json`, `.nvmrc`, `python_requires`, `FROM <image>:<tag>` and the distribution release inside it, `runtime:` in serverless configuration, `<java.version>`, `TargetFramework`, and the major line of the web framework or ORM.
- Dependencies pinned to a major line the maintainer no longer patches even though a newer major exists.
- Managed services declared in IaC: database engine versions past extended support.

**Vulnerable pattern**
```dockerfile
FROM node:<major>-alpine     # the branch stopped receiving security releases months ago
# every scanner reports "no known vulnerabilities": nobody publishes advisories
# for a branch nobody supports
```
**What rules it out (false positive)**
- The vendor or the distribution sells extended support for that branch and the project pays for it. Ask for evidence of the subscription, not for the intent.
- The version only exists in a build stage of a multi-stage build and contributes no layer to the shipped artifact.

**Minimal test**: for each runtime, framework and base image, record three fields — version in use, the vendor's declared end-of-support date, and the source of that date. Where the date has passed, **downgrade every "no known vulnerabilities" result for that component from *clean* to *unmeasured* in the report**, and say why. Distance to the latest release, which is what `SUP-02` measures, is a different question: a dependency can be perfectly up to date inside a dead branch.\
**Traceability**: `CWE-1104` · `CWE-1395` · `CWE-1329` · `A03:2025` · `A06:2025` · `SSDF PW` · `SSDF RV` · `NIST 800-53 SA` · `NIST 800-53 SR` · `CCM TVM` · `CIS v8.1 Control 2`
**Tooling**: the primary source is the vendor's own support calendar; if you use an aggregator, name it in the report and treat its dates as secondary evidence. The lifecycle question is precisely where `osv-scanner`, `trivy`, `grype` and `npm audit` are silent by design, because advisory feeds track supported branches — so their silence here is not a measurement. Context that makes this worth checking first: the median dependency runs **278 days out of date** and **42% of services use unmaintained libraries** (Datadog State of DevSecOps 2026), and this procedure is what stops that debt from being reported as a clean bill of health. S2C2F files the requirement as `SCA-3`.

### SUP-25 Suppressed CVEs and supplier "not affected" claims accepted without justification

**Where to look**
- Suppression and ignore files: `.trivyignore`, `.grype.yaml`, `osv-scanner.toml`, `audit-ci.json`, `npm audit` overrides, `pip-audit` ignore flags in CI, and the dependency-check suppression XML.
- VEX documents the project publishes or consumes: `*.vex.json` (OpenVEX), CSAF advisories, VEX embedded in a CycloneDX SBOM. For each entry, whether it carries a status, a justification, an author and a date.
- Third-party SBOMs and VEX received from a supplier: whether their provenance and signature are checked before their claims are trusted.
- CI configuration that fails the build only above a severity threshold, which is a silent suppression of everything below it.

**Vulnerable pattern**
```text
.trivyignore
CVE-XXXX-NNNNN        # "false positive"
# no status, no justification, no author, no date, no expiry
# — and the same line is now three years old
```
**What rules it out (false positive)**
- The entry carries a status and a justification that you can re-derive yourself with `SUP-13`: the vulnerable symbol is not imported, or not reachable, or the component is not present in the shipped artifact. A dated, owned, expiring suppression is normal operation, not concealment.
- The supplier's claim comes with evidence you can re-check locally against the artifact you actually consume. Then record it as *verified*, not as *accepted*.

**Minimal test**: take every suppressed or "not affected" entry and re-derive the claim independently with the reachability test in `SUP-13`. Report the ones you cannot re-derive as unverified acceptances, with their age and their owner; report the count and the oldest one rather than the full list. **A suppression you did not re-derive is a finding you removed from your own report on someone else's word.**\
**Traceability**: `CWE-1395` · `CWE-1104` · `CWE-345` · `A03:2025` · `A06:2025` · `A09:2025` · `SSDF RV` · `NIST 800-53 RA` · `CCM TVM` · `CIS v8.1 Control 7`
**Tooling**: the suppression files are read by hand; there is no scanner for the honesty of a suppression, by construction — every tool in §7 reads these files in order to obey them, so running the scanner is the one thing that will never surface this. Cross-check the SBOM the supplier ships against `syft` output over what you actually consume. Verify the status and justification vocabulary against the OpenVEX specification itself before quoting it. S2C2F files the consumed-SBOM validation requirement as `AUD-4`, and the SLSA threat model lists tampering with the recorded expectations as a verification threat in its own right — the attacker's cheapest move is not to hide the vulnerable component, it is to get you to write down that it does not matter.

---

## 4. Ruido descartado, y por qué

Un informe que propone ochenta procedimientos es inútil. Estos temas del temario **no** merecen procedimiento y esta es la razón:

1. **Security Basics completo** (qué es seguridad, requisitos, gestión de riesgo, protect/detect/respond, "qué es una vulnerabilidad"): teoría introductoria. El corpus ya opera desde una postura más avanzada (`VER-05` con cuatro estados y ninguno es "seguro").
2. **Secure Design Principles / Saltzer & Schroeder**: marco conceptual. Least privilege y complete mediation ya están encarnados operativamente en `INF-01`, `INF-11`, `INF-15`, `AI-05`, `REM-02`. Un procedimiento "comprueba el mínimo privilegio" no se puede ejecutar.
3. **Threat Modeling / STRIDE**: metodología de diseño, del líder y del cliente, no procedimiento de hallazgo. Ya está en la bibliografía (Shostack, Kohnfelder).
4. **Assurance cases y Formal methods**: fuera del alcance de una auditoría ofensiva con tiempo acotado.
5. **LFD125 Security for Software Development Managers** entero: formación de mando.
6. **LFEL1005 Security Self-Assessments**: gobernanza; el proyecto se autoevalúa, nosotros auditamos. Sería duplicar el trabajo desde el lado equivocado.
7. **"Getting Started" / "Integrate Scorecard with your project" / "View a detailed Scorecard" / "Work with your Scorecard"**: operativa de una herramienta concreta. Lo que sí vale son los *checks* como taxonomía de hallazgos, ya repartidos arriba.
8. **Modelos de madurez como puntuación** (S2C2F L1-L4, niveles del Badge, la nota de Scorecard): **una puntuación no es un hallazgo**. `SUP-12` ya fija el criterio correcto —"está en L1 y el requisito del cliente es L3" sí, "no cumple SLSA" no— y ese criterio se hereda; no hace falta un procedimiento por nivel.
9. **CRA como cumplimiento regulatorio**: consultoría de conformidad, no pentest. Solo conservo su filo auditable (canal de reporte, SBOM), ya recogido en H-06 y `SUP-11`.
10. **Módulos de inyección, validación de entrada y codificación de salida de LFD121** (SQLi, XSS, CSRF, CORS, deserialización, path traversal, open redirect, SSRF): ya cubiertos por `WEB-07`..`WEB-16` con más profundidad que el temario. Reproducirlos en `supply-chain.md` sería duplicación entre packs, que la regla 3 de `knowledge/README.md` prohíbe explícitamente.
11. **OWASP Top 10 y CWE Top 25 como módulos del curso**: son la capa de trazabilidad del corpus, no contenido a incorporar.
12. **Comunidad de Sigstore / cómo contribuir**: divulgación.
13. **LFC108, LFS180, LFS183, SKF100**: sus temarios **no se abrieron** en el mapeo previo. No se puede analizar cobertura contra un temario que no existe verificado, y reconstruirlo de memoria sería fabricarlo.
14. **Todo lo declarado fuera de alcance en el mapa de fuentes** (PPE como técnica de ejecución, robo de secretos de firma, envenenar caché de verdad, publicar señuelos de typosquat, ingeniería social contra revisores, suplantar identidad OIDC en Fulcio, escalar contra administradores de plataforma, ataques de disponibilidad, evasión de deny-list): se mantiene fuera. En los cinco borradores la contrapartida auditable es siempre leer el control, nunca ejercer el ataque, y así está escrito en cada campo *Minimal test*.

---

## 5. Notas de licencia (cumplidas en este documento)

- **No se copió redacción de ninguna fuente.** Los cinco borradores están escritos desde cero, en el estilo del corpus, siguiendo su misma política (`traceability.md` §Citation policy).
- Se citan como hechos: códigos de curso (`LFD121`, `LFS182`, `LFEL1006`…), nombres de módulo, nombres de check de Scorecard (Apache-2.0, identificadores técnicos), IDs de requisito de S2C2F (`SCA-3`, `AUD-4`…) y designaciones de nivel de SLSA (`Build L2`, `Source L4`). La estructura de un temario es un hecho; su redacción no.
- **SLSA y S2C2F son Community Specification License 1.0, no Creative Commons**: no se reproduce texto normativo ni tablas de requisitos.
- **Reproducible Builds y OWASP son CC BY-SA 4.0** (copyleft fuerte, incompatible con MIT si se copiara texto): solo se usan nombres de tema e IDs.
- Si en la integración se decide citar `S2C2F` o `Scorecard` en el campo *Traceability* de los procedimientos, hay que añadir su fila a la tabla de `traceability.md` con esa licencia declarada. Por eso los borradores los mantienen en *Tooling*.

## 6. No verificado en esta sesión

- No abrí ninguna fuente externa: trabajé sobre el mapa de temario entregado y sobre el corpus real. Todo lo que el mapa marcaba como `no_verificado` lo traté como inexistente, no como cierto (afecta a LFC108, LFS180, LFS183, SKF100, los niveles del Badge silver/gold, el desglose de edX y el detalle interno de los cursos LFEL/LFS).
- Tres afirmaciones dentro de los borradores requieren verificación contra fuente antes de publicarse, y están marcadas en el propio texto: las banderas exigidas por la versión mayor de `cosign` que se cite, el vocabulario literal de estados y justificaciones de OpenVEX, y las fechas concretas de fin de soporte que se usen como ejemplo (por eso el ejemplo de `SUP-24` es deliberadamente genérico, sin versión).
