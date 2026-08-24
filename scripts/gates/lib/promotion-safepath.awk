# scripts/gates/lib/promotion-safepath.awk
#
# Structural scanner for one invariant of the promotion model, written in POSIX
# awk: it needs no PyYAML, no zizmor, no actionlint and no network.
#
# THE INVARIANT
#   The release `verify` job runs MAIN's gates with the CANDIDATE tree as the
#   working directory. `python3 -c`, a heredoc on stdin and `python3 -` all put
#   the working directory first on `sys.path`, so a `yaml.py` or `json.py` in
#   the candidate would be imported by the gates judging it. That defeats the
#   sentence the whole promotion model rests on: WHO JUDGES IS ALWAYS MAIN.
#
#   `PYTHONSAFEPATH: '1'` is the mitigation, and this file is the check that
#   fails if the mitigation is removed or a future step reintroduces the shape.
#
# THE RULE - two independent triggers
#   T1, THE PROMOTION SHAPE. A job that checks out TWO OR MORE trees and then
#   runs a step with a `working-directory:` is one tree judging another. Whether
#   python is visible in the `run:` line is irrelevant: `run-all.sh` reaches
#   python through the gates it invokes, and a rule that only looks for the word
#   `python` reads that as clean. Measured: written that way first, this gate
#   passed the real release.yml AND its mutant with PYTHONSAFEPATH deleted -
#   a false green on the one file it was written for.
#   T2, THE HAND-WRITTEN SHAPE. A step whose `run:` invokes python while its
#   effective working directory is not the workspace root (a step
#   `working-directory:`, a job `defaults: run: working-directory:`, or a `cd`
#   in the same block).
#
#   Either trigger requires PYTHONSAFEPATH in scope: the workflow `env:` or the
#   job `env:` for T1 (the exposure spans steps), plus the step `env:` for T2.
#
# Invoked by scripts/gates/gate-promotion-safepath.sh with -v FILE=<path>.
#
# Output protocol (one line per finding):
#   FAIL|<file>|<line>|<rule>|<message>
#   UNMEAS|<file>|<line>|<rule>|<message>
#   STAT|<key>|<value>
#
# Known limitations (declared, not hidden):
#   - Lexical analysis driven by indentation, not a YAML parser. Tabs, anchors
#     and aliases, or a file with no `jobs:`, produce UNMEAS and never silence.
#   - Python reached INDIRECTLY - through `make`, `npm`, a shell script, or an
#     action's own code - is not seen. The rule is about what the workflow
#     writes, which is what a future edit to this repository would write.
#   - It does not judge whether the checkout is trusted: it cannot know. A step
#     that runs python outside the workspace root must declare PYTHONSAFEPATH
#     whatever the tree is, because the declaration costs nothing and the
#     distinction is not machine-checkable.

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

function fail(rule, msg, ln) {
    nfail++
    Fbuf[nfail] = sprintf("FAIL|%s|%d|%s|%s", FILE, ln, rule, msg)
}

function unmeas(rule, msg, ln) {
    nunmeas++
    Ubuf[nunmeas] = sprintf("UNMEAS|%s|%d|%s|%s", FILE, ln, rule, msg)
}

