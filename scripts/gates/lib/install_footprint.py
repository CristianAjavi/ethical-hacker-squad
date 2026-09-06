#!/usr/bin/env python3
"""Refuse a tracked file that nobody declared as part of what gets installed.

THE HOLE THIS FILLS.  A plugin installed from a marketplace lands in
`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`, and that directory
is the whole work tree minus `.git` - measured on a real cache, where an
unrelated plugin left 390 files including its `.github/` and its `.mcp.json`.
Nothing prunes on the way. Measured here: **1205** tracked files travel, and
`gate-plugin-integrity.sh` section 4 looks at **41** of them (`skills agents
commands hooks`, of which only the first two exist). **1164 files - 96.6 % -
reach a stranger's disk with no control reading them at all.**

WHAT IS MEASURED.  Every path `git ls-files` reports, assigned to the policy in
`data/install-footprint.json` whose prefix is the longest one that matches, and
then three questions per file: is its extension one this root declared, is the
execute bit set where the root says it must not be, does it contain a NUL byte
where the root says it must not. The number this gate exists to print is the
first one: **coverage** - how many of the tracked files any policy claims. The
failure mode is *a file nobody declared*, not *a file on a blocklist*, because a
blocklist only ever catches what somebody already thought of.

EVERY QUESTION IS ASKED OF THE GIT OBJECT, NEVER OF THE WORK TREE.  The mode
comes from `git ls-files -s` and so do the bytes, read back with
`git cat-file --batch`. This file used to read the mode from the index and then
open `<root>/<path>` for the bytes, and that split answered two different
questions about two different files. It cost two holes, both reproduced:

*   A tracked symlink passed with rc=0. `skills/referencia.md -> /etc/passwd` is
    mode `120000`; the extension is declared, no execute bit is set, and the NUL
    check followed the link and answered about `/etc/passwd`. The verdict on one
    commit then depended on what happened to be outside the repository that day.
*   An uncommitted local edit switched the check off. Plain text laid over a
    blob that carries NUL bytes gave rc=0, while `git status` saw the change and
    the clone - which is what the stranger receives - still carried the NULs.

Reading the object closes both: what this gate judges is what travels.

A MODE THAT IS NOT `100644` OR `100755` IS AN UNDECLARED SHAPE, and a finding in
its own right, not waivable by an exemption. A symlink (`120000`) carries no
content - it carries a path, and it resolves against the disk of whoever opens
it. A gitlink (`160000`) drags in an entire tree from a repository this one does
not control and this gate has never read.

WHY EACH ROOT GETS ITS OWN RULE.  `skills/` is Markdown that is never executed,
so an execute bit there is a real question. `scripts/` is 99 executables on
purpose and `bench/` is 5 more. Applying the `skills/` rule to the whole tree
would have reported 104 executables and one ELF fixture as defects - 105 red
lines, every one of them correct code. A gate whose first red accuses the
compliant is a gate somebody switches off.

THE EXTENSION MATCH IS CASE-SENSITIVE, DELIBERATELY.  A policy declaring `py`
does not claim `.PY`, and a file called `SETUP.PY` is reported. That reads as a
false positive and it is not one: this gate exists to name the shape nobody
declared, and nobody declared an upper-case extension. Folding case here would
mean this reader deciding that two spellings are the same file type - which is
true on this laptop's case-insensitive volume and false on the Linux box that
runs CI, so the folding itself would travel worse than the finding does.

THE POLICY FILE IS TYPE-CHECKED BEFORE IT IS OBEYED.  A key present but of the
wrong type is a check that switches itself off in silence: `"executable":
"false"` is a non-empty string and therefore true, so the execute-bit rule stops
firing while the policy still reads as if it forbade one; `"extensions": "md"`
is not a list of one extension but a list of the letters `m` and `d`, so `d.md`
passes and `a.md` does not. Both were measured. A wrong type is rc=2 naming the
policy and the key - never a quiet pass.

WHAT THIS CANNOT ANSWER.

*   Whether a declared file is SAFE. A policy says `bench/` may hold `.py`; it
    says nothing about what that Python does. This gate reads shape - name,
    mode, and whether the bytes are text - and nothing about content. The
    fixtures under `bench/` are hostile on purpose and this gate passes them.
*   Whether an UNTRACKED file travels. `git ls-files` reads the index, so a file
    that exists on disk and was never added is invisible here. It is also
    invisible to `git clone`, which is what builds the cache - but the two are
    only the same as long as the cache really is a clone.
*   Whether the install prunes anything. Measured on one cache on one machine.
    If a future Claude Code drops `.github/` on install, this gate keeps
    guarding a file that no longer travels, and would not notice.

Exit codes: 0 = measured and clean | 1 = measured and fails | 2 = could not measure.
"""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys

