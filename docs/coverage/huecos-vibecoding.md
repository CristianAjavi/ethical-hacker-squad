# Análisis de cobertura — código escrito por un LLM (vibecoding)

**Analista de huecos.** Contrasta el terreno ya cartografiado en [`mapa-vibecoding.md`](mapa-vibecoding.md)
—Veracode 2025, Pearce IEEE S&P 2022, Perry CCS 2023, Sandoval USENIX 2023, Fu TOSEM 2025, Mao 2026,
GitClear 2025/2026, Wu FSE 2025, Spracklen USENIX 2025, Wang ICSE 2025 y 2026, Pillar, NVD, OWASP—
contra el corpus real del escuadrón, procedimiento por procedimiento:

- Los **164 procedimientos** de `skills/ethical-hacker-squad/references/knowledge/` (18 ficheros de
  procedimientos + `README.md`), familias `AI-01..28`, `INF-01..23`, `LOC-01..15`, `MOB-01..18`,
  `PRV-01..13`, `REM-01..07`, `SUP-01..25`, `VER-01..09`, `WEB-01..26`.
- Los **9 ficheros de `agents/`** y su lista de carga.
- `references/coverage.md` (encaminamiento), `references/triage.md` (`FP-01`..`FP-10`),
  `references/traceability.md` (huecos ya declarados).

Censo ejecutado el 2026-08-24 sobre el árbol en `84986a3`. **Modo solo lectura para el censo**: este
fichero y su mapa son el único entregable de este análisis; los procedimientos que propone se
escriben aparte.

---

## 0. Criterio de "cubierto"

Cubierto = un especialista que carga ese procedimiento y sigue sus seis campos **encuentra ese fallo
concreto**. No cuenta que el símbolo aparezca de pasada en un campo "Where to look" de otro
procedimiento escrito con otro propósito.

Y aquí hay un segundo criterio que este terreno obliga a añadir, porque casi todo el ruido público
sobre vibecoding se disuelve al aplicarlo:

> **Un defecto no entra por haber aparecido en una aplicación generada. Entra si el generador lo
> produce de una forma que un procedimiento por fichero no puede plantear.**

Dos ejemplos reales de este cruce, uno en cada dirección:

- **No es hueco**: la ausencia de autorización a nivel de fila que hizo célebre a una plataforma de
  *app builders* (`mapa-vibecoding.md` E.1) es `CWE-863`. `WEB-04` la encuentra, con su patrón, sus
  exculpaciones y su prueba. Que la escribiera un generador y que se repitiera en el 10,3 % de una
  plataforma cambia la **frecuencia**, no la **detección**. Inflarlo como hueco sería vender como
  nuevo lo que el corpus ya hace.
- **Sí es hueco**: `SUP-08` busca importaciones de paquetes **ausentes de todo manifiesto** y las
  verifica contra el registro. Un nombre alucinado **que un atacante ya registró** resuelve, instala,
  produce un hash de integridad válido en el fichero de bloqueo y no tiene ningún aviso publicado.
  Pasa la prueba mínima de `SUP-08` con nota. Eso no es un matiz: es el caso que importa.

---

## 1. Cobertura confirmada — no hace falta procedimiento nuevo

Esta sección es tan importante como la de huecos. Es la lista de lo que **no** vamos a reescribir con
otro nombre.

### El defecto que el generador produce, y quién lo encuentra hoy

