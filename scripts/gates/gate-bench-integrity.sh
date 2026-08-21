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
        # When the symbol IS the file name, the file itself is the subject - a
        # committed binary, a configuration file - and there is nothing to find
        # inside it. Anything else must literally appear in the file.
        if item["symbol"] == Path(item["path"]).name:
            continue
        try:
            body = target.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            findings.append(
                f"{item['id']} points at a symbol inside {item['path']}, which is not text: "
                "name the file itself as the symbol when the file is the subject")
            continue
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

# A declared file that git does not track exists on one machine and nowhere
# else. CI found this the hard way: .gitignore excluded a .env.example
# the key declares, so the gate failed on a file that was right there locally.
import subprocess
try:
    tracked = set(subprocess.run(["git", "-C", str(root), "ls-files", "bench/cases"],
                                 capture_output=True, text=True, check=True).stdout.split())
except (OSError, subprocess.CalledProcessError):
    tracked = None
if tracked is not None:
    for kind in ("planted", "decoys"):
        for item in key.get(kind, []):
            case = cases.get(item["case"])
            if not case:
                continue
            rel = f"{case['path']}/{item['path']}"
            checks += 1
            if rel not in tracked:
                findings.append(
                    f"{item['id']} points at {rel}, which git does not track: it exists here "
                    "and nowhere else, and any run elsewhere scores against a file that is missing")

# A planted defect and a decoy that share lines in the same file cannot be told
# apart by any scorer: a finding at that line is simultaneously a detection and a
# false positive. It happened on `pipelines-migration`: decoy D-33 was declared
# over lines 6-13 of a Jenkinsfile whose planted defect sits at line 12, so the
# one correct finding was counted as reporting the decoy. The key is what has to
# be precise here, not the auditor.
def _spans(item):
    out = []
    if isinstance(item.get("lines"), list) and len(item["lines"]) == 2:
        out.append((item["path"], item["lines"][0], item["lines"][1]))
    for extra in item.get("also_at", []):
        if isinstance(extra.get("lines"), list) and len(extra["lines"]) == 2:
            out.append((extra["path"], extra["lines"][0], extra["lines"][1]))
    return out

for name in cases:
    planted_spans = [(p["id"], s) for p in key.get("planted", []) if p["case"] == name for s in _spans(p)]
    decoy_spans = [(d["id"], s) for d in key.get("decoys", []) if d["case"] == name for s in _spans(d)]
    for pid, (ppath, pa, pb) in planted_spans:
        for did, (dpath, da, db) in decoy_spans:
            checks += 1
            if ppath == dpath and pa <= db and da <= pb:
                findings.append(
                    f"{pid} (lines {pa}-{pb}) and {did} (lines {da}-{db}) overlap in {ppath}: "
                    "a finding there is a detection and a false positive at the same time, so "
                    "neither number means anything")

# A README that says which packs the bench exercises is making a coverage claim,
# and that claim rots the moment a case is added. It rotted once already: the
# sentence still said "web-api and local-app only" four cases after the six-pack
# run. So it lives in a marked region and is measured against the key.
COVERAGE = re.compile(r"<!--\s*bench:packs\s*-->(.*?)<!--\s*/bench:packs\s*-->", re.S)
bench_readme = root / "bench" / "README.md"
packs_json = root / "scripts" / "meter" / "packs.json"
checks += 1
if not bench_readme.is_file() or not packs_json.is_file():
    findings.append("bench/README.md or scripts/meter/packs.json is missing: the coverage claim cannot be measured")
else:
    m = COVERAGE.search(bench_readme.read_text(encoding="utf-8"))
    if not m:
        findings.append(
            "bench/README.md states which packs the bench exercises and the claim is not inside a "
            "`bench:packs` region, so nothing can check it against the key")
    else:
        payload = m.group(1)
        head, _, tail = payload.partition("silent about")
        said_exercised = set(re.findall(r"`([a-z-]+)`", head))
        said_silent = set(re.findall(r"`([a-z-]+)`", tail))
        all_packs = {p["pack"] for p in json.loads(packs_json.read_text(encoding="utf-8"))["packs"]}
        real_exercised = {p for c in cases.values() for p in c.get("packs", [])}
        checks += 2
        if said_exercised != real_exercised:
            findings.append(
                f"bench/README.md says the bench exercises {sorted(said_exercised)}; the key says "
                f"{sorted(real_exercised)} - a coverage claim wider than the cases is the one lie "
                "a bench cannot afford")
        if said_silent != all_packs - real_exercised:
            findings.append(
                f"bench/README.md says the score is silent about {sorted(said_silent)}; measured "
                f"{sorted(all_packs - real_exercised)}")

