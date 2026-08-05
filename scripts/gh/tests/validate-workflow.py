#!/usr/bin/env python3
"""Validador en seco de los workflows: estructura, reglas duras del modelo de
amenaza, y sintaxis bash de cada bloque run. No ejecuta nada remoto.

CODIGOS DE SALIDA (doctrina: un rc=0 nunca puede significar "no lo revise")
  0  Revise el fichero y cumple todas las reglas.
  1  Revise el fichero e INCUMPLE alguna regla.
  2  NO PUDE REVISARLO (falta PyYAML, el fichero no existe, el YAML no parsea).
     Nunca se degrada a 1: "no pude parsearlo" no es lo mismo que "esta mal", y
     sobre todo no es lo mismo que "esta bien".
"""
import re
import subprocess
import sys
import tempfile
import pathlib

RC_OK, RC_FAIL, RC_UNMEASURED = 0, 1, 2


def cannot_measure(msg):
    print(f"  NO PUDE MEDIR  {msg}", file=sys.stderr)
    print("  rc=2 significa 'no lo comprobe', que no es lo mismo que 'esta bien'.",
          file=sys.stderr)
    sys.exit(RC_UNMEASURED)


try:
    import yaml
except Exception as e:  # noqa: BLE001 - cualquier fallo de import es "no puedo medir"
    cannot_measure(f"no puedo importar PyYAML ({e}). Instala: pip install pyyaml")

if len(sys.argv) < 2:
    cannot_measure("uso: validate-workflow.py <workflow.yml> [...]")

# SHA de commit: 40 hex en minuscula. Un tag es mutable; quien controle la
# cuenta de la accion puede reapuntarlo a codigo nuevo sin cambiar el nombre.
SHA40 = re.compile(r"^[^@\s]+@[0-9a-f]{40}$")
# Imagen de contenedor fijada por digest inmutable.
DIGEST = re.compile(r"@sha256:[0-9a-f]{64}$")
EXPR = re.compile(r"\$\{\{(.*?)\}\}", re.S)

FORBIDDEN_TRIGGERS = {
    "pull_request_target", "issues", "issue_comment", "discussion",
    "discussion_comment", "fork", "watch", "workflow_run", "repository_dispatch",
    "merge_group", "public", "gollum", "status", "registry_package",
}
ALLOWED_TRIGGERS = {"schedule", "workflow_dispatch"}
# Job unico autorizado a escribir, y por tanto unico que NO ejecuta arbol candidato.
WRITER_JOB = "promote"


