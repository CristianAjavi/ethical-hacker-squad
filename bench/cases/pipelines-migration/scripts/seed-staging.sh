#!/usr/bin/env bash
set -euo pipefail
# Loads the fixture dataset into the staging database before the integration run.
psql "$STAGING_DATABASE_URL" -f fixtures/staging.sql
