#!/usr/bin/env bash
# scripts/gates/gate-stage-eval-floor.sh
#
# A per-stage dataset has to need the stage.
#
# WHY IT EXISTS
#   `google/mantis` shipped per-stage eval datasets at `27467b3` -- one per
#   pipeline stage, which is granularity this bench did not have. Reading them
#   is what produced this gate, and not by copying them.
#
#   Their `review_dataset.json` asks a triage stage to route six findings. The
#   case whose expected answer is `false_positive` under the rule
#   `sample_test_or_mock_code` is titled "...in mock auth provider", described
#   as "test credentials in mock authentication fixture used exclusively during
#   offline unit tests", and filed at `tests/mocks/mock_auth.py`. The rule's own
#   name is in the question three times. Across their `review` and `critic`
#   datasets a stub of **seven substrings and no model** scores **10 of 10**.
#
#   That stub proves the leak is there and is findable by a person, but its
#   keywords were chosen after reading the inputs, so it cannot be the
#   instrument. The instrument is `lib/stage_eval_floor.py`: leave-one-out
#   nearest centroid over word overlap, nothing tuned, the same code on any
#   dataset. And run blind on those two files it clears them -- at n=6 and n=4
#   there is nothing to learn from, which is exactly why it reports **2 and not
#   0** below ten cases. A floor that signs off on four cases is an instrument
#   lying upward.
#
#   Measured here, on this repository's own stage dataset, before the gate was
#   written to protect it: **wording alone sorts 14% of 14 cases, against a 43%
#   majority class** -- the words are less use than guessing the commonest
#   answer, which is the property the cases were meant to have and had never
#   been measured for.
#
# WHAT IT MEASURES
#   For every dataset in `bench/stages/probe-config.json`: whether the text the
#   stage is handed sorts the cases into their answers on its own, against a
#   ceiling of `max(majority + 0.20, 0.50)` that was written down before any
#   dataset was measured.
#
# WHAT IT DOES NOT MEASURE
#   Whether the key is right -- `gate-triage-stage.sh` re-derives that from
#   `triage.md`. Whether a case is realistic, whether the artifact compiles, or
#   whether a model gets it right. A green here says the dataset cannot be
#   answered from its own wording; it says nothing about who can answer it.
#
# Exit codes: 0 = measured and fine | 1 = measured and fails | 2 = could not measure.
#
# Usage:
#   scripts/gates/gate-stage-eval-floor.sh
#   scripts/gates/gate-stage-eval-floor.sh --root DIR
#   scripts/gates/gate-stage-eval-floor.sh --self-test
#
# Environment variables:
#   GATE_SELFTEST=0   skips the self-test; the verdict is then capped at 2.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

ROOT="$(cd "${EHS_REPO_ROOT:-$(gate_root)}" && pwd -P)"
PROBE="$SELF_DIR/lib/stage_eval_floor.py"
ONLY_SELFTEST=0
SELFTEST_SKIPPED=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --self-test) ONLY_SELFTEST=1; shift ;;
    -h|--help) sed -n '2,60p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) gate_warn "unknown argument: $1"; exit "$GATE_UNMEASURABLE" ;;
  esac
done

run_probe() {  # run_probe <config> -> "rc|message" lines
  ( cd "$1" && python3 "$PROBE" "$2" )
}

# fixture <dir> <n> <leaky|clean> -- writes a dataset of n cases with two answers.
fixture() {
  python3 - "$1" "$2" "$3" <<'PY'
import json, sys
from pathlib import Path
d, n, kind = Path(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
d.mkdir(parents=True, exist_ok=True)
cases, answers = [], []
for i in range(n):
    holds = i % 2 == 0
    if kind == "leaky":                       # the answer is spelled in the question
        text = ("this is mock test fixture scaffolding" if holds
                else "this is a live production request path")
    else:                                     # same vocabulary either way
        text = f"handler {i} reads a parameter and passes it to the store, revision {i}"
    cases.append({"finding": {"title": f"case {i}", "detail": text}})
    answers.append({"case": f"C-{i}", "answer": "HOLDS" if holds else "DOES_NOT_HOLD"})
(d / "cases.json").write_text(json.dumps({"cases": cases}), encoding="utf-8")
(d / "key.json").write_text(json.dumps({"answers": answers}), encoding="utf-8")
(d / "cfg.json").write_text(json.dumps({"datasets": [{
    "name": kind, "cases": "cases.json", "cases_at": "cases",
    "key": "key.json", "key_at": "answers",
    "fields": ["finding.title", "finding.detail"], "label": "answer"}]}), encoding="utf-8")
PY
}

selftest() {
  command -v python3 >/dev/null 2>&1 || { gate_warn "python3 is not on PATH"; return "$GATE_UNMEASURABLE"; }
  [ -f "$PROBE" ] || { gate_warn "the probe is missing: $PROBE"; return "$GATE_UNMEASURABLE"; }
  local work out
  work="$(mktemp -d)" || { gate_warn "cannot create a working directory"; return "$GATE_UNMEASURABLE"; }

  # A dataset whose wording gives the answer away must FAIL, or the gate is decoration.
  fixture "$work/leaky" 14 leaky
  out="$(run_probe "$work/leaky" cfg.json)"
  case "$out" in
    1\|*OVER\ the\ ceiling*) : ;;
    *) rm -rf "$work"; gate_fail "self-test: a dataset that spells out its answers returned '$out', expected 1"; return "$GATE_FAIL" ;;
  esac

  # ...and one whose wording does not must PASS, or the gate fails everything and means nothing.
  fixture "$work/clean" 14 clean
  out="$(run_probe "$work/clean" cfg.json)"
  case "$out" in
    0\|*under\ the\ ceiling*) : ;;
    *) rm -rf "$work"; gate_fail "self-test: a dataset with no wording tell returned '$out', expected 0"; return "$GATE_FAIL" ;;
  esac

  # Too few cases is 2, never 0. This is the case that clears a leaky competitor.
  fixture "$work/tiny" 6 leaky
  out="$(run_probe "$work/tiny" cfg.json)"
  case "$out" in
    2\|*below\ the\ pre-registered\ floor*) : ;;
    *) rm -rf "$work"; gate_fail "self-test: 6 leaky cases returned '$out', expected 2 (underpowered, not a clearance)"; return "$GATE_FAIL" ;;
  esac

  # A key that does not line up with the cases is 2, never a pass.
  python3 - "$work/leaky" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1]) / "key.json"