def check_file(path):
    fails, oks = [], []

    def chk(cond, msg):
        (oks if cond else fails).append(msg)

    try:
        raw = path.read_text()
    except OSError as e:
        cannot_measure(f"no puedo leer {path}: {e}")
    try:
        doc = yaml.safe_load(raw)
    except yaml.YAMLError as e:
        cannot_measure(f"{path} no es YAML valido: {str(e).splitlines()[0]}")
    if not isinstance(doc, dict) or "jobs" not in doc:
        cannot_measure(f"{path} no parece un workflow (sin clave 'jobs')")

    # -- disparadores --------------------------------------------------------
    # PyYAML convierte la clave `on:` en el booleano True (YAML 1.1).
    on = doc.get("on", doc.get(True))
    chk(on is not None, "el workflow declara disparadores")
    triggers = set(on.keys()) if isinstance(on, dict) else (
        set(on) if isinstance(on, list) else {on})
    bad = triggers & FORBIDDEN_TRIGGERS
    chk(not bad, f"ningun disparador prohibido (encontrados: {sorted(triggers)})")
    chk(triggers <= ALLOWED_TRIGGERS,
        f"solo schedule/workflow_dispatch: {sorted(triggers)}")

    chk(doc.get("permissions") == {},
        f"permissions de nivel workflow vacio: {doc.get('permissions')!r}")
    chk("concurrency" in doc, "declara concurrency (no hay dos promociones a la vez)")
    # Un defaults.run.shell distinto de bash deja sin sentido el 'bash -n' de
    # mas abajo: la comprobacion de sintaxis dejaria de medir lo que se ejecuta.
    chk("defaults" not in doc,
        f"sin 'defaults' a nivel workflow (cambiaria el shell bajo los pies): {doc.get('defaults')!r}")

    jobs = doc["jobs"]
    writers = []
    for name, job in jobs.items():
        if not isinstance(job, dict):
            chk(False, f"job '{name}' no es un mapa")
            continue

        # -- permisos por job -------------------------------------------------
        perms = job.get("permissions")
        chk(isinstance(perms, dict) and perms,
            f"job '{name}' declara permissions explicitos como mapa (no heredados, no 'write-all'): {perms!r}")
        if isinstance(perms, dict):
            if perms.get("contents") == "write":
                writers.append(name)
            chk(not any(v == "write" for k, v in perms.items() if k != "contents"),
                f"job '{name}' no pide write en ningun scope salvo contents: {perms!r}")
        chk("defaults" not in job, f"job '{name}' no redefine defaults (shell)")

        # -- workflow reutilizable de terceros --------------------------------
        # jobs.<id>.uses no tiene 'steps': si solo se miran los pasos, un
        # workflow reutilizable ajeno y sin fijar entra sin que nadie lo vea.
        juses = job.get("uses")
        if juses:
            local = str(juses).startswith("./")
            chk(local or SHA40.match(str(juses)) is not None,
                f"job '{name}': workflow reutilizable fijado por SHA de 40 o local -> {juses}")
            chk("secrets" not in job,
                f"job '{name}': no pasa 'secrets' a un workflow reutilizable")

        # -- contenedores y servicios -----------------------------------------
        for key in ("container", "services"):
            spec = job.get(key)
            if not spec:
                continue
            items = spec.values() if key == "services" else [spec]
            for it in items:
                img = it if isinstance(it, str) else (it or {}).get("image", "")
                chk(DIGEST.search(str(img)) is not None,
                    f"job '{name}': {key} fijado por digest sha256 -> {img}")

        # -- acciones de terceros ---------------------------------------------
        for i, step in enumerate(job.get("steps") or []):
            uses = step.get("uses")
            if uses:
                local = str(uses).startswith("./") or str(uses).startswith("docker://")
                chk(SHA40.match(str(uses)) is not None or local,
                    f"job '{name}' paso {i}: accion fijada por SHA de 40 -> {uses}")
            chk("shell" not in step or step.get("shell") == "bash",
                f"job '{name}' paso {i}: shell bash o por defecto -> {step.get('shell')!r}")

            # -- credenciales persistidas en un checkout --------------------
            # Un checkout con credenciales deja el GITHUB_TOKEN escrito en
            # .git/config del runner. En el job que EJECUTA el arbol candidato
            # eso entrega el token al codigo no confiable: es el patron exacto
            # del incidente de robo del token de publicacion. Solo el job que
            # tiene que empujar puede persistirlas.
            if uses and "actions/checkout" in str(uses) and name != WRITER_JOB:
                with_ = step.get("with") or {}
                chk(with_.get("persist-credentials") is False,
                    f"job '{name}' paso {i}: checkout con persist-credentials:false "
                    f"(vale {with_.get('persist-credentials')!r})")

    # -- separacion de poderes ------------------------------------------------
    chk(writers == [WRITER_JOB], f"unico job con contents:write = {writers}")
    gates = jobs.get("gates")
    chk(isinstance(gates, dict) and gates.get("permissions") == {"contents": "read"},
        f"el job que ejecuta codigo del candidato es solo-lectura: "
        f"{gates.get('permissions') if isinstance(gates, dict) else gates!r}")

    promote = jobs.get(WRITER_JOB)
    if isinstance(promote, dict):
        promote_runs = " ".join(s.get("run", "") for s in (promote.get("steps") or []))
        chk("scripts/gates" not in promote_runs,
            "el job 'promote' no ejecuta gates del arbol candidato")
        # El job con escritura no debe hacer checkout del commit candidato: si
        # lo hiciera, leeria su configuracion (rama destino, tags) de un arbol
        # que el candidato controla, y con contents:write.
        for i, s in enumerate(promote.get("steps") or []):
            if s.get("uses") and "actions/checkout" in str(s["uses"]):
                ref = (s.get("with") or {}).get("ref")
                chk(ref == "main",
                    f"el job 'promote' hace checkout de main, no del candidato -> ref={ref!r}")

    # -- inyeccion: interpolacion dentro de un run ----------------------------
    interp = []
    for name, job in jobs.items():
        if not isinstance(job, dict):
            continue
        for i, step in enumerate(job.get("steps") or []):
            for m in EXPR.findall(step.get("run", "")):
                interp.append(f"{name}#{i}: ${{{{{m}}}}}")
    chk(not interp, f"cero interpolaciones \\${{{{ }}}} dentro de bloques run: {interp}")

    # -- contexto secrets en CUALQUIER forma ----------------------------------
    # Buscar la cadena "secrets." se salta toJSON(secrets), secrets[...] y
    # secrets['X']. Se inspecciona el interior de cada expresion ${{ }}.
    sec = [m.strip() for m in EXPR.findall(raw) if re.search(r"\bsecrets\b", m)]
    chk(not sec, f"el contexto 'secrets' no aparece en ninguna expresion: {sec}")

    # -- sintaxis bash de cada run --------------------------------------------
    for name, job in jobs.items():
        if not isinstance(job, dict):
            continue
        for i, step in enumerate(job.get("steps") or []):
            r = step.get("run")
            if not r:
                continue
            with tempfile.NamedTemporaryFile("w", suffix=".sh", delete=False) as fh:
                fh.write(r)
                p = fh.name
            try:
                res = subprocess.run(["bash", "-n", p], capture_output=True, text=True)
            except FileNotFoundError:
                cannot_measure("falta 'bash': no puedo comprobar la sintaxis de los run")
            chk(res.returncode == 0,
                f"bash -n OK en job '{name}' paso {i} ({step.get('name', '?')}) {res.stderr.strip()}")

    print(f"\n=== {path}")
    for o in oks:
        print(f"  OK    {o}")
    for f in fails:
        print(f"  FALLA {f}")
    print(f"\n  {len(oks)} OK / {len(fails)} FALLA")
    return not fails


all_ok = True
for arg in sys.argv[1:]:
    pth = pathlib.Path(arg)
    if not pth.is_file():
        cannot_measure(f"no existe el fichero {pth}")
    all_ok = check_file(pth) and all_ok

sys.exit(RC_OK if all_ok else RC_FAIL)
