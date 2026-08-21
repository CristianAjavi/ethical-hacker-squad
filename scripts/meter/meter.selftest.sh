#!/usr/bin/env bash
# scripts/meter/meter.selftest.sh
#
# The meter, measured against itself. Every case here is NEGATIVE: it builds a
# fixture that is broken in one specific way and asserts that the meter NOTICES.
# A measuring instrument that only ever prints green on a healthy repo has not
# been tested; it has been admired.
#
# The cases that matter most, and why they exist:
#   T07  a gate returning 2 must NOT let the meter return 0. The first working
#        version of the meter did exactly that (gates block printed
#        "UNMEASURABLE 1" and the verdict said "exit 0 - nothing failing").
#        This case is that regression, nailed down.
#   T06  a missing PCC baseline must be a 2, never a 0 and never a silent 0%.
#   T09  no python3 must degrade to NOT MEASURED, not to a stack trace.
#
# Exit codes: 0 = every case passed, 1 = a case failed, 2 = the harness itself
# could not run (same doctrine as everything else in this repo).
#
# Usage: bash scripts/meter/meter.selftest.sh [-v]

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METER="$SELF_DIR/meter.sh"
VERBOSE=0
[ "${1:-}" = "-v" ] && VERBOSE=1

[ -f "$METER" ] || { printf 'selftest: NOT MEASURED - meter.sh not found\n' >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || {
  printf 'selftest: NOT MEASURED - python3 is required to exercise the meter core\n' >&2
  exit 2; }

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t metertest)" || {
  printf 'selftest: NOT MEASURED - no temporary directory\n' >&2; exit 2; }
cleanup() { [ -d "$WORK" ] && find "$WORK" -mindepth 0 -delete 2>/dev/null; }
trap cleanup EXIT

PASS=0; FAIL=0
LAST_OUT=""

ok()   { PASS=$((PASS + 1)); printf '  PASS  %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$1"
         printf '        %s\n' "$2"
         [ "$VERBOSE" -eq 1 ] && printf '%s\n' "$LAST_OUT" | sed 's/^/        | /'
         return 0; }

# --------------------------------------------------------------------------
# fixture builder. Creates a minimal but COMPLETE repo: one pack with two
# procedures, a consistent baseline, one SHA-pinned workflow and a stub gate
# runner that reports a clean suite. Each test then breaks exactly one thing.
# --------------------------------------------------------------------------
PROC_BODY='**Where to look**
- somewhere.

**Vulnerable pattern** — the bad thing.

**What rules it out (false positive)**
- the compensating control.

**Minimal test** — local and non-destructive.

**Traceability**: `CWE-79` · `A03:2025`
**Tooling**: `grep -rn x .`
'

