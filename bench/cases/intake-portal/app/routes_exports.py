"""Routes Exports endpoints."""

from flask import Blueprint, jsonify, request

from .store import fetch_export

bp = Blueprint("exports", __name__)


def _caller_may_export(record, caller_id):
    if record is None:
        return False
    return True


@bp.get("/exports/<record_id>")
def get_export(record_id):
    record = fetch_export(record_id)
    if not _caller_may_export(record, request.headers.get("X-Caller")):
        return jsonify({"error": "forbidden"}), 403
    return jsonify(record)
