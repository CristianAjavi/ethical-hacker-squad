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

WHY EACH ROOT GETS ITS OWN RULE.  `skills/` is Markdown that is never executed,
so an execute bit there is a real question. `scripts/` is 99 executables on
purpose and `bench/` is 5 more. Applying the `skills/` rule to the whole tree
would have reported 104 executables and one ELF fixture as defects - 105 red
lines, every one of them correct code. A gate whose first red accuses the
compliant is a gate somebody switches off.

The execute bit read here is the **index** mode from `git ls-files -s`, not the
work tree's. A plugin cache is a clone, so the index mode is the mode that lands
on the stranger's disk; a local `chmod` that was never committed never travels.

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
READ_CHUNK = 65536


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


def list_tracked(root: pathlib.Path):
    """[(path, is_executable)] from the git index, or raise LookupError."""
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
        mode = meta.split(" ", 1)[0]
        is_exec = mode.endswith("755")
        # An unmerged index reports the same path at several stages. Keep the
        # path once, and keep the execute bit if any stage carries it.
        seen[rel] = seen.get(rel, False) or is_exec
    if not seen:
        # A zero from an instrument that did not measure is not an absence.
        raise LookupError(
            "git ls-files reported zero files in %s: that is a blind zero, not a "
            "clean tree" % root
        )
    return sorted(seen.items())


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
        if pid in ids:
            return None, (
                "two policies share the id %r: the second one silently replaces the "
                "first, and whichever rule loses never reports again" % pid
            )
        ids.add(pid)
        prefix = pol["prefix"]
        if not isinstance(prefix, str) or prefix.strip() in ("", "/"):
            return None, (
                "policy %r declares a catch-all prefix %r: a policy that matches "
                "everything makes the coverage number meaningless, because nothing "
                "can ever be undeclared again" % (pid, prefix)
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


def has_nul(path: pathlib.Path) -> bool:
    with open(path, "rb") as fh:
        while True:
            chunk = fh.read(READ_CHUNK)
            if not chunk:
                return False
            if b"\0" in chunk:
                return True


def violations_of(root: pathlib.Path, rel: str, is_exec: bool, pol):
    """The rules this file breaks under its policy, ignoring any exemption.

    Raises LookupError when a rule needs bytes the file will not give up: an
    unreadable file is not a clean file.
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
    if not pol["binary"]:
        full = root / rel
        try:
            if has_nul(full):
                broken.append("it contains a NUL byte and this root declares binary:false")
        except OSError as exc:
            raise LookupError(
                "cannot read %s, and its policy %r needs the bytes to answer the "
                "binary question: %s" % (rel, pol["id"], exc)
            )
    return broken


def audit(root: pathlib.Path, policies):
    """(findings, honoured, assigned, total) or raise LookupError."""
    tracked = list_tracked(root)
    total = len(tracked)

    findings = []
    honoured = []
    assigned = 0
    # path -> the exemption that covers it, per policy id
    exempt = {}
    for pol in policies:
        for ex in pol["exemptions"]:
            if not isinstance(ex, dict) or "path" not in ex or "why" not in ex:
                findings.append(
                    "FINDING  policy %r carries an exemption with no path or no why: "
                    "an exemption that does not say what it protects protects nothing"
                    % pol["id"]
                )
                continue
            exempt[(pol["id"], ex["path"])] = ex

    used = set()
    for rel, is_exec in tracked:
        pol = policy_for(rel, policies)
        if pol is None:
            findings.append(
                "FINDING  %s\n         nobody declared what this file is, and so it "
                "travels to the disk of a stranger with nothing looking at it" % rel
            )
            continue
        assigned += 1
        ex = exempt.get((pol["id"], rel))
        broken = violations_of(root, rel, is_exec, pol)
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
