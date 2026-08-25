# Triage stage — arm `without`, run 2

OUTSIDE INFORMATION: only what appears in this prompt and your own reasoning. Nothing else. Do not open files, do not search the repository, and do not use any knowledge of where these cases came from.

Case order seed: `without-2`. Cases digest: `sha256:4c86d0df6c4e2ef76078c7f013d3fe9c0daed413c56d6b6e265b75ff7346734e`.

## The task

For the case below, name the triage rule the offered reason invokes, answer that rule from the closed vocabulary the rules file declares, and state what follows for the finding. Give the reason for the answer, naming the artifact it rests on.

## Reference in context: `vocabulary.md`

# Verdict vocabulary

This file is the **single closed vocabulary** for every judgement the squad emits about a
finding. Four dimensions, one term list each, no synonyms. `team.md`, `report.md`,
`knowledge/remediation.md` and `agents/ehs-verifier.md` all draw from here, and a gate
(`scripts/gates/gate-verdict-vocabulary.sh`) fails when any of them uses a term this file
does not declare.

## Why it exists

Because the drift was real and measured, not hypothetical. Before this file:

| File | What it declared | Divergence |
|---|---|---|
| `references/report.md` | verified / partially verified / **not executed** / blocked | — |
| `agents/ehs-verifier.md` output | verified / partially verified / **not verified** / blocked / **withdrawn** | third and fifth terms unknown to `report.md` |
| `agents/ehs-verifier.md` frontmatter | verified / **partial** / **unverified** | a third spelling, inside the same file as the second |
| `references/team.md` verifier order | verified / **partial** / **unverified** | matches neither of the two lists it is ordering |
| `knowledge/remediation.md` VER-05 | "**four** states": Verified / Partially verified / Not executed / Blocked by authorization | announces four while the agent returns five |

Five spellings of the same idea across four files, for one deliverable. A reader cannot
tell whether `not verified`, `unverified` and `not executed` are three states or one state
written three ways — and neither can the model that has to pick one.

The rest of the field solved this before we did: every rival examined in
`docs/competitive-analysis.md` §2.1 models a finding's confidence as a **typed state**
rather than an adjective. That is 5/5 convergence, the strongest signal in that document.
The idea is theirs; the terms, the criteria and the enforcement below are ours, written
from scratch.

## How to read a definition

Each term carries two things: what it means **operationally** (what must be true for the
term to be honest) and **what distinguishes it from its neighbour** — because the only
terms that ever drift are the adjacent ones. A term you cannot separate from the one next
to it is a term the model will pick at random.

Three rules bind all four dimensions:

1. **A dimension is closed.** If the situation does not fit any term, that is a defect in
   this file, not a licence to invent a word. Report it and extend this file.
2. **Absence of a measurement is never a favourable term.** This is the repository's 0/1/2
   gate doctrine applied to findings: `2 = could not measure` is not `0 = fine`. A check
   that did not run is `not executed`, `blocked` or `inconclusive` — never "verified", and
   never silence.
3. **Never write that a system is "secure" or "has no vulnerabilities".** There is no term
   for that in any dimension, deliberately. You verified specific findings in a specific
   environment at a specific depth.

---

## Dimension 1 — `status`

What the finding **is**, after triage. One per finding, and it changes over the lifecycle:
`candidate` → (`confirmed` | `probable` | `hardening` | `discarded`) → possibly
`withdrawn`.

<!-- vocabulary:declare status -->
| Term | Operational meaning | What separates it from its neighbour |
|---|---|---|
| `candidate` | A match that has not been triaged: a grep hit, a scanner result, a pattern seen while reading. **Internal working state only — it may never appear in a deliverable.** | Against `probable`: a candidate has not been traced at all. A probable finding has been traced and the trace has one named gap. |
| `confirmed` | Source, transformation and sink traced end to end, and impact demonstrated with evidence — a minimal test, a reproduction, or a fact that is unarguable by construction (a live credential in the tree). The only status the remediator may patch. | Against `probable`: nothing is inferred. If you have to write "assuming this endpoint is reachable", it is not confirmed. |
| `probable` | Traced and argued, but one link is inferred rather than observed: reachability assumed, production configuration not seen, a dependency believed to be called. The inference must be named in the finding. | Against `confirmed`: exactly one thing is missing and you can say what it is. Against `hardening`: an exploit path is claimed, only not demonstrated. |
| `hardening` | No weakness was demonstrated and none is claimed. A defence-in-depth improvement: a missing header on an endpoint that leaks nothing, a pin that is absent but whose registry is trusted. | Against `probable`: there is no exploit path being asserted at all. Against severity `informational`: `hardening` says there is nothing to exploit; `informational` says there is, and it grants the attacker nothing. |
| `discarded` | A candidate that died in triage: a compensating control applies, the pattern does not hold in this context, the code is unreachable test scaffolding. Never reported as a finding; may survive as a one-line note when it saves the next reader repeating the work. | Against `withdrawn`: it was never claimed to anyone. Nothing has to be retracted. |
| `withdrawn` | A finding that **was already claimed** — written into a report, handed to the remediator, or sent to the client — and did not survive later scrutiny. It stays visible in the deliverable, with the reason. | Against `discarded`: somebody may already have acted on it. A withdrawal is a correction of a public claim; a discard is ordinary triage volume. |
<!-- /vocabulary:declare -->