REQUIRED_KEYS = ("id", "prefix", "why", "extensions", "executable", "binary",
                 "exemptions")
MIN_REASON = 20

# The only two modes that travel as content a policy can have an opinion about.
FILE_MODE = "100644"
EXEC_MODE = "100755"
REGULAR_MODES = (FILE_MODE, EXEC_MODE)

# mode -> (what it is, why a policy cannot vouch for it)
UNDECLARED_SHAPES = {
    "120000": (
        "a symlink",
        "a symlink carries no content of its own - it carries a path, and it "
        "resolves against the disk of whoever opens it. The bytes a stranger "
        "ends up reading are not in this repository at all",
    ),
    "160000": (
        "a gitlink (a submodule)",
        "a gitlink drags in an entire tree from a repository this one does not "
        "control, and no policy here has read a single file of it",
    ),
}


def unmeasurable(reason: str) -> int:
    print("UNMEASURABLE %s" % reason)
    return 2


def extension_of(rel: str) -> str:
    """The extension without its dot, or "" for a name that has none.

    A leading dot is part of the name, not a separator: `.gitignore` has no
    extension and `.env.example` has `example`. Getting this backwards would
    hand every dotfile in the tree an extension nobody declared.
    """
    name = rel.rsplit("/", 1)[-1]
    cut = name.rfind(".")
    return name[cut + 1:] if cut > 0 else ""


def percent(part: int, whole: int) -> str:
    """Never round an incomplete coverage up to a round 100.0.

    An instrument that reports 100.0 % while one file is unaccounted for is
    lying in the direction that costs the most.
    """
    if whole <= 0:
        return "0.0"
    pct = 100.0 * part / whole
    text = "%.1f" % pct
    if part < whole and text == "100.0":
        return "99.9"
    if part > 0 and text == "0.0":
        return "0.1"
    return text


def _shape_rank(mode: str) -> int:
    """How much a mode asks of this gate, for picking one stage of an unmerged path."""
    if mode not in REGULAR_MODES:
        return 2
    return 1 if mode == EXEC_MODE else 0


def list_tracked(root: pathlib.Path):
    """[(path, mode, sha)] from the git index, or raise LookupError."""
    try:
        proc = subprocess.run(
            ["git", "-C", str(root), "ls-files", "-s", "-z"],
            capture_output=True,
        )
    except OSError as exc:
        raise LookupError("git could not be run: %s" % exc)
    if proc.returncode != 0:
        detail = proc.stderr.decode("utf-8", "replace").strip().splitlines()
        raise LookupError(
            "git ls-files failed in %s (rc=%d): %s"
            % (root, proc.returncode, detail[0] if detail else "no message")
        )
    try:
        raw = proc.stdout.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise LookupError("git ls-files returned bytes that are not UTF-8: %s" % exc)

    seen = {}
    for entry in raw.split("\0"):
        if not entry:
            continue
        meta, _, rel = entry.partition("\t")
        if not rel:
            raise LookupError("git ls-files -s produced a line with no path: %r" % entry)
        fields = meta.split(" ")
        if len(fields) < 2:
            raise LookupError(
                "git ls-files -s produced a line with no mode and sha: %r" % entry
            )
        mode, sha = fields[0], fields[1]
        # An unmerged index reports the same path at several stages. Keep the
        # path once, and keep the stage that asks the most of this gate: a mode
        # nobody declared beats an execute bit, which beats a plain file.
        if rel not in seen or _shape_rank(mode) > _shape_rank(seen[rel][0]):
            seen[rel] = (mode, sha)
    if not seen:
        # A zero from an instrument that did not measure is not an absence.
        raise LookupError(
            "git ls-files reported zero files in %s: that is a blind zero, not a "
            "clean tree" % root
        )
    return sorted((rel, mode, sha) for rel, (mode, sha) in seen.items())


