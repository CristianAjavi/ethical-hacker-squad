#!/usr/bin/env bash
# scripts/gates/gate-negative-proof-census.sh
#
# The negative proof may not shrink without saying so.
#
# WHY IT EXISTS
#   `gate-negative-proof.sh` asks whether a gate carries a negative proof AT
#   ALL, and its docstring is careful about the limit: "Whether the battery is
#   any good: whether its cases are real, whether they cover the rules that
#   matter, whether an assertion is strong. Counting files cannot answer that."
#   True. But counting files answers a different question that nothing was
#   asking, and it is the one that gets a repository quietly.
#
#   MEASURED 2026-09-01, on the tree at 9ccd3ab. Move
#   `fixtures/findings/bad/26-reported-inside-a-surface-declared-not-read.json`
#   and its `.expected` sidecar out of the tree:
#
#       measured: 29 artifact(s), ...        (it had been 30)
#       VERDICT   : 0 (measured, no findings)
#
#   A negative proof was retired, the count fell by one, and every gate in the
#   repository stayed green. Nothing recorded that the case had ever existed.
#   Weakening a fixture IS caught -- gut the defect and leave the file, and
#   `gate-findings-artifact.sh` says "a fixture under bad/ validated cleanly, so
#   it proves nothing" -- so the shape that survives is precisely DELETION, the
#   one edit that removes the evidence along with the thing it proved.
#
#   Retiring a control and hiding it are the same edit. So the size of the proof
#   stops being an invisible fact about the disk and becomes a declared limit in
#   `data/negative-proof-census.json`, which lives under `scripts/gates/**` and
#   is therefore protected by G7: lowering it is an edit a reviewer sees.
#
# WHAT IT MEASURES
#   Per fixture family under `scripts/gates/fixtures/<family>/`, the number of
#   INPUTS (files under `bad/` or `unmeasurable/`) and ASSERTIONS (`.expected`
#   sidecars) on disk, against the number declared. Equality in both directions,
#   the same shape as `gate-agent-roster.sh`, and each direction is named for
#   what it means rather than reported as a mismatch:
#     * fewer on disk  -- a proof was retired and the declaration is the only
#                         record that it ever existed;
#     * more on disk   -- the declaration stopped being a baseline, and a number
#                         nobody updates is a number nobody can be caught by;
#     * a family on disk that the census does not name -- a whole family added
#                         with no baseline, which is the first shape one level up.
#
# WHAT IT DOES NOT MEASURE
#   Whether a case is real, whether an assertion is strong, whether the family
#   covers the rules that matter. Same limit as its sibling, and for the same
#   reason: this is a census. `gate-negative-proof.sh` asks whether proof exists,
#   this one asks whether it is still all there, and a human asks whether it is
#   any good.
#
# Exit codes: 0 = measured and fine | 1 = measured and fails | 2 = could not measure.
#
# Usage:
#   scripts/gates/gate-negative-proof-census.sh
#   scripts/gates/gate-negative-proof-census.sh --root DIR
#   scripts/gates/gate-negative-proof-census.sh --census FILE
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

ROOT="$(cd "${EHS_REPO_ROOT:-$(gate_root)}" && pwd -P)"
CENSUS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root)   ROOT="${2:-}"; shift 2 ;;
    --census) CENSUS="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,57p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done
[ -n "$CENSUS" ] || CENSUS="$ROOT/scripts/gates/data/negative-proof-census.json"

