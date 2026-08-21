#!/usr/bin/env bash
set -uo pipefail
SP="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WT="$(cd -- "$SP/../../.." && pwd)"
SP="$(mktemp -d)"; trap 'rm -rf "$SP"' EXIT
PASS=0; FAIL=0
command -v python3 >/dev/null || { echo "  ABORT: python3 is missing (rc 2)"; exit 2; }
res() { if [ "$2" = "$3" ]; then printf '  PASS  %-52s rc=%s\n' "$1" "$2"; PASS=$((PASS+1));
        else printf '  FAIL  %-52s rc=%s (expected %s)\n' "$1" "$2" "$3"; FAIL=$((FAIL+1)); fi; }

# The rc rules of the gate runner used to be tested here AND in
# test-gates-loop.sh, both by extracting the loop out of promote-stable.yml.
# That workflow is gone (two workflows were promoting to stable) and the loop
# now lives in scripts/gates/run-all.sh. Keeping two copies of the same suite
# meant two places to update and one of them silently rotting, so the runner is
# covered in exactly one place: test-gates-loop.sh. This file keeps what is
# unique to it, the negative paths of apply-governance.sh.
echo "== The gate runner is covered by test-gates-loop.sh (not duplicated here)"

echo ""
echo "== apply-governance.sh: negative paths"
G="$WT/scripts/gh/apply-governance.sh"

"$G" --help >/dev/null 2>&1; res "--help -> rc 0" "$?" 0

# Hermetic: a gh session of ANOTHER account is simulated. This Mac has several
# gh accounts and acting with the wrong one is a known and expensive mistake;
# the guard has to fire before touching anything.
FB0="$SP/fakebin0"; mkdir -p "$FB0"
printf '#!/usr/bin/env bash\necho other-user\n' >"$FB0/gh"; chmod +x "$FB0/gh"
OUT=$(PATH="$FB0:$PATH" "$G" --no-color 2>&1); RC=$?
res "wrong gh account -> rc 2 (aborts before reading anything)" "$RC" 2
case "$OUT" in
  *"gh auth switch"*) echo "        (the message carries the exact fix command)" ;;
  *) echo "        FAIL: the message does not say how to fix it"; FAIL=$((FAIL+1)) ;;
esac
case "$OUT" in
  *DRIFT*|*APPLIED*) echo "        FAIL: it kept working with the wrong account"; FAIL=$((FAIL+1)) ;;
  *) echo "        (it never got to compare or mutate anything)" ;;
esac

printf '#!/usr/bin/env bash\nexit 1\n' >"$FB0/gh"
PATH="$FB0:$PATH" "$G" >/dev/null 2>&1; res "no usable gh session -> rc 2" "$?" 2

echo 'not json at all' >"$SP/bad.json"
"$G" --state "$SP/bad.json" >/dev/null 2>&1; res "corrupt desired state -> rc 2" "$?" 2
"$G" --state "$SP/does-not-exist.json" >/dev/null 2>&1; res "missing desired state -> rc 2" "$?" 2
"$G" --made-up-flag >/dev/null 2>&1; res "unknown argument -> rc 2" "$?" 2

# without jq on the PATH: I cannot compare -> rc 2, never 0
FB="$SP/fakebin2"; mkdir -p "$FB"
for t in gh git bash sed grep find sort mktemp rm cat tr printf date; do
  p=$(command -v "$t" 2>/dev/null) && ln -sf "$p" "$FB/$t" 2>/dev/null || true
done
env PATH="$FB" "$G" >/dev/null 2>&1; res "no jq on the PATH -> rc 2" "$?" 2

# This one does hit the network and the real gh session: explicit opt-in.
if [ "${GOV_TESTS_NETWORK:-0}" = "1" ]; then
  "$G" --discover-contexts >/dev/null 2>&1; res "--discover-contexts -> rc 0 and no mutation" "$?" 0
else
  echo "  SKIP  --discover-contexts (needs network + gh session; GOV_TESTS_NETWORK=1 to run it)"
fi

echo ""
echo "  $PASS PASS / $FAIL FAIL"
[ "$FAIL" -eq 0 ] || exit 1
