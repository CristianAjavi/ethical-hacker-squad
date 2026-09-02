#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-alert-surface.sh — the file that tells you how to read an alert has to be
# right about what this repository contains.
#
# WHY IT EXISTS
#   .github/dependabot.yml carries a comment written to stop exactly one failure:
#   "do not let a real alert hide behind the assumption that every npm finding
#   here is a fixture." On 2026-09-01 the five open alerts on the default branch
#   were measured against it. All three of that comment's factual claims were
#   false:
#
#     - "There is no requirements.txt" — bench/cases/intake-portal/requirements.txt
#       had been added afterwards and produces THREE of the five alerts. A claim
#       of absence does not age; the tree does.
#     - "makes GitHub report those two — one high, one low" — the real figure is
#       five: one high, two medium, two low.
#     - "the express pin is deliberately old" — `express` appears in no planted
#       entry and no decoy in bench/ground-truth.json. That alert is incidental.
#
#   One of five is ground truth. The document that existed to prevent a real
#   alert hiding behind a fixture had become the hiding place, and nothing read
#   it. This is the same class as gate-budget-ledger, one level up: not a number
#   that moved behind its sentence, an INVENTORY that did.
#
# WHAT IT MEASURES
#   1. completeness  every dependency manifest on disk is named in
#                    scripts/gates/data/alert-surface.json. The omission hole is
#                    closed by enumerating the SOURCE - a manifest nobody
#                    declared is what happened here, and a list that only holds
#                    what someone remembered cannot see it.
#   2. no dangling   every declared path still exists.
#   3. management    `managed: true` iff .github/dependabot.yml has an `updates`
#                    block whose ecosystem and directory cover it. Both
#                    directions: a block for a manifest declared unmanaged is a
#                    bot opening pull requests against a bench fixture.
#   4. justification every `managed: false` carries a non-empty `why`.
#   5. absences      every pattern in `absences_asserted` - a thing the config's
#                    prose claims this repository does not contain - genuinely
#                    matches nothing. This is check 5 because it is the one that
#                    was already red.
#   6. answer key    the `planted` and `decoys` symbols declared for a fixture
#                    manifest are exactly what bench/ground-truth.json plants
#                    there. Both directions. This is what catches a manifest
#                    described as carrying ground truth when it carries none.
#
# WHAT IT DOES NOT MEASURE, and will not pretend to
#   How many alerts GitHub currently reports. That number moves when an upstream
#   advisory is published and nobody here did anything; a gate that tracked it
#   would go red for a reason no change caused, and a gate that cries at the
#   world gets ignored the same way the alert channel did. It also cannot read
#   the PROSE of dependabot.yml: it enforces the absence claims that were
#   transcribed into the data file, so a claim added to the comment and not
#   copied across stays invisible. Manifests under .git, node_modules, dist and
#   build are pruned and not seen.
#
# Usage:
#   scripts/gates/gate-alert-surface.sh [--root DIR] [--surface FILE]
#   scripts/gates/gate-alert-surface.sh --self-test
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, no PyYAML, a missing or unusable data file, config or key).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"
ROOT="${EHS_REPO_ROOT:-$(gate_root)}"
SURFACE="$HERE/data/alert-surface.json"
ONLY_SELFTEST=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root)      ROOT="${2:-}"; shift 2 ;;
    --surface)   SURFACE="${2:-}"; shift 2 ;;
    --self-test) ONLY_SELFTEST=1; shift ;;
    -h|--help)   sed -n '2,60p' "$0"; exit 0 ;;
    *)           shift ;;
  esac
done

