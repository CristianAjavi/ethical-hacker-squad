#!/usr/bin/env python3
"""Measurement core of gate-protected-paths.sh (G7).

An automation that can edit its own limits has none. The paths in
scripts/gates/data/protected-paths.json define what this system may do and what
it may read; a change to them that carries a mark of automation fails, and one
that carries none is listed for a human to review.

WHAT CHANGED, AND WHY IT HAD TO
  Until 2026-09-01 the single question "is the editor an automation?" was
  answered by the BRANCH PREFIX, and the branch is named by whoever is editing.
  In PR #72 an agent raised `MAX_TREE_BYTES` from 655,360 to 786,432 inside
  `scripts/gates/**` - the literal case in this gate's own docstring - and this
  gate signed it green, because the branch was called `loop/...` and the list of
  automation prefixes says `bot/`. The control that forbids an automation from
  editing its own limits was asking the automation whether it was one.

  The fix is not a longer prefix list; any list of names has the same hole. It is
  that a self-declaration is worth something in exactly one direction:

      an admission INCRIMINATES, a denial EXCULPATES NOTHING.

  So the branch prefix stays, demoted from classifier to one incriminating
  signal, and a second one joins it that the editor does not choose as a name:
  the marks its own harness writes into the commits - a `Claude-Session:`
  trailer, an `@anthropic.com` or `[bot]` identity. Measured on the four commits
  merged as PR #72: all four carry the trailer. The mark can be stripped, and
  then this gate is back where it was - but stripping it is an act, where
  choosing a branch name was not even a decision.

  And nothing is called human any more. There is no evidence available at gate
  time that proves a person made a change: a PR approval does not exist yet when
  CI runs, and every other signal is written by the editor. So the third state is
  written down as what it is - UNATTRIBUTED - and it does not pass silently.

Four measurements:

  1. drift      the fenced list under `## G7 - Protected paths` in
                docs/gate-requirements.md matches the data file exactly. The rule
                and the sentence that documents it cannot diverge.
  2. verdict    a change marked as automated that touches a protected path fails,
                naming the path, the pattern, and WHICH signal caught it.
  3. visibility an unattributed change touching one is reported, never silently
                allowed, so the reviewer knows what to look at.
  4. honesty    if the commit range could not be read AND the diff touches a
                protected path, half the classifier did not run: that is
                could-not-measure, not a pass.

  5. override   a maintainer may let one marked change through, and the only
                channel for that is OUTSIDE the diff: a label on the pull
                request. It is not part of the change: no branch name, commit or
                diff line carries it, so granting one is a separate act visible in
                the pull-request timeline, and the run says loudly it was used.

  6. legibility the UNATTRIBUTED listing puts the paths that carry weight first
                and folds negative-proof material into one counted line. Measured
                across the 28 merged changes that tripped this gate: 38 of the 150
                paths it named were fixture inputs, and on the worst change 2
                genuine limits sat under 19 lines of them. This is a DISPLAY
                decision and only that - a finding names every path, an override
                names every path, and nothing leaves `paths`. See
                `$comment_why_not_narrowed` in the data file for the exemption
                this replaced and the measurement that refused it.

THE LIMIT, WRITTEN DOWN BECAUSE IT IS REAL
  In a single-maintainer repository there is NO signal at gate time that
  separates the maintainer from the maintainer's agent: they commit with the
  same account and the same email. So this gate cannot prove a person made a
  change, and it does not try. What it does is make the class impossible to pass
  unnoticed - the failure names the signal that marked the change and every limit
  it moved - and put the decision to proceed somewhere the automation cannot
  reach on its own.

Usage: protected_paths.py <repo-root> <branch> <changed-files-file>
                          [<authorship-file>] [<override-label>]

The authorship file is one line per commit in the range, TAB-separated:
`<sha>\t<author name and email>\t<committer name and email>\t<trailers>`.
`-` or an absent argument means the range could not be read. The override label
is `-` when absent.

A branch of `-` or an unreadable file list is could-not-measure, never a pass.

EXIT: 0 measured fine · 1 measured, findings listed · 2 could not measure
"""

