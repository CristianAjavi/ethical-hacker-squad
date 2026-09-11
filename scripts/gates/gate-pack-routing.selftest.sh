#!/usr/bin/env bash
# Self-test for gate-pack-routing.sh.
#
# Every case is a mutation of a fixture tree that passes, because the only
# evidence that a gate measures anything is that it goes red when the thing it
# watches is broken. What it watches is prose: the sentence that sends a
# specialist to a file. The baseline is therefore written in the two shapes the
# real corpus uses - a header naming one sibling, and a header naming two
# siblings on one line and carrying both ranges, with a trailing sentence about
# a third file. That second shape is a control against this instrument itself:
# two earlier versions of it read those lines as claims about the wrong file and
# accused a correct router, which is the failure mode the gate must not have.
#
# The last case is the one that matters in the other direction: this repository
# has to pass, or the rule is one nobody can satisfy.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-pack-routing.sh"
REAL="$(cd "$HERE/../.." && pwd)"
command -v python3 >/dev/null 2>&1 || { echo "UNMEASURABLE python3 is missing"; exit 2; }
[ -f "$GATE" ] || { echo "UNMEASURABLE the gate is missing"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-pack-routing-XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
T="$TMP/tree"
K="$T/skills/ethical-hacker-squad/references/knowledge"
pass=0; fail=0

base() {
  rm -rf "$T"; mkdir -p "$K" "$T/agents"

  cat > "$K/README.md" <<'EOF'
# Knowledge packs

| File | Role | Note |
| --- | --- | --- |
| `alpha.md` | `ehs-alpha` | entry |
| `alpha-extra.md` | `ehs-alpha` | second file |
| `beta.md` | `ehs-beta` | entry |
| `beta-one.md` | `ehs-beta` | second file |
| `beta-two.md` | `ehs-beta` | third file |
EOF

  cat > "$K/alpha.md" <<'EOF'
# Alpha

> **Second file of this pack.** `alpha-extra.md` holds `ALP-03`..`ALP-04`.

## Procedures

### ALP-01 First
### ALP-02 Second
EOF

  cat > "$K/alpha-extra.md" <<'EOF'
# Alpha, continued

## Procedures

### ALP-03 Third
### ALP-04 Fourth
EOF

  # The two-siblings-on-one-line shape, with a trailing sentence about neither.
  cat > "$K/beta.md" <<'EOF'
# Beta

> The pack continues in `beta-one.md` (`BET-03`..`BET-04`) and in `beta-two.md` (`BET-05`, `BET-06`). `BET-01` applies to every engagement without exception, and the notes at the end of this file govern all three.

## Procedures

### BET-01 First
### BET-02 Second
EOF

  cat > "$K/beta-one.md" <<'EOF'
# Beta, second file

### BET-03 Third
### BET-04 Fourth
EOF

  cat > "$K/beta-two.md" <<'EOF'
# Beta, third file

### BET-05 Fifth
### BET-06 Sixth
EOF

  cat > "$T/agents/ehs-alpha.md" <<'EOF'
# ehs-alpha

## First actions

1. Read `alpha.md` for `ALP-01`..`ALP-02`.
2. Read `alpha-extra.md` for `ALP-03`..`ALP-04`.

## Afterwards
EOF

  cat > "$T/agents/ehs-beta.md" <<'EOF'
# ehs-beta

## First actions

1. Read `beta.md` for `BET-01`..`BET-02`.
2. Read `beta-one.md` for `BET-03`..`BET-04`, then `beta-two.md` for `BET-05`..`BET-06`.

## Afterwards
EOF
}

# case_run <name> <want-rc> <needle> [mutation shell]
case_run() {
  local name="$1" want="$2" needle="$3" mut="${4-}"
  base
  if [ -n "$mut" ]; then eval "$mut" || { printf 'FAILED   %-36s mutation did not apply\n' "$name"; fail=$((fail+1)); return; }; fi
  local out rc
  out="$(bash "$GATE" --tree "$T" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
    printf 'ok       %-36s rc=%s\n' "$name" "$rc"; pass=$((pass+1))
  else
    printf 'FAILED   %-36s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/         /' | tail -8; fail=$((fail+1))
  fi
}

echo "=== self-test: gate-pack-routing.sh ==="

# The baseline, which also carries the control against the instrument: six
# routes, two of them read off a line that names two files and ends with a
# sentence about neither. No finding may come out of it.
case_run a-baseline-passes 0 "CHECKED 6 route"

# The defect this gate exists for, in its two forms: the router stopped naming
# the file at all, and the router still names it with the range from before the
# split.
case_run entry-header-drops-the-sibling 1 "never names" \
  "perl -0pi -e 's/\\*\\*Second file of this pack\\.\\*\\* \`alpha-extra\\.md\` holds \`ALP-03\`\\.\\.\`ALP-04\`\\./Everything you need is in this file./' '$K/alpha.md'"
case_run entry-header-keeps-the-old-range 1 "but not" \
  "perl -0pi -e 's/\`ALP-03\`\\.\\.\`ALP-04\`/\`ALP-03\`/' '$K/alpha.md'"
case_run agent-drops-the-sibling 1 "never names" \
  "perl -0pi -e 's/^2\\. Read \`alpha-extra.*\$//m' '$T/agents/ehs-alpha.md'"
case_run agent-keeps-the-old-range 1 "but not" \
  "perl -0pi -e 's/\`ALP-03\`\\.\\.\`ALP-04\`/\`ALP-03\`/' '$T/agents/ehs-alpha.md'"

# The same drift facing the other way: a procedure was deleted and the range
# still runs past it.
case_run range-outlives-its-procedure 1 "no file of this pack defines" \
  "perl -0pi -e 's/\`ALP-03\`\\.\\.\`ALP-04\`/\`ALP-03\`..\`ALP-06\`/' '$K/alpha.md'"

# A router that cannot be read is not a router that says nothing: a section
# renamed out from under the agent silently removes the route.
case_run agent-has-no-first-actions 1 "no region to read" \
  "perl -0pi -e 's/^## First actions\$/## Where to start/m' '$T/agents/ehs-beta.md'"
case_run agent-file-is-missing 1 "does not exist" "rm -f '$T/agents/ehs-beta.md'"

# The table is the one place that says which file belongs to which pack.
case_run table-names-a-file-that-is-gone 1 "not in knowledge/" "rm -f '$K/beta-two.md'"

# Could not measure, which is not a pass.
case_run no-pack-table-at-all 2 "nothing says which file" "rm -f '$K/README.md'"
case_run table-parses-to-zero-rows 2 "zero rows" \
  "printf '# Knowledge packs\\n\\nNo table here any more.\\n' > '$K/README.md'"

# REACHABILITY. A rule no real tree satisfies is a rule that gets switched off.
out="$(bash "$GATE" --tree "$REAL" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  printf 'ok       %-36s rc=0\n' "z-this-repository-passes"; pass=$((pass+1))
else
  printf 'FAILED   %-36s rc=%s (wanted 0)\n' "z-this-repository-passes" "$rc"
  printf '%s\n' "$out" | sed 's/^/         /' | tail -12; fail=$((fail+1))
fi

echo "---"
printf 'cases: %d | ok: %d | FAILED: %d\n' "$((pass+fail))" "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
