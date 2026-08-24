#!/usr/bin/env bash
# Tests scripts/gh/battery-detects.sh on a throwaway repository holding two
# batteries: one that detects its gate and one that does not.
#
# The hollow one is not invented. It is the shape found in this repository: a
# battery whose every case asserts rc=0, which a gate replaced by `exit 0`
# satisfies. Fourteen of fifteen real batteries went red under that mutation
# and one stayed green.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

SP="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd -- "$SP/../../.." && pwd -P)"
TOOL="$ROOT/scripts/gh/battery-detects.sh"
[ -f "$TOOL" ] || { echo "  COULD NOT MEASURE: battery-detects.sh is missing (rc 2)"; exit 2; }
command -v git >/dev/null 2>&1 || { echo "  COULD NOT MEASURE: git is missing (rc 2)"; exit 2; }

LAB="$(mktemp -d)"; trap 'rm -rf "$LAB"' EXIT
pass=0; fail=0
G() { git -C "$1" -c user.email=t@e -c user.name=t "${@:2}"; }

build_repo() {  # <dir>
  local d="$1"
  mkdir -p "$d/scripts/gates/lib" "$d/scripts/gh"
  cp "$ROOT/scripts/gates/lib/common.sh" "$d/scripts/gates/lib/"
  cp "$TOOL" "$d/scripts/gh/battery-detects.sh"

  # gate-a: says 1 when a marker file is present. Its battery checks BOTH
  # verdicts, so a hollow gate-a fails it.
  cat > "$d/scripts/gates/gate-a.sh" <<'GA'
#!/usr/bin/env bash
[ -f "${EHS_A_TARGET:-/nonexistent}" ] && exit 1
exit 0
GA
  cat > "$d/scripts/gates/gate-a.selftest.sh" <<'GAT'
#!/usr/bin/env bash
H="$(cd "$(dirname "$0")" && pwd -P)"; T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
rc=0; EHS_A_TARGET=/nonexistent bash "$H/gate-a.sh" || rc=$?; [ "$rc" -eq 0 ] || exit 1
: > "$T/marker"
rc=0; EHS_A_TARGET="$T/marker" bash "$H/gate-a.sh" || rc=$?; [ "$rc" -eq 1 ] || exit 1
exit 0
GAT

  # gate-b: the same gate. Its battery only ever asserts rc=0 - the hollow
  # shape - so `exit 0` sails through it.
  cp "$d/scripts/gates/gate-a.sh" "$d/scripts/gates/gate-b.sh"
  cat > "$d/scripts/gates/gate-b.selftest.sh" <<'GBT'
#!/usr/bin/env bash
H="$(cd "$(dirname "$0")" && pwd -P)"
rc=0; EHS_A_TARGET=/nonexistent bash "$H/gate-b.sh" || rc=$?; [ "$rc" -eq 0 ] || exit 1
exit 0
GBT

  chmod +x "$d"/scripts/gates/*.sh "$d/scripts/gh/battery-detects.sh"
  git -C "$d" init -q -b main; G "$d" add -A; G "$d" commit -qm base
}

res() {  # <label> <got> <want> [needle]
  local label="$1" got="$2" want="$3" needle="${4:-}"
  if [ "$got" = "$want" ] && { [ -z "$needle" ] || grep -qi -- "$needle" "$LAB/out.txt"; }; then
    printf '  PASS  %-50s rc=%s\n' "$label" "$got"; pass=$((pass+1))
  else
    printf '  FAIL  %-50s rc=%s (expected %s)\n' "$label" "$got" "$want"
    sed 's/^/        | /' "$LAB/out.txt" | tail -10; fail=$((fail+1))
  fi
}

run() {  # <repo> <args...>
  local d="$1"; shift
  ( cd "$d" && EHS_REPO_ROOT="$d" bash "$d/scripts/gh/battery-detects.sh" "$@" >"$LAB/out.txt" 2>&1 ); echo $?
}

echo "== battery-detects.sh on a throwaway repository"

d="$LAB/repo"; build_repo "$d"
res "a hollow battery is found -> rc 1" "$(run "$d" )" 1 "measures nothing"
res "and it is named" "$( grep -c 'gate-b.selftest.sh' "$LAB/out.txt" )" 1
res "the battery that detects is not accused" "$( grep -c 'gate-a.selftest.sh is GREEN' "$LAB/out.txt" )" 0

# Only the good pair: nothing to report.
d2="$LAB/good"; build_repo "$d2"
rm -f "$d2/scripts/gates/gate-b.sh" "$d2/scripts/gates/gate-b.selftest.sh"
G "$d2" add -A; G "$d2" commit -qm drop-b
res "every battery detects -> rc 0" "$(run "$d2")" 0 "goes red when its gate stops measuring"

# A battery that is red on its own gate is UNMEASURABLE, never credited as
# "detects": without the control run, a broken battery would score as a good one.
d3="$LAB/broken"; build_repo "$d3"
printf '#!/usr/bin/env bash\nexit 1\n' > "$d3/scripts/gates/gate-a.selftest.sh"
rm -f "$d3/scripts/gates/gate-b.sh" "$d3/scripts/gates/gate-b.selftest.sh"
G "$d3" add -A; G "$d3" commit -qm break-a
res "a battery red on its own gate -> rc 2" "$(run "$d3")" 2 "not green on its own gate"

echo
echo "  $pass PASS / $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
exit 0
