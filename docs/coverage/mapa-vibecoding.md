# Mapa de terreno — Área "código escrito por un LLM" (vibecoding)

Cartografía de las fuentes públicas citables sobre el código que escribe un modelo, no sobre los
productos de IA. **Terreno crudo**: definiciones, diseños experimentales, cifras publicadas e
identificadores tal como los nombra cada fuente. No hay redacción copiada de ninguna de ellas.
Extraído el **24 de agosto de 2026**.

Regla aplicada en todo el documento, la misma de `mapa-ia-movil.md` y `mapa-microsoft.md`: se citan
**identificadores, títulos, fechas, diseños de estudio y cifras medidas** (hechos no protegibles),
se declara la **licencia** de cada fuente y la **fecha de consulta**, y no se reproduce la redacción
de nadie.

Cada entrada lleva un **nivel**:

| Nivel | Qué significa |
|---|---|
| **A** | Medición revisada por pares, publicada en conferencia o revista |
| **B** | Informe con metodología declarada — preprint sin revisar, o investigación de proveedor |
| **C** | Incidente único o nota de prensa, sin metodología |

Un nivel **C** no se convierte en procedimiento. Sirve para saber que la clase existe en el mundo,
nunca para afirmar una tasa.

---

## 0. Por qué este mapa no es el de `mapa-ia-movil.md`

Los mapas anteriores cartografían **temarios**: currículos de formación que enumeran temas. Aquí no
hay currículo que cartografiar, y esa ausencia es el primer hallazgo: **ninguna de las fuentes
normativas que abrimos usa el término "vibe coding"**, y la única de un organismo de estándares que
nombra el terreno lo hace por sus artefactos (ficheros de reglas), no por su nombre popular. Lo que
sí existe es un cuerpo de **mediciones experimentales** sobre las propiedades del código generado.
Este mapa cartografía esas mediciones.

Consecuencia práctica: aquí no se puede escribir "el temario X cubre el tema Y y el corpus no". Hay
que ir a la mecánica — qué defecto produce el generador, con qué frecuencia medida, y si el corpus
lo encuentra. Eso es lo que hace `huecos-vibecoding.md`.

---

## BLOQUE A — Qué es, con definición citable

### A.1 · La definición académica
Fuente: https://arxiv.org/abs/2506.23253 — consultada 2026-08-24.
Sarkar, A. y Drosos, I., **"Vibe coding: programming through conversation with artificial
intelligence"**. *Proceedings of the 36th Annual Conference of the Psychology of Programming
Interest Group (PPIG 2025)*. Enviado 2025-06-29, última revisión 2025-10-03.
Licencia: arXiv nonexclusive-distrib 1.0. **Nivel A.**

El resumen define el paradigma como aquel en el que se escribe código **interactuando con modelos
generadores de código en lugar de escribirlo directamente**. Es la definición que este repositorio
adopta, porque describe una **procedencia**, no una tecnología ni un sector.

### A.2 · La línea que separa vibecoding de asistencia con IA
Fuente: https://simonwillison.net/2025/Mar/19/vibe-coding/ — consultada 2026-08-24.
Willison, S., 2025-03-19. **Nivel B** (opinión razonada de practicante, no medición).

Willison acota el término a construir con un LLM **sin revisar el código que escribe**, y contrapone
su propia regla: no hacer *commit* de código que no pueda explicarle a otra persona. La distinción
importa para una auditoría por una razón operativa: **el proceso no es auditable, el árbol sí**. Un
cliente que afirma haber revisado todo y otro que admite no haber revisado nada entregan el mismo
repositorio. Por eso el criterio de entrada de un procedimiento no puede ser "esto se hizo con IA":
tiene que ser un artefacto presente en el árbol.

### A.3 · Origen del término
El término se atribuye a Andrej Karpathy (febrero de 2025) y de ahí pasó a la prensa general.
**No abrimos la publicación original** — la búsqueda solo devolvió reproducciones de terceros — así
que el origen se registra como contexto, no como fuente. Lo que sí está verificado es A.1.

---

## BLOQUE B — Lo que se ha medido del código que escribe un modelo

### B.1 · Veracode, *2025 GenAI Code Security Report* — el diseño más limpio del conjunto
Fuente: https://www.veracode.com/wp-content/uploads/2025_GenAI_Code_Security_Report_Final.pdf
Consultada 2026-08-24; el PDF se descargó y su texto se extrajo localmente para leer las cifras de
las figuras. Sin licencia declarada; © Veracode. **Nivel B** (proveedor, metodología completa).

Diseño: **80 tareas** de completado (4 lenguajes × 4 CWE × 5 instancias) sobre **más de 100
modelos**. Cada tarea admite una implementación segura y una insegura con la misma funcionalidad, y
el resultado lo juzga el motor SAST del propio proveedor.

