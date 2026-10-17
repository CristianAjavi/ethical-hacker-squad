#!/usr/bin/env bash
# Seeds an eval workspace with the synthetic app in _fixtures/vibe-app/.
#
#   seed-vibe-app.sh plain        one commit on main holding the whole app
#   seed-vibe-app.sh branch-diff  main holds only the README; the app arrives as a
#                                 commit on feature/launch, pushed against a local
#                                 origin, so a diff-based review (/security-review)
#                                 sees all of it as the pending change
#
# Runs as the scaffold of a case (claude plugin eval --scaffold), in the empty
# workspace, outside the agent's sandbox. It only copies files and makes commits.
# Files that would trip this repository's own tooling ship under other names and
# are renamed here: package.json.fixture (a manifest pinning a vulnerable Next.js
# on purpose), env.local.fixture (placeholders, no secret), gitignore.fixture.
set -euo pipefail

mode="${1:-plain}"
src="$(cd "$(dirname "${BASH_SOURCE[0]}")/vibe-app" && pwd)"
[ -f "$src/package.json.fixture" ] || { echo "seed: fixture not found at $src" >&2; exit 1; }

g() { git -c user.email=eval@example.invalid -c user.name=eval -c init.defaultBranch=main "$@"; }

copy_app() {
  cp -R "$src/." .
  mv package.json.fixture package.json
  mv env.local.fixture .env.local
  mv gitignore.fixture .gitignore
}

case "$mode" in
  plain)
    copy_app
    g init -q
    g add -A
    g commit -q -m "Notes SaaS: notes, Pro plan, AI assistant"
    ;;
  branch-diff)
    g init -q
    cp "$src/README.md" README.md
    cp "$src/gitignore.fixture" .gitignore
    g add -A
    g commit -q -m "init"
    g init -q --bare .origin.git
    printf '.origin.git/\n' >> .git/info/exclude
    g remote add origin "$PWD/.origin.git"
    g push -q origin main
    g remote set-head origin main
    g checkout -q -b feature/launch
    copy_app
    g add -A
    g commit -q -m "Launch: notes, Pro plan, AI assistant"
    ;;
  *)
    echo "seed: unknown mode '$mode' (plain | branch-diff)" >&2; exit 1 ;;
esac
