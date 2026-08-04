#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-plugin-version.sh — gate CRITICO de distribucion del plugin.
#
# QUE PROBLEMA IMPIDE
#   Claude Code resuelve la version de un plugin en este orden:
#     1) `version` en .claude-plugin/plugin.json
#     2) `version` en la entrada del marketplace
#     3) el SHA del commit del source
#   y "if the resolved version matches what a user already has, /plugin update
#   and auto-update skip the plugin".
#   Consecuencia: si plugin.json fija un `version` congelado, se pueden mergear
#   commits durante meses y NINGUN usuario instalado los recibe. El fallo es
#   SILENCIOSO: no hay error, no hay warning, simplemente no llega nada.
#   Fuente: https://code.claude.com/docs/en/plugin-marketplaces#version-resolution-and-release-channels
#
# DISENO DE CANALES QUE ESTE GATE HACE CUMPLIR
#   - canal `latest`  (rama main)   -> plugin.json OMITE `version`.
#                                      Cada commit = version nueva por SHA.
#   - canal `stable`  (rama stable) -> plugin.json DECLARA semver explicito.
#   - la entrada del marketplace NUNCA declara `version` (plugin.json gana en
#     silencio; declararlo en ambos sitios solo crea desalineacion).
#
#   Mientras main todavia declare `version` (estado de transicion del repo), el
#   gate NO deja pasar el fallo silencioso: exige que todo commit que toque
#   rutas servidas al usuario bumpee esa version.
#
# EXIT CODES (contrato del repo: un rc=0 nunca significa "no lo revise")
#   0 = MEDI y esta bien
#   1 = MEDI y FALLA
#   2 = NO PUDE MEDIR (falta herramienta, falta entrada, falta ref base)
#
# VARIABLES DE ENTORNO
#   EHS_CHANNEL            latest|stable  (por defecto se deduce de la rama)
#   EHS_BASE_REF           ref base para el diff (por defecto GITHUB_BASE_REF,
#                          luego origin/main, luego main)
#   EHS_REQUIRE_CLAUDE_CLI 1 => si falta el binario `claude`, rc=2 en vez de SKIP
#   EHS_REPO_ROOT          raiz del repo (por defecto: git rev-parse, luego cwd)
# ---------------------------------------------------------------------------
set -uo pipefail

SEMVER_RE='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'

# Rutas cuyo contenido se copia al cache del usuario al instalar/actualizar.
# Un cambio aqui SI cambia lo que el usuario ejecuta => obliga version nueva.
USER_SERVED_PATHS=(
  "skills/"
  "agents/"
  "commands/"
  "hooks/"
  ".claude-plugin/"
)

FAILURES=0
CHECKED=()
SKIPPED=()

ok()      { printf '  [OK]   %s\n' "$*"; CHECKED+=("$*"); }
fail()    { printf '  [FAIL] %s\n' "$*" >&2; CHECKED+=("$*"); FAILURES=$((FAILURES + 1)); }
skip()    { printf '  [SKIP] %s\n' "$*"; SKIPPED+=("$*"); }
info()    { printf '         %s\n' "$*"; }
section() { printf '\n== %s\n' "$*"; }

# rc=2 inmediato: no se pudo medir. Nunca degrada a 0.
unmeasurable() {
  printf '\n[NO PUDE MEDIR] %s\n' "$*" >&2
  printf 'gate-plugin-version: rc=2 (no es un pase; es ausencia de medicion)\n' >&2
  exit 2
}

# --- 0. herramientas -------------------------------------------------------
section "herramientas"
for tool in jq git; do
  command -v "$tool" >/dev/null 2>&1 || unmeasurable "falta la herramienta '$tool'"
done
ok "jq y git disponibles"

# --- 1. raiz del repo ------------------------------------------------------
if [[ -n "${EHS_REPO_ROOT:-}" ]]; then
  ROOT="$EHS_REPO_ROOT"
elif ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
  :
else
  ROOT="$PWD"
fi
[[ -d "$ROOT/.claude-plugin" ]] || unmeasurable \
  "no encuentro .claude-plugin/ bajo '$ROOT' (¿cwd equivocado? esto no es el repo del plugin)"

PLUGIN_JSON="$ROOT/.claude-plugin/plugin.json"
MARKET_JSON="$ROOT/.claude-plugin/marketplace.json"
info "raiz: $ROOT"

