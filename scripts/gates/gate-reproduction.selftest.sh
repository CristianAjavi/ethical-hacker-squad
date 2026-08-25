#!/usr/bin/env bash
# Self-test for gate-reproduction.sh and the harness it drives.
#
# A reproduction harness that has only ever run against a healthy corpus is a
# harness nobody has watched fail, and its green means nothing. Each case below
# damages exactly one thing in a COPY of the corpus and demands the outcome that
# damage should produce - a 1 where the two keys contradict each other, a 2
# where the run cannot read what it needs, and a 0 on the cases that must NOT be
# flagged, because a check that fires on everything is as useless as one that
# fires on nothing.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-reproduction.sh"
HARNESS="$HERE/../bench/reproduce.py"
if [ -n "${EHS_REPO_ROOT:-}" ]; then SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then :
else SRC="$(cd "$HERE/../.." && pwd)"; fi

command -v python3 >/dev/null 2>&1 || { echo "UNMEASURED python3 is not on PATH"; exit 2; }
[ -f "$GATE" ]    || { echo "UNMEASURED the gate is missing at $GATE"; exit 2; }
[ -f "$HARNESS" ] || { echo "UNMEASURED the harness is missing at $HARNESS"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ehs-reproduction-XXXXXX")" || { echo "UNMEASURED cannot create a temporary directory"; exit 2; }
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# A private copy of the corpus. Every case mutates its own copy; the repository
# is read and never written.
build() {  # build <dir>
  mkdir -p "$1"
  cp -R "$SRC/bench" "$1/bench" 2>/dev/null || return 1
  return 0
}

check() {  # check <name> <expected-rc> <dir> [extra harness args...]
  local name="$1" want="$2" dir="$3" out rc
  shift 3
  out="$(python3 "$HARNESS" --root "$dir" "$@" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ]; then
    pass=$((pass + 1)); printf 'ok       %-46s rc=%s\n' "$name" "$rc"
  else
    fail=$((fail + 1)); printf 'FAIL     %-46s rc=%s, expected %s\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/           /' | head -4
  fi
}

edit_patch_truth() {  # edit_patch_truth <dir> <patch-id> <expected>
  python3 - "$1/bench/patch-truth.json" "$2" "$3" <<'PY'
import json, sys
path, pid, expected = sys.argv[1], sys.argv[2], sys.argv[3]
doc = json.load(open(path))
for entry in doc["patches"]:
    if entry["id"] == pid:
        entry["expected"] = expected
json.dump(doc, open(path, "w"), indent=1)
PY
}

# ---------------------------------------------------------------------------
# 1. The control. An untouched copy must come back 0, or every red below is
#    meaningless: a harness that fails on everything proves nothing.
# ---------------------------------------------------------------------------
D="$TMP/control"; build "$D" || { echo "UNMEASURED cannot copy the corpus"; exit 2; }
check "an untouched corpus is consistent" 0 "$D"

# ---------------------------------------------------------------------------
# 2. rc=1 - the two keys contradict each other, in both directions.
# ---------------------------------------------------------------------------
D="$TMP/lie-verified"; build "$D" || exit 2
edit_patch_truth "$D" "PC-02" "verified"
check "a patch key that claims a non-fix works" 1 "$D"

D="$TMP/lie-notfixed"; build "$D" || exit 2
edit_patch_truth "$D" "PC-01" "not fixed"
check "a patch key that denies a real fix" 1 "$D"

# ---------------------------------------------------------------------------
# 3. rc=1 - the planted key and the code disagree. Repairing the defect in the
#    case while the key still says it is there must be caught: this is the
#    direction that would otherwise let a corpus rot silently. The replacement
#    binary has to EXIST: pointing at an absent absolute path stops the probe
#    from running at all, which is a 2 and not the 1 this case is testing for.
# ---------------------------------------------------------------------------
D="$TMP/defect-gone"; build "$D" || exit 2
python3 - "$D/bench/cases/cli-packer/packer.py" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace(
    'subprocess.run(["uploader", bundle], check=True)',
    'subprocess.run(["/bin/echo", bundle], check=True)')
open(p, "w").write(s)
PY
check "a planted defect that is no longer there" 1 "$D"

# ---------------------------------------------------------------------------
# 4. rc=2 - the run cannot read what it needs. Never a pass.
# ---------------------------------------------------------------------------
D="$TMP/no-key"; build "$D" || exit 2
rm -f "$D/bench/reproduction/cli-packer/key.json"
check "no reproduction key" 2 "$D"

D="$TMP/no-probes"; build "$D" || exit 2
rm -f "$D/bench/reproduction/cli-packer/probes.py"
check "no probes" 2 "$D"

D="$TMP/no-case"; build "$D" || exit 2
rm -f "$D/bench/cases/cli-packer/packer.py"
check "no case to run against" 2 "$D"

D="$TMP/key-unparseable"; build "$D" || exit 2
printf '{ not json' > "$D/bench/reproduction/cli-packer/key.json"
check "a reproduction key that will not parse" 2 "$D"

D="$TMP/key-empty"; build "$D" || exit 2
printf '{"probes": {}}' > "$D/bench/reproduction/cli-packer/key.json"
check "a reproduction key that names no probe" 2 "$D"

D="$TMP/key-ghost"; build "$D" || exit 2
printf '{"probes": {"P-99": {}}}' > "$D/bench/reproduction/cli-packer/key.json"
check "a key naming a probe that does not exist" 2 "$D"

D="$TMP/patch-broken"; build "$D" || exit 2
printf 'not a diff at all\n' > "$D/bench/patches/cli-packer/PC-02.diff"
check "a patch that will not apply is not a pass" 2 "$D"

# ---------------------------------------------------------------------------
# 5. rc=0 - what must NOT be flagged. A patch declared `partially verified`
#    forces no outcome either way, so flipping the two of them between each
#    other changes nothing, and a harness that reddened here would be inventing
#    a verdict the English does not carry.
# ---------------------------------------------------------------------------
D="$TMP/partial-stays-quiet"; build "$D" || exit 2
edit_patch_truth "$D" "PC-04" "partially verified"
check "a partially verified patch forces nothing" 0 "$D"

# ---------------------------------------------------------------------------
# 6. The gate itself, not only the harness: its own exit codes.
# ---------------------------------------------------------------------------
out="$(bash "$GATE" --root "$SRC" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1)); printf 'ok       %-46s rc=0\n' "the gate signs a healthy tree"
else
  fail=$((fail + 1)); printf 'FAIL     %-46s rc=%s, expected 0\n' "the gate signs a healthy tree" "$rc"
  printf '%s\n' "$out" | sed 's/^/           /' | head -6
fi

out="$(GATE_SELFTEST=0 bash "$GATE" --root "$SRC" 2>&1)"; rc=$?
if [ "$rc" -eq 2 ]; then
  pass=$((pass + 1)); printf 'ok       %-46s rc=2\n' "a gate that skipped its self-test cannot sign"
else
  fail=$((fail + 1)); printf 'FAIL     %-46s rc=%s, expected 2\n' "a gate that skipped its self-test cannot sign" "$rc"
fi

D="$TMP/gate-red"; build "$D" || exit 2
edit_patch_truth "$D" "PC-02" "verified"
out="$(bash "$GATE" --root "$D" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ]; then
  pass=$((pass + 1)); printf 'ok       %-46s rc=1\n' "the gate reddens on a contradicting key"
else
  fail=$((fail + 1)); printf 'FAIL     %-46s rc=%s, expected 1\n' "the gate reddens on a contradicting key" "$rc"
  printf '%s\n' "$out" | sed 's/^/           /' | head -6
fi

# ---------------------------------------------------------------------------
# 7. Isolation. The environment a run uses is part of the result and not a
#    detail: a weaker sandbox than the key declares is an unmeasured run
#    wearing a green.
# ---------------------------------------------------------------------------
D="$TMP/floor-inprocess"; build "$D" || exit 2
check "running below the declared isolation floor" 2 "$D" --environment inprocess

D="$TMP/floor-subprocess"; build "$D" || exit 2
check "the declared floor itself is enough" 0 "$D" --environment subprocess

D="$TMP/floor-unknown"; build "$D" || exit 2
python3 - "$D/bench/reproduction/cli-packer/key.json" <<'FLOOR'
import json, sys
path = sys.argv[1]
doc = json.load(open(path))
doc["minimum_isolation"] = "unobtainium"
json.dump(doc, open(path, "w"), indent=1)
FLOOR
check "a floor nobody can offer" 2 "$D"

# The sandbox is asserted to deny the network. That is MEASURED here rather than
# trusted: the same few lines of Python run in both environments and only the
# sandboxed one may fail. On a machine with no sandbox-exec the case says so and
# is not counted as a pass, because an absent sandbox is not a proved one.
iso="$(python3 "$HERE/../bench/selftest_isolation.py" 2>&1)"
if printf '%s' "$iso" | grep -q '"skip"'; then
  printf 'skip     %-46s %s\n' "the sandbox denies the network" "$iso"
elif printf '%s' "$iso" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except ValueError:
    sys.exit(1)
sys.exit(0 if (d.get('subprocess') is True and d.get('seatbelt') is False) else 1)
" 2>/dev/null; then
  pass=$((pass + 1)); printf 'ok       %-46s %s\n' "the sandbox denies the network" "unsandboxed opens it, sandboxed does not"
else
  fail=$((fail + 1)); printf 'FAIL     %-46s %s\n' "the sandbox denies the network" "$iso"
fi

# ---------------------------------------------------------------------------
# 8. The five probes added for `rag-agent` and `analytics-service`, each proved
#    in the negative. Neither case ships a patch, so the cross-check has no
#    second half to catch a hollow probe: repairing the defect in a copy and
#    demanding the run turn red is the only thing standing between these and a
#    probe that always says yes.
#
#    `--case` keeps each mutation on the case it belongs to. Running all three
#    for every mutant would say nothing extra and cost three times as much.
# ---------------------------------------------------------------------------
repair() {  # repair <dir> <relative file> <needle> <replacement>
  python3 - "$1/$2" "$3" "$4" <<'REPAIR'
import sys
path, needle, replacement = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
if needle not in text:
    print(f"the mutation anchor is not in {path}", file=sys.stderr)
    raise SystemExit(3)
open(path, "w").write(text.replace(needle, replacement, 1))
REPAIR
}

D="$TMP/fix-P29"; build "$D" || exit 2
repair "$D" "bench/cases/analytics-service/app/serializers.py" \
  "    return asdict(customer)" \
  "    return {f: getattr(customer, f) for f in PUBLIC_FIELDS}" || exit 2
check "a serializer that no longer leaks" 1 "$D" --case analytics-service

D="$TMP/fix-P30"; build "$D" || exit 2
repair "$D" "bench/cases/analytics-service/app/logging_setup.py" \
  '    logger.info("request path=%s user=%s email=%s national_id=%s",
                path, user["id"], user["email"], user["national_id"])' \
  '    logger.info("request path=%s user=%s", path, user["id"])' || exit 2
