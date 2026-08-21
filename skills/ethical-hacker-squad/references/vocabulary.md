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
