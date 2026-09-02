# Scope of work

The contract that says what the squad was allowed to touch, what it was not, when it must stop,
and what it owes as evidence. It is a **versioned artifact reconciled against the run's own
output**, not a paragraph the leader reads once and remembers.

Load this before the first action of an engagement, and again when writing the deliverable.

## Why it is a file

Rules 1-9 of `SKILL.md` are the safety contract and they are good prose. Prose has one failure
mode that matters here: **nothing compares it to what happened.** `engagement.scope` in
`findings.schema.json` was a free-text string — "the exact path, repository or authorized target
the squad was pointed at" — so a finding's `location.path` was never checked against it, and an
authorised target nobody examined was indistinguishable from one that came back clean.

That is not a hypothetical shape. It is the shape this repository keeps finding in itself: a list
checked in one direction. `gate-report-contract.sh` had it, `governance.json` had it,
`verify.sh` had it. Here the missing direction is the expensive one — an audit that quietly did
not look at half of what it was pointed at reads exactly like an audit that looked and found
nothing.

## What the field does

Three competitors turned scope into a file, and it is worth being precise about what each solved,
because two thirds of it is already ours:

| | What they ship | Where it stops |
|---|---|---|
| **PentAGI** (MIT) | A reusable scope-of-work template with an 8-step per-action check: allowed and out-of-scope targets, stop conditions, evidence expectations | A checklist the operator performs. Nothing reads it afterwards |
| **PT-Agents** (MIT) | A scope-guard block embedded in every `Bash`-carrying agent, **grepped for in CI** | Proves the paragraph is present, not that the run obeyed it. **We already ship this** — `gate-agent-tools.sh`, 8 of 8 agents |
| **AgSec** (Apache-2.0) | The target as a portable, versionable, reviewable artifact | Describes the target; does not bind the findings to it |

All three are **pre-action**. None reconciles the declared scope against the engagement that
actually ran. That reconciliation is what this file adds, and it is only affordable because
`findings.json` already exists: the run publishes machine-readable locations, so the comparison is
arithmetic rather than judgement.

## The declaration

`engagement.scope` accepts an object. Every field below is required unless marked otherwise.

```json
{
  "version": "1",
  "authorization": {
    "reference": "issue #123 / contract CPS-2026-14855 / verbal, recorded 2026-09-02",
    "granted_by": "the person or role who can grant it",
    "covers": ["local-analysis"]
  },
  "authorized": [
    {"target": "src/**", "kind": "path", "why": "the application under audit"},
    {"target": "package.json", "kind": "path", "why": "dependency surface"}
  ],
  "out_of_scope": [
    {"target": "infra/terraform/**", "kind": "path",
     "why": "production state; rule 4 requires authorization we do not have"}
  ],
  "stop_conditions": [
    "an active secret is found: escalate, redacted, and stop",
    "a third party would be affected: stop and ask"
  ],
  "evidence_expectations": "findings.json plus the report, with locations inside `authorized`",
  "examined": [
    {"target": "src/**", "outcome": "examined"},
    {"target": "package.json", "outcome": "not-examined",
     "why": "no lockfile present, so the resolved tree could not be read"}
  ]
}
```

`covers` is drawn from a closed list, because "authorised" is not one thing:
`local-analysis`, `remote-scan`, `exploitation`, `credential-testing`, `production-access`.
An action outside what `covers` names is out of scope even if its target is in `authorized`.

`kind` is `path`, `host`, `service`, `account` or `artifact`. Only `path` is reconciled
automatically today; the others are declared, carried into the report, and **reported as not
mechanically checked** rather than silently counted as verified.

## The two directions

A scope check that only asks the first question is the defect this file exists to close.

1. **Every location the run reported falls inside `authorized`, and inside none of
   `out_of_scope`.** A finding outside is not a formatting error — it means the audit touched
   something it was not allowed to touch, and it is the highest-severity thing this gate can say.
   `out_of_scope` wins over `authorized` when a target matches both, always, and the overlap is
   itself reported: an exclusion that has to fight an inclusion is a scope somebody should rewrite.

2. **Every entry in `authorized` appears in `examined`**, as `examined` or as `not-examined` with
   a `why`. This is the direction the field omits. An authorised target absent from `examined` is
   a **gap the deliverable claimed to cover**, and it costs more than a false positive: the client
   reads silence as a clean result.

`not-examined` is a first-class outcome, not a failure. What fails is leaving the entry out.

## Could not measure

The verdict is `2` — never a pass, never a clean scope — when:

- `engagement.scope` is a **string** rather than an object. The legacy form is not wrong; it is
  unreconcilable, and reporting it as "in scope" would be inventing a measurement.
- the scope object is missing a required field, or `authorized` is empty.
- `findings.json` is unreadable, or carries findings with no `location.path`.

A run with no findings at all is not automatically `2`: direction 2 still applies, because
`examined` has to account for the authorised targets whether or not anything was found. That is
precisely the run where a silent gap hides best.

## The pre-action check

Before the first action of an engagement, the leader answers all five. Any `no` stops the run.

1. Is there a scope object, with an `authorization.reference` naming something a person can check?
2. Does the action's target match an entry in `authorized`?
3. Does it match nothing in `out_of_scope`?
4. Is the class of action inside `authorization.covers`?
5. If the answer to 2 is "not yet", is the target being **added to the declaration** rather than
   acted on first and written down after?

Question 5 is the one that gets skipped. A scope amended after the fact is a record, not a
control.

## What this does not do

It does not verify the authorisation is genuine — `authorization.reference` is a string a human
checks, and a gate that claimed otherwise would be lying about the one field that matters most.
It does not reconcile `host`, `service`, `account` or `artifact` targets; those are declared and
reported as unchecked. And it says nothing about whether the examination was any good: a target
marked `examined` by a specialist that read one line is `examined` here. Depth is
`references/traceability.md`'s question, and conflating the two would let a coverage number stand
in for coverage.
