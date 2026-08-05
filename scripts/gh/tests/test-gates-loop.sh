#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# PRUEBA EN NEGATIVO del bucle que ejecuta los gates dentro de promote-stable.yml.
#
# La pregunta que responde esta suite no es "pasan los gates?" sino la unica que
# importa de verdad: "puede este job decir TODOS EN VERDE sin haber ejecutado
# todos los gates?". Cada caso es una forma real de que eso ocurra:
#
#   1. Un gate que lee de stdin. Si la lista de gates viaja por stdin, el primer
#      'cat', 'read', 'jq' sin fichero o 'xargs' se traga el resto de la lista y
#      el bucle termina antes de tiempo. No hace falta un atacante: basta un
#      gate escrito con naturalidad. (Hueco real encontrado y corregido.)
#   2. Gates que no terminan en .sh. Descubrir solo '*.sh' convierte cualquier
#      gate en Python o node en un gate que no corre.
#   3. Gates en subcarpetas. Un descubrimiento a un solo nivel los ignora.
#   4. Ficheros que parecen gates y no se sabe ejecutar -> el veredicto honesto
#      es 2 (no pude medir), nunca 0.
#
# El paso se extrae del YAML de verdad, no de una copia: la prueba no se puede
# desincronizar del workflow.
#
# CODIGOS DE SALIDA:  0 todo bien / 1 hay un hueco / 2 no pude correr la prueba
# ---------------------------------------------------------------------------
set -uo pipefail
SP="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SP/../../.." && pwd)"
WF="$ROOT/.github/workflows/promote-stable.yml"

command -v python3 >/dev/null 2>&1 || { echo "  NO PUDE MEDIR: falta python3 (rc 2)"; exit 2; }
command -v jq      >/dev/null 2>&1 || { echo "  NO PUDE MEDIR: falta jq (rc 2)"; exit 2; }
[ -f "$WF" ] || { echo "  NO PUDE MEDIR: no existe $WF (rc 2)"; exit 2; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
python3 - "$WF" "$TMP/gatesjob.sh" <<'PY' || exit 2
import sys, pathlib, yaml
d = yaml.safe_load(pathlib.Path(sys.argv[1]).read_text())
for s in d['jobs']['gates']['steps']:
    if s.get('run'):
        pathlib.Path(sys.argv[2]).write_text(s['run']); break
else:
    sys.exit("no encuentro el paso con 'run' del job 'gates'")
PY

LAB="$TMP/lab"; mkdir -p "$LAB/scripts/gates"
cp "$ROOT/scripts/gh/governance.json" "$LAB/governance.json"
PASS=0; FAIL=0

rc_gates() { ( cd "$LAB" && STATE_FILE=governance.json GITHUB_STEP_SUMMARY=/dev/null \
               bash "$TMP/gatesjob.sh" >/dev/null 2>&1 ); echo $?; }
res() {
  if [ "$2" = "$3" ]; then printf '  PASS  %-58s rc=%s\n' "$1" "$2"; PASS=$((PASS+1))
  else printf '  FAIL  %-58s rc=%s (esperado %s)\n' "$1" "$2" "$3"; FAIL=$((FAIL+1)); fi
}
limpia() { rm -rf "$LAB/scripts/gates"; mkdir -p "$LAB/scripts/gates"; }

echo "== El rc de cada gate manda"
limpia
res "sin directorio de gates -> 2 (no pude medir)" \
    "$( rm -rf "$LAB/scripts/gates"; rc_gates )" 2
limpia
res "directorio vacio -> 2 (cero gates = cero verificacion)" "$(rc_gates)" 2
printf '#!/usr/bin/env bash\nexit 0\n' >"$LAB/scripts/gates/a.sh"
res "un gate verde -> 0" "$(rc_gates)" 0
printf '#!/usr/bin/env bash\nexit 1\n' >"$LAB/scripts/gates/b.sh"
res "un gate en rojo -> 1" "$(rc_gates)" 1
printf '#!/usr/bin/env bash\nexit 2\n' >"$LAB/scripts/gates/b.sh"
res "un gate que no pudo medir -> 1 (no se promueve a ciegas)" "$(rc_gates)" 1
printf '#!/usr/bin/env bash\nexit 7\n' >"$LAB/scripts/gates/b.sh"
res "rc no contemplado -> 1 (jamas se lee como exito)" "$(rc_gates)" 1

echo ""
echo "== Un gate NO puede impedir que los demas se ejecuten"
limpia
# El gate goloso vacia stdin. Si la lista de gates viajase por stdin, se la
# comeria entera y los dos gates rojos de detras nunca correrian.
printf '#!/usr/bin/env bash\ncat >/dev/null 2>&1\nexit 0\n' >"$LAB/scripts/gates/a-goloso.sh"
printf '#!/usr/bin/env bash\nexit 1\n'                      >"$LAB/scripts/gates/b-rojo.sh"
printf '#!/usr/bin/env bash\nexit 1\n'                      >"$LAB/scripts/gates/c-rojo.sh"
res "gate que consume stdin + 2 gates rojos detras -> 1" "$(rc_gates)" 1
OUT=$( cd "$LAB" && STATE_FILE=governance.json GITHUB_STEP_SUMMARY=/dev/null bash "$TMP/gatesjob.sh" 2>&1 )
EJEC=$(printf '%s\n' "$OUT" | grep -c '^   rc=')
res "los 3 gates llegaron a ejecutarse (no solo el primero)" "$EJEC" 3

echo ""
echo "== Ningun gate se descubre a medias"
limpia
printf '#!/usr/bin/env bash\nexit 0\n' >"$LAB/scripts/gates/ok.sh"
printf '#!/usr/bin/env python3\nimport sys; sys.exit(1)\n' >"$LAB/scripts/gates/critico.py"
chmod +x "$LAB/scripts/gates/critico.py"
res "gate .py ejecutable que falla, junto a un .sh verde -> 1" "$(rc_gates)" 1

limpia
printf '#!/usr/bin/env bash\nexit 0\n' >"$LAB/scripts/gates/ok.sh"
mkdir -p "$LAB/scripts/gates/supply-chain"
printf '#!/usr/bin/env bash\nexit 1\n' >"$LAB/scripts/gates/supply-chain/hondo.sh"
res "gate en subcarpeta que falla -> 1" "$(rc_gates)" 1

limpia
printf '#!/usr/bin/env bash\nexit 0\n' >"$LAB/scripts/gates/ok.sh"
printf 'import sys; sys.exit(1)\n' >"$LAB/scripts/gates/sin-bit.py"   # sin +x
res "fichero que parece gate y no se ejecutar -> 2 (no pude medir)" "$(rc_gates)" 2

limpia
printf '#!/usr/bin/env bash\nexit 0\n' >"$LAB/scripts/gates/ok.sh"
printf 'documentacion, no es un gate\n' >"$LAB/scripts/gates/README.md"
res "README.md en el directorio no se confunde con un gate -> 0" "$(rc_gates)" 0

echo ""
echo "  $PASS PASS / $FAIL FAIL"
[ "$FAIL" -eq 0 ] || exit 1