from __future__ import annotations

import fnmatch
import json
import re
import sys
from pathlib import Path

DATA = "scripts/gates/data/protected-paths.json"
DOC = "docs/gate-requirements.md"
DOC_BLOCK = re.compile(r"##\s*G7\s*—\s*Protected paths.*?```\n(.*?)```", re.S)


class Unmeasured(Exception):
    pass


def matches(path: str, pattern: str) -> bool:
    if pattern.endswith("/**"):
        return path == pattern[:-3] or path.startswith(pattern[:-2])
    return fnmatch.fnmatch(path, pattern)


def read_authorship(arg: str) -> list[str] | None:
    """The commit range as lines, or None when it could not be read.

    None and [] are different answers and the difference is the whole point of
    measurement 4: [] is "I read the range and it is empty", None is "I could not
    read it". Collapsing them would turn a blind gate into a green one.
    """
    if arg in ("", "-"):
        return None
    try:
        return [ln for ln in Path(arg).read_text(encoding="utf-8", errors="replace").splitlines()]
    except OSError:
        return None


def fold_group(path: str, groups: list[dict]) -> dict | None:
    """The listing group `path` belongs to, or None when it must be named in full.

    Plain `fnmatch`, where `*` crosses `/`: these patterns describe a REGION of
    the tree, not one directory level, and they are deliberately not the `/**`
    form `matches()` implements for `paths`. An `except` entry wins over a match,
    which is what keeps a `.expected` assertion out of the fold - the input is
    the proof, the assertion is what says the proof proved anything.
    """
    for g in groups:
        pats = [str(m) for m in (g.get("match") or [])]
        skip = [str(e) for e in (g.get("except") or [])]
        if any(fnmatch.fnmatch(path, m) for m in pats) and not any(
                fnmatch.fnmatch(path, e) for e in skip):
            return g
    return None


def fold_bucket(path: str, group: dict) -> str:
    """Where a folded path is, named at the level the pattern is about.

    Grouping by the file's own parent directory was the first attempt and it made
    the fold LONGER than the list it replaced: a family whose fixtures nest one
    level deeper produced thirteen distinct parents on a single line. The level a
    reader needs is the one the PATTERN names - for
    `scripts/gates/fixtures/*/bad/*` that is the `bad` directory of each family -
    so the key is the path truncated after the last LITERAL segment of the
    pattern that matched it. A pattern with no literal segment after a wildcard
    falls back to the parent directory, which is the old behaviour and still
    right for a flat group.
    """
    segs = path.split("/")
    best = ""
    for m in [str(x) for x in (group.get("match") or [])]:
        if not fnmatch.fnmatch(path, m):
            continue
        psegs = m.split("/")
        keep = max((i for i, s in enumerate(psegs) if "*" not in s), default=-1)
        cut = "/".join(segs[:keep + 1]) if 0 <= keep < len(segs) else ""
        if len(cut) > len(best):
            best = cut
    return best or path.rsplit("/", 1)[0]


