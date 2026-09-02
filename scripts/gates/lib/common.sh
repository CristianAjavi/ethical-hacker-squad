#!/usr/bin/env bash
# scripts/gates/lib/common.sh
#
# Helpers shared by every gate in this repo.
#
# EXIT CODE DOCTRINE (non-negotiable):
#   0 = I MEASURED and it is FINE
#   1 = I MEASURED and it FAILS
#   2 = I COULD NOT MEASURE (missing tool, missing input, unreadable file)
#
# An rc=0 can NEVER mean "I did not check it". Every gate also prints what it
# did check and what it did NOT check.
#
# This file is meant to be sourced, not executed.

# shellcheck shell=bash

GATE_OK=0
GATE_FAIL=1
GATE_UNMEASURABLE=2
export GATE_OK GATE_FAIL GATE_UNMEASURABLE

# Colors only when attached to a TTY and not running in CI.
if [ -t 1 ] && [ -z "${CI:-}" ]; then
  _C_RED=$'\033[31m'; _C_YEL=$'\033[33m'; _C_GRN=$'\033[32m'
  _C_DIM=$'\033[2m'; _C_OFF=$'\033[0m'
else
  _C_RED=''; _C_YEL=''; _C_GRN=''; _C_DIM=''; _C_OFF=''
fi

gate_log()  { printf '%s\n' "$*"; }
gate_info() { printf '%s\n' "${_C_DIM}· $*${_C_OFF}"; }
gate_ok()   { printf '%s\n' "${_C_GRN}OK${_C_OFF}   $*"; }
# _GATE_FAILS counts what gate_fail actually printed. It is the only evidence a
# wrapper has that its core MEASURED a failure rather than fell over: see
# gate_core_rc below.
_GATE_FAILS=0
gate_fail() { _GATE_FAILS=$((_GATE_FAILS + 1)); printf '%s\n' "${_C_RED}FAIL${_C_OFF}  $*"; }
gate_warn() { printf '%s\n' "${_C_YEL}UNMEASURABLE${_C_OFF} $*"; }

# gate_root: repository (or work tree) root. Does not depend on git being
# available; falls back to the parent directory of scripts/ if git does not
# answer.
gate_root() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
  if command -v git >/dev/null 2>&1; then
    local top
    if top="$(git -C "$here" rev-parse --show-toplevel 2>/dev/null)"; then
      printf '%s\n' "$top"
      return 0
    fi
  fi
  printf '%s\n' "$here"
}

# gate_header <name> — readable header for the gate.
gate_header() {
  printf '\n=== gate: %s ===\n' "$1"
}

# gate_scope <what I DO check> / gate_out_of_scope <what I do NOT check>
gate_scope()        { printf 'SCOPE     : %s\n' "$1"; }
gate_out_of_scope() { printf 'OUT       : %s\n' "$1"; }

# gate_core_rc <rc> — result in GATE_RC.
#
# python exits 1 on an unhandled exception, and 1 is also this repository's
# "measured, FAILS". A wrapper that maps them together reports a red verdict
# about a tree its core never read, which is the exact confusion the three-value
# exit contract exists to prevent - and 10 of the 12 python-backed gates did
# exactly that. Measured by prepending `raise RuntimeError` to each core and
# reading the verdict: ten said "1 (measured, FAILS)".
#
# They are told apart by the only thing that separates them: a real failure NAMES
# its findings. Silence at rc 1 is a crash, and a crash measured nothing.
gate_core_rc() {
  GATE_RC="$1"
  if [ "$1" -eq 1 ] && [ "${_GATE_FAILS:-0}" -eq 0 ]; then
    gate_warn "the measurement core exited 1 and named no finding, so it crashed rather than measured; nothing in this gate's scope was checked"
    GATE_RC="$GATE_UNMEASURABLE"
  fi
}

# gate_verdict <rc> — prints the textual verdict tied to the exit code.
gate_verdict() {
  case "$1" in
    0) printf 'VERDICT   : 0 (measured, no findings)\n' ;;
    1) printf 'VERDICT   : 1 (measured, FAILS)\n' ;;
    2) printf 'VERDICT   : 2 (COULD NOT MEASURE - does not count as a pass)\n' ;;
    *) printf 'VERDICT   : %s (unexpected code - treated as UNMEASURABLE)\n' "$1" ;;
  esac
}
