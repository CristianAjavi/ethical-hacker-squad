#!/usr/bin/env python3
"""The mutant bank for scripts/time-repeat.py.

A green battery says the cases ran. It does not say they measured anything, and
the only way to tell the two apart is to break the rule on purpose and watch for
the case that was written to catch it. Each entry below silences ONE rule of the
timing instrument and names the case that owns it; the run is a failure unless
that exact case goes red.

Three outcomes, and the middle one is the point:

    cazado por <caso>    the rule is measured, by the case that claims to
    SOBREVIVE            nobody measures it - a green case that proves nothing
    ROJO PERO POR OTRO   something went red, but not the owner: the case passes
                         for a reason other than the one it declares

A fourth outcome is NOT a result: ANCLA MALA, an anchor that no longer matches
the source. That happens every time the instrument is refactored, and it means
the rule stopped being measured without anyone touching the case. The run exits
2 - COULD NOT MEASURE - rather than reporting a smaller total, because a bank
that quietly shrinks is worth less than no bank.

Exit codes follow scripts/gates/lib/common.sh: 0 every mutant caught by its
owner, 1 one was not, 2 could not measure.

Wired through time-repeat.mutants.selftest.sh, which is what run-batteries.sh
discovers - the same way coverage-sweep.mutants.py is wired, and NOT as a gate
under scripts/gates/, where run-all.sh would take a bank for a gate. Measured:
174 s for 20 mutants, one whole battery each plus the baseline.
"""
import pathlib, re, shutil, subprocess, sys, tempfile