def print_listing(touched: list[tuple[str, str]], groups: list[dict]) -> None:
    """The paths a maintainer has to look at, the ones that carry weight first.

    FOLDING IS A DISPLAY DECISION AND NOTHING ELSE. It never reaches a finding,
    never reaches the override listing, never changes a verdict, and never takes
    a path out of `paths`. This function is called from the two branches that
    say "allowed, go and look" and from nowhere else.

    It exists because of a measurement. Across the 28 merged changes that tripped
    G7, 38 of the 150 paths it named were fixture inputs - and on the worst of
    them the 2 genuine limits sat under 19 lines of negative-proof material. A
    reviewer who has to find two lines in twenty-one finds neither, and the
    control that names everything equally is the control that gets skimmed. The
    same measurement is why the fixtures were NOT exempted instead: G7 fired on
    fixtures ALONE in 0 of those 28, so an exemption would have cost 38 paths
    their who-signal and saved not one firing.
    """
    shown = [(f, p) for f, p in touched if fold_group(f, groups) is None]
    folded: dict[str, tuple[dict, list[str]]] = {}
    for f, _p in touched:
        g = fold_group(f, groups)
        if g is not None:
            folded.setdefault(str(g.get("label") or "folded"), (g, []))[1].append(f)
    for f, p in shown:
        print(f"  - {f} (matches `{p}`)")
    for label, (g, files) in folded.items():
        where: dict[str, int] = {}
        for f in files:
            k = fold_bucket(f, g)
            where[k] = where.get(k, 0) + 1
        spread = ", ".join(f"{d} ({n})" for d, n in sorted(where.items()))
        head = (f"  - {len(files)} {label}, folded into this line so the "
                f"{len(shown)} above stay findable")
        if not shown:
            # The case the measurement has never seen. Saying "so the 0 above stay
            # findable" would be nonsense, and a fold with nothing to protect has
            # to say plainly that nothing else moved.
            head = (f"  - {len(files)} {label} and NOTHING ELSE: no other limit moved "
                    f"in this change")
        print(head + f": {spread}")
        print(f"    they are still protected and still G7's business; folded because "
              f"{g.get('watched_by')}")


def automation_marks(branch: str, prefixes: list[str], commits: list[str] | None,
                     markers: dict) -> list[str]:
    """Every incriminating signal found, each named so the finding can cite it.

    One direction only. Each entry here is a reason to call the change automated;
    an empty list is NOT a reason to call it human.
    """
    found: list[str] = []
    for p in prefixes:
        if branch.startswith(p):
            found.append(f"the branch name starts with `{p}`, which this repository "
                         f"reserves for automation")
    if commits:
        keys = [str(k) for k in markers.get("trailer_keys", [])]
        ids = [str(s) for s in markers.get("identity_substrings", [])]
        for line in commits:
            sha = line.split("\t", 1)[0][:9] or "?"
            for key in keys:
                if f"{key}:" in line:
                    found.append(f"commit {sha} carries a `{key}:` trailer, which an agent "
                                 f"harness writes and a person does not type")
            low = line.lower()
            for sub in ids:
                if sub.lower() in low:
                    found.append(f"commit {sha} names `{sub}` as an author or committer")
    # One reason per kind is enough for a reviewer; twenty commits with the same
    # trailer is one fact, not twenty.
    seen, unique = set(), []
    for f in found:
        kind = re.sub(r"commit \S+ ", "", f)
        if kind not in seen:
            seen.add(kind)
            unique.append(f)
    return unique


