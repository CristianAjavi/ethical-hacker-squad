# Amendment — the competitor arms were cancelled before any of them ran

Written **after the four `ours` runs were launched and before any competitor arm was started**.
The pre-registration is not edited; this file records what changed and why, so the change is
visible rather than absorbed.

## What was found

The round was designed with two competitor arms. Before launching them, each product's own
`SKILL.md` was read to pick its correct entry point. **Neither product claims the job this
round measures.**

**`Tencent/AI-Infra-Guard` @ `32df94d`.** Its skills are `aig-scanner`, `edgeone-clawscan`,
`edgeone-skill-scanner` and `aig-agent-redteam`. In its own words, `aig-scanner` is

> "AI security scanning for infrastructure, AI tools / skills, AI Agents, and LLM jailbreak
> evaluation … **Requires AIG_BASE_URL to be configured** … Submits and queries A.I.G scan
> tasks via the `taskapi` endpoint"

It is a client for a remote scanning service, scoped to AI infrastructure, skills and agents.
The rounds here run offline, so its actual mechanism cannot execute at all; and eleven ordinary
web and CLI services are not what it is pointed at. `edgeone-clawscan` audits *"the current
OpenClaw environment"* and installed skills. `edgeone-skill-scanner` scans skills.
`aig-agent-redteam` red-teams agents.

**`google/mantis` @ `56377ad`.** `mantis-advise` says:

> "Proactive security advisor and guardrail assistant for secure code development. Use to query
> threat models, historical vulnerability lineages, verified patch patterns … before and during
> code edits to prevent repeat mistakes. **Don't use for automated multi-pass red-team
> exploitation or fuzzing.**"

It is an advisor consulted *while editing*, and it says in its own description not to use it
for the sweep this round performs.

## Why the arms were cancelled rather than run

Running them would have measured two products at a task neither claims, produced a favourable
number for this project, and that number would have been an artifact of the comparison set. A
band met against non-competitors is not a band met.

**The arms are cancelled. No competitor number from this round exists, favourable or not.**

## What this does to the question that prompted the round

The question was *"are we already the best hacker repo for different products or services built
with vibecoding?"* This round set out to answer it and instead found that **the comparison set
was wrong**, which is a more useful answer than a table would have been:

- The two repositories this project has benchmarked against for four rounds are **an
  AI-infrastructure scanning client** and **an in-editor secure-coding advisor**.
- On the task actually in question — sweep a repository of vibecoded services and report
  exploitable defects — **no competitor has yet been identified**, and *"best"* against a set of
  two non-competitors means nothing.

The earlier comparative pages already refused to claim superiority, on the ground that this
project planted the cases. **That refusal now has a second and independent reason**, and the
tables on those pages should be read with it: the arms were never doing the same job.

## What the `ours` runs are still worth

The four `ours` runs were launched before this was found and are allowed to finish. They
measure **one absolute number**: this project's recall over 54 planted defects across eleven
products it wrote. That is a self-audit, it is registered, and it is reported as a self-audit —
**it ranks nothing**, because after this amendment there is nothing in the round to rank
against.

## What a real comparison would need

A product that claims the same job: pointed at a repository, sweeping it for exploitable
defects, running offline or with its service reachable, and not scoped to AI infrastructure or
to in-editor advice. Until such a product is named and pinned, the *"are we the best"* question
is **not measurable**, and no page here may answer it.

Finding that comparison set is the work. It is a search problem, not a benchmarking problem,
and it is the honest next step.
