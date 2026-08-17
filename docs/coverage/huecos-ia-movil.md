# Análisis de cobertura — área IA/agentes y móvil

**Analista de huecos.** Contrasta el temario profesional ya mapeado (OWASP GenAI/ASI/AITG/MCP/AST10/MAS, MITRE ATLAS, NIST AI RMF + AI 600-1, Microsoft Learn AI Red Teaming Agent, developer.android.com) contra el corpus real del escuadrón:

- `/Users/cristianajavi/ethical-hacker-squad/skills/ethical-hacker-squad/references/knowledge/ai-safety.md` — `AI-01`..`AI-22`, 543 líneas
- `/Users/cristianajavi/ethical-hacker-squad/skills/ethical-hacker-squad/references/knowledge/mobile.md` — `MOB-01`..`MOB-15`, 347 líneas
- `/Users/cristianajavi/ethical-hacker-squad/skills/ethical-hacker-squad/references/traceability.md`
- Packs adyacentes leídos solo para no duplicar: `privacy-abuse.md` §5, `supply-chain.md` §6 y §9, `remediation.md` `VER-04`, `infra-cloud.md` (índice)

**Modo solo lectura.** No se escribió nada dentro del repo. Este archivo es el único entregable.

---

## 0. Criterio de "cubierto"

Cubierto = un agente que carga ese procedimiento y sigue sus seis campos **encuentra ese fallo concreto**. No cuenta que el símbolo aparezca de pasada en un campo "Where to look" de otro procedimiento con otro propósito.

Dos ejemplos de por qué importa, ambos reales en este corpus:

- `AI-15` lista `pickle.loads(` en "Where to look", pero su patrón vulnerable es *salida del modelo → sink ejecutable*. Un agente siguiendo `AI-15` busca dónde el texto generado llega a `exec`. **No** inventaría los checkpoints `.pt`/`.ckpt` que la aplicación carga al arrancar. `torch.load` sobre un artefacto de un hub sin pinning no lo encuentra nadie hoy.
- `MOB-03` menciona `setUserAuthenticationRequired` como "alternativa correcta que puede faltar" dentro del procedimiento de almacenamiento. Eso no es un procedimiento de autenticación biométrica: no hay patrón, no hay lista de falsos positivos, no hay test. El hallazgo canónico de banca móvil —el resultado biométrico es un booleano y no desbloquea ninguna clave— hoy se escapa.

Ambos aparecen abajo como huecos, no como cobertura parcial.

---

## 1. Cobertura confirmada (no hace falta procedimiento nuevo)

### IA

| Tema del temario | Procedimiento que lo cubre |
|---|---|
| LLM01 Prompt Injection directa e indirecta (AITG-APP-01/02, AML.T0051.000/.001) | `AI-02`, `AI-03`, `AI-04` |
| LLM02 Sensitive Information Disclosure / AITG-APP-03 | `AI-17`, `AI-18` + `PRV-07` |
| LLM03:2026 Excessive Agency / ASI02 Tool Misuse / AITG-INF-04 Capability Misuse | `AI-05`, `AI-06`, `AI-07` |
| ASI09 Human-Agent Trust Exploitation, taxonomía prohibited/high-risk/irreversible (MS Learn), AML.M0029 | `AI-07` |
| MCP03 Tool Poisoning, rug pull, shadowing entre servidores | `AI-08` |
| MCP04 Supply chain de servidores MCP / AML.T0010.005 | `AI-09` |
| MCP01 tokens y secretos / MCP07 authn-authz / AML.T0083 parcial | `AI-10`, `AI-11` |
| LLM05 Data & Model Poisoning en RAG (PoisonedRAG) / ASI06 / AITG-APP-08 parcial | `AI-12` |
| AML.T0080 Context Poisoning (.000 Memory, .001 Thread), MINJA, SpAIware | `AI-13` |
| LLM09 Vector & Embedding Weaknesses — aislamiento por consulta | `AI-14` |
| LLM10 Improper Output Handling / ASI05 RCE / MCP05 Command Injection / AITG-APP-05 | `AI-15` |
| AML.T0086 Exfiltración vía invocación de herramienta / AITG-DAT-02 runtime exfiltration | `AI-16` + `AI-01` |
| LLM08 Hidden Context Exposure / AITG-APP-07 Prompt Disclosure / AML.T0056 | `AI-17` |
| AITG-APP-04 Input Leakage, cross-tenant en caché semántica | `AI-18` |
| LLM06 Unbounded Consumption / AITG-INF-02 / AML.T0034.002 / ASI08 parcial | `AI-19` |
| AML.T0068 Prompt Obfuscation, ASCII smuggling, Rules File Backdoor | `AI-20` |
| Estrategias PyRIT como transformaciones de payload; ASR como métrica; límites del juez generativo | `AI-21` + `VER-04` |
| ASI04 supply chain agéntica — capa MCP | `AI-08`, `AI-09`, `AI-11` |
| AITG-DAT-05 minimización y consentimiento; AITG-DAT-01 exposición de datos de entrenamiento | `PRV-03`, `PRV-06`, `PRV-07` |
| AML.T0060 Publish Hallucinated Entities (lado consumidor: dependencias alucinadas) | `SUP-08` |
| NIST AI RMF MEASURE 2.7 (seguridad y resiliencia medidas y documentadas) | el pack entero es la instrumentación de esa subcategoría |
| El propio escuadrón como agente que ingiere contenido no confiable | `AI-22` |

### Móvil

