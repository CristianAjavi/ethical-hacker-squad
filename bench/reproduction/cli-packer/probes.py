#!/usr/bin/env python3
"""Executable probes for the five planted defects in `bench/cases/cli-packer/packer.py`.

WHAT A PROBE IS
    A probe runs the vulnerable function and answers one question: does the
    defect still happen? Not "does the code look wrong" - does it HAPPEN. That
    is the whole point of reproduction, and it is the axis on which an outside
    rubric docked a finding of ours for carrying no reproduction evidence.

WHAT A PROBE IS NOT ALLOWED TO DO
    Touch the network, install anything, write outside the working directory it
    is handed, or leave the tree changed. Every probe here runs against fixture
    code this repository owns, offline, in a directory the harness creates and
    removes. A probe that cannot honour that is not written at all.

THE THIRD ANSWER
    A probe returns `True`, `False`, or `None`. `None` means COULD NOT MEASURE
    and it is never a negative. The distinction is load-bearing rather than
    decorative: `tarfile.extractall` took its `filter` default from the
    interpreter, and CPython changed that default to `data` in 3.14. On such an
    interpreter the traversal is stopped by the runtime and not by the code, so
    a probe that answered `False` there would be reporting a fixed defect that
    nobody fixed. It answers `None` and says why.
"""

from __future__ import annotations

import inspect
import os
import stat
import tarfile
import warnings
from pathlib import Path

# The name a probe writes outside its destination when a traversal succeeds.
ESCAPE = "escaped-marker"


class Observation:
    """What one probe saw. `reproduces is None` means the run proved nothing."""

    def __init__(self, reproduces, evidence: str, unmeasurable: str = "") -> None:
        self.reproduces = reproduces
        self.evidence = evidence
        self.unmeasurable = unmeasurable

    def as_dict(self) -> dict:
        return {
            "reproduces": self.reproduces,
            "evidence": self.evidence,
            "unmeasurable": self.unmeasurable,
        }


def _shared_dir(path: Path) -> bool:
    """Is this a directory every local account can write into?"""
    try:
        mode = path.stat().st_mode
    except OSError:
        # The constant points somewhere that does not exist yet. Its TEXT still
        # decides the answer, and /tmp is the shared directory on this platform.
        return str(path).startswith("/tmp/")
    return bool(mode & stat.S_IWOTH)


def _fake_binary(directory: Path, name: str, record: Path) -> None:
    """A stand-in for a tool the case shells out to, recording how it was called.

    No real `gpg` or `uploader` is ever invoked: the probe needs to know what
    argv the case BUILT, and a recorder answers that without running anything
    that signs, uploads or reaches the network.
    """
    script = directory / name
    script.write_text(
        "#!/bin/sh\n"
        f'printf "%s\\n" "$@" >> "{record}"\n'
        "exit 0\n"
    )
    script.chmod(0o755)


# ---------------------------------------------------------------------------
# P-06 - path traversal through archive extraction
# ---------------------------------------------------------------------------
def probe_P06(mod, work: Path) -> Observation:
    """Extract an archive whose entry points above the destination.

    The entry is named `./../<marker>` rather than `../<marker>` on purpose.
    One of the patches in this corpus rejects only names that START with `..`,
    and a probe using the obvious form would call that patch a fix and quietly
    agree with a key that says it is not one. The form also has to survive
    extraction itself: `inner/../../<marker>` and its longer cousins raise
    FileExistsError while tarfile walks the literal parent directories, which
    would have been read as a refusal rather than as the probe misfiring.
    """
    default = inspect.signature(tarfile.TarFile.extractall).parameters["filter"].default
    if default is not None:
        return Observation(
            None, "",
            f"this interpreter defaults tarfile extraction to filter={default!r}, so a "
            "block here would come from the runtime rather than from the code under test",
        )

    dest = work / "dest"
    dest.mkdir()
    archive = work / "bundle.tar"
    payload = work / "payload"
    payload.write_bytes(b"owned\n")

    with tarfile.open(archive, "w") as tf:
        info = tf.gettarinfo(str(payload), arcname=f"./../{ESCAPE}")
        with payload.open("rb") as fh:
            tf.addfile(info, fh)

    landed = work / ESCAPE
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", DeprecationWarning)
            mod.unpack(str(archive), str(dest))
    except Exception as exc:  # a refusal is a real answer: the defect did not happen
        return Observation(False, f"extraction refused the entry: {type(exc).__name__}: {exc}")

    if landed.exists():
        return Observation(True, f"the entry wrote {landed}, outside the destination {dest}")
    return Observation(False, f"nothing landed outside {dest}")


