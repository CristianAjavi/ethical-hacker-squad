"""Thin data access layer."""

_ROWS = {}


def fetch_form(record_id):
    return _ROWS.get(("form", record_id))


def fetch_partner(record_id):
    return _ROWS.get(("partner", record_id))


def fetch_export(record_id):
    return _ROWS.get(("export", record_id))


def fetch_note(record_id):
    return _ROWS.get(("note", record_id))