| Tema del temario | Procedimiento que lo cubre |
|---|---|
| MASWE PLATFORM — componentes exportados, intents, providers (M8) | `MOB-01`, `MOB-08` |
| MASWE CODE — debuggable, backup, restos de desarrollo (M8) | `MOB-02` |
| MASWE STORAGE 0001-0006 (M9 Insecure Data Storage) | `MOB-03`, `MOB-12` |
| MASWE PLATFORM portapapeles/capturas + logs y SDKs de terceros (M6) | `MOB-04` + `PRV-06` |
| MASWE PLATFORM WebViews (3 debilidades) y bridges nativos; MASTG-BEST 0058/0061/0062 | `MOB-05`, `MOB-06` |
| MASWE PLATFORM deep links; App Links / Universal Links; MASTG-TECH-0172/0174/0175 | `MOB-07` |
| MASWE NETWORK 0026 tráfico sin cifrar; ATS y network_security_config (M5) | `MOB-09` |
| MASWE NETWORK 0027/0028 validación de certificado y pinning; MASTG-TECH-0012/0064 | `MOB-10` |
| MASWE CRYPTO 0007-0017 (M10) | `MOB-11` |
| M1 Improper Credential Usage / secretos embebidos; API key management (Android §10) | `MOB-12` |
| M3 authz del lado servidor, controles solo en cliente; MASVS-RESILIENCE como no-control | `MOB-13` |
| MASWE PLATFORM extensiones/entitlements iOS, ATS, esquemas URL | `MOB-14` |
| MASWE STORAGE iOS: Keychain, UserDefaults, pasteboard; MASTG-TECH-0061/0134 | `MOB-15` |
| M2 Inadequate Supply Chain Security (dependencias, publicación) | `supply-chain.md` completo — ver hueco #12 sobre el matiz Gradle/CocoaPods |

---

## 2. Huecos

Ordenados por severidad. "Qué deja de encontrar hoy" es literal: es el hallazgo que el escuadrón no produce.

### Severidad alta — con borrador de procedimiento (§3)

1. **Carga de artefactos de modelo, adaptadores y datasets sin procedencia ni deserialización segura** (LLM04:2026, LLM05:2026, AITG-INF-01, AITG-INF-05, AITG-MOD-03, AML.T0010.003, AML.T0011.000, AML.T0018.000).
   Hoy: `torch.load` / `joblib.load` / `keras.load_model` / `trust_remote_code=True` sobre un artefacto traído de un hub por tag y no por commit no genera hallazgo. Un checkpoint es contenido ejecutable y se ejecuta *antes* de generar el primer token. Wiz mide 90% de organizaciones con modelos self-hosted y 68% ingiriéndolos vía software de terceros: es la puerta más ancha que el pack no mira. → `AI-23`

2. **Despliegue del vector store y la copia embebida de los datos** (LLM09:2026, AITG-APP-08, AITG-MOD-05 parcial).
   Hoy: `AI-14` verifica que la *consulta* lleve filtro de tenant. Nadie mira si el propio Qdrant/Chroma/Weaviate del `docker-compose` escucha sin autenticación con la copia embebida de todo lo ingerido, ni si el vector sobrevive al borrado del registro origen (el índice es el almacén que los procesos de supresión olvidan siempre). → `AI-24`

3. **Skills y plugins de agente: capacidad declarada frente a lo que el paquete hace** (AST01, AST03, AST05, AST06, AST07, AST10; AML.T0010.005, AML.T0011.002).
   Hoy: `AI-04` trata `skills/*/SKILL.md` como *archivo de instrucciones* (autoría, revisión, barrido Unicode). No inventaría los ejecutables que viajan al lado del manifiesto, ni compararía `allowed-tools` declarados contra lo que hacen esos scripts, ni detectaría instalación desde marketplace sin revisión fijada. El propio repo auditado es un plugin de Claude Code: es el hueco con más valor de dogfooding. → `AI-25`

4. **Handoff entre agentes sin procedencia ni autenticación** (ASI07, ASI08, ASI10; AML.T0061, AML.T0080).
   Hoy: `AI-01` menciona "la salida de otros agentes" como ingesta no confiable en una frase, y ahí muere. No hay procedimiento para sistemas multi-agente: el taint cruza el borde en silencio hacia un agente que suele tener herramientas *distintas y peores*, y el endpoint de handoff acepta cualquier llamante. Con estos dos huecos basta para el caso auto-replicante. → `AI-26`

5. **Acciones del agente no atribuibles: sin traza, sin retención, sin reconstrucción** (MCP08, AML.M0024, AOS "traceable/inspectable", candidato ASI 0.5 "Repudiation & Untraceability", NIST MANAGE 4.3, A09:2025).
   Hoy: `INF-06` cubre logging de plataforma y `WEB-22` la fuga *por* logs. Nadie comprueba que una acción irreversible ejecutada por el agente pueda reconstruirse seis semanas después: qué entrada la provocó, qué documento se recuperó, qué versión del modelo decidió, por cuenta de quién. Es un hueco de no repudio, no de monitorización. → `AI-27`

6. **Frontera de ejecución del agente: alcance de escritura, auto-modificación y credenciales heredadas** (ASI03, ASI06, ASI10; AML.T0081, AML.T0083, AML.T0112.000; AML.M0026, AML.M0031).
   Hoy: nada impide detectar que el agente puede escribir los ficheros que lo gobiernan (`CLAUDE.md`, `.mcp.json`, la memoria, el propio log) — una inyección deja de ser un problema de sesión y se vuelve persistencia — ni que hereda las credenciales ambientales de quien lo lanzó (`~/.aws`, `~/.ssh`, `~/.kube`, sesión de `gh`). El radio de explosión no es el repositorio, es todo lo que alcanza la máquina. Es configuración: se ve antes de cualquier ataque. → `AI-28`

7. **Autenticación biométrica y local no ligada a una clave criptográfica** (MASVS-AUTH, grupo MASWE AUTH, MASTG-TEST-0326..0330, MASTG-BEST-0031/0036/0037/0038).
   Hoy: el resultado de `BiometricPrompt` como booleano que solo cambia el flujo, sin `CryptoObject` ni clave de Keystore con `setUserAuthenticationRequired`, no genera hallazgo. Es *el* hallazgo canónico de una app financiera y el pack no lo tiene. Añade el fallo por invalidación ante cambio de enrolamiento y la aceptación de `BIOMETRIC_WEAK` para acciones de valor. → `MOB-16`

8. **Pantallas de confirmación sin defensa frente a overlay ni a servicios de accesibilidad** (MASVS-PLATFORM, grupo MASWE PLATFORM, MASTG-BEST-0040).
   Hoy: `MOB-04` cubre capturas y portapapeles; overlay y accesibilidad no aparecen ni una vez en el pack. Es el mecanismo de entrega de prácticamente todo troyano bancario Android de los últimos años, y la defensa es una línea que la pantalla tiene o no tiene. → `MOB-17`

