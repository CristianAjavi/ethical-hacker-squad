#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# next-version.sh — calcula el semver siguiente para el canal stable a partir
# de Conventional Commits, de forma DETERMINISTA y sin dependencias externas.
#
# POR QUE NO release-please / semantic-release
#   Encajan tecnicamente (estrategia `simple` + extra-files con jsonpath sobre
#   $.version), pero su modelo de operacion es "un humano mergea el Release PR".
#   Aqui la promocion a stable es automatica, asi que habria que auto-mergear un
#   PR abierto por un bot dentro de main — exactamente el vector que este repo
#   existe para cerrar — y ademas conceder contents:write + pull-requests:write
#   a otra accion de terceros. Conventional Commits se usa solo como ENTRADA de
#   datos; el calculo vive aqui, en ~100 lineas auditables sin superficie nueva.
#
# USO
#   scripts/gh/next-version.sh --current <semver> --from <ref|""> --to <sha> [--bump auto|patch|minor|major]
#
# SALIDA (stdout, formato clave=valor para $GITHUB_OUTPUT)
#   current_version=...
#   next_version=...
#   bump=major|minor|patch|none
#   commit_count=N
#
# EXIT CODES
#   0 = calculado
#   1 = entrada invalida / nada que publicar
#   2 = NO PUDE MEDIR (falta git o el rango no resuelve)
# ---------------------------------------------------------------------------
set -uo pipefail

SEMVER_RE='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'

die1() { printf 'next-version: %s\n' "$*" >&2; exit 1; }
die2() { printf 'next-version: NO PUDE MEDIR — %s\n' "$*" >&2; exit 2; }

CURRENT=""; FROM=""; TO=""; BUMP="auto"
while (( $# > 0 )); do
  case "$1" in
    --current) CURRENT="${2:-}"; shift 2 ;;
    --from)    FROM="${2:-}";    shift 2 ;;
    --to)      TO="${2:-}";      shift 2 ;;
    --bump)    BUMP="${2:-}";    shift 2 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) die1 "argumento desconocido: $1" ;;
  esac
done

command -v git >/dev/null 2>&1 || die2 "falta git"
[[ -n "$TO" ]] || die1 "falta --to <sha>"
[[ -n "$CURRENT" ]] || CURRENT="0.0.0"
[[ "$CURRENT" =~ $SEMVER_RE ]] || die1 "--current '$CURRENT' no es semver x.y.z"
case "$BUMP" in auto|patch|minor|major) ;; *) die1 "--bump '$BUMP' invalido" ;; esac

git rev-parse -q --verify "$TO^{commit}" >/dev/null 2>&1 || die2 "el sha '$TO' no resuelve a un commit en este clon"

if [[ -n "$FROM" ]]; then
  git rev-parse -q --verify "$FROM^{commit}" >/dev/null 2>&1 || die2 "el ref base '$FROM' no resuelve"
  RANGE="${FROM}..${TO}"
else
  RANGE="$TO"   # historia completa: primer release
fi

# UN REGISTRO POR COMMIT, no una linea por commit.
# Un `git log --format='%H<TAB>%s<TAB>%b'` NO produce una linea por commit: el
# body lleva saltos de linea propios, asi que cada linea del body se leia como
# si fuera otro commit. MEDIDO: un unico commit `docs:` cuyo body contenia la
# linea `feat!: ...` se contaba como 3 commits y forzaba un salto MAJOR. El
# cuerpo del commit es texto no confiable (viene de PRs del loop de
# conocimiento), asi que no puede decidir la version.
# Se enumera primero por SHA y se pide subject y body por separado.
SHAS=$(git log --no-merges --format='%H' "$RANGE" 2>/dev/null)
LOG_RC=$?
(( LOG_RC == 0 )) || die2 "git log fallo sobre el rango '$RANGE'"

COUNT=0
HAS_MAJOR=0
HAS_MINOR=0
while IFS= read -r sha; do
  [[ -n "$sha" ]] || continue
  COUNT=$((COUNT + 1))
  subject=$(git show -s --format='%s' "$sha")
  # el body se aplana a una sola linea: solo se busca un marcador en el.
  body=$(git show -s --format='%b' "$sha" | tr '\r\n' '  ')
  # BREAKING: `tipo!:` en el subject o `BREAKING CHANGE:` en el body.
  if printf '%s' "$subject" | grep -qE '^[a-zA-Z]+(\([^)]*\))?!:'; then HAS_MAJOR=1; fi
  if printf '%s' "$body" | grep -qE '(^|[[:space:]])BREAKING[ -]CHANGE:'; then HAS_MAJOR=1; fi
  if printf '%s' "$subject" | grep -qE '^feat(\([^)]*\))?!?:'; then HAS_MINOR=1; fi
done <<<"$SHAS"

if (( COUNT == 0 )); then
  printf 'current_version=%s\n' "$CURRENT"
  printf 'next_version=%s\n' "$CURRENT"
  printf 'bump=none\n'
  printf 'commit_count=0\n'
  printf 'next-version: no hay commits nuevos en %s — nada que publicar\n' "$RANGE" >&2
  exit 1
fi

if [[ "$BUMP" == "auto" ]]; then
  if   (( HAS_MAJOR )); then BUMP="major"
  elif (( HAS_MINOR )); then BUMP="minor"
  else                       BUMP="patch"
  fi
fi

IFS='.' read -r MA MI PA <<<"$CURRENT"
case "$BUMP" in
  major) MA=$((MA + 1)); MI=0; PA=0 ;;
  minor) MI=$((MI + 1)); PA=0 ;;
  patch) PA=$((PA + 1)) ;;
esac
NEXT="${MA}.${MI}.${PA}"

printf 'current_version=%s\n' "$CURRENT"
printf 'next_version=%s\n' "$NEXT"
printf 'bump=%s\n' "$BUMP"
printf 'commit_count=%s\n' "$COUNT"
exit 0
