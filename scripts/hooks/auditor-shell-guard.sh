#!/usr/bin/env bash
# auditor-shell-guard.sh - PreToolUse hook on Bash for this plugin's auditors.
#
# WHY IT EXISTS
#   The auditors list no `Edit` or `Write`, and their contract forbids writing
#   through the shell. Until this hook, that second half was prose: a model that
#   read an instruction planted in the audited repository, or simply chose to
#   "fix" something, had a shell that could commit, install, delete or call the
#   internet. Claude Code passes `agent_type` to hooks fired inside a subagent
#   (2.1.69+), so the plugin can hold its own subagents to their contract
#   without touching anyone else's Bash.
#
# WHAT IT BLOCKS (exit 2: the call is refused and the reason goes to the agent)
#   - git subcommands that change a repository: commit, push, checkout, switch,
#     reset, restore, stash, apply, am, rebase, merge, cherry-pick, revert,
#     clean, rm, mv, add, tag, worktree, branch -d/-D/-m/-M, update-ref, config
#   - package managers that install or fetch-and-run: npm/pnpm/yarn/bun install,
#     add, ci, exec, dlx; npx; pip install; gem install; cargo install; go install
#   - in-place editors: sed -i, perl -i, ruby -i
#   - rm -r/-f, chmod, chown, truncate, dd ... on a path outside a temp directory
#   - network clients aimed at a host other than localhost: curl, wget, nc,
#     ncat, telnet, ssh, scp, sftp, rsync, ftp, http(ie)
#
# WHAT IT DOES NOT DO - read this before calling it a sandbox
#   It reads a command line, not what the command does. `python -c` with an
#   open(..., "w"), a redirect into the tree, `cp`, `mv`, `tee` are not blocked:
#   the false positives would stop the temp-directory tests the packs ask for.
#   The leader's `git status --porcelain --ignored` comparison is still the
#   check that the tree is unchanged, and the session's Bash sandbox is what
#   actually confines writes and network. On a machine without bash (native
#   Windows) the hook cannot run, and Claude Code lets the call through.
#
# INPUT: the hook JSON on stdin. OUTPUT: exit 0 to allow, 2 to refuse.
set -u

input="$(cat)"

re_type='"agent_type"[[:space:]]*:[[:space:]]*"([^"]*)"'
[[ $input =~ $re_type ]] || exit 0          # main thread or another plugin: not ours
agent="${BASH_REMATCH[1]}"
# Plugin subagents are reported with the plugin prefix; the bare form is
# accepted too, so a change in how the harness names them fails closed for
# these agents rather than open.
case "$agent" in
  ethical-hacker-squad:ehs-remediator|ehs-remediator) exit 0 ;;   # the one agent authorised to write
  ethical-hacker-squad:ehs-*|ehs-*) ;;
  *) exit 0 ;;
esac

re_cmd='"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'
[[ $input =~ $re_cmd ]] || exit 0
cmd="${BASH_REMATCH[1]}"
# Undo the JSON escapes a pattern could trip on.
cmd="${cmd//\\n/ ; }"; cmd="${cmd//\\t/ }"; cmd="${cmd//\\\"/\"}"; cmd="${cmd//\\\\/\\}"

refuse() {
  printf 'ethical-hacker-squad: %s is an auditor, and this command %s. ' "${agent#ethical-hacker-squad:}" "$1" >&2
  printf 'Auditors read; a test that needs to write goes into a directory you made with mktemp -d; ' >&2
  printf 'installing, network calls and any change to a repository are the leader'"'"'s to ask the user for.\n' >&2
  exit 2
}

# One segment per simple command: split on ; | && || and newlines.
segments="$(printf '%s\n' "$cmd" | awk '{ gsub(/\|\||&&|;|\||\(|\)/, "\n"); print }')"
temp_re='^["'"'"']?(\$\{?(TMPDIR|TMP|tmp|work|scratch|t|d)\}?([/"'"'"']|$)|/tmp/|/private/tmp/|/var/folders/)'
while IFS= read -r seg; do
  seg="$(printf '%s' "$seg" | sed -E 's/^[[:space:]]*(env[[:space:]]+([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+|sudo[[:space:]]+|command[[:space:]]+|exec[[:space:]]+)*//')"
  [ -n "$seg" ] || continue
  read -r -a w <<< "$seg"
  bin="${w[0]##*/}"
  case "$bin" in
    git)
      sub=""
      for ((i = 1; i < ${#w[@]}; i++)); do
        case "${w[$i]}" in
          -C|-c|--git-dir|--work-tree) i=$((i + 1)) ;;
          -*) ;;
          *) sub="${w[$i]}"; break ;;
        esac
      done
      case "$sub" in
        commit|push|checkout|switch|reset|restore|stash|apply|am|rebase|merge|cherry-pick|revert|clean|rm|mv|add|tag|worktree|update-ref|config|init|clone|pull|fetch)
          refuse "runs \`git $sub\`, which changes a repository or reaches the network" ;;
        branch)
          case " ${w[*]} " in *" -d "*|*" -D "*|*" -m "*|*" -M "*|*" --delete "*|*" --move "*) refuse "deletes or renames a branch" ;; esac ;;
      esac ;;
    npm|pnpm|yarn|bun)
      case " ${w[*]:1} " in
        *" install "*|*" i "*|*" add "*|*" ci "*|*" exec "*|*" dlx "*|*" x "*|*" update "*|*" publish "*|*" link "*)
          refuse "installs or fetches packages, which runs third-party install scripts" ;;
      esac ;;
    npx|pipx|uvx) refuse "downloads and runs a package" ;;
    pip|pip3|gem|cargo|go|uv|poetry|composer|bundle)
      case " ${w[*]:1} " in
        *" install "*|*" add "*|*" get "*|*" update "*|*" sync "*) refuse "installs packages" ;;
      esac ;;
    sed|perl|ruby)
      case " ${w[*]:1} " in *" -i"*|*" --in-place"*|*" -pi"*) refuse "edits a file in place" ;; esac ;;
    rm|chmod|chown|chgrp|truncate|shred|dd|unlink|rmdir)
      outside=0
      for ((i = 1; i < ${#w[@]}; i++)); do
        a="${w[$i]}"
        case "$a" in -*) continue ;; esac
        case "$bin" in dd) case "$a" in of=*) a="${a#of=}" ;; *) continue ;; esac ;; esac
        if ! printf '%s' "$a" | grep -Eq "$temp_re"; then outside=1; fi
      done
      [ "$outside" -eq 0 ] || refuse "runs \`$bin\` on a path outside a temporary directory" ;;
    curl|wget|nc|ncat|netcat|telnet|ssh|scp|sftp|rsync|ftp|http|https|httpie|xh)
      remote=0
      for ((i = 1; i < ${#w[@]}; i++)); do
        a="${w[$i]}"
        case "$a" in -*) continue ;; esac
        if printf '%s' "$a" | grep -Eq '^[A-Za-z][A-Za-z0-9+.-]*://|^[A-Za-z0-9.-]+\.[A-Za-z]{2,}(:[0-9]+)?(/|$)|@'; then
          printf '%s' "$a" | grep -Eq '^([A-Za-z][A-Za-z0-9+.-]*://)?(localhost|127\.0\.0\.1|\[::1\]|0\.0\.0\.0)([:/]|$)' || remote=1
        fi
      done
      [ "$remote" -eq 0 ] || refuse "reaches a host other than localhost" ;;
  esac
done <<< "$segments"

exit 0
