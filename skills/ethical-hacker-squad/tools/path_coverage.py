#!/usr/bin/env python3
"""Do the guards cover the routes? Two lists, and the join nobody makes.

WHY IT ASKS THAT
    On 2026-08-27 two products with entirely different architectures were run
    against a corpus of composition defects - defects where no single file is
    wrong. Both found essentially every single-file defect (93.8% and 100.0%)
    and lost four in ten composition defects (62.5% and 60.4%). The three
    neither found in any run were three out of three composition.

    The commonest shape, measured across that corpus: a control and the thing it
    covers are declared in different files, and nothing checks that the coverage
    actually covers. A guard tests `request.path.startswith("/internal")` while
    the blueprint mounts at `/api/internal`. Both lines are correct. The guard
    never fires.

    Reading either file harder cannot find that. Holding both and joining them
    can, and the join is mechanical.

WHAT IT DOES
    Extracts path-like literals and labels each occurrence by the company it
    keeps: a ROUTE context (a registration, mount, prefix, location block) or a
    GUARD context (a prefix test, matcher, allow/deny list, exclusion). Then it
    reports two asymmetries:

      DEAD GUARD    a guard path that prefixes no route path anywhere in the
                    tree - a control that cannot fire.
      UNGUARDED     a route path that no guard covers, while a SIBLING under the
                    same parent is covered - the asymmetry that says somebody
                    meant to cover it.

    It knows nothing about any framework. It compares strings, which is why it
    works across Flask, Fastify, chi, nginx, Koa and CDK at once, and why its
    output is a worklist rather than a verdict.

WHAT IT IS NOT
    Not a detector. A dead guard may be dead on purpose; an unguarded sibling
    may be public by design. It cannot see a guard expressed as a regex it
    cannot read, a variable, or a value assembled at runtime - so `cleared` here
    means only *matched by something*, never *safe*.

Exit codes: 0 = measured, no asymmetry | 1 = measured, asymmetries |
            2 = could not measure.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

PATH_LIT = re.compile(r"""['"`]((?:/[A-Za-z0-9_\-.:{}*$<>()\[\]]+)+/?)['"`]""")
# nginx `location /x {` and yaml-ish `- /x` carry no quotes
BARE_PATH = re.compile(r"^\s*(?:location\s+(?:[=~^*]+\s+)?|-\s+)(/[A-Za-z0-9_\-./*]+)")

ROUTE_HINT = re.compile(
    r"\b(route|routes|get|post|put|patch|delete|all|use|register|mount|"
    r"url_prefix|prefix|blueprint|handle|handlefunc|location|path|endpoint|"
    r"add_api_route|addroute|resource|controller|matcher)\b", re.I)
GUARD_HINT = re.compile(
    r"\b(startswith|has_prefix|hasprefix|beginswith|match|matches|"
    r"allow|deny|skip|exclude|exempt|whitelist|allowlist|bypass|"
    r"require|guard|middleware|before_request|onrequest|unless|ignore|acl)\b", re.I)

# Words that DECIDE a line is a registration even when a guard word is also on
# it. Found by this tool's own battery: `register_blueprint(public_bp,
# url_prefix="/api/public")` was read as a guard because the route is *named*
# public. `public`, `protected` and `auth` are route names at least as often as
# they are guard verbs, so they are no longer guard words at all, and a strong
# registration marker wins outright.
ROUTE_STRONG = re.compile(
    r"\b(register|register_blueprint|url_prefix|add_url_rule|app\.(get|post|put|patch|delete|use)|"
    r"router\.\w+|r\.(get|post|put|route|group|mount)|handlefunc|location|mount|add_api_route)\b", re.I)

SKIP_DIRS = {".git", "node_modules", "vendor", "dist", "build", "__pycache__", ".venv"}


