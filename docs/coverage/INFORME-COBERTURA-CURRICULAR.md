# Informe de cobertura curricular — ethical-hacker-squad

**Fecha:** 2026-08-16 · **Modo:** solo lectura sobre `/Users/cristianajavi/ethical-hacker-squad`. Cero escrituras en el repo.
**Corpus medido:** 122 procedimientos verificados en disco — `WEB-01..22` (22), `MOB-01..15` (15), `INF-01..18` (18), `SUP-01..20` (20), `AI-01..22` (22), `PRV-01..11` (11), `REM-01..07` + `VER-01..07` (14 encabezados en `remediation.md`).
**Entrada:** 5 áreas que mapearon currículos profesionales (PortSwigger · certs cloud MS/AWS/GCP · OpenSSF/SLSA/S2C2F · certs ofensivas + NICE · OWASP AI + MAS) y los contrastaron contra el corpus.

Reencuadre aplicado sin discutirlo: un currículo no es texto que copiar, es un **mapa de competencias**. Lo que sigue es análisis de cobertura, no resumen didáctico.

---

## 0. Hallazgo de proceso que hay que leer antes que la métrica

**Dos colisiones de ID entre áreas que trabajaron en paralelo.** Si se hubiesen escrito los borradores tal cual, el corpus habría quedado corrupto:

| ID reclamado | Área A | Área B | Resolución |
|---|---|---|---|
| `WEB-23` | XXE / parseo XML inseguro (PortSwigger) | File inclusion y carga dinámica (certs ofensivas) | XXE = `WEB-23`, file inclusion = `WEB-28` |
| `INF-19` | Escalada IAM sin comodín (certs cloud) | Escalada local en imágenes/aprovisionamiento (certs ofensivas) | IAM = `INF-19`, local privesc = `INF-27` |

Esto no es anecdótico: es exactamente el fallo que un gate de unicidad de ID atrapa en 200 ms y una revisión humana deja pasar. Va como gate obligatorio en §1.3.

**Contradicción entre áreas, resuelta contra el área que se equivocó.** El área de certs ofensivas marcó *"NICE DD-WRL-005 · product end-of-life → CUBIERTO por `SUP-02`, `SUP-13`, `SUP-14`"*. El área OpenSSF demostró que **no** lo está: `SUP-02` mide *distancia a la última versión*, que es otra pregunta — una dependencia puede estar perfectamente al día dentro de una rama muerta, y ningún feed de advisories publica avisos de una rama sin soporte. Se resuelve a favor de OpenSSF (`SUP-24` entra al backlog).
**Consecuencia para la métrica: la columna "cubierto" es autoevaluada por cada área y tiene al menos un falso positivo demostrado. El 55 % de abajo es una cota SUPERIOR, no una medición.**

---

## 1. La métrica: Cobertura de Currículo Profesional (PCC)

### 1.1 Definición

```
PCC(pack) = temas_cubiertos(pack) / (temas_cubiertos(pack) + huecos_en_alcance(pack))
```

Tres reglas que hacen la métrica falsable en vez de decorativa:

1. **"Cubierto" = un agente siguiendo el procedimiento citado ENCONTRARÍA el fallo.** "El pack menciona X" no cuenta. Este criterio ya lo aplicaron las cinco áreas y es el que degradó `WEB-10` de "cubre XXE" a "cubre XXE sólo en su forma de SSRF".
2. **El denominador excluye lo descartado.** Todo lo que cayó en `ruido_descartado` (weaponización, evasión, GRC, teoría introductoria, operativa de SOC) sale del denominador por decisión explícita y trazable. La métrica mide cobertura de **lo que decidimos auditar**, no de todo lo que enseña un temario.
3. **Un tema señalado por 2+ áreas cuenta UNA vez** (dedup en §2), pero sube de prioridad.

### 1.2 La cifra real de hoy

| Pack | Cubiertos | Huecos en alcance | **PCC** | Huecos ALTA | Veredicto |
|---|---:|---:|---:|---:|---|
| `infra-cloud` | 16 | 24 | **40 %** | **9** | 🔴 El peor. Ver abajo. |
| `web-api` | 23 | 19 | **55 %** | 6 | 🟠 Profundo pero con clases enteras ausentes |
| `supply-chain` | 21 | 15 | **58 %** | 5 | 🟠 Falla en el lado *consumidor* de sus propios controles |
| `ai-safety` | 20 | 13 | **61 %** | 6 | 🟠 Fuerte en capa prompt, ciego en capa artefacto/runtime |
| `mobile` | 14 | 7 | **67 %** | 3 | 🟡 El mejor relativo; los 3 huecos son MASVS-nativos |
| `privacy-abuse` | 7 | 3 | **70 %** | 2 | 🟡 Buen ratio, muestra pequeña |
| `remediation`+`VER` | 4 | 4 | **50 %** | 1 | ⚪ Muestra demasiado pequeña para concluir |
| **GLOBAL** | **105** | **85** | **55,3 %** | **32** | |

**El pack que sale mal parado es `infra-cloud`, y hay que decirlo sin adornos: 40 % y 9 huecos de severidad alta.** No es mala redacción — los 18 procedimientos existentes son sólidos. Es un problema de **superficie**: el currículo cloud profesional (AZ-500 / SC-500 / SCS-C02 / PCSE / MCSB v2) cubre un área enorme y el pack cubre la mitad clásica (red abierta, bucket público, IAM con `*`, contenedor con root). Le faltan cuatro familias completas que un auditor cloud certificado da por obligatorias:

- **la escalada que no lleva comodín** (`iam:PassRole`, `iam.serviceAccounts.actAs`, `Microsoft.Authorization/roleAssignments/write`) — hoy `INF-01` declara limpia una política que sobre el papel es de mínimo privilegio y en la práctica es administrador;
- **el plano de datos PaaS publicado sin ruta privada** — `public_network_access_enabled`, `publicly_accessible`, `ipv4_enabled` con `0.0.0.0/0`, y sobre todo la **ausencia** de private endpoint, que ningún escáner detecta porque es un recurso que no está;
- **la clave, no el atributo de cifrado** — `INF-03` verifica `encrypted = true` y llega a degradar "sin CMK" a severidad baja; nadie mira la política KMS ni la rotación, así que ciframos con una clave que toda la cuenta puede usar, lo cual pasa todos los escáneres y protege exactamente de una amenaza: el robo físico del disco;
- **quién puede borrar el backup y el log** — sin esto el informe describe el acceso inicial y no dice nada del impacto; el mismo incidente con backups inmutables es una caída y sin ellos es una pérdida total.

Segundo veredicto incómodo: **`remediation`+`VER` con 50 % sobre muestra de 8 temas es estadísticamente ruido**, pero apunta a algo real que ninguna otra área midió — PNPT dedica ~29 % del tiempo de examen a redactar el informe y nuestro corpus dedica 14 de 122 procedimientos a verificación y remediación juntas. No es un hueco de conocimiento, es un hueco de **proporción**.