9. **Carga dinámica de código y actualizaciones OTA de bundle** (MASVS-CODE, grupo MASWE CODE, MASTG-TECH sobre carga dinámica).
   Hoy: `DexClassLoader`, `System.load`, CodePush/Expo Updates, Capacitor live updates no aparecen en el pack. Es ejecución de código que nunca pasó por la tienda ni por la revisión, con la identidad y los permisos completos de la app — y además invalida la conclusión del análisis estático del APK ("lo que se distribuye no es lo que se ejecuta"). → `MOB-18`

### Severidad media — sin procedimiento nuevo; ampliación o handoff

10. **Extracción de modelo, inferencia de pertenencia e inversión** (AITG-APP-09, AITG-MOD-04, AITG-MOD-05, AML.T0024.000/.001/.002).
    Solo aplica si el cliente *sirve* su propio modelo. Comprobación barata y estática: ¿el endpoint de inferencia expone logprobs, embeddings o vectores de confianza completos sin autenticación ni cuota? Ampliar `AI-19` con una línea sobre exposición de logprobs y `AI-24` con inversión de embeddings, antes que crear procedimiento.

11. **Shadow MCP servers y agentes no inventariados** (MCP09, ASI10).
    Por definición no están en el `.mcp.json` del repo: viven en configuración de usuario (`~/.claude.json`, `~/.cursor/mcp.json`) o en CI. En una auditoría de repositorio el rendimiento es bajo. Ampliar el "Where to look" de `AI-09` con los ámbitos de usuario y de CI.

12. **SCA móvil: Gradle sin lockfile, CocoaPods/SPM, `.so` estáticos** (M2, MASWE CODE dependencias vulnerables, MASTG-TECH-0129..0133).
    `supply-chain.md` es genérico ("cualquier manifiesto o lockfile") y `SUP-11` ya avisa de que syft no ve binarios estáticos. Falta el matiz declarado: Gradle **no** tiene lockfile por defecto, así que "no hay lock" en Android no significa lo mismo que en npm. Nota en `mobile.md` §0 + entrada en la tabla de handoff, no procedimiento.

13. **Declarado frente a real en privacidad móvil** (MASWE PRIVACY, `PrivacyInfo.xcprivacy`, formulario Data Safety, dominios de tracking, purpose strings; MASTG-TECH-0136/0137).
    `PRV-06` cubre el 70% (qué sale, a quién, con qué base). Falta el contraste específico *declaración de tienda / purpose strings / manifiesto de privacidad* contra los SDK realmente enlazados. Ampliación de `MOB-04` y `MOB-14`, media.

14. **Perfiles de prueba MAS-L1 / MAS-L2 / MAS-R / MAS-P — corrección factual del corpus.**
    `mobile.md` §"How to use a procedure" y `traceability.md` afirman "MASVS v2.1.0 does **not** define L1/L2/R levels: do not use them". Es **correcto para MASVS** e **incompleto para el proyecto MAS**: los *testing profiles* existen como concepto propio (fuente: `Document/0x03b-Testing-Profiles.md` del repo `OWASP/owasp-mastg`) y definen el modelo de adversario del encargo — MAS-L1 asume SO confiable y otras apps adversarias; MAS-L2 asume SO **no** confiable (rooteado/jailbroken) y tercero con o sin acceso físico. Adoptarlos daría al rol móvil algo que hoy no tiene: declarar contra qué adversario auditó. Es una edición de §0 y de la matriz, no un procedimiento.

15. **Envenenamiento del conjunto de fine-tuning como ruta propia** (AITG-INF-05, AITG-MOD-03).
    Se pliega dentro de `AI-23` (una ruta de escritura al dataset es una ruta de escritura a los pesos). Se declara aquí para que no se lea como omitido.

16. **Manipulación del historial de chat del usuario** (AML.T0092) y **citas/renderizado como componente de confianza** (AML.T0067.000, AML.T0077, AML.T0100).
    Historial persistido en almacenamiento controlable por el cliente y reinyectado como contexto confiable: parcialmente `AI-18`. Citas falsificadas que el humano trata como verificadas: extensión natural de `AI-16` (que ya cubre el renderizado como canal). Dos frases en procedimientos existentes.

17. **NHI / identidad no humana del agente** (OWASP Non-Human Identities Top 10 — **temario no verificado**, el README no enumera NHI1..NHI10).
    El trozo distintivo —una única cuenta de servicio compartida por todos los usuarios, sin delegación ni caducidad— queda repartido entre `AI-05`, `AI-27` y `AI-28`. No se propone procedimiento sobre una fuente no verificada.

### Severidad baja

18. **ASI08 Cascading Failures como clase propia.** Se cubre por composición (`AI-19` topes + `AI-26` grafo de handoffs). Un procedimiento independiente sería un hallazgo de diseño difícil de hacer falsable.
19. **AITG-INF-06 robo de modelo en tiempo de desarrollo.** `SUP-16`/`SUP-18` cubren secretos; pesos propietarios en el árbol es una variante que cabe en `AI-23`.
20. **MASWE PLATFORM notificaciones con contenido sensible.** Una línea en `MOB-04`.

---

## 3. Borradores de procedimientos nuevos

En inglés, con el formato exacto del corpus, numeración continuada: `AI-23`..`AI-28`, `MOB-16`..`MOB-18`.

> **Nota de trazabilidad para quien los escriba.** Los IDs `MASWE-NNNN` individuales del área AUTH, PLATFORM y CODE se **derivaron por orden** del listado del temario, no se leyeron uno a uno en `mas.owasp.org/MASWE/`. Conforme a la política del corpus (regla 3 de `traceability.md`: un ID inventado que parece correcto es peor que ningún ID), los borradores citan el **grupo** y no el número. Verificar contra la fuente antes de fijar un número concreto.
>
> **Nota de licencia.** OWASP MCP Top 10 es **CC BY-NC-SA 4.0**: la cláusula NonCommercial es incompatible con un repo MIT. Los `MCP0x` se usan en este informe como referencia de *hueco* y **no aparecen en el campo Traceability de ningún borrador**; la trazabilidad se apoya en MITRE ATLAS (Apache-2.0), ASI/LLM (CC BY-SA, solo IDs), CWE y NIST (dominio público en EE.UU.). Ningún borrador reproduce ni parafrasea texto de ninguna fuente.

### AI-23 Model, adapter and dataset artifacts loaded without provenance or safe deserialization

