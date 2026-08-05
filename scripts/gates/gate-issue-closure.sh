#!/usr/bin/env bash
# gate-issue-closure.sh
#
# DOCTRINA: un issue de falso positivo o falso negativo no se cierra con el arreglo.
# Se cierra con el arreglo MAS el check que impide que reaparezca. Un arreglo sin
# check es una recaida programada.
#
# QUE HACE: si el cuerpo de un PR declara cerrar (Fixes/Closes/Resolves) un issue
# etiquetado como tipo/falso-positivo o tipo/falso-negativo, exige que el PR toque
# al menos un fichero de gates o del corpus de casos. Si no lo toca, falla.
#
# CODIGOS DE SALIDA (distinguibles a proposito):
#   0 = MEDI y esta bien
#   1 = MEDI y FALLA
#   2 = NO PUDE MEDIR (falta cuerpo del PR, falta gh, la API no respondio, etc.)
#       Un rc=0 nunca significa "no lo revise".
#
# SEGURIDAD: este script NUNCA evalua ni ejecuta el cuerpo del PR. Solo lo pasa por
# grep. El cuerpo llega por fichero o por la variable de entorno PR_BODY; jamas se
# interpola en un `run:` de un workflow.
#
# Uso:
#   scripts/gates/gate-issue-closure.sh [opciones]
#
# Opciones:
#   --pr N                 Numero de PR (para resolver cuerpo y ficheros con gh)
#   --repo OWNER/REPO      Repositorio (por defecto: GITHUB_REPOSITORY o el remoto origin)
#   --body-file F          Fichero con el cuerpo del PR (gana sobre PR_BODY y sobre gh)
#   --changed-files F      Fichero con un path por linea (gana sobre git diff y sobre gh)
#   --deleted-files F      Fichero con los paths BORRADOS por el PR (solo tiene sentido
#                          junto a --changed-files; con git o gh se deduce solo).
#                          Un fichero borrado NO cuenta como regresion vigilada.
#   --labels-file F        Mapa offline "NUMERO<TAB o espacio>label" (una linea por label)
#   --base REF             Base para `git diff` (por defecto: GITHUB_BASE_REF, origin/main o main)
#   --emit-refs            Solo imprime los numeros de issue de ESTE repo que el PR dice cerrar
#   --require-link         Falla tambien si el PR no declara ningun cierre (desactivado por defecto)
#   -h, --help             Esta ayuda
#
# Variables de entorno equivalentes: PR_BODY, PR_NUMBER, GITHUB_REPOSITORY,
#   CHANGED_FILES_FILE, DELETED_FILES_FILE, LABELS_FILE, BASE_REF,
#   REGRESSION_LABELS (por defecto "tipo/falso-positivo,tipo/falso-negativo"),
#   EVIDENCE_PATHS   (globs separados por coma; por defecto los de abajo).

set -uo pipefail

RC_OK=0
RC_FAIL=1
RC_UNMEASURABLE=2

REGRESSION_LABELS="${REGRESSION_LABELS:-tipo/falso-positivo,tipo/falso-negativo}"
EVIDENCE_PATHS="${EVIDENCE_PATHS:-scripts/gates/*,tests/*,cases/*}"

PR_NUMBER="${PR_NUMBER:-}"
REPO="${GITHUB_REPOSITORY:-}"
BODY_FILE=""
CHANGED_FILES_FILE="${CHANGED_FILES_FILE:-}"
DELETED_FILES_FILE="${DELETED_FILES_FILE:-}"
LABELS_FILE="${LABELS_FILE:-}"
BASE_REF="${BASE_REF:-}"
EMIT_REFS=0
REQUIRE_LINK=0

TMPDIR_GATE=""
cleanup() { [ -n "$TMPDIR_GATE" ] && rm -rf "$TMPDIR_GATE"; }
trap cleanup EXIT

say()  { printf '%s\n' "$*"; }
note() { printf '  - %s\n' "$*"; }
err()  { printf '%s\n' "$*" >&2; }

