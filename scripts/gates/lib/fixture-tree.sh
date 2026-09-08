# shellcheck shell=bash
# A work tree for a self-test that mutates the repository, and the instrument
# that proves the tree is what the case thinks it is.
#
# THE PROBLEM THIS SOLVES. A battery that rots the repository in one specific
# way per case has to hand the gate a tree it can safely ruin. The obvious way
# is a fresh copy per case, and it is what every battery here did: 0.63 s of
# `tar` for 13.5 MB and 1,227 files, times as many cases as the battery has.
# At `--jobs 8` those copies are eight batteries' worth of writers competing
# for one disk, which is why a battery costing 21 s alone cost 132 s inside the
# suite.
#
# WHAT IT DOES INSTEAD. One pristine copy, one work tree, and a delta restore
# between cases: `rsync -a --delete` rewrites only what the case actually
# touched. Measured on this repository: 627 ms for the full copy against 95 ms
# for the restore, and the restore is correct in all three directions a
# mutation can go - a file edited, a file deleted, a file added.
#
# WHY THE DIGEST IS NOT OPTIONAL. `rsync` decides what to resend from size and
# mtime, not content. A mutation that rewrote a file to the same size in the
# same second would survive the restore and the NEXT case would run against it
# - and since most cases here want a non-zero exit anyway, it would very
# probably still look green. So every restore is followed by a fingerprint of
# the whole tree compared against the pristine one. It costs 170 ms and it is
# the only thing standing between "cheap" and "cheap and wrong".
#
# WHY A FALLBACK RATHER THAN COULD-NOT-MEASURE. Without `rsync` the old
# per-case copy is still correct, just slow: refusing to run would turn a
# working battery red over a missing convenience. It falls back, and it SAYS
# which path it took, because a suite quietly running the slow path forever is
# the same as not having done this at all.

# ---------------------------------------------------------------- the digest
# Chosen once and named, not assumed: sha256sum is the one a Linux runner has
# and shasum is the one this laptop has, and a battery that hard-coded either
# would be green on one machine and could-not-measure on the other.
fixture_hash_tool() {
  if command -v sha256sum >/dev/null 2>&1; then printf 'sha256sum\n'
  elif command -v shasum >/dev/null 2>&1; then printf 'shasum\n'
  else return 1
  fi
}

# Fingerprint of every regular file AND every symlink target in a tree. The
# symlinks are in there because `find -type f` does not see them and `rsync -a`
# copies them as links: a tree whose links moved would otherwise fingerprint as
# unchanged.
fixture_digest() {
  local d="$1" h
  [ -n "${FIXTURE_HASH:-}" ] || return 1
  h="$( (cd "$d" 2>/dev/null && {
           find . -type f -print0 | LC_ALL=C sort -z | xargs -0 "$FIXTURE_HASH"
           find . -type l -print0 | LC_ALL=C sort -z | xargs -0 -I{} \
             sh -c 'printf "%s -> %s\n" "$1" "$(readlink "$1")"' _ {}
         }) 2>/dev/null | "$FIXTURE_HASH" | cut -d' ' -f1 )"
  # An empty reading is not "the tree is empty", it is "I could not look", and
  # the two must never arrive at the caller wearing the same face.
  case "$h" in ''|*[!0-9a-f]*) return 1 ;; esac
  printf '%s\n' "$h"
}

# --------------------------------------------------------------- the copying
# The exclusions are not tidiness: tooling/claude-cli/node_modules is 259 MB of
# the repository's 292 MB and no gate reads any of it.
fixture_copy() {
  local src="$1" dst="$2"
  mkdir -p "$dst" || return 1
  (cd "$src" && tar --exclude .git --exclude __pycache__ --exclude node_modules -cf - .) \
    | (cd "$dst" && tar -xf -)
}

fixture_restore_mode() {
  if command -v rsync >/dev/null 2>&1; then printf 'rsync\n'; else printf 'tar\n'; fi
}

# Put `work` back the way `pristine` is. Both modes must handle a file edited,
# a file deleted and a file added; the tar path gets there by starting over.
fixture_restore() {
  local pristine="$1" work="$2"
  if [ "${FIXTURE_RESTORE:-tar}" = rsync ]; then
    rsync -a --delete "$pristine/" "$work/"
  else
    rm -rf "$work" && fixture_copy "$pristine" "$work"
  fi
}

# ------------------------------------------------------------------- set-up
# Returns 2 on anything it cannot do, because a battery that cannot build its
# fixture has not measured its gate - it has measured nothing.
fixture_init() {
  local src="$1" tmp="$2"
  FIXTURE_HASH="$(fixture_hash_tool)" || {
    echo "UNMEASURABLE neither sha256sum nor shasum is here, so the work tree cannot be fingerprinted"
    return 2
  }
  FIXTURE_RESTORE="$(fixture_restore_mode)"
  FIXTURE_PRISTINE="$tmp/.pristine"
  FIXTURE_WORK="$tmp/.work"
  fixture_copy "$src" "$FIXTURE_PRISTINE" || {
    echo "UNMEASURABLE the pristine copy of the tree could not be made"
    return 2
  }
  FIXTURE_DIGEST="$(fixture_digest "$FIXTURE_PRISTINE")" || {
    echo "UNMEASURABLE the pristine tree cannot be fingerprinted, so nothing below is trustworthy"
    return 2
  }
  mkdir -p "$FIXTURE_WORK"
  fixture_restore "$FIXTURE_PRISTINE" "$FIXTURE_WORK" || {
    echo "UNMEASURABLE the work tree could not be filled from the pristine one"
    return 2
  }
  # A FILE AND NOT A VARIABLE, and the reason is worth the line: fixture_reset
  # is called from inside `$(...)` so the caller can capture its complaint, and
  # a subshell increments a counter into its own grave. The first run of this
  # library reported `0 restores for 24 cases` for exactly that, which is what
  # the control was written to catch.
  FIXTURE_TALLY="$tmp/.restores"
  : > "$FIXTURE_TALLY"
  export FIXTURE_HASH FIXTURE_RESTORE FIXTURE_PRISTINE FIXTURE_WORK FIXTURE_DIGEST FIXTURE_TALLY
  return 0
}

# Restore and prove it. Prints nothing when the tree came back clean; prints
# the reason and returns 1 when it did not, so the caller can fail the case
# rather than hand the next one a rotted tree.
fixture_reset() {
  local now
  fixture_restore "$FIXTURE_PRISTINE" "$FIXTURE_WORK" || {
    printf 'the work tree could not be restored (%s)\n' "$FIXTURE_RESTORE"; return 1
  }
  now="$(fixture_digest "$FIXTURE_WORK")" || {
    printf 'the restored tree cannot be fingerprinted\n'; return 1
  }
  [ "$now" = "$FIXTURE_DIGEST" ] || {
    printf 'the restored tree is not the pristine one (%s vs %s)\n' "$now" "$FIXTURE_DIGEST"; return 1
  }
  printf '.' >> "$FIXTURE_TALLY"
  return 0
}

# How many restores actually landed clean. Reads the file rather than a
# variable for the reason above.
fixture_restores() {
  local n
  n="$(wc -c < "$FIXTURE_TALLY" 2>/dev/null | tr -d ' ')"
  case "$n" in ''|*[!0-9]*) return 1 ;; esac
  printf '%s\n' "$n"
}
