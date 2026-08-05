# Manual de la maquinaria

Este documento describe **la maquinaria**, no el producto. Para qué hace el plugin,
lee el `README.md` de la raíz. Aquí se explica qué corre solo, qué lo frena, cómo se
promociona una versión, **cómo se apaga todo** y **cómo se revierte**.

Regla que ordena todo lo demás: este repositorio distribuye **instrucciones que Claude
Code ejecuta en la máquina de otras personas**, y parte del contenido nace de un bot
que lee internet. Es decir, el pipeline es un canal de **inyección indirecta de
prompts**. Todo lo que sigue está escrito para que un texto escrito por un
desconocido no llegue nunca a ejecutarse con permisos.

---

## 1. Los códigos de salida (la doctrina)

Todo gate y todo script de este repo distingue tres resultados:

| Código | Significa | Consecuencia |
|---|---|---|
| `0` | **Medí** y está bien | Verde |
| `1` | **Medí** y FALLA | Rojo |
| `2` | **NO PUDE MEDIR** (falta herramienta, falta entrada, fichero ilegible) | Rojo, y se reporta **aparte** |

Un `rc=0` nunca puede significar «no lo revisé». Por eso el `2` existe y por eso
rompe la build igual que el `1`: si una comprobación no llegó a hacerse, el resultado
honesto no es un aprobado. Cada gate además imprime **qué revisó y qué no**.

---

## 2. Los seis workflows

| Workflow | Cuándo corre | Qué hace | Permisos |
|---|---|---|---|
| `ci.yml` | `push` y `pull_request` a `main`/`stable` | Corre **todos** los gates. Job `gates` (sin herramientas externas) y job `workflow-hardening` (zizmor + actionlint) | `contents: read` por job |
| `issue-closure-gate.yml` | `pull_request` | Exige que cerrar un falso positivo/negativo venga con la regresión que lo vigila | `contents: read`, `issues: read` |
| `labels-drift.yml` | `schedule` lunes, `push` a `main`, manual | Compara la taxonomía declarada contra los labels que existen **en GitHub** | `contents: read` |
| `release.yml` | `schedule` lunes 06:17 UTC, manual | **La promoción a `stable`**. Ver §4 | `contents: write` solo en `promote` |
| `scorecard.yml` | `push` a `main`, `schedule` sábados | OpenSSF Scorecard. **Mide, no bloquea** | `security-events: write`, `id-token: write` |
| `supply-chain-audit.yml` | `schedule` martes, `push` a `main`, manual | Auditorías de zizmor que necesitan red y token (impostor-commit, known-vulnerable-actions, stale-action-refs) | `contents: read` |

### Por qué están repartidos así y no juntos

- **`ci.yml` no lleva token.** Analiza el contenido de un PR, que desde un fork es
  contenido de un tercero. La regla dura «ningún job que procese contenido no
  confiable recibe secretos» prohíbe darle uno.
- **`supply-chain-audit.yml` existe porque fijar las acciones por SHA apaga las
  alertas de Dependabot** (GitHub solo alerta de acciones con versionado semántico).
  Esas auditorías necesitan token, así que viven en un workflow que **no se dispara
  con `pull_request`** y por tanto no es alcanzable desde un fork.
- **`scorecard.yml` no es una puerta.** La acción oficial no tiene input de umbral y
  nunca falla el job por puntaje bajo; además el agregado puede *bajar* por hacer las
  cosas bien (un check pasa de `?` a puntuable). Gatear sobre él sería rojo eterno o
  un umbral que no mide nada.

### Disparadores prohibidos, en todos

Ningún workflow usa `pull_request_target`, `issues`, `issue_comment`, `discussion`,
`workflow_run` ni `repository_dispatch`. Son las vías por las que texto escrito por un
desconocido entra en un contexto privilegiado. `scripts/gh/tests/validate-workflow.py`
lo comprueba y `scripts/gh/tests/test-workflow-mutations.py` comprueba que ese
validador **falla de verdad** cuando se le inyecta cada uno.

---

## 3. Los gates

Viven en `scripts/gates/`. Los descubre y agrega `scripts/gates/run-all.sh`.

