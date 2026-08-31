# The prompt both arms received

One template. Each arm was launched at **its own entry point with no architectural constraint** —
this project at `SKILL.md`, told to form the squad its §3 prescribes; `mantis` at
`mantis-meta-agent`, its supervisor, free to fan out as its pipeline defines.

Unlike the seven rounds covered by [`../../CORRECTION-inline-constraint.md`](../../CORRECTION-inline-constraint.md),
**no arm here was told to run its stages inline.** That correction exists because for seven rounds
one arm was, and the other was launched at a single role file — so neither product ran as designed
and the `prompts/` directory did not record it. This directory records the launch difference that
does exist: the entry point, which is the point of the round.

The relaunched arms carried one extra instruction the first attempt lacked: keep at most four
sub-agents in flight, and **write the report even if a stage never returns**. Three arms of the
first attempt died holding an unwritten report while waiting on sub-agents the harness could not
schedule. That instruction changes scheduling, not method, and it was given to the arm that needed
it — which is recorded here rather than left for a reader to discover.
