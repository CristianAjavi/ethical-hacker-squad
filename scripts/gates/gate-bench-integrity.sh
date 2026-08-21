#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-bench-integrity.sh — the answer key still describes the cases.
#
# WHY IT EXISTS
#   A bench is only as honest as its key. A planted defect whose symbol was
#   renamed, a decoy whose file was deleted, a procedure id that no longer
#   exists, a triage rule that was renumbered: every one of those turns a score
#   into confident nonsense, and none of them announces itself.
#
# WHAT IT MEASURES
#   Every case path exists; every planted and decoy entry points at a file that
#   exists inside its case and at a symbol that literally appears in it; every
#   procedure id exists in the corpus; every `ruled_out_by` rule exists in
#   triage.md; ids are unique; and every case has at least one of each half,
#   because a case with no decoys measures agreement rather than detection.
#
# EXIT CODES (repo contract): 0 measured fine · 1 measured FAILS · 2 could not
# measure (no python3, no key, a key that will not parse).
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$HERE/lib/common.sh"
ROOT="${EHS_REPO_ROOT:-$(gate_root)}"

gate_header "bench-integrity (the answer key against the cases it describes)"
gate_scope "every case, planted defect, decoy, procedure id and triage rule in bench/ground-truth.json"
gate_out_of_scope "whether a planted defect is realistic, and whether the bench covers enough surface"

command -v python3 >/dev/null 2>&1 || { gate_warn "python3 is not installed"; gate_verdict "$GATE_UNMEASURABLE"; exit "$GATE_UNMEASURABLE"; }

out="$(EHS_ROOT="$ROOT" python3 - <<'PY' 2>&1
import json, os, re, sys
from pathlib import Path

root = Path(os.environ["EHS_ROOT"])
key_path = root / "bench" / "ground-truth.json"
try:
    key = json.loads(key_path.read_text(encoding="utf-8"))
except (OSError, ValueError) as exc:
    print(f"UNMEASURED cannot read the answer key: {exc}"); sys.exit(2)
try:
    packs = json.loads((root / "scripts/meter/packs.json").read_text(encoding="utf-8"))
    triage = (root / "skills/ethical-hacker-squad/references/triage.md").read_text(encoding="utf-8")
except (OSError, ValueError) as exc:
    print(f"UNMEASURED cannot read a source of truth: {exc}"); sys.exit(2)

kdir = root / packs["knowledge_dir"]
heading = re.compile(packs["procedure_heading"])
procedures = set()
for pack in packs["packs"]:
    for name in pack["files"]:
        try:
            for line in (kdir / name).read_text(encoding="utf-8").splitlines():
                m = heading.match(line)
                if m:
                    procedures.add(f"{m.group(1)}-{int(m.group(2)):02d}")
        except OSError as exc:
            print(f"UNMEASURED cannot read pack {name}: {exc}"); sys.exit(2)
rules = set(re.findall(r"`(FP-\d{2})`", triage))
if not procedures or not rules:
    print("UNMEASURED the corpus or the triage rules came back empty"); sys.exit(2)

findings, checks = [], 0
cases = {c["case"]: c for c in key.get("cases", [])}
if not cases:
    print("UNMEASURED the key declares no cases"); sys.exit(2)

for name, case in cases.items():
    checks += 1
    if not (root / case["path"]).is_dir():
        findings.append(f"case `{name}` points at {case['path']}, which is not a directory")

seen = set()
for kind in ("planted", "decoys"):
    for item in key.get(kind, []):
        checks += 1
        if item["id"] in seen:
            findings.append(f"duplicate id {item['id']}")
        seen.add(item["id"])
        case = cases.get(item["case"])
        if not case:
            findings.append(f"{item['id']} names case `{item['case']}`, which the key does not declare")
            continue
        target = root / case["path"] / item["path"]
        checks += 1
        if not target.is_file():
            findings.append(f"{item['id']} points at {item['path']}, which does not exist in {item['case']}")
            continue
        body = target.read_text(encoding="utf-8")
        needle = item["symbol"].split()[-1] if " " in item["symbol"] else item["symbol"]
        # Word boundaries when the symbol is an identifier: `write_token` must not
        # be satisfied by `write_token_privately`, which is a DIFFERENT function
        # and, in this bench, the decoy that contrasts with it.
        if re.fullmatch(r"\w+", needle):
            present = re.search(rf"\b{re.escape(needle)}\b", body) is not None
        else:
            present = needle in body
        checks += 1
        if not present:
            findings.append(
                f"{item['id']} points at `{item['symbol']}` in {item['path']}, and `{needle}` does not "
                "appear there: the case was edited and the key was not")
        for extra in item.get("also_at", []):
            checks += 2
            extra_path = root / case["path"] / extra["path"]
            if not extra_path.is_file():
                findings.append(f"{item['id']} also_at points at {extra['path']}, which does not exist")
                continue
            extra_body = extra_path.read_text(encoding="utf-8")
            extra_needle = extra.get("symbol", "")
            if extra_needle and re.fullmatch(r"\w+", extra_needle):
                if re.search(rf"\b{re.escape(extra_needle)}\b", extra_body) is None:
                    findings.append(
                        f"{item['id']} also_at names `{extra_needle}` in {extra['path']}, which is not there")
        if kind == "planted":
            checks += 1
            if item["procedure"] not in procedures:
                findings.append(f"{item['id']} expects `{item['procedure']}`, which is not a procedure in the corpus")
        else:
            for rule in item.get("ruled_out_by", []):
                checks += 1
                if rule not in rules:
                    findings.append(f"{item['id']} says `{rule}` rules it out, and triage.md does not declare it")

# A case file that labels its own answers hands the run to the auditor. This was
# a real defect: the first version of both cases carried `# Planted:` and
# `# Decoy:` comments, which would have made every score meaningless.
LEAK = re.compile(r"\bplanted\b|\bdecoy\b|ground.truth|answer key", re.I)
for name, case in cases.items():
    for path in sorted((root / case["path"]).rglob("*")):
        if not path.is_file():
            continue
        checks += 1
        try:
            body = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        hit = LEAK.search(body)
        if hit:
            findings.append(
                f"case file {path.relative_to(root)} contains {hit.group(0)!r}: a case that labels "
                "its own answers hands the run to the auditor and every score from it is worthless")

for name in cases:
    planted = [p for p in key.get("planted", []) if p["case"] == name]
    decoys = [d for d in key.get("decoys", []) if d["case"] == name]
    checks += 2
    if not planted:
        findings.append(f"case `{name}` plants nothing: there is nothing to detect")
    if not decoys:
        findings.append(
            f"case `{name}` has no decoys: a case with only planted defects measures the model's "
            "willingness to agree, not its judgement")

print(f"measured: {len(cases)} case(s), {len(key.get('planted', []))} planted, "
      f"{len(key.get('decoys', []))} decoys, {checks} checks")
for f in findings:
    print(f"FINDING {f}")
sys.exit(1 if findings else 0)
PY
)"; rc=$?

while IFS= read -r line; do
  case "$line" in
    FINDING\ *)    gate_fail "${line#FINDING }" ;;
    UNMEASURED\ *) gate_warn "${line#UNMEASURED }" ;;
    *)             gate_info "$line" ;;
  esac
done <<< "$out"

case "$rc" in
  0) gate_ok "the answer key still describes the cases it scores" ;;
  1) : ;;
  *) rc="$GATE_UNMEASURABLE" ;;
esac
gate_verdict "$rc"
exit "$rc"