# --- 2. los dos JSON existen y parsean -------------------------------------
section "manifiestos"
for f in "$PLUGIN_JSON" "$MARKET_JSON"; do
  if [[ ! -f "$f" ]]; then
    fail "falta $(basename "$f") en .claude-plugin/ (el plugin no es instalable sin el)"
    continue
  fi
  if jq -e . "$f" >/dev/null 2>&1; then
    ok "$(basename "$f") parsea como JSON valido"
  else
    fail "$(basename "$f") NO parsea como JSON: $(jq . "$f" 2>&1 | head -3 | tr '\n' ' ')"
  fi
done
# Sin JSON parseable no hay nada mas que medir de forma fiable.
if (( FAILURES > 0 )); then
  printf '\ngate-plugin-version: rc=1 (manifiestos rotos; el resto no se pudo evaluar)\n' >&2
  exit 1
fi

PLUGIN_NAME=$(jq -r '.name // empty' "$PLUGIN_JSON")
PLUGIN_VERSION=$(jq -r 'if has("version") then (.version|tostring) else "" end' "$PLUGIN_JSON")
HAS_VERSION=$(jq -r 'has("version")' "$PLUGIN_JSON")

if [[ -z "$PLUGIN_NAME" ]]; then
  fail "plugin.json no declara 'name' (es el UNICO campo obligatorio)"
else
  ok "plugin.json name='$PLUGIN_NAME'"
fi

# --- 3. la entrada del marketplace NO debe declarar version ----------------
section "doble declaracion de version"
ENTRIES_WITH_VERSION=$(jq -r '[.plugins[]? | select(has("version")) | .name] | join(", ")' "$MARKET_JSON")
if [[ -n "$ENTRIES_WITH_VERSION" ]]; then
  fail "marketplace.json declara 'version' en: $ENTRIES_WITH_VERSION"
  info "plugin.json SIEMPRE gana y la entrada se ignora en silencio; declarar en"
  info "ambos sitios solo produce un manifiesto obsoleto que enmascara la version real."
  info "Arreglo: borrar 'version' de la entrada del marketplace."
else
  ok "ninguna entrada del marketplace declara 'version' (plugin.json es fuente unica)"
fi

# --- 4. la entrada del marketplace describe ESTE plugin --------------------
LOCAL_ENTRY_NAMES=$(jq -r '[.plugins[]? | select((.source|type=="string") and (.source|test("^\\./|^\\.$"))) | .name] | join("\n")' "$MARKET_JSON")
if [[ -z "$LOCAL_ENTRY_NAMES" ]]; then
  skip "ninguna entrada del marketplace usa source local './' — no hay cruce de nombre que verificar"
elif grep -qxF "$PLUGIN_NAME" <<<"$LOCAL_ENTRY_NAMES"; then
  ok "la entrada local './' se llama igual que plugin.json ('$PLUGIN_NAME')"
else
  fail "la entrada con source './' se llama '$(tr '\n' ' ' <<<"$LOCAL_ENTRY_NAMES")' pero plugin.json dice '$PLUGIN_NAME'"
fi

# Nombres duplicados en el catalogo: el validador oficial ya lo rechaza, pero
# lo medimos aqui para no depender de que `claude` este instalado.
DUPES=$(jq -r '[.plugins[]?.name] | group_by(.) | map(select(length>1) | .[0]) | join(", ")' "$MARKET_JSON")
if [[ -n "$DUPES" ]]; then
  fail "nombres de plugin duplicados en marketplace.json: $DUPES"
else
  ok "sin nombres de plugin duplicados en el catalogo"
fi

# --- 5. canal --------------------------------------------------------------
section "canal"
CHANNEL="${EHS_CHANNEL:-}"
if [[ -z "$CHANNEL" ]]; then
  BRANCH="${GITHUB_REF_NAME:-}"
  [[ -n "$BRANCH" ]] || BRANCH=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [[ "$BRANCH" == "stable" ]]; then CHANNEL="stable"; else CHANNEL="latest"; fi
  info "canal deducido de la rama '${BRANCH:-<desconocida>}'"
fi
case "$CHANNEL" in
  latest|stable) ok "canal = $CHANNEL" ;;
  *) unmeasurable "EHS_CHANNEL='$CHANNEL' no es 'latest' ni 'stable'" ;;
esac

# --- 6. politica por canal -------------------------------------------------
section "politica de version del canal '$CHANNEL'"

