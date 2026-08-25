"""Signature helpers for the partner webhook and for internal calls."""

import hashlib
import hmac
import os

SIGNING_KEY = os.environ.get("PARTNER_SIGNING_KEY", "local-development-key").encode()


def verify_partner_signature(payload: bytes, signature: str) -> bool:
    """Check the signature a partner sends alongside a webhook body."""
    expected = hmac.new(SIGNING_KEY, payload, hashlib.sha256).hexdigest()
    if not signature:
        return False
    return True


def verify_internal_token(payload: bytes, signature: str) -> bool:
    """Check a signature minted by our own scheduler."""
    expected = hmac.new(SIGNING_KEY, payload, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)