def read_blobs(root: pathlib.Path, shas):
    """{sha: bytes} for every sha asked for, in ONE git process.

    Raises LookupError if git will not hand over a blob the index just listed:
    a file whose bytes cannot be read is not a file that passed.
    """
    wanted = sorted(set(shas))
    if not wanted:
        return {}
    payload = "".join(sha + "\n" for sha in wanted).encode("ascii")
    try:
        proc = subprocess.run(
            ["git", "-C", str(root), "cat-file", "--batch"],
            input=payload, capture_output=True,
        )
    except OSError as exc:
        raise LookupError("git cat-file could not be run: %s" % exc)
    if proc.returncode != 0:
        detail = proc.stderr.decode("utf-8", "replace").strip().splitlines()
        raise LookupError(
            "git cat-file failed in %s (rc=%d): %s"
            % (root, proc.returncode, detail[0] if detail else "no message")
        )

    # `<oid> SP <type> SP <size> LF <contents> LF` per request, or `<oid> SP
    # missing LF` for one git will not produce.
    buf = proc.stdout
    out = {}
    at = 0
    for sha in wanted:
        end = buf.find(b"\n", at)
        if end < 0:
            raise LookupError(
                "git cat-file stopped before answering for %s: the blob the index "
                "lists could not be read, and an unreadable blob is not a clean one"
                % sha
            )
        header = buf[at:end].decode("utf-8", "replace").split(" ")
        at = end + 1
        if len(header) < 3:
            raise LookupError(
                "git cat-file answered %r for %s, which the index lists as a blob: "
                "an object that is not there cannot be judged clean"
                % (" ".join(header), sha)
            )
        try:
            size = int(header[2])
        except ValueError:
            raise LookupError(
                "git cat-file gave a size that is not a number for %s: %r"
                % (sha, header[2])
            )
        out[sha] = buf[at:at + size]
        at += size + 1  # the LF git writes after the contents
    return out


def type_error(pid, key: str, value, want: str) -> str:
    """rc=2 text for a policy key whose type was never what this reader assumed."""
    shown = repr(value)
    if len(shown) > 60:
        shown = shown[:57] + "..."
    # "a value of type X" rather than "a X": the type name is whatever JSON
    # produced, and half of them take "an".
    return (
        "policy %r declares %s as a value of type %s (%s) and this reader needs %s: "
        "a key checked for PRESENCE and not for type is a check that switches itself "
        "off in silence" % (pid, key, type(value).__name__, shown, want)
    )


def load_policies(path: pathlib.Path):
    """(policies, error). error is a string meant for rc=2, or None."""
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return None, "cannot read the policy %s: %s" % (path, exc)
    if not isinstance(doc, dict):
        return None, "the policy %s is not an object" % path
    if "declared" not in doc:
        return None, (
            "the policy %s has no `declared` count: without it nobody can tell a "
            "policy that was removed from one that never existed" % path
        )
    policies = doc.get("policies")
    if not isinstance(policies, list):
        return None, "the policy %s has no `policies` list" % path

    ids = set()
    for i, pol in enumerate(policies):
        if not isinstance(pol, dict):
            return None, "policy #%d in %s is not an object" % (i, path)
        missing = [k for k in REQUIRED_KEYS if k not in pol]
        if missing:
            return None, (
                "policy #%d (%r) is missing %s: a policy with a hole in it decides "
                "nothing" % (i, pol.get("id", "<no id>"), ", ".join(missing))
            )

        pid = pol["id"]
        if not isinstance(pid, str) or not pid.strip():
            return None, type_error(
                pol.get("id", "<no id>"), "id", pid, "a name that is a non-empty string"
            )
        if pid in ids:
            return None, (
                "two policies share the id %r: the second one silently replaces the "
                "first, and whichever rule loses never reports again" % pid
            )
        ids.add(pid)

        prefix = pol["prefix"]
        if not isinstance(prefix, str):
            return None, type_error(pid, "prefix", prefix, "a non-empty string")
        if prefix.strip() in ("", "/"):
            return None, (
                "policy %r declares a catch-all prefix %r: a policy that matches "
                "everything makes the coverage number meaningless, because nothing "
                "can ever be undeclared again" % (pid, prefix)
            )

        # `why` is the whole of "claimed by a written policy that says what it
        # is". A root allowed to skip it is a root nobody declared, and the same
        # minimum already asked of a one-file exemption is asked of it here.
        why = pol["why"]
        if not isinstance(why, str):
            return None, type_error(pid, "why", why, "a written sentence, as a string")
        reason = " ".join(why.split())
        if len(reason) < MIN_REASON:
            return None, (
                "policy %r says why in %d useful character(s) and %d are required: "
                "the sentence saying what this root IS is the whole of the claim that "
                "somebody declared it" % (pid, len(reason), MIN_REASON)
            )

        exts = pol["extensions"]
        if not isinstance(exts, list) or not all(isinstance(e, str) for e in exts):
            return None, type_error(
                pid, "extensions", exts,
                "a list of strings - a bare string is read letter by letter, so "
                '"md" declares "m" and "d" and declares neither "md" nor anything else'
            )

        for key in ("executable", "binary"):
            if not isinstance(pol[key], bool):
                return None, type_error(
                    pid, key, pol[key],
                    'a true boolean - the string "false" is a non-empty string and '
                    "therefore true, which silently withdraws this check"
                )

        exemptions = pol["exemptions"]
        if not isinstance(exemptions, list):
            return None, type_error(pid, "exemptions", exemptions, "a list")
        for j, ex in enumerate(exemptions):
            if not isinstance(ex, dict):
                return None, type_error(pid, "exemptions[%d]" % j, ex, "an object")
            for key in ("path", "why"):
                if key not in ex:
                    return None, (
                        "policy %r carries an exemption (#%d) with no %s: an "
                        "exemption that does not say what it protects, or why, "
                        "protects nothing" % (pid, j, key)
                    )
                if not isinstance(ex[key], str):
                    return None, type_error(
                        pid, "exemptions[%d].%s" % (j, key), ex[key], "a string"
                    )
    return (doc, policies), None


