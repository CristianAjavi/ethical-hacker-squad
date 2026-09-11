#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-alert-live.sh — every open Dependabot alert has to be somewhere this
# repository declared in advance that an alert is expected.
#
# WHY IT EXISTS
#   gate-alert-surface.sh measures the INVENTORY on disk: that every dependency
#   manifest is declared, managed and described truthfully. It says so in its own
#   header that it does not read what GitHub currently reports, and it is right
#   not to: a COUNT moves when an upstream advisory is published and nobody here
#   did anything, and a gate that goes red for a reason no change caused gets
#   switched off.
#
#   That leaves a hole with a name. On 2026-09-11 this repository had five open
#   alerts. Whether all five sat on bench fixtures - manifests that carry
#   deliberately vulnerable dependencies as the answer key of the benchmark - or
#   whether one of them sat on code the plugin actually ships was answered by a
#   person running `gh api` by hand and writing the result in a report. Nothing
#   executable would have noticed the day that stopped being true. A real alert
#   on `tooling/claude-cli` would have arrived through the same channel, looking
#   the same, next to four fixtures.
#
# WHAT IT MEASURES
#   The LOCATION of every open alert, never the number of them:
#     1. every open alert sits on a manifest that scripts/gates/data/alert-surface.json
#        declares with `alerts_allowed: true` and a written reason;
#     2. an alert on a manifest declared `alerts_allowed: false` FAILS - that is
#        an alert on code this repository ships;
#     3. an alert on a path the surface file does not declare at all FAILS -
#        approval by omission is how the previous hole was opened.
#   The count is free to move in either direction: publish an advisory against a
#   fixture tomorrow and this gate stays green, because the fixture was declared.
#
# HOW IT REFUSES TO BE BLIND
#   Three ways this measurement can come back empty without being true, each one
#   answered with 2 and the cause named, never with a pass:
#     - the alerts feature is off, or the token cannot see it: the enablement
#       probe `repos/{slug}/vulnerability-alerts` answers 204 when alerts are on;
#       anything else is blindness, not cleanliness;
#     - the API answers something that is not a JSON list;
#     - no alert of ANY state has ever been reported here. A zero from an
#       instrument nobody has seen produce a one is not a measurement. This
#       repository plants vulnerable dependencies on purpose, so a total of zero
#       means the query is not looking where it thinks it is.
#   And the query deliberately sends NO `state=` filter. Measured on 2026-09-11:
#   `state=all` returns `[]`, and so does `state=bogus` - the endpoint answers an
#   empty list to a malformed question, which is a silent way to report a clean
#   repository. The states are filtered here, on a payload we have counted.
#
# WHAT IT DOES NOT MEASURE
#   Whether an alert is exploitable, and whether it should be dismissed. It reads
#   `state` as GitHub reports it: an alert a human dismissed is not open and this
#   gate says nothing about that decision. It does not open, close or dismiss
#   anything - it is read-only against the API.
#
# WHY IT IS DEFERRED IN CI
#   It reads the live repository, so run-all.sh lists it in LIVE_SCOPED and
#   declares it BY NAME as not run unless EHS_LIVE_REPO=1 with an authenticated
#   gh. Whether a workflow's GITHUB_TOKEN can read Dependabot alerts at all was
#   NOT measured here; turning it on in CI is a measurement someone still has to
#   make, and this paragraph is where its absence is recorded rather than left
#   as a silent hole.
#
# Usage:
#   EHS_LIVE_REPO=1 scripts/gates/gate-alert-live.sh [--slug OWNER/REPO]
#   scripts/gates/gate-alert-live.sh --self-test     # no network, stubbed gh
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, no gh, not authenticated, alerts off, unusable payload).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"
ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
SURFACE="$HERE/data/alert-surface.json"
GH="${EHS_GH:-gh}"
SLUG="${EHS_REPO_SLUG:-}"
ONLY_SELFTEST=0

while [ $# -gt 0 ]; do
  case "$1" in
    --slug)      SLUG="${2:-}"; shift 2 ;;
    --surface)   SURFACE="${2:-}"; shift 2 ;;
    --self-test) ONLY_SELFTEST=1; shift ;;
    -h|--help)   sed -n '2,70p' "$0"; exit 0 ;;
    *)           shift ;;
  esac
done

# classify <surface.json> <alerts.json> -> "rc|message" lines
classify() {
  python3 - "$1" "$2" <<'PY'
import json, pathlib, sys

surface_path, alerts_path = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])

def out(rc, msg):
    print(f"{rc}|{msg}")

try:
    surface = json.loads(surface_path.read_text())
    by_path = {e["path"]: e for e in surface["manifests"]}
except Exception as exc:
    out(2, f"{surface_path} is missing or unusable ({exc}): nothing was classified")
    raise SystemExit

try:
    payload = json.loads(alerts_path.read_text())