| Clase medida en el mapa | Procedimiento que ya la cubre |
|---|---|
| `CWE-89` inyección SQL — la peor clase de Perry (36 % frente a 7 %) | `WEB-07` |
| `CWE-78` inyección de órdenes — 83,3 % de escenarios vulnerables en Pearce, 6,21 % de las debilidades de Fu | `WEB-08` |
| `CWE-79`/`CWE-80` XSS — **la peor clase del generador en Veracode (13,53 %)** y 9,55 % en Fu | `WEB-13` (servidor), `WEB-14` (cliente y CSP) |
| `CWE-330` valores no aleatorios — **la clase mayor de Fu (18,15 %)** | `WEB-03`, `WEB-19`, `MOB-11` |
| `CWE-798` credenciales embebidas, `CWE-522` credenciales sin proteger | `SUP-16`, `SUP-17`, `MOB-12`, `LOC-15` |
| `CWE-327` criptografía rota — donde el generador **acierta** (85,61 %) | `WEB-19` |
| `CWE-22` recorrido de rutas (60,4 % en Pearce) | `WEB-12`, `LOC-01` |
| `CWE-502` deserialización, `CWE-94` inyección de código (9,87 % en Fu) | `WEB-11`, `WEB-09`, `AI-15` |
| `CWE-427` ruta de búsqueda no controlada (5,57 % en Fu) | `LOC-06` |
| `CWE-863` autorización ausente a nivel de objeto o de inquilino (el incidente E.1) | `WEB-04`, `WEB-25`, `PRV-05` |
| Punto final sin autenticar que trata un identificador no secreto como capacidad (el incidente E.2) | `WEB-05` + `WEB-04` |
| Valores por defecto permisivos del andamiaje: CORS abierto, `DEBUG` activo, cookie sin banderas | `WEB-16`, `WEB-22`, `WEB-02` |
| Clave de servicio o clave anónima viajando en el paquete del cliente | `SUP-16`, `MOB-12`, `PRV-06` |
| Dependencia con versión vulnerable (la mitad con CVE de C.3) | `SUP-02`, `SUP-13`, `SUP-14`, `SUP-24` |
| Rango flotante y fichero de bloqueo ausente o desincronizado | `SUP-01`, `SUP-02` |
| Control **declarado y nunca cableado** — un middleware definido y no registrado, una constante de límite sin lectores | `WEB-23` |
| Verificación de firma que acepta a cualquiera o que no bloquea nada | `SUP-22` |
| Asimetría entre dos manejadores hermanos, uno con control y otro sin él | `WEB-24` |
| Sin separación de entornos, agente con credenciales de producción (el incidente E.3) | `INF-17`, `INF-05`, `AI-28` |

### El fichero de instrucciones del generador, y quién lo cubre hoy

| Clase | Procedimiento |
|---|---|
| Autoría y revisión de `CLAUDE.md`, `AGENTS.md`, `.cursor/rules/**`, `.github/copilot-instructions.md`, `.windsurfrules`, `.clinerules` | `AI-04` |
| Unicode invisible en esos ficheros — el *Rules File Backdoor* citado por su nombre, con el bloque Tags, los de ancho cero y los bidireccionales | `AI-20` |
| El propio escuadrón leyendo un repositorio que le habla | `AI-22` |
| Servidores MCP sin versión fijada e instalados con `npx -y` | `AI-09` |
| Secretos dentro de la configuración MCP, incluida `.cursor/mcp.json` | `AI-11` |
| Un paquete o *skill* cuya capacidad declarada no coincide con lo que hacen sus ficheros | `AI-25` |
| Alcance de escritura del agente, automodificación y credenciales heredadas del entorno | `AI-28` |
| Descripción de herramienta envenenada, *rug pull*, sombreado entre servidores | `AI-08` |

### La dependencia alucinada

`SUP-08` **ya existe**, ya cita a Spracklen et al. con las cifras del resumen, y ya está encaminado
desde `coverage.md`. Quien escriba "el corpus no cubre las dependencias alucinadas" no ha leído el
corpus. Lo que le falta a `SUP-08` está en el hueco 1, y es otra cosa.

---

## 2. Huecos

Ordenados por valor. Cada uno dice **qué deja de encontrar hoy el escuadrón**, con qué evidencia, y
de qué nivel es esa evidencia. Un hueco cuya evidencia es solo mecánica se etiqueta **hipótesis** y
se dice en voz alta.

---

### Hueco 1 — El nombre alucinado que **sí** resuelve → `SUP-26`
**Evidencia: nivel A** (Spracklen et al., USENIX Security 2025) **+ comprobación directa de registro
y de la base de avisos.**

**Hoy**: `SUP-08` resta del conjunto de importaciones las que resuelven a módulos locales o a
dependencias declaradas, y verifica cada resto contra el registro real. Su exculpación es *"el
paquete existe, es antiguo y es el que el proyecto usa"*. Un nombre alucinado registrado por un
atacante **existe**, y ahí termina la comprobación.

**Por qué el resto de la pila tampoco lo ve**, mecánicamente:

