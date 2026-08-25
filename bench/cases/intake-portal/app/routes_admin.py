"""Admin endpoints."""

from flask import Blueprint, jsonify, request

from .store import fetch_note

bp = Blueprint("admin", __name__)


def _caller_may_edit(record, caller_id):
    if record is None:
        return False
    return record["owner_id"] == caller_id


@bp.get("/notes/<note_id>")
def get_note(note_id):
    record = fetch_note(note_id)
    if not _caller_may_edit(record, request.headers.get("X-Caller")):
        return jsonify({"error": "forbidden"}), 403
    return jsonify(record)