count() {  # count <root> <census> -> "rc|message" lines
  python3 - "$1" "$2" <<'PY'
import json, sys
from pathlib import Path

root, census_path = Path(sys.argv[1]), Path(sys.argv[2])
fixtures = root / "scripts" / "gates" / "fixtures"

if not census_path.is_file():
    print(f"2|the census is missing: {census_path.name} - the baseline is what makes a "
          "deletion visible, and without it this gate would sign a shrinking proof")
    raise SystemExit(0)
if not fixtures.is_dir():
    print("2|scripts/gates/fixtures is not a directory, so there is nothing to count")
    raise SystemExit(0)
try:
    declared = json.loads(census_path.read_text(encoding="utf-8")).get("families")
except ValueError as exc:
    print(f"2|the census does not parse: {exc}")
    raise SystemExit(0)
if not isinstance(declared, dict) or not declared:
    print("2|the census declares no `families` map")
    raise SystemExit(0)

on_disk: dict[str, dict[str, int]] = {}
for family_dir in sorted(p for p in fixtures.iterdir() if p.is_dir()):
    tally = {"inputs": 0, "assertions": 0}
    for f in family_dir.rglob("*"):
        if not f.is_file():
            continue
        rel = f.relative_to(family_dir).as_posix()
        if f.name.endswith(".expected"):
            tally["assertions"] += 1
        elif rel.startswith(("bad/", "unmeasurable/")):
            tally["inputs"] += 1
    if tally["inputs"] or tally["assertions"]:
        on_disk[family_dir.name] = tally

bad = False
for family in sorted(set(declared) | set(on_disk)):
    want = declared.get(family)
    have = on_disk.get(family)
    if want is None:
        bad = True
        print(f"1|{family}: {have['inputs']} input(s) and {have['assertions']} assertion(s) on "
              "disk and the census does not name this family - a family with no baseline is a "
              "family whose deletion nothing would notice")
        continue
    if have is None:
        bad = True
        print(f"1|{family}: the census declares {want.get('inputs', 0)} input(s) and this family "
              "is GONE from disk - the declaration is now the only record it existed")
        continue
    for kind in ("inputs", "assertions"):
        w, h = int(want.get(kind, 0)), have[kind]
        if h < w:
            bad = True
            print(f"1|{family}: {h} {kind} on disk, {w} declared - {w - h} negative proof(s) were "
                  "RETIRED. Retiring a control and hiding it are the same edit: lower the number "
                  "in data/negative-proof-census.json in this same change and say why")
        elif h > w:
            bad = True
            print(f"1|{family}: {h} {kind} on disk, {w} declared - the census is stale by "
                  f"{h - w}. Raise it here, or the number stops being a baseline and nobody can "
                  "be caught by it")

if not bad:
    ti = sum(v["inputs"] for v in on_disk.values())
    ta = sum(v["assertions"] for v in on_disk.values())
    print(f"0|{len(on_disk)} fixture famil(ies), {ti} input(s) and {ta} assertion(s), each "
          "matching the number this repository declares it holds")
PY
}

