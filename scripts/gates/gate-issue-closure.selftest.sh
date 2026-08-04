#!/usr/bin/env bash
# Autoprueba de gate-issue-closure.sh. Un gate que nunca se ha visto fallar no es un
# gate: aqui se prueba EN NEGATIVO (rc=1) y en "no pude medir" (rc=2), no solo en verde.
#
# Es offline: no toca la red ni GitHub. Todo entra por --body-file, --changed-files
# y --labels-file.
#
# Codigos de salida: 0 = todos los casos pasan | 1 = algun caso falla | 2 = no pude medir.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-issue-closure.sh"
REPO="owner/repo"

[ -x "$GATE" ] || { printf 'NO PUDE MEDIR: %s no es ejecutable.\n' "$GATE" >&2; exit 2; }

T="$(mktemp -d)" || { printf 'NO PUDE MEDIR: sin temporal.\n' >&2; exit 2; }
trap 'rm -rf "$T"' EXIT

cat > "$T/labels.txt" <<'EOF'
10 tipo/falso-positivo
10 origen/humano
11 tipo/falso-negativo
12 tipo/bug
12 estado/needs-triage
99 tipo/falso-positivo
EOF

printf 'scripts/gates/gate-issue-closure.sh\n' > "$T/files.gate"
printf 'tests/cases/pickle-worker.md\n'        > "$T/files.case"
printf 'README.md\nskills/ethical-hacker-squad/SKILL.md\n' > "$T/files.norel"
: > "$T/files.empty"

pass=0; fail=0
check() { # $1 nombre  $2 rc esperado  $3.. comando
  local name="$1" want="$2"; shift 2
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ]; then
    printf '  ok    %-58s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf '  FALLA %-58s rc=%s (esperado %s)\n' "$name" "$rc" "$want"; fail=$((fail+1))
    printf '%s\n' "$out" | sed 's/^/        | /'
  fi
}

printf 'Autoprueba de gate-issue-closure.sh\n===================================\n'

# --- rc=1: MEDI y FALLA ----------------------------------------------------
printf 'Fixes #10\n' > "$T/b1"
check "falso positivo sin regresion vigilada" 1 \
  "$GATE" --repo "$REPO" --body-file "$T/b1" --labels-file "$T/labels.txt" --changed-files "$T/files.norel"

check "falso positivo sin ningun fichero tocado" 1 \
  "$GATE" --repo "$REPO" --body-file "$T/b1" --labels-file "$T/labels.txt" --changed-files "$T/files.empty"

printf 'Resolves #11\n' > "$T/b2"
check "falso negativo sin regresion vigilada" 1 \
  "$GATE" --repo "$REPO" --body-file "$T/b2" --labels-file "$T/labels.txt" --changed-files "$T/files.norel"

printf 'Cierro esto. Fixes https://github.com/owner/repo/issues/10\n' > "$T/b3"
check "forma 'keyword + URL' tambien cuenta como cierre" 1 \
  "$GATE" --repo "$REPO" --body-file "$T/b3" --labels-file "$T/labels.txt" --changed-files "$T/files.norel"

printf 'Cambio suelto sin issue.\n' > "$T/b4"
check "--require-link sin ningun cierre declarado" 1 \
  "$GATE" --repo "$REPO" --body-file "$T/b4" --labels-file "$T/labels.txt" --changed-files "$T/files.gate" --require-link

# --- rc=0: MEDI y esta bien ------------------------------------------------
check "falso positivo + gate tocado" 0 \
  "$GATE" --repo "$REPO" --body-file "$T/b1" --labels-file "$T/labels.txt" --changed-files "$T/files.gate"

check "falso negativo + caso del corpus tocado" 0 \
  "$GATE" --repo "$REPO" --body-file "$T/b2" --labels-file "$T/labels.txt" --changed-files "$T/files.case"

printf 'Closes #12\n' > "$T/b5"
check "issue de tipo bug: no se exige regresion" 0 \
  "$GATE" --repo "$REPO" --body-file "$T/b5" --labels-file "$T/labels.txt" --changed-files "$T/files.norel"

check "PR que no declara ningun cierre" 0 \
  "$GATE" --repo "$REPO" --body-file "$T/b4" --labels-file "$T/labels.txt" --changed-files "$T/files.norel"

printf 'Fixes otro/proyecto#10\n' > "$T/b6"
check "cierre en OTRO repositorio: no se juzga" 0 \
  "$GATE" --repo "$REPO" --body-file "$T/b6" --labels-file "$T/labels.txt" --changed-files "$T/files.norel"

printf 'Cambio de docs.\n<!-- ejemplo de la plantilla: Fixes #99 -->\nNada mas.\n' > "$T/b7"
check "referencia dentro de comentario HTML: ignorada" 0 \
  "$GATE" --repo "$REPO" --body-file "$T/b7" --labels-file "$T/labels.txt" --changed-files "$T/files.norel"

printf 'Habla de prefixes #10 y de suffixes #10 sin cerrarlos.\n' > "$T/b8"
check "palabra que solo CONTIENE 'fixes' no cuenta" 0 \
  "$GATE" --repo "$REPO" --body-file "$T/b8" --labels-file "$T/labels.txt" --changed-files "$T/files.norel"

# --- rc=2: NO PUDE MEDIR ---------------------------------------------------
check "sin cuerpo de PR" 2 \
  env -u PR_BODY "$GATE" --repo "$REPO" --labels-file "$T/labels.txt" --changed-files "$T/files.gate"

check "mapa de labels ilegible" 2 \
  "$GATE" --repo "$REPO" --body-file "$T/b1" --labels-file "$T/no-existe.txt" --changed-files "$T/files.gate"

printf 'Fixes #4242\n' > "$T/b10"
check "issue ausente del mapa de labels (no es 'sin labels')" 2 \
  "$GATE" --repo "$REPO" --body-file "$T/b10" --labels-file "$T/labels.txt" --changed-files "$T/files.norel"

check "lista de ficheros ilegible" 2 \
  "$GATE" --repo "$REPO" --body-file "$T/b1" --labels-file "$T/labels.txt" --changed-files "$T/no-existe.txt"

check "opcion desconocida" 2 "$GATE" --lo-que-sea

# --- --emit-refs -----------------------------------------------------------
printf 'Fixes #10\ncloses #11\nresolved #10\n' > "$T/b9"
got="$("$GATE" --repo "$REPO" --body-file "$T/b9" --emit-refs 2>&1 | tr '\n' ' ' | sed 's/ *$//')"
if [ "$got" = "10 11" ]; then
  printf '  ok    %-58s "%s"\n' "--emit-refs deduplica y ordena" "$got"; pass=$((pass+1))
else
  printf '  FALLA %-58s "%s" (esperado "10 11")\n' "--emit-refs deduplica y ordena" "$got"; fail=$((fail+1))
fi

printf '\nResumen: %d ok, %d fallos\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
printf 'Resultado: OK. El gate falla cuando debe fallar y distingue "no pude medir".\n'
exit 0