usage() { sed -n '2,49p' "$0" | sed 's/^# \{0,1\}//'; }

# Los globs de EVIDENCE_PATHS se trocean con IFS pero NO se expanden contra el disco:
# `set -f` evita que "scripts/gates/*" se convierta en la lista de ficheros existentes.
split_config() {
  local old_ifs="$IFS"
  set -f
  IFS=','
  # shellcheck disable=SC2206
  EVIDENCE_ARR=($EVIDENCE_PATHS)
  # shellcheck disable=SC2206
  REGRESSION_ARR=($REGRESSION_LABELS)
  IFS="$old_ifs"
  set +f
}

while [ $# -gt 0 ]; do
  case "$1" in
    --pr)            PR_NUMBER="${2:-}"; shift 2 ;;
    --repo)          REPO="${2:-}"; shift 2 ;;
    --body-file)     BODY_FILE="${2:-}"; shift 2 ;;
    --changed-files) CHANGED_FILES_FILE="${2:-}"; shift 2 ;;
    --deleted-files) DELETED_FILES_FILE="${2:-}"; shift 2 ;;
    --labels-file)   LABELS_FILE="${2:-}"; shift 2 ;;
    --base)          BASE_REF="${2:-}"; shift 2 ;;
    --emit-refs)     EMIT_REFS=1; shift ;;
    --require-link)  REQUIRE_LINK=1; shift ;;
    -h|--help)       usage; exit "$RC_OK" ;;
    *)               err "opcion desconocida: $1"; usage >&2; exit "$RC_UNMEASURABLE" ;;
  esac
done

split_config

TMPDIR_GATE="$(mktemp -d 2>/dev/null)" || {
  err "NO PUDE MEDIR: no pude crear un directorio temporal."
  exit "$RC_UNMEASURABLE"
}

# ---------------------------------------------------------------------------
# 1. Repositorio
# ---------------------------------------------------------------------------
if [ -z "$REPO" ]; then
  origin="$(git remote get-url origin 2>/dev/null)" || origin=""
  case "$origin" in
    *github.com[:/]*)
      REPO="${origin#*github.com}"
      REPO="${REPO#:}"; REPO="${REPO#/}"; REPO="${REPO%.git}"
      ;;
  esac
fi

# ---------------------------------------------------------------------------
# 2. Cuerpo del PR
# ---------------------------------------------------------------------------
BODY_SRC=""
BODY_PATH="$TMPDIR_GATE/body.txt"
if [ -n "$BODY_FILE" ]; then
  if [ ! -r "$BODY_FILE" ]; then
    err "NO PUDE MEDIR: --body-file '$BODY_FILE' no se puede leer."
    exit "$RC_UNMEASURABLE"
  fi
  cat -- "$BODY_FILE" > "$BODY_PATH"
  BODY_SRC="--body-file $BODY_FILE"
elif [ -n "${PR_BODY:-}" ]; then
  printf '%s\n' "$PR_BODY" > "$BODY_PATH"
  BODY_SRC="variable de entorno PR_BODY"
elif [ -n "$PR_NUMBER" ] && command -v gh >/dev/null 2>&1; then
  if gh pr view "$PR_NUMBER" ${REPO:+--repo "$REPO"} --json body --jq '.body' > "$BODY_PATH" 2>"$TMPDIR_GATE/gh.err"; then
    BODY_SRC="gh pr view $PR_NUMBER"
  else
    err "NO PUDE MEDIR: 'gh pr view $PR_NUMBER' fallo:"
    err "$(cat "$TMPDIR_GATE/gh.err")"
    exit "$RC_UNMEASURABLE"
  fi
else
  err "NO PUDE MEDIR: no hay cuerpo de PR. Pasa --body-file, exporta PR_BODY o pasa --pr N con gh disponible."
  exit "$RC_UNMEASURABLE"
fi

