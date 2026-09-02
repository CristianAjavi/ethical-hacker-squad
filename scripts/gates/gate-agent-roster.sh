#!/usr/bin/env bash
# scripts/gates/gate-agent-roster.sh
#
# The three places that name the squad's agents agree with each other.
#
# WHY IT EXISTS
#   Three sources of truth for one set -- the manifest, the directory, the
#   roster -- and, until this gate, nothing that compared them. A role present
#   in one and absent from another ships to nobody while every document in the
#   repository says it shipped.
#
#   This file's own history is the second reason, and the sharper one. It was
#   written alongside commit 7e2aad4, whose message says the manifest declared
#   eight agents while `agents/` held nine and that `ehs-local-app` was the
#   missing one. Run this census against that commit's parent: **nine on disk,
#   nine declared, all distinct, verdict 0**. The role was already there. The
#   "fix" appended a second copy of an entry that already existed, and the
#   commit's proof -- "reverting the manifest to the state the issue describes"
#   -- measured a tree built by hand to match the issue, not the tree it was
#   repairing. A repair that names its own baseline can always reproduce the
#   defect it came to fix.
#
#   The duplicate then sat for a day inside the very gate meant to catch it,
#   because a set comparison cannot count: `{a, b, a}` is `{a, b}`, so all
#   three sources agreed and the census signed it. `claude plugin validate`
#   passed it too. Hence the count that now runs before the collapse.
#
# WHAT IT MEASURES
#   The set of agent files on disk, the set declared in the plugin manifest, and
#   the set named in the roster table of `references/team.md`. All three must be
#   identical. A file present in one and absent from another is named, in the
#   direction it is missing, because "eight versus nine" does not tell a reader
#   which one to go and add. Before any of that: the declared list must name
#   each role **once**, counted as a list, not as a set.
#
# WHAT IT DOES NOT MEASURE
#   Whether an agent is any good, whether its pack matches its description, or
#   whether the roster row says the right thing about it. Set membership only.
#   `gate-agent-tools.sh` judges the contents; this one judges the census.
#
# Exit codes: 0 = measured and fine | 1 = measured and fails | 2 = could not measure.
#
# Usage:
#   scripts/gates/gate-agent-roster.sh
#   scripts/gates/gate-agent-roster.sh --root DIR
#   scripts/gates/gate-agent-roster.sh --self-test
#
# Environment variables:
#   GATE_SELFTEST=0   skips the self-test; the verdict is then capped at 2.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

ROOT="$(cd "${EHS_REPO_ROOT:-$(gate_root)}" && pwd -P)"
ONLY_SELFTEST=0
SELFTEST_SKIPPED=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --self-test) ONLY_SELFTEST=1; shift ;;
    -h|--help) sed -n '2,49p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

