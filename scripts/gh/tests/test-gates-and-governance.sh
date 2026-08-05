#!/usr/bin/env bash
set -uo pipefail
SP="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WT="$(cd -- "$SP/../../.." && pwd)"
SP="$(mktemp -d)"; trap 'rm -rf "$SP"' EXIT
PASS=0; FAIL=0
command -v python3 >/dev/null || { echo "  ABORTA: falta python3 (rc 2)"; exit 2; }
res() { if [ "$2" = "$3" ]; then printf '  PASS  %-52s rc=%s\n' "$1" "$2"; PASS=$((PASS+1));
        else printf '  FAIL  %-52s rc=%s (esperado %s)\n' "$1" "$2" "$3"; FAIL=$((FAIL+1)); fi; }

echo "== Job 'gates': el rc del gate manda"
python3 - <<PY
import yaml,pathlib
d=yaml.safe_load(pathlib.Path("$WT/.github/workflows/promote-stable.yml").read_text())
for s in d['jobs']['gates']['steps']:
    if s.get('run'): pathlib.Path("$SP/gatesjob.sh").write_text(s['run'])
PY
LAB="$SP/lab2"; rm -rf "$LAB"; mkdir -p "$LAB"
cp "$WT/scripts/gh/governance.json" "$LAB/governance.json"
run_gates() { ( cd "$LAB" && STATE_FILE=governance.json GITHUB_STEP_SUMMARY=/dev/null bash "$SP/gatesjob.sh" >/dev/null 2>&1 ); echo $?; }

res "sin directorio scripts/gates -> rc 2 (no pude medir)" "$(run_gates)" 2
mkdir -p "$LAB/scripts/gates"
res "directorio vacio -> rc 2 (cero gates = cero verificacion)" "$(run_gates)" 2
printf '#!/usr/bin/env bash\nexit 0\n' >"$LAB/scripts/gates/a.sh"
res "un gate en verde -> rc 0" "$(run_gates)" 0
printf '#!/usr/bin/env bash\nexit 2\n' >"$LAB/scripts/gates/b.sh"
res "un gate con rc 2 -> rc 1 (no se promueve a ciegas)" "$(run_gates)" 1
printf '#!/usr/bin/env bash\nexit 1\n' >"$LAB/scripts/gates/b.sh"
res "un gate con rc 1 -> rc 1" "$(run_gates)" 1
printf '#!/usr/bin/env bash\nexit 7\n' >"$LAB/scripts/gates/b.sh"
res "rc no contemplado -> rc 1 (nunca se interpreta como exito)" "$(run_gates)" 1
rm "$LAB/scripts/gates/b.sh"
printf '#!/usr/bin/env bash\nexit 0\n' >"$LAB/scripts/gates/b.sh"
res "dos gates en verde -> rc 0" "$(run_gates)" 0

echo ""
echo "== apply-governance.sh: caminos negativos"
G="$WT/scripts/gh/apply-governance.sh"

"$G" --help >/dev/null 2>&1; res "--help -> rc 0" "$?" 0

# Hermetico: se simula una sesion gh de OTRA cuenta. Este Mac tiene varias
# cuentas gh y actuar con la equivocada es un error conocido y caro; la guardia
# tiene que dispararse antes de tocar nada.
FB0="$SP/fakebin0"; mkdir -p "$FB0"
printf '#!/usr/bin/env bash\necho otro-usuario\n' >"$FB0/gh"; chmod +x "$FB0/gh"
OUT=$(PATH="$FB0:$PATH" "$G" --no-color 2>&1); RC=$?
res "cuenta gh equivocada -> rc 2 (aborta antes de leer nada)" "$RC" 2
case "$OUT" in
  *"gh auth switch"*) echo "        (el mensaje trae el comando exacto de arreglo)" ;;
  *) echo "        FALLA: el mensaje no dice como arreglarlo"; FAIL=$((FAIL+1)) ;;
esac
case "$OUT" in
  *DERIVA*|*APLICADO*) echo "        FALLA: siguio trabajando con la cuenta equivocada"; FAIL=$((FAIL+1)) ;;
  *) echo "        (no llego a comparar ni a mutar nada)" ;;
esac

printf '#!/usr/bin/env bash\nexit 1\n' >"$FB0/gh"
PATH="$FB0:$PATH" "$G" >/dev/null 2>&1; res "sin sesion gh utilizable -> rc 2" "$?" 2

echo 'no soy json' >"$SP/bad.json"
"$G" --state "$SP/bad.json" >/dev/null 2>&1; res "estado deseado corrupto -> rc 2" "$?" 2
"$G" --state "$SP/no-existe.json" >/dev/null 2>&1; res "estado deseado inexistente -> rc 2" "$?" 2
"$G" --flag-inventada >/dev/null 2>&1; res "argumento desconocido -> rc 2" "$?" 2

# sin jq en el PATH: no puedo comparar -> rc 2, jamas 0
FB="$SP/fakebin2"; mkdir -p "$FB"
for t in gh git bash sed grep find sort mktemp rm cat tr printf date; do
  p=$(command -v "$t" 2>/dev/null) && ln -sf "$p" "$FB/$t" 2>/dev/null || true
done
env PATH="$FB" "$G" >/dev/null 2>&1; res "sin jq en el PATH -> rc 2" "$?" 2

# Esta si toca la red y la sesion gh real: opt-in explicito.
if [ "${GOV_TESTS_NETWORK:-0}" = "1" ]; then
  "$G" --discover-contexts >/dev/null 2>&1; res "--discover-contexts -> rc 0 y no muta" "$?" 0
else
  echo "  SKIP  --discover-contexts (necesita red + sesion gh; GOV_TESTS_NETWORK=1 para correrla)"
fi

echo ""
echo "  $PASS PASS / $FAIL FAIL"
[ "$FAIL" -eq 0 ] || exit 1