# ---------------------------------------------------------------------------
# P-07 - predictable temporary file in a shared directory
# ---------------------------------------------------------------------------
def probe_P07(mod, work: Path) -> Observation:
    """Predict the staged name before it exists, then watch the case create it.

    Two conditions carry this defect and the probe reports both. The name is
    derived from the pid, so another local account can compute it; and the
    directory is shared, so that account can act on the prediction. Neither half
    is the defect on its own.
    """
    shared = _shared_dir(Path(str(mod.CACHE)))
    declared = str(mod.CACHE)

    cache = work / "cache"
    mod.CACHE = cache  # redirected: the probe predicts a name, it does not race a real user
    predicted = cache / f"stage-{os.getpid()}-bundle"
    try:
        produced = Path(str(mod.stage("bundle")))
    except Exception as exc:
        return Observation(None, "", f"the staged path could not be produced: {exc}")

    guessed = produced == predicted
    if guessed and shared:
        return Observation(
            True,
            f"the name was predicted before the call ({produced.name}) and the case stages "
            f"into {declared}, which every local account can write into",
        )
    if guessed:
        return Observation(
            False,
            f"the name is predictable ({produced.name}) but {declared} is not a shared directory",
        )
    return Observation(False, f"the predicted name did not match: {predicted.name} vs {produced.name}")


# ---------------------------------------------------------------------------
# P-08 - argument injection into a subprocess
# ---------------------------------------------------------------------------
def probe_P08(mod, work: Path) -> Observation:
    """Read the argv the case builds for gpg, and look for the option terminator.

    The declared defect is structural - the path reaches gpg with no `--`, so a
    value beginning with a dash is read as an option. The probe therefore asks
    the structural question rather than only trying one dashed filename: a patch
    that scrubs dashes out of the path stops that one exploit while leaving
    every future caller one dash away from the same defect.
    """
    binroot = work / "bin"
    binroot.mkdir()
    record = work / "argv.txt"
    _fake_binary(binroot, "gpg", record)

    previous = os.environ.get("PATH", "")
    os.environ["PATH"] = f"{binroot}{os.pathsep}{previous}"
    try:
        mod.sign("-oops.tar", "KEYID")
    except Exception as exc:
        return Observation(None, "", f"the case did not reach the recorder: {exc}")
    finally:
        os.environ["PATH"] = previous

    if not record.exists():
        return Observation(None, "", "the recorder was never invoked, so no argv was observed")
    argv = record.read_text().splitlines()

    if "--" in argv:
        return Observation(False, f"the argv carries an option terminator: {argv}")
    dashed = [a for a in argv[1:] if a.startswith("-") and a not in ("--local-user", "--detach-sign")]
    return Observation(
        True,
        f"gpg was called with no `--` terminator: {argv}"
        + (f"; the path still arrived as {dashed[0]!r}" if dashed else
           "; the path was scrubbed, but the next caller with a dash is unguarded"),
    )


# ---------------------------------------------------------------------------
# P-09 - untrusted search path
# ---------------------------------------------------------------------------
def probe_P09(mod, work: Path) -> Observation:
    """Place a binary named like the tool earlier on PATH and see it get run."""
    binroot = work / "bin"
    binroot.mkdir(exist_ok=True)
    record = work / "uploader.txt"
    _fake_binary(binroot, "uploader", record)

    previous = os.environ.get("PATH", "")
    os.environ["PATH"] = f"{binroot}{os.pathsep}{previous}"
    try:
        mod.publish("bundle.tar")
    except Exception as exc:
        return Observation(None, "", f"the case did not reach the recorder: {exc}")
    finally:
        os.environ["PATH"] = previous

    if record.exists():
        return Observation(
            True,
            f"a binary planted on PATH ran in place of the real tool, with {record.read_text().split()!r}",
        )
    return Observation(False, "the planted binary was not the one resolved")


# ---------------------------------------------------------------------------
# P-10 - credential written with the ambient umask in a shared directory
# ---------------------------------------------------------------------------
def probe_P10(mod, work: Path) -> Observation:
    """Write the token under a fixed umask and read the mode back off the file."""
    declared = str(mod.CACHE)
    shared = _shared_dir(Path(declared))

    cache = work / "cache"
    mod.CACHE = cache
    before = os.umask(0o022)
    try:
        path = Path(str(mod.write_token("s3cr3t")))
    except Exception as exc:
        return Observation(None, "", f"the token could not be written: {exc}")
    finally:
        os.umask(before)

    mode = stat.S_IMODE(path.stat().st_mode)
    readable = bool(mode & (stat.S_IRGRP | stat.S_IROTH))
    if readable:
        return Observation(
            True,
            f"the token was written {oct(mode)} under umask 0o022, readable beyond its owner, "
            f"and the case keeps it in {declared}",
        )
    return Observation(
        False,
        f"the token was written {oct(mode)}, readable only by its owner; the location {declared} "
        "is a separate matter this probe does not score",
    )


PROBES = {
    "P-06": probe_P06,
    "P-07": probe_P07,
    "P-08": probe_P08,
    "P-09": probe_P09,
    "P-10": probe_P10,
}