### 1.3 La fórmula lista para ser gate ejecutable

Tres gates, en orden de coste creciente. El primero tiene dientes hoy mismo.

**Gate A — CONSTRUIDO el 2026-08-22 como `scripts/gates/gate-corpus-identifiers.sh`**, con batería de 14 mutantes (`.selftest.sh`), y descubierto solo por `run-all.sh`. Estado hoy: 164 procedimientos, 0 duplicados, 0 saltos, 497 citas comprobadas en 13 familias, 0 violaciones.

Tres cosas salieron distintas del diseño de abajo, y las tres importan:

1. **El `grep` diseñado enumera los prefijos a mano y `LOC` no está en la lista.** El pack `local-app` tiene 15 procedimientos: el gate tal como se diseñó habría sido ciego a un pack entero. El construido reconoce cualquier prefijo `[A-Z]{2,5}`, así que un pack nuevo entra bajo vigilancia sin que nadie se acuerde de añadirlo.
2. **A3 no compara contra una lista de identificadores; comprueba el ESQUEMA que declara `traceability.md`** — rango, año y vocabulario de cada estándar acotado. `A11:2025`, `V23`, `CICD-SEC-14` y `MASVS-STORAGE-1-L2` fallan; y como el propio documento es la autoridad, cada límite se vuelve a leer de su fila en cada corrida. Si el corpus adopta una versión nueva del estándar, el gate devuelve 2 —no pude medir— en vez de seguir aplicando el esquema del año pasado en silencio.
3. **Un mutante encontró un defecto del gate antes de que llegara a `main`.** La expresión terminaba en `\b` detrás de `\*`, y como ni `*` ni el espacio son caracteres de palabra, **las citas con comodín — 23 de las 29 de WSTG — eran invisibles**. Un check que no alcanza nada también da verde.

Lo que Gate A sigue sin medir, dicho aquí y no en una nota al pie: si el identificador válido es el CORRECTO para el procedimiento que lo cita (`CWE-79` donde iba `CWE-89` es un defecto real y no lo ve), y las familias sin límite enumerable — CWE, CAPEC, ATT&CK, ATLAS y los números de MASTG — donde un check de formato aprobaría cualquier cosa con la forma correcta.

Es el gate que habría atrapado `WEB-23`×2 e `INF-19`×2 antes de escribir una línea. El diseño original queda abajo, sin editar, porque la diferencia entre lo diseñado y lo construido es el registro:

```bash
# scripts/gates/gate-ids.sh — falla el build, no avisa
set -euo pipefail
K=skills/ethical-hacker-squad/references/knowledge

# A1: ningún ID de procedimiento duplicado en todo el corpus
dup=$(grep -ho '^### \(WEB\|MOB\|INF\|SUP\|AI\|PRV\|REM\|VER\)-[0-9]\{2\}' $K/*.md \
      | sort | uniq -d)
[ -z "$dup" ] || { echo "FAIL: ID duplicado: $dup"; exit 1; }

# A2: sin huecos en la numeración de cada pack (un salto = un procedimiento perdido en un merge)
# A3: todo identificador citado en un campo Traceability debe existir en traceability.md
#     (atrapa MASWE-NNNN inventados, CAPEC candidatos, WSTG v5 que no existe en la release estable)
exit 0
```

**Gate B — no regresión de cobertura (coste: bajo, valor: el que pidió Cristian).**
Fuente de verdad: un TSV versionado, no prosa.

```
# references/curriculum-coverage.tsv
# pack  tema  estado(covered|gap)  severidad(alta|media|baja)  procedimiento|propuesta  fuente  fecha_verificacion
```

```bash
# scripts/gates/gate-curriculum.sh
# 1. FAIL si algún tema estado=gap severidad=alta NO tiene entrada en el backlog aceptado
# 2. FAIL si PCC(pack) < umbral_pack    (umbrales iniciales = cifra de hoy, trinquete +5 pts por release)
# 3. FAIL si PCC_global < 0.55          (la cifra de hoy: prohibido empeorar)
# 4. WARN  si un tema lleva >2 releases en estado=gap sin cambiar de severidad (deuda congelada)
# Exit codes distintos para "medí y está bien" (0) y "no pude medir el TSV" (2).
# Un rc=0 porque el TSV no existe es exactamente la mentira que este gate debe evitar.
```

**Gate C — descargo de falso positivo con evidencia (coste: medio, valor: corrige un defecto real del corpus).**
`INF-01`, `INF-02` e `INF-04` descartan hallazgos apoyándose en *"hay un guardarraíl más arriba"*, y **ningún procedimiento verifica que ese guardarraíl exista**. El corpus se apoya en una capa que nunca audita. El gate: un descargo que invoque un guardarraíl debe citar **la ruta del fichero** donde vive (`aws_organizations_policy`, `azurerm_policy_assignment`, `google_org_policy_policy`) o marcarse `unverified`. Esto es más barato y más efectivo que el procedimiento `INF-24` que proponía el área — por eso `INF-24` se corta (§3.4) y se sustituye por este gate.

---

## 2. Huecos deduplicados entre áreas

Coincidencia entre currículos independientes = señal, no ruido. Estos suben de prioridad por convergencia.

### 2.1 Convergencias fuertes (2+ áreas, elevados)

**C1 · "Cargar y ejecutar contenido elegido en tiempo de ejecución" — 3 de 5 áreas, 3 sustratos.**
`CWE-829` / `CWE-494` / `CWE-98`. Certs ofensivas lo ven como LFI/RFI y `require`/`import`/`Class.forName` dinámico (web). OWASP MAS lo ve como `DexClassLoader` y bundles OTA de CodePush/Expo (móvil). OWASP AI lo ve como `torch.load` / `trust_remote_code=True` sobre un checkpoint traído por tag (IA). **Tres roles distintos, misma columna vertebral, y el corpus no tiene ni uno.** Se resuelve con tres procedimientos (`WEB-28`, `MOB-18`, `AI-23`) que comparten redacción de `rules_it_out` — el artefacto vive dentro del paquete, se fija por digest, se verifica antes de cargar.

**C2 · Verificación de procedencia en el lado CONSUMIDOR — 2 áreas, elevado a máxima prioridad.**
OpenSSF: `SUP-22`, la firma que acepta a cualquier firmante (`--certificate-identity-regexp '.*'`), o que corre tras un `|| true`, o que verifica un tag y despliega ese mismo tag. Certs cloud: la misma ausencia vista desde admisión (Binary Authorization, Kyverno `verifyImages`, content trust). `SUP-12` distingue "hay firma" de "no hay firma" y **el fallo caro es el tercer estado: hay firma, hay comando de verificación, y la verificación no prueba nada**. Es el hallazgo de mayor valor de todo el ejercicio porque el proyecto ya cree que tiene el control.