make_fixture() { # make_fixture <dir>
  d="$1"
  mkdir -p "$d/kb" "$d/.github/workflows" "$d/scripts/gates" "$d/data"

  { printf '# Pack\n\n## §1 Section\n\n### TST-01 First procedure\n\n%s\n' "$PROC_BODY"
    printf '### TST-02 Second procedure\n\n%s\n' "$PROC_BODY"
  } > "$d/kb/pack-one.md"

  cat > "$d/packs.json" <<'JSON'
{
  "knowledge_dir": "kb",
  "non_procedure_files": [],
  "required_fields": [
    { "name": "where_to_look",       "label": "Where to look",                      "pattern": "^\\*\\*Where to look\\*\\*" },
    { "name": "vulnerable_pattern",  "label": "Vulnerable pattern",                 "pattern": "^\\*\\*Vulnerable pattern\\*\\*" },
    { "name": "rules_it_out",        "label": "What rules it out (false positive)",  "pattern": "^\\*\\*What rules it out \\(false positive\\)\\*\\*" },
    { "name": "minimal_test",        "label": "Minimal test",                       "pattern": "^\\*\\*Minimal test\\*\\*" },
    { "name": "traceability",        "label": "Traceability",                       "pattern": "^\\*\\*Traceability\\*\\*" },
    { "name": "tooling",             "label": "Tooling",                            "pattern": "^\\*\\*Tooling\\*\\*" }
  ],
  "traceability_field": "traceability",
  "procedure_heading": "^### ([A-Z]+)-([0-9]+)\\b",
  "packs": [ { "pack": "one", "role": "test", "id_prefixes": ["TST"], "files": ["pack-one.md"] } ],
  "hygiene_artifacts": [ { "name": "LICENSE", "candidates": ["LICENSE"] } ],
  "workflows_dir": ".github/workflows",
  "gates_runner": "scripts/gates/run-all.sh",
  "baseline_file": "data/baseline.json"
}
JSON

  cat > "$d/data/baseline.json" <<'JSON'
{
  "extracted_on": "2026-08-16",
  "source": { "document": "fixture" },
  "confidence": { "is_upper_bound": true, "self_assessed": true,
                  "statement": "fixture", "known_false_positives": [] },
  "packs": [ { "pack": "one", "covered": 4, "gaps": 6, "pcc_declared": 0.40, "gaps_high": 2 } ],
  "global_declared": { "covered": 4, "gaps": 6, "pcc_declared": 0.40, "gaps_high": 2 }
}
JSON

  cat > "$d/.github/workflows/ci.yml" <<'YML'
name: ci
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
YML

  printf 'MIT\n' > "$d/LICENSE"
  stub_gates "$d" 0 "discovered: 2 | run: 2 | green: 2 | FAIL: 0 | UNMEASURABLE: 0"
}

stub_gates() { # stub_gates <dir> <exit> <summary line>
  cat > "$1/scripts/gates/run-all.sh" <<EOF
#!/usr/bin/env bash
printf '\n===== GATE SUMMARY =====\n'
printf '%s\n' "$3"
printf 'OK   gate-a.sh — measured, no findings\n'
exit $2
EOF
  chmod +x "$1/scripts/gates/run-all.sh"
}

run_meter() { # run_meter <dir> [extra args...]; sets LAST_OUT, returns meter rc
  d="$1"; shift
  LAST_OUT="$(bash "$METER" --root "$d" --packs "$d/packs.json" \
      --families "$SELF_DIR/standards-families.json" \
      --baseline "$d/data/baseline.json" --gates-timeout 30 "$@" 2>&1)"
  return $?
}

expect() { # expect <name> <want_rc> <dir> [extra args...]
  name="$1"; want="$2"; d="$3"; shift 3
  run_meter "$d" "$@"
  got=$?
  if [ "$got" -eq "$want" ]; then ok "$name (exit $got)"
  else bad "$name" "expected exit $want, got $got"; fi
}

expect_says() { # expect_says <name> <want_rc> <substring> <dir> [extra args...]
  name="$1"; want="$2"; needle="$3"; d="$4"; shift 4
  run_meter "$d" "$@"
  got=$?
  if [ "$got" -ne "$want" ]; then
    bad "$name" "expected exit $want, got $got"
  elif printf '%s' "$LAST_OUT" | grep -qF "$needle"; then
    ok "$name (exit $got, said \"$needle\")"
  else
    bad "$name" "exit $want was right but the output never mentions: $needle"
  fi
}

printf '\n=== meter self-test (negative cases) ===\n\n'

# T01 - the control. A healthy fixture must be a clean 0, otherwise every other
#       case is meaningless (a meter that always returns non-zero proves nothing).
F="$WORK/t01"; make_fixture "$F"
expect "T01 healthy fixture returns 0" 0 "$F"

# T02 - a procedure missing a mandatory field is a MEASURED FAILURE (1).
F="$WORK/t02"; make_fixture "$F"
grep -v '^\*\*Minimal test\*\*' "$F/kb/pack-one.md" > "$F/kb/tmp" && mv "$F/kb/tmp" "$F/kb/pack-one.md"
expect_says "T02 procedure missing a mandatory field" 1 "missing mandatory field" "$F"