- El fichero de bloqueo guarda un **hash de integridad válido**, calculado sobre el paquete del
  atacante. Un *lockfile* responde "¿me llegaron los mismos bytes que la última vez?", nunca "¿debería
  estar este nombre aquí?".
- La base de avisos devuelve **nada**. Medido: cero avisos para los tres nombres que circulan como
  casos, con controles que sí devuelven registros (`lodash`, `event-stream`, `ctx`), de modo que el
  nulo es real y no un fallo de consulta. Un aviso es reactivo: existe **después** de que alguien
  denuncie un paquete concreto, y todo el valor del ataque está en la ventana anterior.
- `SUP-07` (paquetes con nombre casi idéntico a uno legítimo) **sub-dispara por construcción**: se
  apoya en una distancia de edición pequeña respecto a un nombre popular, y el artículo mide que **la
  mayoría de los nombres alucinados no se parecen a ningún paquete válido**.

**Lo que hay que preguntar en su lugar** —propiedades del paquete, no su nombre—: la fecha de primera
publicación frente a la edad del proyecto que lo importa; ausencia de enlace a repositorio junto a
una sola versión publicada; historial de descargas de tres cifras frente a las siete del paquete que
se pretendía; y **existir en el registro equivocado** — el 8,7 % de los nombres alucinados en Python
son paquetes válidos de JavaScript.

**Y una consecuencia de diseño que hay que escribir dentro del procedimiento**: una lista negra de
nombres cosechados **no sirve**. El 81 % de los nombres alucinados los produce un solo modelo,
mientras el 58 % persiste dentro de ese modelo entre ejecuciones. La lista no generaliza y caduca; la
regla tiene que ser sobre metadatos.

**Añadido a `SUP-08`**: su línea de trazabilidad no cita **ninguna** referencia de OWASP, y desde la
edición 2026 esta clase tiene dos: `LLM07:2026` para la alucinación y `LLM04:2026` para el registro
del nombre como vector.

---

### Hueco 2 — El repositorio que actúa sobre la máquina que lo abre → `AI-29`
**Evidencia: nivel B, cinco CVE, dos de ellas verificadas dos veces de forma independiente.**

**Hoy**: `AI-04` pregunta **quién escribió y quién revisó** los ficheros de instrucciones. `AI-22`
ordena tratarlos como material a reportar y **no ejecutar el código del objetivo** por curiosidad.
`AI-09` mira los servidores MCP **del producto auditado** como riesgo de cadena de suministro. `AI-11`
busca secretos en esas mismas configuraciones. Ninguno de los cuatro plantea la pregunta:

> **¿Qué se ejecuta, y qué configuración del lector queda anulada, por el mero hecho de abrir este
> árbol?**

**Lo que deja de encontrar hoy** — todo ello presente en el árbol, todo greppable:

- `CVE-2025-64109` (Cursor anterior a 2025.09.17-25b418f, `CWE-78`, CVSS 8,8): un `.cursor/mcp.json`
  **del repositorio** ejecuta órdenes al abrir el proyecto, sin consentimiento.
- `CVE-2025-59536` (Claude Code anterior a 1.0.111, `CWE-94`, CVSS 8,8): ejecución de código del
  proyecto **antes** del diálogo de confianza.
- `CVE-2025-61592` (Cursor 1.7 e inferiores): un `.cursor/cli.json` del repositorio **prevalece sobre
  la configuración global** del usuario. Esta es la variante de **precedencia**, y no hay ningún
  procedimiento en el corpus que pregunte qué fichero del árbol gana sobre qué ajuste del lector.
- `CVE-2026-21852` (Claude Code anterior a 2.0.65) y `CVE-2026-30615` (Windsurf 1.9544.26).

**Dos matices de honestidad que el procedimiento tiene que llevar dentro:**

1. **No es exclusivo de la IA.** Un `.vscode/tasks.json` con ejecución al abrir la carpeta y un
   `postCreateCommand` de contenedor de desarrollo son el análogo anterior, y **tampoco** están
   cubiertos. La clase correcta es "configuración del repositorio que se ejecuta al abrirlo"; las
   herramientas de IA la volvieron común y le pusieron CVE.