census() {  # census <root> -> prints "rc|message" lines, rc 0 fine, 1 mismatch, 2 unreadable
  python3 - "$1" <<'PY'
import json, re, sys
from pathlib import Path

root = Path(sys.argv[1])
manifest = root / ".claude-plugin" / "plugin.json"
agents_dir = root / "agents"
roster = root / "skills" / "ethical-hacker-squad" / "references" / "team.md"

for required in (manifest, agents_dir, roster):
    if not required.exists():
        print(f"2|missing {required.relative_to(root)}")
        raise SystemExit(0)

try:
    declared_raw = json.loads(manifest.read_text(encoding="utf-8")).get("agents")
except ValueError as exc:
    print(f"2|the plugin manifest does not parse: {exc}")
    raise SystemExit(0)
if not isinstance(declared_raw, list):
    print("2|the plugin manifest declares no `agents` list")
    raise SystemExit(0)

bad = False

# A set cannot count. Group by stem BEFORE collapsing, or a repeated entry --
# or two paths resolving to the same agent -- is invisible to every comparison
# below: the sets agree with themselves no matter how many times a name appears.
by_stem = {}
for p in declared_raw:
    by_stem.setdefault(Path(p).stem, []).append(p)
for stem, paths in sorted(by_stem.items()):
    if len(paths) > 1:
        bad = True
        print(f"1|{stem}: declared {len(paths)} times in the plugin manifest "
              f"({', '.join(paths)}) -- the squad is a set, and a manifest that "
              f"repeats a role does not describe it")

declared = set(by_stem)
on_disk = {p.stem for p in agents_dir.glob("*.md")}
named = set(re.findall(r"`(ehs-[a-z0-9-]+)`", roster.read_text(encoding="utf-8")))
named &= on_disk | declared  # the roster mentions ids in prose too; only the census matters

if not on_disk:
    print("2|no agent file on disk, so there is nothing to compare")
    raise SystemExit(0)

for label, a, b in (
    ("on disk but NOT declared in the plugin manifest — it ships to nobody", on_disk, declared),
    ("declared in the plugin manifest but NOT on disk — it ships as a broken path", declared, on_disk),
    ("on disk but NOT named in the roster of references/team.md", on_disk, named),
    ("named in the roster but NOT on disk", named, on_disk),
):
    missing = sorted(a - b)
    if missing:
        bad = True
        print(f"1|{', '.join(missing)}: {label}")

if not bad:
    print(f"0|{len(on_disk)} agent(s), declared {len(declared_raw)} time(s), and the manifest, the directory and the roster name the same set")
PY
}

selftest() {
  command -v python3 >/dev/null 2>&1 || { gate_warn "python3 is not on PATH"; return "$GATE_UNMEASURABLE"; }
  local work out
  work="$(mktemp -d)" || { gate_warn "cannot create a working directory"; return "$GATE_UNMEASURABLE"; }

  # A minimal healthy tree.
  mkdir -p "$work/.claude-plugin" "$work/agents" "$work/skills/ethical-hacker-squad/references"
  printf '%s\n' '{"agents": ["./agents/ehs-alpha.md", "./agents/ehs-beta.md"]}' > "$work/.claude-plugin/plugin.json"
  : > "$work/agents/ehs-alpha.md"; : > "$work/agents/ehs-beta.md"
  printf '%s\n' '| a | `ehs-alpha` |' '| b | `ehs-beta` |' > "$work/skills/ethical-hacker-squad/references/team.md"

  out="$(census "$work")"
  case "$out" in
    0\|*) : ;;
    *) rm -rf "$work"; gate_fail "self-test: a consistent census returned '$out', expected 0"; return "$GATE_FAIL" ;;
  esac

  # The defect this gate was written for: on disk, not in the manifest.
  : > "$work/agents/ehs-gamma.md"
  printf '%s\n' '| c | `ehs-gamma` |' >> "$work/skills/ethical-hacker-squad/references/team.md"
  out="$(census "$work")"
  case "$out" in
    1\|*ehs-gamma*ships\ to\ nobody*) : ;;
    *) rm -rf "$work"; gate_fail "self-test: an undeclared agent returned '$out', expected 1 naming it"; return "$GATE_FAIL" ;;
  esac

  # The mirror: declared, absent from disk.
  printf '%s\n' '{"agents": ["./agents/ehs-alpha.md", "./agents/ehs-ghost.md"]}' > "$work/.claude-plugin/plugin.json"
  out="$(census "$work")"
  case "$out" in
    1\|*ehs-ghost*broken\ path*) : ;;
    *) rm -rf "$work"; gate_fail "self-test: a declared-but-absent agent returned '$out', expected 1"; return "$GATE_FAIL" ;;
  esac

  # A role declared twice. This is the case a set comparison cannot see, and the
  # reason the check above counts before it collapses: with `ehs-alpha` listed
  # twice the three sets still agree with each other, so every other assertion
  # in this file passes and the manifest is still wrong.
  printf '%s\n' '{"agents": ["./agents/ehs-alpha.md", "./agents/ehs-beta.md", "./agents/ehs-alpha.md"]}' > "$work/.claude-plugin/plugin.json"
  out="$(census "$work")"
  case "$out" in
    1\|*ehs-alpha*declared\ 2\ times*) : ;;
    *) rm -rf "$work"; gate_fail "self-test: an agent declared twice returned '$out', expected 1 naming it"; return "$GATE_FAIL" ;;
  esac

  # ...and two different paths that resolve to the same role, which reads as a
  # longer list to a human and as the same single agent to the loader.
  printf '%s\n' '{"agents": ["./agents/ehs-alpha.md", "./agents/ehs-beta.md", "./vendor/ehs-alpha.md"]}' > "$work/.claude-plugin/plugin.json"
  out="$(census "$work")"
  case "$out" in
    1\|*ehs-alpha*declared\ 2\ times*) : ;;
    *) rm -rf "$work"; gate_fail "self-test: two paths for one role returned '$out', expected 1 naming it"; return "$GATE_FAIL" ;;
  esac

  # Unreadable manifest must be 2, never a pass.
  printf '%s\n' '{ not json' > "$work/.claude-plugin/plugin.json"
  out="$(census "$work")"
  case "$out" in
    2\|*) : ;;
    *) rm -rf "$work"; gate_fail "self-test: an unparseable manifest returned '$out', expected 2"; return "$GATE_FAIL" ;;
  esac

  rm -rf "$work"
  return "$GATE_OK"
}

