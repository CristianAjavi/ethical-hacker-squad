#!/usr/bin/env python3
"""PRUEBA EN NEGATIVO del validador de workflows.

Un gate que nunca viste fallar no esta probado: validate-workflow.py podria
estar diciendo "todo OK" porque no mira nada. Aqui se rompe deliberadamente el
workflow real, una regla por mutacion, y se exige que el validador devuelva 1.

Cada mutacion corresponde a una forma concreta y documentada de comprometer la
cadena de suministro (disparador que ejecuta texto de un desconocido, token en
un job que corre codigo no confiable, accion reapuntada por su tag, secreto
interpolado hacia una accion de tercero...). Si alguna deja de detectarse, el
validador dejo de valer y esta suite se pone roja.

CODIGOS DE SALIDA
  0  todas las mutaciones fueron detectadas
  1  alguna mutacion PASO el validador (hueco abierto)
  2  no pude correr la prueba (falta PyYAML / falta el workflow)
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
VALIDATOR = ROOT / "scripts/gh/tests/validate-workflow.py"
WORKFLOW = ROOT / ".github/workflows/promote-stable.yml"

if not WORKFLOW.is_file() or not VALIDATOR.is_file():
    print(f"  NO PUDE MEDIR: falta {WORKFLOW} o {VALIDATOR} (rc 2)", file=sys.stderr)
    sys.exit(2)
try:
    import yaml  # noqa: F401  (lo necesita el validador que vamos a invocar)
except Exception as e:  # noqa: BLE001
    print(f"  NO PUDE MEDIR: falta PyYAML ({e}) (rc 2)", file=sys.stderr)
    sys.exit(2)

WF = WORKFLOW.read_text()
import tempfile

TMP = pathlib.Path(tempfile.mkdtemp(prefix="wfmut-"))
PASS, FAIL = 0, 0

CHECKOUT_GATES = """    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Checkout del commit candidato"""
PROMOTE_HDR = """  promote:
    name: Mover stable y etiquetar"""


def rep(old, new):
    if old not in WF:
        print(f"  NO PUDE MEDIR: el workflow cambio, no encuentro el patron {old[:50]!r}",
              file=sys.stderr)
        sys.exit(2)
    return WF.replace(old, new, 1)


def case(label, text, expect=1):
    global PASS, FAIL
    p = TMP / "wf.yml"
    p.write_text(text)
    r = subprocess.run([sys.executable, str(VALIDATOR), str(p)],
                       capture_output=True, text=True)
    if r.returncode == expect:
        print(f"  PASS  {label:<58s} rc={r.returncode}")
        PASS += 1
    else:
        print(f"  FAIL  {label:<58s} rc={r.returncode} (esperado {expect})")
        print("        el validador NO detecto esta mutacion: hueco abierto")
        FAIL += 1


print("== Mutaciones que el validador DEBE rechazar (rc 1)")

case("disparador pull_request_target",
     rep("on:\n  schedule:", "on:\n  pull_request_target:\n  schedule:"))
case("disparador issue_comment (texto de un desconocido)",
     rep("on:\n  schedule:", "on:\n  issue_comment:\n    types: [created]\n  schedule:"))
case("disparador push",
     rep("on:\n  schedule:", "on:\n  push:\n    branches: [main]\n  schedule:"))
case("job 'gates' con contents:write",
     rep(CHECKOUT_GATES, CHECKOUT_GATES.replace("contents: read", "contents: write")))
case("permissions: write-all como STRING (no debe reventar, debe FALLAR)",
     rep(CHECKOUT_GATES,
         CHECKOUT_GATES.replace("    permissions:\n      contents: read",
                                "    permissions: write-all")))
case("sin permissions {} a nivel workflow",
     rep("permissions: {}\n", ""))
case("accion fijada por tag mutable en vez de SHA",
     rep("actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1",
         "actions/checkout@v7"))
case("interpolacion ${{ }} de datos dentro de un run",
     rep("          set -euo pipefail\n          STABLE=$(jq",
         '          set -euo pipefail\n'
         '          echo "${{ github.event.head_commit.message }}"\n'
         "          STABLE=$(jq"))
case("secreto propio del repo en env",
     rep("          GH_TOKEN: ${{ github.token }}",
         "          GH_TOKEN: ${{ secrets.PUBLISH_PAT }}"))
case("contexto secrets encubierto: toJSON(secrets) hacia un tercero",
     rep(PROMOTE_HDR,
         "  exfil:\n"
         "    runs-on: ubuntu-latest\n"
         "    permissions:\n      contents: read\n"
         "    steps:\n"
         "      - uses: tercero/accion@0000000000000000000000000000000000000000\n"
         "        with:\n          data: ${{ toJSON(secrets) }}\n\n" + PROMOTE_HDR))
case("segundo job con contents:write",
     rep(PROMOTE_HDR,
         "  extra:\n    runs-on: ubuntu-latest\n"
         "    permissions:\n      contents: write\n"
         "    steps:\n      - run: echo hola\n\n" + PROMOTE_HDR))
case("workflow reutilizable de tercero SIN fijar (jobs.<id>.uses)",
     rep(PROMOTE_HDR,
         "  reusable:\n    uses: atacante/malo/.github/workflows/x.yml@main\n"
         "    permissions:\n      contents: read\n\n" + PROMOTE_HDR))
case("container de imagen mutable en el job que corre el candidato",
     rep(CHECKOUT_GATES,
         CHECKOUT_GATES.replace("    runs-on: ubuntu-latest",
                                "    runs-on: ubuntu-latest\n    container: atacante/imagen:latest")))
case("checkout del candidato CON credenciales persistidas (token al codigo no confiable)",
     rep("""        with:
          ref: ${{ needs.candidate.outputs.candidate_sha }}
          persist-credentials: false""",
         """        with:
          ref: ${{ needs.candidate.outputs.candidate_sha }}"""))
case("el job con escritura ejecuta un script del arbol candidato",
     rep("""    permissions:
      contents: write
    steps:
      - name: Checkout""",
         """    permissions:
      contents: write
    steps:
      - name: Paso inyectado
        run: bash scripts/gates/x.sh
      - name: Checkout"""))
case("el job con escritura hace checkout del commit candidato",
     rep("""        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          ref: main
          fetch-depth: 0

      - name: Empujar stable""",
         """        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          ref: ${{ needs.candidate.outputs.candidate_sha }}
          fetch-depth: 0

      - name: Empujar stable"""))
case("defaults.run.shell cambiado (el bash -n dejaria de medir lo que se ejecuta)",
     rep("permissions: {}\n", "permissions: {}\ndefaults:\n  run:\n    shell: python\n"))

print()
print("== El validador debe distinguir 'no pude medir' (rc 2) de 'esta mal' (rc 1)")
r = subprocess.run([sys.executable, str(VALIDATOR), str(TMP / "no-existe.yml")],
                   capture_output=True, text=True)
case_ok = r.returncode == 2
print(f"  {'PASS' if case_ok else 'FAIL'}  {'workflow inexistente -> rc 2':<58s} rc={r.returncode}")
PASS, FAIL = (PASS + 1, FAIL) if case_ok else (PASS, FAIL + 1)

p = TMP / "roto.yml"
p.write_text("on: [schedule\njobs: {")
r = subprocess.run([sys.executable, str(VALIDATOR), str(p)], capture_output=True, text=True)
case_ok = r.returncode == 2
print(f"  {'PASS' if case_ok else 'FAIL'}  {'YAML corrupto -> rc 2':<58s} rc={r.returncode}")
PASS, FAIL = (PASS + 1, FAIL) if case_ok else (PASS, FAIL + 1)

print()
print("== Y el workflow real, sin tocar, debe pasar (rc 0 no es un codigo muerto)")
r = subprocess.run([sys.executable, str(VALIDATOR), str(WORKFLOW)],
                   capture_output=True, text=True)
case_ok = r.returncode == 0
print(f"  {'PASS' if case_ok else 'FAIL'}  {'workflow real intacto -> rc 0':<58s} rc={r.returncode}")
PASS, FAIL = (PASS + 1, FAIL) if case_ok else (PASS, FAIL + 1)

print()
print(f"  {PASS} PASS / {FAIL} FAIL")
sys.exit(1 if FAIL else 0)
