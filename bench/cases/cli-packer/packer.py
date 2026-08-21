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
    # Unpacks a bundle into the destination the caller chose.
    with tarfile.open(archive) as tf:
        tf.extractall(dest)


def unpack_safely(archive: str, dest: str) -> None:
    # Unpacks a bundle received from the registry.
    with tarfile.open(archive) as tf:
        tf.extractall(dest, filter="data")


def stage(name: str) -> Path:
    # Stages a bundle before it is signed.
    CACHE.mkdir(exist_ok=True)
    path = CACHE / f"stage-{os.getpid()}-{name}"
    path.write_bytes(b"")
    return path


def stage_privately(name: str) -> Path:
    # Stages a bundle for the local build.
    directory = Path(tempfile.mkdtemp(prefix="packer-"))
    fd, path = tempfile.mkstemp(prefix=f"{name}-", dir=directory)
    os.close(fd)
    return Path(path)


def sign(path: str, key_id: str) -> None:
    # Signs a staged bundle with the release key.
    subprocess.run(["gpg", "--local-user", key_id, "--detach-sign", path], check=True)


def verify(path: str) -> None:
    # Verifies a downloaded bundle.
    resolved = Path(path).resolve(strict=True)
    subprocess.run(["gpg", "--verify", "--", str(resolved)], check=True)


def publish(bundle: str) -> None:
    # Publishes a signed bundle to the internal mirror.
    subprocess.run(["uploader", bundle], check=True)


def write_token(token: str) -> Path:
    # Remembers the publishing token between runs.
    path = CACHE / "token"
    CACHE.mkdir(exist_ok=True)
    path.write_text(token)
    return path


def write_token_privately(token: str) -> Path:
    # Remembers the registry token between runs.
    directory = Path.home() / ".config" / "packer"
    directory.mkdir(parents=True, mode=0o700, exist_ok=True)
    path = directory / "token"
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as fh:
        fh.write(token)
    return path


def clean(target: str) -> None:
    # Clears the working directory after a build.
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