def main() -> int:
    if len(sys.argv) < 4:
        raise Unmeasured("usage: protected_paths.py <repo-root> <branch> <changed-files-file> "
                         "[<authorship-file>]")
    root = Path(sys.argv[1]).resolve()
    branch = sys.argv[2]
    listing = Path(sys.argv[3])
    commits = read_authorship(sys.argv[4] if len(sys.argv) > 4 else "-")
    override = (sys.argv[5] if len(sys.argv) > 5 else "-").strip()
    override = "" if override == "-" else override

    try:
        data = json.loads((root / DATA).read_text(encoding="utf-8"))
        declared = list(data["paths"])
        prefixes = list(data["automation_branch_prefixes"])
        markers = dict(data.get("automation_commit_markers") or {})
        fold = list((data.get("listing_fold") or {}).get("groups") or [])
    except (OSError, ValueError, KeyError) as exc:
        raise Unmeasured(f"{DATA} is unusable: {exc}") from exc

    findings: list[str] = []
    checks = 0

    # ---- 1. the doc and the data file say the same thing ---------------
    try:
        doc = (root / DOC).read_text(encoding="utf-8")
    except OSError as exc:
        raise Unmeasured(f"cannot read {DOC}: {exc}") from exc
    m = DOC_BLOCK.search(doc)
    checks += 1
    if not m:
        findings.append(
            f"{DOC}: there is no fenced path list under `## G7 — Protected paths`; the rule is "
            "enforced from a data file nobody can read next to its explanation")
    else:
        documented = [ln.strip() for ln in m.group(1).splitlines() if ln.strip()]
        if documented != declared:
            findings.append(
                f"{DOC}: the documented G7 list and {DATA} differ - documented only "
                f"{sorted(set(documented) - set(declared))}, enforced only "
                f"{sorted(set(declared) - set(documented))}"
                + ("" if set(documented) != set(declared) else " (same paths, different order)"))

    if branch == "-" or not branch:
        raise Unmeasured("the branch under test is unknown; a protected-path check that cannot "
                         "tell whose branch it is has not run")
    try:
        changed = [ln.strip() for ln in listing.read_text(encoding="utf-8").splitlines() if ln.strip()]
    except OSError as exc:
        raise Unmeasured(f"cannot read the changed-file list ({listing}): {exc}") from exc

    blind = ""
    marks = automation_marks(branch, prefixes, commits, markers)
    touched = [(f, p) for f in changed for p in declared if matches(f, p)]
    range_read = "unreadable" if commits is None else f"{len(commits)} commit(s)"

    print(f"measured: branch {branch!r}, commit range {range_read}, "
          f"{len(changed)} changed file(s) against {len(declared)} protected pattern(s), "
          f"{checks + len(changed)} checks")

    # ---- 2, 3 and 4 ----------------------------------------------------
    if not touched:
        print("no protected path in this diff")
        if marks:
            print(f"marked as automated ({marks[0]}), but it touched none of the limits")
    elif marks:
        for mark in marks:
            print(f"automation signal: {mark}")
        if override:
            # Loud on purpose. An override that reads like a pass is a pass, and the
            # whole value of this channel is that using it leaves a mark of its own.
            print(f"OVERRIDDEN by the pull-request label `{override}`. A maintainer decided "
                  f"this marked change may move the limits below. The label lives on the pull "
                  f"request, not in the diff, so granting it was a separate act, "
                  f"recorded in the pull-request timeline rather than in this change:")
            for f, p in touched:
                print(f"  - {f} (matches `{p}`) - MOVED BY AN AUTOMATION, WITH CONSENT")
        else:
            for f, p in touched:
                findings.append(
                    f"this change is marked as automated and its diff touches {f} (protected by "
                    f"`{p}`); an automation that can edit its own limits has none. Signal: "
                    f"{marks[0]}")
    elif commits is None:
        # Half the classifier did not run and the diff is in the half that matters.
        # Reporting this as the old "human branch, allowed" would be the same
        # mistake one level down: absence of a reading is not absence of a mark.
        print(f"{len(touched)} protected path(s) in this diff:")
        print_listing(touched, fold)
        blind = (
            "the commit range could not be read, so the only automation signal left was the "
            "branch name - which is chosen by whoever is editing. A protected path was touched "
            "and this gate cannot say by what. Pass --authorship, or run where the base ref "
            "resolves")
    else:
        print(f"UNATTRIBUTED: {len(touched)} protected path(s) in this diff carry no automation "
              f"mark, allowed and listed so the reviewer knows where to look:")
        print_listing(touched, fold)

    if override and not marks:
        print(f"NOTE: the label `{override}` is on this pull request and nothing needed it. "
              f"An override standing on a change that carries no automation mark is worth "
              f"removing, or the next reader learns to expect it.")
    print("NOT MEASURED: whether the change to a protected path is a good one. This gate asks who "
          "is changing it, not whether they should.")
    if touched and not marks and commits is not None:
        print("NOT MEASURED: whether a PERSON made this change. No signal available when this gate "
              "runs proves that - a pull-request approval does not exist yet, and everything else "
              "is written by the editor. `UNATTRIBUTED` means no mark was found, never that a "
              "human was.")

    for f in findings:
        print(f"FINDING {f}")
    if findings:
        # A drift finding is a determinate failure and outranks a partial blindness:
        # both block, and only one of them tells the reader what to go and fix.
        return 1
    if blind:
        print(f"UNMEASURED {blind}")
        return 2
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Unmeasured as exc:
        print(f"UNMEASURED {exc}")
        sys.exit(2)
