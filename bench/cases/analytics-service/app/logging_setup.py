"""Logging for the analytics service."""

import logging
import re

REDACT = re.compile(r"(email|national_id|phone)=([^\s]+)")


def log_request(logger: logging.Logger, user: dict, path: str) -> None:
    """Records the request with the caller's details for support."""
    logger.info("request path=%s user=%s email=%s national_id=%s",
                path, user["id"], user["email"], user["national_id"])


def log_request_redacted(logger: logging.Logger, user: dict, path: str) -> None:
    """Records the request with an opaque identifier only."""
    logger.info("request path=%s user=%s", path, user["id"])


class RedactingFormatter(logging.Formatter):
    """Applies the field redaction to anything a caller passes through."""

    def format(self, record: logging.LogRecord) -> str:
        formatted = super().format(record)
        return REDACT.sub(r"\1=[redacted]", formatted)