**C3 · El efecto ocurre y no queda rastro — 2 áreas, mismo origen, dos capas.**
Certs cloud: `PRV-13`, el logging de **plano de datos** está apagado por defecto en los tres proveedores y se factura por evento, así que tras un incidente nadie puede responder *de quién* se accedieron los datos y hay que tratar a toda la población como afectada. OWASP AI: `AI-27`, una acción irreversible del agente (enviar, pagar, desplegar) no se puede reconstruir seis semanas después. **No es monitorización, es no repudio.** Se mantienen los dos procedimientos porque son dos superficies y dos roles, con referencia cruzada obligatoria a `INF-06` para que el hallazgo se escriba una vez por capa.

**C4 · El escuadrón razona bottom-up y nunca top-down — 2 áreas.**
Certs ofensivas: falta modelado de amenazas estructurado; `traceability.md` línea 88 ya lo confiesa — `A06:2025` → *leader, design review across packs, sin procedimiento*. Certs cloud: falta **composición de rutas de ataque** (encadenar hallazgos en un camino ingreso público → identidad → dato), que los currículos llaman *attack path analysis* y es literalmente la diferencia entre un listado de escáner y una auditoría profesional. Elevado de media a **alta por convergencia**. No va como procedimiento de 6 campos (no es un patrón vulnerable): va como capa de líder junto a `REM-07`.

**C5 · Punto de entrada sin autenticar que no está en el código de la aplicación — 3 áreas rozan lo mismo.**
`INF-21` (Lambda Function URL `authorization_type = NONE`, Cloud Run `allUsers`, Azure Functions `authLevel: anonymous`), `AI-24` (Qdrant/Chroma del `docker-compose` escuchando sin auth con la copia embebida de todo lo ingerido) y `AI-26` (endpoint de handoff que acepta cualquier llamante). El pack web no lo ve porque no está en el código; el pack infra no lo ve porque `INF-02` sólo conoce `allUsers` para buckets.

**C6 · Configuración de identidad auditable desde el repo — 2 áreas.**
Certs cloud: registro de aplicación pidiendo roles de aplicación de Graph tipo `Directory.ReadWrite.All`, redirect URIs con `http://` o comodín, `sign_in_audience` multi-inquilino. Certs ofensivas: SPN kerberoasteable con etype débil, delegación no restringida, AS-REP roasting. La mitad on-prem es host vivo (fuera de superficie primaria); la mitad Entra vía `azuread_*` en Terraform es estática y hoy no la mira nadie.

### 2.2 Solapes resueltos como referencia cruzada, no como procedimiento nuevo

| Tema | Áreas | Resolución |
|---|---|---|
| Vector store expuesto | IA (`AI-24`) ∩ cloud (`INF-20`) | `INF-20` = PaaS gestionado; `AI-24` = vector self-host **+ la pata de supresión** que `INF-20` no tiene (el índice es el almacén que el borrado siempre olvida) |
| Credenciales ambientales heredadas | IA (`AI-28`) ∩ cloud (`INF-05` ampliado) ∩ OpenSSF (`CICD-SEC-6`, cubierto) | `AI-28` conserva el ángulo distintivo: el agente hereda `~/.aws`, `~/.ssh`, `~/.kube` de quien lo lanzó, así que el radio de explosión no es el repo sino la máquina |
| Método "declarado vs observado" | IA (`AI-25` skills) ∩ OpenSSF (`SUP-23` binarios) | Mismo método, sustratos distintos; se mantienen ambos y se comparte la redacción del `minimal_test` (tabla de dos columnas, la fila que sólo aparece a la derecha es el hallazgo) |
| Metadatos de IMDS | cloud (media) ∩ `WEB-10` | Ampliación del *Where to look* de `WEB-10` con el lado IaC. Sin procedimiento. |
| SUID / world-writable en Dockerfile | certs ofensivas (`INF-27`) ∩ `INF-07`/`INF-09` | La mitad contenedor ya está; lo nuevo es Ansible/Chef/DSC/cloud-init y el *unquoted service path* de Windows |

### 2.3 Huecos de área única que igualmente son alta (el currículo autoritativo de su dominio manda)

PortSwigger es la fuente autoritativa de web y OWASP MAS la de móvil; que sólo ellas señalen algo no lo debilita.

- **XXE con entidad propia** (`WEB-23`) — `WEB-10` sólo atrapa XXE en su forma de SSRF: todo su patrón, su rule-out y su test miran tráfico saliente. Un agente que siga `WEB-10` **no** probaría lectura de `/etc/passwd` por entidad reflejada, ni exfiltración ciega por parameter entities, ni XInclude, ni XXE por subida de SVG/DOCX, ni el parser oculto que aparece al cambiar el `Content-Type` de un endpoint JSON.
- **Host header** (`WEB-24`) — `WEB-03` cubre el flujo de reset de contraseña pero no el vector: inyectar `X-Forwarded-Host` para que el enlace de reset apunte al dominio del atacante y fugue el token. Toma de cuenta completa.
- **Integridad de flujo OAuth/OIDC** (`WEB-25`) — `WEB-01` es la mecánica del JWT, no el flujo: `redirect_uri` validado por prefijo, `state` ausente o no verificado, `aud` no comprobado, linking de cuenta por email no verificado.
- **Prototype pollution** (`WEB-26`) — server-side escala a RCE vía `child_process`; muy greppable (`merge`, `mergeWith`, `$.extend(true`, `defaultsDeep`) y con tasa de detección SAST baja, que es justo el perfil que justifica un procedimiento humano.
- **Biometría no ligada a clave** (`MOB-16`) — el hallazgo canónico de banca móvil: `BiometricPrompt.authenticate(promptInfo)` sin `CryptoObject`, un booleano que sólo cambia el flujo. El pack lo menciona de pasada dentro de `MOB-03` como "alternativa correcta que puede faltar", sin patrón ni test.
- **Tapjacking / overlay** (`MOB-17`) — las palabras *overlay*, *obscured* y *AccessibilityService* **no aparecen ni una vez** en `mobile.md`. Es el mecanismo de entrega de casi todo troyano bancario Android reciente y la defensa es una propiedad estática (`filterTouchesWhenObscured`, `setHideOverlayWindows`). Hoy una app de pagos pasa la auditoría con cero controles anti-overlay en la pantalla de confirmar transferencia.
- **Control de flujo en la FUENTE** (`SUP-21`) — `SUP-10` pregunta quién puede *disparar* la publicación; nadie pregunta quién puede *escribir el commit que se publica*. Con una cuenta de mantenedor comprometida se empuja a `main`, se mueve el tag `v1.4.2` y el pipeline firma y publica con toda la ceremonia intacta: firma válida, procedencia válida, SBOM válido, código de otro. Todo el Source track de SLSA está citado como etiqueta en `SUP-10` y **no lo verifica ningún procedimiento**.
- **Supresiones de CVE y VEX aceptados sin re-derivar** (`SUP-25`) — estructural: todas las herramientas del §7 leen `.trivyignore` / `osv-scanner.toml` **para obedecerlos**, así que correr el escáner es lo único que jamás sacará esto a la luz. Una supresión que no re-derivaste es un hallazgo que borraste de tu propio informe fiándote de la palabra de otro.
- **Frontera de ejecución del agente** (`AI-28`) — nada detecta que el agente pueda escribir los ficheros que lo gobiernan (`CLAUDE.md`, `.mcp.json`, la memoria, su propio log). Una inyección deja de ser problema de sesión y se convierte en persistencia para todas las sesiones futuras, incluidas las de otros.

