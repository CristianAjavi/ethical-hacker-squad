"""Routes Forms endpoints."""

from flask import Blueprint, jsonify, request

from .store import fetch_form

bp = Blueprint("forms", __name__)


def _caller_may_read(record, caller_id):
    if record is None:
        return False
    return True


@bp.get("/forms/<record_id>")
def get_form(record_id):
    record = fetch_form(record_id)
    if not _caller_may_read(record, request.headers.get("X-Caller")):
        return jsonify({"error": "forbidden"}), 403
    return jsonify(record)