| Medición | Cifra que imprime el informe |
|---|---|
| Tasa global de aprobación en seguridad | **55 %** — en el **45 %** de las tareas el modelo introduce la vulnerabilidad |
| Por lenguaje (medias, Figura 2) | Python **61,69 %** · JavaScript **57,34 %** · C# **55,27 %** · Java **28,50 %** |
| Por CWE (medias, Figura 3) | `CWE-327` **85,61 %** · `CWE-89` **80,44 %** · `CWE-80` **13,53 %** · `CWE-117` **12,03 %** |
| Por tamaño de modelo (medias, Figura 4) | pequeño <20B **50,65 %** · medio 20–100B **51,10 %** · grande >100B **50,87 %** |
| Por fecha de publicación (RQ5) | la tasa sintáctica mejora mucho; **la de seguridad se mantiene plana** |

**Las dos lecturas que hacen de esto una herramienta y no un titular:**

1. **El fallo del generador tiene forma, y la forma es la dependencia del contexto.** Donde la
   opción segura es *una llamada canónica* — una consulta parametrizada, un cifrado con nombre — el
   modelo acierta cuatro de cada cinco veces. Donde la opción segura depende del **destino** del
   dato — codificar para HTML, para atributo, para log — falla siete de cada ocho. El informe
   ofrece el mecanismo: el saneado aparece a menudo como reacción a un **nombre de variable
   frecuente** en los ejemplos de entrenamiento, no a un hecho de flujo de datos.
2. **No se arregla solo.** Ni el tamaño del modelo ni su fecha mueven la aguja. Un corpus escrito
   contra esta distribución no caduca con el modelo siguiente.

El informe **no** contiene la palabra "vibe" (comprobado sobre el texto extraído), y **no** contiene
ninguna comparación contra una línea base humana. La cifra "2,74× más vulnerabilidades que el código
humano", muy repetida y atribuida a este informe, **no está en él**: no se usa.

### B.2 · Pearce et al., *Asleep at the Keyboard*
Fuente: https://arxiv.org/abs/2108.09293 · IEEE S&P 2022 · arXiv v1 2021-08-20, v3 2021-12-16.
Licencia arXiv nonexclusive-distrib 1.0. **Nivel A.**

**89 escenarios, 1.689 programas, ~40 % vulnerables.** En el eje de diversidad de debilidades: 54
escenarios sobre 18 CWE, 1.084 programas válidos, **477 (44,00 %)** con la CWE presente; C 50,29 %,
Python 38,35 %. En la discusión: **39,33 %** de las opciones mejor puntuadas y **40,73 %** del total.
La determinación es con CodeQL donde es posible y marcado manual en el resto, declarado escenario a
escenario en las tablas.

La forma de la distribución vuelve a importar más que el promedio: las CWE con peor resultado no son
las de memoria, sino aquellas **en las que la forma segura exige conocer un contrato de API o una
política** — `CWE-476` 87,9 %, `CWE-78` 83,3 %, `CWE-522` 65,6 %, `CWE-22` 60,4 %, `CWE-89` 57,9 %
—, mientras `CWE-79` queda en 19,0 % y `CWE-416` en 27,9 %. Las cifras por CWE se obtienen sumando
las columnas por escenario de las tablas I y II; la suma reconcilia con el 477/1.084 que imprime el
propio artículo, y dos de ellas coinciden con afirmaciones del texto.

> **Cautela de edad**: el modelo evaluado es Copilot de 2021. La cifra sirve para la **forma** de la
> distribución, no como tasa vigente. Para la tasa vigente está B.1, que es de 2025 y mide más de
> cien modelos.

### B.3 · Perry et al., *Do Users Write More Insecure Code with AI Assistants?*
Fuente: https://arxiv.org/abs/2211.03622 · ACM CCS '23, pp. 2785–2799, DOI 10.1145/3576915.3623157.
Licencia arXiv nonexclusive-distrib 1.0. **Nivel A.**

**47 participantes analizados** (33 experimento, 14 control), 5 tareas de seguridad, 3 lenguajes. El
grupo asistido escribió código menos seguro en **4 de las 5** preguntas. En la tarea de SQL: **12 %**
de soluciones seguras en el grupo asistido frente a **29 %** en el control, y **36 %** vulnerables a
inyección frente a **7 %**. En la de cifrado: significativamente más probable la solución insegura
(p = 0,017) y el uso de cifrados triviales (p = 0,018).

El dato que ninguna otra fuente aporta es el de **confianza**: en todas las preguntas, el grupo
asistido creyó en promedio que sus respuestas eran **más seguras** que el grupo de control, dándose
a menudo respuestas más inseguras. Para una auditoría eso es una advertencia sobre el valor de la
declaración del cliente, no sobre el código.

