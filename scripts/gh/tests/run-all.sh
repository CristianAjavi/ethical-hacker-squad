#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Banco de pruebas del area de gobierno. Todo local y hermetico: la API de
# GitHub y el binario 'gh' se sustituyen por dobles, y el historial de git se
# fabrica con commits retrofechados. No hace ni una llamada de red salvo que
# pongas GOV_TESTS_NETWORK=1.
#
# Que prueba, y por que estas pruebas y no otras: cada caso corresponde a una
# forma concreta de que la promocion automatica publique algo que no debia.
#
# CODIGOS DE SALIDA
#   0 = corri todas las suites y pasan
#   1 = corri y alguna FALLA
#   2 = NO PUDE CORRER alguna suite (falta python3/pyyaml/jq/git)
# ---------------------------------------------------------------------------
set -uo pipefail
SP="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SP/../../.." && pwd)"

MISSING=""
for t in bash git jq python3; do
  command -v "$t" >/dev/null 2>&1 || MISSING="$MISSING $t"
done
python3 -c 'import yaml' 2>/dev/null || MISSING="$MISSING python3-pyyaml"
if [ -n "$MISSING" ]; then
  echo "NO PUEDO CORRER LAS PRUEBAS: falta$MISSING"
  echo "rc=2 significa 'no lo comprobe', que no es lo mismo que 'esta bien'."
  exit 2
fi

FAILED=""
suite() {
  echo ""
  echo "###############################################################"
  echo "# $1"
  echo "###############################################################"
  shift
  "$@" || FAILED="$FAILED
  - $1"
}

suite "Estructura del workflow (disparadores, permisos, SHAs, inyeccion)" \
  python3 "$SP/validate-workflow.py" "$ROOT/.github/workflows/promote-stable.yml"
suite "NEGATIVO: el validador de workflows rechaza cada mutacion maligna" \
  python3 "$SP/test-workflow-mutations.py"
suite "Logica de decision de la promocion" \
  bash "$SP/test-promote-decision.sh"
suite "Job de gates + caminos negativos de apply-governance.sh" \
  bash "$SP/test-gates-and-governance.sh"
suite "NEGATIVO: el bucle de gates no puede saltarse ningun gate" \
  bash "$SP/test-gates-loop.sh"
suite "apply-governance.sh contra API simulada (rc=0 alcanzable)" \
  bash "$SP/test-governance-rc0.sh"
suite "NEGATIVO: ningun campo de proteccion declarado queda sin vigilar" \
  bash "$SP/test-governance-drift.sh"

echo ""
echo "==============================================================="
if [ -n "$FAILED" ]; then
  echo "SUITES EN ROJO:$FAILED"
  exit 1
fi
echo "TODAS LAS SUITES EN VERDE"
exit 0