# T03 - two procedures sharing an ID. This is the error a parallel merge makes.
F="$WORK/t03"; make_fixture "$F"
printf '### TST-01 Duplicated on purpose\n\n%s\n' "$PROC_BODY" >> "$F/kb/pack-one.md"
expect_says "T03 duplicate procedure ID" 1 "duplicate procedure ID TST-01" "$F"

# T04 - baseline that contradicts its own arithmetic.
F="$WORK/t04"; make_fixture "$F"
sed 's/"pcc_declared": 0.40, "gaps_high": 2 } ],/"pcc_declared": 0.95, "gaps_high": 2 } ],/' \
  "$F/data/baseline.json" > "$F/data/tmp" && mv "$F/data/tmp" "$F/data/baseline.json"
expect_says "T04 baseline contradicts its own arithmetic" 1 "declares pcc=0.95" "$F"

# T05 - an action pinned to a tag instead of a SHA.
F="$WORK/t05"; make_fixture "$F"
sed 's|actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2|actions/checkout@v4|' \
  "$F/.github/workflows/ci.yml" > "$F/.github/workflows/tmp" \
  && mv "$F/.github/workflows/tmp" "$F/.github/workflows/ci.yml"
expect_says "T05 action not pinned to a SHA" 1 "not pinned to a 40-char SHA" "$F"

# T06 - no PCC baseline at all. Must be 2 (unknown), never 0 and never "0%".
F="$WORK/t06"; make_fixture "$F"
mv "$F/data/baseline.json" "$F/data/baseline.json.gone"
expect_says "T06 missing PCC baseline is NOT MEASURED" 2 "file not found" "$F"

# T07 - THE REGRESSION. A gate that returns 2 must never yield a green meter.
F="$WORK/t07"; make_fixture "$F"
stub_gates "$F" 2 "discovered: 2 | run: 2 | green: 1 | FAIL: 0 | UNMEASURABLE: 1"
expect_says "T07 an UNMEASURABLE gate never yields exit 0" 2 "never happened" "$F"

# T08 - a gate that measured a failure is a 1, not a 2 and not a 0.
F="$WORK/t08"; make_fixture "$F"
stub_gates "$F" 1 "discovered: 2 | run: 2 | green: 1 | FAIL: 1 | UNMEASURABLE: 0"
expect_says "T08 a failing gate propagates as exit 1" 1 "MEASURED A FAILURE" "$F"

# T09 - no python3 on PATH. Degrade to NOT MEASURED; do not crash.
F="$WORK/t09"; make_fixture "$F"
BIN="$WORK/nopy-bin"; mkdir -p "$BIN"
for t in bash sh mktemp cat sed grep find sleep kill printf; do
  p="$(command -v "$t" 2>/dev/null)" && ln -sf "$p" "$BIN/$t"
done
if [ -x "$BIN/bash" ] && ! PATH="$BIN" command -v python3 >/dev/null 2>&1; then
  LAST_OUT="$(PATH="$BIN" bash "$METER" --root "$F" --packs "$F/packs.json" \
      --families "$SELF_DIR/standards-families.json" --no-gates 2>&1)"
  got=$?
  if [ "$got" -eq 2 ] && printf '%s' "$LAST_OUT" | grep -qF "python3 is not on PATH"; then
    ok "T09 missing python3 degrades to NOT MEASURED (exit 2)"
  else
    bad "T09 missing python3 degrades to NOT MEASURED" "got exit $got"
  fi
else
  printf '  SKIP  T09 could not build a python3-free PATH on this machine\n'
fi

# T10 - --no-gates is a hole, not a pass.
F="$WORK/t10"; make_fixture "$F"
expect_says "T10 --no-gates is a declared hole, not a pass" 2 "not the same as passing" "$F" --no-gates

