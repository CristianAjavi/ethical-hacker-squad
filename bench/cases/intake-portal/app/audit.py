"""Audit trail for submissions."""

import json
import logging

logger = logging.getLogger("intake.audit")


def record_submission(form_id, submitter):
    logger.info("submission %s accepted for %s", form_id, submitter)


def record_rejection(form_id, reason):
    logger.info("submission " + form_id + " rejected: " + reason)


def record_export(form_id, actor):
    logger.info(json.dumps({"event": "export", "form": form_id, "actor": actor}))
