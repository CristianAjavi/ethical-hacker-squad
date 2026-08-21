# Triage rules — the ten questions that rule a finding out

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

It does not decide whether a procedure's detection pattern is right — a wrong pattern produces a finding these rules cannot save you from. It does not measure severity beyond the `FP-10` downgrade. And a rule answered honestly can still be answered wrongly: the rules make the reasoning visible and checkable, not automatically correct.

## Citing them from a procedure

A procedure's `What rules it out (false positive)` field **ends with a line naming the rules it invokes**:

```
Rules: FP-02, FP-04, FP-08
```

The bullets stay as they are — they say what the exculpation looks like in that stack. The line says which questions this class demands, so a specialist knows what must be answered before reporting, and a gate can check that the field was written as a triage step rather than as prose.

Rules are cited where they apply. A procedure that genuinely invokes only one rule cites one, and a procedure whose exculpations are entirely class-specific says so with `FP-09`.
