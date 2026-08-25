# 2026-08-26 — a check that does not look at the idiom

Issue #53 asked for *"a check a reviewer cannot pass by recognising the idiom"*. This is it,
and the first number on the page is the one that limits it.

## Why it exists

Six independent auditors read `bench/cases/intake-portal/app/audit.py`, reported the
concatenated log line, and named the deferred `%s` line beside it as **the example of doing it
right**. Both carry the same defect; the probe proves one call emits two lines. They were not
careless — they recognised an idiom, and recognition stood in for verification.

So this check does not look at how the string is built. Concatenation, `%s`, f-string and
`.format` are treated identically, because **the interpolation style is exactly what misled
the readers**. It asks one question: does every value reach the sink through something that
neutralises a control character?

## What it separates, on the case that caused the miss

```
UNCLEARED  audit.py:10  record_submission  — arg1:bound `form_id`, arg2:bound `submitter`
UNCLEARED  audit.py:14  record_rejection   — arg0:operands
cleared    audit.py:18  record_export      — arg0:dumps
```

The line six readers called safe is flagged. The one that actually neutralises is cleared, and
the report names `dumps` as what was credited, so a reviewer can disagree with the credit
rather than with a verdict.

## It finds every published advisory of the class we have a key for

| target | keyed defect | model-driven rounds | this check |
|---|---|---|---|
| `intake-portal` | `P-52`, `record_submission` | **0 of 6** — all six called it the safe example | flagged |
| `pyload` @ `6c52b198d` | `add_package`, line 469 | **0 of 4**, then 1 of 3, then 0 of 4 | flagged |
| Django @ `08187c94ed` | `log_response`, line 248 | **1 of 4** | flagged |
| CKAN @ `873d30a477` | `RequestResetView.post`, lines 616 and 650 (`CVE-2024-27097`) | *not measured — this is the fresh target* | flagged |

Four rounds of blinded auditing across three targets could not reliably find the first three. A
deterministic AST pass finds all four, every time, in seconds.

## The fourth one found a false negative in this check first

CKAN was picked as an unused target and the check **cleared both keyed sites**. The cause was a
clever exception in `cleared()`: a call that is not an escaper was credited when all of its
arguments were literals — the *`str(1)` is fine, `str(x)` is not* reasoning. CKAN's reset
endpoint binds `id` from `request.form.get("user")`, a call whose only argument is a literal, so
the value read as neutralised and `'...{}'.format(id)` inherited that.

The exception is gone: **a call that is not an escaper clears nothing, whatever its arguments
look like.** Literal arguments say nothing about what a call returns. Two battery cases hold it
— the advisory shape must be flagged, and a mutant restoring the exception must miss it.

This is what the number below cost.

## And the number that says what it is not

| target | logging calls | uncleared | rate |
|---|---|---|---|
| `pyload` @ `6c52b198d` | 238 | 218 | **92%** |
| Django @ `08187c94ed` | 250 | 211 | **84%** |
| CKAN @ `873d30a477` | 256 | 182 | **71%** |

`pyload` was 106 of 238 before the exception was removed. Removing it more than doubled the
flag rate on that target, and that is the honest trade: the old number bought its precision by
being wrong about a published advisory.

**This is not a detector of vulnerabilities.** It is a *conservative filter*: it flags every
call whose neutralisation it cannot prove, and it cannot see through a function parameter, so
every value arriving from outside the function is uncleared by construction. Most of those 211
Django calls are fine.

What it offers is the property a worklist needs and a judgement cannot promise: **within this
class, it does not miss.** A reviewer working the flagged list will pass the defect; a reviewer
choosing where to look, as four rounds measured, walks past it.

## What it does not do

- **Cross function boundaries.** A value sanitised by the caller reads as uncleared here.
- **Read the handler's formatter.** `json.dumps` escapes a newline, and a consumer that splits
  the JSON back apart would undo that. A cleared result is not a clearance.
- **Rank.** 210 flags in file order is not a priority list, and the rounds already measured
  that ranking is where this corpus loses.

The credited escaper is printed for every cleared call precisely so the `ESCAPERS` list can be
argued with. It is short on purpose, and `strip` is deliberately absent: stripping whitespace
does not remove a newline from the middle of a value.

## It ships

The check lives at `skills/ethical-hacker-squad/tools/log_escaper.py` — inside the plugin, not
in the bench — and `ehs-web-api` runs it as step 0 rather than asking an auditor to recognise
the pattern. `WEB-28` invokes it in place of the hand-written query it used to carry.

That is a real change in what this plugin is: until now a user installed documentation and
agent definitions, and now they install code an agent will run on their machine. So
`gate-plugin-integrity.sh` permits `.py` **only** under a `tools/` directory and only after
parsing it: stdlib-only imports from a named list, no subprocess, no socket, no network module,
no write mode, no `eval`/`exec`/`compile`/`__import__`. Nine cases in its battery hold that
open, one per capability. A tool that needs any of them does not ship.

## Reproduce

```
python3 skills/ethical-hacker-squad/tools/log_escaper.py --target <tree>
python3 skills/ethical-hacker-squad/tools/log_escaper.py --target bench/cases/intake-portal/app/audit.py
```

Exit `1` when something is uncleared, `0` when nothing is, `2` when it could not parse.
