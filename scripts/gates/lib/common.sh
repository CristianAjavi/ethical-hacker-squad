#!/usr/bin/env bash
# scripts/gates/lib/common.sh
#
# Utilidades comunes a todos los gates del repo.
#
# DOCTRINA DE CODIGOS DE SALIDA (no negociable):
#   0 = MEDI y esta BIEN
#   1 = MEDI y FALLA
#   2 = NO PUDE MEDIR (falta herramienta, falta entrada, fichero ilegible)
#
# Un rc=0 NUNCA puede significar "no lo revise". Todo gate imprime, ademas,
# que reviso y que NO reviso.
#
# Este fichero se hace `source`, no se ejecuta.

# shellcheck shell=bash

GATE_OK=0
GATE_FAIL=1
GATE_UNMEASURABLE=2
export GATE_OK GATE_FAIL GATE_UNMEASURABLE

# Colores solo si hay TTY y no estamos en CI.
if [ -t 1 ] && [ -z "${CI:-}" ]; then
  _C_RED=$'\033[31m'; _C_YEL=$'\033[33m'; _C_GRN=$'\033[32m'
  _C_DIM=$'\033[2m'; _C_OFF=$'\033[0m'
else
  _C_RED=''; _C_YEL=''; _C_GRN=''; _C_DIM=''; _C_OFF=''
fi

gate_log()  { printf '%s\n' "$*"; }
gate_info() { printf '%s\n' "${_C_DIM}· $*${_C_OFF}"; }
gate_ok()   { printf '%s\n' "${_C_GRN}OK${_C_OFF}   $*"; }
gate_fail() { printf '%s\n' "${_C_RED}FALLA${_C_OFF} $*"; }
gate_warn() { printf '%s\n' "${_C_YEL}NO MEDIBLE${_C_OFF} $*"; }

# gate_root: raiz del repo (o del arbol de trabajo). No depende de git estando
# disponible; cae al directorio padre de scripts/ si git no responde.
gate_root() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
  if command -v git >/dev/null 2>&1; then
    local top
    if top="$(git -C "$here" rev-parse --show-toplevel 2>/dev/null)"; then
      printf '%s\n' "$top"
      return 0
    fi
  fi
  printf '%s\n' "$here"
}

# gate_header <nombre> — cabecera legible del gate.
gate_header() {
  printf '\n=== gate: %s ===\n' "$1"
}

# gate_scope <lo que SI reviso> / gate_out_of_scope <lo que NO reviso>
gate_scope()        { printf 'ALCANCE   : %s\n' "$1"; }
gate_out_of_scope() { printf 'FUERA     : %s\n' "$1"; }

# gate_verdict <rc> — imprime el veredicto textual asociado al codigo.
gate_verdict() {
  case "$1" in
    0) printf 'VEREDICTO : 0 (medido, sin hallazgos)\n' ;;
    1) printf 'VEREDICTO : 1 (medido, FALLA)\n' ;;
    2) printf 'VEREDICTO : 2 (NO PUDE MEDIR — no cuenta como aprobado)\n' ;;
    *) printf 'VEREDICTO : %s (codigo inesperado — se trata como NO MEDIBLE)\n' "$1" ;;
  esac
}