# ---- the patch bench -------------------------------------------------
# A patch that no longer applies, claims a defect nobody planted, or expects a
# verdict the vocabulary does not declare, turns a verification score into
# noise. And a case whose every patch is a correct fix measures agreement: the
# expensive error is `verified` on a patch that does not fix, so each case must
# carry at least one patch that must NOT come back verified.
LEAK_NAME = re.compile(r"correct|cosmetic|broken|breaks|symptom|wrong|fake|good|bad", re.I)
patch_key_path = root / "bench" / "patch-truth.json"
if patch_key_path.is_file():
    try:
        pkey = json.loads(patch_key_path.read_text(encoding="utf-8"))
    except ValueError as exc:
        print(f"UNMEASURED bench/patch-truth.json does not parse: {exc}"); sys.exit(2)
    vocab = (root / "skills/ethical-hacker-squad/references/vocabulary.md").read_text(encoding="utf-8")
    m = re.search(r"<!--\s*vocabulary:declare verification\s*-->(.*?)<!--\s*/vocabulary:declare\s*-->",
                  vocab, re.S)
    if not m:
        print("UNMEASURED vocabulary.md declares no verification region"); sys.exit(2)
    outcomes = {t.strip() for t in re.findall(r"^\|\s*`([a-z ]+)`\s*\|", m.group(1), re.M)}
    planted_ids = {p["id"] for p in key.get("planted", [])}
    seen_patches, by_case = set(), {}
    for patch in pkey.get("patches", []):
        checks += 1
        if patch["id"] in seen_patches:
            findings.append(f"duplicate patch id {patch['id']}")
        seen_patches.add(patch["id"])
        by_case.setdefault(patch["case"], []).append(patch)
        case = cases.get(patch["case"])
        checks += 3
        if not case:
            findings.append(f"{patch['id']} names case `{patch['case']}`, which the key does not declare")
            continue
        diff = root / "bench" / "patches" / patch["case"] / patch["diff"]
        if not diff.is_file():
            findings.append(f"{patch['id']} points at {patch['diff']}, which does not exist")
        if patch["claims_to_fix"] not in planted_ids:
            findings.append(f"{patch['id']} claims to fix {patch['claims_to_fix']}, which is not a planted defect")
        if LEAK_NAME.search(patch["diff"]):
            findings.append(
                f"{patch['id']} is stored as {patch['diff']}: the filename hands the verdict to the verifier "
                "before it reads a line. Name patches by id only")
        if patch["expected"] not in outcomes:
            findings.append(
                f"{patch['id']} expects the verdict `{patch['expected']}`, which vocabulary.md does not declare")
    # every diff must still apply to its case
    import subprocess, shutil, tempfile
    for patch in pkey.get("patches", []):
        case = cases.get(patch["case"])
        diff = root / "bench" / "patches" / patch["case"] / patch["diff"]
        if not case or not diff.is_file():
            continue
        checks += 1
        with tempfile.TemporaryDirectory() as td:
            work = Path(td) / "case"
            shutil.copytree(root / case["path"], work)
            r = subprocess.run(["git", "apply", "--check", "-p1", str(diff)],
                               cwd=work, capture_output=True, text=True)
            if r.returncode != 0:
                findings.append(
                    f"{patch['id']} no longer applies to {patch['case']}: {r.stderr.strip().splitlines()[:1]}")
    for case_name, patches in by_case.items():
        checks += 1
        if all(p["expected"] == "verified" for p in patches):
            findings.append(
                f"case `{case_name}` has no patch that must fail verification: a set where every patch is a "
                "correct fix measures agreement, not judgement")
    print(f"patch bench: {len(pkey.get('patches', []))} patch(es) over {len(by_case)} case(s)")

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