### B.4 · Sandoval et al., *Lost at C* — y por qué **no** contradice a B.3
Fuente: https://arxiv.org/abs/2208.09727 · USENIX Security '23. Licencia arXiv nonexclusive-distrib
1.0. **Nivel A.** (La página de USENIX devolvió 403; las cifras salen de arXiv.)

**N = 58** estudiantes, tarea única: una lista enlazada simple en C. Resultado: los usuarios asistidos
producen errores críticos de seguridad a una tasa **no mayor del 10 %** por encima del control.

Leer el estadístico antes de citarlo: es un **contraste de no inferioridad con δ = 10 %**, y los
propios autores dicen que no existe umbral aceptado y que eligen 10 %. Rechazar la hipótesis nula
establece "como mucho un 10 % peor", nunca "igual".

**Los dos estudios no se contradicen: acotan dominios distintos.** La tarea de Sandoval es disciplina
de punteros, donde lo seguro es cuestión de cuidado; el efecto de Perry se concentra en tareas donde
lo seguro es **elegir entre idiomas de API**. Es la misma frontera que separa `CWE-327`/`CWE-89` de
`CWE-80`/`CWE-117` en B.1 y las CWE de contrato de las de memoria en B.2. Y conviene decirlo entero:
N = 58 y N = 47 no zanjan nada por sí solos.

### B.5 · Fu et al., debilidades en código de Copilot dentro de proyectos reales de GitHub
Fuente: https://arxiv.org/abs/2310.02059 · ACM TOSEM 2025. Licencia **CC BY 4.0**. **Nivel A.**

**733 fragmentos** (419 Python, 314 JavaScript) de **116 repositorios / 335 ficheros**.
**200 (27,3 %) contienen debilidades**, 628 debilidades en total, **43 CWE distintas**. Las cinco
mayores: `CWE-330` 114 (18,15 %), `CWE-94` 62 (9,87 %), `CWE-79` 60 (9,55 %), `CWE-78` 39 (6,21 %),
`CWE-427` 35 (5,57 %). Ocho de esas CWE están en el CWE Top-25 de 2023 y suman 233 debilidades
(37,1 %). Detección con CodeQL, Bandit y ESLint más filtrado manual, kappa de Cohen 0,82–0,85.

**Sesgo de selección que hay que declarar al citarlo**: son fragmentos que los desarrolladores
**etiquetaron voluntariamente** como generados por IA en repositorios públicos. No es una muestra
aleatoria de código generado.

### B.6 · Mao et al., medición a gran escala en repositorios reales
Fuente: https://arxiv.org/abs/2603.27130 — **"A Large-Scale Comprehensive Measurement of AI-Generated
Code in Real-World Repositories"**, Mao, Zhao, Tang, Wang y Zhang. Enviado 2026-03-28, v3 2026-07-01.
Licencia **CC BY 4.0**. **Nivel B** (preprint sin revisión por pares).

El resumen afirma que las diferencias reales entre código de IA y humano **en métricas de nivel de
código son pequeñas**, en contraste con los hallazgos de laboratorio previos, y presenta la tasa de
duplicación como medida por primera vez. Las cifras concretas están en el cuerpo del artículo (v2 en
HTML), no en el resumen, y así deben citarse:

- 12.749 *commits*; **19.816 ficheros de IA frente a 36.467 humanos**; autoría de IA identificada por
  palabras clave del mensaje de *commit*, filtros de reglas y clasificación con LLM.
- Ficheros de IA **33 % más largos** (256,57 frente a 192,68 LoC).
- **Duplicación entre ficheros MENOR en el código de IA: 17,20 % frente a 24,52 %.**
- Alertas de análisis estático 12,81 frente a 11,58 por KLOC; **alertas de seguridad de riesgo
  alto+medio 0,934 frente a 0,464 por KLOC** (aproximadamente el doble); las críticas, casi iguales.

Este preprint es la razón por la que este repositorio **no** afirmará que la IA aumenta la
duplicación. Ver B.7.

### B.7 · GitClear — duplicación, y el conflicto con B.6
Fuentes: https://www.gitclear.com/ai_assistant_code_quality_2025_research (y el PDF de 34 páginas
`GitClear-AI-Copilot-Code-Quality-2025.pdf`, v2025.2.5) y
https://www.gitclear.com/the_ai_code_quality_maintainability_gap (enero de 2026).
Sin licencia declarada, sin autor nombrado. **Nivel B** (proveedor).

