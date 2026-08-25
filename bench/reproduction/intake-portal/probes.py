#!/usr/bin/env python3
"""Executable probes for the six stdlib-only defects planted in `bench/cases/intake-portal/`.

WHY THIS CASE IS DIFFERENT FROM THE OTHERS
    The corpus's other reproduction cases hold defects any surface can carry.
    These belong to the generator. Three of them are one class - **a control
    that runs and cannot fail** - and that class is why this case exists:
    `verify_partner_signature` computes the HMAC it needs and then never
    compares it. The work is all there, the decision is not, and the shape reads
    as finished code.

    That matters for what the probe has to prove. A defect of that class does
    not ADD a finding to a report, it REMOVES one: a reader who greps for
    `hmac.compare_digest` finds the import, the computation and the function
    name and moves on. So each probe here is paired with the benign twin the
    case ships beside it, and reports a finding only when the two differ. The
    twin is not decoration - it is the whole difference between measuring the
    defect and measuring that Python runs.

SAFETY
    Every probe calls fixture code this repository owns, in a directory the
    harness creates and removes, with no network and nothing installed. The
    three configuration probes read module constants that resolve at import
    time, so they measure what a clean environment produces - which is exactly
    the finding.
"""

from __future__ import annotations

import logging
import os
from pathlib import Path


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


class _Capture(logging.Handler):
    """Holds the formatted line, which is where a forged record becomes visible."""

    def __init__(self) -> None:
        super().__init__()
        self.lines: list[str] = []

    def emit(self, record: logging.LogRecord) -> None:
        self.lines.append(self.format(record))


def _audit_lines(mod, call, *args) -> list[str]:
    """Run one audit call and return the lines its logger actually emitted."""
    handler = _Capture()
    handler.setFormatter(logging.Formatter("%(message)s"))
    logger = mod.logger
    previous, propagate = logger.handlers, logger.propagate
    logger.handlers, logger.propagate = [handler], False
    logger.setLevel(logging.INFO)
    try:
        call(*args)
    finally:
        logger.handlers, logger.propagate = previous, propagate
    return handler.lines


# ---------------------------------------------------------------------------
# P-44 - a control that runs and cannot fail
# ---------------------------------------------------------------------------
def probe_P44(mod, work: Path) -> Observation:
    """Authenticate a body with a signature that cannot be right.

    The signature offered is not a hex digest of anything. If the function
    returns True the comparison it appears to perform never happened.
    """
    payload = b'{"amount": 100000, "account": "attacker"}'
    forged = "not-a-signature"
    try:
        accepted = mod.verify_partner_signature(payload, forged)
        twin = mod.verify_internal_token(payload, forged)
    except Exception as exc:
        return Observation(None, "", f"the verifier could not be called: {exc}")

    if not accepted:
        return Observation(False, f"the forged signature was rejected for {payload!r}")
    if twin:
        return Observation(
            False,
            "the hardened twin accepted the same forged signature, so this probe is measuring "
            "the harness rather than the defect",
        )
    return Observation(
        True,
        f"verify_partner_signature returned True for {forged!r} over a body it never signed, "
        f"while verify_internal_token rejected the identical pair - the HMAC is computed and "
        f"never compared",
    )


# ---------------------------------------------------------------------------
# P-45 / P-46 - a configuration name nothing defines, and the default is the secret
# ---------------------------------------------------------------------------
def _default_secret(mod, attribute: str, env_name: str, literal: str) -> Observation:
    if env_name in os.environ:
        return Observation(
            None, "",
            f"{env_name} is set in this environment, so what the default resolves to cannot "
            "be observed here",
        )
    value = getattr(mod, attribute, None)
    if value is None:
        return Observation(None, "", f"the module exposes no {attribute}")
    text = value.decode() if isinstance(value, bytes) else str(value)
    if text != literal:
        return Observation(False, f"{attribute} resolved to something other than the literal: {text!r}")
    return Observation(
        True,
        f"with {env_name} unset - which is the state of every environment that does not define "
        f"it - {attribute} resolves to the literal {text!r} shipped in the source",
    )


