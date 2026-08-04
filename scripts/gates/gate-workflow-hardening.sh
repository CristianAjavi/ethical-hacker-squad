#!/usr/bin/env bash
# scripts/gates/gate-workflow-hardening.sh
#
# Gate PROPIO de endurecimiento de GitHub Actions. No depende de zizmor, de
# actionlint, de red ni de ningun paquete: solo awk POSIX. Es el gate que sigue
# midiendo cuando el resto de la cadena de herramientas no esta disponible.
#
# Verifica, sobre .github/workflows/*.yml:
#   1. Que ningun workflow use `pull_request_target` (ni ningun otro disparador
#      fuera de: schedule, workflow_dispatch, push, pull_request).
#   2. Que el workflow declare `permissions: {}` y que TODO trabajo declare su
#      propio bloque `permissions:`.
#   3. Que toda accion de tercero este fijada por SHA de 40 caracteres, con su
#      comentario `# vX.Y.Z` (Dependabot lo necesita para actualizar el pin).
#   4. Que ningun workflow alcanzable por terceros (`pull_request`, que tambien
#      llega desde forks) referencie secretos distintos de GITHUB_TOKEN, ni use
#      `secrets: inherit`.
#
# Codigos de salida: 0 = medido y bien | 1 = medido y falla | 2 = no pude medir.
#
# Uso:
#   scripts/gates/gate-workflow-hardening.sh              # audita el repo
#   scripts/gates/gate-workflow-hardening.sh --dir DIR    # audita otro directorio
#   scripts/gates/gate-workflow-hardening.sh --self-test  # solo la autoprueba
#
# Variables de entorno:
#   GATE_SELFTEST=0   omite la autoprueba sobre los fixtures (no recomendado)

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

AWK_PROG="$SELF_DIR/lib/workflow-hardening.awk"
FIXTURES="$SELF_DIR/fixtures/hardening"
ROOT="$(gate_root)"
TARGET_DIR="$ROOT/.github/workflows"
ONLY_SELFTEST=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) TARGET_DIR="${2:-}"; shift 2 ;;
    --self-test) ONLY_SELFTEST=1; shift ;;
    -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "argumento desconocido: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

TMPDIR_GATE="$(mktemp -d 2>/dev/null || mktemp -d -t gatehard)"
trap 'rm -rf "$TMPDIR_GATE"' EXIT

# ---------------------------------------------------------------------------
# scan_dir <dir> <fichero-de-salida>
#   0 = escaneado sin hallazgos | 1 = hallazgos FAIL | 2 = no medible
# ---------------------------------------------------------------------------
scan_dir() {
  local dir="$1" out="$2"
  : > "$out"

  if [ -z "$dir" ] || [ ! -d "$dir" ]; then
    printf 'UNMEAS|%s|0|input|el directorio no existe\n' "$dir" >> "$out"
    return "$GATE_UNMEASURABLE"
  fi

  local list="$TMPDIR_GATE/list.$$"
  find "$dir" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null \
    | LC_ALL=C sort > "$list"

  local n
  n="$(wc -l < "$list" | tr -d ' ')"
  if [ "$n" -eq 0 ]; then
    printf 'UNMEAS|%s|0|input|no hay ficheros .yml/.yaml que auditar\n' "$dir" >> "$out"
    return "$GATE_UNMEASURABLE"
  fi

  local f awk_rc=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if ! awk -v FILE="$f" -f "$AWK_PROG" "$f" >> "$out" 2>"$TMPDIR_GATE/awk.err"; then
      awk_rc=1
      printf 'UNMEAS|%s|0|tool|awk no pudo procesar el fichero: %s\n' \
        "$f" "$(tr '\n' ' ' < "$TMPDIR_GATE/awk.err")" >> "$out"
    fi
  done < "$list"

  local nfail nunmeas
  nfail="$(grep -c '^FAIL|' "$out" 2>/dev/null || true)"
  nunmeas="$(grep -c '^UNMEAS|' "$out" 2>/dev/null || true)"
  nfail="${nfail:-0}"; nunmeas="${nunmeas:-0}"

  # Un fallo MEDIDO manda sobre un "no pude medir": es mas accionable y ambos
  # rompen la build igual. Los no-medibles se imprimen siempre, no se tragan.
  if [ "$nfail" -gt 0 ]; then return "$GATE_FAIL"; fi
  if [ "$nunmeas" -gt 0 ] || [ "$awk_rc" -ne 0 ]; then return "$GATE_UNMEASURABLE"; fi
  return "$GATE_OK"
}

print_findings() {
  local out="$1" kind="$2" prefix="$3"
  grep "^$kind|" "$out" 2>/dev/null | while IFS='|' read -r _k file line rule msg; do
    printf '%s %s:%s [%s] %s\n' "$prefix" "$file" "$line" "$rule" "$msg"
  done
}

