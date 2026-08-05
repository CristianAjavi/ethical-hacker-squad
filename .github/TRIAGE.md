# Deterministic triage of external input

Hard rule of this repo: **the labels of an external submission are derived from form
fields, never from the judgement of an LLM**, and no workflow processes content written
by strangers.

## How it is enforced today

The **template choice is the field**. Issue forms do not support conditional labels:
`labels:` is template level and applies the same way to every issue created with it
([syntax for issue forms][forms]). That is why there is one template per category, each
one with its own hardwired `labels:`:

| Template | Labels applied |
|---|---|
| `1-false-positive.yml` | `type/false-positive`, `origin/human`, `status/needs-triage` |
| `2-false-negative.yml` | `type/false-negative`, `origin/human`, `status/needs-triage` |
| `3-knowledge-gap.yml` | `type/knowledge-gap`, `origin/human`, `status/needs-triage` |
| `4-bug.yml` | `type/bug`, `origin/human`, `status/needs-triage` |

`config.yml` sets `blank_issues_enabled: false`, which removes the blank issue (the only
path in with no label at all), and diverts vulnerability reports to the private advisory
form **before** they get published in a public issue.

The `area/<role>` and `severity/<value>` labels are **not** applied automatically: they
live in dropdowns whose options are literally the suffixes of those labels
(`scripts/gh/labels.sh` creates the taxonomy). A maintainer copies them without exercising
judgement: the answer is in the issue body, as exact, closed text.

Attack surface of this design: **zero**. No `issues:` trigger, no token, no parser, no LLM
reading text from strangers.

## Option evaluated and REJECTED: parsing the dropdowns in a workflow

The body of an issue created from a form renders predictably (`### <field label>`, a blank
line, then the value; empty optional fields become the literal `_No response_`), so it
would be technically possible to derive `area/*` and `severity/*` in a workflow: split on
`/^### /`, compare the value against a closed allowlist, and apply no label unless there is
an exact match.

It is rejected for two reasons:

1. **It requires `on: issues`**, that is, a workflow triggered by content written by anyone
   and needing `issues: write` to label. That is exactly the kind of channel the hard rules
   of this repo forbid, and the benefit (two finer-grained labels) does not pay for that
   surface.
2. **The format is not a stable contract.** `### label` and `_No response_` are verified
   empirically on real issues, but GitHub does not document them as a guarantee. Parsing
   them would mean building automation on something that can change without notice, and a
   parser that fails silently leaves issues unlabeled.

If the policy is ever revisited, this is the note to reread first.

[forms]: https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms
