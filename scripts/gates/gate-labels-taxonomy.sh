#!/usr/bin/env bash
# gate-labels-taxonomy.sh
#
# WHY IT EXISTS: if an issue form applies a label that is not in the taxonomy of
# scripts/gh/labels.sh, GitHub drops it SILENTLY and the issue comes in unclassified.
# Deterministic triage breaks without anyone noticing. This gate makes it loud.
#
# WHAT IT CHECKS (no network):
#   1. Every label declared in `labels:` of an issue form exists in scripts/gh/labels.sh.
#   2. Every option of the role/area and severity dropdowns maps to a real label
#      `area/<x>` or `severity/<x>` (so the maintainer copies it without exercising
#      judgement).
#   3. Every form declares the mandatory fields (name, description, body) and uses
#      only valid element types.
#   4. config.yml exists and has blank_issues_enabled: false (without it there is an
#      entry path with no label at all).
#
# WHAT IT DOES NOT CHECK: whether those labels really exist ON GITHUB. That needs the
# network and it is scripts/gh/labels.sh --check.
#
# EXIT CODES: 0 = measured and fine | 1 = measured and FAILS | 2 = COULD NOT MEASURE.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

command -v python3 >/dev/null 2>&1 || {
  printf 'COULD NOT MEASURE: python3 is missing (needed to parse the form YAML files).\n' >&2
  exit 2
}
python3 -c 'import yaml' 2>/dev/null || {
  printf 'COULD NOT MEASURE: the PyYAML module is missing (pip install pyyaml).\n' >&2
  exit 2
}
[ -r "$ROOT/scripts/gh/labels.sh" ] || {
  printf 'COULD NOT MEASURE: I cannot find scripts/gh/labels.sh under %s.\n' "$ROOT" >&2
  exit 2
}
[ -d "$ROOT/.github/ISSUE_TEMPLATE" ] || {
  printf 'COULD NOT MEASURE: I cannot find .github/ISSUE_TEMPLATE under %s.\n' "$ROOT" >&2
  exit 2
}

ROOT="$ROOT" python3 <<'PY'
import os, re, sys, pathlib, yaml

root = pathlib.Path(os.environ["ROOT"])
tpl_dir = root / ".github/ISSUE_TEMPLATE"

tax = set()
for line in (root / "scripts/gh/labels.sh").read_text().splitlines():
    m = re.match(r'^([a-z]+/[a-z0-9-]+)\|([0-9a-f]{6})\|(.+)$', line)
    if m:
        tax.add(m.group(1))

if not tax:
    print("COULD NOT MEASURE: I extracted no label from scripts/gh/labels.sh "
          "(the 'name|color|description' format changed).")
    sys.exit(2)

VALID_TYPES = {"markdown", "input", "textarea", "dropdown", "checkboxes"}

# EXPLICIT DROPDOWN REGISTRY. This used to be an "opt-in" dict: a dropdown whose id
# was not listed here was skipped SILENTLY and the gate kept saying "OK".
# Renaming `id: role` to `id: reporter_role` disabled the whole check without
# anything failing: rc=0 meant "I did not check it", which is exactly what must not
# happen. Now every dropdown has to be declared in ONE of the two tables.
#
#   id -> (label prefix, options that deliberately are NOT a label)
MAPPED_DROPDOWNS = {
    "role":     ("area/",     set()),
    "area":     ("area/",     set()),
    "severity": ("severity/", set()),
    "channel":  ("channel/",  {"installed by hand / not sure"}),
}
# id -> reason why its options do not correspond to any label
EXEMPT_DROPDOWNS = {}

problems = []
checked_forms = 0
checked_labels = 0
checked_options = 0
skipped_dropdowns = []

# Both .yml and .yaml are inspected: GitHub's docs only document .yml, but a stray
# .yaml file here would go unchecked and this gate cannot stay quiet about what it
# does not look at.
forms = sorted(p for p in list(tpl_dir.glob("*.yml")) + list(tpl_dir.glob("*.yaml"))
               if p.stem != "config")
if not forms:
    print("COULD NOT MEASURE: there is no issue form in .github/ISSUE_TEMPLATE.")
    sys.exit(2)

for p in forms:
    try:
        doc = yaml.safe_load(p.read_text())
    except Exception as e:
        problems.append(f"{p.name}: invalid YAML: {e}")
        continue
    checked_forms += 1
    for key in ("name", "description", "body"):
        if key not in doc:
            problems.append(f"{p.name}: the mandatory key '{key}' is missing")
    if not doc.get("labels"):
        problems.append(f"{p.name}: it does not declare 'labels'; an issue created with "
                        f"this form would come in unclassified")
    for lbl in doc.get("labels", []):
        checked_labels += 1
        if lbl not in tax:
            problems.append(f"{p.name}: the label '{lbl}' does not exist in scripts/gh/labels.sh")
    for elem in doc.get("body", []) or []:
        t = elem.get("type")
        if t not in VALID_TYPES:
            problems.append(f"{p.name}: invalid element type: {t!r}")
            continue
        if t != "dropdown":
            continue
        did = elem.get("id", "")
        if did in EXEMPT_DROPDOWNS:
            skipped_dropdowns.append(f"{p.name}:{did} (exempt: {EXEMPT_DROPDOWNS[did]})")
            continue
        if did not in MAPPED_DROPDOWNS:
            problems.append(
                f"{p.name}: the dropdown '{did}' is not declared. Add it to "
                f"MAPPED_DROPDOWNS (with its label prefix) or to EXEMPT_DROPDOWNS "
                f"(with the reason). Without declaring it, its options would go "
                f"unchecked and this gate would say 'OK' without having measured "
                f"anything.")
            continue
        prefix, free = MAPPED_DROPDOWNS[did]
        for opt in elem.get("attributes", {}).get("options", []):
            checked_options += 1
            if str(opt) in free:
                continue
            key = str(opt).split(" ")[0]
            full = prefix + key
            if full not in tax:
                problems.append(f"{p.name}: the option '{opt}' of dropdown "
                                f"'{did}' maps to no label ({full})")

