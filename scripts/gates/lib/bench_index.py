"""Every directory under bench/runs/ must be reachable from an index.

A run that exists and nothing points at is not published, whatever the file
system says. This project's measured advantage is that a reader can CHECK the
numbers - it answers yes to all six axes of a transparency rubric where no other
product exceeds one - and a result nobody can navigate to is outside that claim.

It is not hypothetical: the check was written after a run was added to this
repository and left unlinked by the person adding it, in the same session.

WHAT COUNTS AS AN INDEX
  Any document that is meant to be read from the outside: bench/README.md, the
  top-level README.md, CHANGELOG.md, docs/*.md. A link from a run to another run
  does NOT count - runs citing each other is a graph with no entrance.

WHAT THIS DOES NOT DECIDE
  Whether a run is a measurement, a pre-registration, a retraction or a patch
  bench. That taxonomy is an editorial judgement about what the project claims,
  it is not derivable from the tree, and a gate that invented it would be
  enforcing its author's opinion. This asks one mechanical question: can a
  reader get there.

Output, one finding per line:
    UNINDEXED|<run>
    BROKEN|<document> -> <target>
    STAT|<key>|<value>
"""

import pathlib
import re
import sys


def main(argv):
    root = pathlib.Path(argv[1] if len(argv) > 1 else ".")
    runs_dir = root / "bench" / "runs"
    if not runs_dir.is_dir():
        print("ERR|bench/runs does not exist: there is nothing to index")
        return 2

    runs = {p.name for p in runs_dir.iterdir() if p.is_dir()}
    if not runs:
        print("ERR|bench/runs holds no run: an empty bench cannot be checked against an index")
        return 2

    indexes = [root / "bench" / "README.md", root / "README.md", root / "CHANGELOG.md"]
    indexes += sorted((root / "docs").glob("*.md")) if (root / "docs").is_dir() else []
    indexes = [p for p in indexes if p.is_file()]
    if not indexes:
        print("ERR|no index document was found to check against")
        return 2

    referenced = set()
    for doc in indexes:
        try:
            text = doc.read_text(encoding="utf-8")
        except OSError as exc:
            print("ERR|%s is not readable: %s" % (doc, exc))
            return 2
        for m in re.finditer(r"(?:bench/)?runs/([A-Za-z0-9._-]+)/?", text):
            name = m.group(1)
            if name in runs:
                referenced.add(name)
            else:
                print("BROKEN|%s -> runs/%s" % (doc.relative_to(root), name))

    for name in sorted(runs - referenced):
        print("UNINDEXED|%s" % name)

    print("STAT|runs|%d" % len(runs))
    print("STAT|indexed|%d" % len(referenced))
    print("STAT|index_documents|%d" % len(indexes))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