**Where to look**
- Python loaders: `torch.load(`, `pickle.load(`, `joblib.load(`, `numpy.load(..., allow_pickle=True)`, `keras.models.load_model(` (Lambda layers), `tf.saved_model.load(`, `dill`, `cloudpickle`
- Hub clients: `AutoModel*.from_pretrained(` / `AutoTokenizer.from_pretrained(` with `trust_remote_code=True` or without an immutable `revision=`; `hf_hub_download(`, `snapshot_download(`, `ollama pull`, registry URLs, model buckets, and the `Dockerfile` or entrypoint that fetches weights at build or boot
- Artifacts in the tree or in the image: `*.pt`, `*.pth`, `*.ckpt`, `*.pkl`, `*.h5`, `*.bin`, `*.gguf`, LoRA adapters
- The fine-tuning and evaluation pipeline: where the training corpus, the adapter and the reward model come from, and who can write to that location

**Vulnerable pattern**
```python
model = torch.load(f"{CACHE}/{name}.pt")                          # pickle → code at load time
tok   = AutoTokenizer.from_pretrained(repo, trust_remote_code=True)  # runs code from the repo
```
A checkpoint is executable content: `.pt`, `.pkl`, `.ckpt` and `.h5` deserialize into Python objects and run code while loading, before a single token is generated. `trust_remote_code=True` executes modelling code published in the repository. Pulling by tag or branch instead of by commit or digest means the artifact you audited and the artifact production loads are not the same file. The dataset is the same problem one step earlier: a write path into the training corpus or the adapter is a write path into the weights, and no scanner will find it afterwards.

**What rules it out (false positive)**
- Weights are `safetensors` (no code execution on load), pulled by immutable revision or digest, checksum-verified against a first-party manifest, and `trust_remote_code` is absent or explicitly `False`.
- The artifact is first-party, produced by the pipeline in this repository, stored in an access-controlled registry and consumed by digest.
- The pickle-format file is a fixture generated by the test suite itself and is never loaded from a remote path.

**Minimal test**
Inventory, one row per artifact: format, source, pinning (tag / branch / commit / digest), who can publish under that name, `trust_remote_code`. Statically, `python -c "import pickletools,sys; pickletools.dis(open(sys.argv[1],'rb'))" file.pkl` disassembles a pickle **without executing it**; look for `GLOBAL` and `REDUCE` opcodes referencing `os`, `subprocess` or `builtins.eval`. Never load an untrusted checkpoint to inspect it. Downloading a third-party artifact onto a machine holding credentials: `REQUIRES AUTHORIZATION`.

**Traceability**: `LLM04:2026` · `LLM05:2026` · `ASI04` · `AML.T0010.003` · `AML.T0011.000` · `AML.T0018.000` · `CWE-502` · `CWE-494` · `CWE-829` · `SSDF PS`
**Tooling**: `rg -n "torch\.load|pickle\.load|joblib\.load|allow_pickle=True|trust_remote_code"` plus `fd -e pt -e pth -e ckpt -e pkl -e h5 -e gguf`. `picklescan` and `modelscan` are candidate generators matching known-bad opcode patterns: a clean scan is not evidence of a benign artifact (`VER-06` applies). A hit does not prove compromise — it proves the format permits execution and the source is not pinned.

### AI-24 Vector store deployment and the embedded copy of the data

**Where to look**
- Deployment: `docker-compose.yml`, Helm values, Terraform for `qdrant`, `chroma`, `weaviate`, `milvus`, `pgvector`, `redis`; the listening port, whether an API key or auth is configured, whether snapshot, backup or collection-listing endpoints are reachable
- Client construction: `QdrantClient(url=`, `chromadb.HttpClient(`, `weaviate.connect_to_*`, connection strings with no credentials, `create_collection(`
- Lifecycle: the code path that deletes a record from the source of record — does the same operation delete its chunks and its vectors? And the embedding provider call: what raw text leaves the perimeter to be embedded

**Vulnerable pattern**
A vector service exposed without authentication because "it is internal", holding the embedded copy of everything the pipeline ingested: contracts, tickets, personal records. Reading a collection returns payloads and vectors with no application layer in front. The quieter variant is the lifecycle one: the record is deleted from the database, the erasure job runs, and the chunk plus its vector stay in the index and keep coming back through retrieval. Treating an embedding as anonymized data is an assumption, not a control: inversion recovers substantial parts of the source text from the vector alone, so a dump of the index is a disclosure of the corpus.

**What rules it out (false positive)**
- The store requires authentication, is bound to a private network or a unix socket, and every query passes through an application layer that resolves identity (per-query filtering is `AI-14`, not this procedure).
- Deletion in the source of record propagates to chunks and vectors, with a test proving the vector disappears.
- What is indexed is public content with no personal data and no confidentiality expectation.

**Minimal test**
Local, against a development instance you own: bring up the compose file and `curl` the collection endpoint with no credentials. If it answers, the exposure is proved without touching production. For the lifecycle: index a synthetic record, delete it through the product's own deletion path, re-run the query, and see whether it still comes back. Against a deployed instance: `REQUIRES AUTHORIZATION`.

**Traceability**: `LLM09:2026` · `LLM02:2026` · `A01:2025` · `A02:2025` · `CWE-306` · `CWE-359` · `CWE-212` · ASVS 5.0 V14
**Tooling**: `rg -n "QdrantClient|chromadb|weaviate|milvus|pgvector|create_collection"` plus a read of the compose or Helm ports. The client carrying an API key proves the parameter exists, not that the server rejects an anonymous request: check the server side. Coordinate with `privacy-abuse` (`PRV-04`, `PRV-08`) — the vector index is the store that erasure procedures forget.

### AI-25 Agent skills and plugins: declared capability versus what the package does

**Where to look**
- Manifests: `skills/*/SKILL.md` front matter (`name`, `description`, `allowed-tools`), `.claude-plugin/plugin.json`, a `.mcp.json` bundled inside a plugin, `manifest.json`, `package.json` `contributes` and `activationEvents`, `.cursor/rules/**`
- What ships beside the manifest: `scripts/**`, `hooks/**`, `bin/**`, `*.sh`, `*.py`, `postinstall`, and every network call inside them
- Installation and update: marketplace entry or git URL, whether a version or commit is pinned, whether updates apply automatically