# `python`, `python3`, `python3.12`, at the start of a command or after a shell
# separator. Padded with spaces by the caller so the edges match too.
function runs_python(b) {
    return (b ~ /[ ;&|(]python[0-9.]*[ ]/)
}

function changes_dir(b) {
    return (b ~ /[ ;&|(]cd[ ]/)
}

# CPython: PYTHONSAFEPATH takes effect when it is set to a NON-EMPTY string. So
# `'0'` and `'false'` switch it ON - the value is not read as a boolean - and
# only an empty value leaves the interpreter prepending the working directory.
# Declaring the key is therefore not enough: `PYTHONSAFEPATH: ''` is a mitigation
# that does nothing, and reads in review exactly like one that does.
function safepath_on(l,   v) {
    v = valof(l)
    sub(/[ ]*#.*$/, "", v)
    return (unq(trim(v)) != "")
}

function finalize_step(   b, why, who) {
    if (step_open) {
        nsteps++
        if (step_wd != "") job_any_wd = step_wd
        if (step_run != "") {
            b = " " step_run " "
            gsub(/\t/, " ", b)
            if (changes_dir(b) && job_cd == "") job_cd = (step_name != "") ? step_name : "an unnamed step"
            if (runs_python(b)) {
                npython++
                why = ""
                if (step_wd != "")     why = "the step declares `working-directory: " step_wd "`"
                else if (job_wd != "") why = "job `" job "` defaults to `working-directory: " job_wd "`"
                else if (changes_dir(b)) why = "the `run:` block changes directory with `cd`"
                if (why != "") {
                    who = (step_name != "") ? "step `" step_name "`" : "a step"
                    npend++
                    Pline[npend] = step_line
                    Psafe[npend] = (step_safe || job_safe) ? 1 : 0
                    Pseen[npend] = (step_seen || job_seen) ? 1 : 0
                    Pmsg[npend]  = who " runs python outside the workspace root (" why ") and PYTHONSAFEPATH is not in scope at the step, the job or the workflow `env:`. The working directory goes first on sys.path, so a `yaml.py` in the tree being judged would be imported by the judge"
                }
            }
        }
    }
    step_open = 0; step_run = ""; step_wd = ""; step_safe = 0; step_seen = 0
    step_name = ""; in_step_env = 0; step_key_ind = -1; step_env_ind = -1
}

# T1: two trees in one workspace, and a step that runs inside one of them.
function finalize_job(   how) {
    finalize_step()
    if (job != "") {
        if (job_wd != "") job_any_wd = job_wd
        how = ""
        if (job_any_wd != "") how = "runs a step with `working-directory: " job_any_wd "`"
        else if (job_cd != "") how = "runs `cd` inside the `run:` block of " job_cd
        if (job_checkouts >= 2 && how != "") {
            ntwotree++
            npend++
            Pline[npend] = job_line
            Psafe[npend] = job_safe ? 1 : 0
            Pseen[npend] = job_seen ? 1 : 0
            Pmsg[npend]  = "job `" job "` checks out " job_checkouts " trees and " how ": one tree is judging another, and PYTHONSAFEPATH is not in scope at the job or the workflow `env:`. Anything that job runs - directly or through a script - imports the judged tree first from sys.path"
        }
    }
    job = ""; job_checkouts = 0; job_any_wd = ""; job_wd = ""; job_safe = 0; job_seen = 0; job_line = 0; job_cd = ""
}

function parse_step_key(t, ln,   k, v) {
    k = keyof(t)
    in_step_env = 0
    last_was_run = 0
    if (k == "env")                    { in_step_env = 1; step_env_ind = -1 }
    else if (k == "name")              { step_name = unq(valof(t)) }
    else if (k == "working-directory") { step_wd = unq(valof(t)) }
    else if (k == "uses") {
        v = valof(t)
        sub(/[ ]*#.*$/, "", v)
        v = unq(trim(v))
        if (v ~ /^actions\/checkout@/) job_checkouts++
    }
    else if (k == "run") {
        v = valof(t)
        if (v ~ /^[|>][-+0-9]*$/) last_was_run = 1     # block scalar on the next lines
        else step_run = step_run " " v
    }
}

function handle_step_line(tl, ci, ln,   u, off) {
    if (step_ind < 0) {
        if (substr(tl, 1, 1) == "-") step_ind = ci
        else return
    }
    if (ci == step_ind && substr(tl, 1, 1) == "-") {
        finalize_step()
        step_open = 1
        u = tl
        sub(/^-[ ]*/, "", u)
        off = length(tl) - length(u)
        step_key_ind = ci + off
        step_line = ln
        parse_step_key(u, ln)
        return
    }
    if (!step_open) return
    if (ci == step_key_ind) { parse_step_key(tl, ln); return }
    if (ci > step_key_ind && in_step_env) {
        if (step_env_ind < 0) step_env_ind = ci
        if (ci == step_env_ind && keyof(tl) == "PYTHONSAFEPATH") { step_seen = 1; if (safepath_on(tl)) step_safe = 1 }
    }
}

BEGIN {
    in_bs = 0; bs_ind = 0; bs_capture = 0; last_was_run = 0
    section = ""; jobs_ind = -1; jobkey_ind = -1; wf_env_ind = -1
    job = ""; job_safe = 0; job_seen = 0; job_wd = ""; job_env_ind = -1
    job_checkouts = 0; job_any_wd = ""; job_line = 0; job_cd = ""
    in_wf_env = 0; in_job_env = 0; in_defaults = 0; in_steps = 0
    step_ind = -1; step_open = 0; step_run = ""; step_wd = ""
    step_safe = 0; step_seen = 0; step_name = ""; step_key_ind = -1; step_env_ind = -1; step_line = 0
    wf_safe = 0; wf_seen = 0; saw_jobs = 0; njobs = 0; nsteps = 0; npython = 0
    ntwotree = 0; npend = 0; nguarded = 0
    nfail = 0; nunmeas = 0; has_tab = 0; has_anchor = 0
}

{
    line = $0
    if (index(line, "\t") > 0) has_tab = 1
    if (line ~ /^[ ]*[A-Za-z_0-9-]+:[ ]*[&*][A-Za-z_]/) has_anchor = 1

    # Inside a block scalar: only a `run:` body is collected, everything else is
    # skipped. A blank line does not close the block.
    if (in_bs) {
        if (trim(line) == "") next
        if (ind(line) > bs_ind) {
            if (bs_capture) step_run = step_run " " trim(line)
            next
        }
        in_bs = 0; bs_capture = 0
    }

    tl = trim(line)
    if (tl == "") next
    if (substr(tl, 1, 1) == "#") next
    ci = ind(line)
    last_was_run = 0

    if (ci == 0) {
        finalize_job()
        in_steps = 0; in_job_env = 0; in_defaults = 0
        k = keyof(line)
        section = k
        in_wf_env = (k == "env"); wf_env_ind = -1
        if (k == "jobs") saw_jobs = 1
    } else if (in_wf_env) {
        if (wf_env_ind < 0) wf_env_ind = ci
        if (ci == wf_env_ind && keyof(line) == "PYTHONSAFEPATH") { wf_seen = 1; if (safepath_on(line)) wf_safe = 1 }
    } else if (section == "jobs") {
        if (jobs_ind < 0) jobs_ind = ci
        if (ci == jobs_ind) {
            finalize_job()
            job = keyof(line)
            if (job != "") {
                njobs++; job_line = FNR; jobkey_ind = -1
                in_job_env = 0; in_defaults = 0; in_steps = 0; step_ind = -1
            }
        } else if (ci > jobs_ind && job != "") {
            if (jobkey_ind < 0) jobkey_ind = ci
            if (ci == jobkey_ind) {
                finalize_step()
                k = keyof(line)
                in_job_env = (k == "env"); job_env_ind = -1
                in_defaults = (k == "defaults")
                in_steps = (k == "steps"); if (in_steps) step_ind = -1
            } else if (ci > jobkey_ind) {
                if (in_job_env) {
                    if (job_env_ind < 0) job_env_ind = ci
                    if (ci == job_env_ind && keyof(line) == "PYTHONSAFEPATH") { job_seen = 1; if (safepath_on(line)) job_safe = 1 }
                } else if (in_defaults) {
                    if (keyof(line) == "working-directory") job_wd = unq(valof(line))
                } else if (in_steps) {
                    handle_step_line(tl, ci, FNR)
                }
            }
        }
    }

    if (line ~ /:[ ]*[|>][-+0-9]*[ ]*$/) { in_bs = 1; bs_ind = ci; bs_capture = last_was_run }
}

END {
    finalize_job()

    for (i = 1; i <= npend; i++) {
        if (Psafe[i] || wf_safe) nguarded++
        else if (Pseen[i] || wf_seen)
            fail("python-safepath", Pmsg[i] ". PYTHONSAFEPATH IS declared here, with an empty value: CPython only acts on a non-empty string, so that declaration mitigates nothing while reading like it does", Pline[i])
        else
            fail("python-safepath", Pmsg[i], Pline[i])
    }

    if (has_tab)
        unmeas("parse", "the file contains tabs: indentation is not reliable and I cannot audit it with any guarantee", 0)
    if (has_anchor)
        unmeas("parse", "the file uses YAML anchors/aliases (& / *): out of scope for this lexical scanner", 0)
    if (!saw_jobs || njobs == 0)
        unmeas("parse", "no jobs found under `jobs:`; there is nothing to audit and that is not a pass", 0)

    if (has_tab || has_anchor) {
        if (nfail > 0)
            unmeas("parse", "discarding " nfail " finding(s) from this file: I cannot stand behind them on a YAML I do not know how to interpret", 0)
        nfail = 0
    }

    for (i = 1; i <= nfail; i++) print Fbuf[i]
    for (i = 1; i <= nunmeas; i++) print Ubuf[i]

    printf "STAT|jobs|%d\n", njobs
    printf "STAT|steps|%d\n", nsteps
    printf "STAT|python_steps|%d\n", npython
    printf "STAT|two_tree_jobs|%d\n", ntwotree
    printf "STAT|guarded|%d\n", nguarded
    printf "STAT|fail|%d\n", nfail
    printf "STAT|unmeas|%d\n", nunmeas
}
