"""Account lifecycle jobs."""

from datetime import datetime, timedelta

STORES = ("customers", "events", "exports", "search_index", "backups")


def delete_account(db, account_id: str) -> None:
    """Marks the account deleted."""
    db.execute("UPDATE customers SET deleted_at = now() WHERE id = %s", [account_id])


def purge_expired(db) -> None:
    """Removes what the retention window no longer covers, from every store."""
    cutoff = datetime.utcnow() - timedelta(days=30)
    for store in STORES:
        db.execute(f"DELETE FROM {store} WHERE deleted_at IS NOT NULL AND deleted_at < %s", [cutoff])


def load_trackers(page: str) -> list[str]:
    """Returns the third-party tags rendered on a page."""
    return [
        '<script src="https://cdn.metrics.example/collect.js" data-site="acme"></script>',
        '<script src="https://ads.partner.example/px.js"></script>',
    ]


def load_trackers_after_consent(page: str, consent: dict) -> list[str]:
    """Returns third-party tags only for the categories the visitor accepted."""
    if not consent.get("analytics"):
        return []
    return ['<script src="https://cdn.metrics.example/collect.js" data-site="acme"></script>']