# Quita comentarios HTML: la plantilla de PR lleva ejemplos dentro de <!-- --> y no
# deben contar como declaracion de cierre.
strip_html_comments() {
  awk '
    {
      line = $0
      out = ""
      while (1) {
        if (incomment) {
          p = index(line, "-->")
          if (p == 0) { line = ""; break }
          line = substr(line, p + 3); incomment = 0
        } else {
          p = index(line, "<!--")
          if (p == 0) { out = out line; line = ""; break }
          out = out substr(line, 1, p - 1)
          line = substr(line, p + 4); incomment = 1
        }
      }
      print out
    }
  ' "$1"
}
strip_html_comments "$BODY_PATH" > "$TMPDIR_GATE/body.clean"

# ---------------------------------------------------------------------------
# 3. Referencias de cierre
#    Palabras clave documentadas por GitHub: close, closes, closed, fix, fixes,
#    fixed, resolve, resolves, resolved. Formas: "#N" y "OWNER/REPO#N".
#    La forma "KEYWORD <url del issue>" NO esta documentada como cierre, pero
#    declara la intencion de cerrar, asi que el gate la cuenta (direccion estricta).
# ---------------------------------------------------------------------------
KEYWORDS='(close[sd]?|fix(e[sd])?|resolve[sd]?)'
REFPART='(#[0-9]+|[A-Za-z0-9._-]+/[A-Za-z0-9._-]+#[0-9]+|https://github\.com/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+/issues/[0-9]+)'

grep -Eio "(^|[^A-Za-z])${KEYWORDS}[[:space:]]*:?[[:space:]]+${REFPART}" \
  "$TMPDIR_GATE/body.clean" > "$TMPDIR_GATE/matches" 2>/dev/null

: > "$TMPDIR_GATE/refs.mine"
: > "$TMPDIR_GATE/refs.foreign"

repo_lc="$(printf '%s' "$REPO" | tr '[:upper:]' '[:lower:]')"

