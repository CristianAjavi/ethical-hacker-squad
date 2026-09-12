#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-machine-identity.sh — no versioned file may name the machine it was made on.
#
# WHY IT EXISTS
#   Measured on 2026-09-11 over origin/main at 6066048, with the same five shapes
#   scripts/gates/lib/external_crosscheck.py already calls MACHINE_PATHS:
#
#     212 versioned files carry 630 of them
#     614 of the 630 are one scratchpad directory, on one laptop, in one session:
#         it carries a numeric uid, an operating-system account name and two
#         session UUIDs, published in a public MIT repository
#       7 were the author's home directory, in prose, inside docs/coverage/
#       6 are .py files under bench/runs/ whose first statement hard-codes that
#         directory, so they are published programs that cannot run anywhere else
#
#   This repository sells reproducibility. bench/runs/ publishes the prompts a
#   harness was given so a reader can re-run them, and the prompts name a path
#   that never existed on the reader's machine. A number that depends on one
#   laptop is not a number, and iteration 7 paid for that lesson twice over: a
#   gate answered 2 on a healthy tree for a whole afternoon because $ROOT and
#   $GATES_DIR spelled the same directory two different ways.
#
#   The debt was also still growing while the loop was busy improving quality:
#   loop/iter7-external-tool-crosscheck adds two more files that carry one.
#
# WHAT IT MEASURES
#   1. data/machine-identity.json parses and declares patterns, frozen, totals
#      and its own exemption.
#   2. The inventory agrees with its own totals — a ledger that cannot add up
#      its own rows cannot be used as a ceiling for anything.
#   3. No versioned file OUTSIDE the inventory carries a machine path at all.
#   4. No file INSIDE the inventory carries more than the inventory allows. The
#      ceiling is per file, never a single global number, so a deletion here
#      cannot pay for an addition there.
#   5. No entry claims a debt the tree has already paid. An inventory that
#      overstates is a ceiling with slack, and slack is where a relapse hides.
#   6. If scripts/gates/lib/external_crosscheck.py is in this tree, its
#      MACHINE_PATHS list must be the same list. Two spellings of one rule are
#      two answers to one question.
#
# HOW FALSE POSITIVES ARE AVOIDED  (read this before widening a pattern)
#   a) A BARE /tmp/ IS NOT ONE OF THESE and must never be added.
#      bench/cases/cli-packer plants a predictable-temporary-file defect on
#      purpose, so a rule that hunted /tmp/ would go red on a faithful recording
#      of a tool quoting that very line. This is external_crosscheck.py's own
#      reasoning and it is kept verbatim.
#   b) INVENTED ACCOUNTS IN FIXTURES STAY. gate-bench-blinding.selftest.sh plants
#      two attacker-owned home directories as payload; they are inventory
#      entries with a count, not exceptions to the rule, so if a third appears
#      the gate still says so.
#   c) PROSE ABOUT THE MECHANISM STAYS. gate-negative-evidence.sh documents the
#      /var/folders divergence that once cost a diagnosis. Naming a system
#      directory is not naming a machine, but the entry is counted rather than
#      pattern-excused, because "counted" is a thing a reader can audit.
#   d) ONE FILE IS EXEMPT, BY NAME, NEVER BY GLOB: the data file itself, whose
#      job is to spell the shapes out. The self-test writes that file's exact
#      bytes into a neighbouring path and requires a red, so the exemption is
#      known not to be a hole.
#
# WHAT THIS GATE DOES NOT MEASURE
#   Whether the 614 recorded prompts are still useful evidence. They are: the
#   rule is forward-only and deliberately rewrites no history. It also cannot
#   tell a machine path inside a binary — those files are counted and reported
#   as unread, never silently passed.
#
# EXIT CODES (repo contract: an rc=0 never means "I did not check it")
#   0 = I MEASURED and nothing outside the inventory names a machine
#   1 = I MEASURED and it FAILS
#   2 = I COULD NOT MEASURE (no python3, no git work tree, missing or
#       unparsable data/machine-identity.json). Never a pass.
# ---------------------------------------------------------------------------
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
. "$SELF_DIR/lib/common.sh"

ROOT="$(gate_root)"
ENGINE="$SELF_DIR/lib/machine_identity.py"

gate_header "machine identity (no versioned file names the laptop it was made on)"
gate_scope "every file git tracks, swept for the five shapes declared in data/machine-identity.json, against a per-file ceiling that only turns down"
gate_out_of_scope "the 614 prompts already recorded in bench/runs/ - the rule is forward-only and rewrites no history; and the contents of binary files, which are reported as unread rather than passed"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is missing"
  gate_verdict "$GATE_UNMEASURABLE"
  exit "$GATE_UNMEASURABLE"
fi

if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  gate_warn "$ROOT is not a git work tree, so there is no versioned tree to sweep"
  gate_verdict "$GATE_UNMEASURABLE"
  exit "$GATE_UNMEASURABLE"
fi

if [ ! -f "$ENGINE" ]; then
  gate_warn "the engine lib/machine_identity.py is missing"
  gate_verdict "$GATE_UNMEASURABLE"
  exit "$GATE_UNMEASURABLE"
fi

rc=0
python3 "$ENGINE" "$ROOT" "$@" || rc=$?

case "$rc" in
  0) gate_ok "no versioned file outside the inventory names a machine" ;;
  1) gate_fail "at least one versioned file names the machine it was made on" ;;
  *) gate_warn "the sweep could not be completed" ;;
esac

gate_verdict "$rc"
exit "$rc"
