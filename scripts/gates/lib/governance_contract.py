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
    UNWATCHED|<field>     a top-level field the comparator script never reads
    DISAGREE|<field>      the census and the block carrying the reasoning differ
    STAT|<key>|<value>
    ERR|<message>         could not measure (exit code 2 for the caller)

The comparator script is an OPTIONAL second argument. When it is not supplied
the UNWATCHED check cannot run, and the absence is printed as a STAT rather
than passed over: a check that quietly does not run reads exactly like a check
that passed.

Invoked as `python3 lib/governance_contract.py <file>`: the directory that goes
first on sys.path is this library's own, never a working directory that could
belong to the tree under audit.
"""

import json
import sys


def main(argv):
    if len(argv) not in (2, 3):
        print("ERR|usage: governance_contract.py <governance.json> [apply-governance.sh]")
        return 2
    path = argv[1]
    comparator = argv[2] if len(argv) == 3 else None

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

    # -- UNWATCHED -----------------------------------------------------------
    # The evidence that a field is compared is that the comparator mentions its
    # jq path. It is a coarse instrument and its limit is stated rather than
    # implied: a mention inside a comment counts, so this catches "nobody wrote
    # the comparator" and not "somebody wrote a comparator that reads the field
    # and does nothing with it". The first is what has happened; the second has
    # not, and a check that pretends to catch both would be the lie.
    fields = sorted(k for k in state if not k.startswith("_"))
    if comparator is None:
        print("STAT|unwatched_check|not-run-no-comparator-supplied")
    else:
        try:
            with open(comparator, encoding="utf-8") as fh:
                source_text = fh.read()
        except OSError as exc:
            print("ERR|the comparator %s is not readable: %s" % (comparator, exc))
            return 2
        for field in fields:
            if ".%s" % field not in source_text:
                print("UNWATCHED|%s" % field)
        print("STAT|fields_checked|%d" % len(fields))

    # -- DISAGREE ------------------------------------------------------------
    census = state.get("security_and_analysis_declared")
    if isinstance(census, dict):
        pairs = [
            ("dependabot_security_updates",
             _status(state.get("dependabot_security_updates"))),
            ("secret_scanning",
             _status((state.get("secret_scanning") or {}).get("enabled")
                     if isinstance(state.get("secret_scanning"), dict) else None)),
            ("secret_scanning_push_protection",
             _status((state.get("secret_scanning") or {}).get("push_protection")
                     if isinstance(state.get("secret_scanning"), dict) else None)),
        ]
        for key, derived in pairs:
            if derived is None:
                continue
            if census.get(key) != derived:
                print("DISAGREE|%s census=%s block=%s"
                      % (key, census.get(key), derived))
        print("STAT|census_keys|%d" % len(census))

    print("STAT|source_branch|%s" % source)
    print("STAT|declared_required|%d" % len(want))
    print("STAT|enforced_by_protection|%d" % len(have))
    return 0


def _status(value):
    """A declared boolean as the API spells it, or None when it is not declared."""
    if value is True:
        return "enabled"
    if value is False:
        return "disabled"
    return None


if __name__ == "__main__":
    sys.exit(main(sys.argv))