**Why `withdrawn` was kept and not merged into `discarded`.** The obvious economy is to
call both of them `discarded` and save a term. It is the wrong economy. `discarded` is
healthy throughput — most raw candidates die there and nobody is affected. `withdrawn` is
the record that **we published something wrong and took it back**, and the client may
already have opened a ticket, scheduled a change window or paid for a fix on the strength
of it. Collapsing the two erases exactly the fact the reader most needs. It also destroys
a measurement: the count of `withdrawn` findings is a false-positive signal about our own
corpus and feeds the knowledge loop (`.github/ISSUE_TEMPLATE/1-false-positive.yml`),
whereas the count of `discarded` findings measures nothing but how much noise the tooling
produced.

**Why `withdrawn` moved from the verification dimension to this one.** `agents/ehs-verifier.md`
used to return it alongside `verified` and `blocked`, which mixed two questions: *what did
the check establish?* and *what is the finding now?* Those are independent — the check that
withdraws a finding is a check that **succeeded**. A verifier that refutes a finding now
returns verification `refuted` and status `withdrawn`, and neither term has to pretend to
be the other.

**Why `candidate` was added rather than left implicit.** `SKILL.md`, `references/tooling.md`
and `knowledge/web-api.md` already use the word for the pre-triage state ("a match is a
candidate, not a finding"). Leaving it undeclared meant the corpus used a verdict term the
vocabulary did not know. Declaring it also makes the important rule expressible: a
`candidate` in a deliverable is a defect, because it is a finding nobody triaged.

---

## Dimension 2 — `severity`

How much the finding matters **in this system**. Never a scanner's label copied across: a
dependency advisory rated critical whose vulnerable symbol is never reached is not critical
here.

<!-- vocabulary:declare severity -->
| Term | Operational meaning | What separates it from its neighbour |
|---|---|---|
| `critical` | Full compromise of the system, or of data belonging to users other than the attacker, reachable without authentication and without a precondition the attacker does not control. | Against `high`: there is no gate left to pass. If an attacker needs a valid session, a role or a non-default setting first, it is not critical. |
| `high` | Significant compromise, but one precondition stands between the attacker and it: a valid account, a specific role, a non-default configuration, a user interaction. | Against `medium`: the blast radius still crosses the trust boundary — other users, other tenants, the host. |
| `medium` | Real impact bounded to a subset: one tenant, the attacker's own data, one non-critical function; or it requires chaining with a second issue that is not itself demonstrated. | Against `low`: the attacker ends up with a capability they did not have before. |
| `low` | The exploit grants the attacker something marginal beyond the position they already held: information they could infer anyway, an action already available to them at that privilege level. | Against `informational`: something is still gained, however small. |
| `informational` | An exploit path exists or a fact is worth recording, and it grants the attacker nothing. Written because the reader needs it, not because it is a risk. | Against status `hardening`: here there is a path and it is worthless. `hardening` means there is no path. |
<!-- /vocabulary:declare -->

The severity floor is deliberate and it is the direction the model gets wrong: **inflation,
not deflation.** The rule that fixes most of it is marginal capability — if the exploit
grants the attacker nothing beyond what they already held, it is `low` or `informational`,
whatever the class of bug is called. A calibration catalogue with explicit caps is backlog
item 8 of `docs/competitive-analysis.md` §5; when it lands it will cite these five terms
and add caps, not new terms.

---

## Dimension 3 — `confidence`

How good the **evidence** is. Severity is about the system; confidence is about us. They
are independent: a `low` confidence `critical` is a legitimate and urgent thing to report,
as long as both words are present.

`confidence` shares the words `high`, `medium` and `low` with `severity`. That collision is
tolerated because renaming would churn eight agent contracts, but it carries a hard rule:
**a confidence value is never written bare.** Always `confidence: high`, never "high".

<!-- vocabulary:declare confidence -->
| Term | Operational meaning | What separates it from its neighbour |
|---|---|---|
| `high` | Reproduced with a test or a request, or read end to end in code we can see, from the attacker-controllable source to the sink. | Against `medium`: nothing in the chain is assumed. |
| `medium` | The chain is traced but one link is inferred rather than observed, and the finding names which one — typically reachability, a production setting, or behaviour of a dependency read from its documentation. | Against `low`: the chain exists and was followed; only one step rests on an argument. |
| `low` | A signal, not a trace: a tool match, a name-based hit, a string in a decompiled artifact, a pattern seen without following it. | Against `medium`: nobody followed the path. This is the level at which `status: candidate` is normal and `status: confirmed` is forbidden. |
<!-- /vocabulary:declare -->

---

## Dimension 4 — `verification`

What the check **established** about a fix or a control. Emitted by the verifier, and by
nobody else — the remediator does not get to declare its own patch verified.

The three terms at the bottom of the table are the same distinction the gates make between
`0` and `2`: they are not weak verdicts, they are the honest absence of one, and each names
a different reason for the absence.

<!-- vocabulary:declare verification -->
| Term | Operational meaning | What separates it from its neighbour |
|---|---|---|
| `verified` | The original case was reproduced before the patch, it does not reproduce after it, the failure is caused by the new control rather than by an unrelated error, and the variant axes of `VER-03` were tried and listed. | Against `partially verified`: no applicable axis was left untried. |
| `partially verified` | The specific case is closed and the check reached the code, but a named class, variant or environment remains open. The open part is named, never left as "further testing recommended". | Against `verified`: something applicable was not covered. Against `inconclusive`: what was covered was actually established. |
| `refuted` | The check ran and established the opposite of the claim: the finding does not hold — the source was not attacker-controllable, the sink was unreachable, a compensating control was already in place. A successful, conclusive check. Sets the finding's status to `withdrawn`. | Against `inconclusive`: this is a conclusion, not the lack of one. Against `verified`: what was demonstrated is that there was nothing to fix. |
| `inconclusive` | The check **ran** and decided nothing: the result was nondeterministic, the harness failed before reaching the code under test, the build broke, the output was ambiguous. Nothing may be concluded from it — least of all that the system is not vulnerable. | Against `not executed`: it did run. Against `blocked`: nothing external prevented it. This is the term for "the test errored", and recording that as a pass is the failure this dimension exists to prevent. |
| `not fixed` | The check **ran**, reached the code under test, and the original case still reproduces after the patch. The finding stays open, the patch does not ship, and what was tried is written down. | Against `inconclusive`: this run established something, and what it established is the opposite of a fix. Against `refuted`: the finding holds; it is the *patch* that does not. |
| `not executed` | The check was in scope, nothing external prevented it, and it was not run: out of time, deprioritised, out of the agreed plan. | Against `blocked`: there is no permission to request and no environment to provide — it simply was not done. Against `inconclusive`: it never started. |
| `blocked` | A named external condition prevented the check: authorization not granted, target unreachable, credentials or environment unavailable. The finding must name **what would unblock it** and leave the check proposed with its procedure. | Against `not executed`: there is a specific thing someone else has to grant or provide, and it is written down. |
<!-- /vocabulary:declare -->

**Why `not verified` was removed rather than kept as the sixth term.** It was the most
ambiguous term in the old set and it is what generated the drift. Read one way it means
"the check ran and settled nothing" (`inconclusive`); read another it means "nobody ran the
check" (`not executed`); read a third it means "the fix is not verified", which is a
statement about the fix rather than about the check and is true of every other term in the
lower half of the table. A term that can be substituted by two other declared terms is not
a term, it is a hole. On top of that it names **the conclusion we failed to reach** instead
of **what we did**, which is precisely the reporting habit `VER-05` exists to break: every
other term here names a fact about the check.

`unverified` and `partial` are removed for the same reason and a smaller one: they were
never definitions, only careless spellings of `not verified` and `partially verified` that
happened to survive in a frontmatter and in a role order.

**Why six terms and not four.** `VER-05` used to say "four states". Four was one too few in
one place and one too many in another: it had no term for the check that succeeds by
refuting the finding (that outcome had been misfiled in the verifier's status list as
`withdrawn`), and it merged "it ran and told us nothing" into "it never ran". The second
merge is the dangerous one — it is the case where a build failure, an `exit 127` or a
missing fixture gets filed as "no bug found". Splitting it out is what makes the negative
verification gate of backlog item 2 expressible at all.

---

## Cross-dimension invariants

These are rules between dimensions. They are **doctrine, not yet gated**: no automation
reads a finding today, because we do not emit a machine-readable finding yet (backlog item
7). Stated here so that the schema, when it lands, has something to encode.

- `status: confirmed` requires `confidence: high`. Confirmed means demonstrated; if
  something is inferred, the status is `probable` and the inference is named.
- `status: confirmed` may not be paired with `verification: inconclusive` when the reason
  for the inconclusiveness is that the reproduction never worked. That combination means
  the finding was never demonstrated, so it was not `confirmed`.
- `verification: refuted` implies `status: withdrawn`. Nothing else does.
- `status: hardening` and `severity: critical` are contradictory: a hardening item asserts
  no exploit path, and severity measures the impact of one.
- `status: candidate` may not appear in a deliverable, at any severity or confidence.
- Severity and confidence are never merged into a single word. "Critical" alone is a
  severity; the confidence must still be written.

---

## Terms this vocabulary rejects

The gate treats these as failures wherever a finding verdict is written. Each one maps to
the declared term that replaces it.

<!-- vocabulary:reject -->
| Rejected | Where it was found | Use instead |
|---|---|---|
| `not verified` | `agents/ehs-verifier.md` output list | `inconclusive` when the check ran; `not executed` when it did not |
| `unverified` | `agents/ehs-verifier.md` frontmatter, `references/team.md` verifier order | `inconclusive` |
| `unconfirmed` | not in this repository; standing ban | `probable` when traced with a gap, `candidate` when not triaged |
| `not reproducible` | not in this repository; it is a GitHub issue label (see aliases) | `refuted` when reproduction failed and that settles it, `inconclusive` when it does not |
| `not vulnerable` | not in this repository; standing ban | say which check ran and what it established: `refuted`, or `inconclusive` if nothing was |
<!-- /vocabulary:reject -->

The last three are pre-emptive. They are the terms every one of these files would have
drifted into next, and banning a term before it appears costs nothing.

**Two words that are *not* on this list, and why that is deliberate.** `partial` and
`secure` are both forbidden as verdicts by the prose of this repository, and neither can be
policed by a gate without firing on correct files. `partial` is a Rails partial, HTTP 206
Partial Content and a partial refund — all three appear or could appear in the web pack.
`secure` is the `Secure` cookie attribute and `SESSION_COOKIE_SECURE`, which
`knowledge/web-api.md` already contains today. Both were tried against the gate and both
produced a false positive on correct text. They are governed by the definitions above and
by human review, and this file says so instead of pretending a grep covers them.

Note also that `not verified` is rejected **everywhere except the three provenance files**
listed under the aliases. If a knowledge pack needs to say that a fact could not be
established at its source, the phrase is *"not confirmed at the source"*, which is what
`traceability.md` already uses.

---

## Aliases in other namespaces

Two term sets in this repository look like verdicts and are **not** finding verdicts. They
are recorded here so nobody "fixes" them into conformance and so the gate knows to leave
them alone.

<!-- vocabulary:alias -->
| Foreign term | Namespace | Closest term here | Note |
|---|---|---|---|
| `severity/info` | GitHub issue labels (`docs/gate-requirements.md`, `scripts/gh/labels.sh`) | `informational` | Same concept, abbreviated for the label. The label namespace is not edited from here. |
| `status/confirmed` | GitHub issue labels | `confirmed` | Labels describe an **issue about the plugin**, not a finding about a target. |
| `status/not-reproducible` | GitHub issue labels | `inconclusive` | About a bug report we could not reproduce, not about a security control. |
| `status/rejected` | GitHub issue labels | `discarded` | Issue triage, not finding triage. |
| `status/blocked` | GitHub issue labels | `blocked` | Same word, different object: the issue is blocked, not the check. |
| `not verified` | `references/traceability.md`, `references/bibliography.md`, `references/tooling.md` | none | Provenance of a **standard or a bibliographic fact** ("could not be confirmed at the source"), not a verification outcome. Excluded from the gate scan by name; see below. |
<!-- /vocabulary:alias -->

---

## How this is enforced, and what the gate deliberately does not do

`scripts/gates/gate-verdict-vocabulary.sh` reads this file as its only source of truth and
follows the repository's exit-code doctrine: `0` measured and conforming, `1` measured and
failing, `2` could not measure — and a `2` is never a pass.

It runs two checks with different scopes, because a single check could not have both
recall and precision:

1. **Declared regions (strict).** Every place that *enumerates* verdict terms is wrapped in
   `<!-- vocabulary:use <dimension> -->` … `<!-- /vocabulary:use -->`. Inside such a region,
   every backticked token must be a declared term **of that dimension**; anything else
   fails, including a real term borrowed from a different dimension. A backticked token
   that is itself a dimension name is the field label and is ignored. The four files listed
   above must each still carry at least one region and a reference back to this file —
   deleting the normalisation is itself a failure.

   A marker may name several dimensions (`vocabulary:use verification status`) when the
   terms are genuinely intermixed, as in the verifier's output where an outcome sets a
   status. **A multi-dimension region is looser**: a token passes if it is declared in any
   of the listed dimensions, so a severity term written on a status line inside such a
   region would not be caught. That is why a region that presents one slot per line — the
   finding format of `team.md`, the finding header of `report.md` — is written as one
   single-dimension region per slot instead. This was found by breaking the gate on
   purpose, not by reasoning about it.
2. **Rejected terms (targeted).** Across the agents and the skill corpus, the rejected
   terms above are matched only when they appear as **markup** — inside backticks or bold —
   which is how this repository writes every verdict. Inside the four normalised files they
   are additionally matched in plain prose, because in those files ordinary English that
   says "not verified" *is* the drift.

**The false-positive problem, and the rule that solves it.** A gate that greps for verdict
words in English prose is a gate that will be switched off within a week. The corpus is
full of legitimate collisions, and one was measured before this file was written:
`knowledge/web-api.md` contains `` `Secure` `` and `` `SESSION_COOKIE_SECURE` `` — the
cookie attribute and a Django setting, not a claim that anything is secure. A naive
blocklist containing `secure` would fail the gate on a correct file, every run.

So the vocabulary obeys a rule about its own terms, and **the gate enforces the rule on
this file** rather than trusting whoever edits it:

> **A rejected term must be a multi-word phrase or carry an `un-`/`non-` prefix.** No bare
> common English word may be added to the rejected list. Single words (`verified`,
> `blocked`, `high`, `low`) are checked **only inside declared regions**, where the markers
> themselves prove the author was writing a verdict.

Adding a term that breaks this rule fails the gate with `1`, naming the term. The rule was
not obeyed on the first attempt: `partial` was on the rejected list, dodged the rule by
being matched as markup only, and duly produced a false positive on `` `partial` `` used
as a refund. Making the rule executable is what removed it. Word-boundary matching handles
the rest — `unverifiable` in `ehs-verifier.md` is not `unverified`, and the gate does not
treat it as such; that pair is a test case.

**Declared blind spots.** Stating them is the point; an unstated exclusion is how a gate
comes to measure nothing.

- `references/traceability.md`, `references/bibliography.md` and `references/tooling.md` are
  excluded from the rejected-term scan. They use `` `not verified` `` about the provenance
  of standards and bibliography, a different namespace (see the alias table). The exclusion
  is by file name, never by glob, so adding one is a visible diff; the gate fails if an
  excluded file no longer exists, so the list cannot rot.
- This file is excluded from the rejected-term scan, since it necessarily contains every
  rejected term. In exchange the gate checks this file against itself: no term may be
  declared in two dimensions, and no term may be both declared and rejected.
- The gate reads **specifications**, not deliverables. It cannot check an actual audit
  report, because we do not yet emit one in a machine-readable form. That arrives with the
  findings artifact of backlog item 7, and this vocabulary is its enum.
- The cross-dimension invariants above are not checked by anything today.


Answer every case. For each one return exactly these four fields:

    case         the case id, copied
    rule         the id of the triage rule the offered reason invokes
    answer       one of HOLDS, DOES_NOT_HOLD, UNKNOWN, NOT_APPLICABLE
    why          one sentence, naming the artifact your answer rests on

Return a single JSON array of those objects and nothing else - no prose before
it, no code fence, no commentary after it. An answer outside the four tokens
above is scored as wrong rather than interpreted.


## The cases
### Case TS-04

**Finding.** Customer name rendered into an HTML template

The invoice renderer passes a customer-supplied display name into a template string that is returned as `text/html`.

`render/invoice.py`
```
from jinja2 import Template

TPL = "<div class='header'>Invoice for {{ name }}</div>"


def render_header(name: str) -> str:
    return Template(TPL).render(name=name)
```

`requirements.txt`
```
flask>=2.0
jinja2>=2.10
psycopg2-binary>=2.9
```

`Dockerfile`
```
FROM python:3.11-slim
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . /app
CMD ["python", "-m", "app"]
```

**The reason offered for not reporting it.** The reviewer says the template engine escapes the value on its way out.

**Evidence available.** render/invoice.py; requirements.txt; Dockerfile

**Evidence that was asked for and did not arrive.** any lock file, `pip freeze` output, or image manifest that resolves the template engine to a single version


### Case TS-10

**Finding.** Workflow runs a third-party action from a moving reference

The release workflow calls a third-party action at a branch reference, so the code it runs can change between runs without the repository changing.

`.github/workflows/release.yml`
```
name: release
on:
  push:
    tags: ['v*']
permissions:
  contents: write
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: some-vendor/publish-action@main
        with:
          token: ${{ secrets.REGISTRY_TOKEN }}
```

**The reason offered for not reporting it.** The reviewer says everything this pipeline touches is open-source code that anyone can read, so there is no sensitive material at stake.

**Evidence available.** .github/workflows/release.yml


### Case TS-05

**Finding.** Administrative command endpoint in the application

`debug_routes.py` registers `/__admin/exec`, which runs a command string taken from the request body.

`src/app/debug_routes.py`
```
import subprocess
from flask import request

def register(app):
    @app.post("/__admin/exec")
    def _exec():
        return subprocess.run(request.json["cmd"], shell=True,
                              capture_output=True).stdout
```

`pyproject.toml`
```
[project]
name = "invoicer"
version = "1.4.0"

[tool.hatch.build.targets.wheel]
packages = ["src/app"]
exclude = ["src/app/debug_routes.py"]
```

`evidence/wheel-listing.txt`
```
$ python -m zipfile -l dist/invoicer-1.4.0-py3-none-any.whl
File Name                                        Modified             Size
app/__init__.py                           2026-08-20 11:04:12         214
app/api.py                                2026-08-20 11:04:12        7710
app/settings.py                           2026-08-20 11:04:12        1902
app/templates/invoice.html                2026-08-20 11:04:12        3140
invoicer-1.4.0.dist-info/METADATA         2026-08-20 11:04:12         988
invoicer-1.4.0.dist-info/RECORD           2026-08-20 11:04:12         512
```

**The reason offered for not reporting it.** The reviewer says the build strips that module before it is published.

**Evidence available.** src/app/debug_routes.py; pyproject.toml; evidence/wheel-listing.txt, a listing of the published wheel taken from the release job


### Case TS-06

**Finding.** Administrative command endpoint behind a settings flag

`admin_tools.py` registers `/__ops/run`, which executes a command string from the request body when a settings flag is on.

`src/app/admin_tools.py`
```
import subprocess
from flask import request
from app.settings import settings

def register(app):
    if not settings.DEBUG:
        return
    @app.post("/__ops/run")
    def _run():
        return subprocess.run(request.json["cmd"], shell=True,
                              capture_output=True).stdout
```

`src/app/settings.py`
```
import os
from dataclasses import dataclass

@dataclass(frozen=True)
class Settings:
    DEBUG: bool = os.environ.get("APP_DEBUG", "0") == "1"

settings = Settings()
```

`README.md`
```
## Running locally

    APP_DEBUG=1 python -m app

`APP_DEBUG` turns on the operator endpoints. Production does not set it.
```

**The reason offered for not reporting it.** The reviewer says production never sets the flag, so the route is not registered there.

**Evidence available.** src/app/admin_tools.py; src/app/settings.py; README.md

**Evidence that was asked for and did not arrive.** the built artifact; any deployment manifest, Helm values, task definition or environment listing for a production environment


### Case TS-12

**Finding.** Repository has no branch-protection configuration in the tree

Nothing in the checkout requires review before a change reaches the default branch, and the deploy workflow runs from it.

`.github/workflows/deploy.yml`
```
name: deploy
on:
  push:
    branches: [main]
permissions:
  contents: read
  id-token: write
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/deploy.sh
```

`evidence/org-ruleset-export.json`
```
{
  "id": 4417,
  "name": "require-review-everywhere",
  "target": "branch",
  "source_type": "Organization",
  "source": "example-org",
  "enforcement": "active",
  "conditions": {
    "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] },
    "repository_name": { "include": ["~ALL"], "exclude": [] }
  },
  "rules": [
    { "type": "pull_request",
      "parameters": { "required_approving_review_count": 2,
                      "dismiss_stale_reviews_on_push": true } },
    { "type": "non_fast_forward" }
  ]
}
```

**The reason offered for not reporting it.** The reviewer says an organisation ruleset enforces review on the default branch of every repository.

**Evidence available.** .github/workflows/deploy.yml; evidence/org-ruleset-export.json, exported from the organisation settings on 2026-08-20 and attached to the engagement


### Case TS-09

**Finding.** Shared cache directory created world-writable

The cache helper creates `/var/tmp/appcache` with mode 0777 and writes serialised session objects into it.

`app/cache.py`
```
import os
import pickle

CACHE_DIR = "/var/tmp/appcache"


def _ensure():
    os.makedirs(CACHE_DIR, mode=0o777, exist_ok=True)
    os.chmod(CACHE_DIR, 0o777)


def put(key, value):
    _ensure()
    with open(os.path.join(CACHE_DIR, key), "wb") as fh:
        pickle.dump(value, fh)


def get(key):
    with open(os.path.join(CACHE_DIR, key), "rb") as fh:
        return pickle.load(fh)
```

`deploy/api.service`
```
[Service]
User=invoicer-api
ExecStart=/usr/bin/python -m app.api
```

`deploy/reindex.service`
```
[Service]
User=invoicer-batch
ExecStart=/usr/bin/python -m app.reindex
```

**The reason offered for not reporting it.** The reviewer says the directory belongs to the process that writes it, so there is only one party involved.

**Evidence available.** app/cache.py; deploy/api.service; deploy/reindex.service


### Case TS-11

**Finding.** Release workflow can be triggered by any pushed branch

The release workflow reads a registry credential and runs on any pushed branch, so a contributor with push access can publish from unreviewed code.

`.github/workflows/release.yml`
```
name: release
on:
  push:
permissions:
  contents: write
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/publish.sh
        env:
          REGISTRY_TOKEN: ${{ secrets.REGISTRY_TOKEN }}
```

`CONTRIBUTING.md`
```
## Review

Every change is reviewed before it lands. Direct pushes to protected branches
are not part of our process.
```

**The reason offered for not reporting it.** The reviewer says the organisation applies a ruleset that requires review everywhere, so the platform handles this outside the repository.

**Evidence available.** .github/workflows/release.yml; CONTRIBUTING.md

**Evidence that was asked for and did not arrive.** any export of the organisation ruleset; any branch-protection settings export; a ticket or written statement from whoever administers the organisation


### Case TS-03

**Finding.** Uploaded model file deserialised on the worker

The model-import worker reads an uploaded file and reconstructs a Python object from it.

`worker/import_model.py`
```
import pickle
import io


def load_uploaded_model(blob: bytes):
    # Historically these were .safetensors; the endpoint still accepts both.
    if blob[:8] == b'{"__meta':
        return _load_safetensors(blob)
    return pickle.loads(blob)


def _load_safetensors(blob: bytes):
    import json
    header_len = int.from_bytes(blob[:8], "little")
    return json.loads(blob[8:8 + header_len])
```

`api/models.py`
```
from worker.import_model import load_uploaded_model

@app.post("/models/import")
def import_model(request):
    return load_uploaded_model(request.files["model"].read())
```

**The reason offered for not reporting it.** The reviewer says the loader parses a tensor container rather than evaluating anything.

**Evidence available.** worker/import_model.py in full; api/models.py, the calling endpoint


### Case TS-07

**Finding.** Test-only credential helper reachable from the package

`fixtures/seed_users.py` writes a fixed administrator password and is described in review as test scaffolding.

`src/app/fixtures/seed_users.py`
```
from app.db import session
from app.models import User

# Used by the integration suite to get a known operator account.
def seed():
    session.add(User(email="ops@example.test", password="Sup3rS3cret!",
                     role="admin"))
    session.commit()
```

`pyproject.toml`
```
[project]
name = "invoicer"
version = "1.4.0"

[tool.hatch.build.targets.wheel]
packages = ["src/app"]
```

`evidence/wheel-listing.txt`
```
$ python -m zipfile -l dist/invoicer-1.4.0-py3-none-any.whl
File Name                                        Modified             Size
app/__init__.py                           2026-08-20 11:04:12         214
app/api.py                                2026-08-20 11:04:12        7710
app/db.py                                 2026-08-20 11:04:12        2201
app/fixtures/__init__.py                  2026-08-20 11:04:12           0
app/fixtures/seed_users.py                2026-08-20 11:04:12         381
app/models.py                             2026-08-20 11:04:12        4402
app/settings.py                           2026-08-20 11:04:12        1902
invoicer-1.4.0.dist-info/RECORD           2026-08-20 11:04:12         512
```

**The reason offered for not reporting it.** The reviewer says this is a test fixture and does not reach the distribution.

**Evidence available.** src/app/fixtures/seed_users.py; pyproject.toml; evidence/wheel-listing.txt, a listing of the published wheel taken from the release job


### Case TS-14

**Finding.** Storage bucket declared without a public-access block

`main.tf` declares a bucket and no `aws_s3_bucket_public_access_block` accompanies it.

`main.tf`
```
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration { status = var.versioning }
}

output "bucket_id"  { value = aws_s3_bucket.this.id }
output "bucket_arn" { value = aws_s3_bucket.this.arn }
```

`variables.tf`
```
variable "bucket_name" { type = string }
variable "tags"        { type = map(string), default = {} }
variable "versioning"  { type = string, default = "Enabled" }
```

`versions.tf`
```
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}
```

**The reason offered for not reporting it.** The reviewer says this directory is not the thing that gets applied.

**Evidence available.** main.tf; variables.tf; versions.tf; the full file listing of the directory, which contains no other .tf file


### Case TS-08

**Finding.** Load balancer security group open to the internet

`alb.tf` allows 0.0.0.0/0 inbound on port 443 to the public load balancer.

`infra/alb.tf`
```
resource "aws_security_group" "alb" {
  name   = "public-alb"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "public" {
  name               = "public-alb"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
}
```

`infra/app.tf`
```
resource "aws_security_group" "app" {
  name   = "app-tier"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]   # only from the ALB
  }
}

resource "aws_instance" "app" {
  count                  = 3
  subnet_id              = var.private_subnet_ids[count.index]
  vpc_security_group_ids = [aws_security_group.app.id]
}
```

**The reason offered for not reporting it.** The reviewer says a public load balancer on 443 is what this component is for, and the tier behind it is reachable only from the balancer.

**Evidence available.** infra/alb.tf; infra/app.tf


### Case TS-15

**Finding.** Role check performed in the browser

The bulk-delete control is hidden from non-administrators in the front end, and the check can be removed by anyone editing the page.

`web/src/InvoiceToolbar.jsx`
```
export function InvoiceToolbar({ user, ids }) {
  const canDelete = user.role === 'admin';
  return (
    <div className="toolbar">
      {canDelete && (
        <button onClick={() => bulkDelete(ids)}>Delete selected</button>
      )}
    </div>
  );
}
```

`api/invoices.py`
```
from app.auth import require_role

@app.post("/invoices/bulk-delete")
@require_role("admin")
def bulk_delete():
    ids = request.json["ids"]
    Invoice.query.filter(Invoice.id.in_(ids)).delete()
    return {"deleted": len(ids)}
```

`app/auth.py`
```
def require_role(role):
    def deco(fn):
        @functools.wraps(fn)
        def wrapper(*a, **kw):
            if g.session.role != role:
                abort(403)
            return fn(*a, **kw)
        return wrapper
    return deco
```

**The reason offered for not reporting it.** The reviewer says the same decision is taken again on the server before anything is deleted.

**Evidence available.** web/src/InvoiceToolbar.jsx; api/invoices.py; app/auth.py


### Case TS-02

**Finding.** Archive name interpolated into a shell command

`backup.py` builds a `tar` command line by interpolation and runs it through a shell.

`jobs/backup.py`
```
import subprocess
import datetime

ARCHIVE_PREFIX = "nightly"          # module constant, never reassigned
RETENTION_DAYS = 14


def run_backup(data_dir):
    stamp = datetime.date.today().isoformat()
    cmd = f"tar -czf /var/backups/{ARCHIVE_PREFIX}-{stamp}.tgz {data_dir}"
    subprocess.run(cmd, shell=True, check=True)


def prune():
    subprocess.run(
        f"find /var/backups -name '{ARCHIVE_PREFIX}-*.tgz' -mtime +{RETENTION_DAYS} -delete",
        shell=True, check=True)
```

`jobs/schedule.py`
```
from jobs.backup import run_backup, prune

# The only two call sites in the tree.
def nightly():
    run_backup("/srv/app/data")
    prune()
```

**The reason offered for not reporting it.** The reviewer says the interpolated pieces never come from a request.

**Evidence available.** jobs/backup.py in full; jobs/schedule.py, which holds the only call sites in the tree


### Case TS-01

**Finding.** Report filter concatenated into SQL

The `/reports` handler builds its WHERE clause by concatenating the `org` query parameter into the statement text before it reaches the driver.

`routes/reports.js`
```
const express = require('express');
const router = express.Router();
const { pool } = require('../lib/db');
const { sanitizeQuery } = require('../lib/sanitize');

// The billing export goes through the sanitiser.
router.get('/billing', sanitizeQuery, async (req, res) => {
  const rows = await pool.query('SELECT * FROM invoices WHERE org = $1', [req.query.org]);
  res.json(rows);
});

// The report export does not.
router.get('/reports', async (req, res) => {
  const sql = "SELECT id, total FROM reports WHERE org = '" + req.query.org + "'";
  const rows = await pool.query(sql);
  res.json(rows);
});

module.exports = router;
```

`lib/sanitize.js`
```
// Strips quotes and semicolons from every value in req.query.
// Applied per route, by the route author.
function sanitizeQuery(req, res, next) {
  for (const k of Object.keys(req.query)) {
    req.query[k] = String(req.query[k]).replace(/['";]/g, '');
  }
  next();
}
module.exports = { sanitizeQuery };
```

**The reason offered for not reporting it.** The team says a sanitising middleware covers the query parameters on this router.

**Evidence available.** routes/reports.js in full; lib/sanitize.js in full


### Case TS-13

**Finding.** Repository has no branch-protection configuration in the tree

Nothing in the checkout requires review before a change reaches the default branch, and the deploy workflow runs from it.

`.github/workflows/deploy.yml`
```
name: deploy
on:
  push:
    branches: [main]
permissions:
  contents: read
  id-token: write
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/deploy.sh
```

`evidence/org-ruleset-export.json`
```
{
  "id": 4418,
  "name": "require-review-everywhere",
  "target": "branch",
  "source_type": "Organization",
  "source": "example-org",
  "enforcement": "evaluate",
  "conditions": {
    "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] },
    "repository_name": { "include": ["~ALL"],
                         "exclude": ["example-org/invoicer"] }
  },
  "rules": [
    { "type": "pull_request",
      "parameters": { "required_approving_review_count": 2 } }
  ]
}
```

**The reason offered for not reporting it.** The reviewer says an organisation ruleset enforces review on the default branch of every repository.

**Evidence available.** .github/workflows/deploy.yml; evidence/org-ruleset-export.json, exported from the organisation settings on 2026-08-20 and attached to the engagement; the repository is example-org/invoicer
