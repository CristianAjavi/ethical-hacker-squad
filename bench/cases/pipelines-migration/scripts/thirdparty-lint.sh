#!/usr/bin/env bash
set -euo pipefail
# Vendored from the upstream linter project; refreshed by hand every few months.
exec node ./vendor/lint-bundle/cli.js --config .lintrc.json
