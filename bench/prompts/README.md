# The clauses every bench run prompt must carry

A run prompt is part of the measurement, not context for it. This directory holds the clauses that must appear, identically, in **every** arm of a comparison — because a clause that reaches one arm and not another is a confound wearing the costume of a result.

## `external-sources.txt`

Measured, not hypothesised. In the round of 2026-08-21 one unaided run reported that it had **diffed the target against the upstream `main` branch** and identified two hardening controls present upstream and absent here; one corpus run cited **CVE identifiers** for the defects it found. Neither was authorized or forbidden, because no prompt in this bench had ever said anything about it.

Finding a defect by diffing against a fixed upstream is not the act of finding it by reading the code. An arm that does it is not performing the task the other arm is performing, and any recall number from such a pair measures library familiarity rather than review. Consistency is unaffected — it compares runs of one arm — but recall is not.

So the policy is now stated, identically, in both arms of every future round. `gate-bench-integrity.sh` enforces it: a run whose `prompts/` directory omits the policy, and whose README does not disclose that the policy was unstated, fails.

**Rounds published before 2026-08-21 evening carried the silence.** Their recall numbers are not withdrawn — nothing about them is shown to be wrong — but they are marked, and no recall claim from them should be repeated without that mark.