| Gate | Qué mide | Qué NO mide |
|---|---|---|
| `gate-workflow-hardening.sh` | Disparadores permitidos, `permissions: {}` en la raíz y mínimos por job, pin por SHA de 40 chars con comentario de versión, lectura del contexto `secrets` en workflows alcanzables desde forks | Inyección de plantillas en `run:`, sintaxis YAML/cron — eso es el siguiente |
| `gate-actions-lint.sh` | zizmor + actionlint (+ shellcheck sobre los `run:`) | Devuelve `2` si falta shellcheck: sin él, los bloques `run:` no se analizan |
| `gate-plugin-integrity.sh` | Forma del árbol servido (`skills/`, `agents/`, …): symlinks, extensiones, bit de ejecución, presupuestos de tamaño, enlaces rotos, lista blanca del frontmatter | El **contenido semántico** de los `.md`. Acota forma, no juzga texto |
| `gate-plugin-version.sh` | Que `latest` OMITA `version` y `stable` la declare; que no esté declarada dos veces; `claude plugin validate --strict` | — |
| `gate-labels-taxonomy.sh` | Que los issue forms solo apliquen labels que la taxonomía declara, y que los labels que consumen `gate-issue-closure.sh` y `governance.json` **existan** | Si esos labels existen **en GitHub**: eso es `labels.sh --check` |
| `gate-issue-closure.sh` | Que cerrar un `type/false-positive` o `type/false-negative` toque un gate, un test o el corpus | Que el fichero tocado contenga **de verdad** el caso. Lo imprime como AVISO |

### Cómo se descubren (y por qué importa)

`run-all.sh` descubre **recursivamente y sin filtrar por extensión**. Un descubridor
que solo mire `gate-*.sh` a un nivel convierte en invisible cualquier gate escrito en
Python y cualquier gate en una subcarpeta — y eso ya pasó: un gate `.py` que fallaba
junto a un `.sh` verde daba `rc=0`. Además:

- La lista viaja por el **FD 3**, no por stdin, y cada gate se lanza con `</dev/null`.
  Con la lista en stdin, el primer gate que lea stdin (`cat`, `read`, `jq` sin fichero,
  `xargs`) se traga el resto y el bucle termina antes de tiempo **declarando verde lo
  que jamás ejecutó**.
- Contabilidad explícita `descubiertos == ejecutados + declarados`. Si no cuadra, `2`.
- Lo que no se sabe lanzar es `2`, nunca un aprobado por omisión.
- **Nada se salta en silencio.** `gate-issue-closure.sh` necesita un PR delante, así
  que fuera de ese contexto se declara como *no ejecutado aquí* (lo corre
  `issue-closure-gate.yml`, y `run-all.sh --pr-context` también). Un gate nuevo que no
  esté declarado ni sea ejecutable hace que `run-all.sh` devuelva `2`: no se puede
  añadir un gate y que no lo corra nadie sin enterarse.

```bash
scripts/gates/run-all.sh              # los gates que no necesitan PR
scripts/gates/run-all.sh --pr-context # además, los que sí
scripts/gates/run-all.sh --list       # inventario
scripts/gates/run-all.sh --selftests  # las autopruebas de los gates
```

---

## 4. Cómo se promueve a `stable`

Dos canales, y **tienen que resolver a versiones distintas** o Claude Code los trata
como el mismo plugin y no actualiza:

| Canal | Rama | La versión resuelve a |
|---|---|---|
| `latest` | `main` | el **SHA** del commit (`plugin.json` **no** declara `version`) |
| `stable` | `stable` | el **semver** que la promoción escribe en `plugin.json` |

El usuario elige el canal al añadir el marketplace:

```
/plugin marketplace add CristianAjavi/ethical-hacker-squad          -> latest
/plugin marketplace add CristianAjavi/ethical-hacker-squad@stable   -> stable
```

### La secuencia (`release.yml`, tres jobs)

1. **`resolve`** (solo lectura). Lee el contrato de `scripts/gh/governance.json`,
   elige el commit candidato y calcula la versión.
2. **`verify`** (solo lectura, sin token). Corre **todos** los gates sobre el árbol
   candidato.
3. **`promote`** (`contents: write`, el único). Construye el árbol de `stable`,
   pasa los gates de identidad y empuja la rama y el tag.

### Lo que tiene que cumplirse para que algo llegue a `stable`

- **Reposo real.** El candidato es el commit más reciente de la cadena `--first-parent`
  de `main` que ya cumplió `cooldown_days`. `--first-parent` no es cosmético: `git
  rev-list --before` filtra por **fecha de commit**, y esa fecha la elige quien escribe
  el commit (`GIT_COMMITTER_DATE`). Sin `--first-parent`, un PR del loop con un commit
  retrofechado a 8 días y mergeado hoy se promovía con **cero días de reposo real**, y
  encima ese árbol solo vivió dentro de la rama del PR: nunca fue un estado de `main`.
  Hay además una **invariante dura de pertenencia** a esa cadena, que se aplica también
  al disparo manual.
