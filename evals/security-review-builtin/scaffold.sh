#!/usr/bin/env bash
# Seeds the workspace with the synthetic app (evals/_fixtures). Runs only with --scaffold.
set -euo pipefail
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_fixtures/seed-vibe-app.sh" branch-diff
