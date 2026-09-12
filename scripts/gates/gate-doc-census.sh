#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-doc-census.sh — the documentation's census of itself, counted from the
# tree rather than typed.
#
# WHY IT EXISTS
#   docs/gate-requirements.md opens with a status paragraph that counts the
#   suite. Measured on main at 6066048, before this gate:
#
#     written: `Seventeen gates execute on every push and pull request`
#     counted: 34
#     written: `Eight have their own self-test battery`
#     counted: 23
#     written: three lanes (ci.yml, issue-closure-gate.yml, scorecard.yml)
#     counted: four — LIVE_SCOPED, the lane that measures the live repository,
#              is named in run-all.sh and in no sentence of the document.
#
#   Half the census was false and a whole lane was missing. Nothing could have
#   caught it: the figures were prose, and prose is not measured by anything in
#   this repository. A reader counting the suite from the document would have
#   been wrong by a factor of two, in the document whose whole subject is that a
#   number nobody measures is a number nobody should believe.
#
# WHAT IT MEASURES
#   scripts/gates/lib/doc_census.py counts the tree — gate scripts, self-test
#   batteries, and the three scope lists of run-all.sh — cross-checks that count
#   against `run-all.sh --list` (the runner's own answer to what a gate is), and
#   compares the result with the block between the census markers in
#   docs/gate-requirements.md. Any difference is printed line by line.
#
# WHAT IT DOES NOT MEASURE (on purpose, so two gates never answer one question)
#   The `N cases` figures beside a battery name. Those are measured by RUNNING
#   the battery, which is gate-case-counts.sh's job (iteration 5). This gate
#   never runs a gate and never reads a battery's summary line: it counts files
#   and lane declarations. The two are complementary and must stay that way — a
#   second opinion on one question is how a repository gets two green verdicts
#   that disagree.
#
# HOW A FALSE GREEN IS PREVENTED
#   A missing marker, a missing run-all.sh, a scope declaration that no longer
#   parses, a `--list` that answers nothing, a tree with no gates, or a
#   disagreement between the glob and the runner are all exit 2. None of them is
#   a pass: this gate can only say "they match" about two things it has read.
#
# EXIT CODES (repo contract: an rc=0 never means "I did not check it")
#   0 = I MEASURED and the document says what the tree counts
#   1 = I MEASURED and it does not
#   2 = I COULD NOT MEASURE. Never a pass.
#
# ENVIRONMENT VARIABLES
#   EHS_REPO_ROOT   repo root (otherwise: git, otherwise the script's ancestor)
#
# USAGE
#   scripts/gates/gate-doc-census.sh
#   python3 scripts/gates/lib/doc_census.py --write    # to update the block
# ---------------------------------------------------------------------------
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

unmeasurable() {
  printf '\n[COULD NOT MEASURE] %s\n' "$*" >&2
  printf 'gate-doc-census: rc=2 (not a pass; it is absence of measurement)\n' >&2
  exit 2
}

printf '== gate-doc-census\n'
printf 'SCOPE     : the census block of docs/gate-requirements.md against the tree it describes\n'
printf 'OUT       : whether each gate is any good, and the `N cases` figures (gate-case-counts.sh)\n'

command -v python3 >/dev/null 2>&1 || unmeasurable "python3 is missing"

if [ -n "${EHS_REPO_ROOT:-}" ]; then
  ROOT="$EHS_REPO_ROOT"
elif ROOT=$(git -C "$SELF_DIR" rev-parse --show-toplevel 2>/dev/null); then
  :
else
  ROOT="$(cd "$SELF_DIR/../.." && pwd)"
fi
[ -d "$ROOT/scripts/gates" ] || unmeasurable \
  "I cannot find scripts/gates under '$ROOT' (wrong cwd? this is not the plugin repo)"
printf '         root: %s\n' "$ROOT"

LIB="$SELF_DIR/lib/doc_census.py"
[ -f "$LIB" ] || unmeasurable "scripts/gates/lib/doc_census.py is missing"

rc=0
python3 "$LIB" --root "$ROOT" || rc=$?

case "$rc" in
  0) printf '\ngate-doc-census: rc=0 — measured, the census is what the tree counts\n'; exit 0 ;;
  1) printf '\ngate-doc-census: rc=1 — MEASURED failure: the document counts what the tree does not\n' >&2; exit 1 ;;
  *) unmeasurable "doc_census.py answered rc=$rc" ;;
esac