- **Ningún issue abierto con `channel/stable-blocked`.** El bloqueo es
  **determinista**: se **cuentan** issues con esa etiqueta. Nunca se lee el título ni
  el cuerpo de ninguna.
- **Todos los gates en verde sobre el árbol candidato.** Un gate en `2` bloquea igual
  que un `1`: promover sobre una verificación incompleta es publicar a ciegas.
- **Los gates que juzgan vienen de `main`, no del candidato.** El job hace dos
  checkouts (`tools/` = la punta de `main`, `source/` = el candidato), reemplaza
  `source/scripts/gates` por el de `tools/` y comprueba con `cmp` que la copia es
  byte a byte la de `main`. Si el candidato pudiera aportar sus propios gates, se
  estaría auto-aprobando.
- **La versión tiene que subir.** Si `plugin.json` no se bumpea, los usuarios no
  reciben nada aunque `stable` se mueva.
- **El árbol de `stable` es el de `main`.** Un gate hace `git diff` entre el candidato
  y el árbol construido excluyendo solo `plugin.json` y `CHANGELOG.md`; y dentro de
  `plugin.json`, la única diferencia permitida es `version`. Es el gate que sostiene
  el modelo entero: prueba que la promoción no introdujo **nada** que no haya pasado
  por `main`.
- **`stable` no se movió mientras se verificaba** (guardia TOCTOU): se compara el
  trailer `Source-Commit:` visto al principio con el de ahora, justo antes del push.
- **El push es fast-forward, sin `--force`.** El commit de `stable` se cuelga con
  `git commit-tree` del **`stable` anterior**, no del candidato de `main`. Si colgara
  del candidato, el segundo release no descendería del primero y el push se rechazaría
  por non-fast-forward: la promoción funcionaría **exactamente una vez**.

### El contrato vive en un solo sitio

`scripts/gh/governance.json`, bloque `promotion`: `cooldown_days`, `stable_branch`,
`source_branch`, `tag_prefix`, `blocking_issue_labels`, `required_contexts`,
`gates_dir`. `release.yml` lo **lee** (no duplica los valores) y falla cerrado si
alguno está vacío o es absurdo. Duplicarlos era como divergían: el fichero decía
`BLOCK_LABEL: channel-stable-block` mientras la taxonomía declaraba
`channel/stable-blocked`, y **GitHub ignora en silencio un label que no existe**, así
que el freno del canal era decoración y la consulta devolvía siempre cero.

---

## 5. Los labels

**Una sola autoridad**: `scripts/gh/labels.sh`. Los issue forms, `gate-issue-closure.sh`
y `governance.json` solo **referencian** nombres de esa lista, y
`gate-labels-taxonomy.sh` falla si alguno no existe.

```bash
scripts/gh/labels.sh --check     # gate: ¿coincide GitHub con la taxonomía?
scripts/gh/labels.sh --dry-run   # qué haría
scripts/gh/labels.sh --apply     # aplicarlo (requiere permiso de escritura)
```

`apply-governance.sh` **no** gestiona labels: delega en este script y pliega su `rc`.
Antes había dos listas y dos scripts creando labels en el mismo repo, cada uno viendo
los del otro como «no declarados».

---

## 6. Cómo se apaga todo (kill switch)

**Desactiva los workflows programados.** Nada más hace falta: todo camino automático
corre con `schedule` o `workflow_dispatch`.

```bash
gh workflow disable release.yml
gh workflow disable labels-drift.yml
gh workflow disable supply-chain-audit.yml
gh workflow disable scorecard.yml
```

Con eso, `latest` se congela en su commit actual y `stable` se queda donde está. `ci.yml`
y `issue-closure-gate.yml` pueden quedarse encendidos: solo miden, no publican.

**Congelar solo el canal `stable`, sin tocar nada más:** abre un issue con la etiqueta
`channel/stable-blocked`. La siguiente ejecución la lee de `governance.json` y no
promueve mientras siga abierto. Es la palanca reversible y sin permisos especiales.

**Parar una ejecución en curso:** `gh run cancel <run-id>`.

---

## 7. Cómo se revierte

### Un release malo en `stable`

Devuelve `stable` al commit del release anterior. El marketplace resolverá el semver
antiguo y los usuarios de `stable` vuelven al snapshot previo en su siguiente refresco;
los de `latest` no se enteran.

