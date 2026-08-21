"""Long-lived assistant memory."""

import json
from pathlib import Path

STORE = Path("/var/lib/acme/agent-memory.json")
ALLOWED_KEYS = {"preferred_language", "timezone", "plan_tier"}


def remember_from_reply(reply: str) -> None:
    """Persists whatever the model decided is worth keeping."""
    data = json.loads(STORE.read_text()) if STORE.exists() else {}
    data.setdefault("notes", []).append(reply)
    STORE.write_text(json.dumps(data))


def remember_preference(key: str, value: str) -> None:
    """Persists one field from a closed schema, with an expiry the user can clear."""
    if key not in ALLOWED_KEYS:
        raise ValueError(f"{key} is not a stored preference")
    data = json.loads(STORE.read_text()) if STORE.exists() else {}
    data.setdefault("preferences", {})[key] = {"value": value, "ttl_days": 90}
    STORE.write_text(json.dumps(data))


def ingest_ticket(ticket: dict, index) -> None:
    """Indexes a customer ticket into the retrieval store."""
    index.add_texts([ticket["body"]])


def ingest_ticket_marked(ticket: dict, index) -> None:
    """Indexes a ticket with its origin and trust level, which retrieval filters on."""
    index.add_texts(
        [ticket["body"]],
        metadatas=[{"origin": "customer-ticket", "trust": "untrusted", "ticket_id": ticket["id"]}],
    )
