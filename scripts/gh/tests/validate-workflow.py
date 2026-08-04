#!/usr/bin/env python3
"""Validador en seco del workflow: estructura, reglas duras del modelo de
amenaza, y sintaxis bash de cada bloque run. No ejecuta nada remoto."""
import re
import subprocess
import sys
import tempfile
import pathlib

import yaml

WF = pathlib.Path(sys.argv[1])
raw = WF.read_text()
doc = yaml.safe_load(raw)

fails, oks = [], []


def chk(cond, msg):
    (oks if cond else fails).append(msg)


# PyYAML convierte la clave `on:` en el booleano True (YAML 1.1). Aceptar ambas.
on = doc.get("on", doc.get(True))
chk(on is not None, "el workflow declara disparadores")
triggers = set(on.keys()) if isinstance(on, dict) else {on}
FORBIDDEN = {
    "pull_request_target", "issues", "issue_comment", "discussion",
    "discussion_comment", "fork", "watch", "workflow_run", "repository_dispatch",
}
bad = triggers & FORBIDDEN
chk(not bad, f"ningun disparador prohibido (encontrados: {sorted(triggers)})")
chk(triggers <= {"schedule", "workflow_dispatch"},
    f"solo schedule/workflow_dispatch: {sorted(triggers)}")

chk(doc.get("permissions") == {}, f"permissions de nivel workflow vacio: {doc.get('permissions')!r}")
chk("concurrency" in doc, "declara concurrency (no hay dos promociones a la vez)")

jobs = doc["jobs"]
for name, job in jobs.items():
    perms = job.get("permissions")
    chk(isinstance(perms, dict) and perms,
        f"job '{name}' declara permissions explicitos: {perms}")
    chk(perms != "write-all" and "write-all" not in str(perms),
        f"job '{name}' no usa write-all")
    for i, step in enumerate(job.get("steps", [])):
        uses = step.get("uses")
        if uses:
            chk(re.fullmatch(r"[^@]+@[0-9a-f]{40}", uses) is not None,
                f"job '{name}' paso {i}: accion fijada por SHA de 40 -> {uses}")

# Solo un job puede escribir, y no puede ser el que ejecuta codigo del candidato
writers = [n for n, j in jobs.items() if j.get("permissions", {}).get("contents") == "write"]
chk(writers == ["promote"], f"unico job con contents:write = {writers}")
chk(jobs["gates"]["permissions"] == {"contents": "read"},
    f"el job que ejecuta codigo del candidato es solo-lectura: {jobs['gates']['permissions']}")

# El job de escritura no debe ejecutar nada del arbol candidato
promote_runs = " ".join(s.get("run", "") for s in jobs["promote"]["steps"])
chk("scripts/gates" not in promote_runs, "el job 'promote' no ejecuta gates del arbol candidato")

# Ninguna interpolacion ${{ }} dentro de un bloque run (sink de inyeccion)
interp = []
for name, job in jobs.items():
    for i, step in enumerate(job.get("steps", [])):
        r = step.get("run", "")
        for m in re.findall(r"\$\{\{[^}]*\}\}", r):
            interp.append(f"{name}#{i}: {m}")
chk(not interp, f"cero interpolaciones \\${{{{ }}}} dentro de bloques run: {interp}")

# Sin secretos propios
chk("secrets." not in raw or "secrets.GITHUB_TOKEN" in raw,
    "no referencia ningun secreto propio del repo")
chk("secrets." not in raw, "no referencia el contexto secrets en absoluto")

# Sintaxis bash de cada run
for name, job in jobs.items():
    for i, step in enumerate(job.get("steps", [])):
        r = step.get("run")
        if not r:
            continue
        with tempfile.NamedTemporaryFile("w", suffix=".sh", delete=False) as fh:
            fh.write(r)
            p = fh.name
        res = subprocess.run(["bash", "-n", p], capture_output=True, text=True)
        chk(res.returncode == 0,
            f"bash -n OK en job '{name}' paso {i} ({step.get('name','?')}) {res.stderr.strip()}")

print(f"\n=== {WF}")
for o in oks:
    print(f"  OK    {o}")
for f in fails:
    print(f"  FALLA {f}")
print(f"\n  {len(oks)} OK / {len(fails)} FALLA")
sys.exit(1 if fails else 0)