d = json.loads(p.read_text()); d["answers"] = d["answers"][:3]
p.write_text(json.dumps(d))
PY
  out="$(run_probe "$work/leaky" cfg.json)"
  case "$out" in
    2\|*against*) : ;;
    *) rm -rf "$work"; gate_fail "self-test: a truncated key returned '$out', expected 2"; return "$GATE_FAIL" ;;
  esac

  # An unreadable config is 2.
  printf '%s\n' '{ not json' > "$work/leaky/cfg.json"
  out="$(run_probe "$work/leaky" cfg.json)"
  case "$out" in
    2\|*) : ;;
    *) rm -rf "$work"; gate_fail "self-test: an unparseable config returned '$out', expected 2"; return "$GATE_FAIL" ;;
  esac

  rm -rf "$work"
  return "$GATE_OK"
}

main() {
  gate_header "stage-eval-floor (a per-stage dataset has to need the stage)"
  gate_scope "for every dataset in bench/stages/probe-config.json, whether its own wording sorts the cases into their answers without a model"
  gate_out_of_scope "whether the key is right (gate-triage-stage.sh), whether a case is realistic, and whether any model answers it correctly"

  if [ "${GATE_SELFTEST:-1}" != "0" ]; then
    selftest
    local st=$?
    [ "$st" -eq "$GATE_OK" ] || { gate_verdict "$st"; return "$st"; }
    gate_info "self-test: a leaky dataset fails, a clean one passes, six leaky cases report 2 rather than a clearance, and a truncated key and an unparseable config both report 2"
  else
    SELFTEST_SKIPPED=1
    gate_warn "self-test SKIPPED via GATE_SELFTEST=0: the verdict cannot be 0"
  fi

  if [ "$ONLY_SELFTEST" -eq 1 ]; then
    [ "$SELFTEST_SKIPPED" -eq 1 ] && { gate_warn "--self-test with GATE_SELFTEST=0: no test was run"; gate_verdict 2; return "$GATE_UNMEASURABLE"; }
    gate_ok "self-test passed; the repo was not audited (--self-test)"; gate_verdict 0; return "$GATE_OK"
  fi

  command -v python3 >/dev/null 2>&1 || { gate_warn "python3 is not on PATH"; gate_verdict 2; return "$GATE_UNMEASURABLE"; }
  local cfg="$ROOT/bench/stages/probe-config.json"
  [ -f "$cfg" ] || { gate_warn "no probe config at bench/stages/probe-config.json"; gate_verdict 2; return "$GATE_UNMEASURABLE"; }
  [ -f "$PROBE" ] || { gate_warn "the probe is missing: $PROBE"; gate_verdict 2; return "$GATE_UNMEASURABLE"; }

  local out rc=0
  out="$(run_probe "$ROOT" "bench/stages/probe-config.json")"
  [ -z "$out" ] && { gate_warn "the probe config lists no dataset, so nothing was measured"; gate_verdict 2; return "$GATE_UNMEASURABLE"; }
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
        gate_warn "every dataset is under its ceiling, but the self-test was skipped: I cannot sign this result"
        gate_verdict 2; return "$GATE_UNMEASURABLE"
      fi
      gate_ok "no stage dataset can be answered from its own wording"
      gate_verdict 0; return "$GATE_OK" ;;
    1) gate_verdict 1; return "$GATE_FAIL" ;;
    *) gate_verdict 2; return "$GATE_UNMEASURABLE" ;;
  esac
}

main
exit $?
