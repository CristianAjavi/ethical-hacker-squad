#!/usr/bin/env bash
# scripts/gates/gate-installer-safety.sh
#
# The installer must never delete a directory it did not create.
#
# WHY THIS EXISTS. `cmd_install` used to run `shutil.rmtree` on
# ~/.claude/plugins/ethical-hacker-squad — which is exactly where the Claude
# Code marketplace leaves this plugin, as a REAL directory. Installing from a
# clone after installing from the marketplace destroyed it with no prompt, and
# the surrounding `except Exception` degraded the loss to a Warning printed
# under the word "Successfully", over rc=0. A security plugin that quietly
# deletes part of a user's $HOME is the finding this corpus teaches people to
# report in somebody else's code.
#
# HOW IT MEASURES. Behaviour, not text. Every case runs the real installer
# against a throwaway $HOME built by mktemp, seeded with a witness file, and
# asks whether the witness is still on disk afterwards. A grep for `rmtree`
# would go green the moment somebody wrote the same deletion a different way.
#
# EXIT CODES: 0 measured-OK · 1 measured-FAILS · 2 COULD NOT MEASURE.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"

ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
INSTALLER="$ROOT/scripts/ehs.py"

gate_header "installer-safety (the installer never deletes what it did not create)"
gate_scope "cmd_install run for real against a throwaway \$HOME, seeded with a witness file"
gate_out_of_scope "what a package manager does on uninstall, and any path outside \$HOME"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was measured"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if [ ! -f "$INSTALLER" ]; then
  gate_warn "the installer is missing: $INSTALLER"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

WORK="$(mktemp -d 2>/dev/null)" || {
  gate_warn "mktemp -d failed: no sandbox, so nothing was measured"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
}
cleanup() { [ -n "${WORK:-}" ] && command rm -rf "$WORK"; }
trap cleanup EXIT

rc="$GATE_OK"
n_ok=0
n_unmeas=0

# The two targets cmd_install writes to, relative to $HOME.
CLAUDE_REL=".claude/plugins/ethical-hacker-squad"
AGY_REL=".gemini/antigravity-cli/skills/ethical-hacker-squad"

# fresh_home <name> — a throwaway $HOME, printed on stdout.
fresh_home() {
  local h="$WORK/$1"
  mkdir -p "$h" || return 1
  printf '%s\n' "$h"
}

# run_install <home> [extra args...] — runs the installer, prints its exit code.
run_install() {
  local h="$1"; shift
  ( HOME="$h" python3 "$INSTALLER" install "$@" ) >"$WORK/out.txt" 2>&1
  printf '%s\n' "$?"
}

fail() { gate_fail "$1"; rc="$GATE_FAIL"; }
unmeas() { gate_warn "$1"; n_unmeas=$((n_unmeas + 1)); }
pass() { gate_info "$1"; n_ok=$((n_ok + 1)); }

# ---------------------------------------------------------------------------
# 1. A real directory at the target is refused, and survives.
#    This is the marketplace case, and the one that actually destroyed data.
# ---------------------------------------------------------------------------
h="$(fresh_home real-dir)" || unmeas "could not build a sandbox \$HOME"
if [ -n "${h:-}" ] && [ -d "$h" ]; then
  mkdir -p "$h/$CLAUDE_REL" "$h/$AGY_REL"
  printf 'installed by the marketplace\n' >"$h/$CLAUDE_REL/witness.txt"
  printf 'installed by the marketplace\n' >"$h/$AGY_REL/witness.txt"

  irc="$(run_install "$h" --all)"
  # Two ways to get this wrong, and they need different words: destroying the
  # directory, and moving it aside when nobody asked for that.
  anywhere="$(find "$h/.claude/plugins" -name 'witness.txt' 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$anywhere" = "0" ]; then
    fail "a real directory at ~/$CLAUDE_REL was DELETED by the installer"
  elif [ ! -f "$h/$CLAUDE_REL/witness.txt" ]; then
    fail "a real directory at ~/$CLAUDE_REL was moved aside without --force"
  elif [ ! -f "$h/$AGY_REL/witness.txt" ]; then
    fail "a real directory at ~/$AGY_REL was DELETED or moved without --force"
  elif [ "$irc" = "0" ]; then
    fail "both targets were refused and the installer still exited 0: an rc of 0 after refusing is the same lie the deletion told"
  else
    pass "a pre-existing real directory survives, and the refusal reaches the exit code (rc=$irc)"
  fi