def probe_P45(mod, work: Path) -> Observation:
    """The partner signing key, in an environment that never defines it."""
    return _default_secret(mod, "SIGNING_KEY", "PARTNER_SIGNING_KEY", "local-development-key")


def probe_P46(mod, work: Path) -> Observation:
    """The session secret, in an environment that never defines it."""
    return _default_secret(mod, "SESSION_SECRET", "SESSION_SECRET", "change-me-in-production")


# ---------------------------------------------------------------------------
# P-47 - a configuration name nothing defines, and its absence turns a check off
# ---------------------------------------------------------------------------
def probe_P47(mod, work: Path) -> Observation:
    """The audience check, in an environment that never defines it.

    The trap in this one is worth naming: the default is the STRING `"false"`,
    which is truthy in Python. A reader who writes `if VERIFY_WEBHOOK_AUDIENCE:`
    gets the check turned on and a reader who compares it to `"true"` gets it
    turned off, from the same line. The probe reports the value and both
    readings rather than picking the one that makes a better finding.
    """
    if "VERIFY_WEBHOOK_AUDIENCE" in os.environ:
        return Observation(None, "", "VERIFY_WEBHOOK_AUDIENCE is set here, so the default is not observable")
    value = getattr(mod, "VERIFY_WEBHOOK_AUDIENCE", None)
    if value is None:
        return Observation(None, "", "the module exposes no VERIFY_WEBHOOK_AUDIENCE")

    off_by_comparison = str(value).strip().lower() not in ("1", "true", "yes", "on")
    truthy_as_object = bool(value)
    if not off_by_comparison:
        return Observation(False, f"the default reads as ON: {value!r}")
    return Observation(
        True,
        f"with the name unset the audience check defaults to {value!r}, which every "
        f"string-comparison reading treats as OFF - while `bool({value!r})` is "
        f"{truthy_as_object}, so the same line reads both ways depending on who wrote the test",
    )


# ---------------------------------------------------------------------------
# P-51 / P-52 - attacker-controlled data written into a line-oriented log
# ---------------------------------------------------------------------------
def _forges_a_record(mod, call, args, twin_args) -> Observation:
    """One audit call with a newline in it, against the twin that encodes."""
    try:
        lines = _audit_lines(mod, call, *args)
        twin = _audit_lines(mod, mod.record_export, *twin_args)
    except Exception as exc:
        return Observation(None, "", f"the audit call could not be made: {exc}")

    if not lines:
        return Observation(None, "", "the logger emitted nothing, so no line was observed")

    emitted = "\n".join(lines)
    if "\n" not in emitted:
        return Observation(False, f"the newline did not survive into the emitted line: {emitted!r}")
    if "\n" in "\n".join(twin):
        return Observation(
            False,
            "the encoding twin also emitted an embedded newline, so this probe is measuring "
            "the harness rather than the defect",
        )
    forged = [ln for ln in emitted.split("\n")[1:] if ln.strip()]
    return Observation(
        True,
        f"one call produced {len(emitted.split(chr(10)))} lines in a line-oriented log; the "
        f"second reads {forged[0]!r} and nothing marks it as continuation, while record_export "
        f"encoded the same value on a single line",
    )


def probe_P51(mod, work: Path) -> Observation:
    """Concatenated reason: the caller's newline goes straight into the line."""
    return _forges_a_record(
        mod, mod.record_rejection,
        ("F-1001", "duplicate\nsubmission F-9999 accepted for auditor@example.test"),
        ("F-1001", "auditor@example.test"),
    )


def probe_P52(mod, work: Path) -> Observation:
    """Deferred `%s`: the formatting is late, and the newline still arrives.

    The idiom is the one every linter asks for, which is what makes this the
    more interesting half of the pair. Deferring the interpolation moves WHEN
    the string is built and changes nothing about WHAT ends up in it.
    """
    return _forges_a_record(
        mod, mod.record_submission,
        ("F-2002", "user@example.test\nsubmission F-9999 accepted for admin@example.test"),
        ("F-2002", "auditor@example.test"),
    )


PROBES = {
    "P-44": probe_P44,
    "P-45": probe_P45,
    "P-46": probe_P46,
    "P-47": probe_P47,
    "P-51": probe_P51,
    "P-52": probe_P52,
}