2. **La víctima no es el usuario del producto**, es el siguiente colaborador que clone el repositorio
   — y el auditor. Eso obliga a nombrar el segundo principal, igual que hace `local-app.md` §0.

**Además**: la versión del propio agente de codificación, cuando el repositorio la fija (por ejemplo
en `package.json`), es una dependencia que nadie compara contra las versiones corregidas. `SUP-24`
cubre componentes fuera de soporte, no esto.

---

### Hueco 3 — Un control que se ejecuta y **no puede fallar** → `WEB-27`
**Evidencia: mecanismo de nivel B (Veracode) + un caso ilustrativo de nivel A (Perry).
Prevalencia: NO MEDIDA POR NADIE. Se etiqueta hipótesis.**

**Hoy**: `WEB-23` encuentra el control **no cableado** — la constante de límite sin lectores, el
middleware definido y nunca registrado, el validador definido y nunca llamado. Su eje es la
**alcanzabilidad**. `SUP-22` encuentra una instancia concreta del otro eje: la verificación de firma
que acepta a cualquier firmante o que no bloquea nada. **Nada generaliza ese segundo eje al código de
aplicación.**

**Lo que deja de encontrar hoy**: el control que está registrado, se llama, se ejecuta — y cuyo
cuerpo no tiene ningún camino que devuelva falso. Un predicado de validación sin rama negativa. Una
comparación de secretos que lee un solo operando. Un saneador que devuelve su argumento. Una
verificación envuelta en un `except` que se traga el error y continúa. Un `assert` en un intérprete
que corre con optimización.

**Por qué esta clase es peor que un control ausente, y es lo que la hace valiosa**: un control
ausente **añade** un hallazgo; un control inerte **borra** hallazgos. Un análisis por contaminación
modela los saneadores por nombre o por firma configurada, de modo que una función llamada
`sanitize_input()` que devuelve su argumento **limpia la contaminación** y elimina el hallazgo aguas
abajo. Y en el triaje de este mismo repositorio es la forma canónica de responder `FP-01 HOLDS`
—"existe un control compensatorio en una capa que no se puede saltar"— sobre un control que no
compensa nada. Es decir: **esta clase produce falsos negativos por las dos vías que el corpus ya usa.**

**El mecanismo, y viene medido**: Veracode explica su propio 13,53 % en XSS y 12,03 % en registro
diciendo que el saneado aparece a menudo como reacción a un **nombre de variable frecuente** en los
ejemplos de entrenamiento. Un control disparado por una pista léxica y no por un hecho de flujo de
datos es exactamente un control colocado donde no toca. Y en Perry hay el caso ilustrativo: cifrado
AES-EAX correcto que **no devuelve la etiqueta de autenticación**; el participante, al ver una
etiqueta que nadie le pedía usar, concluyó que no hacía falta.

**Lo que hay que decir en voz alta**: **no existe ninguna medición publicada de la prevalencia de
esta clase.** Se buscó y no se encontró. El procedimiento se escribe por su mecanismo y por su coste
—borra hallazgos—, no por una tasa. Y el caso de banco de pruebas que lo acompaña la convierte en la
primera medición que este repositorio puede publicar sobre ella.

---

### Hueco 4 — Un referente que el proyecto no define en ninguna parte → `INF-24`
**Evidencia: mecanismo de nivel A por analogía medida (la alucinación de paquetes es exactamente esta
clase, en el eje de dependencias). Prevalencia para variables de entorno, claves de configuración y
rutas internas: NO MEDIDA. Se etiqueta hipótesis.**

**Hoy**: `SUP-08` cubre un caso particular de esta clase —el **paquete** que el código importa y
ningún manifiesto declara—. Nadie hace el mismo cruce con el resto de los nombres de los que depende
el código.

**Lo que deja de encontrar hoy**: `os.environ.get("JWT_SECRET", "dev-secret")` donde **ningún**
fichero de despliegue, gráfico, plantilla de entorno ni fichero de composición define `JWT_SECRET`.
El programa arranca. El valor por defecto es el secreto. Y también: una clave de configuración que se
lee y ningún fichero de ajustes escribe; una llamada interna a una ruta que ninguna tabla de rutas
registra; un indicador de característica que se consulta y nadie define, cuyo valor ausente decide si
el control se aplica.

