# scripts/gates/lib/workflow-hardening.awk
#
# Structural scanner for a GitHub Actions workflow, written in POSIX awk.
# It needs no PyYAML, no zizmor, no actionlint and no network: it is the gate
# of last resort, the one that keeps measuring when no tooling is installed.
#
# Invoked by scripts/gates/gate-workflow-hardening.sh with -v FILE=<path>.
#
# Output protocol (one line per finding):
#   FAIL|<file>|<line>|<rule>|<message>
#   UNMEAS|<file>|<line>|<rule>|<message>
#   STAT|<key>|<value>
#
# Known limitations (declared, not hidden):
#   - This is a lexical analysis driven by indentation, not a YAML parser. So
#     for anything it cannot interpret safely (tabs, a missing `on:` or
#     `jobs:`, a `uses:` whose value lives on another line) it emits UNMEAS and
#     NEVER silence.
#   - It does not understand YAML anchors/aliases (&x / *x). If they show up,
#     it emits UNMEAS.
#   - It does not evaluate job-level `if:`: rule 4 (secrets) is applied at the
#     workflow level, which is the strict reading and the one that cannot be
#     dodged with a badly reasoned conditional.

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

# Findings are buffered and printed in END: if the file turns out not to be
# safely interpretable (tabs, anchors), the structural FAILs are DISCARDED and
# the file becomes "I could not measure". Asserting a concrete failure from an
# indentation I do not understand would be lying.
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

# ---- rule 3: `uses:` pinned to a 40-character SHA --------------------------
function check_uses(u, ln,   v, c, cpos, ref, at, digest) {
    v = trim(substr(u, 6))
    if (v == "") {
        unmeas("uses-pin", "`uses:` with no value on the same line; the lexical scanner cannot resolve it", ln)
        return
    }
    cpos = index(v, "#")
    if (cpos > 0) { c = substr(v, cpos); v = trim(substr(v, 1, cpos - 1)) } else { c = "" }
    v = unq(v)
    if (v == "") { unmeas("uses-pin", "`uses:` with an empty value", ln); return }

    # Local references: not third-party code, they live in this repo.
    if (substr(v, 1, 2) == "./" || substr(v, 1, 3) == "../") { nlocal++; return }

    if (substr(v, 1, 9) == "docker://") {
        at = index(v, "@sha256:")
        if (at == 0) {
            fail("uses-pin", "docker image without an immutable digest (@sha256:...): " v, ln)
        } else {
            digest = substr(v, at + 8)
            if (!ishex(digest, 64)) fail("uses-pin", "malformed sha256 digest: " v, ln)
            else npinned++
        }
        return
    }

    at = index(v, "@")
    if (at == 0) {
        fail("uses-pin", "`uses:` without `@ref`; an action with no reference is not reproducible: " v, ln)
        return
    }
    ref = substr(v, at + 1)
    if (!ishex40(ref)) {
        fail("uses-pin", "third-party action NOT pinned to a 40-character SHA (`" ref "`): " v, ln)
        return
    }
    # The comment has to look like a VERSION (`v7`, `v7.0.1`, `1.7.12`).
    # A `# 0` or a `# check later` used to slip through the previous rule and
    # left the pin without the tag Dependabot needs to update it.
    if (c !~ /v[0-9]/ && c !~ /[0-9]+\.[0-9]+/) {
        fail("uses-comment", "SHA without a version comment (`# vX.Y.Z`); Dependabot uses that comment to report and update the pin: " v, ln)
        return
    }
    npinned++
}

# ---- rule 4 (collection): references to the `secrets` context --------------
# GitHub documents TWO syntaxes for reading a context, and both hand back the
# same secret: `secrets.NAME` (property dereference) and `secrets['NAME']`
# (index). On top of that, `toJSON(secrets)` dumps the WHOLE context. Looking
# only at the first form left a clean path to smuggle a secret into a workflow
# reachable from a fork, which is exactly what this rule exists to prevent.
function record_secret(nm, ln) {
    if (nm == "GITHUB_TOKEN") return
    if (!(nm in secretref)) { secretref[nm] = ln; nsecret++ }
}