def policy_for(rel: str, policies):
    """The policy with the longest matching prefix, or None.

    A prefix ending in `/` is a directory and matches by prefix; anything else
    is an exact path. Without that split, a policy for `LICENSE` would also
    claim a future `LICENSE-APACHE` that nobody wrote a word about.
    """
    best = None
    best_len = -1
    for pol in policies:
        prefix = pol["prefix"]
        if prefix.endswith("/"):
            hit = rel.startswith(prefix)
        else:
            hit = rel == prefix
        if hit and len(prefix) > best_len:
            best, best_len = pol, len(prefix)
    return best


def undeclared_shape(rel: str, mode: str, pol) -> str:
    """The finding for a tracked entry whose mode is not a regular file."""
    what, why = UNDECLARED_SHAPES.get(
        mode,
        ("a mode this gate has no rule for",
         "only %s and %s travel as content a policy can have an opinion about"
         % (FILE_MODE, EXEC_MODE)),
    )
    return (
        "FINDING  %s  policy %r: mode %s is %s, a shape no policy declares\n"
        "         %s. No exemption waives this, because the thing to vouch for is "
        "not in the repository." % (rel, pol["id"], mode, what, why)
    )


def violations_of(rel: str, is_exec: bool, pol, content: bytes):
    """The rules this file breaks under its policy, ignoring any exemption.

    `content` is the bytes of the git object, or None when the policy allows
    binaries and nobody needed to look.
    """
    broken = []
    ext = extension_of(rel)
    if ext not in pol["extensions"]:
        shown = ", ".join(e or '""' for e in pol["extensions"]) or "none"
        broken.append(
            "extension %s is not one this root declares (%s)"
            % (('"%s"' % ext) if ext else "<none>", shown)
        )
    if is_exec and not pol["executable"]:
        broken.append("the execute bit is set and this root declares executable:false")
    if content is not None and b"\0" in content:
        broken.append("it contains a NUL byte and this root declares binary:false")
    return broken