if [[ "$CHANNEL" == "stable" ]]; then
  # stable DEBE llevar semver explicito: es lo que distingue este canal de
  # latest. Si stable no declarara version, resolveria por SHA igual que
  # latest y no habria dos canales distinguibles.
  if [[ "$HAS_VERSION" != "true" ]]; then
    fail "stable NO declara 'version' en plugin.json"
    info "sin semver explicito, stable resuelve por SHA igual que latest y deja de ser un canal distinto"
  elif [[ ! "$PLUGIN_VERSION" =~ $SEMVER_RE ]]; then
    fail "version='$PLUGIN_VERSION' no es semver valido"
  else
    ok "stable declara semver '$PLUGIN_VERSION'"
    # Re-publicar una version ya taggeada = update saltado en silencio.
    TAG="${PLUGIN_NAME}--v${PLUGIN_VERSION}"
    if ! git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
      skip "no es un repo git: no puedo comprobar si el tag '$TAG' ya existe"
    elif git -C "$ROOT" rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1; then
      TAGGED_SHA=$(git -C "$ROOT" rev-list -n1 "refs/tags/$TAG")
      HEAD_SHA=$(git -C "$ROOT" rev-parse HEAD)
      if [[ "$TAGGED_SHA" == "$HEAD_SHA" ]]; then
        ok "el tag '$TAG' ya apunta a este mismo commit (re-ejecucion idempotente)"
      else
        fail "el tag '$TAG' ya existe apuntando a $TAGGED_SHA, distinto de HEAD ($HEAD_SHA)"
        info "publicar contenido nuevo con una version ya usada = los usuarios NO reciben la actualizacion"
      fi
    else
      ok "el tag '$TAG' aun no existe: la version es nueva"
    fi
  fi

else # latest
  if [[ "$HAS_VERSION" != "true" ]]; then
    ok "latest OMITE 'version': cada commit resuelve a una version nueva por su SHA"
    info "esto es el diseno objetivo; no hay bump que mantener y CI nunca escribe en main"
  else
    # Estado de transicion: main todavia declara version. No la damos por buena,
    # pero tampoco dejamos pasar el fallo silencioso: exigimos el bump.
    fail "latest declara version='$PLUGIN_VERSION' — el diseno pide OMITIRLA en main"
    info "con version fija, ningun commit de main llega a los usuarios instalados hasta que alguien la bumpee a mano"
    info "arreglo: borrar la clave 'version' de .claude-plugin/plugin.json en main"

    if [[ ! "$PLUGIN_VERSION" =~ $SEMVER_RE ]]; then
      fail "ademas, version='$PLUGIN_VERSION' no es semver valido"
    fi

    # Regla de bump mientras la version siga ahi.
    BASE_REF="${EHS_BASE_REF:-}"
    if [[ -z "$BASE_REF" && -n "${GITHUB_BASE_REF:-}" ]]; then BASE_REF="origin/${GITHUB_BASE_REF}"; fi
    if [[ -z "$BASE_REF" ]]; then
      for cand in origin/main main; do
        if git -C "$ROOT" rev-parse -q --verify "$cand" >/dev/null 2>&1; then BASE_REF="$cand"; break; fi
      done
    fi
    if [[ -z "$BASE_REF" ]] || ! git -C "$ROOT" rev-parse -q --verify "$BASE_REF" >/dev/null 2>&1; then
      unmeasurable "no puedo resolver un ref base para el diff (probé EHS_BASE_REF, GITHUB_BASE_REF, origin/main, main). Sin base no puedo comprobar la regla de bump."
    fi
    BASE_SHA=$(git -C "$ROOT" rev-parse "$BASE_REF")
    HEAD_SHA=$(git -C "$ROOT" rev-parse HEAD)
    info "base=$BASE_REF ($BASE_SHA)  head=$HEAD_SHA"

    if [[ "$BASE_SHA" == "$HEAD_SHA" ]]; then
      ok "HEAD == base: no hay cambios que exijan bump"
    else
      CHANGED=$(git -C "$ROOT" diff --name-only "$BASE_SHA" "$HEAD_SHA" 2>/dev/null)
      if [[ -z "$CHANGED" ]]; then
        ok "diff vacio frente a la base: no hay cambios que exijan bump"
      else
        TOUCHED=""
        while IFS= read -r f; do
          [[ -n "$f" ]] || continue
          for p in "${USER_SERVED_PATHS[@]}"; do
            case "$f" in "$p"*) TOUCHED+="$f"$'\n'; break ;; esac
          done
        done <<<"$CHANGED"

        if [[ -z "$TOUCHED" ]]; then
          ok "ningun cambio toca rutas servidas al usuario (${USER_SERVED_PATHS[*]}): no hace falta bump"
        else
          BASE_VERSION=$(git -C "$ROOT" show "$BASE_SHA:.claude-plugin/plugin.json" 2>/dev/null \
            | jq -r 'if has("version") then (.version|tostring) else "" end' 2>/dev/null)
          info "cambios servidos al usuario: $(tr '\n' ' ' <<<"$TOUCHED")"
          if [[ "$BASE_VERSION" == "$PLUGIN_VERSION" ]]; then
            fail "se tocaron rutas servidas al usuario pero version sigue en '$PLUGIN_VERSION' (igual que en la base)"
            info "FALLO SILENCIOSO DE DISTRIBUCION: /plugin update saltara este plugin porque la version resuelta no cambio"
          else
            ok "version cambio de '${BASE_VERSION:-<ausente>}' a '$PLUGIN_VERSION' junto con los cambios servidos"
          fi
        fi
      fi
    fi
  fi