check "a log line that no longer carries the data" 1 "$D" --case analytics-service

D="$TMP/fix-P32"; build "$D" || exit 2
repair "$D" "bench/cases/analytics-service/jobs/lifecycle.py" \
  '    return [
        '"'"'<script src="https://cdn.metrics.example/collect.js" data-site="acme"></script>'"'"',
        '"'"'<script src="https://ads.partner.example/px.js"></script>'"'"',
    ]' \
  '    return []' || exit 2
check "tags that are no longer rendered" 1 "$D" --case analytics-service

D="$TMP/fix-P24"; build "$D" || exit 2
repair "$D" "bench/cases/rag-agent/agent/memory.py" \
  '    data.setdefault("notes", []).append(reply)' \
  '    raise ValueError("free text is not stored")' || exit 2
check "memory that refuses free text" 1 "$D" --case rag-agent

D="$TMP/fix-P28"; build "$D" || exit 2
repair "$D" "bench/cases/rag-agent/agent/memory.py" \
  '    index.add_texts([ticket["body"]])' \
  '    index.add_texts([ticket["body"]], metadatas=[{"origin": "customer-ticket"}])' || exit 2
check "ingestion that now records an origin" 1 "$D" --case rag-agent

# And the control for the new cases: untouched, they must be quiet. Without this
# the five reds above would prove only that the harness reddens on everything.
D="$TMP/new-control-a"; build "$D" || exit 2
check "analytics-service untouched is consistent" 0 "$D" --case analytics-service

