#!/usr/bin/env python3
"""Dry validator for the workflows: structure, hard rules of the threat model,
and bash syntax of every run block. It executes nothing remote.

EXIT CODES (doctrine: an rc=0 can never mean "I did not review it")
  0  I reviewed the file and it meets every rule.
  1  I reviewed the file and it BREAKS some rule.
  2  I COULD NOT REVIEW IT (PyYAML missing, the file does not exist, the YAML
     does not parse). It never degrades to 1: "I could not parse it" is not the
     same as "it is wrong", and above all it is not the same as "it is fine".
"""
import re
import subprocess
import sys
import tempfile
import os
import pathlib

RC_OK, RC_FAIL, RC_UNMEASURED = 0, 1, 2


def cannot_measure(msg):
    print(f"  COULD NOT MEASURE  {msg}", file=sys.stderr)
    print("  rc=2 means 'I did not check it', which is not the same as 'it is fine'.",
          file=sys.stderr)
    sys.exit(RC_UNMEASURED)


try:
    import yaml
except Exception as e:  # noqa: BLE001 - any import failure is "I cannot measure"
    cannot_measure(f"I cannot import PyYAML ({e}). Install it: pip install pyyaml")

if len(sys.argv) < 2:
    cannot_measure("usage: validate-workflow.py <workflow.yml> [...]")

# Commit SHA: 40 lowercase hex. A tag is mutable; whoever controls the action's
# account can repoint it to new code without changing the name.
SHA40 = re.compile(r"^[^@\s]+@[0-9a-f]{40}$")
# Container image pinned by immutable digest.
DIGEST = re.compile(r"@sha256:[0-9a-f]{64}$")
EXPR = re.compile(r"\$\{\{(.*?)\}\}", re.S)

FORBIDDEN_TRIGGERS = {
    "pull_request_target", "issues", "issue_comment", "discussion",
    "discussion_comment", "fork", "watch", "workflow_run", "repository_dispatch",
    "merge_group", "public", "gollum", "status", "registry_package",
}
ALLOWED_TRIGGERS = {"schedule", "workflow_dispatch"}
# The only job allowed to write. It is also the only one allowed to check out
# with credentials persisted, because it is the one that pushes.
WRITER_JOB = os.environ.get("WF_WRITER_JOB", "promote")
# The job that runs the candidate's tree. It must be read-only: it executes code
# that came from the commit being judged, so it is treated as untrusted.
CANDIDATE_JOB = os.environ.get("WF_CANDIDATE_JOB", "verify")
# Path (inside the workspace) that holds the candidate checkout. The writer job
# may MATERIALISE that tree -- it has to, in order to build what it pushes --
# but it must never EXECUTE anything from it: its scripts come from the trusted
# checkout instead. Interpolating this into a run block is the difference
# between building an artifact and running the attacker's code with a write token.
CANDIDATE_PATH = os.environ.get("WF_CANDIDATE_PATH", "source")
TRUSTED_PATH = os.environ.get("WF_TRUSTED_PATH", "tools")