```bash
git fetch origin
git push --force-with-lease=stable:$(git rev-parse origin/stable) \
         origin <SHA-BUENO-ANTERIOR>:refs/heads/stable
```

- `--force-with-lease` y no `--force`: si alguien movió `stable` entre tu `fetch` y tu
  `push`, el comando se niega en vez de borrar su trabajo.
- El SHA bueno anterior sale de `git log --oneline origin/stable` o del tag del release
  previo: `git rev-list -n1 ethical-hacker-squad--vX.Y.Z`.
- **Lo tiene que correr una persona, no el workflow.** El `GITHUB_TOKEN` de Actions
  tiene `write` pero no es administrador, y `stable` está pensada con
  `allow_force_pushes=false`. Que un bot pudiera reescribir el canal que consumen los
  usuarios sería una puerta trasera, no una comodidad.
- **El tag no se borra.** Un tag publicado es un hecho histórico; si esa versión era
  mala, se saca una nueva, no se reescribe la vieja.

**Alternativa sin reescribir historia** (preferible si ya hay gente en esa versión):
revierte el contenido en `main`, sube la versión, y deja que la siguiente promoción
avance hacia delante.

### Un cambio malo en `latest`

`latest` es `main`. Se revierte con un `git revert` normal y un PR. No hay ventana de
reposo que proteja a `latest`: **ese es el trato del canal** — quien quiera reposo usa
`stable`, y quien quiera garantía total se ancla a un `sha`.

### Toda la integración

Esta rama es aditiva sobre `main`: solo añade `.github/**`, `scripts/gates/**` y
`scripts/gh/**`. Revertir es revertir el merge commit.

---

## 8. El banco de pruebas

Los gates también se prueban. `scripts/gh/tests/run-all.sh` corre 7 suites:

```bash
scripts/gh/tests/run-all.sh
```

Todas son herméticas: la API de GitHub y el binario `gh` se sustituyen por dobles y la
historia de git se fabrica con commits retrofechados. **Cero red**, salvo que exportes
`GOV_TESTS_NETWORK=1`.

Las suites son **negativas**: no preguntan «¿pasan los gates?» sino «¿puede este gate
decir verde sin haber mirado?». `test-workflow-mutations.py` rompe el workflow real de
17 formas distintas y exige que el validador devuelva `1` en las 17; si alguna deja de
detectarse, el validador no vale nada y la suite se pone roja.

---

## 9. Lo que esta maquinaria NO garantiza

Dicho en voz alta, porque fingir lo contrario sería peor que no tenerlo:

- **Un procedimiento verosímil, bien citado, bien formateado y simplemente
  equivocado llega a los usuarios.** Los gates acotan forma, no verdad. Esa clase de
  error se recoge por los issues `type/false-positive` y `type/false-negative`, y se
  cierra con la regresión que lo vigila. El sistema **converge por uso**, no garantiza
  corrección antes de publicar. Quien necesite garantía previa debe anclarse a un `sha`
  y revisarlo.
- **No hay protección de rama aplicada.** `scripts/gh/apply-governance.sh` la describe
  y la compara, pero mientras no se ejecute con `--apply`, los gates son **consultivos**:
  hay que marcarlos como *required checks* para que bloqueen un merge.
- **Los tags son anotados, no firmados.** Firmarlos exigiría darle una clave privada a
  un job automático, que es peor riesgo que la firma que aporta.
- **Ningún workflow se ha ejecutado nunca en GitHub.** Todo lo de arriba está medido en
  local. La primera ejecución de CI lo confirmará o lo desmentirá.
- **El loop de conocimiento no existe todavía.** No hay workflow del bot ni ramas
  `bot/knowledge-YYYY-WW`. Falta por tanto `gate-bot-diff-allowlist.sh`, el control que
  impedirá que un PR del bot toque `.github/**`, `scripts/**` o `.claude-plugin/**` —
  es decir, que edite a su propio juez y convierta una inyección indirecta en
  persistencia. **Debe entrar en el mismo cambio que el bot, no antes**: un gate sin
  sujeto no se puede probar.
- **`release.yml` no comprueba los check runs del candidato por API.** Confía en que
  los gates se re-ejecutan sobre el árbol (que es la evidencia más fuerte), pero no
  verifica que el CI **corriera en su momento** ni que lo reportara la app
  `github-actions` (id 15368). `governance.json` ya declara `required_contexts` para
  cuando se cablee.