while IFS= read -r m; do
  [ -n "$m" ] || continue
  ref="${m##* }"          # el ultimo token es la referencia
  ref="${ref##*[[:space:]]}"
  case "$ref" in
    https://github.com/*/issues/*)
      num="${ref##*/}"
      owner_repo="${ref#https://github.com/}"
      owner_repo="${owner_repo%/issues/*}"
      ;;
    \#*)
      num="${ref#\#}"
      owner_repo="$repo_lc"
      ;;
    */*\#*)
      num="${ref##*\#}"
      owner_repo="${ref%%\#*}"
      ;;
    *) continue ;;
  esac
  owner_repo="$(printf '%s' "$owner_repo" | tr '[:upper:]' '[:lower:]')"
  case "$num" in ''|*[!0-9]*) continue ;; esac
  if [ -n "$repo_lc" ] && [ "$owner_repo" != "$repo_lc" ]; then
    printf '%s#%s\n' "$owner_repo" "$num" >> "$TMPDIR_GATE/refs.foreign"
  elif [ -z "$repo_lc" ] && [ "$owner_repo" != "$repo_lc" ] && [ "$owner_repo" != "" ]; then
    # No sabemos cual es "este" repo: no podemos afirmar que sea ajeno ni propio.
    printf '%s#%s\n' "$owner_repo" "$num" >> "$TMPDIR_GATE/refs.foreign"
  else
    printf '%s\n' "$num" >> "$TMPDIR_GATE/refs.mine"
  fi
done < "$TMPDIR_GATE/matches"

sort -un "$TMPDIR_GATE/refs.mine" -o "$TMPDIR_GATE/refs.mine"
sort -u "$TMPDIR_GATE/refs.foreign" -o "$TMPDIR_GATE/refs.foreign"

if [ "$EMIT_REFS" -eq 1 ]; then
  cat "$TMPDIR_GATE/refs.mine"
  exit "$RC_OK"
fi

n_mine=$(wc -l < "$TMPDIR_GATE/refs.mine" | tr -d ' ')
n_foreign=$(wc -l < "$TMPDIR_GATE/refs.foreign" | tr -d ' ')

say "gate-issue-closure"
say "=================="
say "Repositorio        : ${REPO:-<desconocido>}"
say "Cuerpo del PR      : $BODY_SRC"
say "Labels que exigen regresion: $REGRESSION_LABELS"
say "Rutas que cuentan como regresion vigilada: $EVIDENCE_PATHS"
say ""

if [ "$n_mine" -eq 0 ]; then
  say "REVISADO: el cuerpo del PR no declara cerrar ningun issue de este repositorio."
  if [ "$n_foreign" -gt 0 ]; then
    say "NO REVISADO: referencias a otros repositorios (no puedo juzgar su taxonomia):"
    while IFS= read -r f; do note "$f"; done < "$TMPDIR_GATE/refs.foreign"
  fi
  if [ "$REQUIRE_LINK" -eq 1 ]; then
    say ""
    say "FALLA: --require-link activo y el PR no declara ningun 'Fixes #N'."
    exit "$RC_FAIL"
  fi
  say ""
  say "Resultado: OK (nada que exigir)."
  exit "$RC_OK"
fi

# ---------------------------------------------------------------------------
# 4. Labels de cada issue referenciado
# ---------------------------------------------------------------------------
labels_of() { # $1 = numero de issue -> imprime un label por linea; rc 2 si no se pudo
  local n="$1"
  if [ -n "$LABELS_FILE" ]; then
    if [ ! -r "$LABELS_FILE" ]; then return 2; fi
    # Si el issue NO aparece en el mapa, esto es "no pude medir", no "no tiene labels".
    # Un fichero incompleto no puede dar via libre a un PR.
    local out
    if out="$(awk -v want="$n" '
      { gsub(/\r/, "") }
      $1 == want { found=1; $1=""; sub(/^[ \t]+/, ""); if (length($0)) print $0 }
      END { exit(found ? 0 : 1) }
    ' "$LABELS_FILE")"; then
      printf '%s\n' "$out"
      return 0
    fi
    return 2
  fi
  command -v gh >/dev/null 2>&1 || return 2
  [ -n "$REPO" ] || return 2
  local out attempt
  for attempt in 1 2; do
    if out="$(gh api "repos/$REPO/issues/$n" --jq '.labels[].name' 2>"$TMPDIR_GATE/api.err")"; then
      printf '%s\n' "$out"
      return 0
    fi
    # 404 real (issue inexistente) vs fallo transitorio de la API: reintentamos una vez
    # y, si seguimos sin certeza, es NO PUDE MEDIR, nunca un fallo del PR.
    sleep 2
  done
  return 2
}

is_regression_label() {
  local l="$1" want
  for want in "${REGRESSION_ARR[@]}"; do
    want="$(printf '%s' "$want" | tr -d '[:space:]')"
    [ -n "$want" ] || continue
    [ "$l" = "$want" ] && return 0
  done
  return 1
}

: > "$TMPDIR_GATE/needs_regression"
unmeasured=0
say "Issues que el PR dice cerrar en este repositorio:"
while IFS= read -r n; do
  [ -n "$n" ] || continue
  if lbls="$(labels_of "$n")"; then
    hit=""
    while IFS= read -r l; do
      [ -n "$l" ] || continue
      if is_regression_label "$l"; then hit="$l"; fi
    done <<EOF
$lbls
EOF
    if [ -n "$hit" ]; then
      note "#$n  labels: $(printf '%s' "$lbls" | tr '\n' ' ')  -> EXIGE regresion vigilada ($hit)"
      printf '%s\n' "$n" >> "$TMPDIR_GATE/needs_regression"
    else
      note "#$n  labels: $(printf '%s' "$lbls" | tr '\n' ' ')  -> no exige regresion vigilada"
    fi
  else
    note "#$n  NO PUDE LEER SUS LABELS (gh ausente, sin repo, o la API no respondio)"
    unmeasured=1
  fi
done < "$TMPDIR_GATE/refs.mine"

if [ "$n_foreign" -gt 0 ]; then
  say ""
  say "NO REVISADO: referencias a otros repositorios:"
  while IFS= read -r f; do note "$f"; done < "$TMPDIR_GATE/refs.foreign"
fi

if [ "$unmeasured" -eq 1 ]; then
  say ""
  say "Resultado: NO PUDE MEDIR. No afirmo que el PR este bien ni que este mal."
  exit "$RC_UNMEASURABLE"
fi

if [ ! -s "$TMPDIR_GATE/needs_regression" ]; then
  say ""
  say "Resultado: OK. Ningun issue cerrado es de tipo falso positivo ni falso negativo."
  exit "$RC_OK"
fi

# ---------------------------------------------------------------------------
# 5. Ficheros que toca el PR
# ---------------------------------------------------------------------------
CHANGED="$TMPDIR_GATE/changed.txt"
# Ficheros BORRADOS por el PR. Borrar el gate que te delata NO es vigilar la regresion:
# `git diff --name-only` lista los borrados igual que los añadidos, asi que sin esto un
# PR podia cerrar un falso positivo BORRANDO scripts/gates/... y salir en verde.
DELETED="$TMPDIR_GATE/deleted.txt"
: > "$DELETED"
DELETED_SRC=""            # vacio = no se pudo saber que se borro
CHANGED_SRC=""
if [ -n "$CHANGED_FILES_FILE" ]; then
  if [ ! -r "$CHANGED_FILES_FILE" ]; then
    err "NO PUDE MEDIR: --changed-files '$CHANGED_FILES_FILE' no se puede leer."
    exit "$RC_UNMEASURABLE"
  fi
  cat -- "$CHANGED_FILES_FILE" > "$CHANGED"
  CHANGED_SRC="--changed-files $CHANGED_FILES_FILE"
  if [ -n "$DELETED_FILES_FILE" ]; then
    if [ ! -r "$DELETED_FILES_FILE" ]; then
      err "NO PUDE MEDIR: --deleted-files '$DELETED_FILES_FILE' no se puede leer."
      exit "$RC_UNMEASURABLE"
    fi
    cat -- "$DELETED_FILES_FILE" > "$DELETED"
    DELETED_SRC="--deleted-files $DELETED_FILES_FILE"
  fi
else
  base="$BASE_REF"
  if [ -z "$base" ] && [ -n "${GITHUB_BASE_REF:-}" ]; then base="origin/$GITHUB_BASE_REF"; fi
  if [ -z "$base" ]; then
    if git rev-parse --verify -q origin/main >/dev/null 2>&1; then base="origin/main"
    elif git rev-parse --verify -q main >/dev/null 2>&1; then base="main"
    fi
  fi
  if [ -n "$base" ] && git rev-parse --verify -q "$base" >/dev/null 2>&1; then
    if ! git diff --name-only "$base"...HEAD > "$CHANGED" 2>"$TMPDIR_GATE/git.err"; then
      err "NO PUDE MEDIR: 'git diff $base...HEAD' fallo: $(cat "$TMPDIR_GATE/git.err")"
      exit "$RC_UNMEASURABLE"
    fi
    CHANGED_SRC="git diff --name-only $base...HEAD"
    if ! git diff --name-only --diff-filter=D "$base"...HEAD > "$DELETED" 2>/dev/null; then
      err "NO PUDE MEDIR: no pude listar los ficheros borrados con --diff-filter=D."
      exit "$RC_UNMEASURABLE"
    fi
    DELETED_SRC="git diff --name-only --diff-filter=D $base...HEAD"
  elif [ -n "$PR_NUMBER" ] && command -v gh >/dev/null 2>&1 && [ -n "$REPO" ]; then
    if ! gh api --paginate "repos/$REPO/pulls/$PR_NUMBER/files" --jq '.[].filename' > "$CHANGED" 2>"$TMPDIR_GATE/api.err"; then
      err "NO PUDE MEDIR: la API de ficheros del PR no respondio: $(cat "$TMPDIR_GATE/api.err")"
      exit "$RC_UNMEASURABLE"
    fi
    CHANGED_SRC="gh api repos/$REPO/pulls/$PR_NUMBER/files"
    if ! gh api --paginate "repos/$REPO/pulls/$PR_NUMBER/files" \
         --jq '.[] | select(.status == "removed") | .filename' > "$DELETED" 2>"$TMPDIR_GATE/api.err"; then
      err "NO PUDE MEDIR: no pude saber que ficheros borra el PR: $(cat "$TMPDIR_GATE/api.err")"
      exit "$RC_UNMEASURABLE"
    fi
    DELETED_SRC="gh api ... (status == removed)"
  else
    err "NO PUDE MEDIR: no pude obtener la lista de ficheros del PR (sin base git valida y sin gh)."
    exit "$RC_UNMEASURABLE"
  fi
fi

matches_evidence() {
  local f="$1" p
  for p in "${EVIDENCE_ARR[@]}"; do
    p="$(printf '%s' "$p" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -n "$p" ] || continue
    # shellcheck disable=SC2053
    if [[ "$f" == $p ]]; then return 0; fi
  done
  return 1
}

is_deleted() { # $1 = path -> rc 0 si el PR lo borra
  [ -s "$DELETED" ] || return 1
  awk -v want="$1" '$0 == want { found=1 } END { exit(found ? 0 : 1) }' "$DELETED"
}

: > "$TMPDIR_GATE/evidence.hits"
: > "$TMPDIR_GATE/evidence.deleted"
n_changed=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n_changed=$((n_changed + 1))
  if matches_evidence "$f"; then
    if is_deleted "$f"; then
      printf '%s\n' "$f" >> "$TMPDIR_GATE/evidence.deleted"
    else
      printf '%s\n' "$f" >> "$TMPDIR_GATE/evidence.hits"
    fi
  fi
done < "$CHANGED"

say ""
say "Ficheros del PR    : $n_changed  (fuente: $CHANGED_SRC)"
if [ -n "$DELETED_SRC" ]; then
  say "Ficheros borrados  : $(wc -l < "$DELETED" | tr -d ' ')  (fuente: $DELETED_SRC)"
else
  say "Ficheros borrados  : NO REVISADO (no se me dijo cuales borra el PR; usa --deleted-files)"
fi
if [ -s "$TMPDIR_GATE/evidence.deleted" ]; then
  say "Ficheros de regresion que el PR BORRA (no cuentan como vigilancia):"
  while IFS= read -r f; do note "$f"; done < "$TMPDIR_GATE/evidence.deleted"
fi
if [ -s "$TMPDIR_GATE/evidence.hits" ]; then
  say "Ficheros que cuentan como regresion vigilada:"
  while IFS= read -r f; do note "$f"; done < "$TMPDIR_GATE/evidence.hits"
  say ""
  say "Resultado: OK. El PR cierra issues de falso positivo/negativo Y toca un gate o el corpus de casos."
  say "AVISO (no lo puedo medir yo): que ese fichero contenga de verdad el caso de esta regresion"
  say "       y que el PR muestre la ejecucion en negativo, lo verifica la revision humana."
  exit "$RC_OK"
fi

say "Ficheros que cuentan como regresion vigilada: NINGUNO"
say ""
say "Resultado: FALLA."
say "El PR dice cerrar estos issues:"
while IFS= read -r n; do note "#$n (falso positivo o falso negativo)"; done < "$TMPDIR_GATE/needs_regression"
if [ -s "$TMPDIR_GATE/evidence.deleted" ]; then
  say "...y lo unico que toca de: $EVIDENCE_PATHS lo BORRA. Borrar el check que te delata"
  say "   no es vigilar la regresion."
else
  say "...pero no toca ningun fichero de: $EVIDENCE_PATHS"
fi
say ""
say "Un arreglo sin check que lo vigile es una recaida programada. Añade el caso de"
say "regresion (o el gate) que falle si el defecto vuelve, y declaralo en la seccion"
say "'Que quedo vigilando la regresion' de la plantilla de PR."
exit "$RC_FAIL"