# ---------------------------------------------------------------------------
# AUTOPRUEBA: el gate se mide a si mismo antes de medir el repo.
# Cada fixture declara en su cabecera `# gate-expect: <regla>` (o `ninguna`).
# Si la autoprueba no cuadra, el gate NO puede afirmar nada -> rc 2.
# ---------------------------------------------------------------------------
self_test() {
  local ok=1 f out expect rule_found

  if [ ! -d "$FIXTURES" ]; then
    gate_warn "autoprueba: no encuentro los fixtures en $FIXTURES"
    return "$GATE_UNMEASURABLE"
  fi

  out="$TMPDIR_GATE/selftest.out"

  # --- casos que DEBEN fallar, con la regla concreta que deben disparar ---
  for f in "$FIXTURES"/bad/*.yml; do
    [ -e "$f" ] || { gate_warn "autoprueba: no hay fixtures negativos"; return "$GATE_UNMEASURABLE"; }
    : > "$out"
    awk -v FILE="$f" -f "$AWK_PROG" "$f" > "$out" 2>/dev/null
    expect="$(sed -n 's/^#[ ]*gate-expect:[ ]*//p' "$f" | head -1)"
    if [ -z "$expect" ]; then
      gate_warn "autoprueba: el fixture $(basename "$f") no declara '# gate-expect:'"
      ok=0
      continue
    fi
    rule_found="$(grep -c "^FAIL|[^|]*|[0-9]*|$expect|" "$out" 2>/dev/null || true)"
    if [ "${rule_found:-0}" -lt 1 ]; then
      gate_warn "autoprueba EN NEGATIVO fallida: $(basename "$f") deberia disparar '$expect' y no lo hizo"
      ok=0
    fi
  done

  # --- casos que DEBEN pasar limpios ---
  for f in "$FIXTURES"/good/*.yml; do
    [ -e "$f" ] || { gate_warn "autoprueba: no hay fixtures positivos"; return "$GATE_UNMEASURABLE"; }
    : > "$out"
    awk -v FILE="$f" -f "$AWK_PROG" "$f" > "$out" 2>/dev/null
    if grep -q '^FAIL|' "$out" || grep -q '^UNMEAS|' "$out"; then
      gate_warn "autoprueba EN POSITIVO fallida: $(basename "$f") deberia salir limpio:"
      print_findings "$out" FAIL   "        "
      print_findings "$out" UNMEAS "        "
      ok=0
    fi
  done

  # --- casos que DEBEN salir como NO MEDIBLE (nunca como aprobado) ---
  for f in "$FIXTURES"/unmeasurable/*.yml; do
    [ -e "$f" ] || continue
    : > "$out"
    awk -v FILE="$f" -f "$AWK_PROG" "$f" > "$out" 2>/dev/null
    if ! grep -q '^UNMEAS|' "$out"; then
      gate_warn "autoprueba fallida: $(basename "$f") deberia salir NO MEDIBLE y salio silencioso"
      ok=0
    fi
  done

  [ "$ok" -eq 1 ] && return "$GATE_OK"
  return "$GATE_UNMEASURABLE"
}

# ---------------------------------------------------------------------------
main() {
  gate_header "workflow-hardening (awk, sin dependencias externas)"
  gate_scope   "disparadores permitidos, permissions por workflow y por job, pin por SHA de 40 chars + comentario de version, secretos en workflows alcanzables desde forks"
  gate_out_of_scope "inyeccion de plantillas en \`run:\`, shellcheck, sintaxis YAML/cron, acciones suplantadas o vulnerables conocidas — de eso se ocupa gate-actions-lint.sh (zizmor + actionlint)"

  if [ ! -f "$AWK_PROG" ]; then
    gate_warn "falta el escaner $AWK_PROG"
    gate_verdict 2
    return "$GATE_UNMEASURABLE"
  fi
  if ! command -v awk >/dev/null 2>&1; then
    gate_warn "no hay awk en el PATH"
    gate_verdict 2
    return "$GATE_UNMEASURABLE"
  fi

  if [ "${GATE_SELFTEST:-1}" != "0" ]; then
    self_test
    local st=$?
    if [ "$st" -ne 0 ]; then
      gate_warn "el gate NO supera su propia autoprueba; cualquier resultado sobre el repo seria indefendible"
      gate_verdict 2
      return "$GATE_UNMEASURABLE"
    fi
    gate_info "autoprueba superada (fixtures negativos, positivos y no-medibles en $FIXTURES)"
  else
    gate_warn "autoprueba OMITIDA por GATE_SELFTEST=0"
  fi

  if [ "$ONLY_SELFTEST" -eq 1 ]; then
    gate_ok "autoprueba superada; no se audito el repo (--self-test)"
    gate_verdict 0
    return "$GATE_OK"
  fi

  local out="$TMPDIR_GATE/repo.out" rc
  scan_dir "$TARGET_DIR" "$out"; rc=$?

  local nf
  nf="$(find "$TARGET_DIR" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | wc -l | tr -d ' ')"
  gate_info "directorio auditado: ${TARGET_DIR#"$ROOT"/} (${nf:-0} fichero(s))"
  awk -F'|' '$1=="STAT"{s[$2]+=$3} END{for (k in s) printf "· total %s: %d\n", k, s[k]}' "$out" | LC_ALL=C sort

  if [ "$rc" -eq 0 ]; then
    gate_ok "los ${nf} workflow(s) cumplen las 4 reglas duras"
  else
    print_findings "$out" FAIL   "  FALLA     "
    print_findings "$out" UNMEAS "  NO MEDIBLE"
  fi

  gate_verdict "$rc"
  return "$rc"
}

main
exit $?
