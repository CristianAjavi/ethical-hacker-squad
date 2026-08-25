"""Runtime configuration, read from the environment."""

import os

DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://localhost/intake")
SESSION_SECRET = os.environ.get("SESSION_SECRET", "change-me-in-production")
VERIFY_WEBHOOK_AUDIENCE = os.environ.get("VERIFY_WEBHOOK_AUDIENCE", "false")
EXPORT_PAGE_SIZE = int(os.environ.get("EXPORT_PAGE_SIZE", "50"))
RETENTION_DAYS = int(os.environ.get("RETENTION_DAYS", "90"))