# T11 - a knowledge file on disk that packs.json does not declare would be
#       invisible to every count. It must be reported, and the totals must go
#       UNMEASURED with it: they no longer describe what is on disk. Reporting the
#       stray file while still printing a confident TOTAL is the silent
#       under-count that packs.json promises not to do.
F="$WORK/t11"; make_fixture "$F"
printf '# Orphan\n\n### TST-99 Nobody counts me\n\n%s\n' "$PROC_BODY" > "$F/kb/orphan.md"
expect_says "T11 undeclared knowledge file is reported" 2 "not declared in packs.json" "$F"
run_meter "$F"
if printf '%s' "$LAST_OUT" | grep -q 'TOTALS NOT MEASURED'; then
  ok "T11b undeclared file also voids the totals (no silent under-count)"
else
  bad "T11b undeclared file also voids the totals" "the totals were still published as measured"
fi

# T12 - an empty Traceability field is a failure; a field that says
#       "internal process" is not (T01 already covers the legitimate case).
F="$WORK/t12"; make_fixture "$F"
sed 's/^\*\*Traceability\*\*: .*/**Traceability**:/' "$F/kb/pack-one.md" > "$F/kb/tmp" \
  && mv "$F/kb/tmp" "$F/kb/pack-one.md"
expect_says "T12 empty Traceability field is a failure" 1 "Traceability field is empty" "$F"

# T13 - a gate runner whose output cannot be parsed. Unknown is 2, never 0.
F="$WORK/t13"; make_fixture "$F"
cat > "$F/scripts/gates/run-all.sh" <<'EOF'
#!/usr/bin/env bash
echo "something went sideways"
exit 0
EOF
chmod +x "$F/scripts/gates/run-all.sh"
expect_says "T13 unparseable gate output is NOT MEASURED" 2 "no GATE SUMMARY" "$F"

# T14 - a corpus directory that does not exist. Not zero procedures: unknown.
F="$WORK/t14"; make_fixture "$F"
mv "$F/kb" "$F/kb-moved"
expect_says "T14 missing corpus is NOT MEASURED, not 0 procedures" 2 "knowledge directory not found" "$F"

# T15 - JSON output must be well formed and carry the same verdict. stdout only:
#       the progress line the meter writes to stderr must never pollute the JSON,
#       and capturing 2>&1 here would hide exactly that bug.
F="$WORK/t15"; make_fixture "$F"
LAST_OUT="$(bash "$METER" --root "$F" --packs "$F/packs.json" \
    --families "$SELF_DIR/standards-families.json" \
    --baseline "$F/data/baseline.json" --gates-timeout 30 --json 2>/dev/null)"
got=$?
if command -v jq >/dev/null 2>&1; then
  jverdict="$(printf '%s' "$LAST_OUT" | jq -r '.verdict.exit_code' 2>/dev/null)"
  if [ "$jverdict" = "$got" ]; then
    ok "T15 --json is valid and its verdict matches the exit code ($got)"
  else
    bad "T15 --json verdict matches exit code" "json says '$jverdict', process exited $got"
  fi
else
  printf '  SKIP  T15 jq not installed, JSON not validated\n'
fi

# --------------------------------------------------------------------------
# T16-T20 were added by the adversarial review of 2026-08-16. Each one is a
# real defect that was found by attacking the meter, not by reading it.
# --------------------------------------------------------------------------

# T16 - THE SECOND FALSE GREEN. The runner's GATE SUMMARY counters are taken on
#       trust, and the entire verdict hangs off them. Here the summary swears
#       FAIL: 0 / UNMEASURABLE: 0 while its own detail lines say a gate failed
#       and another could not be measured. Before the fix the meter printed both
#       detail lines and concluded "exit 0 - everything measured, nothing
#       failing". A runner that contradicts itself cannot be believed in either
#       direction: that is a 2.
F="$WORK/t16"; make_fixture "$F"
cat > "$F/scripts/gates/run-all.sh" <<'EOF'
#!/usr/bin/env bash
printf '\n===== GATE SUMMARY =====\n'
printf 'discovered: 2 | run: 2 | green: 2 | FAIL: 0 | UNMEASURABLE: 0\n'
printf 'FAIL gate-a.sh — the manifest is broken\n'
printf 'UNMEASURABLE gate-b.sh — COULD NOT MEASURE\n'
exit 0
EOF
chmod +x "$F/scripts/gates/run-all.sh"
expect_says "T16 a runner contradicting its own summary is NOT MEASURED" 2 \
  "contradicts itself" "$F"

