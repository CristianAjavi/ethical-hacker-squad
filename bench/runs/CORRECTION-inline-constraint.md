# A correction that applies to seven rounds: the arms were not given the same instruction

Found on 2026-08-26 while re-reading the ledger, not by a gate. It changes how seven pages
should be read and it is written where a reader of any of them will meet it.

## What happened

From the refutation-stage round onward, every `mantis` launch carried this line:

> Run the stages inline yourself rather than spawning sub-agents: the harness caps concurrency,
> which is the condition under which mantis documents its sequential fallback.

**No `ours` launch carried anything like it**, because this project's corpus is nine role files
executed by one agent — there was nothing to constrain.

The justification was real: `mantis` run 4 of the eleven-product round, which ran unconstrained,
recorded that its sub-agent parallelism hit the harness concurrency limit and it used its own
documented sequential fallback anyway. That was written up at the time as a reason to believe
the deviation immaterial, explicitly **not** as proof.

## Why it is a correction and not a footnote

`google/mantis` is **nineteen skills forming a supervised pipeline**, whose entry point is
called `mantis-meta-agent` — *"the persistent supervisor, launching and monitoring the automated
review campaign"*. Its architecture is fan-out plus a review stage that argues in a **fresh
context**. Told to run inline, it becomes what this project already is: one agent reading a
procedure.

So the honest description of seven rounds is: **two prose corpora, each executed by a single
agent.** Not two products as they ship. Every "level on detection" and every "we lead by N" in
those pages is a statement about the corpora, and says less than it appears to about the
products.

## And the evidence shipped with the gap in it

The rounds that ship a `prompts/` directory ship the shared `PROMPT.md` template. **The inline
constraint was never in that template** — it lived in the per-arm launch call, which the
directory does not contain. Worse, `prompts/README.md` on those pages says the arms *"differ
only in which corpus the launch instruction points at and in the mantis arm's stage-contract
paragraph."* That sentence is wrong, it names the smaller difference and omits the larger, and
this author wrote it.

`gate-bench-integrity.sh` did not catch it: it checks that a comparative round ships prompts,
and the round shipped prompts. A file can be present and incomplete.

## The suppression was symmetric, and that is worse

The paragraph above says no `ours` launch carried a constraint "because this project's corpus is
nine role files executed by one agent — there was nothing to constrain." **That is wrong, and it
is the more serious half of this correction.**

`SKILL.md` §3 is called *Form the adaptive squad* and says:

> Staff two to four relevant specialists… **Run them in parallel** when their files and tests do
> not collide. Reserve capacity for `ehs-remediator` and `ehs-verifier`.

Every prompt in every round pointed at **one** role file and said other roles "apply where the
tree calls for them". A single agent read them. **This project never formed a squad either.**

So the honest statement is not that one arm was constrained. It is that **neither product ran as
designed in nine rounds**, and a product whose entry point is called *the adaptive squad* was
measured without ever adapting or forming one.

It also reinterprets an earlier finding. `VER-09` fired **zero times** across four measured runs,
and that was written up as evidence that a rule in a file the executor reads is a rule the
executor can ignore. It is at least as likely that it fired zero times because **`ehs-verifier`
is a separate specialist that §3 reserves capacity for, and there was never a second agent to
be it.** That page's conclusion is not withdrawn — the rule may still be weak — but its evidence
no longer establishes it, and it now says so.

## What is and is not undone

- **The recall and decoy numbers stand.** They measure what the arms did on the day.
- **No page is edited to a friendlier number**, and no verdict changes: nine rounds, none met
  the band.
- **What narrows is the claim.** "This project is level with `mantis` on detection" must be read
  as *level with `mantis` running as a single inline agent*. Whether it is level with the product
  as shipped is **unmeasured**, and after nine rounds this ledger has to say so.

## What it forces

The next comparative round lets each arm run as its design intends — this project as its roles,
`mantis` as its supervisor with fan-out — and reports the cost of both, since a pipeline that
takes 70 minutes and 682 tool calls is buying its result with something. Until that runs, the
comparison in the affected pages is between corpora and not between products, and each of them
now says so.

Affected: `2026-08-26-refutation-stage`, `2026-08-27-artifact-contract`, `2026-08-27-composition`,
`2026-08-26-four-tools`, `2026-08-26-fp11`, `2026-08-26-scope-field`, and the relaunched arms of
`2026-08-26-coverage-rules`.

## A correction to this correction, made minutes later

The first version of this note was pasted into **fifteen** `prompts/README.md` files by a
glob that did not check which rounds were affected. Twelve of them predate the inline
constraint entirely — the 2026-08-21 and 2026-08-22 rounds never carried it — and
`2026-08-26-join-effect` has no `mantis` arm at all, being a within-arm measurement.

Writing a true correction into a page where it is false is its own defect, and a
particularly bad one on a page whose whole subject is that evidence must say what actually
happened. The note now sits only on the three affected rounds that ship a `prompts/`
directory, and the pointer at the top of a page sits only on the seven affected rounds.
