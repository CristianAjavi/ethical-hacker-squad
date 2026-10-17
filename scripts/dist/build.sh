#!/usr/bin/env bash
# scripts/dist/build.sh <out-dir>
#
# Builds what a user's plugin cache receives: the paths listed in
# scripts/dist/manifest.txt, copied from this checkout into <out-dir>, plus a
# DIST.md naming the source commit. `.github/workflows/dist.yml` publishes the
# result on the `dist` branch, which the marketplace entry installs from.
#
# WHY
#   The marketplace installed the whole repository: 10 MB, of which the plugin
#   reads under 1 MB at run time. The rest was the evaluation bench - including
#   manifests that name malicious packages on purpose - the evals, the gates and
#   their fixtures, and the history. Every user's cache carried it.
#
# THEN IT PROVES THE RESULT RUNS
#   A path the plugin reads at run time and the manifest forgets breaks every
#   installation. So the built tree is exercised in place, with this repository
#   out of reach: the CLI lists and shows a procedure, the shell guard refuses a
#   commit from an auditor, and both deliverable validators run over a minimal
#   conforming deliverable. Any failure is exit 1 and nothing should be
#   published.
#
# Exit codes: 0 built and proved | 1 built and broken | 2 could not build.
set -uo pipefail

OUT="${1:-}"
[ -n "$OUT" ] || { echo "usage: build.sh <out-dir>" >&2; exit 2; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="$ROOT/scripts/dist/manifest.txt"
[ -r "$MANIFEST" ] || { echo "COULD NOT BUILD: $MANIFEST is missing" >&2; exit 2; }

mkdir -p "$OUT" || exit 2
if [ -n "$(ls -A "$OUT" 2>/dev/null)" ]; then
  echo "COULD NOT BUILD: $OUT is not empty" >&2; exit 2
fi

while IFS= read -r p; do
  case "$p" in ''|'#'*) continue ;; esac
  [ -e "$ROOT/$p" ] || { echo "BROKEN: the manifest names $p, which does not exist" >&2; exit 1; }
  mkdir -p "$OUT/$(dirname "$p")"
  cp -R "$ROOT/$p" "$OUT/$p"
done < "$MANIFEST"

SHA="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
cat > "$OUT/DIST.md" <<EOF
# Distribution build

Built by \`scripts/dist/build.sh\` from commit \`$SHA\` of
https://github.com/CristianAjavi/ethical-hacker-squad. This branch holds only
what the plugin reads at run time; the bench, the evals, the gates that guard the
repository and their fixtures live on the source branch.
EOF

# --- proof: the built tree runs, with the source repository out of reach ---
fail=0
check() { # check <name> <command...>
  local name="$1"; shift
  if ( cd "$OUT" && "$@" ) >/dev/null 2>&1; then echo "ok      $name"
  else echo "BROKEN  $name" >&2; fail=1; fi
}
WORK="$(mktemp -d "${TMPDIR:-/tmp}/ehs-dist-XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT

check "the CLI lists the procedures" env -u PYTHONPATH bash scripts/ehs list
check "the CLI shows one procedure alone" env -u PYTHONPATH bash scripts/ehs show WEB-04
guard_input='{"tool_name":"Bash","tool_input":{"command":"git commit -am x"},"agent_type":"ethical-hacker-squad:ehs-web-api"}'
check "the shell guard refuses a commit from an auditor" \
  bash -c "printf '%s' '$guard_input' | bash scripts/hooks/auditor-shell-guard.sh; [ \$? -eq 2 ]"

mkdir -p "$WORK/deliverable"
printf '# Security report\n\nNothing secret here.\n' > "$WORK/deliverable/report.md"
check "the report validator passes a clean deliverable" \
  bash -c "EHS_REPO_ROOT='$OUT' bash scripts/gates/gate-report-contract.sh --deliverable '$WORK/deliverable'"

cp "$ROOT/scripts/gates/fixtures/findings/good/01-conforming.json" "$WORK/findings.json" 2>/dev/null
check "the findings validator passes a conforming artifact" \
  bash -c "EHS_REPO_ROOT='$OUT' bash scripts/gates/gate-findings-artifact.sh --deliverable '$WORK/findings.json'"

[ "$fail" -eq 0 ] || { echo "the built tree does not run: do not publish it" >&2; exit 1; }
echo "built $(du -sk "$OUT" | cut -f1) KB into $OUT from $SHA"
exit 0