D="$TMP/new-control-r"; build "$D" || exit 2
check "rag-agent untouched is consistent" 0 "$D" --case rag-agent

# ---------------------------------------------------------------------------
# 9. The six probes for `intake-portal`, each proved in the negative.
#
#    Only one of this case's two patches targets a defect that carries a probe,
#    so the two-key cross-check catches almost nothing here. Repairing each
#    defect in a copy and demanding the run redden is what stands between these
#    probes and six functions that always say yes.
# ---------------------------------------------------------------------------
# The two secret mutants drop the literal and keep an empty default rather than
# indexing os.environ directly. Indexing raises KeyError AT IMPORT when the name
# is unset, so the module never loads and the run answers 2 - a mutant that
# prevents the measurement instead of removing the defect, which is the same
# mistake an absent binary made in section 3.
IP="bench/cases/intake-portal/app"

D="$TMP/fix-P44"; build "$D" || exit 2
repair "$D" "$IP/security.py" \
  '    if not signature:
        return False
    return True' \
  '    return hmac.compare_digest(expected, signature)' || exit 2
check "a signature check that now compares" 1 "$D" --case intake-portal

D="$TMP/fix-P45"; build "$D" || exit 2
repair "$D" "$IP/security.py" \
  'os.environ.get("PARTNER_SIGNING_KEY", "local-development-key")' \
  'os.environ.get("PARTNER_SIGNING_KEY", "")' || exit 2