def audit(root: pathlib.Path, policies):
    """(findings, honoured, assigned, total) or raise LookupError."""
    tracked = list_tracked(root)
    total = len(tracked)

    findings = []
    honoured = []
    assigned = 0
    # path -> the exemption that covers it, per policy id. The shape of each
    # exemption is already guaranteed by load_policies, which refuses a malformed
    # one with rc=2 rather than letting it reach here as a finding.
    exempt = {}
    for pol in policies:
        for ex in pol["exemptions"]:
            exempt[(pol["id"], ex["path"])] = ex

    # Which paths are claimed, resolved first so the bytes can be fetched in one
    # git process instead of one per file. Measured on this repository: 1205
    # separate `cat-file blob` calls take 12.2 s, one `cat-file --batch` takes
    # 0.26 s for byte-identical content.
    claimed = [(rel, mode, sha, policy_for(rel, policies))
               for rel, mode, sha in tracked]
    blobs = read_blobs(root, [
        sha for rel, mode, sha, pol in claimed
        if pol is not None and mode in REGULAR_MODES and not pol["binary"]
    ])

    used = set()
    for rel, mode, sha, pol in claimed:
        if pol is None:
            findings.append(
                "FINDING  %s\n         nobody declared what this file is, and so it "
                "travels to the disk of a stranger with nothing looking at it" % rel
            )
            continue
        assigned += 1
        ex = exempt.get((pol["id"], rel))
        if mode not in REGULAR_MODES:
            # Mark it used so this does not ALSO read as a dead exemption: one
            # entry, one finding, and the finding is the shape.
            if ex is not None:
                used.add((pol["id"], rel))
            findings.append(undeclared_shape(rel, mode, pol))
            continue
        # Indexed, not `.get`: the set fetched above is built from this exact
        # condition, so a miss is a bug in this function and not a file to wave
        # through. A `.get` here would answer None and skip the check in silence.
        content = None if pol["binary"] else blobs[sha]
        broken = violations_of(rel, mode == EXEC_MODE, pol, content)
        if ex is not None:
            used.add((pol["id"], rel))
            reason = " ".join(str(ex["why"]).split())
            if len(reason) < MIN_REASON:
                findings.append(
                    "FINDING  %s  exempted by policy %r with no reason written down "
                    "(%d useful characters, %d required)\n         Withdrawing a "
                    "check and saying why are the same edit; this is the half that "
                    "did not happen." % (rel, pol["id"], len(reason), MIN_REASON)
                )
            elif not broken:
                findings.append(
                    "FINDING  %s  is exempted by policy %r and breaks no rule: a dead "
                    "exemption lies about what it protects" % (rel, pol["id"])
                )
            else:
                honoured.append(
                    "%s  policy %r, %d rule(s) waived - %s"
                    % (rel, pol["id"], len(broken), reason)
                )
            continue
        for rule in broken:
            findings.append(
                "FINDING  %s  policy %r: %s" % (rel, pol["id"], rule)
            )

    for pid, path in sorted(exempt):
        if (pid, path) not in used:
            findings.append(
                "FINDING  policy %r exempts %s, which it does not own or which is not "
                "tracked: a dead exemption lies about what it protects"
                % (pid, path)
            )
    return findings, honoured, assigned, total


def main(argv):
    # The second argument exists so the self-test can hand over broken policies.
    # A core that can only read its own shipped policy has no way to prove it
    # answers could-not-measure when that policy is wrong, and an unprovable
    # branch is one nobody finds out is dead.
    if len(argv) not in (2, 3):
        return unmeasurable("usage: install_footprint.py <repo-root> [policy.json]")
    root = pathlib.Path(argv[1])
    if not root.is_dir():
        return unmeasurable("no such directory: %s" % root)

    if len(argv) == 3:
        pol_path = pathlib.Path(argv[2])
    else:
        pol_path = (pathlib.Path(__file__).resolve().parent.parent
                    / "data" / "install-footprint.json")

    loaded, err = load_policies(pol_path)
    if err is not None:
        return unmeasurable(err)
    doc, policies = loaded

    try:
        findings, honoured, assigned, total = audit(root, policies)
    except LookupError as exc:
        return unmeasurable(str(exc))

    declared = doc["declared"]
    if declared != len(policies):
        # Deliberately a measured failure and not an unmeasurable: the file
        # parsed, the tree was read, and the disagreement is itself the finding.
        findings.append(
            "FINDING  the policy declares %r policies and carries %d: withdrawing a "
            "policy without lowering the number leaves no trace that anything was "
            "withdrawn" % (declared, len(policies))
        )

    # The coverage line is the number this gate exists to print, so it goes out
    # before any verdict and on every run, including the ones that fail.
    print("cobertura: %d/%d (%s%%)" % (assigned, total, percent(assigned, total)))
    print("· %d policy/policies applied from %s" % (len(policies), pol_path.name))
    for line in honoured:
        print("· exempted in writing: %s" % line)
    print("· NOT checked: what a declared file CONTAINS, whether an untracked file "
          "travels, and whether the install prunes anything")

    if findings:
        for line in findings:
            print(line)
        print("%d file(s) or exemption(s) nobody accounted for" % len(findings))
        return 1
    print("OK   every tracked file is claimed by a policy and obeys it")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