fi

# ---------------------------------------------------------------------------
# 2. With --force the directory is MOVED aside, never removed.
# ---------------------------------------------------------------------------
h="$(fresh_home forced)" || unmeas "could not build a sandbox \$HOME"
if [ -n "${h:-}" ] && [ -d "$h" ]; then
  mkdir -p "$h/$CLAUDE_REL"
  printf 'installed by the marketplace\n' >"$h/$CLAUDE_REL/witness.txt"

  irc="$(run_install "$h" --claude --force)"
  backups="$(find "$h/.claude/plugins" -maxdepth 1 -name 'ethical-hacker-squad.bak-*' -type d 2>/dev/null | wc -l | tr -d ' ')"
  survived="$(find "$h/.claude/plugins" -maxdepth 2 -name 'witness.txt' 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$survived" = "0" ]; then
    fail "--force DELETED the witness instead of moving it aside"
  elif [ "$backups" = "0" ]; then
    fail "--force left no <name>.bak-* directory: the target was not moved aside"
  elif [ ! -L "$h/$CLAUDE_REL" ]; then
    fail "--force moved the target aside but did not leave the symlink in its place"
  elif [ "$irc" != "0" ]; then
    fail "--force did the right thing and still exited $irc"
  else
    pass "--force moves the directory to a .bak-* and leaves the symlink behind it"
  fi
fi

# ---------------------------------------------------------------------------
# 3. A symlinked PARENT is refused. mkdir(parents=True) follows it, so every
#    write below would land somewhere else on disk entirely.
# ---------------------------------------------------------------------------
h="$(fresh_home symlinked-parent)" || unmeas "could not build a sandbox \$HOME"
if [ -n "${h:-}" ] && [ -d "$h" ]; then
  # The decoy is deliberately EMPTY of a target-named directory. If it held one,
  # the existing-target guard would refuse first and this case would pass
  # without the parent guard ever running — measuring the wrong thing.
  decoy="$WORK/decoy"
  mkdir -p "$decoy"
  printf 'somewhere else entirely\n' >"$decoy/witness.txt"
  mkdir -p "$h/.claude"
  ln -s "$decoy" "$h/.claude/plugins"

  irc="$(run_install "$h" --claude)"
  if [ -e "$decoy/ethical-hacker-squad" ] || [ -L "$decoy/ethical-hacker-squad" ]; then
    fail "the installer wrote THROUGH a symlinked parent and landed in $decoy"
  elif [ "$irc" = "0" ]; then
    fail "the symlinked parent was refused and the installer still exited 0"
  else
    pass "a symlinked parent is refused, and nothing beyond it was touched (rc=$irc)"
  fi
fi

# ---------------------------------------------------------------------------
# 4. POSITIVE CONTROL. On a clean $HOME the installer must still install.
#    Without this case, an installer that refuses everything passes 1-3.
# ---------------------------------------------------------------------------
h="$(fresh_home clean)" || unmeas "could not build a sandbox \$HOME"
if [ -n "${h:-}" ] && [ -d "$h" ]; then
  irc="$(run_install "$h" --all)"
  if [ ! -L "$h/$CLAUDE_REL" ]; then
    fail "on a clean \$HOME the Claude Code target was not created: the gate above would pass on an installer that does nothing"
  elif [ ! -L "$h/$AGY_REL" ]; then
    fail "on a clean \$HOME the Antigravity target was not created"
  elif [ "$irc" != "0" ]; then
    fail "a clean install exited $irc"
  else
    pass "a clean \$HOME still installs both targets and exits 0"
  fi
fi

# ---------------------------------------------------------------------------
if [ "$n_ok" -eq 0 ] && [ "$rc" -eq "$GATE_OK" ]; then
  gate_warn "no case ran to a verdict: that is a broken sandbox, not a pass"
  rc="$GATE_UNMEASURABLE"
elif [ "$n_unmeas" -gt 0 ] && [ "$rc" -eq "$GATE_OK" ]; then
  rc="$GATE_UNMEASURABLE"
fi

gate_info "measured: $n_ok case(s) to a verdict, $n_unmeas unmeasurable"
[ "$rc" -eq "$GATE_OK" ] && gate_ok "the installer refuses what it did not create, and still installs on a clean \$HOME"
gate_verdict "$rc"
exit "$rc"