Es la contrapartida exacta de `WEB-23` y merece decirse así: `WEB-23` encuentra **un nombre declarado
que nadie lee**; esto encuentra **un nombre leído que nadie declara**. Los dos son uniones entre
ficheros y ninguno de los dos lo ve un analizador, porque la forma del código es correcta.

**Por qué es característico de un generador**: el modelo escribe contra un despliegue **imaginado**.
No tiene el fichero de entorno delante, y el idioma seguro —leer con valor por defecto— es
precisamente el que convierte la ausencia en silencio. Es el mismo mecanismo que produce el nombre de
paquete inexistente, aplicado a un nombre que no vive en ningún registro que se pueda consultar.

**El detector es una unión pura y no necesita criterio**: enumerar todo nombre literal de variable de
entorno, clave de configuración y ruta interna referenciado desde el código; enumerar todos los que
define cualquier manifiesto, gráfico, `*.env.example`, fichero de composición o tabla de rutas;
restar. Sin modelo, sin ajuste de falsos positivos. El hallazgo de seguridad es el **valor por defecto
que queda vigente**, no la ausencia en sí.

---

### Hueco 5 — Verificar el **caso**, con la familia intacta → `VER-10`
**Evidencia: nivel A para la persistencia dentro de un modelo (Spracklen) y nivel A de sede para las
tasas de clonado (Wu, FSE 2025). En disputa en el eje entre ficheros (Mao 2026). Ver la advertencia.**

**Hoy**: `REM-01` lo dice bien y lo dice primero — antes de tocar nada, buscar en todo el repositorio
otros usos del mismo patrón, y si el parche no los cubre, decirlo en el informe con la lista. Es una
instrucción excelente **en el lado de la reparación**. En el lado de la verificación no hay nada:
`VER-02` exige que **el caso original** falle ahora, `VER-03` busca variantes del **mismo** control,
y `VER-08` exige las tres ejecuciones sobre **ese** hallazgo. **Ningún procedimiento exige que los
hermanos vuelvan a medirse.** El resultado es la forma más cómoda de firmar un `verified` falso:
arreglar uno de nueve y comprobar ese uno.

**Por qué el generador lo agrava**, con la evidencia y su reserva:

- La completación de un modelo es casi determinista respecto a su contexto. Está medido como
  persistencia: **43 % de los nombres alucinados reaparece en las diez repeticiones del mismo
  *prompt*, 58 % más de una vez**, y variar la temperatura mueve la tasa un 1,16 %.
- Wu et al. (FSE 2025) miden clones Tipo-1 + Tipo-2 de hasta **7,50 %** en generadores comerciales, y
  nombran la propagación de código vulnerable por clonado como el riesgo.
- Wang et al. (2026) observan que los diez modelos convergen en el **mismo** conjunto pequeño de
  versiones de riesgo.

> **Advertencia obligatoria, y va dentro del procedimiento**: **no se puede afirmar que la IA aumente
> la duplicación.** GitClear lo mide subiendo (0,45 % → 6,66 % de *commits* con bloque duplicado entre
> 2022 y 2024) sobre una muestra propia, sin atribuir autoría de IA por *commit* y declarándolo como
> correlación; Mao et al. (2026) miden **duplicación entre ficheros MENOR** en código de IA (17,20 %
> frente a 24,52 %). Son denominadores distintos, no un empate — y quien escriba lo contrario está
> afirmando más de lo medido.

Por eso el procedimiento **no** se escribe como "el código de IA está duplicado". Se escribe como lo
que sí se sostiene: **un hallazgo cuya familia no se enumeró no está verificado**, se genere como se
genere el código. Es barato, se mide, y cae exactamente donde este repositorio tiene su ventaja medida
—la verificación— y no donde no la tiene.

**Y hay una medición que nadie ha publicado y que este repositorio puede publicar**: el número medio
de clones hermanos por hallazgo de seguridad. La técnica es estándar —normalizar identificadores,
canonizar literales, hashear el subárbol, agrupar—. Si la mediana resulta ser 1, la historia entera se
cae, y lo habríamos mostrado nosotros.

---

### Hueco 6 — `CWE-117`, y no tiene nada que ver con la IA → `WEB-28`
**Evidencia: nivel B (Veracode), directa.**