selftest() {
  command -v python3 >/dev/null 2>&1 || { gate_warn "python3 is not on PATH"; return "$GATE_UNMEASURABLE"; }
  local work out
  work="$(mktemp -d)" || { gate_warn "cannot create a working directory"; return "$GATE_UNMEASURABLE"; }
  mkdir -p "$work/scripts/gates/fixtures/alpha/bad" "$work/scripts/gates/fixtures/alpha/good"
  : > "$work/scripts/gates/fixtures/alpha/bad/1-broken.json"
  : > "$work/scripts/gates/fixtures/alpha/bad/1-broken.expected"
  : > "$work/scripts/gates/fixtures/alpha/good/1-fine.json"
  local c="$work/census.json"
  printf '%s\n' '{"families":{"alpha":{"inputs":1,"assertions":1}}}' > "$c"

  out="$(count "$work" "$c")"
  case "$out" in 0\|*) : ;;
    *) rm -rf "$work"; gate_fail "self-test: a matching census returned '$out', expected 0"; return "$GATE_FAIL" ;;
  esac

  # THE DEFECT THIS GATE EXISTS FOR: a negative proof removed from the tree.
  command rm "$work/scripts/gates/fixtures/alpha/bad/1-broken.json"
  out="$(count "$work" "$c")"
  case "$out" in 1\|*RETIRED*) : ;;
    *) rm -rf "$work"; gate_fail "self-test: a retired proof returned '$out', expected 1 saying RETIRED"; return "$GATE_FAIL" ;;
  esac

  # The mirror: a proof added and the baseline left behind.
  : > "$work/scripts/gates/fixtures/alpha/bad/1-broken.json"
  : > "$work/scripts/gates/fixtures/alpha/bad/2-also-broken.json"
  out="$(count "$work" "$c")"
  case "$out" in 1\|*stale*) : ;;
    *) rm -rf "$work"; gate_fail "self-test: a stale census returned '$out', expected 1 saying stale"; return "$GATE_FAIL" ;;
  esac
  command rm "$work/scripts/gates/fixtures/alpha/bad/2-also-broken.json"

  # A whole family with no baseline: the same defect one level up, where a
  # per-family comparison would otherwise have nothing to compare against.
  mkdir -p "$work/scripts/gates/fixtures/beta/bad"
  : > "$work/scripts/gates/fixtures/beta/bad/1-broken.json"
  out="$(count "$work" "$c")"
  case "$out" in 1\|*does\ not\ name\ this\ family*) : ;;
    *) rm -rf "$work"; gate_fail "self-test: an undeclared family returned '$out', expected 1"; return "$GATE_FAIL" ;;
  esac
  command rm -rf "$work/scripts/gates/fixtures/beta"

  # A declared family deleted whole: the shape that empties the count to zero,
  # which a naive per-file comparison reads as "nothing to compare".
  command rm -rf "$work/scripts/gates/fixtures/alpha"
  out="$(count "$work" "$c")"
  case "$out" in 1\|*GONE\ from\ disk*) : ;;
    *) rm -rf "$work"; gate_fail "self-test: a deleted family returned '$out', expected 1"; return "$GATE_FAIL" ;;
  esac

  # And a missing census must be 2, never a pass: a gate whose baseline is gone
  # has not measured a clean tree, it has measured nothing.
  out="$(count "$work" "$work/does-not-exist.json")"
  case "$out" in 2\|*) : ;;
    *) rm -rf "$work"; gate_fail "self-test: a missing census returned '$out', expected 2"; return "$GATE_FAIL" ;;
  esac

  rm -rf "$work"
  return "$GATE_OK"
}

main() {
  gate_header "negative-proof-census (the negative proof may not shrink without saying so)"
  gate_scope "the count of bad/ and unmeasurable/ inputs and .expected assertions per fixture family, against scripts/gates/data/negative-proof-census.json"
  gate_out_of_scope "whether a case is real, whether an assertion is strong, or whether a family covers the rules that matter - this counts the proof, it does not judge it"

  command -v python3 >/dev/null 2>&1 || { gate_warn "python3 is not on PATH"; gate_verdict 2; return "$GATE_UNMEASURABLE"; }

  local st
  if [ "${GATE_SELFTEST:-1}" != "0" ]; then
    selftest; st=$?
    [ "$st" -eq "$GATE_OK" ] || { gate_verdict "$st"; return "$st"; }
    gate_info "self-test: a retired proof, a stale baseline, an undeclared family, a deleted family and a missing census all behave"
  else
    gate_warn "self-test SKIPPED via GATE_SELFTEST=0: the verdict cannot be 0"
    gate_verdict 2; return "$GATE_UNMEASURABLE"
  fi

  local out rc=0
  out="$(count "$ROOT" "$CENSUS")"
  while IFS='|' read -r code message; do
    [ -z "$code" ] && continue
    case "$code" in
      0) gate_info "$message" ;;
      1) gate_fail "$message"; rc=1 ;;
      *) gate_warn "$message"; [ "$rc" -eq 0 ] && rc=2 ;;
    esac
  done <<< "$out"

  case "$rc" in
    0) gate_ok "the negative proof is the size this repository says it is"; gate_verdict 0; return "$GATE_OK" ;;
    1) gate_verdict 1; return "$GATE_FAIL" ;;
    *) gate_verdict 2; return "$GATE_UNMEASURABLE" ;;
  esac
}

main
exit $?
