#!/usr/bin/env python3
"""Reconcile a declared scope of work against the engagement that actually ran.

WHY IT EXISTS
  `engagement.scope` was a sentence. Nothing compared it to anything, so a
  finding outside the authorised tree and an authorised target nobody ever
  opened were both invisible - and the second is the expensive one, because an
  audit that quietly skipped half of what it was pointed at reads exactly like
  an audit that looked and found nothing.

  Three neighbouring products ship a scope file: PentAGI a template with an
  eight-step check, PT-Agents a guard block grepped for in CI (which this repo
  already has), AgSec a portable artifact. All three are PRE-ACTION. None of
  them reconciles the declaration against the run. That comparison is what this
  adds, and it is only affordable because findings.json already publishes
  machine-readable locations.

WHAT IT MEASURES, IN BOTH DIRECTIONS
  1. Every path the run touched - a finding's `location.path`, and every entry
     of `engagement.coverage` - falls inside `authorized` and inside none of
     `out_of_scope`. `out_of_scope` wins on an overlap, always.
  2. Every entry of `authorized` appears in `examined`, as `examined` or as
     `not-examined` WITH a reason. This is the direction the field omits, and
     it is the one that still applies when a run reports nothing at all.

WHAT IT DOES NOT MEASURE
  Whether the authorisation is genuine: `authorization.reference` is a string a
  person checks, and a gate claiming otherwise would be lying about the field
  that matters most. Whether a `host`, `service`, `account` or `artifact` target
  was respected: those are declared, reported as UNCHECKED, and never counted as
  verified. Whether an examination was any good - `examined` by a specialist
  that read one line is `examined` here; depth belongs to traceability.md, and
  conflating them would let a coverage number stand in for coverage.
  `ruled_out[].where` is prose, not a path, so it is not reconciled.

EXIT CODES: 0 measured fine · 1 measured FAILS · 2 could not measure.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from findings_artifact import check_shape  # noqa: E402  the shape has ONE owner

SCHEMA = "skills/ethical-hacker-squad/references/findings.schema.json"
DOC = "skills/ethical-hacker-squad/references/scope.md"
FIXTURES = "scripts/gates/fixtures/scope"
MECHANICAL = "path"  # the only kind a machine can honestly reconcile


def glob_to_re(pattern: str) -> re.Pattern:
    """`**` crosses separators, `*` and `?` do not. Anything else is literal.

    fnmatch would have been one line and wrong: its `*` eats `/`, so `src/*`
    would silently authorise `src/a/b/c` and the exclusion `infra/*` would
    quietly cover more than it says.

    The separator beside a `**` is optional, because `routes/**` means
    everything under routes and a reader includes the directory in that. Getting
    this wrong is not cosmetic: `coverage.inventoried` is written as `routes/`,
    so a mandatory separator reported every correctly scoped run as a breach.
    """
    out, i, n = [], 0, len(pattern)
    while i < n:
        c = pattern[i]
        if c == "*" and pattern[i:i + 2] == "**":
            after = pattern[i + 2:]
            before_sep = out and out[-1] == "/"
            if before_sep and not after:                 # `a/**`  -> a, a/x, a/x/y
                out[-1] = "(?:/.*)?"
            elif before_sep and after.startswith("/"):   # `a/**/b` -> a/b, a/x/b
                out[-1] = "/(?:.*/)?"
                i += 1                                   # the trailing / is spent
            elif not before_sep and after.startswith("/"):  # `**/b` -> b, x/b
                out.append("(?:.*/)?")
                i += 1
            else:
                out.append(".*")
            i += 2
            continue
        if c == "*":
            out.append("[^/]*")
        elif c == "?":
            out.append("[^/]")
        elif c == "/":
            out.append("/")
        else:
            out.append(re.escape(c))
        i += 1
    return re.compile("^" + "".join(out) + "$")


def matches(path: str, entry: dict) -> bool:
    if entry.get("kind") != MECHANICAL:
        return False
    return bool(glob_to_re(entry["target"]).match(path.strip("/")))


def coverage_paths(engagement: dict) -> list[tuple[str, str]]:
    """Every path the run says it touched, with where the claim came from."""
    out = []
    cov = engagement.get("coverage")
    if isinstance(cov, dict):
        for field in ("inventoried", "read", "not_read"):
            for p in cov.get(field, []) or []:
                if isinstance(p, str):
                    out.append((p, f"engagement.coverage.{field}"))
    return out


def reconcile(data: dict, schema: dict, name: str) -> tuple[list[str], list[str], list[str]]:
    """-> (findings, unmeasured, notes). A finding is rc 1; unmeasured is rc 2."""
    bad: list[str] = []
    unmeasured: list[str] = []
    notes: list[str] = []

    eng = data.get("engagement")
    if not isinstance(eng, dict) or "scope" not in eng:
        unmeasured.append(f"{name}: no engagement.scope, so there was nothing to reconcile")
        return bad, unmeasured, notes

    scope = eng["scope"]
    if isinstance(scope, str):
        unmeasured.append(
            f"{name}: engagement.scope is the legacy string form. It is not wrong, it is "
            "unreconcilable - reporting it as `in scope` would be inventing a measurement")
        return bad, unmeasured, notes
    if not isinstance(scope, dict):
        bad.append(f"{name}: engagement.scope is neither a string nor a declaration")
        return bad, unmeasured, notes

    errs: list[str] = []
    check_shape(scope, schema["$defs"]["scope_declaration"], "engagement.scope",
                errs.append, schema)
    if errs:
        bad.extend(f"{name}: {e}" for e in errs)
        return bad, unmeasured, notes

    authorized = scope["authorized"]
    excluded = scope.get("out_of_scope", [])

    # The schema cannot say "required when outcome is not-examined", so this is
    # the one shape rule that lives here rather than there.
    for i, e in enumerate(scope["examined"]):
        if e["outcome"] == "not-examined" and not e.get("why"):
            bad.append(f"{name}: examined[{i}] `{e['target']}` was not examined and does not "
                       "say why, which is the whole of what the entry was for")

    mech = [e for e in authorized if e["kind"] == MECHANICAL]
    other = [e for e in authorized if e["kind"] != MECHANICAL]
    if other:
        notes.append(f"{name}: {len(other)} authorised target(s) of kind "
                     f"{sorted({e['kind'] for e in other})} were NOT mechanically checked - "
                     "declared and reported, never counted as verified")

    # An exclusion that has to fight an inclusion is a scope somebody should
    # rewrite, so the overlap is said out loud rather than resolved in silence.
    for x in excluded:
        if x.get("kind") != MECHANICAL:
            continue
        for a in mech:
            if glob_to_re(a["target"]).match(x["target"].strip("/")) or \
               glob_to_re(x["target"]).match(a["target"].strip("/")):
                notes.append(f"{name}: `{x['target']}` is excluded and overlaps the authorised "
                             f"`{a['target']}`; the exclusion wins, and the pair is worth rewriting")

    # ---- direction 1: nothing the run touched sits outside the authorisation
    touched: list[tuple[str, str]] = coverage_paths(eng)
    for i, f in enumerate(data.get("findings", []) or []):
        loc = f.get("location") if isinstance(f, dict) else None
        if isinstance(loc, dict) and isinstance(loc.get("path"), str):
            touched.append((loc["path"], f"findings[{i}].location.path"))

    for path, where in touched:
        hit = next((x for x in excluded if matches(path, x)), None)
        if hit is not None:
            bad.append(f"{name}: {where} `{path}` is inside `{hit['target']}`, which the scope "
                       f"excludes ({hit['why']}). The audit touched what it was told not to")
            continue
        if not any(matches(path, a) for a in mech):
            if not mech:
                bad.append(f"{name}: {where} `{path}` was touched and no authorised path exists "
                           "to cover it")
            else:
                bad.append(f"{name}: {where} `{path}` matches no authorised target "
                           f"({', '.join(a['target'] for a in mech)})")

    # ---- direction 2: nothing authorised went unaccounted for
    accounted = {e["target"] for e in scope["examined"]}
    for a in authorized:
        if a["target"] not in accounted:
            bad.append(f"{name}: `{a['target']}` was authorised ({a['why']}) and `examined` does "
                       "not account for it. A client reads that silence as a clean result")
    declared = {a["target"] for a in authorized}
    for e in scope["examined"]:
        if e["target"] not in declared:
            bad.append(f"{name}: `{e['target']}` is reported as {e['outcome']} and is not in "
                       "`authorized`. Whatever happened there, nobody authorised it")

    if not bad:
        skipped = sum(1 for e in scope["examined"] if e["outcome"] == "not-examined")
        notes.append(f"{name}: {len(touched)} touched path(s) inside {len(mech)} authorised "
                     f"glob(s); {len(authorized)} authorised target(s) accounted for, "
                     f"{skipped} of them declared not-examined")
    return bad, unmeasured, notes


def main(argv: list[str]) -> int:
    if not argv:
        print("UNMEASURED no repository root was given")
        return 2
    root = Path(argv[0])
    targets = [Path(a) for a in argv[1:]]

    try:
        schema = json.loads((root / SCHEMA).read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001 - the reason belongs in the output
        print(f"UNMEASURED the schema is unreadable: {exc}")
        return 2
    if "scope_declaration" not in schema.get("$defs", {}):
        print("UNMEASURED the schema declares no $defs.scope_declaration, so the shape this "
              "gate reconciles against does not exist")
        return 2
    if not (root / DOC).is_file():
        print(f"UNMEASURED {DOC} is missing: the contract this enforces is undocumented")
        return 2

    fixture_mode = not targets
    if fixture_mode:
        base = root / FIXTURES
        targets = sorted(base.glob("good/*.json")) + sorted(base.glob("bad/*.json"))
        if not targets:
            print(f"UNMEASURED no fixtures under {FIXTURES}, and no artifact was given")
            return 2

    findings: list[str] = []
    unmeasured: list[str] = []
    notes: list[str] = []
    for t in targets:
        name = t.name if fixture_mode else str(t)
        try:
            data = json.loads(t.read_text(encoding="utf-8"))
        except Exception as exc:  # noqa: BLE001
            unmeasured.append(f"{name}: unreadable ({exc})")
            continue

        bad, unm, note = reconcile(data, schema, name)

        if not fixture_mode:
            findings.extend(bad)
            unmeasured.extend(unm)
            notes.extend(note)
            continue

        # A fixture under bad/ that validates cleanly proves nothing, and one
        # that fails for a reason other than its own is the same defect as a
        # green gate: the right exit code for the wrong motive.
        if t.parent.name == "bad":
            problems = bad + unm
            if not problems:
                findings.append(f"{name}: a fixture under bad/ reconciled cleanly, so it proves "
                                "nothing")
                continue
            sidecar = t.with_suffix(".expected")
            if not sidecar.is_file():
                findings.append(f"{name}: no .expected sidecar saying which defect it stands for")
                continue
            needle = sidecar.read_text(encoding="utf-8").strip()
            if not any(needle in p for p in problems):
                findings.append(f"{name}: rejected, but for the wrong reason - expected "
                                f"{needle!r}, got {problems[0]!r}")
        else:
            findings.extend(bad)
            unmeasured.extend(unm)
            notes.extend(note)

    for n in notes:
        print(n)
    for u in unmeasured:
        print(f"UNMEASURED {u}")
    for f in findings:
        print(f"FINDING {f}")

    if findings:
        return 1
    if unmeasured:
        return 2
    print(f"measured: {len(targets)} artifact(s) reconciled in both directions")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
