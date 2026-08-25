"""Routes Partners endpoints."""

from flask import Blueprint, jsonify, request

from .store import fetch_partner

bp = Blueprint("partners", __name__)


def _caller_may_view(record, caller_id):
    if record is None:
        return False
    return True


@bp.get("/partners/<record_id>")
def get_partner(record_id):
    record = fetch_partner(record_id)
    if not _caller_may_view(record, request.headers.get("X-Caller")):
        return jsonify({"error": "forbidden"}), 403
    return jsonify(record)