**Vulnerable pattern**
A skill is not a document, it is a package: instructions the model obeys, plus executable files, plus a declared permission set. Three findings live here.
1. The manifest declares narrow tools while a bundled script does something else — reads `~/.aws/credentials`, curls an endpoint, appends to a shell rc file.
2. The declared permission set is wider than the task needs (`allowed-tools: Bash` for a formatting helper), so any injection landing in that session inherits it.
3. The source is a marketplace or a git URL with no pinned revision and automatic updates, so what was reviewed once is not what runs tomorrow — the rug pull of `AI-08` applied to skills instead of MCP tools.
Apply the `AI-01` trifecta test to the package itself: instructions, private data and an egress path inside a single installable unit.

**What rules it out (false positive)**
- The package is first-party, lives in this repository, is covered by `CODEOWNERS` with security review, and is installed from a pinned commit.
- The manifest declares no tool with side effects and the directory contains no executable files (documentation-only skill).
- Execution is confined to a sandbox with no credentials and no network, and the permission prompt shows the literal command.

**Minimal test**
Per package, a two-column table: capability declared in the manifest against capability observed in the bundled files — `rg -n "curl|wget|requests\.|urllib|subprocess|os\.environ|~/\.aws|~/\.ssh" <package dir>`. Any row present on the right and absent on the left is the finding. Do not execute the package to find out. Run the `AI-20` sweep over the manifest and the instructions as well: this is exactly the file class the Rules File Backdoor targets.

**Traceability**: `LLM04:2026` · `ASI04` · `ASI02` · `AML.T0010.005` · `AML.T0011.002` · `AML.T0084.001` · `CWE-829` · `CWE-250` · `CWE-1104`
**Tooling**: `fd -H 'SKILL.md|plugin.json|manifest.json' <target>` for the inventory, `rg` over each package directory for the observed column. A package with no executables can still be a finding through its instructions alone (`AI-04`). This procedure also applies to the tooling you are running: a squad that never audits its own skill directory has not applied `AI-22`.

### AI-26 Inter-agent handoff without provenance or authentication

**Where to look**
- Orchestration: `crewai` (`Crew(`, `Task(`, `delegate`), `autogen` (`GroupChat`, `initiate_chat`), LangGraph (`Send(`, `Command(goto=`, subgraphs), `openai-agents` (`handoff(`), or the spawn call of a homegrown framework
- Transport: the HTTP route or queue where one agent posts work for another (`/agent`, `/task`, Redis, SQS, Kafka topics) and whether it authenticates the caller
- The receiving side: where the other agent's output lands — user turn, system turn, or a typed field

**Vulnerable pattern**
Agent A's output is written into agent B's context as if it were an instruction, with no marker of where it came from and no record of what A had read first. If A ingested untrusted content the taint crosses the boundary silently, and B usually holds a different tool set — often a more dangerous one — so passing the message along is itself the escalation. The transport variant: the handoff endpoint accepts any caller, so tasks are injected straight into the swarm without ever touching the user-facing agent. A self-replicating payload (each agent instructed to carry it into the next handoff) needs nothing beyond these two gaps.

**What rules it out (false positive)**
- Every inter-agent message carries origin and trust level, and the receiver's tool set is filtered on it — this is `AI-06` applied across the boundary.
- The handoff is a typed structure with a closed schema, not free text, and the receiver never interpolates the sender's prose into instructions.
- Transport is authenticated with per-agent identities and agents are unreachable from outside the orchestrator.

**Minimal test**
Draw the graph: nodes are agents, edges are handoffs. Annotate each edge with what crosses (free text or typed), whether the origin is marked, and which tools the receiver holds. An edge carrying free text from an agent with untrusted ingestion into an agent with a write or outbound tool is the finding, proved by construction. For dynamic evidence, place the `AI-01` canary in the first agent's ingestion source and look for it in the last agent's tool arguments.

**Traceability**: `LLM01:2026` · `ASI07` · `ASI08` · `ASI10` · `AML.T0061` · `AML.T0080` · `CWE-346` · `CWE-306` · `CWE-501`
**Tooling**: `rg -n "Crew\(|GroupChat|initiate_chat|handoff\(|Command\(goto|Send\("` → finds the edges, not the trust model. A framework advertising "secure handoffs" is describing transport, not provenance; read where the text lands.

### AI-27 Agent actions are not attributable: no trace, no retention, no reconstruction

**Where to look**
- The dispatcher and the tool wrapper: is there a record per tool call carrying subject, tool, arguments, outcome and a correlation id? `logging`, `structlog`, OpenTelemetry spans, `langfuse`, `langsmith`, `traceloop`
- What travels with it: the assembled prompt, the retrieved context identifiers, the model and version that decided
- Retention and destination of those records; whether the agent itself can write to them (`AI-28`); whether they leave the machine

**Vulnerable pattern**
The agent performs actions with real effects — sends, writes, pays, deploys — and the only evidence afterwards is the provider's usage counter plus whatever the model narrated in the chat. Nobody can answer which input produced the action, which document was retrieved, which model version decided it, or on whose behalf it ran. That is not a monitoring gap, it is non-repudiation: the effect is real and unattributable. When every user shares one service account the attribution collapses anyway. The inverse failure belongs to the same procedure: traces recording full prompts with personal data, shipped to a third-party observability vendor with no agreement — hand that leg to `privacy-abuse` (`PRV-06`).

**What rules it out (false positive)**
- Every invocation with side effects emits a structured record with the authenticated subject, the turn's correlation id, the tool, redacted arguments and the outcome, retained beyond the discovery window, in storage the agent cannot write to.
- The agent holds no tool with side effects (read-only assistant): there is nothing to attribute.

**Minimal test**
Take one irreversible action the agent can perform and trace backwards in code from the effect to the record, asking a single question: six weeks from now, could I reconstruct who caused it and with what input, without relying on the model's own account? Every missing link is the finding. Locally, run the agent once against a fixture and read what it actually emitted, rather than what the logging configuration claims it emits.

