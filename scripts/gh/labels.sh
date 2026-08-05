#!/usr/bin/env bash
# labels.sh — taxonomia de labels del repositorio, idempotente y en seco por defecto.
#
# POR QUE EXISTE: los issue forms de .github/ISSUE_TEMPLATE aplican labels cableados
# (`tipo/*`, `origen/*`, `estado/needs-triage`). Si un label no existe en el repo,
# GitHub simplemente no lo aplica y el triaje determinista se rompe en silencio.
# Este script es la fuente de verdad de esa taxonomia y el gate que detecta la deriva.
#
# MODOS:
#   (por defecto)  dry-run: imprime el plan (crear / actualizar / sin cambios). No muta nada.
#   --check        gate de solo lectura: falla si falta algun label o si difiere color/descripcion.
#   --apply        aplica los cambios (POST/PATCH). Requiere confirmacion explicita.
#
# CODIGOS DE SALIDA:
#   0 = MEDI y esta bien
#       (dry-run: el plan se calculo entero | --check: la taxonomia esta completa y sin deriva
#        | --apply: se aplicaron todos los cambios)
#   1 = MEDI y FALLA
#       (--check: falta algun label o hay deriva | --apply: alguna mutacion fallo)
#   2 = NO PUDE MEDIR
#       (no hay gh, no hay sesion, no se conoce el repo, o la API no respondio)
#
# NUNCA borra labels: renombrar o eliminar un label mueve issues historicos y eso se
# decide a mano. Los labels sobrantes se listan como aviso, no se tocan.
#
# Uso:
#   scripts/gh/labels.sh [--repo OWNER/REPO] [--check | --apply] [--json] [-h]

set -uo pipefail

RC_OK=0
RC_FAIL=1
RC_UNMEASURABLE=2

MODE="dry-run"
REPO="${GITHUB_REPOSITORY:-}"
JSON_OUT=0

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)  REPO="${2:-}"; shift 2 ;;
    --check) MODE="check"; shift ;;
    --apply) MODE="apply"; shift ;;
    --dry-run) MODE="dry-run"; shift ;;
    --json)  JSON_OUT=1; shift ;;
    -h|--help) usage; exit "$RC_OK" ;;
    *) printf 'opcion desconocida: %s\n' "$1" >&2; usage >&2; exit "$RC_UNMEASURABLE" ;;
  esac
done

# ---------------------------------------------------------------------------
# TAXONOMIA  —  "nombre|color|descripcion"
# Sin acentos en los nombres: viajan en la ruta de la URL de la API.
# ---------------------------------------------------------------------------
LABELS='
tipo/falso-positivo|d93f0b|El escuadron reporto algo que no es explotable
tipo/falso-negativo|b60205|El escuadron no vio un hallazgo real
tipo/knowledge-gap|0e8a16|Falta cobertura, tecnica o estandar en el corpus
tipo/bug|d73a4a|El plugin no hace lo que dice (instalacion, flujo, formato)
tipo/mejora|a2eeef|Mejora de una capacidad existente
tipo/documentacion|0075ca|Solo documentacion o textos de la skill
tipo/mantenimiento|ededed|Infraestructura del repo, CI, dependencias
area/security-lead|5319e7|Orquestacion, seleccion de roles, informe final
area/web-api|5319e7|AppSec web, backend y API
area/mobile|5319e7|Android, iOS y APK
area/infra-cloud|5319e7|Infraestructura, nube, contenedores
area/supply-chain|5319e7|Dependencias, secretos y cadena de suministro
area/ai-safety|5319e7|IA, agentes, LLM y chatbots
area/privacy-abuse|5319e7|Privacidad, datos personales y abuso de logica
area/remediator|5319e7|Reparacion de hallazgos confirmados
area/verifier|5319e7|Verificacion independiente de correcciones
area/plugin|1d76db|Empaquetado, marketplace y versionado
area/ci|1d76db|Workflows, gates y scripts del repositorio
origen/humano|c5def5|Lo abrio una persona
origen/loop|c5def5|Lo abrio el loop automatico de conocimiento
severidad/critica|b60205|Impacto critico
severidad/alta|d93f0b|Impacto alto
severidad/media|fbca04|Impacto medio
severidad/baja|c2e0c6|Impacto bajo
severidad/informativa|ededed|Sin impacto directo, informativo
estado/needs-triage|fef2c0|Sin clasificar todavia
estado/confirmado|0e8a16|Reproducido y aceptado
estado/no-reproducible|ededed|No se pudo reproducir con lo aportado
estado/necesita-info|fbca04|Falta informacion de quien lo reporto
estado/rechazado|ededed|Fuera de alcance o no se va a arreglar
estado/en-reposo|c5def5|En periodo de reposo antes de promocionar a stable
estado/bloqueado|d4c5f9|Depende de algo externo
canal/latest|bfd4f2|Afecta al canal latest (rama main)
canal/stable|bfd4f2|Afecta al canal stable (rama stable)
'