---

## 3. Backlog priorizado

**31 borradores llegaron. Se aceptan 27, se cortan 4.** Los cortes están justificados en §3.4 — ninguno se descarta por "no da tiempo", los cuatro se cierran por una vía más barata que un procedimiento.

Renumeración aplicada tras resolver las colisiones: `WEB-23..28` · `INF-19..27` · `SUP-21..25` · `AI-23..28` · `MOB-16..18` · `PRV-12..13`.

### 3.1 Tier 1 — escribir primero (12). Alta severidad, confirmable desde repo, o convergente entre áreas.

| # | ID | Título | Pack | Por qué primero |
|---|---|---|---|---|
| 1 | `SUP-22` | Signature verification that accepts any signer, or that gates nothing | supply-chain | C2. Control aparente = control nulo. El hallazgo más caro del ejercicio |
| 2 | `SUP-21` | Source-side flow control: unprotected branches, self-approval, movable tags | supply-chain | El mayor hueco individual detectado; vector real de chalk/debug (sept-2025) |
| 3 | `INF-19` | Privilege escalation paths in cloud IAM that need no wildcard | infra-cloud | Invalida el veredicto "limpio" de `INF-01` en el caso más común |
| 4 | `INF-20` | PaaS data services published on the internet with no private path | infra-cloud | El hallazgo más frecuente de una auditoría cloud real; hoy sale limpio |
| 5 | `WEB-23` | XML external entity processing (XXE) and unsafe XML parsing | web-api | Clase web de primer nivel sin procedimiento propio |
| 6 | `WEB-24` | HTTP Host header and absolute-URL trust | web-api | Toma de cuenta vía reset poisoning, cero cobertura |
| 7 | `WEB-25` | OAuth 2.0 and OpenID Connect flow integrity | web-api | De los hallazgos real-world más comunes; el escuadrón no lo busca |
| 8 | `AI-28` | Agent execution boundary: writable scope, self-modification, inherited credentials | ai-safety | Configuración, visible antes de cualquier ataque. **Dogfooding directo sobre este repo** |
| 9 | `AI-25` | Agent skills and plugins: declared capability versus what the package does | ai-safety | El repo auditado **es** un plugin de Claude Code. Máximo valor de dogfooding |
| 10 | `SUP-24` | Components and runtimes past their end of support | supply-chain | Convierte "sin vulnerabilidades conocidas" de *limpio* a **no medido** |
| 11 | `INF-23` | Backups, snapshots and audit trails the workload identity can delete | infra-cloud | Es la mitad de *impacto* que falta en todo informe cloud |
| 12 | `MOB-17` | Confirmation screens without overlay and accessibility defenses | mobile | Check estático, coste casi cero, vector dominante en banca móvil |

### 3.2 Tier 2 — siguiente ola (12)

| # | ID | Título | Pack |
|---|---|---|---|
| 13 | `SUP-25` | Suppressed CVEs and supplier "not affected" claims accepted without justification | supply-chain |
| 14 | `SUP-23` | Binary artifacts committed to the source tree and consumed by the build | supply-chain |
| 15 | `INF-22` | Keys and secret stores: policy, rotation and the key's blast radius | infra-cloud |
| 16 | `INF-21` | Serverless and PaaS entry points invocable with no authentication | infra-cloud |
| 17 | `WEB-26` | Prototype pollution (client and server side) | web-api |
| 18 | `WEB-28` | File inclusion and dynamic code/module loading | web-api |
| 19 | `AI-24` | Vector store deployment and the embedded copy of the data | ai-safety |
| 20 | `AI-27` | Agent actions are not attributable: no trace, no retention, no reconstruction | ai-safety |
| 21 | `AI-26` | Inter-agent handoff without provenance or authentication | ai-safety |
| 22 | `PRV-13` | Reading personal data leaves no trace | privacy-abuse |
| 23 | `MOB-16` | Biometric and local authentication not bound to a cryptographic key | mobile |
| 24 | `MOB-18` | Dynamic code loading and over-the-air bundle updates | mobile |

### 3.3 Tier 3 — condicionales (3). Se escriben, pero su rendimiento depende del objetivo; el pack debe decirlo.

| # | ID | Título | Condición de aplicabilidad |
|---|---|---|---|
| 25 | `AI-23` | Model, adapter and dataset artifacts loaded without provenance or safe deserialization | Sólo si el objetivo carga pesos propios. Cuando aplica, es RCE **antes del primer token** |
| 26 | `PRV-12` | Where the personal data physically lands, and where it is replicated | Necesita una declaración de jurisdicción contra la que contrastar. Es el **único control de privacidad escrito en el código** |
| 27 | `INF-27` | Local privilege-escalation conditions in images and provisioning code | Sólo si hay Ansible/Chef/DSC/cloud-init. La mitad contenedor ya está en `INF-07`/`INF-09` |

### 3.4 Lo que se cortó, y por qué (4)

