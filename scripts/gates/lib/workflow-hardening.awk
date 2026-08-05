# scripts/gates/lib/workflow-hardening.awk
#
# Escaner estructural de un workflow de GitHub Actions, en awk POSIX.
# No requiere PyYAML, ni zizmor, ni actionlint, ni red: es el gate de ultima
# instancia, el que sigue midiendo cuando no hay herramientas instaladas.
#
# Lo invoca scripts/gates/gate-workflow-hardening.sh con -v FILE=<ruta>.
#
# Protocolo de salida (una linea por hallazgo):
#   FAIL|<fichero>|<linea>|<regla>|<mensaje>
#   UNMEAS|<fichero>|<linea>|<regla>|<mensaje>
#   STAT|<clave>|<valor>
#
# Limitaciones conocidas (se declaran, no se ocultan):
#   - Es un analisis lexico guiado por indentacion, no un parser YAML. Por eso,
#     ante cualquier cosa que no sepa interpretar con seguridad (tabuladores,
#     ausencia de `on:` o de `jobs:`, `uses:` cuyo valor esta en otra linea),
#     emite UNMEAS y NUNCA silencio.
#   - No entiende anclas/alias YAML (&x / *x). Si aparecen, emite UNMEAS.
#   - No evalua `if:` de trabajo: la regla 4 (secretos) se aplica a nivel de
#     workflow, que es la lectura estricta y la que no se puede eludir con un
#     condicional mal razonado.

function ind(l,   n) {
    n = 0
    while (substr(l, n + 1, 1) == " ") n++
    return n
}

function trim(s) {
    sub(/^[ \t]+/, "", s)
    sub(/[ \t]+$/, "", s)
    return s
}

function unq(s) {
    if (substr(s, 1, 1) == "\"" || substr(s, 1, 1) == "'") s = substr(s, 2)
    if (substr(s, length(s), 1) == "\"" || substr(s, length(s), 1) == "'") s = substr(s, 1, length(s) - 1)
    return s
}

# Los hallazgos se acumulan y se imprimen en END: si al final resulta que el
# fichero no era interpretable con garantias (tabuladores, anclas), los FAIL
# estructurales se DESCARTAN y el fichero pasa a "no pude medir". Afirmar un
# fallo concreto a partir de una indentacion que no entiendo seria mentir.
function fail(rule, msg, ln) {
    nfail++
    Fbuf[nfail] = sprintf("FAIL|%s|%d|%s|%s", FILE, ln, rule, msg)
}

function unmeas(rule, msg, ln) {
    nunmeas++
    Ubuf[nunmeas] = sprintf("UNMEAS|%s|%d|%s|%s", FILE, ln, rule, msg)
}

