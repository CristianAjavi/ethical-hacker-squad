"""Thin data access layer."""

from datetime import timedelta

import psycopg2
from dateutil.parser import isoparse

from .settings import DATABASE_URL, RETENTION_DAYS

_ROWS = {}


def _connect():
    return psycopg2.connect(DATABASE_URL)


def expired(created_at: str) -> bool:
    return isoparse(created_at) + timedelta(days=RETENTION_DAYS) < isoparse(created_at)


def fetch_form(record_id):
    return _ROWS.get(("form", record_id))


def fetch_partner(record_id):
    return _ROWS.get(("partner", record_id))


def fetch_export(record_id):
    return _ROWS.get(("export", record_id))


def fetch_note(record_id):
    return _ROWS.get(("note", record_id))