**Traceability**: `LLM03:2026` · `ASI03` · `ASI10` · `AML.M0024` · `A09:2025` · `CWE-778` · `CWE-223` · `NIST 800-53 AU`
**Tooling**: `rg -n "logger\.|structlog|opentelemetry|langfuse|langsmith"` over the agent module → tracing that exists for debugging is not an audit trail; check subject, retention and tamper resistance. Overlaps `infra-cloud` `INF-06` (platform logging): coordinate so the finding is written once, at the agent layer.

### AI-28 Agent execution boundary: writable scope, self-modification and inherited credentials

**Where to look**
- Filesystem and shell tools and their scope: `Read`, `Write`, `Edit`, `Bash`, `run_command`, `python_repl`, `file_write`, MCP filesystem servers and the directories mounted into them; the root path, the allow or deny list, whether the path is validated
- Whether that scope reaches the files that steer the agent: `CLAUDE.md`, `AGENTS.md`, `.cursor/rules/**`, `skills/*/SKILL.md`, `.mcp.json`, the memory store, the tool registry, and the audit records of `AI-27`
- The process environment: `~/.aws/credentials`, `~/.ssh`, `~/.kube/config`, `~/.netrc`, `~/.docker/config.json`, `gh` tokens, browser profiles, `.env`; the container or sandbox declaration (`docker run` flags, `--network`, seccomp, dedicated user); and any flag that disables confirmation globally

**Vulnerable pattern**
Two failures with one root cause — nobody defined the boundary.
1. The agent can write the files that govern it. One successful injection then stops being a session problem and becomes persistence: rules rewritten, a tool definition altered, memory seeded, and every later session — including other people's — starts compromised.
2. The agent inherits the ambient credentials of whoever launched it. The blast radius is not "the repository", it is every cloud account, cluster and registry that machine can reach. The model does not need to exfiltrate a key when it can run the CLI that already holds one.
Both are configuration, not exploitation: they are visible before any attack takes place.

**What rules it out (false positive)**
- The write scope is an explicit allowlist that excludes configuration, instruction, memory and audit paths, enforced in the tool rather than requested in the prompt.
- The agent runs as its own principal in a container with only the credentials its task needs, short-lived and scoped, with no host mount of the developer's home directory.
- Every side-effecting command passes a confirmation gate showing the literal argument (`AI-07`), with no global bypass flag set in the environment.