measure() {
  python3 - "$1" "$2" <<'PY'
import json, sys, pathlib

root = pathlib.Path(sys.argv[1])
surface_path = pathlib.Path(sys.argv[2])

def out(rc, msg):
    print(f"{rc}|{msg}")

# filename -> the ecosystem Dependabot calls it
ECOSYSTEM = {
    "package.json": "npm", "package-lock.json": "npm", "yarn.lock": "npm",
    "requirements.txt": "pip", "pyproject.toml": "pip", "Pipfile": "pip",
    "Pipfile.lock": "pip", "setup.py": "pip",
    "go.mod": "gomod", "Gemfile": "bundler", "Gemfile.lock": "bundler",
    "pom.xml": "maven", "build.gradle": "gradle", "Cargo.toml": "cargo",
    "composer.json": "composer", "Dockerfile": "docker",
}
PRUNE = {".git", "node_modules", "dist", "build", ".venv", "vendor"}

try:
    import yaml
except ImportError:
    out(2, "the PyYAML module is missing (pip install pyyaml): the dependabot config was not parsed")
    raise SystemExit

try:
    surface = json.loads(surface_path.read_text(encoding="utf-8"))
    declared = surface["manifests"]
    absences = surface.get("absences_asserted") or []
    if not isinstance(declared, list) or not declared:
        raise ValueError("`manifests` is not a non-empty list")
except (OSError, ValueError, KeyError) as exc:
    out(2, f"the surface file is missing or unusable ({surface_path}): {exc}")
    raise SystemExit

cfg_path = root / ".github" / "dependabot.yml"
try:
    cfg = yaml.safe_load(cfg_path.read_text(encoding="utf-8")) or {}
    updates = cfg.get("updates") or []
    if not isinstance(updates, list):
        raise ValueError("`updates` is not a list")
except (OSError, ValueError) as exc:
    out(2, f"the dependabot config is missing or unusable ({cfg_path}): {exc}")
    raise SystemExit

# --- 0. what is actually on disk -------------------------------------------
found = {}   # relpath -> ecosystem
for p in root.rglob("*"):
    if not p.is_file():
        continue
    rel = p.relative_to(root)
    if PRUNE & set(rel.parts[:-1]):
        continue
    name = p.name
    eco = ECOSYSTEM.get(name)
    if eco is None and name.startswith("requirements") and name.endswith(".txt"):
        eco = "pip"
    if eco is not None:
        found[rel.as_posix()] = eco

if not found:
    out(2, "no dependency manifest was found anywhere under the root: this check read nothing, "
           "which is not the same as finding nothing wrong")
    raise SystemExit

fails = 0
by_path = {}
for e in declared:
    if not isinstance(e, dict) or not str(e.get("path") or "").strip():
        out(1, f"an entry in {surface_path.name} has no `path`: {e!r}")
        fails += 1
        continue
    by_path[str(e["path"])] = e

# --- 1. completeness: enumerate the SOURCE ---------------------------------
for rel, eco in sorted(found.items()):
    if rel not in by_path:
        out(1, f"{rel} is a {eco} manifest on disk and appears nowhere in {surface_path.name}. A "
               f"manifest nobody declared is how an alert channel starts lying: name it, say "
               f"whether an alert on it would be real, and say who manages it")
        fails += 1
        continue
    if str(by_path[rel].get("ecosystem")) != eco:
        out(1, f"{rel}: declared ecosystem {by_path[rel].get('ecosystem')!r}, and its filename "
               f"makes it {eco!r}")
        fails += 1

# --- 2. no dangling --------------------------------------------------------
for rel in sorted(set(by_path) - set(found)):
    out(1, f"{surface_path.name} names {rel}, which is not a manifest on disk any more. A "
           f"declaration outliving its file is a rule nobody can trip and a reader can still believe")
    fails += 1

# --- 3. management, both directions ----------------------------------------
def covers(block, rel, eco):
    if str(block.get("package-ecosystem") or "") != eco:
        return False
    dirs = block.get("directories") or [block.get("directory")]
    parent = "/" + str(pathlib.PurePosixPath(rel).parent)
    parent = "/" if parent == "/." else parent
    return any(str(d).rstrip("/") in ("", parent.rstrip("/")) for d in dirs if d)

for rel, e in sorted(by_path.items()):
    if rel not in found:
        continue
    eco = found[rel]
    managed = bool(e.get("managed"))
    has_block = any(covers(b, rel, eco) for b in updates if isinstance(b, dict))
    if managed and not has_block:
        out(1, f"{rel} is declared `managed: true` and no `updates` block in "
               f".github/dependabot.yml covers it ({eco} at its directory). The declaration says a "
               f"bot keeps this pin current; nothing does")
        fails += 1
    if (not managed) and has_block:
        out(1, f"{rel} is declared `managed: false` and .github/dependabot.yml HAS a block that "
               f"covers it. A bot is opening pull requests against a file this repository says "
               f"must not be bumped")
        fails += 1
    # --- 4. justification --------------------------------------------------
    if not managed and not str(e.get("why") or "").strip():
        out(1, f"{rel}: `why` is empty. A manifest left unmanaged on purpose has a reason, and the "
               f"next person to look at a red alert on it needs to read that reason, not guess it")
        fails += 1

# --- 5. asserted absences --------------------------------------------------
for a in absences:
    pat = str((a or {}).get("pattern") or "").strip()
    if not pat:
        out(1, f"an entry in `absences_asserted` has no `pattern`: {a!r}")
        fails += 1
        continue
    hits = [p.relative_to(root).as_posix() for p in root.rglob(pat)
            if p.is_file() and not (PRUNE & set(p.relative_to(root).parts[:-1]))]
    if hits:
        out(1, f"{a.get('claimed_in')} states this repository has no `{pat}`, and it has "
               f"{len(hits)}: {', '.join(sorted(hits)[:4])}. A claim of absence does not age; the "
               f"tree does, and the reader who trusts the claim stops looking")
        fails += len(hits)

# --- 6. the answer key -----------------------------------------------------
gt_path = root / "bench" / "ground-truth.json"
fixtures = [e for e in by_path.values() if str(e.get("role")) == "bench-fixture"]
checked = 0
if fixtures:
    try:
        gt = json.loads(gt_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        out(2, f"the answer key is missing or unusable ({gt_path}): {exc}")
        raise SystemExit
    for section, field, label in (("planted", "planted", "plant"), ("decoys", "decoys", "decoy")):
        actual = {}
        for entry in gt.get(section) or []:
            case = str(entry.get("case") or "")
            sub = str(entry.get("path") or "")
            if not case or not sub:
                continue
            actual.setdefault(f"bench/cases/{case}/{sub}", set()).add(str(entry.get("symbol") or ""))
        for e in fixtures:
            rel = str(e["path"])
            want = set(str(s) for s in (e.get(field) or []))
            have = actual.get(rel, set())
            checked += 1
            for s in sorted(want - have):
                out(1, f"{rel} is declared to carry the {label} "
                       f"`{s}` and bench/ground-truth.json plants nothing of that name there. A "
                       f"manifest described as ground truth when it is not is how an incidental "
                       f"alert gets filed as expected")
                fails += 1
            for s in sorted(have - want):
                out(1, f"bench/ground-truth.json puts `{s}` in {rel} as a {label} and "
                       f"{surface_path.name} does not list it. Anyone reading this file to decide "
                       f"whether a bump is safe would bump it")
                fails += 1

out(0, f"measured: {len(found)} manifest(s) on disk, {len(by_path)} declared, "
       f"{sum(1 for e in by_path.values() if e.get('managed'))} managed by dependabot, "
       f"{len(absences)} asserted absence(s) checked, {checked} answer-key cross-check(s), "
       f"{fails} finding(s)")
if fails:
    out("FAILS", "")
PY
}

selftest() {
  command -v python3 >/dev/null 2>&1 || { echo "  UNMEASURABLE python3 is missing"; return 2; }
  python3 -c 'import yaml' 2>/dev/null || { echo "  UNMEASURABLE PyYAML is missing"; return 2; }
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/ehs-surface-XXXXXX")"
  local p=0 f=0
  # A synthetic tree, not a copy of the repository: this gate walks the whole
  # root, and copying it per case would cost minutes for nothing. One case runs
  # against the real repository so the synthetic shape cannot drift away from it.
  seed() {
    local w="$1"
    mkdir -p "$w/.github" "$w/bench/cases/node-supply" "$w/tooling/cli" "$w/scripts/gates/data"
    printf '{"dependencies":{"lodahs":"1.0.1"}}\n' > "$w/bench/cases/node-supply/package.json"
    printf '{"devDependencies":{"x":"1.0.0"}}\n'   > "$w/tooling/cli/package.json"
    cat > "$w/.github/dependabot.yml" <<'YML'
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
  - package-ecosystem: "npm"
    directory: "/tooling/cli"
YML
    cat > "$w/bench/ground-truth.json" <<'GT'
{"cases":[{"case":"node-supply","path":"bench/cases/node-supply"}],
 "planted":[{"id":"P-20","case":"node-supply","path":"package.json","symbol":"lodahs"}],
 "decoys":[]}
GT
    cat > "$w/scripts/gates/data/alert-surface.json" <<'SF'
{"manifests":[
  {"path":"bench/cases/node-supply/package.json","ecosystem":"npm","role":"bench-fixture",
   "managed":false,"why":"planted defect","planted":["lodahs"],"decoys":[]},
  {"path":"tooling/cli/package.json","ecosystem":"npm","role":"product","managed":true,
   "planted":[],"decoys":[]}],
 "absences_asserted":[{"pattern":"go.mod","claimed_in":".github/dependabot.yml","why":"none here"}]}
SF
  }
  # case <name> <expected rc> <needle> <mutation>
  run_case() {
    local name="$1" want="$2" needle="$3" mut="$4"
    local w="$tmp/$name"
    command rm -rf "$w"; mkdir -p "$w"
    seed "$w"
    if [ -n "$mut" ] && ! EHS_WORK="$w" python3 -c "$mut" >/dev/null 2>&1; then
      printf '  HARNESS  %-46s the mutation itself failed\n' "$name"; f=$((f+1)); return
    fi
    local out rc
    out="$(measure "$w" "$w/scripts/gates/data/alert-surface.json" 2>&1)"; rc=0
    printf '%s' "$out" | grep -q '^1|' && rc=1
    printf '%s' "$out" | grep -q '^2|' && rc=2
    if [ "$rc" -eq "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q -- "$needle"; }; then
      printf '  PASS  %-48s rc=%s\n' "$name" "$rc"; p=$((p+1))
    else
      printf '  FAIL  %-48s rc=%s (wanted %s)\n' "$name" "$rc" "$want"
      printf '%s\n' "$out" | sed 's/^/        /' | head -4; f=$((f+1))
    fi
  }

  echo "  == the shapes that must pass =="
  run_case a-tree-that-agrees-with-itself 0 "measured:" ""
  local real
  real="$(measure "$ROOT" "$SURFACE" 2>&1)"
  if printf '%s' "$real" | grep -q '^0|' && ! printf '%s' "$real" | grep -q '^[12]|'; then
    printf '  PASS  %-48s rc=0\n' "this-repository-as-it-stands"; p=$((p+1))
  else
    printf '  FAIL  %-48s\n' "this-repository-as-it-stands"
    printf '%s\n' "$real" | sed 's/^/        /' | head -4; f=$((f+1))
  fi

  echo "  == the omission hole: a manifest nobody declared =="
  run_case a-new-manifest-nobody-declared 1 "appears nowhere in" '
import os,pathlib
d=pathlib.Path(os.environ["EHS_WORK"])/"services/api"; d.mkdir(parents=True)
(d/"requirements.txt").write_text("flask==3.0.3\n")'

  run_case a-declaration-that-outlived-its-file 1 "not a manifest on disk any more" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"tooling/cli/package.json").unlink()'

  echo "  == the claim of absence that stopped being true =="
  run_case an-asserted-absence-that-is-now-present 1 "does not age" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"go.mod").write_text("module x\n")'

  echo "  == management, in both directions =="
  run_case managed-with-no-block-behind-it 1 "nothing does" '
import os,pathlib,re
p=pathlib.Path(os.environ["EHS_WORK"])/".github/dependabot.yml"
p.write_text(p.read_text().replace("/tooling/cli","/somewhere-else"))'

  run_case a-bot-pointed-at-a-bench-fixture 1 "must not be bumped" '
import os,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/".github/dependabot.yml"
p.write_text(p.read_text()+"  - package-ecosystem: \"npm\"\n    directory: \"/bench/cases/node-supply\"\n")'

  run_case unmanaged-without-a-reason 1 "needs to read that reason" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/data/alert-surface.json"
d=json.loads(p.read_text()); d["manifests"][0]["why"]="  "
p.write_text(json.dumps(d,indent=2))'

  echo "  == the answer key, in both directions =="
  run_case ground-truth-claimed-where-there-is-none 1 "is how an incidental" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/data/alert-surface.json"
d=json.loads(p.read_text()); d["manifests"][0]["planted"].append("express")
p.write_text(json.dumps(d,indent=2))'

  run_case a-plant-the-surface-file-never-heard-of 1 "would bump it" '
import os,json,pathlib
p=pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/data/alert-surface.json"
d=json.loads(p.read_text()); d["manifests"][0]["planted"]=[]
p.write_text(json.dumps(d,indent=2))'

  echo "  == could not measure =="
  run_case surface-file-missing 2 "missing or unusable" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"scripts/gates/data/alert-surface.json").unlink()'

  run_case dependabot-config-missing 2 "missing or unusable" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/".github/dependabot.yml").unlink()'

  run_case answer-key-missing 2 "missing or unusable" '
