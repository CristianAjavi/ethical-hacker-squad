#!/usr/bin/env python3
"""Count the clone siblings of the unit each security finding sits in.

The method is fixed in `bench/runs/2026-08-26-clone-siblings/METHOD.md`, committed
before this file computed anything. With normalisation rules chosen after seeing
the distribution, any answer can be produced, so the rules are not here to be
tuned: they are here because that page says what they are.

Two units are siblings when their normalised AST hashes match — identical up to
identifier names and literal values, which is type-1 plus type-2 clone detection.
A unit with no sibling scores 1, not 0.

Exit codes: 0 = measured | 2 = could not measure, which is never a pass.
"""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import statistics
import sys
from pathlib import Path

MIN_DUMP_CHARS = 200  # declared in METHOD.md before the run


class Normaliser(ast.NodeTransformer):
    """Identifiers and literals become positional placeholders; structure survives."""

    def __init__(self) -> None:
        self.names: dict[str, str] = {}

    def _slot(self, original: str) -> str:
        if original not in self.names:
            self.names[original] = f"n{len(self.names)}"
        return self.names[original]

    def visit_Name(self, node: ast.Name):
        node.id = self._slot(node.id)
        return self.generic_visit(node)

    def visit_Attribute(self, node: ast.Attribute):
        node.attr = self._slot(node.attr)
        return self.generic_visit(node)

    def visit_arg(self, node: ast.arg):
        node.arg = self._slot(node.arg)
        node.annotation = None
        return self.generic_visit(node)

    def visit_keyword(self, node: ast.keyword):
        if node.arg:
            node.arg = self._slot(node.arg)
        return self.generic_visit(node)

    def visit_Constant(self, node: ast.Constant):
        return ast.copy_location(ast.Constant(value=type(node.value).__name__), node)

    def _fn(self, node):
        node.name = self._slot(node.name)
        node.returns = None
        node.decorator_list = []
        # a docstring is prose, not structure
        if (node.body and isinstance(node.body[0], ast.Expr)
                and isinstance(node.body[0].value, ast.Constant)):
            node.body = node.body[1:] or [ast.Pass()]
        return self.generic_visit(node)

    visit_FunctionDef = _fn
    visit_AsyncFunctionDef = _fn


def unit_hash(node) -> str | None:
    """The hash of one function, or None if it is below the declared size floor."""
    try:
        clone = ast.parse(ast.unparse(node)).body[0]
    except (SyntaxError, ValueError, RecursionError):
        return None
    dump = ast.dump(Normaliser().visit(clone), annotate_fields=False)
    if len(dump) < MIN_DUMP_CHARS:
        return None
    return hashlib.sha256(dump.encode()).hexdigest()


def index_repo(root: Path):
    """Every function in the tree: its hash, and where it is."""
    by_hash: dict[str, int] = {}
    by_file: dict[str, list] = {}
    small = 0
    for path in root.rglob("*.py"):
        try:
            tree = ast.parse(path.read_text(errors="ignore"))
        except (SyntaxError, ValueError, RecursionError):
            continue
        rel = str(path.relative_to(root))
        for node in ast.walk(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                h = unit_hash(node)
                if h is None:
                    small += 1
                    continue
                by_hash[h] = by_hash.get(h, 0) + 1
                by_file.setdefault(rel, []).append((node.lineno, node.end_lineno, node.name, h))
    return by_hash, by_file, small


def enclosing(by_file, rel: str, line: int):
    """The innermost function containing this line, or None."""
    best = None
    for start, end, name, h in by_file.get(rel, []):
        if start <= line <= (end or start):
            if best is None or start > best[0]:
                best = (start, end, name, h)
    return best


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--target", type=Path, required=True, help="the repository the findings are about")
    ap.add_argument("--findings", type=Path, nargs="+", required=True, help="directories of *.findings.json")
    ap.add_argument("--label", required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args(argv)

    if not args.target.is_dir():
        print(f"UNMEASURED the target is not a directory: {args.target}")
        return 2

    by_hash, by_file, small = index_repo(args.target)
    if not by_hash:
        print(f"UNMEASURED no parseable function found under {args.target}")
        return 2

    seen, counts, no_unit, off_tree = set(), [], [], []
    for directory in args.findings:
        for f in sorted(directory.glob("*.findings.json")):
            raw = json.loads(f.read_text(encoding="utf-8"))
            rows = raw.get("findings", raw) if isinstance(raw, dict) else raw
            for r in rows:
                if not isinstance(r, dict):
                    continue
                rel, line = str(r.get("file", "")).lstrip("./"), r.get("line")
                key = (rel, r.get("symbol"), line)
                if key in seen:
                    continue
                seen.add(key)
                if rel not in by_file:
                    off_tree.append(rel)
                    continue
                unit = enclosing(by_file, rel, int(line) if line else 0)
                if unit is None:
                    no_unit.append(f"{rel}:{line}")
                    continue
                counts.append({"file": rel, "unit": unit[2], "siblings": by_hash[unit[3]]})

    if not counts:
        print("UNMEASURED no finding resolved to a function in this target")
        return 2

    values = sorted(c["siblings"] for c in counts)
    report = {
        "label": args.label,
        "target": str(args.target),
        "functions_indexed": sum(by_hash.values()),
        "distinct_shapes": len(by_hash),
        "units_below_size_floor": small,
        "findings_resolved": len(counts),
        "findings_without_enclosing_function": no_unit,
        "findings_in_files_not_in_this_target": len(off_tree),
        "median": statistics.median(values),
        "mean": round(statistics.mean(values), 3),
        "max": values[-1],
        "distribution": {str(v): values.count(v) for v in sorted(set(values))},
        "per_finding": counts,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print(f"  {args.label}: {len(counts)} finding(s) resolved to a function")
    print(f"    functions indexed {sum(by_hash.values())} · distinct shapes {len(by_hash)}"
          f" · below the size floor {small}")
    print(f"    siblings per finding — median {report['median']} · mean {report['mean']}"
          f" · max {report['max']}")
    print(f"    distribution {report['distribution']}")
    if no_unit:
        print(f"    {len(no_unit)} finding(s) had no enclosing function: {', '.join(no_unit[:4])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
