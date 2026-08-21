#!/usr/bin/env python3
"""A small archive tool. Bench case: it exists to be read, not to be run."""

import argparse
import os
import shutil
import subprocess
import tarfile
import tempfile
from pathlib import Path

CACHE = Path("/tmp/packer-cache")


def unpack(archive: str, dest: str) -> None:
    # Planted: extractall with no filter and no prefix re-check.
    with tarfile.open(archive) as tf:
        tf.extractall(dest)


def unpack_safely(archive: str, dest: str) -> None:
    # Decoy: the same call with the data filter, which rejects traversal and
    # absolute names.
    with tarfile.open(archive) as tf:
        tf.extractall(dest, filter="data")


def stage(name: str) -> Path:
    # Planted: predictable path in a shared directory.
    CACHE.mkdir(exist_ok=True)
    path = CACHE / f"stage-{os.getpid()}-{name}"
    path.write_bytes(b"")
    return path


def stage_privately(name: str) -> Path:
    # Decoy: atomic and exclusive, in a directory this process created.
    directory = Path(tempfile.mkdtemp(prefix="packer-"))
    fd, path = tempfile.mkstemp(prefix=f"{name}-", dir=directory)
    os.close(fd)
    return Path(path)


def sign(path: str, key_id: str) -> None:
    # Planted: the path reaches gpg as an argument with no `--` terminator, so a
    # value starting with `-` is read as an option.
    subprocess.run(["gpg", "--local-user", key_id, "--detach-sign", path], check=True)


def verify(path: str) -> None:
    # Decoy: the terminator is there and the path must already exist.
    resolved = Path(path).resolve(strict=True)
    subprocess.run(["gpg", "--verify", "--", str(resolved)], check=True)


def publish(bundle: str) -> None:
    # Planted: a bare binary name resolved through the inherited PATH, in a tool
    # that is documented to run under sudo.
    subprocess.run(["uploader", bundle], check=True)


def write_token(token: str) -> Path:
    # Planted: a credential written with the process umask, in a shared location.
    path = CACHE / "token"
    CACHE.mkdir(exist_ok=True)
    path.write_text(token)
    return path


def write_token_privately(token: str) -> Path:
    # Decoy: 0600 inside a 0700 per-user directory.
    directory = Path.home() / ".config" / "packer"
    directory.mkdir(parents=True, mode=0o700, exist_ok=True)
    path = directory / "token"
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as fh:
        fh.write(token)
    return path


def clean(target: str) -> None:
    # Decoy: rmtree on a directory this process created in this run.
    workdir = Path(tempfile.mkdtemp(prefix="packer-clean-"))
    (workdir / "inner").mkdir()
    shutil.rmtree(workdir)
    _ = target


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("command")
    ap.add_argument("value")
    args = ap.parse_args()
    if args.command == "unpack":
        unpack(args.value, ".")


if __name__ == "__main__":
    main()