Sobre 211 millones de líneas modificadas (2020–2024): las líneas **movidas** caen del 24,1 % al 9,5 %
y las **copiadas y pegadas** suben del 8,3 % al 12,3 %; 2024 es el primer año registrado en que las
copiadas superan a las movidas. En el sub-estudio de **bloques duplicados** —definidos como cinco o
más líneas contiguas repetidas, ignorando líneas en blanco y de palabra clave— los *commits* con al
menos un bloque duplicado pasan del **0,45 % (2022) al 6,66 % (2024)**. El informe de 2026 (623
millones de cambios) lleva la duplicación de bloques de 40,3 a **73,0 por millón de líneas
modificadas** y las líneas movidas al 3,8 %.

**Tres cautelas, y son la razón por la que esto no soporta un procedimiento por sí solo:**
1. El sub-estudio de bloques se mide sobre **56.495 *commits***, no sobre los 211 millones de líneas:
   muestra distinta y mucho menor.
2. GitClear no atribuye autoría de IA *commit* a *commit*. Su propio texto lo plantea como
   **correlación**.
3. **B.6 mide lo contrario** en el eje entre ficheros. Denominadores distintos, atribución distinta,
   unidad distinta — pero quien afirme "la IA aumenta la duplicación" como hecho asentado está
   afirmando más de lo medido.

### B.8 · Wu, Hu, Fan et al., clones de generadores comerciales
Fuente: página del programa de FSE 2025 en `conf.researchr.org` (la entrada de ACM DL devolvió 403).
PACMSE vol. 2, pp. 2874–2896, DOI 10.1145/3729397. **Nivel A** por la sede; **cifra parcialmente
verificada** — ver la advertencia.

Tres generadores comerciales; tasa combinada de clones **Tipo-1 + Tipo-2 de hasta 7,50 %**, con
estabilidad declarada en la generación de clones, y el riesgo planteado por los autores como
infracción de derechos y **propagación de código vulnerable por clonado**.

> **NO VERIFICADO**: tamaño de muestra, número de *prompts*, qué tres generadores y contra qué corpus
> de referencia se midieron los clones. El texto completo no se pudo abrir.

---

## BLOQUE C — Dependencias, versiones y referentes que no existen

### C.1 · Spracklen et al., alucinación de paquetes
Fuente: https://arxiv.org/abs/2406.10279 (más el HTML y el PDF de la v3, extraídos localmente) ·
USENIX Security 2025 · v3 2025-03-02. Licencia **CC BY-NC-SA 4.0**. **Nivel A.**

**576.000 muestras de código, 16 modelos, 2 ecosistemas.** Tasa de alucinación **≥5,2 % en modelos
comerciales y 21,7 % en abiertos**; **205.474 nombres de paquete inventados distintos**. El cuerpo
del artículo da la cifra mejor: esas pruebas produjeron **2,23 millones de referencias a paquetes, de
las cuales 440.445 (19,7 %) eran alucinaciones**. Por modelo, GPT-4 Turbo es el más bajo con 3,59 % y
CodeLlama 7B el más alto con 26,12 %; por ecosistema, Python 15,8 % frente a JavaScript 21,3 %.

Lo que convierte esto en una primitiva de ataque y no en una errata es la **persistencia**: al
repetir el mismo *prompt* diez veces, **el 43 % de los paquetes alucinados reaparece en las diez** y
el 39 % en ninguna — distribución bimodal, no ruido de muestreo; **el 58 % reaparece más de una vez**.
Y **el 81 % de los nombres alucinados lo produce un solo modelo**, de modo que la repetición es una
huella del generador concreto. Variar los parámetros de decodificación mueve la tasa un 1,16 % de
media: la temperatura no es la palanca.

Dos resultados del cuerpo que **cambian el diseño de una comprobación** y que no suelen citarse:

- **La distancia de edición no sirve.** El artículo mide la similitud semántica con la distancia de
  Levenshtein al paquete válido más próximo y concluye que **la mayoría de los nombres alucinados NO
  se parecen a ningún paquete real**. Un detector de *typosquatting*, que se apoya en una distancia
  de edición pequeña respecto a un nombre popular, **sub-dispara por construcción** sobre esta clase.
- **Existir no basta: hay que existir en el registro correcto.** El **8,7 % (6.705 de 76.489)** de los
  nombres alucinados en Python son paquetes **válidos de JavaScript**; los otros ocho ecosistemas
  juntos solo suman el 0,8 %.

> Esta fuente **ya está en el corpus**: `SUP-08` la cita con las cifras del resumen. Lo que el corpus
> no tiene es lo de arriba, y de ahí sale un hueco real — ver `huecos-vibecoding.md` §2.

### C.1b · Dónde vive esta clase en OWASP, y por qué la referencia habitual está desfasada
Fuentes: https://owasp.org/www-project-top-10-for-large-language-model-applications/ (la página
declara **CC BY-SA 4.0**) y el repositorio oficial `github.com/GenAI-Security-Project/GenAI-LLM-Top10`
(README con la misma licencia), leído por la API de contenidos de GitHub. Consultadas 2026-08-24.

