#!/usr/bin/env bash
# scripts/gates/gate-coverage-gap-claims.sh
#
# A routing row may not send a reader away from a pack that exists.
#
# WHY IT EXISTS
#   `references/coverage.md` carried this row from the repository's first commit
#   until 2026-09-01:
#
#     | Desktop app, CLI, published library | `web-api` (partial only) | ...
#       Path traversal via symlink, temp-file races, argument and environment
#       parsing, and dangerous public-API defaults have **no procedure** - see
#       the gap list in `traceability.md`. |
#
#   By then all four had one: `LOC-01`/`LOC-02`, `LOC-03`/`LOC-04`, `LOC-05` and
#   `LOC-10`, shipped with the `local-app` pack in `45233a5`. The gap list the
#   row points at had been updated in the same direction and reads **"now
#   covered by `local-app.md` (`LOC-01`..`LOC-16`)"**. So the pointer still
#   resolved, and its target refuted the sentence that cited it -- the worst
#   shape a stale reference takes, because following the link looks like
#   diligence and confirms nothing.
#
#   The cost was the whole role. A reader with a desktop app or a CLI in the
#   inventory landed on that row, routed to `web-api` partial, and was told the
#   four classes did not exist, so `local-app` was never staffed. Sixteen
#   procedures sat behind a row saying they were not there. Twenty-eight gates
#   were green throughout: nothing compared a routing row's claim of absence
#   against the corpus that answers it.
#
# WHAT IT MEASURES
#   Every claim of absence in `coverage.md` -- the literal `**no procedure**` --
#   must name the gap-list entry that records it, as `(gap: **entry name**)`,
#   and that entry must exist in the `## Known coverage gaps` section of
#   `traceability.md` and must NOT declare itself covered. A claim with no
#   anchor is unverifiable prose; an anchor whose entry says `now covered by`
#   is this defect exactly.
#
# WHAT IT DOES NOT MEASURE
#   Whether a row routes to the right role, whether the sections it names are
#   the useful ones, or whether a gap the corpus really has is written down at
#   all. This catches a document contradicting its own reference, not a document
#   that is silent.
#
# Exit codes: 0 = measured and fine | 1 = measured and fails | 2 = could not measure.
#
# Usage:
#   scripts/gates/gate-coverage-gap-claims.sh
#   scripts/gates/gate-coverage-gap-claims.sh --root DIR
#   scripts/gates/gate-coverage-gap-claims.sh --self-test
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
    -h|--help) sed -n '2,52p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

audit() {  # audit <root> -> "rc|message" lines
  python3 - "$1" <<'PY'
import re, sys
from pathlib import Path

root = Path(sys.argv[1])
cov = root / "skills" / "ethical-hacker-squad" / "references" / "coverage.md"
tra = root / "skills" / "ethical-hacker-squad" / "references" / "traceability.md"
for f in (cov, tra):
    if not f.exists():
        print(f"2|missing {f.relative_to(root)}")
        raise SystemExit(0)

gaps_block = re.search(r"^## Known coverage gaps\s*$(.*?)(?=^## |\Z)",
                       tra.read_text(encoding="utf-8"), re.S | re.M)
if not gaps_block:
    print("2|traceability.md has no `## Known coverage gaps` section to anchor against")
    raise SystemExit(0)

entries = {}
for line in gaps_block.group(1).splitlines():
    m = re.match(r"^-\s+\*\*(.+?)\*\*\s*(.*)$", line)
    if m:
        entries[m.group(1)] = m.group(2)
if not entries:
    print("2|the gap list holds no `- **entry**` line, so no claim can be anchored")
    raise SystemExit(0)

CLAIM = "**no procedure**"
ANCHOR = re.compile(r"\(gap:\s*\*\*(.+?)\*\*\s*\)")
bad = False
seen = 0
for n, line in enumerate(cov.read_text(encoding="utf-8").splitlines(), 1):
    if CLAIM not in line:
        continue
    seen += 1
    a = ANCHOR.search(line)
    if not a:
        bad = True
        print(f"1|coverage.md:{n} claims `no procedure` and names no gap-list entry: "
              f"write `(gap: **entry name**)` so the claim can be checked against "
              f"traceability.md instead of taken on trust")
        continue
    name = a.group(1)
    if name not in entries:
        bad = True
        print(f"1|coverage.md:{n} anchors its claim to the gap **{name}**, which is not an "
              f"entry in the `## Known coverage gaps` list of traceability.md")
        continue
    if "now covered by" in entries[name].lower():
        bad = True
        print(f"1|coverage.md:{n} claims `no procedure` and anchors it to the gap "
              f"**{name}**, whose own entry says it is now covered: the row sends a reader "
              f"away from a pack that exists")

if not seen:
    print("0|coverage.md makes no claim of absence, so there is none to check")
elif not bad:
    print(f"0|{seen} claim(s) of absence, each anchored to a gap-list entry that still holds it")
PY
}