# Consistency with gate-issue-closure.sh: that gate only REQUIRES a watched regression
# when the issue carries one of the REGRESSION_LABELS. If someone renames the label in
# the taxonomy (or there is a typo in the default value), that gate stops requiring
# anything and returns rc=0 "OK" forever, without anyone noticing. This ties that end.
closure = root / "scripts/gates/gate-issue-closure.sh"
checked_regression = []
if not closure.exists():
    problems.append("I cannot find scripts/gates/gate-issue-closure.sh: I cannot check "
                    "that its regression labels exist in the taxonomy")
else:
    m = re.search(r'^REGRESSION_LABELS="\$\{REGRESSION_LABELS:-([^}"]*)\}"',
                  closure.read_text(), re.M)
    if not m:
        problems.append("gate-issue-closure.sh: I could not read the default value of "
                        "REGRESSION_LABELS (the format changed); without it I cannot check "
                        "that those labels exist")
    else:
        checked_regression = [x.strip() for x in m.group(1).split(",") if x.strip()]
        if not checked_regression:
            problems.append("gate-issue-closure.sh: the default REGRESSION_LABELS is empty; "
                            "the closure gate would require a regression from NO issue at all")
        for lbl in checked_regression:
            if lbl not in tax:
                problems.append(f"gate-issue-closure.sh: the regression label '{lbl}' does not "
                                f"exist in scripts/gh/labels.sh; that gate would never fire")

# The same loose end, from the other side: promotion.blocking_issue_labels in
# scripts/gh/governance.json is the only thing that freezes automatic promotion to
# stable. GitHub SILENTLY IGNORES a label that does not exist, so a name outside the
# taxonomy turns the channel brake into decoration: the query would always return zero
# issues and release.yml would happily promote. Measured during integration: the file
# declared 'stable-blocker' and 'security-incident', which existed nowhere.
gov = root / "scripts/gh/governance.json"
checked_blockers = []
if not gov.exists():
    problems.append("I cannot find scripts/gh/governance.json: I cannot check that the "
                    "labels blocking promotion exist in the taxonomy")
else:
    try:
        import json
        gdoc = json.loads(gov.read_text())
        checked_blockers = list(gdoc.get("promotion", {}).get("blocking_issue_labels", []))
        if not checked_blockers:
            problems.append("governance.json: promotion.blocking_issue_labels is empty; "
                            "nothing could freeze automatic promotion to stable")
        for lbl in checked_blockers:
            if lbl not in tax:
                problems.append(f"governance.json: the blocking label '{lbl}' does not exist in "
                                f"scripts/gh/labels.sh; GitHub would ignore it and the stable "
                                f"channel brake would be decorative")
    except Exception as e:
        problems.append(f"governance.json: I could not read it ({e}); without that I cannot "
                        f"check that the labels blocking promotion exist")

cfg = tpl_dir / "config.yml"
if not cfg.exists():
    problems.append(".github/ISSUE_TEMPLATE/config.yml is missing")
else:
    try:
        c = yaml.safe_load(cfg.read_text()) or {}
        if c.get("blank_issues_enabled") is not False:
            problems.append("config.yml: blank_issues_enabled must be false "
                            "(the blank issue is the only entry path with no label)")
    except Exception as e:
        problems.append(f"config.yml: invalid YAML: {e}")

print("gate-labels-taxonomy")
print("====================")
print(f"CHECKED: {checked_forms} issue forms, {checked_labels} declared labels, "
      f"{checked_options} dropdown options, against {len(tax)} labels of the taxonomy.")
print(f"CHECKED: the {len(checked_regression)} regression labels of gate-issue-closure.sh "
      f"exist in the taxonomy: {', '.join(checked_regression) or '<none>'}")
print(f"CHECKED: the {len(checked_blockers)} labels that freeze promotion to stable "
      f"(governance.json) exist in the taxonomy: {', '.join(checked_blockers) or '<none>'}")
if skipped_dropdowns:
    print("NOT CHECKED (exempt and declared as such): " + "; ".join(skipped_dropdowns))
print("NOT CHECKED: whether those labels exist on GitHub (that is scripts/gh/labels.sh --check).")
print()

if problems:
    print("Result: FAIL.")
    for pr in problems:
        print(f"  - {pr}")
    sys.exit(1)

print("Result: OK. The forms only apply labels that the taxonomy declares.")
sys.exit(0)
PY
