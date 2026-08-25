# Deviations, written before any arm was scored

## The session lost authentication mid-round

Part-way through, this session's API authentication failed and eight agents died with
`Not logged in`. Four arms had written nothing at all. **A run that did not happen is not a run
that failed**, so none of them was scored as empty; they were relaunched, which is legitimate
precisely because there was no result to select on.

## The relaunched `mantis` runs carry an instruction the originals did not

Runs 1 and 2 were relaunched with an added line: *"do the audit work yourself rather than
spawning sub-agents — a previous attempt lost its whole pipeline when its children died."*

**That instruction alters the arm.** `mantis-meta-agent` is by definition a supervisor that
launches sub-agents, and constraining it is a handicap unless something says otherwise. Runs 3
and 4 ran without it.

What says otherwise is `mantis` run 4's own report, which ran unconstrained and recorded:

> The researcher's Wave-1/2 sub-agent parallelism hit the harness concurrency limit, so its
> documented sequential fallback was used — throughput only, coverage unaffected.

So the harness was already forcing the sequential path on the unconstrained runs, and the
added instruction describes what `mantis` does by itself under this cap. **That is a reason to
believe the deviation is immaterial; it is not proof, and it is not offered as proof.** A
reader who wants to discount runs 1 and 2 has the information to do it, and the arm's per-run
numbers are printed individually so they can.

The alternative — killing and relaunching all four for uniformity — was weighed and not taken.
That choice is recorded here rather than left invisible.

## The corpus author is not independent of this project

The corpus was written by an author instructed not to read this project's procedures, and it
was verified from outside: the key sits outside the tree, no file carries a marker naming a
defect or identifying the tree as a benchmark, and all 60 keyed line numbers were re-checked
against the files.

**That is blinding, not independence.** The brief was still written here, and it specified the
property under test — at least 8 files with more than one independent defect, at least 3 with
three or more, several in manifests. A corpus commissioned to contain the thing being measured
is a fair test of *whether the rules work* and a weak basis for any claim about the world.

## The eleven-product corpus is not re-used

It is retired for this question. Re-running it after changing the product is the fishing these
pages exist to refuse.
