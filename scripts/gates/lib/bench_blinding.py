#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# bench_blinding.py — measurement core for gate-bench-blinding.sh.
#
# WHAT THIS IS FOR
#   When one blinded batch pools claims from MORE THAN ONE ARM, anything that
#   varies with the arm rather than with the claim is a label. Not just a name:
#   the SHAPE of a field does it too. On 2026-08-22 two of these were caught by
#   eye, minutes before judging, in the same round:
#
#     - one arm wrote `target/agent/answer.py`, another `agent/answer.py`
#     - one arm folded the line into the path, `answer.py:48`, another did not
#
#   Neither contains an arm's name. Both let a judge sort the pool into groups
#   and treat the groups differently, which is exactly what blinding is for.
#
# WHAT IT MEASURES, and only for pooled batches
#   1. no absolute path anywhere in the batch
#   2. no directory that names an arm or the harness
#   3. the location field uses ONE style across the whole batch
#
# WHAT IT DOES NOT MEASURE
#   Whether the CONTENT of a claim gives its arm away - house vocabulary, a
#   citation style, a statistic only one corpus supplies. That needs a reader,
#   not a regex, and a green here is not a blinding clearance.
#
#   Batches judged one arm at a time are skipped and reported as skipped. A
#   judge holding a single list has nothing to sort into groups, so uniformity
#   buys nothing there; saying so out loud is better than a green that hides
#   which files were examined.
#
# Output: FINDING <text>, UNMEASURED <text>, anything else is info.
# Exit: 0 measured fine / 1 measured FAILS / 2 could not measure.
# ---------------------------------------------------------------------------
import collections
import json
import os
import re
import sys

findings, unmeasured, info = [], [], []


def finding(msg):
    findings.append(msg)


def unmeasurable(msg):
    unmeasured.append(msg)

ARM_WORDS = ("corpus", "mantis", "competitor", "unaided", "aig-", "skill-scan",
             "pentest-ai", "infra-guard", "scratchpad")


def style_of(loc):
    """The shape of a location, ignoring which file it points at."""
    if not loc:
        return "empty"
    if loc.startswith("/"):
        return "absolute"
    if re.match(r"^[a-zA-Z]+/", loc) and loc.split("/", 1)[0] in ("target", "src-root", "repo"):
        return "root-prefixed"
    if re.search(r":\d", loc):
        return "path-with-line"
    return "relative"


def claims_of(doc):
    for key in ("claims", "findings"):
        if isinstance(doc.get(key), list):
            return doc[key]
    return None


def location_of(item):
    loc = item.get("location")
    if isinstance(loc, dict):
        return f"{loc.get('path', '')}"
    if isinstance(loc, str) and loc:
        return loc
    return str(item.get("file") or "")


def main(root):
    runs = os.path.join(root, "bench", "runs")
    if not os.path.isdir(runs):
        unmeasurable("no bench/runs directory: nothing to check")
        return 2

    pooled, single, checked_claims = [], [], 0
    for rnd in sorted(os.listdir(runs)):
        rdir = os.path.join(runs, rnd)
        if not os.path.isdir(rdir):
            continue
        # A batch is POOLED when the round's provenance maps its claims to runs
        # from more than one arm. That mapping is the only honest signal; the
        # directory name is not.
        arms = set()
        for keydir in ("keys",):
            kd = os.path.join(rdir, keydir)
            if not os.path.isdir(kd):
                continue
            for f in sorted(os.listdir(kd)):
                if "provenance" not in f:
                    continue
                try:
                    m = json.load(open(os.path.join(kd, f), encoding="utf-8"))
                except (OSError, ValueError) as exc:
                    unmeasurable(f"{rnd}/{keydir}/{f} will not parse, so this round's batches could not be classified: {exc}")
                    return 2
                for row in m.get("map", []):
                    run = str(row.get("run", ""))
                    if run:
                        arms.add(run[0])
        for sub in sorted(os.listdir(rdir)):
            sdir = os.path.join(rdir, sub)
            if not os.path.isdir(sdir):
                continue
            for f in sorted(os.listdir(sdir)):
                if not (f == "claims.json" or f.startswith("batch-")):
                    continue
                path = os.path.join(sdir, f)
                rel = os.path.relpath(path, root)
                (pooled if len(arms) > 1 else single).append((rel, path))

    if not pooled and not single:
        unmeasurable("no blinded batch was found under bench/runs; a green here would mean nothing")
        return 2

    for rel, path in pooled:
        try:
            doc = json.load(open(path, encoding="utf-8"))
        except (OSError, ValueError) as exc:
            unmeasurable(f"{rel} will not parse: {exc}")
            return 2
        items = claims_of(doc)
        if items is None:
            unmeasurable(f"{rel} has neither a claims nor a findings list, so this check read nothing")
            return 2
        checked_claims += len(items)
        blob = json.dumps(items)
        # Absolute paths are checked in the LOCATION field only. Prose legitimately
        # names attacker paths - a claim about writing to /tmp/exfil is the finding,
        # not a leak - and an early version of this check failed two clean rounds on
        # exactly that. Harness paths anywhere are still caught, by ARM_WORDS.
        for loc in {location_of(i) for i in items}:
            if loc.startswith("/"):
                finding(f"{rel} gives a location as an absolute path ({loc[:60]}...): a pooled batch must not "
                        f"tell a judge where any arm wrote")
                break
        low = blob.lower()
        for word in ARM_WORDS:
            if word in low:
                finding(f"{rel} contains {word!r}: in a pooled batch that names the arm a claim came from")
        styles = collections.Counter(style_of(location_of(i)) for i in items)
        if len(styles) > 1:
            finding(f"{rel} mixes {len(styles)} location styles ({dict(styles)}): the SHAPE of the field sorts the pool "
                    f"into arms without naming one, which is the leak this check exists for")

    info.append(f"{len(pooled)} pooled batch(es) checked, {checked_claims} claims")
    if single:
        info.append(f"{len(single)} batch(es) skipped as single-arm — a judge holding one list has no groups to sort: "
                    + ", ".join(os.path.basename(os.path.dirname(r)) + "/" + os.path.basename(r) for r, _ in single[:4])
                    + (f" and {len(single) - 4} more" if len(single) > 4 else ""))
    return 1 if findings else 0




if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: bench_blinding.py <repo-root>", file=sys.stderr)
        sys.exit(2)
    code = main(sys.argv[1])
    for line in info:
        print(line)
    for line in findings:
        print("FINDING " + line)
    for line in unmeasured:
        print("UNMEASURED " + line)
    sys.exit(code)