HERE = pathlib.Path(__file__).resolve().parent
try:
    ROOT = pathlib.Path(subprocess.run(
        ["git", "-C", str(HERE), "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, check=True).stdout.strip())
except Exception:
    ROOT = HERE.parent
T = "scripts/time-repeat.py"
BATTERY = "scripts/time-repeat.selftest.sh"

M = [
 ("una-sola-vuelta-deja-de-rechazarse", T,
  '    if a.runs < 2:', '    if False:',
  "one-run-is-refused"),

 ("un-comando-que-falla-se-cuenta-como-lento", T,
  '''            dt, rc, err = run_once(argv, cwd, env, a.contenders)
            if rc != 0:''',
  '''            dt, rc, err = run_once(argv, cwd, env, a.contenders)
            if False:''',
  "a-failing-command-is-unmeasurable"),

 ("el-calentamiento-roto-deja-de-detenerlo", T,
  '''        dt, rc, err = run_once(cmd, cwd, env, a.contenders)
        if rc != 0:
            print("\\nCOULD NOT MEASURE: warm-up %d exited %d.''',
  '''        dt, rc, err = run_once(cmd, cwd, env, a.contenders)
        if False:
            print("\\nCOULD NOT MEASURE: warm-up %d exited %d.''',
  "a-failing-warmup-is-unmeasurable"),

 ("el-error-del-comando-deja-de-mostrarse", T,
  'is not a slow command.\\n%s" % (i + 1, rc, err.strip()[:800]),',
  'is not a slow command.\\n%s" % (i + 1, rc, ""),',
  "the-failure-names-what-the-command-said"),

 ("sin-comando-pasa-por-medido", T,
  '''    if not cmd:
        print("COULD NOT MEASURE: no command given", file=sys.stderr)
        return UNMEASURABLE''',
  '''    if not cmd:
        return MEASURED''',
  "no-command-is-refused"),

 ("el-directorio-ausente-deja-de-rechazarse", T,
  '    if not os.path.isdir(cwd):', '    if False:',
  "a-missing-directory-is-refused"),

 ("el-calentamiento-negativo-pasa", T,
  '    if a.warmup < 0:', '    if False:',
  "a-negative-warmup-is-refused"),

 ("el-calentamiento-se-esconde", T,
  '        print("   warm-up %d: %.1f s (dropped, on purpose, and said so)" % (i + 1, dt))',
  '        pass',
  "the-warmup-is-reported-not-hidden"),

 ("la-mediana-viaja-sola", T,
  '''        print("\\n%s%s: median %.1f s, range %.1f-%.1f s over %d run(s)"
              % (name, load, m, min(xs), max(xs), len(xs)))''',
  '        print("\\n%s: median %.1f s" % (name, m))',
  "the-median-never-travels-alone"),

 ("el-ruido-deja-de-nombrarse", T,
  '                "Quote the median." if s_ < 10 else',
  '                "Quote the median." if s_ < 100000 else',
  "a-wide-spread-is-named-as-noise"),

 ("el-tope-de-dispersion-deja-de-fallar", T,
  '    if a.max_spread is not None and sp > a.max_spread:',
  '    if False:',
  "a-noisy-box-is-exit-1-not-a-number"),

 ("el-calentamiento-no-se-ejecuta", T,
  '''    for i in range(a.warmup):
        dt, rc, err = run_once(cmd, cwd, env, a.contenders)''',
  '''    for i in range(0):
        dt, rc, err = run_once(cmd, cwd, env, a.contenders)''',
  "it-runs-the-command-as-often-as-it-says"),
 ("los-contendientes-negativos-pasan", T,
  '    if a.contenders < 0:', '    if False:',
  "a-negative-contenders-is-refused"),

 ("los-contendientes-no-se-lanzan", T,
  '            for _ in range(contenders)]',
  '            for _ in range(0)]',
  "the-contenders-are-really-launched"),

 ("el-contendiente-muerto-no-se-mira", T,
  '        if q.returncode != 0 and rc == 0:', '        if False:',
  "a-dead-contender-is-unmeasurable"),

 ("la-mediana-viaja-sin-su-condicion", T,
  '              % (name, load, m, min(xs), max(xs), len(xs)))',
  '              % (name, "", m, min(xs), max(xs), len(xs)))',
  "a-contended-median-says-it-was-contended"),

 ("los-dos-brazos-dejan-de-alternarse", T,
  '    for i in range(a.runs):\n        for arm, argv, bucket in (("A", cmd, samples),\n                                  ("B", other, others)):',
  '    for arm, argv, bucket in (("A", cmd, samples),\n                              ("B", other, others)):\n      for i in range(a.runs):',
  "against-alternates-run-for-run"),

 ("todo-par-de-rangos-es-una-diferencia", T,
  '        if max(samples) < min(others) or max(others) < min(samples):',
  '        if True:',
  "overlapping-ranges-are-the-box"),

 ("el-brazo-que-murio-no-se-nombra", T,
  '                      % (i + 1, "" if other is None else " (arm %s)" % arm,',
  '                      % (i + 1, "",',
  "a-failing-second-arm-is-unmeasurable"),

 ("el-against-vacio-pasa-en-silencio", T,
  '    if a.against is not None and not other:',
  '    if False:',
  "against-with-nothing-to-run-is-refused"),
]

def run(cwd):
    p = subprocess.run(["bash", BATTERY],
                       cwd=cwd, capture_output=True, text=True, timeout=600,
                       stdin=subprocess.DEVNULL)
    red = {m.group(1) for m in
           (re.match(r"^FAILED\s+(\S+?):", l) for l in (p.stdout + p.stderr).splitlines()) if m}
    return p.returncode, red

base = tempfile.mkdtemp(prefix="cnt-")
try:
    pristine = pathlib.Path(base) / "p"
    subprocess.run("(cd %s && tar --exclude .git --exclude __pycache__ --exclude node_modules -cf - .) "
                   "| (mkdir -p %s && cd %s && tar -xf -)" % (ROOT, pristine, pristine),
                   shell=True, check=True)
    rc, red = run(pristine)
    if rc != 0 or red:
        # Un 1 y un 2 no se arreglan igual, asi que no se dicen igual: uno es la
        # bateria rota y el otro es la bateria que no pudo medirse. Para el banco
        # los dos acaban en lo mismo -- sin linea base verde, un rojo bajo un
        # mutante no prueba nada -- y eso es COULD NOT MEASURE, nunca un fallo
        # medido y nunca un aprobado.
        print("REHUSADO: %s (rc=%d%s)"
              % ("la bateria no se pudo medir sin mutar" if rc == 2 else
                 "la bateria ya esta roja sin mutar",
                 rc, (", casos: %s" % sorted(red)) if red else ""),
              file=sys.stderr)
        sys.exit(2)
    print("linea base: la bateria pasa entera sin mutar\n")
    ok = 0
    stale = 0
    for name, target, old, new, owner in M:
        work = pathlib.Path(base) / name
        subprocess.run(["cp", "-Rc", str(pristine), str(work)], capture_output=True) \
            or subprocess.run(["cp", "-R", str(pristine), str(work)], check=True)
        f = work / target
        t = f.read_text()
        if t.count(old) != 1:
            print("%-44s ANCLA MALA (%d)" % (name, t.count(old)))
            stale += 1
            continue
        f.write_text(t.replace(old, new))
        rc, redset = run(work)
        if rc == 0:
            print("%-44s SOBREVIVE  <- nadie lo caza" % name)
        elif owner in redset:
            print("%-44s cazado por %s%s" % (name, owner,
                  "" if len(redset) == 1 else "  (+%d mas)" % (len(redset) - 1)))
            ok += 1
        else:
            print("%-44s ROJO PERO POR OTRO: %s" % (name, sorted(redset)[:3]))
        subprocess.run(["/bin/rm", "-rf", str(work)])
    print("\n%d de %d cazados por su dueno" % (ok, len(M)))
    if stale:
        print("NO MEDIDO: %d ancla(s) caduca(s). Un ancla que ya no casa no es un "
              "mutante de menos: es una regla que dejo de medirse." % stale)
        sys.exit(2)
    if ok != len(M):
        # Hasta aqui el banco imprimia SOBREVIVE y salia 0. La docstring prometia
        # un 1 y nadie lo escribio, asi que el banco daba por bueno justo el
        # hallazgo que existe para encontrar: una regla del instrumento que
        # ningun caso mide. Cablearlo a un corredor sin esto habria metido en la
        # suite un verde que no significa nada.
        print("FALLO: %d mutante(s) sin el caso que dice cazarlos. Un caso verde "
              "sobre una regla silenciada no mide esa regla: escribe el caso, en "
              "%s." % (len(M) - ok, BATTERY))
        sys.exit(1)
    print("OK: cada regla del cronometro tiene un caso que la mide")
finally:
    shutil.rmtree(base, ignore_errors=True)
