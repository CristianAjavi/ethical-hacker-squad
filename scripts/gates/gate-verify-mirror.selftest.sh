#!/usr/bin/env bash
# scripts/gates/gate-verify-mirror.selftest.sh
#
# Proves gate-verify-mirror.sh in the negative. A gate that has never been seen
# to fail is a gate nobody has measured, and this one is a comparison between
# two lists - the failure mode is that both sides are read as empty and equal.
#
# Every case builds a throwaway workflow and a throwaway mirror script, so the
# gate is exercised end to end through --workflow/--script and not only through
# its Python core.
set -uo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SELF_DIR/gate-verify-mirror.sh"
LAB="$(mktemp -d)"; trap 'rm -rf "$LAB"' EXIT
PASS=0; FAIL=0

mk_workflow() { # file, steps...
  local f="$1"; shift
  {
    echo "name: CI"
    echo "on: [push]"
    echo "jobs:"
    echo "  build:"
    echo "    name: workflow-hardening"
    echo "    steps:"
    echo "      - name: something else"
    echo "        run: ./scripts/not-the-job.sh"
    echo "  g:"
    echo "    name: gates"
    echo "    steps:"
    local n=0
    for s in "$@"; do
      n=$((n+1))
      echo "      - name: step $n"
      echo "        run: $s"
    done
  } >"$f"
}

mk_script() { # file, steps...
  local f="$1"; shift
  {
    echo '#!/usr/bin/env bash'
    echo 'if [ "${1:-}" = "--list" ]; then'
    for s in "$@"; do printf "  printf '%%s\\\\n' %s\n" "\"$s\""; done
    echo '  exit 0'
    echo 'fi'
    echo 'exit 0'
  } >"$f"
  chmod +x "$f"
}

probe() { # name, expected_rc, workflow, script, [job]
  local name="$1" want="$2" wf="$3" sc="$4" job="${5:-gates}" out rc
  out=$(GATE_SELFTEST=0 "$GATE" --workflow "$wf" --script "$sc" --job "$job" 2>&1); rc=$?
  # GATE_SELFTEST=0 caps a would-be 0 at 2 - the gate refuses to certify while
  # unproved - so "agrees" cannot be asserted by rc alone. It is asserted as the
  # cap PLUS zero findings, which is what separates a capped pass from a 2 the
  # blind-spot cases below produce by breaking the measurement outright.
  if [ "$want" = "0" ]; then
    if [ "$rc" = "2" ] && ! printf '%s\n' "$out" | grep -q '^FAIL'; then
      printf '  PASS  %-58s rc=2 (capped, and it found nothing)\n' "$name"; PASS=$((PASS+1)); return
    fi
  elif [ "$rc" = "$want" ]; then
    printf '  PASS  %-58s rc=%s\n' "$name" "$rc"; PASS=$((PASS+1)); return
  fi
  printf '  FAIL  %-58s rc=%s (expected %s)\n' "$name" "$rc" "$want"
  printf '%s\n' "$out" | sed 's/^/        | /' | tail -12
  FAIL=$((FAIL+1))
}

says() { # name, needle, workflow, script
  local out
  out=$(GATE_SELFTEST=0 "$GATE" --workflow "$3" --script "$4" 2>&1)
  if printf '%s' "$out" | grep -qF "$2"; then
    printf '  PASS  %-58s\n' "$1"; PASS=$((PASS+1))
  else
    printf '  FAIL  %-58s (never said %s)\n' "$1" "$2"; FAIL=$((FAIL+1))
  fi
}

echo "== the agreeing case, so rc 0 is reachable"
mk_workflow "$LAB/ok.yml"  "./a.sh --list" "./a.sh --skip 'x'" "./b.sh"
mk_script   "$LAB/ok.sh"   "./a.sh --list" "./a.sh --skip 'x'" "./b.sh"
probe "identical lists in identical order" 0 "$LAB/ok.yml" "$LAB/ok.sh"

echo ""
echo "== the defect of 2026-09-02: a runner CI runs and nothing local does"
mk_script "$LAB/short.sh" "./a.sh --list" "./a.sh --skip 'x'"
probe "CI has a step the mirror omits" 1 "$LAB/ok.yml" "$LAB/short.sh"
says  "it names the omitted command" "./b.sh" "$LAB/ok.yml" "$LAB/short.sh"

echo ""
echo "== and the other direction, which is how a mirror rots quietly"
mk_script "$LAB/long.sh" "./a.sh --list" "./a.sh --skip 'x'" "./b.sh" "./c.sh"
probe "the mirror runs a step CI does not" 1 "$LAB/ok.yml" "$LAB/long.sh"
says  "it names the invented command" "./c.sh" "$LAB/ok.yml" "$LAB/long.sh"

echo ""
echo "== a paraphrase is not a mirror"
mk_script "$LAB/para.sh" "./a.sh --list" "./a.sh" "./b.sh"
probe "the same runner without its flags" 1 "$LAB/ok.yml" "$LAB/para.sh"

echo ""
echo "== order, because an inventory after the run is a different check"
mk_script "$LAB/ord.sh" "./a.sh --skip 'x'" "./a.sh --list" "./b.sh"
probe "same steps, swapped order" 1 "$LAB/ok.yml" "$LAB/ord.sh"

echo ""
echo "== two empty lists must not read as a match"
mk_workflow "$LAB/empty.yml"
mk_script   "$LAB/empty.sh"
probe "CI job with no run: step is UNMEASURABLE" 2 "$LAB/empty.yml" "$LAB/empty.sh"
probe "a mirror that names no step is UNMEASURABLE" 2 "$LAB/ok.yml" "$LAB/empty.sh"

echo ""
echo "== the instrument's own blind spots, made loud"
probe "an absent workflow is 2, not a clean field" 2 "$LAB/nope.yml" "$LAB/ok.sh"
probe "a job name that matches nothing is 2" 2 "$LAB/ok.yml" "$LAB/ok.sh" "no-such-job"
printf '#!/usr/bin/env bash\nexit 3\n' >"$LAB/broken.sh"; chmod +x "$LAB/broken.sh"
probe "a mirror whose --list fails is 2" 2 "$LAB/ok.yml" "$LAB/broken.sh"
printf 'not executable\n' >"$LAB/noexec.sh"
probe "a mirror that is not executable is 2" 2 "$LAB/ok.yml" "$LAB/noexec.sh"

echo ""
echo "== it must read the RIGHT job, not the first one it finds"
# ok.yml declares a job BEFORE the gates one, with a step of its own. A parser
# that took the first job it saw would accept this mirror; the gate must reject
# every one of the three steps it is missing and the one it invented.
mk_script "$LAB/wrongjob.sh" "./scripts/not-the-job.sh"
probe "the other job's steps do not satisfy it" 1 "$LAB/ok.yml" "$LAB/wrongjob.sh"
says  "it names the step that belongs to the other job" "./scripts/not-the-job.sh" \
      "$LAB/ok.yml" "$LAB/wrongjob.sh"

echo ""
echo "  $PASS PASS / $FAIL FAIL"
[ "$FAIL" -eq 0 ] || exit 1
