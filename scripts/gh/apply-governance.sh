#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# apply-governance.sh - comparador declarativo del gobierno del repositorio.
#
# Lee scripts/gh/governance.json (estado DESEADO), lee el estado REAL via GET
# de la API de GitHub, e informa cada diferencia. Con --apply, y solo con
# --apply, muta. Por defecto es --dry-run: no toca nada.
#
# Doble uso: es a la vez el aplicador y el GATE DE DERIVA. Corrido sin flags
# responde "el gobierno real coincide con el declarado?" con codigo de salida.
#
# CODIGOS DE SALIDA (doctrina: un rc=0 nunca puede significar "no lo revise")
#   0  Medi todo lo que declare y coincide (o, con --apply, quedo aplicado).
#   1  Medi y HAY DERIVA / una mutacion fallo. Estado real != estado deseado.
#   2  NO PUDE MEDIR alguna parte (falta gh/jq/jq-version, sin sesion, sin
#      permiso admin, la rama stable aun no existe, endpoint no disponible).
#      Nunca se degrada a 0: "no pude comprobarlo" no es "esta bien".
#
# Precedencia: si hay algo sin medir Y algo con deriva, gana 2, porque el
# veredicto honesto es "no se el estado completo".
#
# NO ejecuta ninguna mutacion sin --apply. NO acepta tokens por argumento.
# ---------------------------------------------------------------------------
set -Eeuo pipefail

readonly RC_OK=0
readonly RC_DRIFT=1
readonly RC_UNMEASURED=2

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
STATE_FILE="${SCRIPT_DIR}/governance.json"

MODE="dry-run"
ALLOW_UNOBSERVED=0
SKIP_STABLE=0
DISCOVER_ONLY=0
OPT_NO_COLOR=0

# Compatible con bash 3.2 (el unico que trae macOS): sin ${x,,}, sin arrays
# asociativos, sin mapfile.
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# ---------------------------------------------------------------------------
# Presentacion
# ---------------------------------------------------------------------------
c_reset=""; c_red=""; c_grn=""; c_yel=""; c_blu=""; c_dim=""
setup_colors() {
  if [[ $OPT_NO_COLOR -eq 1 || ! -t 1 || -n "${NO_COLOR:-}" ]]; then return; fi
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_grn=$'\033[32m'
  c_yel=$'\033[33m'; c_blu=$'\033[34m'; c_dim=$'\033[2m'
}

section() { printf '\n%s== %s%s\n' "$c_blu" "$1" "$c_reset"; }
ok()      { printf '   %sOK%s        %s\n' "$c_grn" "$c_reset" "$1"; N_OK=$((N_OK+1)); }
drift()   { printf '   %sDERIVA%s    %s\n' "$c_red" "$c_reset" "$1"; N_DRIFT=$((N_DRIFT+1)); }
applied() { printf '   %sAPLICADO%s  %s\n' "$c_grn" "$c_reset" "$1"; N_APPLIED=$((N_APPLIED+1)); }
failed()  { printf '   %sFALLO%s     %s\n' "$c_red" "$c_reset" "$1"; N_FAILED=$((N_FAILED+1)); }
unmeas()  { printf '   %sSIN MEDIR%s %s\n' "$c_yel" "$c_reset" "$1"; N_UNMEASURED=$((N_UNMEASURED+1)); }
info()    { printf '   %sinfo%s      %s\n' "$c_dim" "$c_reset" "$1"; }
plan()    { printf '   %splan%s      %s\n' "$c_dim" "$c_reset" "$1"; }

N_OK=0; N_DRIFT=0; N_APPLIED=0; N_FAILED=0; N_UNMEASURED=0

fatal() {
  printf '\n%sABORTA%s %s\n' "$c_red" "$c_reset" "$1" >&2
  exit "${2:-$RC_UNMEASURED}"
}