# T17 - THE REASSURING ZERO. The knowledge directory EXISTS but every pack file
#       is gone. T14 covers the easy branch (directory absent); this is the one
#       that used to print "TOTAL 0 0 0 0" followed by "every procedure carries
#       the six mandatory fields" - a green sentence about a corpus that is not
#       there. Zero is a measurement. Absent is not zero.
F="$WORK/t17"; make_fixture "$F"
mv "$F/kb/pack-one.md" "$F/pack-one.md.moved"
run_meter "$F"; got=$?
if [ "$got" -ne 2 ]; then
  bad "T17 an empty corpus directory is NOT MEASURED, never 0 procedures" "expected 2, got $got"
elif printf '%s' "$LAST_OUT" | grep -qE '^  TOTAL +0 +0 +0'; then
  bad "T17 an empty corpus directory is NOT MEASURED, never 0 procedures" \
      "it printed a TOTAL of 0 as though it had counted"
elif printf '%s' "$LAST_OUT" | grep -qF 'every procedure carries the six'; then
  bad "T17 an empty corpus directory is NOT MEASURED, never 0 procedures" \
      "it gave an all-clear on the six fields over a corpus it never read"
else
  ok "T17 an empty corpus directory is NOT MEASURED, never 0 procedures (exit 2)"
fi

# T18 - THE PLAUSIBLE UNDER-COUNT. One pack file of two is unreadable. The pack
#       row correctly said n/m, but the TOTAL row kept printing the sum of what
#       it managed to read, unmarked: a number that looks exactly like a real
#       measurement and is short by a whole file. Harder to catch than a zero,
#       because nothing on screen invites you to doubt it.
F="$WORK/t18"; make_fixture "$F"
printf '### TST-03 In the second file\n\n%s\n' "$PROC_BODY" > "$F/kb/pack-two.md"
sed 's|"files": \["pack-one.md"\]|"files": ["pack-one.md", "pack-two.md"]|' \
  "$F/packs.json" > "$F/tmp" && mv "$F/tmp" "$F/packs.json"
mv "$F/kb/pack-two.md" "$F/pack-two.md.moved"
run_meter "$F"; got=$?
if [ "$got" -ne 2 ]; then
  bad "T18 an unreadable pack file voids the totals" "expected 2, got $got"
elif printf '%s' "$LAST_OUT" | grep -qE '^  TOTAL +[0-9]'; then
  bad "T18 an unreadable pack file voids the totals" \
      "the TOTAL row still published a number summed over files it could not read"
else
  ok "T18 an unreadable pack file voids the totals, not just the pack row (exit 2)"
fi

# T19 - A GAP IS A LOST PROCEDURE. Numbering gaps were computed and printed, and
#       then changed nothing: with green gates the meter returned 0 while a
#       procedure had vanished from the middle of a pack. Printing a defect is
#       not the same as counting it.
F="$WORK/t19"; make_fixture "$F"
printf '### TST-04 Leaves a hole at 03\n\n%s\n' "$PROC_BODY" >> "$F/kb/pack-one.md"
expect_says "T19 a numbering gap is a measured failure, not a note" 1 \
  "numbering gap in TST" "$F"

# T20 - a runner that claims gates ran but names none of them. Nothing can be
#       attributed, so nothing can be trusted.
F="$WORK/t20"; make_fixture "$F"
cat > "$F/scripts/gates/run-all.sh" <<'EOF'
#!/usr/bin/env bash
printf '\n===== GATE SUMMARY =====\n'
printf 'discovered: 2 | run: 2 | green: 2 | FAIL: 0 | UNMEASURABLE: 0\n'
exit 0
EOF
chmod +x "$F/scripts/gates/run-all.sh"
expect_says "T20 a runner that names no gate is NOT MEASURED" 2 "printed no per-gate line" "$F"

printf '\n=== %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