import os,pathlib
(pathlib.Path(os.environ["EHS_WORK"])/"bench/ground-truth.json").unlink()'

  command rm -rf "$tmp"
  echo "  $p PASS / $f FAIL"
  [ "$f" -eq 0 ] || return 1
  return 0
}

if [ "$ONLY_SELFTEST" -eq 1 ]; then
  selftest; exit $?
fi

gate_header "alert-surface (the file that tells you how to read an alert has to be right)"
gate_scope "every dependency manifest on disk, against scripts/gates/data/alert-surface.json, .github/dependabot.yml and bench/ground-truth.json"
gate_out_of_scope "how many alerts GitHub currently reports - that number moves when an upstream advisory is published and nobody here did anything - and any claim in the config's PROSE that was not transcribed into the data file"

if ! command -v python3 >/dev/null 2>&1; then
  gate_warn "python3 is not installed: nothing was checked"
  gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
fi

SELFTEST_SKIPPED=0
if [ "${GATE_SELFTEST:-1}" = "0" ]; then
  SELFTEST_SKIPPED=1
  gate_warn "the self-test was skipped (GATE_SELFTEST=0): the verdict is capped at 2"
else
  echo "== self-test: this gate, proved in the negative =="
  if ! selftest; then
    gate_warn "the gate does NOT pass its own self-test; any result over the repo would be indefensible"
    gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"
  fi
fi

echo "== the repository =="
RC=0
while IFS= read -r line; do
  code="${line%%|*}"; msg="${line#*|}"
  case "$code" in
    0)     [ -n "$msg" ] && echo "· $msg" ;;
    1)     gate_fail "$msg"; RC=1 ;;
    2)     gate_warn "$msg"; RC=2 ;;
    FAILS) : ;;
  esac
done < <(measure "$ROOT" "$SURFACE")

echo "NOT MEASURED: the alert COUNT, on purpose - it moves when an advisory is published and no"
echo "              change here caused it. And the prose of .github/dependabot.yml: a gate cannot"
echo "              read English, only the claims that were transcribed into the data file."

if [ "$SELFTEST_SKIPPED" -eq 1 ] && [ "$RC" -eq 0 ]; then RC=2; fi
gate_verdict "$RC"; exit "$RC"