check "a signing key with no literal fallback" 1 "$D" --case intake-portal

D="$TMP/fix-P46"; build "$D" || exit 2
repair "$D" "$IP/settings.py" \
  'os.environ.get("SESSION_SECRET", "change-me-in-production")' \
  'os.environ.get("SESSION_SECRET", "")' || exit 2
check "a session secret with no literal fallback" 1 "$D" --case intake-portal

D="$TMP/fix-P47"; build "$D" || exit 2
repair "$D" "$IP/settings.py" \
  'os.environ.get("VERIFY_WEBHOOK_AUDIENCE", "false")' \
  'os.environ.get("VERIFY_WEBHOOK_AUDIENCE", "true")' || exit 2
check "an audience check that defaults on" 1 "$D" --case intake-portal

D="$TMP/fix-P51"; build "$D" || exit 2
repair "$D" "$IP/audit.py" \
  '    logger.info("submission " + form_id + " rejected: " + reason)' \
  '    logger.info(json.dumps({"event": "reject", "form": form_id, "reason": reason}))' || exit 2
check "a rejection line that encodes" 1 "$D" --case intake-portal

D="$TMP/fix-P52"; build "$D" || exit 2
repair "$D" "$IP/audit.py" \
  '    logger.info("submission %s accepted for %s", form_id, submitter)' \
  '    logger.info(json.dumps({"event": "accept", "form": form_id, "by": submitter}))' || exit 2
check "a submission line that encodes" 1 "$D" --case intake-portal

# The control for this case. Without it the six reds above would prove only that
# the harness reddens whenever anything is touched.
D="$TMP/intake-control"; build "$D" || exit 2
check "intake-portal untouched is consistent" 0 "$D" --case intake-portal

printf -- '--- %s passed, %s failed ---\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
