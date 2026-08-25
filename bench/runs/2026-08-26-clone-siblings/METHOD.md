# Method — clone siblings per security finding, fixed before the corpus was touched

Committed **before any number was computed**. This is a descriptive measurement rather than a
hypothesis test, so the discipline that matters is that the method is fixed first: with
normalisation rules chosen after seeing the distribution, any answer can be produced.

## The question

Given a security finding at `file:symbol`, **how many other functions in the same repository
are clones of the one the finding is in?**

Clone research counts clones. Security research counts findings. Nobody has multiplied the
two, and the corpus already argues from both — Wu et al. (FSE 2025) on type-1+type-2 rates
from commercial generators, Spracklen et al. (USENIX Security 2025) on generator persistence.

## Why it is worth measuring rather than citing

**It is falsifiable against this project's own interest.** If the median is 1, the "one
generator defect becomes N" story collapses, and this repository would have been the one to
show it. That is a better position than repeating a claim two vendor datasets already
disagree about.

## The method, fixed here

1. **The unit** is the innermost `FunctionDef` / `AsyncFunctionDef` enclosing the finding's
   line. A finding at module level has no unit and is excluded, counted separately, and
   reported.
2. **Normalisation.** Parse to AST. Replace every identifier — function name, argument names,
   local names, attribute names — with a positional placeholder assigned in order of first
   appearance within the unit. Replace every literal with a placeholder carrying only its
   type. Keep control flow, call structure and operator identity. Drop docstrings, comments
   and all position information.
3. **The hash** is `sha256` of `ast.dump` of the normalised unit, with `annotate_fields=False`.
   Two units with the same hash are **type-1 or type-2 clones** of each other: identical up to
   names and literal values.
4. **The count** for a finding is the number of units in the same repository sharing its hash,
   **including itself**. A unit with no clone therefore scores **1**, not 0.
5. **Minimum size.** Units whose normalised dump is under 200 characters are excluded: a
   two-line getter clones itself across any codebase and would dominate the distribution
   without saying anything about defects. The threshold is declared here, before the run, and
   the excluded count is reported.

## What is measured

Every finding produced by the blinded rounds of 2026-08-25 and 26 that names a file, a symbol
and a line in a target this project still has on disk — `pyload/pyload` at `6c52b198d` and
Django at `08187c94ed`.

Reported: the distribution, the median, the mean, the maximum, the number of findings excluded
for having no enclosing function, and the number of units excluded by the size floor.

## What this sample cannot support

Two repositories, both Python, neither known to be generator-authored. **Nothing here
measures whether AI-written code clones more than human-written code** — that needs a corpus
labelled by authorship, which this is not. What it can support is a narrower and still
unpublished statement: in these repositories, a finding sits in a unit that has *this many*
identical-up-to-renaming siblings. If that number is 1, the amplification story has no support
here and the page says so.