# ---------------------------------------------------------------------------
# Prerrequisitos
# ---------------------------------------------------------------------------
if ! command -v gh >/dev/null 2>&1; then
  printf 'NO PUDE MEDIR: falta el binario gh (https://cli.github.com).\n' >&2
  exit "$RC_UNMEASURABLE"
fi
if ! command -v jq >/dev/null 2>&1; then
  printf 'NO PUDE MEDIR: falta jq.\n' >&2
  exit "$RC_UNMEASURABLE"
fi

if [ -z "$REPO" ]; then
  origin="$(git remote get-url origin 2>/dev/null)" || origin=""
  case "$origin" in
    *github.com[:/]*)
      REPO="${origin#*github.com}"; REPO="${REPO#:}"; REPO="${REPO#/}"; REPO="${REPO%.git}" ;;
  esac
fi
if [ -z "$REPO" ]; then
  printf 'NO PUDE MEDIR: no se cual es el repositorio. Pasa --repo OWNER/REPO.\n' >&2
  exit "$RC_UNMEASURABLE"
fi

# Una taxonomia vacia hacia que --check dijera "OK. Taxonomia completa y sin deriva"
# con rc=0 habiendo comprobado CERO labels: un rc=0 que significaba "no revise nada".
# Sin declaraciones no hay nada que medir, y eso es NO PUDE MEDIR.
N_DECLARED="$(printf '%s\n' "$LABELS" | grep -c '|')"
if [ "$N_DECLARED" -eq 0 ]; then
  printf 'NO PUDE MEDIR: la taxonomia LABELS esta vacia (0 labels declarados).\n' >&2
  printf 'Un "sin deriva" sobre cero labels no es una medicion.\n' >&2
  exit "$RC_UNMEASURABLE"
fi

TMPD="$(mktemp -d)" || { printf 'NO PUDE MEDIR: no pude crear temporal.\n' >&2; exit "$RC_UNMEASURABLE"; }
trap 'rm -rf "$TMPD"' EXIT

# Estado actual del repo: una sola llamada paginada. Si falla, NO PUDE MEDIR.
if ! gh api --paginate "repos/$REPO/labels" --jq '.[] | [.name, .color, (.description // "")] | @tsv' \
     > "$TMPD/actual.tsv" 2>"$TMPD/api.err"; then
  printf 'NO PUDE MEDIR: la API de labels no respondio para %s:\n%s\n' "$REPO" "$(cat "$TMPD/api.err")" >&2
  exit "$RC_UNMEASURABLE"
fi

lookup() { # $1 nombre -> imprime "color\tdescripcion", rc 1 si no existe
  awk -F'\t' -v n="$1" '$1 == n { print $2 "\t" $3; found=1 } END { exit(found ? 0 : 1) }' "$TMPD/actual.tsv"
}

urlenc_name() { printf '%s' "$1" | sed 's|/|%2F|g'; }

n_create=0; n_update=0; n_same=0; n_err=0
: > "$TMPD/plan.txt"

printf 'labels.sh\n=========\n'
printf 'Repositorio : %s\n' "$REPO"
printf 'Modo        : %s\n' "$MODE"
printf 'Taxonomia   : %s labels declarados\n\n' "$N_DECLARED"

while IFS='|' read -r name color desc; do
  [ -n "${name:-}" ] || continue
  case "$name" in \#*) continue ;; esac

  if cur="$(lookup "$name")"; then
    cur_color="${cur%%	*}"
    cur_desc="${cur#*	}"
    if [ "$cur_color" = "$color" ] && [ "$cur_desc" = "$desc" ]; then
      n_same=$((n_same + 1))
      printf '  =  %-28s sin cambios\n' "$name"
      continue
    fi
    n_update=$((n_update + 1))
    printf '  ~  %-28s ACTUALIZAR color %s->%s | descripcion "%s"->"%s"\n' \
      "$name" "$cur_color" "$color" "$cur_desc" "$desc"
    printf 'update\t%s\t%s\t%s\n' "$name" "$color" "$desc" >> "$TMPD/plan.txt"
  else
    n_create=$((n_create + 1))
    printf '  +  %-28s CREAR (color %s)\n' "$name" "$color"
    printf 'create\t%s\t%s\t%s\n' "$name" "$color" "$desc" >> "$TMPD/plan.txt"
  fi