1. **`INF-24` Guardarraíles organizacionales** → **sustituido por el Gate C de §1.3.** Su `vulnerable_pattern` es literalmente un comentario ("cuarenta módulos y ni una política") y su `minimal_test` es una pregunta metodológica. El defecto real que denuncia — que `INF-01`/`INF-02`/`INF-04` descartan hallazgos apoyándose en una capa que nadie audita — se cierra mejor con una **regla de descargo con evidencia** (cita la ruta del fichero o marca `unverified`) que con un procedimiento nuevo. Más barato y con dientes.
2. **`INF-25` Registro de aplicación / cliente OAuth** → **plegado en dos sitios.** La pata de `redirect_uri` es literalmente `WEB-25`. La pata de permisos excesivos de directorio (`Directory.ReadWrite.All` como `type = "Role"`) es literalmente `INF-19`, que ya responde "quién puede convertirse en qué". Un procedimiento entero para lo que son dos filas.
3. **`INF-26` Servicio de IA gestionado** → **plegado como fila "recursos de IA" en `INF-20` (red pública), `INF-21` (auth por clave vs identidad) e `INF-06` (diagnostic setting).** Sus cuatro preguntas sí/no ya son las preguntas de esos tres procedimientos aplicadas a `azurerm_cognitive_account` / Bedrock / Vertex. El área tenía razón en que hoy no lo ve nadie; la corrección barata es ampliar el *Where to look*, no crear un procedimiento.
4. **`WEB-27` HTTP request smuggling** → **diferido a una pregunta de intake, no descartado.** Es el tema más grande de PortSwigger (22 labs) y es alta severidad, así que el corte duele y lo digo claro. Razón: **su propio campo `tooling` admite que ningún grep a nivel de código confirma la clase** — es una propiedad emergente de la cadena de proxies — y todo `minimal_test` honesto exige un target de staging propio y una sonda diferencial no repetible. Nuestra superficie primaria es código y configuración. Se convierte en una **pregunta obligatoria del intake** ("¿cuántos saltos HTTP reparsean la petición y hay downgrade de HTTP/2 a HTTP/1.1 en el salto de back-end?") y en una entrada de `VER-07` ("lo que no se comprobó"). Si el encargo incluye staging con autorización escrita, se reactiva como procedimiento.

**Nota de disciplina:** 27 > 25 a propósito. Los tres de Tier 3 son condicionales y podrían no ejecutarse nunca en un encargo dado; el núcleo incondicional son **24**.

### 3.5 Correcciones de corpus con coste cero (no son procedimientos, son erratas)

- **Perfiles de prueba MAS.** `mobile.md` y `traceability.md` (línea 25) afirman *"MASVS 2.1.0 … no L1/L2/R levels"*. Es **correcto para MASVS e incompleto para el proyecto MAS**: los *testing profiles* MAS-L1 / MAS-L2 / MAS-R / MAS-P existen como concepto propio (`Document/0x03b-Testing-Profiles.md` del repo `owasp-mastg`) y definen el **modelo de adversario del encargo** — MAS-L1 asume SO confiable, MAS-L2 asume dispositivo rooteado/jailbroken con acceso físico de un tercero. Adoptarlos da al rol móvil lo que hoy no tiene: **declarar contra qué adversario auditó**. Edición de la §0 de `mobile.md` y de la matriz.
- **`WEB-10` y `SUP-02`.** Añadir una línea de frontera explícita en cada uno: `WEB-10` cubre XXE *sólo como SSRF* (ver `WEB-23`); `SUP-02` mide *distancia a la última versión*, no *estado de soporte* (ver `SUP-24`). Esto evita que el próximo lector repita el falso "cubierto" del §0.

---

## 4. Veredicto de licencias por plataforma

El repo es MIT y público. **Ninguna redacción de ninguna plataforma se copió ni debe copiarse.** Lo que se usó de cada fuente es su **estructura** (nombres de tema, códigos de examen, IDs) como hecho.

### 4.1 Verde — texto reutilizable en un repo MIT

| Fuente | Licencia (verificada) | Cómo se verificó | Qué se puede |
|---|---|---|---|
| **NICE / NIST SP 800-181r1 (v2.2.0)** | Obra del Gobierno de EE. UU., **dominio público**, atribución agradecida | Nota de copyright de NIST/CSRC | **Único caso donde se puede copiar VERBATIM** con su ID. Es el ancla de trazabilidad ideal |
| **NIST AI RMF, AI 600-1, AI 100-2e2025, SP 800-53/115/218** | Dominio público en EE. UU. | nist.gov/oism/copyrights | Todo, con crédito |
| **MITRE ATLAS (`atlas-data`)** | **Apache 2.0**, © 2021-2026 MITRE | Fichero `LICENSE` del repo leído íntegro | IDs, nombres **y descripciones**, con atribución + `NOTICE`. La fuente más reutilizable del área IA |
| **OpenSSF LFD121 (`ossf/secure-sw-dev-fundamentals`)** | **CC BY 4.0** | GitHub API `.license.spdx_id` + README | Redacción reutilizable con atribución. Ojo: imágenes citadas (xkcd) con licencia propia; el material de examen no está en el repo |
| **MicrosoftDocs públicos (`azure-docs`, `azure-ai-docs`)** | **CC BY 4.0** | `raw.githubusercontent.com/.../LICENSE` | Adaptar texto **con atribución a Microsoft, enlace y aviso de modificación**, marcado como CC BY dentro del repo MIT |
| **OpenSSF Scorecard** | **Apache 2.0** | GitHub API | Nombres de check reutilizables |
| **OpenSSF Best Practices Badge** | **(MIT OR CC-BY-3.0+)** | `SPDX-License-Identifier` del README | Reutilizable bajo MIT |
| **OWASP Secure Agent Playbook** | **CC BY 4.0** | `LICENSE.md` + badge | Todo con atribución (la más permisiva de OWASP) |
| **OWASP Agent Observability Standard** | **Apache 2.0** | badge + `LICENSE.txt` | Todo con atribución + `NOTICE` |
| **developer.android.com** | Docs y código **Apache 2.0**; resto del sitio **CC BY 2.5** | developer.android.com/license | Encabezados y estructura |

### 4.2 Ámbar — sólo IDs, nombres y estructura. Copiar prosa rompería el MIT.

| Fuente | Licencia | Riesgo | Qué se cita |
|---|---|---|---|
| **Todo OWASP CC BY-SA 4.0**: LLM Top 10, Agentic/ASI, AI Testing Guide, Agentic Skills, MASTG, MASVS, MASWE, Mobile Top 10, CI/CD Top 10 | **CC BY-SA 4.0** | **Copyleft fuerte**: copiar redacción forzaría el derivado a ShareAlike y rompería el MIT | `LLM01:2026`, `ASI01..10`, `AITG-APP-nn`, `AST01..10`, `MASTG-TEST-*`, `MASVS-*`, `M1..M10`, `CICD-SEC-n` + títulos |
| **docs.aws.amazon.com** (incl. Well-Architected Security Pillar) | **CC-BY-SA-4.0** (código MIT-0) | Igual: copyleft fuerte | Sólo hechos y nombres de servicio. **Nunca redacción** |
| **Reproducible Builds** | **CC BY-SA 4.0** | Igual | Nombres de tema |
| **SLSA v1.0/v1.1/v1.2** | **Community Specification License 1.0** (no es CC) | No reproducir texto normativo | `Build L0..L3`, `Source L1..L4`, IDs de amenaza |
| **S2C2F (`ossf/s2c2f`)** | **Community Specification License 1.0** (código de ejemplo MIT) | La API de GitHub dice `NOASSERTION`; **hubo que leer el `LICENSE.md`** | IDs de práctica (`SCA-3`, `AUD-4`, `ENF-1`, `UPD-1`). Títulos largos **parafraseados** |
| **CSA CCM** | Sin modificación ni traducción sin consentimiento de CSA | — | `PREFIX-NN` a nivel de control |
| **CIS Controls / Benchmarks** | **CC BY-NC-ND** / **CC BY-NC-SA** | El caso más estricto: NC + ND | `CIS v8.1 Control N` a nivel de control; criterios con palabras propias; benchmarks por existencia |
| **cloud.google.com (páginas)** | **CC BY 4.0** ("except as otherwise noted"), código Apache 2.0 | El aviso dice *"of this page"* | Nombres y estructura |