function keyof(l,   k) {
    if (match(l, /^[ ]*[^ :#][^:]*:/)) {
        k = substr(l, RSTART, RLENGTH - 1)
        return unq(trim(k))
    }
    return ""
}

function valof(l,   p) {
    p = index(l, ":")
    if (p == 0) return ""
    return trim(substr(l, p + 1))
}

function ishex40(s,   i, c) {
    if (length(s) != 40) return 0
    for (i = 1; i <= 40; i++) {
        c = substr(s, i, 1)
        if (index("0123456789abcdef", c) == 0) return 0
    }
    return 1
}

function ishex(s, want,   i, c) {
    if (length(s) != want) return 0
    for (i = 1; i <= want; i++) {
        c = substr(s, i, 1)
        if (index("0123456789abcdef", c) == 0) return 0
    }
    return 1
}

# ---- regla 3: `uses:` fijado por SHA de 40 caracteres -----------------------
function check_uses(u, ln,   v, c, cpos, ref, at, digest) {
    v = trim(substr(u, 6))
    if (v == "") {
        unmeas("uses-pin", "`uses:` sin valor en la misma linea; el escaner lexico no puede resolverlo", ln)
        return
    }
    cpos = index(v, "#")
    if (cpos > 0) { c = substr(v, cpos); v = trim(substr(v, 1, cpos - 1)) } else { c = "" }
    v = unq(v)
    if (v == "") { unmeas("uses-pin", "`uses:` con valor vacio", ln); return }

    # Referencias locales: no son codigo de tercero, viven en este repo.
    if (substr(v, 1, 2) == "./" || substr(v, 1, 3) == "../") { nlocal++; return }

    if (substr(v, 1, 9) == "docker://") {
        at = index(v, "@sha256:")
        if (at == 0) {
            fail("uses-pin", "imagen docker sin digest inmutable (@sha256:...): " v, ln)
        } else {
            digest = substr(v, at + 8)
            if (!ishex(digest, 64)) fail("uses-pin", "digest sha256 malformado: " v, ln)
            else npinned++
        }
        return
    }

    at = index(v, "@")
    if (at == 0) {
        fail("uses-pin", "`uses:` sin `@ref`; una accion sin referencia no es reproducible: " v, ln)
        return
    }
    ref = substr(v, at + 1)
    if (!ishex40(ref)) {
        fail("uses-pin", "accion de tercero NO fijada por SHA de 40 caracteres (`" ref "`): " v, ln)
        return
    }
    # El comentario tiene que parecerse a una VERSION (`v7`, `v7.0.1`, `1.7.12`).
    # Un `# 0` o un `# ver luego` colaban con la regla anterior y dejaban el pin
    # sin la etiqueta que Dependabot necesita para actualizarlo.
    if (c !~ /v[0-9]/ && c !~ /[0-9]+\.[0-9]+/) {
        fail("uses-comment", "SHA sin comentario de version (`# vX.Y.Z`); Dependabot usa ese comentario para reportar y actualizar el pin: " v, ln)
        return
    }
    npinned++
}

# ---- regla 4 (recoleccion): referencias al contexto `secrets` ---------------
# GitHub documenta DOS sintaxis para leer un contexto, y ambas dan el mismo
# secreto: `secrets.NOMBRE` (property dereference) y `secrets['NOMBRE']` (index).
# Ademas, `toJSON(secrets)` vuelca el contexto ENTERO. Mirar solo la primera
# forma dejaba una via limpia para colar un secreto en un workflow alcanzable
# desde un fork, que es justo lo que esta regla existe para impedir.
function record_secret(nm, ln) {
    if (nm == "GITHUB_TOKEN") return
    if (!(nm in secretref)) { secretref[nm] = ln; nsecret++ }
}

function scan_secrets(s, ln,   i, j, prev, c, q, nm, inexpr) {
    i = 1
    while (1) {
        j = index(substr(s, i), "secrets")
        if (j == 0) return
        i = i + j - 1                       # posicion absoluta de la palabra
        prev = (i > 1) ? substr(s, i - 1, 1) : ""
        if (prev != "" && prev ~ /[A-Za-z0-9_]/) { i = i + 7; continue }

        j = i + 7
        while (substr(s, j, 1) == " ") j++
        c = substr(s, j, 1)

        if (c == ".") {                     # secrets.NOMBRE
            j++
            nm = ""
            while (substr(s, j, 1) ~ /[A-Za-z0-9_-]/) { nm = nm substr(s, j, 1); j++ }
            if (nm != "") record_secret(nm, ln)
        } else if (c == "[") {              # secrets['NOMBRE'] / secrets["NOMBRE"]
            j++
            while (substr(s, j, 1) == " ") j++
            q = substr(s, j, 1)
            if (q == "'" || q == "\"") {
                j++
                nm = ""
                while (substr(s, j, 1) != q && substr(s, j, 1) != "") { nm = nm substr(s, j, 1); j++ }
                if (nm != "") record_secret(nm, ln)
            } else {
                record_secret("<indice calculado>", ln)
            }
        } else if (c == ":") {
            # es la clave YAML `secrets:`, no una lectura del contexto.
        } else {
            # `secrets` a secas: solo cuenta dentro de una expresion ${{ ... }},
            # para no confundirlo con la palabra suelta en un `name:` o un
            # comentario. Cubre toJSON(secrets), que vuelca todos los secretos.
            inexpr = (index(substr(s, 1, i - 1), "${{") > 0)
            if (inexpr) record_secret("<contexto completo>", ln)
        }
        i = i + 7
    }
}

function record_trigger(name, ln) {
    name = unq(trim(name))
    if (name == "") return
    if (!(name in trig)) trig[name] = ln
}

function record_triggers_inline(v, ln,   body, n, i, parts) {
    sub(/[ ]*#.*$/, "", v)
    v = trim(v)
    if (v == "") return
    if (substr(v, 1, 1) == "[") {
        body = v
        sub(/^\[/, "", body)
        sub(/\][ ]*$/, "", body)
        n = split(body, parts, ",")
        for (i = 1; i <= n; i++) record_trigger(parts[i], ln)
    } else {
        record_trigger(v, ln)
    }
}

# ---- regla 2: todo trabajo declara `permissions:` ---------------------------
function finalize_job() {
    if (job != "") {
        if (job_perm == 0)
            fail("job-permissions", "el trabajo `" job "` no declara `permissions:`; heredaria los permisos por defecto del repositorio", job_line)
        if (job_body == 0)
            unmeas("job-permissions", "el trabajo `" job "` no tiene cuerpo reconocible; no puedo afirmar nada sobre sus permisos", job_line)
    }
    job = ""
}

BEGIN {
    # Unicos disparadores admitidos por el modelo de amenaza del repo.
    split("schedule workflow_dispatch push pull_request", _a, " ")
    for (_i in _a) allowed[_a[_i]] = 1

    in_bs = 0; bs_ind = 0
    section = ""; on_ind = -1; jobs_ind = -1; jobkey_ind = -1
    job = ""; job_perm = 0; job_line = 0; job_body = 0
    njobs = 0; nsecret = 0; npinned = 0; nlocal = 0
    nfail = 0; nunmeas = 0
    saw_on = 0; saw_jobs = 0; has_tab = 0
    wf_perm_seen = 0; wf_perm_val = ""; wf_perm_line = 0
    has_anchor = 0
}

# --- tabuladores: la indentacion deja de ser fiable --------------------------
index($0, "\t") > 0 { has_tab = 1 }

# --- anclas/alias YAML: fuera del alcance del escaner lexico -----------------
/^[ ]*[A-Za-z_0-9-]+:[ ]*[&*][A-Za-z_]/ { has_anchor = 1 }

# --- regla 4 (recoleccion): referencias a secretos, texto crudo --------------
{
    # Un comentario YAML puro no lee nada... SALVO que lleve `${{ }}` dentro: en
    # un bloque `run:`, GitHub expande la plantilla ANTES de que el shell vea la
    # almohadilla, asi que un `# ${{ secrets.X }}` si filtra. Se salta solo el
    # comentario sin plantilla (prosa que menciona `secrets.ALGO`).
    if (!(trim($0) ~ /^#/ && index($0, "${{") == 0))
        scan_secrets($0, FNR)
    if (trim($0) ~ /^secrets:[ ]*inherit[ ]*$/)
        fail("secrets-inherit", "`secrets: inherit` entrega TODOS los secretos del repositorio al workflow llamado", FNR)
}

# --- estructura --------------------------------------------------------------
{
    line = $0

    if (in_bs) {
        if (trim(line) == "") next
        if (ind(line) > bs_ind) next
        in_bs = 0
    }

    tl = trim(line)
    if (tl == "") next
    if (substr(tl, 1, 1) == "#") next
    ci = ind(line)

    u = tl
    sub(/^-[ ]+/, "", u)
    if (u ~ /^uses:/) check_uses(u, FNR)

    if (ci == 0) {
        finalize_job()
        k = keyof(line)
        section = k
        if (k == "on") {
            saw_on = 1; on_ind = -1
            record_triggers_inline(valof(line), FNR)
        } else if (k == "jobs") {
            saw_jobs = 1; jobs_ind = -1
        } else if (k == "permissions") {
            wf_perm_seen = 1
            wf_perm_line = FNR
            v = valof(line)
            sub(/[ ]*#.*$/, "", v)
            wf_perm_val = trim(v)
        }
    } else if (section == "on") {
        if (on_ind < 0) on_ind = ci
        if (ci == on_ind) {
            if (substr(tl, 1, 1) == "-") {
                nm = trim(substr(tl, 2))
                sub(/:.*$/, "", nm)
                record_trigger(nm, FNR)
            } else {
                k = keyof(line)
                if (k != "") record_trigger(k, FNR)
            }
        }
    } else if (section == "jobs") {
        if (jobs_ind < 0) jobs_ind = ci
        if (ci == jobs_ind) {
            finalize_job()
            job = keyof(line)
            if (job != "") { njobs++; job_perm = 0; job_line = FNR; jobkey_ind = -1; job_body = 0 }
        } else if (ci > jobs_ind && job != "") {
            job_body = 1
            if (jobkey_ind < 0) jobkey_ind = ci
            if (ci == jobkey_ind) {
                k = keyof(line)
                if (k == "permissions") {
                    job_perm = 1
                    # No basta con DECLARAR `permissions:`: la regla es "minimos
                    # por trabajo". Un `write-all`/`read-all` es una concesion en
                    # bloque, es decir, exactamente lo que la regla prohibe.
                    jpv = valof(line)
                    sub(/[ ]*#.*$/, "", jpv)
                    jpv = trim(jpv)
                    if (jpv != "" && jpv != "{}")
                        fail("job-permissions-broad", "el trabajo `" job "` concede permisos EN BLOQUE (`permissions: " jpv "`); se exige `{}` o un mapa explicito scope por scope", FNR)
                }
            }
        }
    }

    if (line ~ /:[ ]*[|>][-+0-9]*[ ]*$/) { in_bs = 1; bs_ind = ci }
}

END {
    finalize_job()

    if (has_tab)
        unmeas("parse", "el fichero contiene tabuladores: la indentacion no es fiable y no puedo auditarlo con garantias", 0)
    if (has_anchor)
        unmeas("parse", "el fichero usa anclas/alias YAML (&/ *): fuera del alcance de este escaner lexico", 0)
    if (!saw_on)
        unmeas("parse", "no encontre un bloque `on:` de nivel superior (recuerda: YAML 1.1 convierte `on` en booleano si no se cita; usa `on:` tal cual o `\"on\":`)", 0)
    if (!saw_jobs || njobs == 0)
        unmeas("parse", "no encontre trabajos bajo `jobs:`; no hay nada que auditar y eso no es un aprobado", 0)

    # ---- regla 1: solo disparadores del propio repositorio ------------------
    for (t in trig) {
        if (!(t in allowed)) {
            if (t == "pull_request_target")
                fail("trigger", "`pull_request_target` ejecuta en el contexto del repositorio destino con secretos y token de escritura, sobre codigo de un fork: prohibido en este repo", trig[t])
            else if (t == "workflow_run")
                fail("trigger", "`workflow_run` tambien corre en el contexto privilegiado del repositorio y puede originarse en un fork: prohibido en este repo", trig[t])
            else if (t == "issues" || t == "issue_comment" || t == "discussion" || t == "discussion_comment" || t == "pull_request_review" || t == "pull_request_review_comment")
                fail("trigger", "`" t "` se dispara con contenido escrito por terceros (inyeccion indirecta de prompts): prohibido en este repo", trig[t])
            else
                fail("trigger", "disparador `" t "` fuera de la lista permitida (schedule, workflow_dispatch, push, pull_request)", trig[t])
        }
    }

    # ---- regla 2 (nivel workflow) ------------------------------------------
    if (saw_jobs) {
        if (!wf_perm_seen)
            fail("wf-permissions", "el workflow no declara `permissions:` de nivel superior; se exige `permissions: {}` para no heredar el default del repositorio", 1)
        else if (wf_perm_val != "{}")
            fail("wf-permissions", "`permissions:` de nivel superior debe ser exactamente `{}` (encontrado: `" wf_perm_val "`); los permisos se conceden trabajo a trabajo", wf_perm_line)
    }

    # ---- regla 4: secretos + disparadores alcanzables por terceros ----------
    if (("pull_request" in trig) && nsecret > 0) {
        for (n in secretref)
            fail("secrets-untrusted", "el workflow se dispara con `pull_request` (alcanzable desde un fork) y lee el contexto de secretos (`" n "`); ningun trabajo que procese contenido no confiable puede recibir secretos", secretref[n])
    }

    # Si el fichero no es interpretable, no sostengo ningun FAIL estructural.
    if (has_tab || has_anchor) {
        if (nfail > 0)
            unmeas("parse", "descarto " nfail " hallazgo(s) estructural(es) de este fichero: no puedo sostenerlos sobre un YAML que no se interpretar", 0)
        nfail = 0
    }

    for (i = 1; i <= nfail; i++) print Fbuf[i]
    for (i = 1; i <= nunmeas; i++) print Ubuf[i]

    printf "STAT|jobs|%d\n", njobs
    printf "STAT|uses_pinned|%d\n", npinned
    printf "STAT|uses_local|%d\n", nlocal
    printf "STAT|secrets_no_github_token|%d\n", nsecret
    printf "STAT|fail|%d\n", nfail
    printf "STAT|unmeas|%d\n", nunmeas
}
