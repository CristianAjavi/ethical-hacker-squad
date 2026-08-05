#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# build-changelog.sh — genera la seccion de CHANGELOG de un release de stable.
#
# MODELO DE AMENAZA DE ESTE SCRIPT
#   Los asuntos de commit no son texto de confianza: pueden venir de un PR del
#   loop de conocimiento (bot/knowledge-*), es decir, de contenido derivado de
#   internet. El CHANGELOG se publica y ademas se convierte en el mensaje del
#   tag anotado. Por eso cada asunto se SANEA:
#     - se recorta a una sola linea y a 120 caracteres
#     - se eliminan caracteres de control
#     - se neutralizan las marcas que darian control tipografico o social:
#       backticks (bloques de codigo), '<' '>' (HTML crudo), '[' ']' (enlaces),
#       '@' (menciones que notifican a personas reales) y '#' (auto-enlace a
#       issues/PRs, que permitiria hacer "referencia cruzada" desde el release
#       a cualquier issue del repo).
#   El resultado es texto plano legible, no markdown activo.
#   LO QUE ESTO NO RESUELVE (medido, no lo escondemos): una URL desnuda sigue
#   siendo autoenlazada por GitHub al renderizar. Lo que si se elimina es el
#   enlace DISFRAZADO ([texto](destino)), que es el riesgo real: ahi la etiqueta
#   miente sobre el destino. Una URL visible que dice exactamente adonde va es
#   informacion, no engano.
#
# USO
#   scripts/gh/build-changelog.sh --version <semver> --from <ref|""> --to <sha> \
#       [--date YYYY-MM-DD] [--repo owner/name]
#
# SALIDA: la seccion markdown por stdout.
#
# EXIT CODES
#   0 = generado
#   1 = entrada invalida o rango sin commits
#   2 = NO PUDE MEDIR (falta git o el rango no resuelve)
# ---------------------------------------------------------------------------
set -uo pipefail

die1() { printf 'build-changelog: %s\n' "$*" >&2; exit 1; }
die2() { printf 'build-changelog: NO PUDE MEDIR — %s\n' "$*" >&2; exit 2; }

VERSION=""; FROM=""; TO=""; DATE=""; REPO="${GITHUB_REPOSITORY:-}"
while (( $# > 0 )); do
  case "$1" in
    --version) VERSION="${2:-}"; shift 2 ;;
    --from)    FROM="${2:-}";    shift 2 ;;
    --to)      TO="${2:-}";      shift 2 ;;
    --date)    DATE="${2:-}";    shift 2 ;;
    --repo)    REPO="${2:-}";    shift 2 ;;
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    *) die1 "argumento desconocido: $1" ;;
  esac
done

command -v git >/dev/null 2>&1 || die2 "falta git"
[[ -n "$VERSION" ]] || die1 "falta --version"
[[ -n "$TO" ]] || die1 "falta --to <sha>"
[[ -n "$DATE" ]] || DATE=$(date -u +%Y-%m-%d)

git rev-parse -q --verify "$TO^{commit}" >/dev/null 2>&1 || die2 "el sha '$TO' no resuelve"
if [[ -n "$FROM" ]]; then
  git rev-parse -q --verify "$FROM^{commit}" >/dev/null 2>&1 || die2 "el ref base '$FROM' no resuelve"
  RANGE="${FROM}..${TO}"
else
  RANGE="$TO"
fi

# Saneado: una linea, sin control, sin markdown activo, <=120 caracteres.
sanitize() {
  printf '%s' "$1" \
    | tr '\r\n\t' '   ' \
    | LC_ALL=C tr -d '\000-\037\177' \
    | sed -e 's/[`<>][`<>]*/ /g' -e 's/[][]/ /g' -e 's/@/(at)/g' -e 's/#/(num)/g' \
    | sed -e 's/  */ /g' -e 's/^ //' -e 's/ $//' \
    | cut -c1-120
}

FEATS=""; FIXES=""; SECS=""; OTHERS=""; BREAKS=""
COUNT=0

# UN REGISTRO POR COMMIT. Ver la nota en next-version.sh: el body trae saltos
# de linea propios, asi que un formato '%H<TAB>%s<TAB>%b' hacia que CADA LINEA
# del cuerpo se tratara como un commit distinto. MEDIDO: un solo commit
# producia tres entradas de CHANGELOG, dos de ellas con texto elegido por quien
# escribio el cuerpo y con un "sha" falso (los 7 primeros caracteres de esa
# linea). Es decir, texto no confiable publicado como si fuera un commit real.
SHAS=$(git log --no-merges --format='%H' "$RANGE" 2>/dev/null)
[[ -n "$SHAS" ]] || die1 "no hay commits en el rango '$RANGE'"

while IFS= read -r sha; do
  [[ -n "$sha" ]] || continue
  subject=$(git show -s --format='%s' "$sha")
  body=$(git show -s --format='%b' "$sha" | tr '\r\n' '  ')
  short="${sha:0:7}"
  COUNT=$((COUNT + 1))

  type=$(printf '%s' "$subject" | sed -nE 's/^([a-zA-Z]+)(\([^)]*\))?!?:.*/\1/p' | tr 'A-Z' 'a-z')
  desc=$(printf '%s' "$subject" | sed -E 's/^[a-zA-Z]+(\([^)]*\))?!?:[[:space:]]*//')
  [[ -n "$desc" ]] || desc="$subject"
  desc=$(sanitize "$desc")
  entry="- ${desc} (\`${short}\`)"

  if printf '%s' "$subject" | grep -qE '^[a-zA-Z]+(\([^)]*\))?!:' \
     || printf '%s' "$body" | grep -qE '(^|[[:space:]])BREAKING[ -]CHANGE:'; then
    BREAKS+="${entry}"$'\n'
  fi

  case "$type" in
    feat)              FEATS+="${entry}"$'\n' ;;
    fix)               FIXES+="${entry}"$'\n' ;;
    sec|security)      SECS+="${entry}"$'\n' ;;
    docs|chore|ci|refactor|test|build|perf|style) OTHERS+="${entry}"$'\n' ;;
    *)                 OTHERS+="${entry}"$'\n' ;;
  esac
done <<<"$SHAS"

printf '## %s — %s\n\n' "$VERSION" "$DATE"
if [[ -n "$REPO" ]]; then
  printf 'Promovido a `stable` desde `main@%s`.\n' "${TO:0:7}"
  printf 'Diff: https://github.com/%s/compare/%s...%s\n\n' "$REPO" "${FROM:-$TO}" "$TO"
else
  printf 'Promovido a `stable` desde `main@%s`.\n\n' "${TO:0:7}"
fi

emit() { # $1=titulo $2=cuerpo
  [[ -n "$2" ]] || return 0
  printf '### %s\n\n%s\n' "$1" "$2"
}
emit "Cambios incompatibles" "$BREAKS"
emit "Seguridad" "$SECS"
emit "Nuevo" "$FEATS"
emit "Correcciones" "$FIXES"
emit "Otros" "$OTHERS"

printf '_%s commit(s). Asuntos saneados a texto plano: el CHANGELOG no ejecuta markdown de origen no confiable._\n' "$COUNT"
exit 0