main() {
  gate_header "agent-roster (the manifest, the directory and the roster name the same squad)"
  gate_scope "the set of agents in .claude-plugin/plugin.json, in agents/, and in the roster of references/team.md"
  gate_out_of_scope "whether an agent is any good, whether its pack matches its description, and whether its roster row is accurate - this is a census, not a review"

  if [ "${GATE_SELFTEST:-1}" != "0" ]; then
    selftest
    local st=$?
    [ "$st" -eq "$GATE_OK" ] || { gate_verdict "$st"; return "$st"; }
    gate_info "self-test: an undeclared agent, a declared-but-absent one, a role declared twice, two paths for one role and an unparseable manifest all behave"
  else
    SELFTEST_SKIPPED=1
    gate_warn "self-test SKIPPED via GATE_SELFTEST=0: the verdict cannot be 0"
  fi

  if [ "$ONLY_SELFTEST" -eq 1 ]; then
    [ "$SELFTEST_SKIPPED" -eq 1 ] && { gate_warn "--self-test with GATE_SELFTEST=0: no test was run"; gate_verdict 2; return "$GATE_UNMEASURABLE"; }
    gate_ok "self-test passed; the repo was not audited (--self-test)"; gate_verdict 0; return "$GATE_OK"
  fi

  command -v python3 >/dev/null 2>&1 || { gate_warn "python3 is not on PATH"; gate_verdict 2; return "$GATE_UNMEASURABLE"; }

  local out rc=0
  out="$(census "$ROOT")"
  while IFS='|' read -r code message; do
    [ -z "$code" ] && continue
    case "$code" in
      0) gate_info "$message" ;;
      1) gate_fail "$message"; rc=1 ;;
      *) gate_warn "$message"; [ "$rc" -eq 0 ] && rc=2 ;;
    esac
  done <<< "$out"

  case "$rc" in
    0)
      if [ "$SELFTEST_SKIPPED" -eq 1 ]; then
        gate_warn "the census agrees, but the self-test was skipped: I cannot sign this result"
        gate_verdict 2; return "$GATE_UNMEASURABLE"
      fi
      gate_ok "the manifest, the directory and the roster name the same squad"
      gate_verdict 0; return "$GATE_OK" ;;
    1) gate_verdict 1; return "$GATE_FAIL" ;;
    *) gate_verdict 2; return "$GATE_UNMEASURABLE" ;;
  esac
}

main
exit $?