Este hueco lo encontró esta cartografía sin buscarlo, y hay que presentarlo por lo que es.

**Hoy**: el corpus no tiene **ningún** procedimiento para inyección en registros. `WEB-22` cubre la
**divulgación a través** de los registros —`CWE-209`, `CWE-532`, `CWE-778`—: qué se escapa por el log.
La dirección contraria, escribir en el registro datos controlados por el atacante sin neutralizar
saltos de línea ni secuencias de control, no aparece. `CWE-117` no se cita en ninguna línea de
trazabilidad de los 164 procedimientos.

**Por qué sale aquí**: porque `CWE-117` es, junto a `CWE-80`, **la clase que peor resuelve el
generador**: 12,03 % de aprobación en Veracode. Un corpus que se presente como la mejor opción para
auditar código generado y que no tenga procedimiento para la clase que el generador falla el 88 % de
las veces no es defendible.

**No es un hueco de vibecoding.** Es un hueco de AppSec ordinaria que esta lente sacó a la luz, y así
hay que escribirlo: sin la palabra vibecoding en ninguna parte del procedimiento.

---

## 3. Lo que **no** es un hueco, aunque el mercado lo venda como tal

Esta sección existe porque la tentación de inflar aquí es enorme.

| Se dice que… | Qué es en realidad | Quién lo cubre |
|---|---|---|
| "El código generado trae valores por defecto permisivos" | Frecuencia elevada, detección ordinaria. `CWE-330`, `CWE-798`, `CWE-732` son cobertura central de cualquier analizador y de este corpus | `WEB-03`, `WEB-19`, `SUP-16`, `MOB-11` |
| "Las apps generadas filtran claves en el paquete de cliente" | Error de 2015. Lo único nuevo es que un generador lo repite | `SUP-16`, `MOB-12` |
| "Las plataformas de *app builder* dejan la base de datos abierta" | `CWE-863`. Además, el estado de las políticas de fila vive en el proveedor, no en el árbol: es petición de evidencia (`FP-08`), no barrido | `WEB-04`, `PRV-05` |
| "El vibecoding introduce inyección de *prompt*" | Eso es un producto **de** IA, no código **escrito por** IA. Terreno distinto y ya cubierto | `AI-01`..`AI-22` |
| "Hay que detectar si el código lo escribió una IA" | No es auditable ni útil: dos clientes con el mismo árbol declaran procesos distintos. El criterio de entrada es un **artefacto**, no una declaración | §5 |
| "Los ficheros de reglas del agente son una superficie nueva" | La mitad de instrucción y de Unicode invisible está cubierta desde `AI-04` y `AI-20`, con la investigación citada por su nombre. Lo que falta es la **ejecución al abrir**, y es el hueco 2 | `AI-04`, `AI-20` |
| "La alucinación de dependencias es un hueco" | `SUP-08` existe desde antes de este análisis. Lo que falta es el caso en que el nombre **ya resuelve**, y es el hueco 1 | `SUP-08` |

---

## 4. Decisión de arquitectura: por qué **no** hay un pack `vibecoding`

Lo primero que pide el cuerpo es crear `knowledge/vibecoding.md` con familia `VIB-01..`, un rol nuevo
y una fila en el plantel. Se descarta, y conviene dejar escrito por qué, porque es reversible y
alguien lo volverá a proponer.

1. **El vibecoding no es una superficie, es una procedencia.** Los packs de este corpus se cargan por
   lo que hay en el inventario —hay rutas HTTP, hay un `AndroidManifest.xml`, hay Terraform—. "Lo
   escribió un modelo" no es un componente: es una propiedad de **cómo** llegó ahí el código que ya
   está clasificado por superficie. Los seis huecos de §2 caen en cinco superficies distintas.
2. **Un rol nuevo compite por una plaza.** El escuadrón dota **de dos a cuatro** especialistas
   (`SKILL.md` paso 3). Un rol `vibecoding` desplazaría a uno que sí tiene superficie que auditar, y
   además tendría que reportar un control inerte en una ruta web, que es el carril de `ehs-web-api`.
   Este repositorio es cuidadoso con los carriles y romperlo por presentación sería el peor motivo.
