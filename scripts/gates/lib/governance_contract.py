"""Reads scripts/gh/governance.json and compares the two lists inside it that
must agree, without touching the network.

    promotion.required_contexts          what the promotion verifies on the candidate
    branches.<source>.protection
        .required_status_checks.checks   what a merge into <source> actually requires

A context declared in the first and absent from the second is a job whose red
result blocks nothing: it runs on every pull request and gates a merge only in
prose. That is finding F-005 of the blinded self-audit, issue #16.

Output protocol, one finding per line, read by gate-governance-contract.sh:

    MISSING|<context>     declared as required, not enforced by the protection
    EXTRA|<context>       enforced by the protection, not declared as required
    STAT|<key>|<value>
    ERR|<message>         could not measure (exit code 2 for the caller)

Invoked as `python3 lib/governance_contract.py <file>`: the directory that goes
first on sys.path is this library's own, never a working directory that could
belong to the tree under audit.
"""

import json
import sys


def main(argv):
    if len(argv) != 2:
        print("ERR|usage: governance_contract.py <governance.json>")
        return 2
    path = argv[1]

    try:
        with open(path, encoding="utf-8") as fh:
            state = json.load(fh)
    except FileNotFoundError:
        print("ERR|%s does not exist" % path)
        return 2
    except (OSError, ValueError) as exc:
        print("ERR|%s is not readable JSON: %s" % (path, exc))
        return 2

    promotion = state.get("promotion")
    if not isinstance(promotion, dict):
        print("ERR|the file declares no `promotion` block")
        return 2

    want = promotion.get("required_contexts")
    if not isinstance(want, list) or not all(isinstance(c, str) for c in want):
        print("ERR|`promotion.required_contexts` is missing or is not a list of strings")
        return 2

    source = promotion.get("source_branch")
    if not isinstance(source, str) or not source:
        print("ERR|`promotion.source_branch` is missing: I do not know which branch to read")
        return 2

    branches = state.get("branches")
    if not isinstance(branches, dict) or source not in branches:
        print("ERR|`branches.%s` is not declared: there is no protection to compare against" % source)
        return 2

    protection = branches[source].get("protection")
    if not isinstance(protection, dict):
        print("ERR|`branches.%s.protection` is missing" % source)
        return 2

    # A protection with NO required checks is not an absence of information: it
    # is the strongest possible disagreement, and it is reported as such.
    rsc = protection.get("required_status_checks")
    if rsc is None:
        have = []
    elif isinstance(rsc, dict):
        checks = rsc.get("checks")
        if not isinstance(checks, list):
            print("ERR|`branches.%s.protection.required_status_checks.checks` is not a list" % source)
            return 2
        have = []
        for entry in checks:
            if not isinstance(entry, dict) or not isinstance(entry.get("context"), str):
                print("ERR|an entry of `required_status_checks.checks` has no string `context`")
                return 2
            have.append(entry["context"])
    else:
        print("ERR|`branches.%s.protection.required_status_checks` is neither null nor an object" % source)
        return 2

    for ctx in sorted(set(want) - set(have)):
        print("MISSING|%s" % ctx)
    for ctx in sorted(set(have) - set(want)):
        print("EXTRA|%s" % ctx)

    print("STAT|source_branch|%s" % source)
    print("STAT|declared_required|%d" % len(want))
    print("STAT|enforced_by_protection|%d" % len(have))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
