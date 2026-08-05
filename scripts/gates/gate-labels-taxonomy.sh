#!/usr/bin/env bash
# gate-labels-taxonomy.sh
#
# POR QUE EXISTE: si un issue form aplica un label que no esta en la taxonomia de
# scripts/gh/labels.sh, GitHub lo ignora EN SILENCIO y la issue entra sin clasificar.
# El triaje determinista se rompe sin que nadie se entere. Este gate lo hace ruidoso.
#
# QUE REVISA (sin red):
#   1. Todo label declarado en `labels:` de un issue form existe en scripts/gh/labels.sh.
#   2. Cada opcion de los desplegables de rol/area y severidad corresponde a un label
#      real `area/<x>` o `severidad/<x>` (asi el mantenedor lo copia sin ejercer juicio).
#   3. Todos los forms declaran los campos obligatorios (name, description, body) y
#      usan solo tipos de elemento validos.
#   4. config.yml existe y tiene blank_issues_enabled: false (sin eso hay una via de
#      entrada sin ningun label).
#
# QUE NO REVISA: si esos labels existen de verdad EN GITHUB. Eso es red y es
# scripts/gh/labels.sh --check.
#
# CODIGOS DE SALIDA: 0 = medi y esta bien | 1 = medi y FALLA | 2 = NO PUDE MEDIR.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

command -v python3 >/dev/null 2>&1 || {
  printf 'NO PUDE MEDIR: falta python3 (hace falta para parsear los YAML de los forms).\n' >&2
  exit 2
}
python3 -c 'import yaml' 2>/dev/null || {
  printf 'NO PUDE MEDIR: falta el modulo PyYAML (pip install pyyaml).\n' >&2
  exit 2
}
[ -r "$ROOT/scripts/gh/labels.sh" ] || {
  printf 'NO PUDE MEDIR: no encuentro scripts/gh/labels.sh en %s.\n' "$ROOT" >&2
  exit 2
}
[ -d "$ROOT/.github/ISSUE_TEMPLATE" ] || {
  printf 'NO PUDE MEDIR: no encuentro .github/ISSUE_TEMPLATE en %s.\n' "$ROOT" >&2
  exit 2
}

ROOT="$ROOT" python3 <<'PY'
import os, re, sys, pathlib, yaml

root = pathlib.Path(os.environ["ROOT"])
tpl_dir = root / ".github/ISSUE_TEMPLATE"

tax = set()
for line in (root / "scripts/gh/labels.sh").read_text().splitlines():
    m = re.match(r'^([a-z]+/[a-z0-9-]+)\|([0-9a-f]{6})\|(.+)$', line)
    if m:
        tax.add(m.group(1))

if not tax:
    print("NO PUDE MEDIR: no extraje ningun label de scripts/gh/labels.sh "
          "(cambio el formato 'nombre|color|descripcion').")
    sys.exit(2)

VALID_TYPES = {"markdown", "input", "textarea", "dropdown", "checkboxes"}

# REGISTRO EXPLICITO DE DESPLEGABLES. Antes esto era un dict "opt-in": un desplegable
# cuyo id no estuviera aqui se saltaba EN SILENCIO y el gate seguia diciendo "OK".
# Renombrar `id: rol` a `id: rol_emisor` desactivaba la comprobacion entera sin que
# nada fallara: rc=0 significaba "no lo revise", que es justo lo que no puede pasar.
# Ahora todo desplegable tiene que estar declarado en UNA de las dos tablas.
#
#   id -> (prefijo del label, opciones que a proposito NO son un label)
DROPDOWN_MAPEADOS = {
    "rol":       ("area/",      set()),
    "area":      ("area/",      set()),
    "severidad": ("severidad/", set()),
    "canal":     ("canal/",     {"instalado a mano / no lo se"}),
}
# id -> razon por la que sus opciones no corresponden a ningun label
DROPDOWN_EXENTOS = {}

problems = []
checked_forms = 0
checked_labels = 0
checked_options = 0
skipped_dropdowns = []

# Se miran .yml y .yaml: la doc de GitHub solo documenta .yml, pero un fichero .yaml
# suelto aqui quedaria sin revisar y este gate no puede callarse sobre lo que no mira.
forms = sorted(p for p in list(tpl_dir.glob("*.yml")) + list(tpl_dir.glob("*.yaml"))
               if p.stem != "config")
if not forms:
    print("NO PUDE MEDIR: no hay ningun issue form en .github/ISSUE_TEMPLATE.")
    sys.exit(2)

