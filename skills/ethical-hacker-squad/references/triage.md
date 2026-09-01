# Triage rules — the sixteen questions that rule a finding out

Two families. `FP-01`..`FP-10` rule out a **report**: the finding is not real, or not reportable, or not that severe. `DUP-01`..`DUP-06` rule out a **merge**: two findings that look like one are two. Both families end a finding's life as a separate entry, and until this file only the first had rules.

Half the value of this corpus is knowing when **not** to report. Every procedure carries a `What rules it out (false positive)` field, and until now that field was free prose: nothing named the rules, nothing required an answer, and nothing could check that a specialist had worked through them. A distributed discipline that nobody verifies is a discipline in name only.

This file closes that. Ten rules, each with an identifier, each **answerable**, derived from the exculpating conditions the corpus already uses — they were read out of 370 `What rules it out` bullets, not invented.

## How a rule is answered

Each rule asks whether an **exculpating condition** holds. Four answers, and only these four:

| Answer | Meaning | Consequence |
|---|---|---|
| `HOLDS` | The condition is true **and you can point at the artifact that shows it** | The finding is ruled out, or drops to `informational` if the rule says so |
| `DOES_NOT_HOLD` | You checked and it is false | The finding survives this rule |
| `UNKNOWN` | You could not establish it | The finding **cannot** be reported as `confirmed`; `probable` is its ceiling |
| `NOT_APPLICABLE` | The rule does not apply to this class of finding | Nothing |

Three invariants, and they are the point of the file:

1. **A finding reported as `confirmed` has every invoked rule answered, none of them `HOLDS`, and none of them `UNKNOWN`.** An unanswered rule is not a silent `DOES_NOT_HOLD` — this is the same doctrine as the gates' exit code `2`: could-not-measure is never a pass.
2. **`HOLDS` and `UNKNOWN` require a written reason** naming the file, the line, the configuration or the document that supports the answer. "It looked fine" is not an answer.
3. **Absence of evidence is never `HOLDS`.** `FP-08` exists precisely because the tempting move — "they said the platform handles it" — is the most common way a real finding disappears.

Answers travel with the finding, in the `triage` block of the return format in `references/team.md`, and into the report through `references/report.md`.

## The rules

<!-- triage:rules -->
| Id | The exculpating condition | A `HOLDS` requires |
|---|---|---|
| `FP-01` | **A compensating control enforces it in a layer that cannot be skipped.** Row-level security, a mandatory middleware, a server-side invariant, signature verification with a pinned key. | The control's location, and the argument for why no code path reaches the sink around it. A control that a caller may forget is not this rule. |
| `FP-02` | **The value is not attacker-controlled.** A literal, a constant, a value constrained by an allowlist before it reaches the sink, a placeholder such as `${VAR}` or `changeme`. | The origin of the value traced backwards to something outside an attacker's reach. |
| `FP-03` | **The sink is not dangerous in the form it is reached.** Text rather than HTML, a format that does not execute (`safetensors` rather than a pickle), an API that parses instead of evaluating. | The exact sink call, and what the framework does with that argument in the version in use. |
| `FP-04` | **The path does not exist in what ships.** Debug-only, a test fixture, removed by the release build, behind an environment flag that production does not set. | Evidence from the shipped artifact, not from the source. The build that ships is the authority. |
| `FP-05` | **The exposure is intended and bounded.** A public load balancer on `443`, a log agent that needs host access, a minified bundle that is the declared distribution artifact. | What bounds it — and the finding usually **moves** rather than disappearing, to whatever sits behind the intended exposure. |
| `FP-06` | **No boundary is crossed: there is no second principal.** Same user, a private per-user directory, an internal-only binding, an agent unreachable from outside its orchestrator. | The boundary named explicitly. On a local surface this is `local-app.md` §0, and a finding that cannot name a second principal is a hardening note. |
| `FP-07` | **The data has no security value.** Public content, synthetic fixtures, non-personal records — where `PRV-01` decides what is personal, not intuition. | What the data is, and who decided it is not sensitive. |
| `FP-08` | **The control lives outside the repository and the evidence arrived.** An organization ruleset, a provider console setting, a support subscription, a landing-zone policy. | The exported artifact, the ticket or the written statement. **Without it the answer is `UNKNOWN`, never `HOLDS`** — "the platform takes care of it" is the most common way a real finding disappears. |
| `FP-09` | **The construct is not what it looks like.** A Terraform module rather than a root, a Rails partial, legitimate Unicode in Arabic or Hebrew text, an emoji modifier. | The reading that makes it benign, in a sentence a reviewer can check in one step. |
| `FP-10` | **It is real but bounded to `informational`.** A client-side check whose server-side equivalent exists, a missing attestation where provenance is already stored and verified, a defence in depth that is absent but not load-bearing. | Why the impact does not reach the user: this rule downgrades severity, it does not delete the finding, and the finding is still written down. |
<!-- /triage:rules -->

## What this does not do

It does not decide **which** of two merged findings survives, or how to write the surviving one — that is the leader's judgement and it is recorded, not governed. It does not decide whether a procedure's detection pattern is right — a wrong pattern produces a finding these rules cannot save you from. It does not measure severity beyond the `FP-10` downgrade. And a rule answered honestly can still be answered wrongly: the rules make the reasoning visible and checkable, not automatically correct.