selftest() {
  command -v python3 >/dev/null 2>&1 || { gate_warn "python3 is not on PATH"; return "$GATE_UNMEASURABLE"; }
  local work out cov tra
  work="$(mktemp -d)" || { gate_warn "cannot create a working directory"; return "$GATE_UNMEASURABLE"; }
  cov="$work/skills/ethical-hacker-squad/references/coverage.md"
  tra="$work/skills/ethical-hacker-squad/references/traceability.md"
  mkdir -p "$(dirname "$cov")"

  write_tra() { printf '%s\n' '## Known coverage gaps' '' "- **Widget surfaces** — $1" '' '## Next' > "$tra"; }

  # Healthy: a claim anchored to an entry that still records the gap.
  write_tra "no procedure, and deliberately so."
  printf '%s\n' '| widgets | x | y | has **no procedure** (gap: **Widget surfaces**). |' > "$cov"
  out="$(audit "$work")"
  case "$out" in 0\|*) : ;; *) rm -rf "$work"; gate_fail "self-test: an anchored live gap returned '$out', expected 0"; return "$GATE_FAIL" ;; esac

  # The defect: the anchor resolves and its target refutes the claim.
  write_tra "now covered by \`widget.md\` (\`WID-01\`..\`WID-09\`)."
  out="$(audit "$work")"
  case "$out" in 1\|*sends\ a\ reader\ away*) : ;; *) rm -rf "$work"; gate_fail "self-test: a claim anchored to a covered gap returned '$out', expected 1"; return "$GATE_FAIL" ;; esac

  # An unanchored claim of absence is unverifiable prose.
  write_tra "no procedure, and deliberately so."
  printf '%s\n' '| widgets | x | y | has **no procedure** - see the gap list. |' > "$cov"
  out="$(audit "$work")"
  case "$out" in 1\|*names\ no\ gap-list\ entry*) : ;; *) rm -rf "$work"; gate_fail "self-test: an unanchored claim returned '$out', expected 1"; return "$GATE_FAIL" ;; esac

  # An anchor pointing at nothing.
  printf '%s\n' '| widgets | x | y | has **no procedure** (gap: **Gadget surfaces**). |' > "$cov"
  out="$(audit "$work")"
  case "$out" in 1\|*not\ an\ entry*) : ;; *) rm -rf "$work"; gate_fail "self-test: a dangling anchor returned '$out', expected 1"; return "$GATE_FAIL" ;; esac

  # No gap section at all is 2, never a pass.
  printf '%s\n' '# nothing here' > "$tra"
  out="$(audit "$work")"
  case "$out" in 2\|*) : ;; *) rm -rf "$work"; gate_fail "self-test: a missing gap section returned '$out', expected 2"; return "$GATE_FAIL" ;; esac

  rm -rf "$work"
  return "$GATE_OK"
}

main() {
  gate_header "coverage-gap-claims (a routing row may not send a reader away from a pack that exists)"
  gate_scope "every \`**no procedure**\` claim in references/coverage.md, its anchor, and whether the gap-list entry in references/traceability.md still records that gap"
  gate_out_of_scope "whether a row routes to the right role, whether its sections are the useful ones, and whether a real gap is written down at all - this catches a contradiction, not a silence"

  if [ "${GATE_SELFTEST:-1}" != "0" ]; then
    selftest
    local st=$?
    [ "$st" -eq "$GATE_OK" ] || { gate_verdict "$st"; return "$st"; }
    gate_info "self-test: a live anchored gap passes; a claim anchored to a covered gap, an unanchored claim and a dangling anchor each fail; a missing gap section reports 2"
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
  out="$(audit "$ROOT")"
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
        gate_warn "every claim checks out, but the self-test was skipped: I cannot sign this result"
        gate_verdict 2; return "$GATE_UNMEASURABLE"
      fi
      gate_ok "no routing row claims a gap its own reference says is closed"
      gate_verdict 0; return "$GATE_OK" ;;
    1) gate_verdict 1; return "$GATE_FAIL" ;;
    *) gate_verdict 2; return "$GATE_UNMEASURABLE" ;;
  esac
}

main
exit $?
