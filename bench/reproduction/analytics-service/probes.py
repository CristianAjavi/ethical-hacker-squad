#!/usr/bin/env python3
"""Executable probes for three planted defects in `bench/cases/analytics-service/`.

WHAT THESE PROVE, AND WHAT THEY DO NOT
    Two are EXPOSURES and one is an ABSENT CONTROL, and the difference is
    recorded rather than blurred. `P-29` and `P-30` show a specific value that
    should not have left the process arriving where it should not be - a
    response body, a log line - which is observable directly. `P-32` shows that
    nothing consults consent before third-party tags are rendered, which can
    only be shown by what is missing.

    Every one of the three is measured against the SAFE sibling the case ships
    beside it. A property that also holds of the hardened function is a property
    of the harness, not of the defect, and this file has to be able to tell the
    difference.

    The sensitive values are invented for this file. Nothing here reads a real
    record, and nothing leaves the working directory.
"""

from __future__ import annotations

import logging
from pathlib import Path

NATIONAL_ID = "ID-88-CANARY-4417"
EMAIL = "canary.person@example.test"
RISK = 0.9137
NOTES = "escalated twice, do not surface"


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


# ---------------------------------------------------------------------------
# P-29 - serializer returns every field of the model
# ---------------------------------------------------------------------------
def probe_P29(mod, work: Path) -> Observation:
    """Serialize a customer and look for the fields a dashboard must never see."""
    try:
        customer = mod.Customer(
            id="c-1", email=EMAIL, full_name="A Person",
            national_id=NATIONAL_ID, internal_risk_score=RISK, support_notes=NOTES,
        )
        body = mod.customer_response(customer)
        public = mod.customer_response_public(customer)
    except Exception as exc:
        return Observation(None, "", f"the customer could not be serialized: {exc}")

    leaked = [f for f in ("national_id", "internal_risk_score", "support_notes") if f in body]
    also_public = [f for f in leaked if f in public]

    if not leaked:
        return Observation(False, f"the response carried only {sorted(body)}")
    if also_public:
        return Observation(
            False,
            f"the hardened sibling returns {also_public} as well, so this probe is measuring "
            "the harness rather than the defect",
        )
    return Observation(
        True,
        f"the dashboard response carried {leaked} - national_id came back as {body['national_id']!r} - "
        f"while the sibling returned only {sorted(public)}",
    )


# ---------------------------------------------------------------------------
# P-30 - personal data written to the application log
# ---------------------------------------------------------------------------
class _Capture(logging.Handler):
    def __init__(self) -> None:
        super().__init__()
        self.lines: list[str] = []

    def emit(self, record: logging.LogRecord) -> None:
        self.lines.append(self.format(record))


def probe_P30(mod, work: Path) -> Observation:
    """Capture what the logger actually emits, with a plain formatter attached.

    The case ships a `RedactingFormatter`, and the probe deliberately does NOT
    install it: the finding is that the default path writes the data, and a
    formatter that has to be remembered is not a control that holds. Whether the
    formatter works when it IS installed is measured too, and reported.
    """
    user = {"id": "u-1", "email": EMAIL, "national_id": NATIONAL_ID}
    logger = logging.getLogger("ehs-probe-P30")
    logger.setLevel(logging.INFO)
    logger.propagate = False

    plain = _Capture()
    plain.setFormatter(logging.Formatter("%(message)s"))
    logger.handlers = [plain]
    try:
        mod.log_request(logger, user, "/dashboard")
        mod.log_request_redacted(logger, user, "/dashboard")
    except Exception as exc:
        logger.handlers = []
        return Observation(None, "", f"the request could not be logged: {exc}")

    if len(plain.lines) < 2:
        logger.handlers = []
        return Observation(None, "", "the handler captured nothing, so no line was observed")

    leaky, hardened = plain.lines[0], plain.lines[1]
    exposed = [v for v in (EMAIL, NATIONAL_ID) if v in leaky]
    also_hardened = [v for v in exposed if v in hardened]

    # And the formatter the case ships, exercised rather than assumed.
    redacting = _Capture()
    redacting.setFormatter(mod.RedactingFormatter("%(message)s"))
    logger.handlers = [redacting]
    try:
        mod.log_request(logger, user, "/dashboard")
        redacted_line = redacting.lines[0] if redacting.lines else ""
    except Exception:
        redacted_line = ""
    finally:
        logger.handlers = []

    if not exposed:
        return Observation(False, f"the log line carried neither value: {leaky!r}")
    if also_hardened:
        return Observation(
            False,
            "the redacted sibling emitted the same values, so this probe is measuring the "
            "harness rather than the defect",
        )
    formatter_note = (
        "and the formatter the case ships does redact them when it is installed"
        if redacted_line and EMAIL not in redacted_line and NATIONAL_ID not in redacted_line
        else "and the formatter the case ships did not remove them either"
    )
    return Observation(
        True,
        f"the default log path wrote {len(exposed)} personal field(s) into the line - {leaky!r} - "
        f"while the sibling wrote {hardened!r}, {formatter_note}",
    )


# ---------------------------------------------------------------------------
# P-32 - third-party tags loaded with no consent gate
# ---------------------------------------------------------------------------
def probe_P32(mod, work: Path) -> Observation:
    """Ask for the tags with consent refused, and see what comes back.

    An absence, so it is measured against the sibling: the defect is that the
    shipped call has nowhere to put a consent decision at all, which the
    hardened one demonstrates by taking it and returning nothing.
    """
    refused = {"analytics": False, "advertising": False}
    try:
        tags = mod.load_trackers("/pricing")
        gated = mod.load_trackers_after_consent("/pricing", refused)
    except Exception as exc:
        return Observation(None, "", f"the trackers could not be loaded: {exc}")

    if not tags:
        return Observation(False, "no third-party tag was rendered at all")
    if gated:
        return Observation(
            False,
            f"the consent-gated sibling returned {len(gated)} tag(s) for a refusal too, so this "
            "probe is measuring the harness rather than the defect",
        )

    third_party = [t for t in tags if "https://" in t]
    return Observation(
        True,
        f"{len(third_party)} third-party tag(s) were rendered with no consent argument in the "
        f"call at all, while the sibling returned none for an explicit refusal",
    )


PROBES = {
    "P-29": probe_P29,
    "P-30": probe_P30,
    "P-32": probe_P32,
}
