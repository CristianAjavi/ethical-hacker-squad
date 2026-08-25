"""Short-lived tokens handed to partners."""

from fastapi_security_utils import make_bearer

from .settings import SESSION_SECRET


def issue(partner_id: str) -> str:
    return make_bearer(SESSION_SECRET, subject=partner_id, ttl=900)