def check_file(path):
    fails, oks = [], []

    def chk(cond, msg):
        (oks if cond else fails).append(msg)

    try:
        raw = path.read_text()
    except OSError as e:
        cannot_measure(f"I cannot read {path}: {e}")
    try:
        doc = yaml.safe_load(raw)
    except yaml.YAMLError as e:
        cannot_measure(f"{path} is not valid YAML: {str(e).splitlines()[0]}")
    if not isinstance(doc, dict) or "jobs" not in doc:
        cannot_measure(f"{path} does not look like a workflow (no 'jobs' key)")

    # -- triggers ------------------------------------------------------------
    # PyYAML turns the `on:` key into the boolean True (YAML 1.1).
    on = doc.get("on", doc.get(True))
    chk(on is not None, "the workflow declares triggers")
    triggers = set(on.keys()) if isinstance(on, dict) else (
        set(on) if isinstance(on, list) else {on})
    bad = triggers & FORBIDDEN_TRIGGERS
    chk(not bad, f"no forbidden trigger (found: {sorted(triggers)})")
    chk(triggers <= ALLOWED_TRIGGERS,
        f"only schedule/workflow_dispatch: {sorted(triggers)}")

    chk(doc.get("permissions") == {},
        f"workflow-level permissions is empty: {doc.get('permissions')!r}")
    chk("concurrency" in doc, "declares concurrency (no two promotions at once)")
    # A defaults.run.shell other than bash would make the 'bash -n' below
    # meaningless: the syntax check would stop measuring what actually runs.
    chk("defaults" not in doc,
        f"no workflow-level 'defaults' (it would change the shell under our feet): {doc.get('defaults')!r}")

    jobs = doc["jobs"]
    writers = []
    for name, job in jobs.items():
        if not isinstance(job, dict):
            chk(False, f"job '{name}' is not a map")
            continue

        # -- per-job permissions ----------------------------------------------
        perms = job.get("permissions")
        chk(isinstance(perms, dict) and perms,
            f"job '{name}' declares explicit permissions as a map (not inherited, not 'write-all'): {perms!r}")
        if isinstance(perms, dict):
            if perms.get("contents") == "write":
                writers.append(name)
            chk(not any(v == "write" for k, v in perms.items() if k != "contents"),
                f"job '{name}' asks for write in no scope other than contents: {perms!r}")
        chk("defaults" not in job, f"job '{name}' does not redefine defaults (shell)")

        # -- third-party reusable workflow -------------------------------------
        # jobs.<id>.uses has no 'steps': if only the steps are inspected, an
        # unpinned third-party reusable workflow gets in unnoticed.
        juses = job.get("uses")
        if juses:
            local = str(juses).startswith("./")
            chk(local or SHA40.match(str(juses)) is not None,
                f"job '{name}': reusable workflow pinned by 40-char SHA or local -> {juses}")
            chk("secrets" not in job,
                f"job '{name}': does not pass 'secrets' to a reusable workflow")

        # -- containers and services -------------------------------------------
        for key in ("container", "services"):
            spec = job.get(key)
            if not spec:
                continue
            items = spec.values() if key == "services" else [spec]
            for it in items:
                img = it if isinstance(it, str) else (it or {}).get("image", "")
                chk(DIGEST.search(str(img)) is not None,
                    f"job '{name}': {key} pinned by sha256 digest -> {img}")

        # -- third-party actions ------------------------------------------------
        for i, step in enumerate(job.get("steps") or []):
            uses = step.get("uses")
            if uses:
                local = str(uses).startswith("./") or str(uses).startswith("docker://")
                chk(SHA40.match(str(uses)) is not None or local,
                    f"job '{name}' step {i}: action pinned by 40-char SHA -> {uses}")
            chk("shell" not in step or step.get("shell") == "bash",
                f"job '{name}' step {i}: bash shell or default -> {step.get('shell')!r}")

            # -- credentials persisted in a checkout -------------------------
            # A checkout with credentials leaves the GITHUB_TOKEN written into
            # the runner's .git/config. In the job that RUNS the candidate tree
            # that hands the token to untrusted code: it is the exact pattern of
            # the publishing-token theft incident. Only the job that has to push
            # may persist them.
            if uses and "actions/checkout" in str(uses) and name != WRITER_JOB:
                with_ = step.get("with") or {}
                chk(with_.get("persist-credentials") is False,
                    f"job '{name}' step {i}: checkout with persist-credentials:false "
                    f"(it is {with_.get('persist-credentials')!r})")

    # -- separation of powers -------------------------------------------------
    chk(writers == [WRITER_JOB], f"the only job with contents:write = {writers}")
    cand = jobs.get(CANDIDATE_JOB)
    chk(isinstance(cand, dict) and cand.get("permissions") == {"contents": "read"},
        f"the job '{CANDIDATE_JOB}' that runs the candidate's code is read-only: "
        f"{cand.get('permissions') if isinstance(cand, dict) else cand!r}")

    # The candidate job must run the gates from the TRUSTED checkout, never the
    # ones the candidate itself ships: a commit that could supply its own gates
    # would be approving itself.
    if isinstance(cand, dict):
        cand_runs = " ".join(st.get("run", "") for st in (cand.get("steps") or []))
        if "scripts/gates" in cand_runs:
            chk(f"{TRUSTED_PATH}/scripts/gates" in cand_runs,
                f"job '{CANDIDATE_JOB}' runs the gates from the trusted checkout "
                f"('{TRUSTED_PATH}/'), not the ones shipped by the candidate")

    promote = jobs.get(WRITER_JOB)
    if isinstance(promote, dict):
        promote_runs = " ".join(st.get("run", "") for st in (promote.get("steps") or []))
        # The writer job may build the candidate tree, but every script it
        # EXECUTES has to come from the trusted checkout. Any bare invocation of
        # the candidate path is code the candidate controls, running with write.
        bad_exec = re.findall(r"(?:bash|sh|source|\.)\s+[\"\']?(?:\./)?"
                              + re.escape(CANDIDATE_PATH) + r"/\S+", promote_runs)
        chk(not bad_exec,
            f"the '{WRITER_JOB}' job executes nothing from the candidate tree "
            f"'{CANDIDATE_PATH}/': {bad_exec}")
        chk(f"{CANDIDATE_PATH}/scripts/gates" not in promote_runs,
            f"the '{WRITER_JOB}' job does not run gates from the candidate tree")

    # -- injection: interpolation inside a run --------------------------------
    interp = []
    for name, job in jobs.items():
        if not isinstance(job, dict):
            continue
        for i, step in enumerate(job.get("steps") or []):
            for m in EXPR.findall(step.get("run", "")):
                interp.append(f"{name}#{i}: ${{{{{m}}}}}")
    chk(not interp, f"zero \\${{{{ }}}} interpolations inside run blocks: {interp}")

    # -- the secrets context in ANY form --------------------------------------
    # Searching for the string "secrets." misses toJSON(secrets), secrets[...]
    # and secrets['X']. The inside of every ${{ }} expression is inspected.
    sec = [m.strip() for m in EXPR.findall(raw) if re.search(r"\bsecrets\b", m)]
    chk(not sec, f"the 'secrets' context appears in no expression: {sec}")

    # -- bash syntax of every run ---------------------------------------------
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
                cannot_measure("'bash' is missing: I cannot check the syntax of the run blocks")
            chk(res.returncode == 0,
                f"bash -n OK in job '{name}' step {i} ({step.get('name', '?')}) {res.stderr.strip()}")

    print(f"\n=== {path}")
    for o in oks:
        print(f"  OK    {o}")
    for f in fails:
        print(f"  FAIL  {f}")
    print(f"\n  {len(oks)} OK / {len(fails)} FAIL")
    return not fails


all_ok = True
for arg in sys.argv[1:]:
    pth = pathlib.Path(arg)
    if not pth.is_file():
        cannot_measure(f"the file {pth} does not exist")
    all_ok = check_file(pth) and all_ok

sys.exit(RC_OK if all_ok else RC_FAIL)