except Exception as exc:
    out(2, f"the alerts payload did not parse as JSON ({exc}): that is the API "
           f"or the credential answering, not a repository with no alerts")
    raise SystemExit

if not isinstance(payload, list):
    out(2, f"the alerts endpoint answered a {type(payload).__name__}, not a list. "
           f"An error body reads as 'no alerts' to anything that only checks length")
    raise SystemExit

if not payload:
    out(2, "no alert of ANY state has ever been reported for this repository. This "
           "repository plants vulnerable dependencies on purpose, so a total of zero "
           "is an instrument nobody has seen produce a one - not a clean repository")
    raise SystemExit

open_alerts = [a for a in payload if a.get("state") == "open"]
fails = 0

for a in sorted(open_alerts, key=lambda x: x.get("number", 0)):
    dep = a.get("dependency") or {}
    pkg = (dep.get("package") or {}).get("name", "?")
    eco = (dep.get("package") or {}).get("ecosystem", "?")
    mp = dep.get("manifest_path")
    sev = (a.get("security_advisory") or {}).get("severity", "?")
    num = a.get("number", "?")
    if not mp:
        out(1, f"alert #{num} ({sev} {eco}:{pkg}) reports no manifest path, so it "
               f"cannot be placed against the declared surface")
        fails += 1
        continue
    entry = by_path.get(mp)
    if entry is None:
        out(1, f"alert #{num} ({sev} {eco}:{pkg}) is on {mp}, which "
               f"{surface_path.name} does not declare AT ALL. Approval by omission is "
               f"exactly how the last hole was opened: a manifest nobody listed")
        fails += 1
        continue
    if entry.get("alerts_allowed") is not True:
        out(1, f"alert #{num} ({sev} {eco}:{pkg}) is on {mp}, declared role="
               f"{entry.get('role','?')} with alerts_allowed="
               f"{json.dumps(entry.get('alerts_allowed'))}. This is an alert on code "
               f"this repository SHIPS, sitting in the same channel as the fixtures")
        fails += 1
        continue
    out(0, f"#{num} {sev:<8} {eco}:{pkg}  on {mp}")
    out(0, f"    expected here: {entry.get('alerts_why','(no reason declared)')}")

out(0, f"measured: {len(payload)} alert(s) of all states, {len(open_alerts)} open, "
       f"{fails} on a manifest that was not declared to expect one")
if not open_alerts:
    out(0, "zero OPEN alerts, and this is a measured zero: the feature answers 204 "
           "and this query does report alerts for this repository")
PY
}

selftest() {
  command -v python3 >/dev/null 2>&1 || { echo "  UNMEASURABLE python3 is missing"; return 2; }
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/ehs-alert-live-XXXXXX")"
  local p=0 f=0

  # A stubbed gh, because the point of these cases is what this gate DOES with an
  # answer, and a case that needs the network measures the network.
  mkdir -p "$tmp/bin"
  cat > "$tmp/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  *auth*status*)            exit "${STUB_AUTH_RC:-0}" ;;
  *vulnerability-alerts*)   printf '%s\n' "${STUB_PROBE:-HTTP/2.0 204 No Content}"; exit "${STUB_PROBE_RC:-0}" ;;
  *dependabot/alerts*)      cat "$STUB_ALERTS"; exit "${STUB_ALERTS_RC:-0}" ;;
  *)                        exit 1 ;;
esac
STUB
  chmod +x "$tmp/bin/gh"

  cat > "$tmp/surface.json" <<'SF'
{"manifests":[
  {"path":"bench/cases/node-supply/package.json","role":"bench-fixture","alerts_allowed":true,
   "alerts_why":"the answer key of the benchmark: this dependency is vulnerable on purpose"},
  {"path":"tooling/cli/package.json","role":"product","alerts_allowed":false}]}