usage() {
  cat <<'EOF'
Uso: scripts/gh/apply-governance.sh [opciones]

  (sin opciones)            DRY-RUN. Compara e informa. No muta nada.
  --apply                   Ejecuta las mutaciones necesarias. Explicito a proposito.
  --dry-run                 Explicito, es el valor por defecto.
  --discover-contexts       Solo lista los check contexts realmente observados en
                            los ultimos commits de main. Util para rellenar
                            promotion.required_contexts sin adivinar. No muta.
  --allow-unobserved-contexts
                            Permite declarar como requerido un context que nunca
                            se ha observado. PELIGROSO: un nombre mal escrito deja
                            main imposible de fusionar para siempre.
  --skip-stable             Reconoce que la rama stable aun no existe y no cuenta
                            su ausencia como "sin medir".
  --state <ruta>            Usa otro fichero de estado deseado (por defecto
                            scripts/gh/governance.json).
  --no-color                Sin colores ANSI.
  -h, --help                Esta ayuda.

Codigos de salida: 0 coincide / 1 hay deriva o fallo una mutacion / 2 no pude medir.
EOF
}

# ---------------------------------------------------------------------------
# Parseo de argumentos
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)   MODE="apply" ;;
    --dry-run) MODE="dry-run" ;;
    --discover-contexts) DISCOVER_ONLY=1 ;;
    --allow-unobserved-contexts) ALLOW_UNOBSERVED=1 ;;
    --skip-stable) SKIP_STABLE=1 ;;
    --state) STATE_FILE="${2:-}"; shift ;;
    --no-color) OPT_NO_COLOR=1 ;;
    -h|--help) usage; exit "$RC_OK" ;;
    *) usage >&2; fatal "argumento desconocido: $1" "$RC_UNMEASURED" ;;
  esac
  shift
done
setup_colors

# ---------------------------------------------------------------------------
# Precondiciones. Cualquier fallo aqui es rc=2: no puedo medir, no "esta bien".
# ---------------------------------------------------------------------------
command -v gh >/dev/null 2>&1 || fatal "falta la CLI 'gh'. Sin ella no puedo leer ni el estado real ni el deseado."
command -v jq >/dev/null 2>&1 || fatal "falta 'jq'. Sin el no puedo comparar estructuras."
[[ -f "$STATE_FILE" ]] || fatal "no existe el fichero de estado deseado: $STATE_FILE"
jq -e . "$STATE_FILE" >/dev/null 2>&1 || fatal "$STATE_FILE no es JSON valido."

STATE="$(cat "$STATE_FILE")"
REPO="$(jq -r '.repo' <<<"$STATE")"
EXPECTED_ACCOUNT="$(jq -r '.expected_account' <<<"$STATE")"
ACTIONS_APP_ID="$(jq -r '.actions_app_id' <<<"$STATE")"
STABLE_BRANCH="$(jq -r '.promotion.stable_branch' <<<"$STATE")"
SOURCE_BRANCH="$(jq -r '.promotion.source_branch' <<<"$STATE")"