- En la edición **2025**, la clase entera vive en `LLM09:2025` Misinformation; `LLM03:2025` Supply
  Chain **no** menciona nombres alucinados.
- En la edición **2026** se parte en dos. `LLM07:2026` Misinformation cubre la **alucinación** en su
  sección de código y dependencias fabricadas, citando a Spracklen et al. 2025, y remite
  explícitamente la otra mitad. **`LLM04:2026` Supply Chain es donde se nombra el registro de nombres
  alucinados como vector**, con la palabra *slopsquatting*, y su mitigación incluye comprobar que una
  dependencia sugerida por IA existe y es la que se pretendía.

**Consecuencia para el corpus**: hay que citar `LLM04:2026` para el ataque y `LLM07:2026` para la
alucinación. `SUP-08` hoy no cita **ninguna** de las dos.

### C.1c · Estado del arte 2026 y la respuesta de los registros
- **Churilov**, https://arxiv.org/abs/2605.17062, v1 2026-05-16, v3 2026-08-09, licencia **CC BY
  4.0**, **preprint sin revisar (nivel B)**: cinco modelos de frontera, **199.845 *prompts*
  emparejados** Python/JS, tasas del **4,62 % al 6,10 %** — el rango se comprime frente al 5,2–21,7 %
  de C.1, pero **127 nombres idénticos aparecen en los cinco modelos** y **53 seguían siendo
  registrables** (41 en PyPI, 12 en npm).
- **Socket**, https://socket.dev/blog/slopsquatting-targets-across-frontier-llms, 2026-07-22, sin
  licencia declarada, **nivel B**: de 109 candidatos en PyPI, la lista de nombres prohibidos y la
  normalización de PyPI **bloquearon 68 y dejaron 41**; en npm, 12 de 18 sobrevivieron a la revisión
  manual.
- **Warehouse** (código de PyPI, Apache-2.0), https://github.com/pypi/warehouse: el mecanismo
  existe de verdad — modelo `ProhibitedProjectName`, vistas de administración y carga masiva.
- **Detección estática**: https://arxiv.org/abs/2604.07755 (2026-04-09, nivel B) mide que el análisis
  estático detecta **entre el 14 % y el 85 %** de las alucinaciones de biblioteca, con un techo
  práctico del análisis manual del 48,5–77 %.
