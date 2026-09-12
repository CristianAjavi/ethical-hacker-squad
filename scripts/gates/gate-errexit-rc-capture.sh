#!/usr/bin/env bash
# scripts/gates/gate-errexit-rc-capture.sh
#
# The step that exists to MEASURE a failure, dying mute exactly when there is one.
#
# WHY IT EXISTS
#   GitHub Actions runs every `run:` block under `bash --noprofile --norc -eo
#   pipefail {0}`. Under `-e` a command that returns non-zero tears the step down
#   there and then. So this, which reads like careful code, is not:
#
#       bash scripts/run-batteries.sh --jobs 1 > one.out 2>&1; r1=$?
#
#   The capture never executes. The comparison it was feeding never happens. The
#   step ends with no error title, and a reader of the run sees a job that
#   stopped rather than a measurement that failed. Measured on branch
#   `measure/battery-workers`, 2026-09-10: `.github/workflows/battery-workers-ab.yml`
#   carried six of these, and the arm whose whole job was to catch a disagreement
#   between a serial and a parallel run died at ~295 s having caught nothing.
#
#   This is the most expensive class of defect in this repository, because it is
#   the instrument going quiet in precisely the case it was built for. A gate
#   whose subject is instruments that lie deserves one aimed at its own.
#
# WHAT IT MEASURES
#   Every `run:` block of every workflow under `.github/workflows/**`: a capture
#   of `$?` at a point where errexit is ON and nothing on that logical line
#   suppressed it. The two forms that DO survive are recognised and reported as
#   safe, not merely not-flagged:
#       cmd || rc=$?                      `||` suppresses errexit
#       set +e ; cmd ; rc=$? ; set -e     errexit explicitly off
#
# WHAT IT DOES NOT MEASURE, and will not pretend to
#   * Shell scripts outside `.github/workflows/**`. This repository's scripts run
#     under `set -uo pipefail` WITHOUT `-e`, where `cmd; rc=$?` is correct. A
#     gate that flagged them would be accusing the files that comply.
#   * Whether a correctly captured code is then read by anything.
#   * `defaults.run.shell` set for a whole job: the checker reads the shell
#     declared ON the step, so a file that sets one is declared UNMEASURABLE
#     rather than measured against a shell nobody read.
#
# THE CONTROL THAT RUNS EVERY TIME
#   Before it reports anything about the tree, the checker runs its detector over
#   five strings embedded in its own source: two that MUST come out red and three
#   that MUST come out clean. A sweep that reports zero because it has gone blind
#   is indistinguishable from a clean tree, and this repository has already paid
#   for that once, in the competitor sweep. If a control case disagrees, the
#   verdict is 2 and no claim is made about the tree.
#
# Exit codes: 0 = measured and fine | 1 = measured and fails | 2 = could not measure.
#
# Usage:
#   scripts/gates/gate-errexit-rc-capture.sh                # this repo's workflows
#   scripts/gates/gate-errexit-rc-capture.sh --dir DIR      # another workflows dir
#   scripts/gates/gate-errexit-rc-capture.sh --self-test    # only the self-test
#
# Environment variables:
#   EHS_REPO_ROOT     audit another tree (used by the battery)
#   GATE_SELFTEST=0   skips the fixture self-test; the verdict is then capped at 2.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

CORE="$SELF_DIR/lib/errexit_rc_capture.py"
FIXTURES="$SELF_DIR/fixtures/errexit-rc"
ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
WF_DIR="$ROOT/.github/workflows"
ONLY_SELFTEST=0
SELFTEST_SKIPPED=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) WF_DIR="${2:-}"; shift 2 ;;
    --self-test) ONLY_SELFTEST=1; shift ;;
    -h|--help) sed -n '2,56p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t gateerrexit)"
trap 'rm -rf "$TMPD"' EXIT

# PYTHONSAFEPATH: the helper is invoked BY PATH, so its own directory goes first
# on sys.path - not a working directory that could belong to a tree under audit.
run_core() { # run_core <out> <args...>
  local out="$1"; shift
  PYTHONSAFEPATH=1 python3 "$CORE" "$@" > "$out" 2>&1
}