### 4.3 Rojo — propietario. Sólo códigos, nombres de dominio y pesos porcentuales, como hechos.

| Fuente | Licencia verificada | Citable | **Prohibido** |
|---|---|---|---|
| **Microsoft Learn — study guides de certificación** (SC-200, AZ-500, SC-500, SC-100) | Repo **privado** `MicrosoftDocs/learn-certs-pr`, sin licencia abierta. Learn ToU verificados: *personal and non-commercial use*, sin obras derivadas | Códigos de examen, nombres de dominio y sus pesos, fechas "skills measured as of", el retiro de AZ-500 el 2026-08-31, URLs | Copiar los bullets de objetivos; publicar el temario; cualquier uso comercial del texto |
| **Microsoft Cloud Security Benchmark v2** | **NO confirmada.** `original_content_git_url` → repo privado `security-benchmark-docs-pr` | IDs de dominio y control (`NS`, `IM`, `PA`, `DP`, `LT`, `AI`; `NS-1`, `DP-1`…) y la lista de campos de cada control | Descripciones de dominio y texto de control |
| **AWS SCS-C02 Exam Guide (PDF `d1.awsstatic.com`)** | **Propietaria.** AWS Site Terms: no reproducir, duplicar ni explotar comercialmente. El PDF **no** está en `docs.aws.amazon.com`, así que no le aplica la excepción abierta | `SCS-C02`, los 6 dominios con pesos, numeración `1.1..6.4`, nombres de servicio | Bullets "Knowledge of" / "Skills in"; el apéndice de servicios in/out of scope |
| **Google Cloud PCSE Exam Guide (PDF `services.google.com`)** | El aviso CC BY es *"of this page"* y **el PDF no lo lleva** → cae en "except as otherwise noted". **No asumir CC BY** | Nombres de sección con pesos (~25 %, ~22 %, ~23 %, ~19 %, ~11 %), numeración `1.1..5.1` | Bullets "Considerations include"; marcas y logos |
| **OffSec PEN-200 / PWK v3.0** | `Copyright ©2023 OffSec Ltd. All rights reserved` (PDF) | El código del curso, el hecho de los 24 módulos | Títulos de módulo como compilación; cualquier contenido |
| **CompTIA PenTest+ PT0-003** | `Copyright © 2026 CompTIA, Inc. All rights reserved` | `PT0-003`, nombres de dominio y pesos (21 %, 17 %, 35 %, 14 %, 13 %) | Sub-objetivos y su redacción |
| **INE eCPPT** | `© 2026 INE. All Rights Reserved` | Nombre y pesos de dominio (15 %, 10 %, 5 %…) | Contenido |
| **TCM PNPT** | `Copyright TCM Security, INC © 2025` | Nombre, estructura, el ~29 % de tiempo de informe | Contenido |
| **PortSwigger Web Security Academy** | **Todos los derechos reservados** (gratis de leer, no de redistribuir) | Nombres de tema y de lab, el recuento de labs | Cualquier redacción, incluido el texto de un lab |
| **DeepLearning.AI "Red Teaming LLM Applications"** | De pago, todos los derechos reservados | Su existencia y el número de lecciones | Todo lo demás |
| **Páginas de curso LF Training** (LFD125, LFS182, LFEL1001/1005/1006/1007/1012) | **Sin declaración → todos los derechos reservados** por defecto | Códigos de curso y nombres de módulo, como hechos | Redacción |

### 4.4 Descartado íntegramente por licencia

1. **OWASP MCP Top 10 — `CC BY-NC-SA 4.0`.** La cláusula **NC (no comercial)** más ShareAlike la hace **incompatible con un repo MIT de uso libre**, que por definición permite uso comercial. **Se cita `MCP01..MCP10` como identificador y enlace, y no se deriva NADA de su texto.** Ojo: el corpus ya cita `MCP01`, `MCP03`, `MCP04`, `MCP05`, `MCP07`, `MCP08`, `MCP09` en `ai-safety.md` — citar el ID está bien, pero conviene una revisión explícita de que ninguna redacción se parezca a la suya.
2. **OWASP AI Exchange — licencia NO DECLARADA y repo no localizado.** No se deriva nada de una fuente cuya licencia se desconoce. Se conserva sólo el nombre de sus 8 secciones como hecho.
3. **Material de evaluación de LFD121** — deliberadamente excluido del repo por OpenSSF; no se buscó por otras vías.
4. **Cualquier bullet de objetivo de examen de las 6 plataformas comerciales del §4.3.** Se usó su *estructura* (dominio + peso) para construir el denominador de la métrica, que es un hecho no protegible.

### 4.5 Cómo se atribuye

Mecanismo, no buena intención:
- `NOTICE.md` en la raíz (ya existe) lista: MITRE (ATT&CK/CWE/CAPEC/ATLAS, Apache 2.0 + aviso), NIST (dominio público, crédito), OpenSSF LFD121 y Scorecard, Microsoft Learn product docs (CC BY 4.0, enlace + "modificado").
- **Regla operativa, cableable como gate:** todo identificador procedente de una fuente **CC BY-SA o NC** puede aparecer **únicamente en el campo `Traceability`** de un procedimiento, nunca en `Vulnerable pattern` ni en `What rules it out`. Esos dos campos son redacción propia por construcción. Es exactamente la regla que ya aplica `traceability.md` §2 — sólo hay que hacerla comprobable.

---

## 5. Lo que NO se pudo verificar

Sin maquillar. Un temario alucinado es peor que ninguno.

### 5.1 Lo más grave: falta el mapa de fuentes del área web

**No existe `mapa-portswigger.md` (ni equivalente) en el scratchpad.** Los ficheros en disco son `mapa-certs`, `mapa-microsoft`, `mapa-openssf` y `mapa-ia-movil`. El área web entregó su análisis de cobertura, pero **su verificación de licencia y su lista de "no verificado" no están en disco y no se pudieron auditar en esta sesión**. La licencia de PortSwigger del §4.3 procede del enunciado del encargo, no de una verificación mía en esta sesión. Sus 5 propuestas (`WEB-23..27`) son técnicamente sólidas y coherentes con el corpus, pero **su trazabilidad de fuente es la más débil de las cinco áreas**. Corregirlo antes de escribir `WEB-23`.

### 5.2 IDs citados en los borradores que NO están verificados