for p in forms:
    try:
        doc = yaml.safe_load(p.read_text())
    except Exception as e:
        problems.append(f"{p.name}: YAML invalido: {e}")
        continue
    checked_forms += 1
    for key in ("name", "description", "body"):
        if key not in doc:
            problems.append(f"{p.name}: falta la clave obligatoria '{key}'")
    if not doc.get("labels"):
        problems.append(f"{p.name}: no declara 'labels'; una issue creada con este form "
                        f"entraria sin clasificar")
    for lbl in doc.get("labels", []):
        checked_labels += 1
        if lbl not in tax:
            problems.append(f"{p.name}: el label '{lbl}' no existe en scripts/gh/labels.sh")
    for el in doc.get("body", []) or []:
        t = el.get("type")
        if t not in VALID_TYPES:
            problems.append(f"{p.name}: tipo de elemento no valido: {t!r}")
            continue
        if t != "dropdown":
            continue
        did = el.get("id", "")
        if did in DROPDOWN_EXENTOS:
            skipped_dropdowns.append(f"{p.name}:{did} (exento: {DROPDOWN_EXENTOS[did]})")
            continue
        if did not in DROPDOWN_MAPEADOS:
            problems.append(
                f"{p.name}: el desplegable '{did}' no esta declarado. Añadelo a "
                f"DROPDOWN_MAPEADOS (con su prefijo de label) o a DROPDOWN_EXENTOS "
                f"(con la razon). Sin declararlo, sus opciones quedarian sin revisar "
                f"y este gate diria 'OK' sin haber medido nada.")
            continue
        prefix, libres = DROPDOWN_MAPEADOS[did]
        for opt in el.get("attributes", {}).get("options", []):
            checked_options += 1
            if str(opt) in libres:
                continue
            key = str(opt).split(" ")[0]
            full = prefix + key
            if full not in tax:
                problems.append(f"{p.name}: la opcion '{opt}' del desplegable "
                                f"'{did}' no mapea a ningun label ({full})")

# Coherencia con gate-issue-closure.sh: ese gate solo EXIGE regresion vigilada cuando el
# issue lleva uno de los labels de REGRESSION_LABELS. Si alguien renombra el label en la
# taxonomia (o hay un typo en el valor por defecto), el gate deja de exigir nada y
# devuelve rc=0 "OK" para siempre, sin que nadie se entere. Aqui se ata el cabo.
closure = root / "scripts/gates/gate-issue-closure.sh"
checked_regression = []
if not closure.exists():
    problems.append("no encuentro scripts/gates/gate-issue-closure.sh: no puedo comprobar "
                    "que sus labels de regresion existan en la taxonomia")
else:
    m = re.search(r'^REGRESSION_LABELS="\$\{REGRESSION_LABELS:-([^}"]*)\}"',
                  closure.read_text(), re.M)
    if not m:
        problems.append("gate-issue-closure.sh: no pude leer el valor por defecto de "
                        "REGRESSION_LABELS (cambio el formato); sin eso no puedo comprobar "
                        "que esos labels existan")
    else:
        checked_regression = [x.strip() for x in m.group(1).split(",") if x.strip()]
        if not checked_regression:
            problems.append("gate-issue-closure.sh: REGRESSION_LABELS por defecto esta vacio; "
                            "el gate de cierre no exigiria regresion a NINGUN issue")
        for lbl in checked_regression:
            if lbl not in tax:
                problems.append(f"gate-issue-closure.sh: el label de regresion '{lbl}' no existe "
                                f"en scripts/gh/labels.sh; ese gate nunca se activaria")

cfg = tpl_dir / "config.yml"
if not cfg.exists():
    problems.append("falta .github/ISSUE_TEMPLATE/config.yml")
else:
    try:
        c = yaml.safe_load(cfg.read_text()) or {}
        if c.get("blank_issues_enabled") is not False:
            problems.append("config.yml: blank_issues_enabled debe ser false "
                            "(la issue en blanco es la unica via de entrada sin label)")
    except Exception as e:
        problems.append(f"config.yml: YAML invalido: {e}")

print("gate-labels-taxonomy")
print("====================")
print(f"REVISADO: {checked_forms} issue forms, {checked_labels} labels declarados, "
      f"{checked_options} opciones de desplegable, contra {len(tax)} labels de la taxonomia.")
print(f"REVISADO: los {len(checked_regression)} labels de regresion de gate-issue-closure.sh "
      f"existen en la taxonomia: {', '.join(checked_regression) or '<ninguno>'}")
if skipped_dropdowns:
    print("NO REVISADO (exento y declarado como tal): " + "; ".join(skipped_dropdowns))
print("NO REVISADO: si esos labels existen en GitHub (eso es scripts/gh/labels.sh --check).")
print()

if problems:
    print("Resultado: FALLA.")
    for pr in problems:
        print(f"  - {pr}")
    sys.exit(1)

print("Resultado: OK. Los forms solo aplican labels que la taxonomia declara.")
sys.exit(0)
PY