SF

  alert() {  # <number> <state> <path> [severity]
    printf '{"number":%s,"state":"%s","dependency":{"manifest_path":"%s","package":{"ecosystem":"npm","name":"lodahs"}},"security_advisory":{"severity":"%s"}}' \
      "$1" "$2" "$3" "${4:-high}"
  }

  run_case() {  # <name> <expected rc> <needle> <alerts-json> [probe-line]
    local name="$1" want="$2" needle="$3" body="$4" probe="${5:-HTTP/2.0 204 No Content}"
    printf '%s' "$body" > "$tmp/alerts.json"
    local out rc=0
    # The whole gate is exercised, not just its python: a case that called
    # classify() directly would never see the probe, the auth check or the wiring
    # between them - which is where three of these five failures live.
    out="$(PATH="$tmp/bin:$PATH" EHS_GH="$tmp/bin/gh" STUB_ALERTS="$tmp/alerts.json" \
           STUB_PROBE="$probe" EHS_REPO_SLUG="o/r" EHS_LIVE_REPO=1 GATE_SELFTEST=0 \
           bash "$0" --surface "$tmp/surface.json" 2>&1)" || rc=$?
    if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
      printf '  PASS  %-52s rc=%s\n' "$name" "$rc"; p=$((p+1))
    else
      printf '  FAIL  %-52s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
      printf '%s\n' "$out" | sed 's/^/        /' | tail -4; f=$((f+1))
    fi
  }

  echo "  == an alert where one was declared to be expected =="
  run_case "on a declared fixture" 0 "expected here:" \
    "[$(alert 1 open bench/cases/node-supply/package.json)]"

  echo "  == the two shapes this gate exists to catch =="
  run_case "on code the repository SHIPS" 1 "repository SHIPS" \
    "[$(alert 2 open tooling/cli/package.json)]"
  run_case "on a path nobody declared" 1 "does not declare AT ALL" \
    "[$(alert 3 open services/api/requirements.txt)]"
  # And it must not blame a fixture for an alert somebody already dismissed.
  run_case "a dismissed alert on shipped code is not open" 0 "1 alert(s) of all states, 0 open" \
    "[$(alert 4 dismissed tooling/cli/package.json)]"

  echo "  == the ways of being blind, each one a 2 and not a pass =="
  run_case "the alerts feature is off" 2 "blindness, not cleanliness" "[]" "HTTP/2.0 404 Not Found"
  run_case "the endpoint answered an error object" 2 "not a list" '{"message":"Bad credentials"}'
  run_case "the payload is not JSON at all" 2 "did not parse as JSON" 'gh: could not resolve host'
  run_case "no alert of any state, ever" 2 "instrument nobody has seen produce a one" "[]"

  command rm -rf "$tmp"
  echo "  $p PASS / $f FAIL"
  [ "$f" -eq 0 ] || return 1
  return 0
}

if [ "$ONLY_SELFTEST" -eq 1 ]; then
  selftest; exit $?
fi

gate_header "alert-live (an open alert has to be somewhere we said an alert was expected)"
gate_scope "every OPEN Dependabot alert of this repository, placed against scripts/gates/data/alert-surface.json"
gate_out_of_scope "how MANY alerts there are - that number moves when an advisory is published and no change here caused it - and whether any of them is exploitable"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was checked"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

if [ "${GATE_SELFTEST:-1}" != "0" ]; then
  echo "== self-test: this gate, proved in the negative =="
  if ! selftest; then
    gate_warn "the gate does NOT pass its own self-test; any result over the live repository would be indefensible"
    gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
  fi
fi

echo "== the live repository =="
if ! command -v "$GH" >/dev/null 2>&1 && [ ! -x "$GH" ]; then
  gate_warn "gh is not installed: the live alerts were NOT read (this is not zero alerts)"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
if ! "$GH" auth status >/dev/null 2>&1; then
  gate_warn "gh is not authenticated: the live alerts were NOT read (this is not zero alerts)"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

if [ -z "$SLUG" ]; then
  SLUG="$(git -C "$ROOT" remote get-url origin 2>/dev/null \
          | sed -e 's#^git@github.com:##' -e 's#^https://github.com/##' -e 's#\.git$##')"
fi
if [ -z "$SLUG" ]; then
  gate_warn "no owner/repo could be resolved: pass --slug or set EHS_REPO_SLUG"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi
gate_info "repository: $SLUG"

PROBE="$("$GH" api -i "repos/$SLUG/vulnerability-alerts" 2>/dev/null | head -1)"
case "$PROBE" in
  *204*) gate_info "Dependabot alerts are ENABLED here (the probe answers 204)" ;;
  *)     gate_warn "the enablement probe answered '${PROBE:-nothing}', not 204: alerts are off or this token cannot see them. An empty answer from here is blindness, not cleanliness"
         gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE" ;;
esac

TMPD="$(mktemp -d "${TMPDIR:-/tmp}/ehs-alert-live-run-XXXXXX")"
trap 'command rm -rf "$TMPD"' EXIT
# NO state= filter on purpose. Measured 2026-09-11: `state=all` and any invalid
# value answer `[]`, so a filter is a way for this query to report a clean
# repository by asking the wrong question. The states are filtered in classify().
if ! "$GH" api "repos/$SLUG/dependabot/alerts?per_page=100" --paginate > "$TMPD/alerts.json" 2>"$TMPD/err"; then
  gate_warn "the alerts API call failed: $(head -1 "$TMPD/err" 2>/dev/null). The alerts were NOT read"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

RC=0
while IFS= read -r line; do
  code="${line%%|*}"; msg="${line#*|}"
  case "$code" in
    0) [ -n "$msg" ] && echo "· $msg" ;;
    1) gate_fail "$msg"; RC=1 ;;
    2) gate_warn "$msg"; [ "$RC" -eq 1 ] || RC=2 ;;
  esac
done < <(classify "$SURFACE" "$TMPD/alerts.json")

gate_verdict "$RC"
exit "$RC"