def looks_like_path(p: str) -> bool:
    if len(p) < 2 or not p.startswith("/"):
        return False
    if re.fullmatch(r"/+", p):
        return False
    # file paths and content types are not routes
    if re.search(r"\.(js|ts|py|go|rb|java|cs|rs|json|ya?ml|conf|sql|txt|md|png|css|html)$", p, re.I):
        return False
    if p.count("/") == 1 and len(p) > 40:
        return False
    return True


def normalise(p: str) -> str:
    """Collapse parameter syntaxes so /users/:id, /users/{id} and /users/<id> join."""
    q = re.sub(r"[:{}<>$]|\[[^\]]*\]", "", p)
    q = re.sub(r"/[A-Za-z0-9_]*(?=/|$)(?<=/)", lambda m: m.group(0), q)
    q = re.sub(r"//+", "/", q)
    return q.rstrip("/") or "/"


# NAME = "/path" in any of the languages this has to cross. A path literal bound
# to a constant is the commonest way the literal and the guard that uses it end
# up on different lines - and the first real target this tool was pointed at did
# exactly that (`INTERNAL_PREFIX = "/internal"` on one line, `startswith` on
# another). A line-local classifier has, there, precisely the blind spot it
# exists to remove.
ASSIGN = re.compile(
    r"""(?:const|let|var|final|static|val)?\s*([A-Za-z_][A-Za-z0-9_]*)\s*"""
    r"""(?::=|=|:)\s*['"`](/[^'"`]*)['"`]""")


def scan(root: Path):
    routes, guards = {}, {}
    bindings: dict[str, list] = {}
    name_ctx: dict[str, set] = {}
    parsed = 0
    texts = []
    for f in sorted(root.rglob("*")):
        if not f.is_file() or any(d in f.parts for d in SKIP_DIRS):
            continue
        try:
            text = f.read_text(errors="ignore")
        except OSError:
            continue
        parsed += 1
        texts.append(text)
        for i, line in enumerate(text.splitlines(), 1):
            found = [m.group(1) for m in PATH_LIT.finditer(line)]
            bare = BARE_PATH.match(line)
            if bare:
                found.append(bare.group(1))
            if not found:
                continue
            strong = bool(ROUTE_STRONG.search(line)) or bool(bare)
            is_guard = bool(GUARD_HINT.search(line)) and not strong
            is_route = bool(ROUTE_HINT.search(line)) or bool(bare)
            # a bare assignment is neither until its NAME is seen in context
            m = ASSIGN.search(line)
            if m and not is_guard and not is_route:
                bindings.setdefault(m.group(1), []).append(
                    (str(f.relative_to(root)), i, m.group(2)))
                continue
            for p in found:
                if not looks_like_path(p):
                    continue
                where = (str(f.relative_to(root)), i, p)
                if is_guard:
                    guards.setdefault(normalise(p), []).append(where)
                elif is_route:
                    routes.setdefault(normalise(p), []).append(where)
    # Second pass: a bound path is a guard path if its NAME is ever used in a
    # guard context, a route path if used in a route context. This is the join
    # the tool exists to make, applied to its own extraction.
    for name, wheres in bindings.items():
        word = re.compile(r"\b" + re.escape(name) + r"\b")
        g = r = False
        for text in texts:
            for line in text.splitlines():
                if not word.search(line):
                    continue
                if ROUTE_STRONG.search(line):
                    r = True
                elif GUARD_HINT.search(line):
                    g = True
                elif ROUTE_HINT.search(line):
                    r = True
        for f, i, raw in wheres:
            if g:
                guards.setdefault(normalise(raw), []).append((f, i, raw))
            elif r:
                routes.setdefault(normalise(raw), []).append((f, i, raw))
    return routes, guards, parsed