3. **Un pack transversal leído por un solo rol es una contradicción con el contrato del propio
   repositorio**: `gate-corpus-contract.sh` exige que todo fichero de pack lo lea algún rol del
   plantel, y un fichero cuyos procedimientos pertenecen a cinco roles no tiene dueño honesto.
4. **La discusión de descubrimiento se resuelve donde toca**: con este par de documentos, con una fila
   de encaminamiento en `coverage.md`, y con el `README` — no metiendo prosa comercial en la
   estructura operativa.

Lo que **sí** hace falta y no existía es el **criterio de entrada**: §5.

---

## 5. Criterio de entrada — qué hace que el escuadrón haga estas preguntas

Nada en `SKILL.md` paso 2 ni en `coverage.md` dice hoy que la **procedencia** del código sea parte
del inventario. Hace falta una señal observable en el árbol, nunca una declaración del cliente:

- Ficheros que dirigen a un generador: `CLAUDE.md`, `AGENTS.md`, `.cursor/rules/**`, `.cursorrules`,
  `.github/copilot-instructions.md`, `.windsurfrules`, `.clinerules`, `.continue/**`.
- Configuración que un editor con agente ejecuta o consume al abrir el proyecto: `.cursor/mcp.json`,
  `.cursor/cli.json`, `.mcp.json`, `.vscode/tasks.json`, `.devcontainer/**`.
- Rastros en el historial: mensajes de *commit* con marcas de coautoría de un agente, o
  incorporaciones grandes de un solo golpe sin revisión.
- El agente de codificación como dependencia declarada del propio proyecto.

Una sola de esas señales basta para abrir las secciones de los seis procedimientos de §2. Y hay que
decir el límite en el mismo sitio: **su ausencia no prueba nada**. Un repositorio generado del que se
borraron los ficheros de configuración se ve igual que uno escrito a mano. La señal enruta; nunca
exculpa.

---

## 6. Lo que queda declarado como no cubierto

Se declara, en vez de dar a entender que está cubierto — la misma doctrina de la sección de huecos
conocidos de `traceability.md`:

- **Idiomas de API obsoletos que todavía no son una CVE.** Está bien medido (25–38 % de uso obsoleto,
  y **9–18 % incluso cuando el contexto usa la API moderna**), y no lo ve nadie: no el análisis
  estático, porque no hay vulnerabilidad que emparejar; no el análisis de composición, porque la
  **versión** del paquete está bien y lo que está viejo es la **llamada**. **No se escribe
  procedimiento** porque su eje no es una pregunta sobre el repositorio: exige un oráculo de vigencia
  externo —un mapa de deprecaciones, un canal de publicación— y sin él la respuesta honesta es
  `UNKNOWN` por `FP-08` en todos los casos. Un procedimiento que siempre responde `UNKNOWN` es prosa.
- **Prevalencia de las clases de los huecos 3 y 4.** Nadie las ha medido. Los procedimientos se
  escriben por mecanismo y lo dicen dentro.
- **Clones hermanos por hallazgo.** Medición ausente en toda la literatura abierta; el hueco 5 la
  convierte en trabajo propio.
- **El estado en el proveedor** de las plataformas de *app builder* —políticas de fila, ajustes del
  panel—: es petición de evidencia bajo `FP-08`, no barrido, y así hay que reportarlo.

---

## 7. Resumen ejecutable

| # | Hueco | Destino | Evidencia | Caso de banco |
|---|---|---|---|---|
| 1 | El nombre alucinado que ya resuelve | `SUP-26` + retoque a `SUP-08` | Nivel A + medición propia de registro | sí |
| 2 | El repositorio se ejecuta al abrirlo | `AI-29` | Nivel B, 5 CVE | sí |
| 3 | Un control que corre y no puede fallar | `WEB-27` | Mecanismo medido, prevalencia **hipótesis** | sí |
| 4 | Un referente que nadie define | `INF-24` | Analogía medida, prevalencia **hipótesis** | sí |
| 5 | Verificar el caso con la familia intacta | `VER-10` | Nivel A con reserva declarada | sí |
| 6 | `CWE-117`, hueco de AppSec ordinaria | `WEB-28` | Nivel B directa | sí |

Seis procedimientos en cinco packs. **Ningún pack nuevo, ningún rol nuevo, ninguna familia de
identificadores nueva.**