## Citing them from a procedure

A procedure's `What rules it out (false positive)` field **ends with a line naming the rules it invokes**:

```
Rules: FP-02, FP-04, FP-08
```

The bullets stay as they are — they say what the exculpation looks like in that stack. The line says which questions this class demands, so a specialist knows what must be answered before reporting, and a gate can check that the field was written as a triage step rather than as prose.

Rules are cited where they apply. A procedure that genuinely invokes only one rule cites one, and a procedure whose class admits **no** exculpation writes `Rules: none (reason).` — `AI-22` does, because only the user can change the squad's rules and never the audited content, and three `VER-*` procedures do, because they always run.

## Merge rules — the six questions that rule a merge out

A false positive is one way a finding stops being reported. **A merge is the other**, and nothing governed it. `references/team.md` orders the leader to deduplicate in three separate places and gives no criterion; the artifact records the outcome nowhere. `engagement.unaided_pass.dropped[].resolution: merged` covers only a candidate absorbed inside **one specialist's own pass** — when the leader folds `ehs-web`'s finding into `ehs-appsec`'s, the absorbed one leaves no trace at all. That is the substitution invariant 4 of `references/findings-artifact.md` was written to make visible, happening one level up where nothing was looking.

These rules are the mirror image of the ones above. Each states a **separating** condition, answered with the same four answers, and a single `HOLDS` means the two findings are two.

### The test a merge has to pass

**Two findings are one when a single fix closes both.** Not when they share a CWE, not when they sit in the same file, not when they read alike. The reader of a report is somebody who is going to repair something, and a merge is a promise that one repair discharges the whole entry.

The test is necessary and not sufficient: `DUP-02` holds even where one fix does close both, because what it protects is the inventory rather than the repair.

There is another way to ask this question — score the two texts for similarity and merge above a threshold. It needs an embedding provider, it spends third-party credits on every pair compared, and between its merge threshold and its distinct threshold it leaves a band of scores with no rule written for it at all. The test above is deterministic, costs nothing, and its unresolved band has an answer: **do not merge**.

### The two errors do not cost the same

A wrong merge **deletes a finding**: the remediator fixes the sink that got named and never learns of the other one. A missed merge makes the report longer. So the default is asymmetric, and that is a consequence rather than a preference:

- Every separating rule `DOES_NOT_HOLD`, and one fix demonstrably closes both → `duplicate_of`. The absorbed finding **stays in the artifact with its own id**; it is rendered under its parent, not deleted.
- Any rule `HOLDS` → two findings. Name the rule and stop.
- Any rule `UNKNOWN` → **`possible_duplicate_of`, never a merge.** Both ship, both are counted, and the pair is named so a reader can collapse it if it turns out to be one.

<!-- triage:merge-rules -->
| Id | The separating condition | A `HOLDS` requires |
|---|---|---|
| `DUP-01` | **One source, two sinks.** The same attacker-controlled value reaches two different dangerous operations. A fix at the source closes both; a fix at either sink closes one. | The two sink locations, and the observation that the recommendation being made is **not** at the source. Where the recommendation is at the source and no other path reaches either sink, this does not hold and the pair may merge. |
| `DUP-02` | **Two sources, one sink.** Two independent entry points feed one dangerous operation. | The two source locations. This rule holds **even when one fix closes both**: what it protects is not the repair but the record that the second entry point was found, without which the next reader cannot tell whether it was considered or missed. |
| `DUP-03` | **Same class, same file, different line.** Two occurrences of one pattern at two lines are two edits. | The two line numbers. They merge only when the repair is a single edit — one shared helper, one configuration value — and then the finding's location is that edit and neither line. |
| `DUP-04` | **Different trust boundary.** The same weakness class with a different principal on the other side: one value unescaped in a server-rendered template and in a client-side sink, one missing check on an internal service and on a public route. | The two boundaries named in the terms `FP-06` uses. A different boundary means a different severity, a different reachability and, nearly always, a different repair. |
| `DUP-05` | **Caller and callee, where the callee has other callers.** A defect in a shared function, reached through one caller, reads as the caller's defect. It is the callee's, and the caller is an instance. | **The count of callers, taken mechanically rather than by eye.** More than one: the finding belongs at the callee with the callers listed as instances. Exactly one: they are one finding. This is the rule to measure instead of judging. |
| `DUP-06` | **Different reachability precondition.** The same defect, one instance reachable unauthenticated and the other behind a role, a feature flag or a non-default setting. | The precondition that differs, in the terms `vocabulary.md` uses to separate `critical` from `high`. Merging keeps the higher severity and silently rewrites the other instance's preconditions, which makes the surviving entry false about half of what it covers. |
<!-- /triage:merge-rules -->

### What a merge costs to claim

A finding carrying `duplicate_of` carries `merge_rules` with every rule answered and none `HOLDS` — the same contract a `confirmed` finding has with `FP-01`..`FP-10`. `possible_duplicate_of` carries no such obligation: it is the state for *not having decided*, and charging for it would push work toward the merge, which is the direction that loses findings.

These rules are not cited from procedures the way `FP-*` are — a procedure describes one class of defect and cannot know what else the engagement found. They are answered by whoever proposes the merge, which is the leader. A `DUP-` identifier written anywhere in the corpus must exist here, and `gate-triage-rules.sh` checks that in both directions.
