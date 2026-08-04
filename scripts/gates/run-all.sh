#!/usr/bin/env bash
# scripts/gates/run-all.sh
#
# Ejecuta TODOS los gates del repo (scripts/gates/gate-*.sh) y agrega sus
# resultados respetando la doctrina de codigos:
#
#   0 = todos los gates midieron y ninguno fallo
#   1 = al menos un gate MIDIO y FALLO
#   2 = ningun fallo medido, pero al menos un gate NO PUDO MEDIR
#
# Un gate que no pudo medir NO cuenta como aprobado: se reporta aparte y la
# ejecucion no devuelve 0. Cualquier codigo distinto de 0/1/2 se trata como 2
# (un gate que no respeta el contrato no puede dar garantias).
#
# Uso:
#   scripts/gates/run-all.sh                       # todos
#   scripts/gates/run-all.sh --only 'gate-actions-lint.sh'
#   scripts/gates/run-all.sh --skip 'gate-actions-lint.sh'
#   scripts/gates/run-all.sh --list
#
# --only/--skip aceptan patrones glob y pueden repetirse.
# Si se define GITHUB_STEP_SUMMARY, escribe ademas un resumen en Markdown.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

ONLY=""
SKIP=""
LIST_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY="${ONLY}${2:-}"$'\n'; shift 2 ;;
    --skip) SKIP="${SKIP}${2:-}"$'\n'; shift 2 ;;
    --list) LIST_ONLY=1; shift ;;
    -h|--help) sed -n '2,26p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "argumento desconocido: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

matches_any() { # matches_any <nombre> <lista-con-saltos-de-linea>
  local name="$1" list="$2" pat
  [ -n "$list" ] || return 1
  while IFS= read -r pat; do
    [ -n "$pat" ] || continue
    # shellcheck disable=SC2254
    case "$name" in $pat) return 0 ;; esac
  done <<EOF
$list
EOF
  return 1
}

TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t runall)"
trap 'rm -rf "$TMPD"' EXIT
RESULTS="$TMPD/results"
: > "$RESULTS"

n_total=0; n_ok=0; n_fail=0; n_unmeas=0

for g in "$SELF_DIR"/gate-*.sh; do
  [ -e "$g" ] || continue
  name="$(basename "$g")"
  if [ -n "$ONLY" ] && ! matches_any "$name" "$ONLY"; then continue; fi
  if matches_any "$name" "$SKIP"; then
    gate_info "omitido por --skip: $name"
    continue
  fi
  n_total=$((n_total + 1))
  if [ "$LIST_ONLY" -eq 1 ]; then printf '%s\n' "$name"; continue; fi

  if [ ! -x "$g" ]; then
    gate_warn "$name no es ejecutable (falta chmod +x): no puedo medir con el"
    printf '2|%s|no ejecutable\n' "$name" >> "$RESULTS"
    n_unmeas=$((n_unmeas + 1))
    continue
  fi

  "$g"
  rc=$?
  case "$rc" in
    0) n_ok=$((n_ok + 1));      printf '0|%s|medido, sin hallazgos\n' "$name" >> "$RESULTS" ;;
    1) n_fail=$((n_fail + 1));  printf '1|%s|medido, FALLA\n' "$name" >> "$RESULTS" ;;
    2) n_unmeas=$((n_unmeas + 1)); printf '2|%s|NO PUDO MEDIR\n' "$name" >> "$RESULTS" ;;
    *) n_unmeas=$((n_unmeas + 1)); printf '2|%s|codigo inesperado %s, tratado como NO PUDO MEDIR\n' "$name" "$rc" >> "$RESULTS" ;;
  esac
done

[ "$LIST_ONLY" -eq 1 ] && exit 0

if [ "$n_total" -eq 0 ]; then
  gate_warn "no se ejecuto ningun gate (¿filtros --only/--skip demasiado estrictos?)"
  gate_verdict 2
  exit "$GATE_UNMEASURABLE"
fi

FINAL=0
[ "$n_unmeas" -gt 0 ] && FINAL=2
[ "$n_fail" -gt 0 ] && FINAL=1

printf '\n===== RESUMEN DE GATES =====\n'
printf 'ejecutados: %d | verdes: %d | FALLA: %d | NO MEDIBLES: %d\n' \
  "$n_total" "$n_ok" "$n_fail" "$n_unmeas"
while IFS='|' read -r rc name msg; do
  case "$rc" in
    0) gate_ok   "$name — $msg" ;;
    1) gate_fail "$name — $msg" ;;
    *) gate_warn "$name — $msg" ;;
  esac
done < "$RESULTS"

if [ "$n_unmeas" -gt 0 ]; then
  printf '\nUn gate NO MEDIBLE no es un gate verde: significa que esa comprobacion\n'
  printf 'no se hizo. Se reporta aparte y la ejecucion NO devuelve 0.\n'
fi

# Resumen para la pestaña de GitHub Actions, si estamos en CI.
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    printf '## Gates\n\n'
    printf '| Resultado | Gate | Detalle |\n|---|---|---|\n'
    while IFS='|' read -r rc name msg; do
      case "$rc" in
        0) printf '| ✅ 0 medido/OK | `%s` | %s |\n' "$name" "$msg" ;;
        1) printf '| ❌ 1 medido/FALLA | `%s` | %s |\n' "$name" "$msg" ;;
        *) printf '| ⚠️ 2 NO MEDIBLE | `%s` | %s |\n' "$name" "$msg" ;;
      esac
    done < "$RESULTS"
    printf '\n**ejecutados %d · verdes %d · falla %d · no medibles %d**\n' \
      "$n_total" "$n_ok" "$n_fail" "$n_unmeas"
    printf '\n> Un gate en ⚠️ NO MEDIBLE no esta aprobado: esa comprobacion no llego a hacerse.\n'
  } >> "$GITHUB_STEP_SUMMARY"
fi

gate_verdict "$FINAL"
exit "$FINAL"