Esto contamina campos `Traceability` de procedimientos que están en Tier 1 y Tier 2:

- **`MASWE-NNNN` de los grupos AUTH, PLATFORM y CODE** — los borradores `MOB-16`, `MOB-17` y `MOB-18` lo declaran ellos mismos: *"se derivaron por orden del temario, NO se leyeron uno a uno"*. **No fijar un número concreto.** Citar el grupo (`MASWE AUTH group`) hasta comprobarlo. `traceability.md` línea 115 ya establece esta política para `MASTG-TEST-NNNN`; se extiende a MASWE.
- **`CAPEC-193` y los `WSTG-INPV-11/12` de `WEB-28`** — el propio borrador los marca *"draft candidates; verify against the source"*.
- **`LLM01:2026`..`LLM10:2026`** — **conflicto entre fuentes.** `traceability.md` (línea 29 y 50) los declara verificados el 2026-08-04, incluyendo que `LLM03` es Excessive Agency y `LLM08` Hidden Context Exposure. Pero `mapa-ia-movil.md` (línea 64) dice que **la edición 2026 existe y su listado de riesgos NO se verificó** en el mapeo. Los seis borradores `AI-23..28` citan esos IDs. **Son una aserción heredada del corpus, no una verificación independiente de este ejercicio.** No es necesariamente un error — es que no se re-comprobó.
- **OWASP Agentic Top 10 for 2026 (PDF)** — no verificado (`mapa-ia-movil.md` línea 97). Los `ASI0n` citados vienen del repo, no del PDF.
- **Títulos textuales de los controles `MASVS-*-n`** — la web renderiza sólo los IDs.

### 5.3 Temarios que no se abrieron (declarados, no reconstruidos)

- **PT0-003:** los sub-objetivos numerados (1.1, 1.2, 2.1…). Los dos PDFs candidatos devolvieron **HTTP 404** y la ruta del sitio también. CompTIA entrega el PDF tras formulario. **No se reconstruyeron de memoria.**
- **AWS Security Fundamentals:** el temario por módulos vive tras el login de Skill Builder.
- **AWS Well-Architected Security Pillar:** las preguntas numeradas `SEC 1..n` no se extrajeron; sólo se confirmaron las 7 áreas de buenas prácticas.
- **edX LFD104x / LFD105x / LFD106x:** la URL intentada dio **404** con el presupuesto de WebSearch ya agotado. Códigos y títulos sí verificados desde `openssf.org/training/courses/`.
- **LFC108, LFS180, LFS183, SKF100:** título, código y URL verificados; temario **no abierto**.
- **Contenido interno de los cursos LFEL/LFS/LFD125:** sólo índice público de módulos; sin matrícula no hay más.
- **Criterios del Badge en niveles *silver* y *gold*:** sólo se abrió `/criteria/0` (*passing*).
- **NIST AI RMF:** la función **GOVERN** completa no se abrió; **MEASURE** quedó truncada tras 2.11 (2.2, 2.6, 2.7, 2.8, 2.9, 2.12 sin verificar).
- **GenAI Red Teaming Guide:** índice de capítulos no verificado.
- **Google Cloud Security Foundations / Skills Boost:** no abiertos (presupuesto).
- **Apple Platform Security:** ninguna ruta oficial de Apple se abrió → el lado iOS del análisis móvil es más delgado que el Android.
- **eJPT:** no consultado (presupuesto priorizado a eCPPT, nivel practitioner).

### 5.4 Hechos que son inferencias, marcadas como tales

- **Que SC-500 reemplace oficialmente a AZ-500:** ninguna de las dos páginas lo declara. Es una inferencia sólida (retiro 2026-08-31 + cert nueva del mismo rol + temario solapado), **no un hecho publicado**.
- **Vigencia de PWK v3.0:** el PDF servido se identifica como v3.0 ©2023 mientras el sitio comercializa OSCP+. No se verificó si hay syllabus más reciente.
- **Existencia de SCS-C03:** sólo se verificó "Version 1.0 SCS-C02".
- **Fecha/versión del exam guide de Google PCSE:** el PDF no la incluye.
- **Cambios de SLSA v1.2 en el Build track:** `/spec/v1.2/levels` devolvió **404**. Si v1.2 renombró o añadió niveles de Build, **no lo sabemos**. El track "Build Environment" aparece en discusiones pero **no se vio definido**; no se afirma que exista.
- **Niveles de responsabilidad NICE** (Entry/Intermediate/Advanced): referenciados por NIST pero no extraídos. Los niveles usados en los entregables son **clasificación propia**, no una afirmación sobre lo que publica la plataforma.
- **TKS de 7 de las 11 Competency Areas de NICE** (Access Controls, Asset Management, Cloud Security, Communications Security, OS Security, OT Security, Supply Chain Security): declaradas con nombre y descripción en v2.2.0, **sin K/S poblados en el JSON**. No se infirió su contenido.
- **Licencia de `learn-certs-pr` y `security-benchmark-docs-pr`:** repos privados, sin `LICENSE` accesible. **Tratados como propietarios** (postura conservadora deliberada).
- **Licencia del contenido interno de los cursos LFEL/LFS:** ninguna página la declara. Asumido "todos los derechos reservados"; **no confirmado** con LF Training.

### 5.5 Sobre la propia métrica

- Los recuentos de "cubierto" son **autoevaluación de cada área**, y §0 documenta un falso positivo demostrado (EOL). **55,3 % es cota superior.**
- La unidad "tema" no es homogénea entre currículos: PortSwigger enumera por clase explotable (granularidad fina), los exam guides cloud por objetivo (granularidad gruesa). Esto **infla artificialmente el denominador de `web-api` y deprime el de `infra-cloud`** — es decir, el 40 % de infra es probablemente aún **peor** de lo que parece, porque un objetivo de AZ-500 encierra más superficie que un lab de PortSwigger.
- `remediation`+`VER` con n=8 no es una medición, es una anécdota. Marcarlo así en el TSV.

---

## 6. Recomendación honesta: ¿qué aporta el currículo profesional que los estándares no aportaban?

Cristian pidió criterio, no adulación. Empiezo por lo que **no** funcionó.

### 6.1 El área que no aportó casi nada: certificaciones ofensivas + NICE

**Rendimiento: 2 procedimientos de 27, y uno de los dos es condicional (`INF-27`).** Todo lo demás fue (a) ya cubierto, (b) weaponización que ya habíamos declarado fuera de alcance, o (c) competencias blandas.

La razón es estructural y conviene entenderla antes de repetir el ejercicio: **OSCP, PenTest+, eCPPT y PNPT están organizados alrededor de lo que un atacante hace sobre un host vivo**, y este escuadrón audita repositorios. Su núcleo — post-explotación, movimiento lateral, evasión de AV/EDR, desarrollo de exploits, cracking de hashes, phishing — no es que sea difícil de incorporar: es que **incorporarlo sería traicionar el contrato del producto**. El único hallazgo técnico de verdad, file inclusion (`WEB-28`), es una clase estática que se les escapó a los otros cuatro mapeos.

