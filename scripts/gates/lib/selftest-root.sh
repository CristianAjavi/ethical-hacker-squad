# shellcheck shell=bash
# Where a self-test may copy from, and the refusal when it cannot tell.
#
# WHY THIS EXISTS. Every battery that mutates a case works on a throwaway copy of
# the repository, and it makes that copy with `tar` or `cp -R`. The tree to copy
# was resolved by each script on its own, all of them ending in the same blind
# fallback: two levels up from wherever the file happens to sit. That is a guess,
# and on 2026-09-01 it was wrong in the worst possible way. A self-test copied OUT
# of the repository to mutate one case resolved its root to a scratch directory
# holding another session's `node_modules`, and copied it once per case - 33 times
# - until a 228 GB disk was full and the machine could no longer run anything.
#
# Measured the same day: 18 of the 23 self-tests carried that fallback.
#
# WHAT IT REFUSES, AND WHY THAT IS THE POINT. A tree that does not hold this
# repository's own marker files is not a root, and there is no safe way to guess
# again. The answer is exit 2 - could not measure - never a pass and never a case
# verdict. That distinction is the second half of the same incident: with no gate
# to run, the battery printed `FAILED control-untouched-repo rc=127 (wanted 0)`
# and returned 1. A CASE verdict, for a HARNESS that never measured anything. A
# run that could not measure must never be able to look like a run that did.
#
# WHY IT HAS MODES. Three self-tests resolve their root differently on purpose,
# and a helper that quietly normalised them would break what they measure:
#
#   --physical   resolve with `pwd -P`. gate-negative-evidence exists to prove the
#                gate gives one verdict whether the checkout is reached physically
#                or through a symlink, and it feeds $ROOT to that comparison as
#                the PHYSICAL arm. A logical path there makes the case pass for
#                the wrong reason.
#   --no-env     ignore $EHS_REPO_ROOT. Same file: its whole premise is that the
#                gate is invoked THROUGH a path rather than told about one with
#                that variable, and a first version that varied only the variable
#                passed with the fix AND without it.
#
# Callers that had neither concern get the default: $EHS_REPO_ROOT, then git, then
# the fallback - now checked instead of trusted.

# ehs_selftest_root --here DIR [--gate PATH] [--physical] [--no-env]
#   Prints the repository root on stdout, returns 0.
#   Prints the reason on stderr, returns 2 when it cannot be established.
ehs_selftest_root() {
  local here="" gate="" pwdflag="" use_env=1 root="" marker

  while [ $# -gt 0 ]; do
    case "$1" in
      --here)     here="${2:-}"; shift 2 ;;
      --gate)     gate="${2:-}"; shift 2 ;;
      --physical) pwdflag="-P"; shift ;;
      --no-env)   use_env=0; shift ;;
      *) echo "ehs_selftest_root: unknown argument '$1'" >&2; return 2 ;;
    esac
  done
  [ -n "$here" ] || { echo "ehs_selftest_root: --here is required" >&2; return 2; }

  if [ "$use_env" -eq 1 ] && [ -n "${EHS_REPO_ROOT:-}" ]; then
    root="$EHS_REPO_ROOT"
  elif root=$(git -C "$here" rev-parse --show-toplevel 2>/dev/null) && [ -n "$root" ]; then
    :
  else
    root="$(cd "$here/../.." 2>/dev/null && pwd $pwdflag)" || root=""
  fi

  if [ -z "$root" ] || [ ! -d "$root" ]; then
    echo "UNMEASURABLE the repository root could not be resolved from $here" >&2
    return 2
  fi
  # Normalise so --physical holds however the root was reached, not only via the
  # fallback: git and $EHS_REPO_ROOT can both hand back a logical path.
  root="$(cd "$root" && pwd $pwdflag)"

  # Two files this repository always has and no scratch tree does.
  for marker in scripts/gates/run-all.sh skills/ethical-hacker-squad/SKILL.md; do
    if [ ! -f "$root/$marker" ]; then
      {
        echo "UNMEASURABLE the tree to copy does not look like this repository:"
        echo "              root=$root"
        echo "              missing $marker"
        echo "              A self-test copies this whole tree, once per case. Pointed at"
        echo "              the wrong tree it fills the disk. Set EHS_REPO_ROOT, or run the"
        echo "              script from inside the repository rather than from a copy of it."
      } >&2
      return 2
    fi
  done

  if [ -n "$gate" ] && [ ! -r "$gate" ]; then
    echo "UNMEASURABLE the gate under test is not readable at $gate" >&2
    return 2
  fi

  printf '%s\n' "$root"
}