**Minimal test**
Two lists and one intersection. List A: paths the agent can write. List B: the steering, memory and audit paths above, plus the credential files present in the runtime environment (`ls ~/.aws ~/.ssh ~/.kube 2>/dev/null` on the machine being audited, with the owner's permission). A non-empty intersection is the finding and needs no exploitation. `env | rg -i "token|key|secret" | sed 's/=.*/=<redacted>/'` inventories what the process inherits without printing any value.

**Traceability**: `LLM03:2026` · `ASI03` · `ASI06` · `ASI10` · `AML.T0081` · `AML.T0083` · `AML.T0112.000` · `AML.M0026` · `AML.M0031` · `CWE-732` · `CWE-269` · `CWE-250`
**Tooling**: `rg -n "allowed[_-]?tools|allowedDirectories|dangerously|skip.?permissions|auto.?approve"` plus a read of the sandbox declaration. The absence of any sandbox declaration is the common case and is itself the finding; the presence of a container proves isolation of the process, not of the credentials mounted into it.

### MOB-16 Biometric and local authentication not bound to a cryptographic key

**Where to look**
- Android: `BiometricPrompt` and `BiometricManager`, **which `authenticate(` overload is used** (with or without `CryptoObject`), `setAllowedAuthenticators` (`BIOMETRIC_STRONG` vs `BIOMETRIC_WEAK` vs `DEVICE_CREDENTIAL`), `KeyGenParameterSpec` with `setUserAuthenticationRequired(true)`, `setInvalidatedByBiometricEnrollment(true)`, `setUserAuthenticationValidityDurationSeconds`; deprecated `FingerprintManager`
- iOS: `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)` and what is done with its `success` boolean, versus keychain items carrying `kSecAttrAccessControl` (`.biometryCurrentSet`, `.userPresence`); `evaluatedPolicyDomainState`
- What happens after success: does the app unwrap or decrypt something, or does it set `isUnlocked = true` and navigate?
- The fallback: a PIN validated locally against a stored hash, a "skip" path, or a weaker authenticator accepted for the same action

**Vulnerable pattern**
```kotlin
biometricPrompt.authenticate(promptInfo)          // no CryptoObject
// onAuthenticationSucceeded { showAccounts() }   // a boolean decides everything
```
The biometric result is just a branch in the app's own code, so the session token or the local data is available whether or not the check passes: anyone able to patch and repackage the app, or to hook the callback on a device they control, reaches the same state. The bound version differs in kind — the key that decrypts the material lives in the Keystore or the Secure Enclave, was created requiring user authentication, and is only usable inside the authenticated `CryptoObject`; there is no branch to flip. Second failure: keys that survive an enrollment change, so whoever adds a fingerprint to a stolen unlocked device inherits access. Third: a weak authenticator accepted for a high-value action.

**What rules it out (false positive)**
- Success unwraps a Keystore or Secure Enclave key created with `setUserAuthenticationRequired(true)` and `setInvalidatedByBiometricEnrollment(true)` (Android) or an access control of `.biometryCurrentSet` (iOS), and nothing sensitive is reachable without it.
- Biometrics are a convenience shortcut over a server-side session that is itself authenticated and revocable, and no local material of value is gated by the boolean.
- The action behind the prompt has no security value.

**Minimal test** — static: for every `authenticate(` and `evaluatePolicy(`, follow the success callback and answer one question: does anything cryptographic happen, or does control flow merely change? Then list the keys declaring user authentication and confirm the same material is not reachable by another route (a cached token from `MOB-03`, a backup from `MOB-02`). Hooking the callback on a device: **REQUIRES AUTHORIZATION**, and it is dynamic instrumentation, excluded from the automated pipeline per §0.

**Traceability**: `CWE-287` · `CWE-603` · `CWE-522` · `MASVS-AUTH-*` · `MASVS-CRYPTO-*` · MASWE AUTH group · `MASTG-TEST-*` from the AUTH group
**Tooling**: `grep -rn "BiometricPrompt\|CryptoObject\|setUserAuthenticationRequired\|evaluatePolicy\|kSecAttrAccessControl" out/` → the presence of `BiometricPrompt` says nothing. The finding is decided by the absence of `CryptoObject` on the call and of user authentication on the key. Under jadx, confirm the overload against the smali before concluding (§0).

### MOB-17 Confirmation screens without overlay and accessibility defenses

**Where to look**
- Android: `filterTouchesWhenObscured` in layouts and `setFilterTouchesWhenObscured(true)` in code; `onFilterTouchEventForSecurity` overrides; checks of `MotionEvent.FLAG_WINDOW_IS_OBSCURED` and `FLAG_WINDOW_IS_PARTIALLY_OBSCURED`; `Window.setHideOverlayWindows(true)`; whether the app itself requests `SYSTEM_ALERT_WINDOW`
- The screens where it matters: payment or transfer confirmation, permission grants, adding a beneficiary, approving a second factor, changing credentials — anything where one tap authorizes an effect
- Accessibility: whether the app declares an `AccessibilityService` of its own, and whether sensitive fields are marked (`importantForAccessibility`, `setDataIsSensitive`) or exposed to autofill by an arbitrary service
- iOS: the platform largely mitigates this class; the analogous checks are app-switcher snapshots and third-party keyboards (`MOB-15`)

**Vulnerable pattern**
A transparent window drawn by another app on top of the confirmation button: the user believes they are tapping "Cancel" and the touch lands on "Confirm transfer". This is the delivery mechanism behind most Android banking trojans, and the defense is one property the screen either declares or does not. The accessibility variant reaches further: a service the user granted under a pretext reads the screen and injects taps, so the operation is authorized without the user seeing it. The finding is not that the platform allows overlays — it is that a screen authorizing an irreversible effect accepts obscured touches.

**What rules it out (false positive)**
- Every confirmation view filters obscured touches (declaratively or in `dispatchTouchEvent`) and the flow hides overlay windows while displayed.
- Confirmation is out of band: the effect requires a code from a channel outside that screen, or a server-side approval a tap alone cannot produce.
- The screen authorizes nothing irreversible.

**Minimal test** — static: list every screen that authorizes an effect and check each for the touch filter or an equivalent guard. The intersection "authorizes an effect" and "no filter" is the finding, with no device involved. Building an overlay to demonstrate it means writing an attacking app: out of scope for this squad, and unnecessary — the absent control is the evidence.

**Traceability**: `CWE-1021` · `CWE-451` · `MASVS-PLATFORM-*` · MASWE PLATFORM group · `MASTG-TEST-*` from the PLATFORM group
**Tooling**: `grep -rn "filterTouchesWhenObscured\|FLAG_WINDOW_IS_OBSCURED\|setHideOverlayWindows\|SYSTEM_ALERT_WINDOW\|AccessibilityService" out/` over layouts and code → zero hits in a financial app is the finding, not a tooling failure. Confirm first that the screen exists: a grep cannot tell you which activity confirms a payment.

### MOB-18 Dynamic code loading and over-the-air bundle updates

**Where to look**
- Android: `DexClassLoader`, `PathClassLoader`, `InMemoryDexClassLoader`, `System.load(` and `System.loadLibrary(` with a path outside the APK, `Class.forName` over a downloaded name, plugin frameworks loading a downloaded APK, DEX or JAR, `WebView.evaluateJavascript` of remote script
- Cross-platform: React Native CodePush, Expo Updates, Capacitor live updates, Flutter dynamic feature modules, Unity asset bundles carrying scripts — the update URL, whether it is HTTPS, and whether the bundle signature is verified before use
- Where the artifact lands: `getFilesDir()`, `getExternalFilesDir()` or cache. A writable or shared directory means another app, or an intermediary on the network, chooses what executes

**Vulnerable pattern**
```java
File dex = new File(getExternalFilesDir(null), "plugin.dex");   // shared storage
new DexClassLoader(dex.getPath(), odex, null, getClassLoader())
    .loadClass("com.x.Plugin").newInstance();                    // nothing verified
```
Code that was never reviewed, never signed by the store and never present in the analyzed artifact runs with the app's full identity, permissions and data. The OTA bundle case is the same defect dressed as a product feature: a channel that fetches JavaScript and executes it is remote code execution by design, and its only real controls are signature verification of the bundle and a transport you cannot strip (`MOB-09`, `MOB-10`). It is also why a static review of the package stops being conclusive: what ships is not what runs.

**What rules it out (false positive)**
- The loaded artifact lives inside the package (`assets/`, `lib/`) or in the app's private directory, is written only by the app, and its signature or hash is verified against a key pinned in the artifact before loading.
- The OTA channel verifies a code-signing signature over the bundle before applying it, rolls back on failure, and pins the endpoint.
- The mechanism is the platform's own delivery (Play Feature Delivery, on-demand resources), where the store performs verification.

**Minimal test** — static: locate every loader and answer three questions — where does the artifact come from, who can write to that path, and what is verified before loading. Missing any one of the three is the finding. In the compiled artifact, confirm the loader survives into release (§0: source and APK are different evidence). Serving a modified bundle to a device: **REQUIRES AUTHORIZATION**.

**Traceability**: `CWE-494` · `CWE-829` · `CWE-114` · `MASVS-CODE-*` · `MASVS-RESILIENCE-*` · MASWE CODE group · `MASTG-TEST-*` from the CODE group
**Tooling**: `grep -rn "DexClassLoader\|InMemoryDexClassLoader\|System.load(\|codePush\|expo-updates\|evaluateJavascript(" out/` → a hit inside a third-party SDK (analytics, A/B testing) still counts: the finding belongs to the app that ships it. Under jadx a reflective loader may be reconstructed badly; cross-check the smali before reporting.

---

## 4. Ruido descartado

Contenido del temario que **no** merece procedimiento. Se declara para que no se lea como omisión.

1. **AITG-APP-10 Content Bias, APP-11 Hallucinations, APP-12 Toxic Output, APP-13 Over-Reliance, APP-14 Explainability.** Evaluación de IA responsable, no de seguridad ofensiva. Requieren generación en vivo (coste), corpus de juicio y un modelo juez: producen opiniones, no pruebas. `AI-21` ya fija esa epistemología y `VER-04` prohíbe cerrar un hallazgo con el veredicto de un juez.
2. **Categorías de contenido dañino de Microsoft Learn (Hateful and Unfair, Sexual, Violent, Self-Harm) y NIST 600-1 §2.11.** Son categorías de evaluación de guardarraíles, no clases de vulnerabilidad de aplicación. Se comprueba el rechazo; no se produce, no se almacena, no se reproduce en entregables.
3. **NIST AI 600-1 §2.1 CBRN.** Fuera de alcance por diseño; ya declarado.
4. **AITG-MOD-01 Evasion, MOD-06 Robustness to New Data, MOD-07 Goal Alignment; AML.T0043 Craft Adversarial Data, T0015 Evade AI Model, T0005 Create Proxy Model.** Investigación adversarial de ML: exige acceso al modelo, cómputo y una campaña propia. No cabe en una auditoría de aplicación por tiempo y coste, y `AI-21` ya explica por qué un ASR contra el modelo desnudo no dice nada de la ruta de producción.
5. **Marco metodológico de la AI Testing Guide** (1.2 Principles, 2.1.1/2.1.2 mapeos, apéndices SAIF, DIE, ciclo de vida del riesgo, enumeración de amenazas). Es metodología de encuadre; el escuadrón ya tiene la suya (inventario → pack → seis campos → trazabilidad).
6. **NIST AI RMF funciones MAP y MANAGE casi completas** (MAP 1.1-1.6, 3.x, 4.x; MANAGE 1.x-4.x). Gobernanza organizativa: tolerancias al riesgo, valor de negocio, actores interdisciplinares, planes de retirada, comunicación de incidentes. No es trabajo de un auditor técnico y convertirlo en procedimientos llenaría el corpus de casillas que nadie puede verificar leyendo código. Excepciones ya recogidas: MEASURE 2.7 (cubierta por el pack entero) y MANAGE 4.3 (parte del hueco de atribución, `AI-27`).
7. **NIST AI RMF función GOVERN.** Además, **no verificada** — no se abrió. No se afirma nada sobre ella.
8. **DeepLearning.AI "Red Teaming LLM Applications" (8 lecciones).** Curso de pago, todos los derechos reservados, y su contenido —panorámica de vulnerabilidades, red teaming a escala, LLM contra LLM— ya está cubierto conceptualmente por `AI-21`. Solo se cita como hecho de existencia.
9. **OWASP AI Exchange, 8 secciones.** Licencia no verificada y sin IDs de control obtenidos. No se deriva nada de una fuente cuya licencia no se conoce.
10. **MASVS-RESILIENCE como fuente de hallazgos** (root/jailbreak detection, emulador, ofuscación, anti-debug, attestation; MASWE 0051-0065). Deliberadamente descartado: `MOB-13` ya establece que el anti-tampering sube el coste del atacante pero no es control de acceso, y `mobile.md` §0 fija que ofuscar no sustituye un control de servidor. Añadir procedimientos aquí empujaría al escuadrón a recomendar exactamente lo que el corpus prohíbe recomendar. Nota para el remediador: nunca cerrar un hallazgo de `MOB-12` con "ofúscalo mejor".
11. **MASTG-TECH de instrumentación dinámica** (Frida, hooking, inyección de biblioteca, ejecución simbólica, parcheo y re-firma, bypass de root/jailbreak/pinning/biometría). Correctos y dentro de alcance con autorización escrita sobre la app del propio cliente, pero **excluidos del pipeline automatizado** por decisión ya tomada en `mobile.md` §0. Se proponen como trabajo aparte con alcance y permiso explícitos, no como procedimiento del pack.
12. **MASTG-KNOW (141 artículos) y MASTG-DEMO.** Material formativo y demostrativo, no procedimientos de auditoría.
13. **AITG-DAT-03 Dataset Diversity & Coverage y DAT-04 Harmful Content in Data.** Calidad de datos y seguridad de contenido; no producen un hallazgo de seguridad accionable en el código del cliente.
14. **Catálogo de 17 skills del OWASP Secure Agent Playbook.** Es un currículo *ejecutable* con el mismo formato que este escuadrón, es decir, un competidor/espejo, no un temario a incorporar. Licencia CC BY 4.0 (la más permisiva del área): útil como **referencia de contraste de cobertura**, y su mapeo CWE/ASVS/WSTG vía OpenCRE es una idea de trazabilidad a considerar aparte. No genera procedimientos.
15. **Código nativo, JNI y explotación binaria** (Android §15, MASTG análisis binario y ejecución simbólica). Ya declarado fuera de alcance en `traceability.md`; se mantiene.
16. **Operativa de SOC y respuesta a incidentes** (GenAI Incident Response Guide, Threat Defense COMPASS). Otro oficio; el escuadrón audita, no opera un SOC.
17. **Tácticas ATLAS de post-explotación y evasión** (TA0007 Defense Evasion, T0072 Reverse Shell, T0090 Credential Dumping, T0105 Escape to Host, T0113 Steal Session Cookie, T0101 Data Destruction, T0088 Deepfakes). Fuera de alcance por el contrato de seguridad, ya declarado en el encargo. Nota deliberada: la contrapartida defensiva sí entra — confirmación humana (`AI-07`), reversibilidad y auditabilidad (`AI-27`).

---

## 5. Cuentas del informe

- Temas del temario evaluados: **36 bloques**, ~330 subtemas.
- Ya cubiertos por procedimiento existente: **34 mapeos** (22 IA, 12 móvil).
- Huecos: **20** — 9 altos, 8 medios, 3 bajos.
- Procedimientos nuevos propuestos: **9** (`AI-23`..`AI-28`, `MOB-16`..`MOB-18`). El corpus pasaría de 122 a 131.
- Ruido descartado explícitamente: **17 bloques**, que es la mayor parte del volumen del temario.

Si alguien quiere una regla para leer esto: el temario profesional del área de IA está desplazado hacia gobernanza y evaluación de modelos, y el corpus está —correctamente— desplazado hacia la aplicación y el agente. Los nueve huecos altos son justo la franja donde ambos deberían solaparse y hoy no lo hacen: **el artefacto** (modelo, dataset, skill), **el borde** (entre agentes, con el sistema de ficheros, con las credenciales) y **la traza**. En móvil, los tres huecos son los tres controles que un banco exige y el pack no pregunta: biometría ligada a clave, superposición de ventanas y código que llega después de la tienda.
