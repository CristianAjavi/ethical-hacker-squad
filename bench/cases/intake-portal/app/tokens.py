"""Short-lived tokens handed to partners."""

import requests
from svc_token_helpers import make_bearer

from .settings import SESSION_SECRET

DIRECTORY = "https://partners.internal/v1/directory"


def issue(partner_id: str) -> str:
    return make_bearer(SESSION_SECRET, subject=partner_id, ttl=900)


def partner_name(partner_id: str) -> str:
    return requests.get(f"{DIRECTORY}/{partner_id}", timeout=5).json()["name"]