**Y NICE específicamente no aportó ni un procedimiento.** Es una taxonomía de fuerza laboral, no un cuerpo técnico: sus *task statements* describen roles, no fallos. Su valor real es otro y hay que nombrarlo con precisión: **NICE es la única fuente de todo este ejercicio cuyo texto es de dominio público y se puede copiar verbatim al repo MIT.** Eso la convierte en el **ancla de trazabilidad y el vocabulario del informe** ideales — "Perform authorized penetration testing on enterprise network assets", con su ID y atribución a NIST, es una frase que podemos poner literalmente en el `README` para describir qué hace el escuadrón. Usarla como fuente de procedimientos fue el uso equivocado; usarla como capa de citabilidad es el correcto.

Si alguien propone mapear más certificaciones ofensivas, **el rendimiento esperado es bajo y hay que decírselo antes, no después.**

### 6.2 Lo que sí aportó, y por qué los estándares estructuralmente no podían

El corpus ya estaba construido sobre estándares — por eso mapea limpiamente a CWE, OWASP, ASVS, WSTG. Un estándar te da **la taxonomía de lo que puede salir mal**. Un currículo profesional te da **el mapa de lo que se espera que un profesional sepa HACER**, y eso destapa tres cosas que una taxonomía no puede expresar:

**(1) Clases que la taxonomía colapsa en una sola fila.** `A05:2025 Security Misconfiguration` es *una* fila. PortSwigger dedica cuatro bloques de labs separados a XXE, Host header, cache poisoning y request smuggling — y cada uno necesita su propio procedimiento porque cada uno tiene un *where to look* distinto y, sobre todo, un *rule-out* distinto. La taxonomía te dice que existe la categoría; el currículo te dice cuántos procedimientos hacen falta para cubrirla. **Ésta fue la mayor fuente de valor y viene de PortSwigger y de OWASP MAS: los dos currículos organizados por clase explotable.**

**(2) La mitad *verificación* de cada control.** Un estándar dice "firma tus artefactos" y el corpus lo cumplió con `SUP-12`. Un currículo enseña a comprobar **cómo verifica el consumidor**, y ahí viven los hallazgos caros: `SUP-22` (hay firma, hay `cosign verify`, y acepta a cualquier firmante tras un `|| true`), `SUP-25` (hay triaje, y cada línea de `.trivyignore` es un CVE que desapareció del informe fiándonos de la palabra de otro), el Gate C (descartamos hallazgos invocando un guardarraíl que nunca auditamos). **Un checklist de estándar no puede expresar "el control existe y no hace nada", y ése es exactamente el hallazgo que distingue una auditoría profesional de un escaneo.** Éste es el aporte más sofisticado del ejercicio y viene de OpenSSF/SLSA/S2C2F.

**(3) Proporción.** PNPT dedica ~29 % del examen a redactar el informe. Nuestro corpus dedica 14 de 122 procedimientos a verificación y remediación juntas. Un estándar nunca te dice cuánto pesa cada cosa; un currículo profesional sí, porque tiene que repartir horas. Esa señal — sobre dónde aterriza de verdad el valor de un encargo — no la teníamos.

Añado una cuarta, no prevista: **el ejercicio se auditó a sí mismo.** `AI-25` (skills y plugins: capacidad declarada vs. lo que hace el paquete) y `AI-28` (frontera de ejecución del agente) aplican directamente a **este repo, que es un plugin de Claude Code**. Un escuadrón que nunca audita su propio directorio de skills no ha aplicado `AI-22`. Ése es el mejor argumento para escribirlos primero.

### 6.3 Veredicto por área, sin adornos

| Área | Rendimiento | Veredicto |
|---|---|---|
| **PortSwigger (web)** | 5 propuestas, 5 altas | **El mejor rendimiento por unidad de esfuerzo.** Organizado por clase explotable con lab, que es la granularidad exacta de un procedimiento. Único pero: su mapa de fuentes no está en disco (§5.1) |
| **OWASP AI + MAS (móvil)** | 9 propuestas, 6+3 altas | **Mayor rendimiento absoluto.** Destapó que el pack IA estaba construido contra la capa *prompt* y ciego a la capa *artefacto y runtime*. La mitad móvil dio 3 huecos MASVS-nativos que un auditor formado en web nunca comprueba |
| **OpenSSF / SLSA / S2C2F** | 5 propuestas, 5 altas | **El más sofisticado.** Único que atacó el lado consumidor de controles que ya emitíamos. `SUP-22` y `SUP-25` son los dos mejores hallazgos del ejercicio |
| **Certs cloud MS/AWS/GCP** | 10 propuestas → 6 tras cortes | **Valor real, pero vino del reencuadre, no de la fuente.** Los objetivos de examen son genéricos ("secure networking") y por sí solos no habrían producido nada; lo que produjo 9 altas fue leerlos como inventario de competencias y preguntar qué falta. Diagnosticó el peor pack |
| **Certs ofensivas + NICE** | 2 propuestas, 1 alta + 1 condicional | **Bajo rendimiento técnico, y hay que decirlo.** Su núcleo está fuera de alcance por contrato. NICE aporta cero procedimientos y un activo distinto: vocabulario de dominio público citable |

### 6.4 La recomendación operativa

1. **Escribir Tier 1 (12 procedimientos)** empezando por `AI-25` y `AI-28`, que se auditan sobre este mismo repo y dan evidencia de dogfooding.
2. **Cablear el Gate A (unicidad de ID) antes de escribir nada.** Acabamos de encontrar dos colisiones entre áreas paralelas; el gate cuesta 20 líneas de bash.
3. **Aplicar las correcciones de §3.5** (perfiles MAS, fronteras de `WEB-10` y `SUP-02`): coste cero, corrigen afirmaciones incorrectas ya publicadas.
4. **Resolver §5.1 y §5.2 antes de fijar campos `Traceability`.** Ningún `MASWE-NNNN` concreto entra al corpus sin leerlo en la fuente.
5. **No repetir este ejercicio con más certificaciones de rol.** El filón restante son las fuentes organizadas por *clase explotable* (forma PortSwigger) o por *verificación* (forma OpenSSF). Las organizadas por *puesto de trabajo* ya dieron lo que tenían.

Dato final para calibrar expectativas: **alrededor del 60 % del contenido curricular mapeado se descartó correctamente como ruido** (weaponización, GRC, teoría introductoria, operativa de SOC, productos de postura, modelos de madurez como puntuación). Eso no es un fallo del método — es el método funcionando. Pero significa que el rendimiento futuro de "mapear otro currículo" es bajo, y presentarlo como una veta abundante sería venderte humo.