[[ "$REPO" == */* ]] || fatal "campo .repo invalido en $STATE_FILE: '$REPO'"

MODE_NOTE=""
if [[ "$MODE" == "dry-run" ]]; then MODE_NOTE="(no se muta nada)"; fi
printf '%s' "$c_dim"
cat <<EOF
repo            : $REPO
estado deseado  : $STATE_FILE
modo            : $MODE $MODE_NOTE
EOF
printf '%s' "$c_reset"

# --- Guardia de identidad: la cuenta gh activa DEBE ser la esperada ---------
section "Identidad de la sesion gh"
if ! ACTIVE_LOGIN="$(gh api user --jq '.login' 2>/dev/null)"; then
  fatal "no hay sesion gh utilizable (gh api user fallo). Corre: gh auth login"
fi
if [[ "$ACTIVE_LOGIN" != "$EXPECTED_ACCOUNT" ]]; then
  fatal "la cuenta gh ACTIVA es '$ACTIVE_LOGIN' y este repo exige '$EXPECTED_ACCOUNT'.
       Este Mac tiene varias cuentas gh y empujar/mutar con la equivocada es un error
       conocido y caro. Corrige con:  gh auth switch --user $EXPECTED_ACCOUNT
       No sigo: prefiero no medir a medir contra la identidad equivocada."
fi
ok "cuenta gh activa = $ACTIVE_LOGIN (coincide con expected_account)"

# --- Acceso y permisos ------------------------------------------------------
if ! REPO_JSON="$(gh api "repos/$REPO" 2>/dev/null)"; then
  fatal "no puedo leer repos/$REPO (repo inexistente, sin acceso, o token sin scope 'repo')."
fi
IS_ADMIN="$(jq -r '.permissions.admin // false' <<<"$REPO_JSON")"
OWNER_TYPE="$(jq -r '.owner.type' <<<"$REPO_JSON")"
if [[ "$IS_ADMIN" != "true" ]]; then
  fatal "el token activo no tiene permiso ADMIN sobre $REPO. La proteccion de ramas y los
       ajustes del repo no son ni siquiera LEGIBLES sin admin, asi que cualquier veredicto
       seria falso. rc=2."
fi
ok "permiso admin sobre $REPO (owner.type=$OWNER_TYPE)"
if [[ "$OWNER_TYPE" != "Organization" ]]; then
  info "repo de cuenta personal: 'restrictions' (quien puede pushear) es org-only y va en null."
fi

# ---------------------------------------------------------------------------
# Helper de mutacion. UNICO punto por el que pasa cualquier escritura.
#   run_mutation "<descripcion>" gh <args...>
# ---------------------------------------------------------------------------
run_mutation() {
  local desc="$1"; shift
  if [[ "$MODE" != "apply" ]]; then
    plan "$desc"
    printf '             %s$ %s%s\n' "$c_dim" "$*" "$c_reset"
    return 0
  fi
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?
  if [[ $rc -eq 0 ]]; then
    applied "$desc"
    return 0
  fi
  failed "$desc"
  printf '%s\n' "$out" | sed 's/^/             /' >&2
  return 1
}

# ---------------------------------------------------------------------------
# --discover-contexts: mira que check runs se han observado de verdad.
# ---------------------------------------------------------------------------
discover_contexts() {
  section "Check contexts observados en $SOURCE_BRANCH (ultimos 20 commits)"
  local shas
  if ! shas="$(gh api "repos/$REPO/commits?sha=$SOURCE_BRANCH&per_page=20" --jq '.[].sha' 2>/dev/null)"; then
    unmeas "no pude listar commits de $SOURCE_BRANCH"
    return
  fi
  local tmp; tmp="$(mktemp)"
  local sha
  # FD 3 + </dev/null: si 'gh' consumiese stdin se comeria el resto de la lista
  # de commits y el descubrimiento saldria corto sin decirlo.
  while IFS= read -r sha <&3; do
    [[ -n "$sha" ]] || continue
    gh api "repos/$REPO/commits/$sha/check-runs" \
      --jq '.check_runs[] | "\(.name)\t\(.app.id)\t\(.conclusion)"' </dev/null 2>/dev/null >>"$tmp" || true
  done 3<<<"$shas"
  if [[ -s "$tmp" ]]; then
    sort -u "$tmp" | while IFS=$'\t' read -r name appid concl; do
      printf '   %-40s app_id=%-8s conclusion=%s\n' "$name" "$appid" "$concl"
      found=1
    done
  else
    info "ningun check run observado. Todavia no hay CI que reportar, o el CI no ha corrido en main."
  fi
  rm -f "$tmp"
}

observed_contexts() {
  # imprime, una por linea, "nombre\tapp_id" de los checks vistos en main
  local shas sha
  shas="$(gh api "repos/$REPO/commits?sha=$SOURCE_BRANCH&per_page=20" --jq '.[].sha' 2>/dev/null)" || return 1
  while IFS= read -r sha <&3; do
    [[ -n "$sha" ]] || continue
    gh api "repos/$REPO/commits/$sha/check-runs" --jq '.check_runs[] | "\(.name)\t\(.app.id)"' </dev/null 2>/dev/null || true
  done 3<<<"$shas" | sort -u
}

if [[ $DISCOVER_ONLY -eq 1 ]]; then
  discover_contexts
  exit "$RC_OK"
fi

# ---------------------------------------------------------------------------
# 1) PROTECCION DE RAMAS
#    Se hace ANTES que los ajustes del repo a proposito: auto-merge no es un
#    gate sino un disparador, y solo aparece cuando ya hay un requisito
#    pendiente. Activar allow_auto_merge antes de declarar los checks
#    requeridos produce merges instantaneos sin gate.
# ---------------------------------------------------------------------------
readonly NORM_FROM_PUT='{
  strict:              (.required_status_checks.strict // false),
  contexts:            ([ (.required_status_checks.checks // [])[] | "\(.context)@\(.app_id // 0)" ] | sort),
  enforce_admins:      (.enforce_admins // false),
  pr_required:         (.required_pull_request_reviews != null),
  approvals:           (.required_pull_request_reviews.required_approving_review_count // 0),
  code_owner_review:   (.required_pull_request_reviews.require_code_owner_reviews // false),
  dismiss_stale:       (.required_pull_request_reviews.dismiss_stale_reviews // false),
  last_push_approval:  (.required_pull_request_reviews.require_last_push_approval // false),
  force_pushes:        (.allow_force_pushes // false),
  deletions:           (.allow_deletions // false),
  linear_history:      (.required_linear_history // false),
  conversation_res:    (.required_conversation_resolution // false),
  lock_branch:         (.lock_branch // false),
  block_creations:     (.block_creations // false),
  fork_syncing:        (.allow_fork_syncing // false)
}'

readonly NORM_FROM_GET='{
  strict:              (.required_status_checks.strict // false),
  contexts:            ([ (.required_status_checks.checks // [])[] | "\(.context)@\(.app_id // 0)" ] | sort),
  enforce_admins:      (.enforce_admins.enabled // false),
  pr_required:         (.required_pull_request_reviews != null),
  approvals:           (.required_pull_request_reviews.required_approving_review_count // 0),
  code_owner_review:   (.required_pull_request_reviews.require_code_owner_reviews // false),
  dismiss_stale:       (.required_pull_request_reviews.dismiss_stale_reviews // false),
  last_push_approval:  (.required_pull_request_reviews.require_last_push_approval // false),
  force_pushes:        (.allow_force_pushes.enabled // false),
  deletions:           (.allow_deletions.enabled // false),
  linear_history:      (.required_linear_history.enabled // false),
  conversation_res:    (.required_conversation_resolution.enabled // false),
  lock_branch:         (.lock_branch.enabled // false),
  block_creations:     (.block_creations.enabled // false),
  fork_syncing:        (.allow_fork_syncing.enabled // false)
}'

# Inyecta actions_app_id en cada check requerido: el JSON declarativo solo
# lleva el nombre del context, el app_id es politica global y va en un sitio.
desired_protection() {
  local branch="$1"
  jq -c --argjson app "$ACTIONS_APP_ID" --arg b "$branch" '
    .branches[$b].protection
    | if .required_status_checks != null
      then .required_status_checks.checks =
             [ .required_status_checks.checks[] | {context: .context, app_id: $app} ]
      else . end
  ' <<<"$STATE"
}

check_branch_exists() {
  gh api "repos/$REPO/branches/$1" --jq '.name' >/dev/null 2>&1
}

# Salvaguarda anti-auto-DoS: nunca declares como requerido un context que
# jamas se ha visto. Un nombre mal escrito deja main imposible de fusionar y
# el token de Actions NO es admin, asi que no hay quien lo desatasque solo.
verify_contexts_observed() {
  local want="$1"   # lista "ctx@appid" separada por saltos de linea
  [[ -z "$want" ]] && return 0
  local obs rc=0
  if ! obs="$(observed_contexts)"; then
    unmeas "no pude listar los check runs de $SOURCE_BRANCH para validar los contextos requeridos"
    return 2
  fi
  local entry ctx app
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    ctx="${entry%@*}"; app="${entry##*@}"
    if grep -qF "$(printf '%s\t%s' "$ctx" "$app")" <<<"$obs"; then
      ok "context requerido '$ctx' (app_id=$app) OBSERVADO en $SOURCE_BRANCH"
    else
      rc=1
      if [[ $ALLOW_UNOBSERVED -eq 1 ]]; then
        info "context '$ctx' (app_id=$app) NUNCA observado, pero --allow-unobserved-contexts esta activo"
        rc=0
      else
        drift "context requerido '$ctx' (app_id=$app) NUNCA se ha observado en $SOURCE_BRANCH.
             Declararlo dejaria $SOURCE_BRANCH imposible de fusionar. Corre
             --discover-contexts para ver los nombres reales, corrige
             promotion.required_contexts / branches.$SOURCE_BRANCH en el JSON, o
             pasa --allow-unobserved-contexts si sabes lo que haces."
      fi
    fi
  done <<<"$want"
  return $rc
}

reconcile_branch_protection() {
  local branch="$1"
  section "Proteccion de rama: $branch"

  local want; want="$(desired_protection "$branch")"
  if [[ -z "$want" || "$want" == "null" ]]; then
    unmeas "no hay proteccion declarada para '$branch' en $STATE_FILE"
    return
  fi

  if ! check_branch_exists "$branch"; then
    if [[ $SKIP_STABLE -eq 1 && "$branch" == "$STABLE_BRANCH" ]]; then
      info "la rama '$branch' aun no existe; omitida por --skip-stable (reconocido explicitamente)"
    else
      unmeas "la rama '$branch' NO EXISTE todavia, asi que no puedo verificar ni aplicar su proteccion.
             La crea la primera promocion (.github/workflows/promote-stable.yml). Vuelve a correr
             este script DESPUES de esa primera promocion. rc=2 = 'no lo revise', no 'esta bien'."
    fi
    return
  fi

  local want_norm; want_norm="$(jq -S "$NORM_FROM_PUT" <<<"$want")"
  local want_ctx;  want_ctx="$(jq -r '.contexts[]' <<<"$want_norm")"

  local ctx_rc=0
  verify_contexts_observed "$want_ctx" || ctx_rc=$?
  if [[ $ctx_rc -ne 0 ]]; then
    info "no aplico la proteccion de '$branch' hasta que los contextos requeridos sean validos"
    return
  fi

  local have have_norm
  if have="$(gh api "repos/$REPO/branches/$branch/protection" 2>/dev/null)"; then
    have_norm="$(jq -S "$NORM_FROM_GET" <<<"$have")"
  else
    have_norm='null'
    info "la rama '$branch' no tiene ninguna proteccion activa (GET -> 404 Branch not protected)"
  fi

  if [[ "$have_norm" == "$want_norm" ]]; then
    ok "$branch: la proteccion real coincide con la declarada"
    jq -r 'to_entries[] | "             \(.key) = \(.value|tostring)"' <<<"$want_norm"
    return
  fi

  drift "$branch: la proteccion real NO coincide con la declarada"
  if [[ "$have_norm" == "null" ]]; then
    jq -r 'to_entries[] | "             + \(.key) = \(.value|tostring)"' <<<"$want_norm"
  else
    local k hv wv
    while IFS= read -r k; do
      hv="$(jq -r --arg k "$k" '.[$k]|tostring' <<<"$have_norm")"
      wv="$(jq -r --arg k "$k" '.[$k]|tostring' <<<"$want_norm")"
      [[ "$hv" == "$wv" ]] && continue
      printf '             %-20s real=%-28s deseado=%s\n' "$k" "$hv" "$wv"
    done < <(jq -r 'keys[]' <<<"$want_norm")
  fi

  local tmp; tmp="$(mktemp)"; printf '%s' "$want" >"$tmp"
  run_mutation "$branch: PUT /repos/$REPO/branches/$branch/protection (reemplazo total, idempotente)" \
    gh api --method PUT "repos/$REPO/branches/$branch/protection" --input "$tmp" || true
  rm -f "$tmp"
}

reconcile_branch_protection "$SOURCE_BRANCH"
reconcile_branch_protection "$STABLE_BRANCH"

# ---------------------------------------------------------------------------
# 2) AJUSTES DEL REPO
# ---------------------------------------------------------------------------
section "Ajustes del repositorio"
SETTING_KEYS="$(jq -r '.settings | keys[]' <<<"$STATE")"

settings_patch='{}'
for k in $SETTING_KEYS; do
  want="$(jq -r --arg k "$k" '.settings[$k]|tostring' <<<"$STATE")"
  have="$(jq -r --arg k "$k" '.[$k]|tostring' <<<"$REPO_JSON")"
  if [[ "$have" == "$want" ]]; then
    ok "$k = $have"
  else
    drift "$k: real=$have deseado=$want"
    settings_patch="$(jq -c --arg k "$k" --argjson v "$(jq -c --arg k "$k" '.settings[$k]' <<<"$STATE")" \
      '. + {($k): $v}' <<<"$settings_patch")"
  fi
done

if [[ "$settings_patch" != '{}' ]]; then
  tmp="$(mktemp)"; printf '%s' "$settings_patch" >"$tmp"
  run_mutation "PATCH /repos/$REPO ($(jq -r 'keys|join(", ")' <<<"$settings_patch"))" \
    gh api --method PATCH "repos/$REPO" --input "$tmp" || true
  rm -f "$tmp"
fi

# ---------------------------------------------------------------------------
# 3) TOPICS (PUT reemplaza el conjunto completo -> declarativo e idempotente)
# ---------------------------------------------------------------------------
section "Topics"
if have_topics="$(gh api "repos/$REPO/topics" --jq '.names|sort|join(",")' 2>/dev/null)"; then
  want_topics="$(jq -r '.topics|sort|join(",")' <<<"$STATE")"
  if [[ "$have_topics" == "$want_topics" ]]; then
    ok "topics = $have_topics"
  else
    drift "topics: real=[$have_topics] deseado=[$want_topics]"
    tmp="$(mktemp)"; jq -c '{names: .topics}' <<<"$STATE" >"$tmp"
    run_mutation "PUT /repos/$REPO/topics" gh api --method PUT "repos/$REPO/topics" --input "$tmp" || true
    rm -f "$tmp"
  fi
else
  unmeas "no pude leer repos/$REPO/topics"
fi

# ---------------------------------------------------------------------------
# 4) LABELS. Crear las que faltan, corregir color/descripcion.
#    NUNCA borra labels no declaradas: destruir metadatos ajenos no es gobierno.
# ---------------------------------------------------------------------------
section "Labels"
if ! labels_json="$(gh api "repos/$REPO/labels?per_page=100" 2>/dev/null)"; then
  unmeas "no pude listar las labels de $REPO"
else
  n_labels="$(jq -r '.labels|length' <<<"$STATE")"
  for ((i=0; i<n_labels; i++)); do
    lname="$(jq -r --argjson i "$i" '.labels[$i].name' <<<"$STATE")"
    lcolor="$(jq -r --argjson i "$i" '.labels[$i].color' <<<"$STATE")"
    ldesc="$(jq -r --argjson i "$i" '.labels[$i].description' <<<"$STATE")"

    existing="$(jq -c --arg n "$lname" '.[] | select(.name == $n)' <<<"$labels_json")"
    if [[ -z "$existing" ]]; then
      drift "falta la label '$lname'"
      run_mutation "crear label '$lname'" \
        gh api --method POST "repos/$REPO/labels" \
          -f "name=$lname" -f "color=$lcolor" -f "description=$ldesc" || true
      continue
    fi
    ecolor="$(jq -r '.color' <<<"$existing")"
    edesc="$(jq -r '.description // ""' <<<"$existing")"
    if [[ "$(lower "$ecolor")" == "$(lower "$lcolor")" && "$edesc" == "$ldesc" ]]; then
      ok "label '$lname'"
    else
      drift "label '$lname': color real=$ecolor deseado=$lcolor | desc real='$edesc' deseado='$ldesc'"
      run_mutation "actualizar label '$lname'" \
        gh api --method PATCH "repos/$REPO/labels/$lname" \
          -f "new_name=$lname" -f "color=$lcolor" -f "description=$ldesc" || true
    fi
  done
  extra="$(jq -r --argjson want "$(jq -c '[.labels[].name]' <<<"$STATE")" \
    '[.[].name] - $want | join(", ")' <<<"$labels_json")"
  if [[ -n "$extra" ]]; then
    info "labels no declaradas (se dejan intactas a proposito): $extra"
  fi
fi

# ---------------------------------------------------------------------------
# 5) ALERTAS DE VULNERABILIDAD (Dependabot)
#    GET /vulnerability-alerts -> 204 activado, 404 desactivado.
# ---------------------------------------------------------------------------
section "Alertas de vulnerabilidad"
want_va="$(jq -r '.vulnerability_alerts' <<<"$STATE")"
va_rc=0
gh api "repos/$REPO/vulnerability-alerts" >/dev/null 2>&1 || va_rc=$?
if [[ $va_rc -eq 0 ]]; then have_va="true"; else have_va="false"; fi
if [[ "$have_va" == "$want_va" ]]; then
  ok "vulnerability_alerts = $have_va"
else
  drift "vulnerability_alerts: real=$have_va deseado=$want_va"
  if [[ "$want_va" == "true" ]]; then
    run_mutation "activar alertas de vulnerabilidad" gh api --method PUT "repos/$REPO/vulnerability-alerts" || true
  else
    run_mutation "desactivar alertas de vulnerabilidad" gh api --method DELETE "repos/$REPO/vulnerability-alerts" || true
  fi
fi

# ---------------------------------------------------------------------------
# 6) SECRET SCANNING + PUSH PROTECTION
#    Disponibilidad por API en repo publico de cuenta personal Free: NO
#    VERIFICADA. Por eso un fallo aqui cuenta como SIN MEDIR, no como exito.
# ---------------------------------------------------------------------------
section "Secret scanning"
want_ss="$(jq -r '.secret_scanning.enabled' <<<"$STATE")"
want_pp="$(jq -r '.secret_scanning.push_protection' <<<"$STATE")"
have_ss="$(jq -r '.security_and_analysis.secret_scanning.status // "desconocido"' <<<"$REPO_JSON")"
have_pp="$(jq -r '.security_and_analysis.secret_scanning_push_protection.status // "desconocido"' <<<"$REPO_JSON")"
want_ss_s=$([[ "$want_ss" == "true" ]] && echo enabled || echo disabled)
want_pp_s=$([[ "$want_pp" == "true" ]] && echo enabled || echo disabled)

if [[ "$have_ss" == "desconocido" || "$have_pp" == "desconocido" ]]; then
  unmeas "la respuesta de repos/$REPO no trae security_and_analysis (secret_scanning=$have_ss push_protection=$have_pp).
         Disponibilidad en repo publico de cuenta personal Free NO verificada con doc oficial.
         Lo cuento como SIN MEDIR, nunca como correcto."
elif [[ "$have_ss" == "$want_ss_s" && "$have_pp" == "$want_pp_s" ]]; then
  ok "secret_scanning=$have_ss push_protection=$have_pp"
else
  drift "secret_scanning: real=$have_ss deseado=$want_ss_s | push_protection: real=$have_pp deseado=$want_pp_s"
  tmp="$(mktemp)"
  jq -nc --arg ss "$want_ss_s" --arg pp "$want_pp_s" \
    '{security_and_analysis:{secret_scanning:{status:$ss},secret_scanning_push_protection:{status:$pp}}}' >"$tmp"
  run_mutation "PATCH /repos/$REPO (security_and_analysis)" \
    gh api --method PATCH "repos/$REPO" --input "$tmp" || true
  rm -f "$tmp"
fi

# ---------------------------------------------------------------------------
# 7) COHERENCIA: lo declarado aqui vs lo que consume promote-stable.yml
# ---------------------------------------------------------------------------
section "Coherencia con el workflow de promocion"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
WF="${REPO_ROOT}/.github/workflows/promote-stable.yml"
if [[ ! -f "$WF" ]]; then
  unmeas "no encuentro $WF: no puedo comprobar que el workflow y este JSON hablen de lo mismo"
else
  if grep -q 'scripts/gh/governance.json' "$WF"; then
    ok "promote-stable.yml lee scripts/gh/governance.json (una sola fuente de verdad)"
  else
    drift "promote-stable.yml NO lee governance.json: los nombres de labels/ramas estarian duplicados"
  fi
  gates_dir="${REPO_ROOT}/$(jq -r '.promotion.gates_dir' <<<"$STATE")"
  if [[ -d "$gates_dir" ]]; then
    n_gates="$(find "$gates_dir" -maxdepth 1 -type f -name '*.sh' | wc -l | tr -d ' ')"
    if [[ "$n_gates" -gt 0 ]]; then
      ok "$gates_dir contiene $n_gates gate(s) ejecutables"
    else
      drift "$gates_dir existe pero esta VACIO: la promocion se bloqueara (correcto: fail-safe)"
    fi
  else
    unmeas "$gates_dir no existe todavia (lo construye el area de gates). La promocion se bloqueara hasta entonces."
  fi
fi

# ---------------------------------------------------------------------------
# Veredicto
# ---------------------------------------------------------------------------
section "Resumen"
printf '   revisado OK : %d\n' "$N_OK"
printf '   deriva      : %d\n' "$N_DRIFT"
printf '   aplicado    : %d\n' "$N_APPLIED"
printf '   fallos      : %d\n' "$N_FAILED"
printf '   SIN MEDIR   : %d\n' "$N_UNMEASURED"

cat <<EOF

   Lo que este script NO revisa (dilo en voz alta en vez de fingir cobertura):
     - Quien puede pushear a una rama. En repo de cuenta personal 'restrictions' es
       org-only; es INEXPRESABLE. La garantia real la dan los gates, no la rama.
     - Rulesets. Este repo usa proteccion clasica a proposito; si algun dia se crea un
       ruleset, se apilaria con la clasica y ganaria lo mas restrictivo.
       Deteccion manual: gh api repos/$REPO/rules/branches/$SOURCE_BRANCH
     - El contenido de los gates. Aqui solo se comprueba que existan y esten declarados.
EOF

if [[ $N_UNMEASURED -gt 0 ]]; then
  printf '\n%sVEREDICTO: rc=2 NO PUDE MEDIRLO TODO.%s Hay partes del gobierno cuyo estado desconozco.\n' "$c_yel" "$c_reset"
  exit "$RC_UNMEASURED"
fi
if [[ $N_FAILED -gt 0 ]]; then
  printf '\n%sVEREDICTO: rc=1 alguna mutacion FALLO.%s\n' "$c_red" "$c_reset"
  exit "$RC_DRIFT"
fi
if [[ $N_DRIFT -gt 0 && "$MODE" != "apply" ]]; then
  printf '\n%sVEREDICTO: rc=1 HAY DERIVA.%s El estado real no coincide con el declarado. Revisa el plan y corre --apply.\n' "$c_red" "$c_reset"
  exit "$RC_DRIFT"
fi
if [[ $N_DRIFT -gt 0 && $N_APPLIED -eq 0 ]]; then
  printf '\n%sVEREDICTO: rc=1 habia deriva y no se aplico nada.%s\n' "$c_red" "$c_reset"
  exit "$RC_DRIFT"
fi
printf '\n%sVEREDICTO: rc=0 medido y conforme.%s\n' "$c_grn" "$c_reset"
exit "$RC_OK"
