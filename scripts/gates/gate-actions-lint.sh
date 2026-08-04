#!/usr/bin/env bash
# scripts/gates/gate-actions-lint.sh
#
# Gate de analisis estatico de GitHub Actions con las dos herramientas que se
# validaron para este repo: zizmor (seguridad) y actionlint (correccion).
# Son complementarias, no redundantes:
#   - zizmor cubre las reglas duras del modelo de amenaza: dangerous-triggers,
#     template-injection, excessive-permissions, unpinned-uses, artipacked...
#     y ademas audita .github/dependabot.yml.
#   - actionlint valida sintaxis, expresiones, cron, etiquetas de runner, el
#     formato de `uses:`, y pasa shellcheck sobre cada `run:`. Su lista de
#     contextos no confiables (github.event.issue.title, comment.body, ...) es
#     la enumeracion canonica que la documentacion de GitHub no publica.
#
# Codigos de salida: 0 = medido y bien | 1 = medido y falla | 2 = no pude medir.
#
# Mapeo de codigos MEDIDO empiricamente (zizmor 1.29.0, actionlint 1.7.12):
#   zizmor     0 -> 0 | 11,12,13,14 (informational/low/medium/high) -> 1
#              3 (no se recolecto ningun input) -> 2 | 1 (error) -> 2
#   actionlint 0 -> 0 | 1 -> 1 | 3 (no pudo leer) -> 2
#
# PROHIBIDO en este fichero, por construccion:
#   - `--format=sarif`: devuelve 0 aunque haya hallazgos high (comprobado).
#   - pipear la herramienta a `tail`/`head`: destruye el codigo de salida.
#     Por eso toda salida va a fichero por redireccion, y se lee despues.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"
# shellcheck source=scripts/gates/lib/bootstrap-actions-lint.sh
. "$SELF_DIR/lib/bootstrap-actions-lint.sh"

ROOT="$(gate_root)"
WF_DIR="$ROOT/.github/workflows"

TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t gatelint)"
trap 'rm -rf "$TMPD"' EXIT

RC_FINAL=0
# escala(rc): un FALLA (1) manda sobre un NO MEDIBLE (2); 0 no degrada nada.
escala() {
  case "$1" in
    1) RC_FINAL=1 ;;
    2) [ "$RC_FINAL" -eq 1 ] || RC_FINAL=2 ;;
  esac
}

dump() { # dump <fichero> <prefijo>
  [ -s "$1" ] || return 0
  while IFS= read -r l; do printf '%s%s\n' "$2" "$l"; done < "$1"
}

gate_header "actions-lint (zizmor + actionlint)"
gate_scope "todos los workflows, acciones compuestas y .github/dependabot.yml del repo"
gate_out_of_scope "logica de negocio de los scripts; el contrato de permisos/disparadores lo verifica ademas gate-workflow-hardening.sh sin depender de estas herramientas"

if [ ! -d "$WF_DIR" ]; then
  gate_warn "no existe $WF_DIR: no hay workflows que analizar (y eso no es un aprobado)"
  gate_verdict 2
  exit "$GATE_UNMEASURABLE"
fi

# ---------------------------------------------------------------------------
# zizmor
# ---------------------------------------------------------------------------
ZOUT="$TMPD/zizmor.txt"
if ensure_zizmor; then
  ZARGS="--no-progress --color never --format plain"
  # Auditorias en linea (impostor-commit, known-vulnerable-actions,
  # stale-action-refs) solo si hay token Y se pide explicitamente. Nunca por
  # defecto: un trabajo que analiza un PR de un fork no debe recibir secretos.
  if [ "${ZIZMOR_ONLINE:-0}" = "1" ] && [ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]; then
    gate_info "zizmor: auditorias EN LINEA activadas (ZIZMOR_ONLINE=1 y hay token)"
  else
    ZARGS="$ZARGS --no-online-audits"
    gate_info "zizmor: auditorias en linea DESACTIVADAS — NO se comprobo impostor-commit, known-vulnerable-actions ni stale-action-refs (eso corre en el workflow supply-chain-audit)"
  fi
  # shellcheck disable=SC2086
  "$ZIZMOR_BIN" $ZARGS "$ROOT" > "$ZOUT" 2>&1
  zrc=$?
  case "$zrc" in
    0)  gate_ok "zizmor $ZIZMOR_VERSION: sin hallazgos" ;;
    11|12|13|14)
        gate_fail "zizmor $ZIZMOR_VERSION: hallazgos (codigo $zrc)"
        dump "$ZOUT" "  "
        escala 1 ;;
    3)  gate_warn "zizmor $ZIZMOR_VERSION: no recolecto ningun input (codigo 3)"
        dump "$ZOUT" "  "
        escala 2 ;;
    *)  gate_warn "zizmor $ZIZMOR_VERSION: error de la herramienta (codigo $zrc)"
        dump "$ZOUT" "  "
        escala 2 ;;
  esac
else
  gate_warn "zizmor NO disponible: NO se auditaron dangerous-triggers, template-injection, excessive-permissions, unpinned-uses ni dependabot.yml"
  escala 2
fi
printf '%s' "$BOOTSTRAP_NOTES" | sed 's/^/  · /'
BOOTSTRAP_NOTES=""

# ---------------------------------------------------------------------------
# actionlint
# ---------------------------------------------------------------------------
AOUT="$TMPD/actionlint.txt"
if ensure_actionlint; then
  if ! command -v shellcheck >/dev/null 2>&1; then
    gate_warn "shellcheck NO esta instalado: actionlint NO analizara el contenido de los bloques \`run:\`. Se mide lo demas, pero esto NO es un aprobado completo."
    escala 2
  fi
  ( cd "$ROOT" && "$ACTIONLINT_BIN" -no-color -oneline ) > "$AOUT" 2>&1
  arc=$?
  case "$arc" in
    0) gate_ok "actionlint $ACTIONLINT_VERSION: sin problemas" ;;
    1) gate_fail "actionlint $ACTIONLINT_VERSION: problemas encontrados (codigo 1)"
       dump "$AOUT" "  "
       escala 1 ;;
    3) gate_warn "actionlint $ACTIONLINT_VERSION: no pudo leer los ficheros (codigo 3)"
       dump "$AOUT" "  "
       escala 2 ;;
    *) gate_warn "actionlint $ACTIONLINT_VERSION: codigo inesperado $arc"
       dump "$AOUT" "  "
       escala 2 ;;
  esac
else
  gate_warn "actionlint NO disponible: NO se valido sintaxis, cron, runners, ni las expresiones con contextos no confiables"
  escala 2
fi
printf '%s' "$BOOTSTRAP_NOTES" | sed 's/^/  · /'

gate_verdict "$RC_FINAL"
exit "$RC_FINAL"