def covers(guard: str, route: str) -> bool:
    if guard == "/":
        return True
    return route == guard or route.startswith(guard.rstrip("/") + "/")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--target", type=Path, required=True)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)

    if not a.target.is_dir():
        print(f"UNMEASURABLE not a directory: {a.target}")
        return 2

    # PARTITION. A repository of independent services shares no path namespace:
    # /admin in one is unrelated to /admin in another. Joined as one tree, almost
    # every route reads as unguarded-while-a-sibling-is-protected.
    #
    # Measured, on a real run rather than on a fixture: pointed at six services
    # at once this emitted 32 UNGUARDED, and the run found the one true DEAD
    # GUARD only by re-running the tool per directory on its own initiative. A
    # tool whose output has to be worked around is a tool that is wrong.
    #
    # The heuristic is deliberately dull: if the target's immediate children are
    # directories and more than one of them holds routes, each is its own
    # namespace. Say so, because a reader who disagrees has to be able to see it.
    subdirs = [d for d in sorted(a.target.iterdir()) if d.is_dir() and d.name not in SKIP_DIRS]
    partitions = [a.target]
    if len(subdirs) > 1:
        with_routes = [d for d in subdirs if scan(d)[0]]
        if len(with_routes) > 1:
            partitions = with_routes
            print(f"  partitioned into {len(partitions)} independent trees "
                  f"({', '.join(d.name for d in partitions)}): a path namespace is per service, "
                  f"and joining them makes almost everything look unguarded")

    rc_worst, tot_routes, tot_guards, tot_parsed, tot_dead, tot_ung = 0, 0, 0, 0, 0, 0
    for part in partitions:
        r, g, n = run_one(part, a, len(partitions) > 1)
        tot_routes += r[0]; tot_guards += r[1]; tot_parsed += n
        tot_dead += r[2]; tot_ung += r[3]
        rc_worst = max(rc_worst, g)
    if len(partitions) > 1:
        print(f"  {tot_routes} route path(s), {tot_guards} guard path(s) in {tot_parsed} file(s) "
              f"across {len(partitions)} tree(s); {tot_dead} dead guard(s), "
              f"{tot_ung} unguarded sibling(s)")
    return rc_worst


def run_one(target, a, prefixed):
    routes, guards, parsed = scan(target)
    if not parsed:
        if prefixed:
            return (0, 0, 0, 0), 0, 0
        print(f"UNMEASURABLE nothing readable under {target}")
        return (0, 0, 0, 0), 2, 0
    if not routes:
        if prefixed:
            return (0, 0, 0, 0), 0, parsed
        print(f"UNMEASURABLE no route-like path literal found under {target}; "
              "this check has nothing to join")
        return (0, 0, 0, 0), 2, parsed

    dead = {g: w for g, w in guards.items() if not any(covers(g, r) for r in routes)}

    covered = {r for r in routes if any(covers(g, r) for g in guards)}
    unguarded = []
    for r in sorted(set(routes) - covered):
        parent = r.rsplit("/", 1)[0] or "/"
        siblings = [s for s in routes if s != r and (s.rsplit("/", 1)[0] or "/") == parent]
        if any(s in covered for s in siblings):
            unguarded.append((r, [s for s in siblings if s in covered]))

    tag = target.name + "/" if prefixed else ""
    if a.json:
        print(json.dumps({
            "tree": str(target), "files": parsed, "routes": len(routes), "guards": len(guards),
            "dead_guards": {g: w for g, w in dead.items()},
            "unguarded_siblings": [{"route": r, "guarded_siblings": s} for r, s in unguarded],
        }, indent=2))
    else:
        for g, w in sorted(dead.items()):
            f, ln, raw = w[0]
            print(f"  DEAD GUARD   {g!r} guards nothing: no route starts with it   [{tag}{f}:{ln}]")
        for r, sibs in unguarded:
            for f, ln, raw in routes[r][:1]:
                print(f"  UNGUARDED    {r!r} has no guard, but sibling {sibs[0]!r} does   [{tag}{f}:{ln}]")
        if not prefixed:
            print(f"  {len(routes)} route path(s), {len(guards)} guard path(s) in {parsed} file(s); "
                  f"{len(dead)} dead guard(s), {len(unguarded)} unguarded sibling(s)")
    return ((len(routes), len(guards), len(dead), len(unguarded)),
            1 if (dead or unguarded) else 0, parsed)


if __name__ == "__main__":
    sys.exit(main())