function scan_secrets(s, ln,   i, j, prev, c, q, nm, inexpr) {
    i = 1
    while (1) {
        j = index(substr(s, i), "secrets")
        if (j == 0) return
        i = i + j - 1                       # absolute position of the word
        prev = (i > 1) ? substr(s, i - 1, 1) : ""
        if (prev != "" && prev ~ /[A-Za-z0-9_]/) { i = i + 7; continue }

        j = i + 7
        while (substr(s, j, 1) == " ") j++
        c = substr(s, j, 1)

        if (c == ".") {                     # secrets.NAME
            j++
            nm = ""
            while (substr(s, j, 1) ~ /[A-Za-z0-9_-]/) { nm = nm substr(s, j, 1); j++ }
            if (nm != "") record_secret(nm, ln)
        } else if (c == "[") {              # secrets['NAME'] / secrets["NAME"]
            j++
            while (substr(s, j, 1) == " ") j++
            q = substr(s, j, 1)
            if (q == "'" || q == "\"") {
                j++
                nm = ""
                while (substr(s, j, 1) != q && substr(s, j, 1) != "") { nm = nm substr(s, j, 1); j++ }
                if (nm != "") record_secret(nm, ln)
            } else {
                record_secret("<computed index>", ln)
            }
        } else if (c == ":") {
            # this is the YAML key `secrets:`, not a read of the context.
        } else {
            # bare `secrets`: only counts inside a `${{ ... }}` expression, so
            # it is not confused with the plain word in a `name:` or in a
            # comment. Covers toJSON(secrets), which dumps every secret.
            inexpr = (index(substr(s, 1, i - 1), "${{") > 0)
            if (inexpr) record_secret("<full context>", ln)
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

# ---- rule 2: every job declares `permissions:` -----------------------------
function finalize_job() {
    if (job != "") {
        if (job_perm == 0)
            fail("job-permissions", "job `" job "` does not declare `permissions:`; it would inherit the repository default permissions", job_line)
        if (job_body == 0)
            unmeas("job-permissions", "job `" job "` has no recognizable body; I cannot assert anything about its permissions", job_line)
    }
    job = ""
}

BEGIN {
    # The only triggers allowed by this repo's threat model.
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

# --- tabs: indentation stops being trustworthy ------------------------------
index($0, "\t") > 0 { has_tab = 1 }

# --- YAML anchors/aliases: out of scope for a lexical scanner ---------------
/^[ ]*[A-Za-z_0-9-]+:[ ]*[&*][A-Za-z_]/ { has_anchor = 1 }

# --- rule 4 (collection): secret references, raw text ----------------------
{
    # A pure YAML comment reads nothing... UNLESS it carries `${{ }}` inside:
    # in a `run:` block GitHub expands the template BEFORE the shell ever sees
    # the hash sign, so a `# ${{ secrets.X }}` does leak. Only the comment
    # without a template is skipped (prose that mentions `secrets.SOMETHING`).
    if (!(trim($0) ~ /^#/ && index($0, "${{") == 0))
        scan_secrets($0, FNR)
    if (trim($0) ~ /^secrets:[ ]*inherit[ ]*$/)
        fail("secrets-inherit", "`secrets: inherit` hands EVERY repository secret to the called workflow", FNR)
}

# --- structure ---------------------------------------------------------------
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
                    # Declaring `permissions:` is not enough: the rule is
                    # "minimum per job". A `write-all`/`read-all` is a bulk
                    # grant, that is, exactly what the rule forbids.
                    jpv = valof(line)
                    sub(/[ ]*#.*$/, "", jpv)
                    jpv = trim(jpv)
                    if (jpv != "" && jpv != "{}")
                        fail("job-permissions-broad", "job `" job "` grants permissions IN BULK (`permissions: " jpv "`); `{}` or an explicit scope-by-scope map is required", FNR)
                }
            }
        }
    }

    if (line ~ /:[ ]*[|>][-+0-9]*[ ]*$/) { in_bs = 1; bs_ind = ci }
}

END {
    finalize_job()

    if (has_tab)
        unmeas("parse", "the file contains tabs: indentation is not reliable and I cannot audit it with any guarantee", 0)
    if (has_anchor)
        unmeas("parse", "the file uses YAML anchors/aliases (& / *): out of scope for this lexical scanner", 0)
    if (!saw_on)
        unmeas("parse", "no top-level `on:` block found (remember: YAML 1.1 turns `on` into a boolean if it is not quoted; use `on:` as is or `\"on\":`)", 0)
    if (!saw_jobs || njobs == 0)
        unmeas("parse", "no jobs found under `jobs:`; there is nothing to audit and that is not a pass", 0)

    # ---- rule 1: only triggers owned by this repository --------------------
    for (t in trig) {
        if (!(t in allowed)) {
            if (t == "pull_request_target")
                fail("trigger", "`pull_request_target` runs in the context of the target repository with secrets and a write token, over code from a fork: forbidden in this repo", trig[t])
            else if (t == "workflow_run")
                fail("trigger", "`workflow_run` also runs in the privileged context of the repository and can originate in a fork: forbidden in this repo", trig[t])
            else if (t == "issues" || t == "issue_comment" || t == "discussion" || t == "discussion_comment" || t == "pull_request_review" || t == "pull_request_review_comment")
                fail("trigger", "`" t "` fires on content written by third parties (indirect prompt injection): forbidden in this repo", trig[t])
            else
                fail("trigger", "trigger `" t "` is outside the allowed list (schedule, workflow_dispatch, push, pull_request)", trig[t])
        }
    }

    # ---- rule 2 (workflow level) -------------------------------------------
    if (saw_jobs) {
        if (!wf_perm_seen)
            fail("wf-permissions", "the workflow does not declare a top-level `permissions:`; `permissions: {}` is required so it does not inherit the repository default", 1)
        else if (wf_perm_val != "{}")
            fail("wf-permissions", "top-level `permissions:` must be exactly `{}` (found: `" wf_perm_val "`); permissions are granted job by job", wf_perm_line)
    }

    # ---- rule 4: secrets + triggers reachable by third parties -------------
    if (("pull_request" in trig) && nsecret > 0) {
        for (n in secretref)
            fail("secrets-untrusted", "the workflow fires on `pull_request` (reachable from a fork) and reads the secrets context (`" n "`); no job that processes untrusted content may receive secrets", secretref[n])
    }

    # If the file is not interpretable, I do not stand behind any structural FAIL.
    if (has_tab || has_anchor) {
        if (nfail > 0)
            unmeas("parse", "discarding " nfail " structural finding(s) from this file: I cannot stand behind them on a YAML I do not know how to interpret", 0)
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