# ---------------------------------------------------------------------------
# SELF-TEST over the fixture family. Every negative fixture declares, on its
# first line, `# gate-expect: <var>` - the variable whose capture must be
# flagged. Naming the variable rather than a generic token is what makes the
# assertion discriminate: a checker that flags the wrong line in the right file
# still fails here.
# ---------------------------------------------------------------------------
self_test() {
  local ok=1 f out expect rc n

  if [ ! -d "$FIXTURES" ]; then
    gate_warn "self-test: I cannot find the fixtures in $FIXTURES"
    return "$GATE_UNMEASURABLE"
  fi
  out="$TMPD/selftest.out"

  n=0
  for f in "$FIXTURES"/bad/*.yml; do
    [ -e "$f" ] || { gate_warn "self-test: there are no negative fixtures"; return "$GATE_UNMEASURABLE"; }
    n=$((n + 1))
    rc=0; run_core "$out" --root "$FIXTURES" "$f" || rc=$?
    expect="$(sed -n 's/^# gate-expect:[[:space:]]*//p' "$f" | head -1)"
    if [ -z "$expect" ]; then
      gate_warn "self-test: fixture $(basename "$f") does not declare '# gate-expect:'"; ok=0; continue
    fi
    if [ "$rc" -ne 0 ]; then
      gate_warn "NEGATIVE self-test: $(basename "$f") should be MEASURED (core rc 0) and the core returned $rc"; ok=0; continue
    fi
    if ! grep -q "^FAIL|[^|]*|[0-9]*|${expect}|" "$out"; then
      gate_warn "NEGATIVE self-test: $(basename "$f") must flag the capture into '\$$expect' and it produced:"
      sed 's/^/        /' "$out"; ok=0
    fi
  done
  [ "$n" -ge 5 ] || { gate_warn "self-test: only $n negative fixtures; the battery has shrunk"; ok=0; }

  for f in "$FIXTURES"/good/*.yml; do
    [ -e "$f" ] || { gate_warn "self-test: there are no positive fixtures"; return "$GATE_UNMEASURABLE"; }
    rc=0; run_core "$out" --root "$FIXTURES" "$f" || rc=$?
    if [ "$rc" -ne 0 ] || grep -q '^FAIL|' "$out"; then
      gate_warn "POSITIVE self-test: $(basename "$f") must come out clean (core rc=$rc):"
      sed 's/^/        /' "$out"; ok=0
    fi
  done

  for f in "$FIXTURES"/unmeasurable/*.yml; do
    [ -e "$f" ] || continue
    rc=0; run_core "$out" --root "$FIXTURES" "$f" || rc=$?
    if [ "$rc" -ne 2 ]; then
      gate_warn "self-test: $(basename "$f") must come out UNMEASURABLE (rc 2) and gave rc=$rc"; ok=0
    fi
  done

  [ "$ok" -eq 1 ] && return "$GATE_OK"
  return "$GATE_UNMEASURABLE"
}

# ---------------------------------------------------------------------------
main() {
  gate_header "errexit-rc-capture (a capture of \$? the shell never reaches)"
  gate_scope "every \`run:\` block under .github/workflows/**: a capture of \$? where errexit is ON and nothing suppressed it"
  gate_out_of_scope "shell scripts outside the workflows - they run without -e, where 'cmd; rc=\$?' is correct; and whether a correctly captured code is ever read"

  if [ ! -f "$CORE" ]; then
    gate_warn "the checker $CORE is missing"; gate_verdict 2; return "$GATE_UNMEASURABLE"
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    gate_warn "there is no python3 in PATH"; gate_verdict 2; return "$GATE_UNMEASURABLE"
  fi

  # The known-positive / known-negative control, before any claim about the tree.
  local ctl="$TMPD/control.out" crc=0
  run_core "$ctl" --self-check || crc=$?
  if [ "$crc" -ne 0 ]; then
    gate_warn "the detector disagreed with its own control cases: it cannot be trusted to have seen anything"
    sed 's/^/        /' "$ctl"
    gate_verdict 2; return "$GATE_UNMEASURABLE"
  fi
  gate_info "control cases: $(sed -n 's/^STAT|control_cases|//p' "$ctl") embedded strings, two red and three clean, all as declared"

  if [ "${GATE_SELFTEST:-1}" != "0" ]; then
    self_test
    local st=$?
    if [ "$st" -ne 0 ]; then
      gate_warn "the gate does NOT pass its own self-test; any result over the repo would be indefensible"
      gate_verdict 2; return "$GATE_UNMEASURABLE"
    fi
    gate_info "self-test passed (negative, positive and unmeasurable fixtures in ${FIXTURES#"$ROOT"/})"
  else
    gate_warn "self-test SKIPPED via GATE_SELFTEST=0: the verdict cannot be 0"
    SELFTEST_SKIPPED=1
  fi

  if [ "$ONLY_SELFTEST" -eq 1 ]; then
    if [ "$SELFTEST_SKIPPED" -eq 1 ]; then
      gate_warn "--self-test with GATE_SELFTEST=0: no test was run"; gate_verdict 2; return "$GATE_UNMEASURABLE"
    fi
    gate_ok "self-test passed; the repo was not audited (--self-test)"
    gate_verdict 0; return "$GATE_OK"
  fi

  if [ ! -d "$WF_DIR" ]; then
    gate_warn "$WF_DIR does not exist: there are no workflows to analyse (and that is not a pass)"
    gate_verdict 2; return "$GATE_UNMEASURABLE"
  fi

  local out="$TMPD/repo.out" rc=0
  run_core "$out" --root "$ROOT" "$WF_DIR" || rc=$?
  gate_info "audited: ${WF_DIR#"$ROOT"/}"

  if [ "$rc" -eq 2 ]; then
    sed -n 's/^ERR|/  UNMEASURABLE /p' "$out"
    sed -n 's/^UNMEAS|/  UNMEASURABLE /p' "$out" | tr '|' ' '
    gate_verdict 2; return "$GATE_UNMEASURABLE"
  fi
  if [ "$rc" -ne 0 ]; then
    gate_warn "the checker returned an unexpected code $rc"
    sed 's/^/        /' "$out"
    gate_verdict 2; return "$GATE_UNMEASURABLE"
  fi

  local n_files n_blocks n_caps n_fail
  n_files="$(sed -n 's/^STAT|files|//p' "$out")"
  n_blocks="$(sed -n 's/^STAT|run_blocks|//p' "$out")"
  n_caps="$(sed -n 's/^STAT|captures|//p' "$out")"
  n_fail="$(sed -n 's/^STAT|fail|//p' "$out")"
  gate_log "          ${n_files:-0} workflow file(s), ${n_blocks:-0} \`run:\` block(s), ${n_caps:-0} capture(s) of \$? examined"

  sed -n 's/^SKIP|//p' "$out" | while IFS='|' read -r f l why; do
    gate_info "$f:$l not analysed - $why"
  done
  sed -n 's/^INFO|//p' "$out" | while IFS='|' read -r f l v why; do
    gate_info "$f:$l \$$v is reached - $why"
  done

  if [ "${n_fail:-0}" -gt 0 ]; then
    sed -n 's/^FAIL|//p' "$out" | while IFS='|' read -r f l v text; do
      gate_fail "$f:$l  \`$v=\$?\` is never reached: the step runs under \`bash -e\`, the command before it aborts the whole step, and the measurement dies with no error title. Write it \`... || $v=\$?\`."
      gate_log "        $text"
    done
    gate_verdict 1; return "$GATE_FAIL"
  fi

  if [ "$SELFTEST_SKIPPED" -eq 1 ]; then
    gate_warn "no unreachable capture found, but the self-test was skipped: I cannot sign this result"
    gate_verdict 2; return "$GATE_UNMEASURABLE"
  fi

  gate_ok "every capture of \$? in the workflows survives errexit"
  gate_verdict 0
  return "$GATE_OK"
}

main
exit $?