fi

# --- 7. validador oficial (opcional, con teeth si CI lo exige) -------------
section "validador oficial de Anthropic"
# MEDIDO en 2.1.221: `claude plugin validate <dir>` con marketplace.json presente
# valida SOLO el manifiesto del marketplace y NO reporta el warning de version
# del plugin. Para auditar plugin.json hay que apuntar al ARCHIVO.
# MEDIDO tambien: devuelve rc=1 tanto si midio y fallo como si el path no existe
# => por eso este wrapper pre-verifica y nunca delega su exit code a la herramienta.
if ! command -v claude >/dev/null 2>&1; then
  if [[ "${EHS_REQUIRE_CLAUDE_CLI:-0}" == "1" ]]; then
    unmeasurable "EHS_REQUIRE_CLAUDE_CLI=1 pero el binario 'claude' no esta en PATH"
  fi
  skip "binario 'claude' no disponible: no se corrio validate (poner EHS_REQUIRE_CLAUDE_CLI=1 para exigirlo)"
else
  # En latest, la UNICA queja legitima de --strict es "No version specified":
  # es intencional. En vez de renunciar a --strict (perder cobertura) o de
  # tragarnoslo entero (aprobar a ciegas), se corre --strict y se comprueba que
  # TODA queja sea exactamente esa. Cualquier otra advertencia sigue fallando.
  EXPECTED_WARN='version: No version specified'

  validate_target() { # $1=path  $2=etiqueta
    local target="$1" label="$2" out rc n_warn n_expected
    out=$(claude plugin validate "$target" --strict 2>&1); rc=$?
    if (( rc == 0 )); then
      ok "claude plugin validate --strict sobre $label"
      return 0
    fi
    if [[ "$CHANNEL" == "latest" ]]; then
      n_warn=$(grep -c '❯ ' <<<"$out")
      n_expected=$(grep -c "❯ .*$EXPECTED_WARN" <<<"$out")
      if (( n_warn > 0 && n_warn == n_expected )) && ! grep -q 'Found .* error' <<<"$out"; then
        ok "claude plugin validate --strict sobre $label: la unica queja es la ausencia de 'version', que en latest es intencional ($n_warn advertencia(s), todas esperadas)"
        return 0
      fi
    fi
    fail "claude plugin validate --strict fallo sobre $label"
    sed 's/^/         | /' <<<"$out" >&2
    return 1
  }

  validate_target "$MARKET_JSON" "marketplace.json"
  validate_target "$PLUGIN_JSON" "plugin.json"
fi

# --- resumen ---------------------------------------------------------------
section "resumen"
printf '  revisado: %d comprobacion(es)\n' "${#CHECKED[@]}"
if ((${#SKIPPED[@]} > 0)); then
  printf '  NO revisado: %d\n' "${#SKIPPED[@]}"
  for s in "${SKIPPED[@]}"; do printf '    - %s\n' "$s"; done
else
  printf '  NO revisado: 0\n'
fi

if (( FAILURES > 0 )); then
  printf '\ngate-plugin-version: rc=1 — %d fallo(s) MEDIDO(s)\n' "$FAILURES" >&2
  exit 1
fi
printf '\ngate-plugin-version: rc=0 — medido y correcto\n'
exit 0
