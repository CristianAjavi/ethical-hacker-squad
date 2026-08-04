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
DROPDOWN_PREFIX = {"rol": "area/", "area": "area/", "severidad": "severidad/"}

problems = []
checked_forms = 0
checked_labels = 0
checked_options = 0

forms = sorted(p for p in tpl_dir.glob("*.yml") if p.name != "config.yml")
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
        prefix = DROPDOWN_PREFIX.get(el.get("id", ""))
        if not prefix:
            continue
        for opt in el.get("attributes", {}).get("options", []):
            checked_options += 1
            key = str(opt).split(" ")[0]
            full = prefix + key
            if full not in tax:
                problems.append(f"{p.name}: la opcion '{opt}' del desplegable "
                                f"'{el.get('id')}' no mapea a ningun label ({full})")

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