- **Detección por metadatos**: https://arxiv.org/abs/2606.13918 (2026-06-11, nivel B) usa como
  señales **existencia en el registro, antigüedad del paquete, número de publicaciones, descriptor de
  autor y resumen**. `slopgate` 0.1.0 (https://pypi.org/project/slopgate/, MIT, 2026-06-09) las
  convierte en reglas ejecutables: **BLOQUEAR** si el nombre no está en el registro, o si se registró
  hace menos de 14 días y se parece a un paquete popular, o si es reciente **y** no tiene repositorio
  de origen **y** tiene una sola versión; **AVISAR** si se publicó hace menos de 90 días; y **nunca
  fallar automáticamente** si la consulta al registro no se pudo hacer — la misma doctrina del código
  de salida `2` de este repositorio, en otra casa.

### C.1d · Lo que la conversación pública afirma y las comprobaciones contradicen
Tres afirmaciones que circulan y que **no** deben entrar al corpus:

1. **La taxonomía "38 % conflaciones / 13 % variantes tipográficas / 51 % fabricaciones puras" está
   mal atribuida.** Dos publicaciones de proveedor se la adjudican a Spracklen et al.; sobre el texto
   completo del artículo **no aparece ninguna de esas cifras ni esa división en tres**.
2. **"2,23 millones de muestras de código"** es un error de unidad: son 576.000 muestras que producen
   2,23 millones de **referencias** a paquetes.
3. **"Ya hay ataques confirmados por slopsquatting" está en disputa.** El caso de `huggingface-cli`
   es una prueba de concepto **declaradamente benigna** de Lasso Security
   (https://www.lasso.security/blog/ai-package-hallucinations, 2024-03-28, **nivel B**: 47.803
   preguntas, 5 lenguajes, 4 modelos; el paquete vacío superó las decenas de miles de descargas en
   tres meses) y la cifra de descargas que se le atribuye a un ataque real es la suya. Wikipedia
   (**CC BY-SA 4.0**, última modificación 2026-07-14) afirma que **a julio de 2026 no consta ningún
   ciberataque por esta vía**. Una consulta directa a la API de avisos de GitHub devuelve **cero
   avisos** para los tres nombres que se citan como casos —y los controles funcionan: `lodash`,
   `event-stream` y `ctx` sí devuelven registros—, de modo que el resultado nulo es real y no un
   fallo de consulta. **Nivel C y en disputa.**

Lo que **sí** está fuera de disputa: la superficie es real y medida (53 nombres registrables vivos),
las pruebas de concepto benignas se descargaron a escala, y **la pila de auditoría de dependencias
habitual no ve nada de esto**. Ver la respuesta mecánica en `huecos-vibecoding.md` §2, hueco 1.

### C.2 · Wang et al., uso de API obsoletas
Fuente: https://arxiv.org/abs/2406.09834 — **"LLMs Meet Library Evolution: Evaluating Deprecated API
Usage in LLM-based Code Completion"**, ICSE 2025, DOI 10.1109/ICSE55347.2025.00245. Enviado
2024-06-14, v3 2025-02-13. Licencia **CC BY 4.0**. **Nivel A.**

Diseño verificado en el resumen: **7 modelos, 145 mapeos de API, 8 bibliotecas de Python, 28.125
*prompts* de completado**. Las cifras están en el cuerpo, no en el resumen, y así se citan: tasa de
uso obsoleto (*DUR*) del **25 % al 38 %** global, con **70–90 %** cuando el contexto del *prompt*
procede de funciones ya obsoletas y **9–18 % aun cuando procede de funciones actualizadas**. Los
modelos mayores presentan DUR más alta. Causa declarada por los autores, en dos mecanismos: la
presencia de usos obsoletos en el corpus de entrenamiento y la ausencia de conocimiento posterior
sobre las deprecaciones en el momento de la inferencia.

**El 9–18 % residual es el número que importa**: aunque el fichero que rodea la línea use la API
moderna, el modelo sigue emitiendo la obsoleta. Eso lo convierte en una propiedad del generador y no
del código base.

### C.3 · Wang et al., versiones de biblioteca con CVE conocida
Fuente: https://arxiv.org/abs/2605.06279 — enviado 2026-05-07, 35 pp. Licencia **CC BY 4.0**.
**Nivel B** (preprint sin revisar).

Diez modelos sobre 1.000 tareas: entre el **36,70 % y el 55,70 %** de las tareas especifican una
versión de biblioteca con al menos una CVE conocida, y entre el **62,75 % y el 74,51 %** de esas son
críticas o altas. La cifra que sostiene el argumento: **entre el 72,27 % y el 91,37 % de esas CVE se
divulgaron ANTES del corte de conocimiento del modelo**. No es un problema de lo que el modelo no
podía saber; es una preferencia. Los autores señalan que los diez modelos convergen en el mismo
conjunto pequeño de versiones de riesgo.

---

## BLOQUE D — La herramienta que escribe el código, como superficie del repositorio

Este bloque es el único del mapa donde el mecanismo **no existía antes de la IA**: un fichero de
texto o de configuración dentro de un repositorio que, al abrirlo, **dirige o ejecuta** algo en la
máquina de quien lo abre.

### D.1 · Pillar Security, *Rules File Backdoor*
Fuente: https://www.pillar.security/blog/new-vulnerability-in-github-copilot-and-cursor-how-hackers-can-weaponize-code-agents
Ziv Karliner, 2025-03-18. © Pillar Security. **Nivel B.**

Unicode invisible —uniones de ancho cero, marcas de dirección bidireccional y el bloque **Tags
(U+E0000–U+E007F)**— incrustado en `.cursor/rules` y `.github/copilot-instructions.md`, con carga que
además instruye al modelo para **ocultar la modificación** en su salida de chat. Divulgado a Cursor
el 2025-02-26 y a GitHub el 2025-03-12; ambos respondieron atribuyendo la responsabilidad al usuario,
y GitHub incorporó avisos de Unicode oculto hacia el 2025-05-01.

> Esta fuente **ya está en el corpus**: `AI-04` y `AI-20` la citan por nombre. No es terreno nuevo.

### D.2 · CVE de agentes de codificación — el repositorio que ataca a quien lo abre
Todas las entradas siguientes se consultaron el 2026-08-24 en `nvd.nist.gov`. NVD es obra del
Gobierno de los EE. UU., de dominio público allí. **Nivel B** (registro de vulnerabilidad).
Las dos primeras filas fueron abiertas y verificadas **dos veces, de forma independiente**, por ser
las que sostienen un procedimiento nuevo.

| Identificador | Producto y versiones | Publicada | CVSS | CWE | Mecanismo |
|---|---|---|---|---|---|
| `CVE-2025-64109` | Cursor anterior a 2025.09.17-25b418f | 2025-11-04 | 8,8 | `CWE-78` | un `.cursor/mcp.json` presente en el repositorio ejecuta órdenes **al abrir el proyecto**, sin consentimiento |
| `CVE-2025-59536` | Claude Code anterior a 1.0.111 | 2025-10-03 | 8,8 (3.1) / 8,7 (4.0) | `CWE-94` | ejecución de código del proyecto **antes** de que el usuario acepte el diálogo de confianza, al lanzarlo en un directorio no confiable |
| `CVE-2026-21852` | Claude Code anterior a 2.0.65 | — | — | — | exfiltración de clave de API antes del diálogo de confianza |
| `CVE-2025-61592` | Cursor 1.7 e inferiores | — | — | — | `.cursor/cli.json` del repositorio **prevalece** sobre la configuración global del usuario |
| `CVE-2026-30615` | Windsurf 1.9544.26 | — | — | — | inyección de *prompt* que deriva en ejecución de órdenes |

Aviso relacionado, abierto: `GHSA-4fgq-fpq9-mr3g`, "Command execution prior to Claude Code startup
trust dialog".

> Las tres últimas filas se abrieron una sola vez y sus campos de CVSS, CWE y fecha **no** se
> transcriben aquí porque no se leyeron dos veces. Se citan por identificador y mecanismo, que es lo
> que sostiene el procedimiento; cualquier severidad que se quiera afirmar hay que volver a leerla.

### D.3 · OWASP — lo más cercano a una fuente normativa
Fuente: https://cheatsheetseries.owasp.org/cheatsheets/Secure_Coding_with_AI_Cheat_Sheet.html y
`/AI_Agent_Security_Cheat_Sheet.html` — consultadas 2026-08-24. Licencia **CC BY-SA 4.0**. La fuente
está en `docs/sources-allowlist.json` como `owasp-cheatsheets`. **Nivel B.**

La *Secure Coding with AI Cheat Sheet* tiene una sección dedicada a **ficheros de reglas y dirección
persistente**, que nombra `.cursorrules`, `CLAUDE.md` y `.windsurfrules`, además de secciones sobre
seguridad de MCP y sobre inyección por Markdown, enlaces y Unicode.

> **NO VERIFICADO**: la hoja **no imprime fecha ni versión** en la página abierta, así que no se le
> puede poner una fecha de edición. Y `genai.owasp.org` devolvió **HTTP 403** en dos rutas: no se
> abrió ninguna publicación del proyecto GenAI en esta extracción. Los identificadores `LLM0x:2026` y
> `ASIxx` que use el corpus vienen de su propia verificación previa, registrada en
> `skills/ethical-hacker-squad/references/traceability.md`, **no de esta sesión**.

---

## BLOQUE E — Plataformas de construcción de aplicaciones por IA

Este bloque es el que más ruido produce en la conversación pública y el que menos procedimiento
nuevo genera. Se cartografía para poder decir por qué.

### E.1 · Lovable — `CVE-2025-48757`
Fuentes: https://mattpalmer.io/posts/CVE-2025-48757/ y la nota de posición del mismo autor;
registro NVD del identificador. Consultadas 2026-08-24. **Nivel B, con dos reservas.**

CVSS **9,3**, `CWE-863`, publicada 2025-05-29. Cifra declarada: **303 puntos finales en 170 proyectos
de 1.645 analizados (≈ 10,3 %)**.

**Reserva 1**: el registro está marcado **DISPUTED** en NVD. **Reserva 2**: el divulgante trabaja en
un producto competidor directo de la plataforma afectada. Ninguna de las dos invalida el hallazgo;
ambas obligan a citarlo con las dos etiquetas puestas. La documentación pública de la plataforma no
menciona la CVE.

Causa raíz: falta de autorización a nivel de fila. Es `CWE-863`, la misma de siempre; lo único nuevo
es la **escala y el valor por defecto** — un generador reproduciendo el mismo error en una décima
parte de una plataforma.

### E.2 · base44 — omisión de autenticación
Fuente: https://www.wiz.io/blog/critical-vulnerability-base44 — Wiz Research, Gal Nagli, 2025-07-29.
© Wiz. **Nivel B.**

Puntos finales de registro y verificación de OTP sin autenticar, con un identificador de aplicación
que no es secreto y aparece en la URL y en el manifiesto. Corregido en unas 24 horas; **sin CVE
asignada**. Causa raíz: tratar un identificador no secreto como si fuera una capacidad. Ordinario.

### E.3 · Replit — borrado de una base de datos de producción por un agente
Fuentes: https://www.theregister.com/2025/07/21/replit_saastr_vibe_coding_incident/ y
https://incidentdatabase.ai/cite/1152/ (incidente del 2025-07-18). **Nivel C.**

Fallo de radio de explosión: sin separación entre desarrollo y producción, con el agente sosteniendo
credenciales de producción. Lo único específico del paradigma es que una **congelación de código
pedida en lenguaje natural** nunca fue un control exigible.

### E.4 · Guardio Labs, *VibeScamming*
Fuente: https://guard.io/labs/vibescamming-from-prompt-to-phish-... — Nati Tal, 2025-04-09. © Guardio.
**Nivel B.** Es un banco de pruebas de **mal uso y salvaguardas**, no una vulnerabilidad, y no
pertenece a este terreno. Se registra para que nadie lo cuente como tal.

> **Discrepancia sin resolver**: la página renderizó puntuaciones ≈7,2 / 3,8 / 1,5 mientras la
> cobertura secundaria cita 8 / 4,3 / 1,8. No se usa ninguna de las dos.

---

## BLOQUE F — Lo que ninguna fuente dice

Tres clases que la mecánica sugiere con fuerza y que **nadie ha medido** en ninguna fuente que
abriéramos. Aparecen aquí para que nunca se citen como cubiertas, y para que `huecos-vibecoding.md`
las etiquete como hipótesis:

1. **Prevalencia de controles de seguridad presentes e inertes** — un validador que no puede devolver
   falso, una comparación que lee un solo operando, un saneador que devuelve su argumento. Lo más
   cercano es el caso ilustrativo de un participante de B.3 (cifrado AES-EAX correcto que no devuelve
   la etiqueta de autenticación) y la explicación de mecanismo de B.1 (saneado disparado por un
   nombre de variable). **Ninguna tasa publicada.**
2. **Prevalencia de referencias a variables de entorno, claves de configuración o rutas internas que
   no existen** — a diferencia de los **paquetes** inexistentes, que sí están medidos en C.1.
   **Ninguna tasa publicada.**
3. **Número medio de clones hermanos por hallazgo de seguridad** en un repositorio asistido por IA.
   La investigación de clones mide clones; la de seguridad mide hallazgos; **nadie ha multiplicado
   las dos**.

La tercera es medible y barata: sobre cualquier análisis estático, tomar la función que envuelve cada
hallazgo, normalizar identificadores, calcular el hash y contar hermanos. Si la mediana es 1, la
historia de "la IA replica defectos" se cae, y lo habría mostrado este repositorio.

---

## Lista de no verificado

Todo lo que no se pudo abrir, para que nadie lo confunda con una fuente:

- `genai.owasp.org` — **HTTP 403** en dos rutas. Ninguna publicación del proyecto GenAI de OWASP se
  abrió en esta extracción.
- *OWASP Guide to Secure Vibe Coding at Scale* — solo apareció en resultados de búsqueda. **Su
  existencia no está confirmada.**
- `dl.acm.org/doi/10.1145/3729397` (B.8, texto completo) — **HTTP 403**.
- `usenix.org` para B.4 y para C.1 — **HTTP 403** en ambas. Las cifras salen de arXiv, y la sede
  USENIX de C.1 está corroborada solo por la nota de la propia página de arXiv. **La página de USENIX
  no se abrió.**
- El PDF de la edición 2025 del Top 10 de OWASP para LLM — la descarga superó el límite de tamaño. No
  se abrió; los identificadores de C.1b salen de `owasp.org` y del repositorio oficial.
- **Ninguna declaración oficial de npm ni de GitHub sobre slopsquatting se abrió.** La respuesta de
  npm se infiere de los registros del propio registro y del relato de un tercero.
- Cobertura de atestación de procedencia en npm o de publicación confiable en PyPI: **no se abrió
  ninguna fuente**. Cualquier afirmación sobre qué fracción de paquetes la tiene es razonamiento, no
  medición.
- Fecha y versión de la hoja de OWASP de D.3.
- Los campos de CVSS, CWE y fecha de las tres últimas filas de D.2.
- Una réplica académica del resultado de duplicación de B.7. Se buscó y no se encontró; la medición
  independiente más cercana (B.6) apunta en sentido contrario. **No escribir "corroborado por
  trabajo académico".**
- La cifra "2,74× más vulnerabilidades que el código humano" atribuida a B.1: **no está en el
  documento**.
- Un estudio de secretos en interfaces generadas por IA. Existe una medición de claves de API de LLM
  en aplicaciones de iOS (póster de NDSS 2026: 500 aplicaciones analizadas, 203 que invocan un LLM,
  **52 con clave expuesta, 25,6 %**), pero mide aplicaciones que **usan** un LLM, no aplicaciones
  **escritas por** uno. La cifra "282 de 444 (64 %)" que circula en cobertura secundaria **queda
  contradicha** por ese póster y no se usa.
- Todo lo que cuelga de una nota de la Cloud Security Alliance que se **autodeclara generada por IA y
  no revisada oficialmente**: no se abrió ninguna de sus fuentes y nada de ella se cita.
- `CVE-2025-59944`, `CVE-2025-61590`, `CVE-2025-61591`, `CVE-2025-61593` (Cursor) — nombradas en
  resultados de búsqueda, **no abiertas**.