done <<EOF
$LABELS
EOF

# Labels que existen en el repo y no estan declarados: se avisan, no se tocan.
: > "$TMPD/extra.txt"
while IFS=$'\t' read -r name _color _desc; do
  [ -n "${name:-}" ] || continue
  # Comparacion EXACTA del nombre: con grep -F "$name|" el label por defecto "bug"
  # casaria contra la linea "tipo/bug|..." y quedaria oculto.
  if ! printf '%s\n' "$LABELS" | awk -F'|' -v n="$name" '$1 == n { found=1 } END { exit(found?0:1) }'; then
    printf '%s\n' "$name" >> "$TMPD/extra.txt"
  fi
done < "$TMPD/actual.tsv"

printf '\nResumen: crear=%d actualizar=%d sin_cambios=%d\n' "$n_create" "$n_update" "$n_same"
if [ -s "$TMPD/extra.txt" ]; then
  printf 'AVISO (no se tocan, se borran a mano si procede): labels no declarados en la taxonomia:\n'
  while IFS= read -r e; do printf '  ?  %s\n' "$e"; done < "$TMPD/extra.txt"
fi

if [ "$JSON_OUT" -eq 1 ]; then
  jq -n --argjson c "$n_create" --argjson u "$n_update" --argjson s "$n_same" \
        --arg repo "$REPO" --arg mode "$MODE" \
        '{repo:$repo, mode:$mode, create:$c, update:$u, unchanged:$s}'
fi

case "$MODE" in
  check)
    printf '\nREVISADO: existencia, color y descripcion de los %d labels declarados.\n' \
      "$N_DECLARED"
    printf 'NO REVISADO: labels no declarados (listados arriba como aviso).\n'
    if [ "$n_create" -gt 0 ] || [ "$n_update" -gt 0 ]; then
      printf '\nResultado: FALLA. La taxonomia del repo no coincide con scripts/gh/labels.sh.\n'
      printf 'Arreglalo con: scripts/gh/labels.sh --apply\n'
      exit "$RC_FAIL"
    fi
    printf '\nResultado: OK. Taxonomia completa y sin deriva.\n'
    exit "$RC_OK"
    ;;
  dry-run)
    printf '\nEsto ha sido un DRY-RUN: no se ha mutado nada.\n'
    printf 'Para aplicarlo: scripts/gh/labels.sh --apply   (requiere permiso de escritura en el repo)\n'
    printf 'Para usarlo como gate: scripts/gh/labels.sh --check\n'
    exit "$RC_OK"
    ;;
  apply)
    if [ ! -s "$TMPD/plan.txt" ]; then
      printf '\nNada que aplicar. Resultado: OK.\n'
      exit "$RC_OK"
    fi
    printf '\nAplicando %d cambios...\n' "$(wc -l < "$TMPD/plan.txt" | tr -d ' ')"
    while IFS=$'\t' read -r action name color desc; do
      [ -n "${action:-}" ] || continue
      if [ "$action" = "create" ]; then
        if gh api -X POST "repos/$REPO/labels" \
             -f name="$name" -f color="$color" -f description="$desc" >/dev/null 2>"$TMPD/err"; then
          printf '  +  %s creado\n' "$name"
        else
          n_err=$((n_err + 1)); printf '  !  %s FALLO: %s\n' "$name" "$(cat "$TMPD/err")" >&2
        fi
      else
        if gh api -X PATCH "repos/$REPO/labels/$(urlenc_name "$name")" \
             -f new_name="$name" -f color="$color" -f description="$desc" >/dev/null 2>"$TMPD/err"; then
          printf '  ~  %s actualizado\n' "$name"
        else
          n_err=$((n_err + 1)); printf '  !  %s FALLO: %s\n' "$name" "$(cat "$TMPD/err")" >&2
        fi
      fi
    done < "$TMPD/plan.txt"
    if [ "$n_err" -gt 0 ]; then
      printf '\nResultado: FALLA. %d mutaciones fallaron. Es idempotente: puedes reejecutarlo.\n' "$n_err"
      exit "$RC_FAIL"
    fi
    printf '\nResultado: OK. Reejecutalo con --check para confirmar que no queda deriva.\n'
    exit "$RC_OK"
    ;;
esac

printf 'NO PUDE MEDIR: modo desconocido "%s".\n' "$MODE" >&2
exit "$RC_UNMEASURABLE"
