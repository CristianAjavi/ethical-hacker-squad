# The findings artifact

The markdown report is what a person reads. `findings.json` is what a pipeline can check, diff between two engagements, and score — and it is what finally makes **our own output** measurable, which is the thing nobody in this field currently does.

It is written **beside** the report, never instead of it. A JSON file is not a deliverable to a client; it is the deliverable's skeleton, and every field in it also appears in the prose.

## Where the rules live

| Thing | Its single home |
|---|---|
| The shape: fields, types, what is required | [`findings.schema.json`](findings.schema.json) |
| The words: `status`, `severity`, `confidence`, `verification` | [`vocabulary.md`](vocabulary.md) — the schema deliberately does **not** repeat them |
| The triage answers and what they mean | [`triage.md`](triage.md) |
| Redaction placeholders and what may not travel | [`report.md`](report.md) |

`gate-findings-artifact.sh` validates the artifact against all four, and the same command validates a real deliverable: `scripts/gates/gate-findings-artifact.sh --deliverable path/to/findings.json`.

## The fields, and why each is there

**The prefix is part of the contract.** `engagement.x` is a key of the engagement object, `findings[].x` is a key of each finding, and a bare name is a top-level key of the artifact. A finding rejects any field not listed here as `findings[].`, so a top-level key written inside a finding fails validation — which is exactly what happened the first time a specialist read this table without the prefixes.

| Field | Why it exists |
|---|---|
| `schema_version` | **Top-level.** Exactly `ehs.findings/v1`. A consumer must be able to tell which contract a file was written against, and a version invented per run tells it nothing. |
| `engagement.scope` | The exact target. A finding without the scope it was found in cannot be re-checked. |
| `engagement.commit` | What the audit actually read. Without it, "fixed" and "not reproducible" are unarguable. |
| `engagement.mode` | `audit`, `harden` or `verify`: what the squad was allowed to do. |
| `engagement.language` | The language of the prose. Identifiers are never translated. |
| `engagement.generated_by` | Which skill version produced this. |
| `engagement.coverage` | **The inventory, resolved.** Three lists — `inventoried`, `read`, `not_read` — and every surface in the first must appear in exactly one of the other two. The validator does the set arithmetic, so a surface cannot be inventoried, routed to, and then quietly left out. A blinded reader test found exactly that in one of our own reports and concluded that *silence about SQL injection in this report is not evidence of its absence*; prose could not stop it, this can. |
| `engagement.unaided_pass` | **What you would have reported with no corpus at all, written down before you opened a pack, then resolved.** Three parts — `candidates`, `reported`, `dropped` — and every candidate ends in exactly one of the last two, a drop carrying the reason the second reading overturned the first. *No procedure covers it* is refused by the validator as a reason: that case is what `ad-hoc` is for. This exists because eleven measurements said the corpus was substituting for judgement rather than adding to it. |
| `engagement.unaided_pass.dropped[].resolution` | Why a candidate is not a finding, as a category rather than a mood: `refuted`, `merged` or `out_of_scope`. Each carries its own evidence requirement, because **a dismissal has to cost what an assertion costs.** Measured: a weaker model short of budget did not go quiet, it refuted confidently — twice dismissing a real unbounded allocation, once by asserting the bounds were fine and once by citing the length cap of a different method. |
| `engagement.unaided_pass.dropped[].control_at` | **Required for `refuted`**: `path:line` of the control that makes the candidate harmless, on the path that reaches the sink. A refutation names where the bound *is* enforced, exactly as a confirmation names where it is missing. *It looks correct* is not a refutation. |
| `engagement.unaided_pass.dropped[].merged_into` | **Required for `merged`**: the id of the finding that absorbed this candidate, which must exist in `findings`. |
| `engagement.coverage_declaration` | What was exercised and what was not. A file of findings with no coverage statement invites the reader to assume the rest is clean. |
| `engagement.authorization` | The reference under which any remote or active test was run. Absent means none was. |
| `engagement.target_digest` | **What was actually read**, as a digest over the in-scope tree. `commit` is what the target calls itself, and a dirty worktree can say `v2.1.0` while holding something else; this is the bytes that were in front of the squad. Two artifacts carrying the same digest audited the same thing, which is the only condition under which a diff between them means anything. |
| `engagement.baseline` | **The previous artifact this run was compared against**: its digest, when it was produced, and how many findings it carried. Present only when a comparison actually happened — declaring it is a claim that the matcher ran, and invariant 28 makes the artifact prove it by balancing the count. |
| `engagement.baseline_absent_reason` | **Required at `v2` when there is no baseline**: first engagement on this target, the previous artifact was not made available, the target moved. Without this field the same silence covers *no previous audit exists* and *nobody looked for one*, and a reader diffing two reports cannot tell which they are holding. |
| `findings[].id` | `F-001`, `F-002`, … — three digits, and the validator enforces it. Stable within the engagement, so the report, the annex and the issue can all point at the same thing. |
| `findings[].title` | One line a maintainer can triage from. |
| `findings[].procedure` | The pack procedure that produced it, or `ad-hoc`. This is what makes a finding traceable back to a written method instead of to a model's mood. |
| `findings[].status` | From `vocabulary.md`. `candidate` may never appear here: it is internal working state. |
| `findings[].severity` | Judged in this system, not copied from a tool's label. |
| `findings[].confidence` | How much of the chain was observed rather than inferred. |
| `findings[].location` | Path, and line when there is one. |
| `findings[].evidence` | The minimal trace, already redacted. |
| `findings[].impact` | What an attacker gets. |
| `findings[].preconditions` | What has to be true first. |
| `findings[].recommendation` | The fix at root-cause level. |
| `findings[].verification` | From `vocabulary.md`, when a fix was checked. |
| `findings[].inference` | **Required for `probable`**: the one link that was inferred. A `probable` finding that cannot name it is a `confirmed` finding without the evidence, or a `candidate` in disguise. |
| `findings[].what_would_settle_it` | **Required for `probable`**: the artifact, file or symbol that turns the inference into an observation. A gap named with no way to close it sends the reader nowhere, and this is the field a second reader uses to decide whether to go and look. |
| `findings[].unaided_label` | The label this finding carried in `engagement.unaided_pass.candidates`, when it came from your own reading rather than from a procedure. It is the join that lets the validator prove nothing found before the pack was opened went missing after. |
| `findings[].duplicate_of` | The id of the finding this one was merged into. The absorbed finding **stays in the artifact with its own id** and is rendered under its parent; a merge that deletes the entry deletes the record that it was ever found. Requires `merge_rules`. |
| `findings[].possible_duplicate_of` | Ids this finding may be the same as, where a `DUP-*` rule came back `UNKNOWN`. Both findings ship and both are counted. This is the state for **not having decided**, and it carries no proof obligation. |
| `findings[].merge_rules` | Required with `duplicate_of`: the `DUP-01`..`DUP-06` rules of `triage.md`, answered, same shape as `triage`. A merge is a claim and pays what a claim pays. |
| `findings[].withdrawn_reason` | **Required for `withdrawn`**: a claim already made that did not survive. It stays visible; that is the difference from `discarded`. |
| `findings[].traceability` | The standard identifiers, verbatim. |
| `findings[].triage` | Every rule the procedure invokes, its answer, and a reason whenever the answer is not `DOES_NOT_HOLD`. |
| `findings[].severity_calibration` | **Required on `critical` and `high`**: the `SEV-01`..`SEV-10` caps of `triage.md`, answered, same shape as `triage`. The ceiling each rule imposes lives in `triage.md`, never here, so a finding cannot restate the cap it exceeds. `HOLDS` and `UNKNOWN` both bind; `DOES_NOT_HOLD` is free below `high` and costs a reason at or above it, because there it is the answer that buys the label. |
| `findings[].fingerprint` | **A candidate key, never an identity.** `algorithm`, `value`, the `inputs` it was computed over, and an `ordinal` for its collisions. Measured over 117 real artifacts and 587 findings: no key over these fields is unique — `path`+`line`+`procedure` covers 539 and collides on 4.5%, `path`+`component`+`procedure` covers 372 and collides on 6.5%, `path`+`procedure` covers 544 and collides on 26.7%. A field that cannot be unique must not be spelled like an id, so this one declares its own strength. **`line` is deliberately not an available input**: a key that moves when a comment is inserted above the defect reports every rebase as a new finding. |
| `findings[].baseline_state` | From `vocabulary.md`, dimension 5. What this finding is against the baseline. `unmeasured` is the term this dimension exists for — the honest answer when no comparison was made, and the one a matcher that failed open must be forced to give instead of `new`. |
| `findings[].lineage` | **Required for `unchanged` and `updated`, refused for `new` and `unmeasured`**: the baseline fingerprint value(s) this finding continues. More than one means the baseline split what this run reports as one defect. |
| `findings[].changed_fields` | **Required for `updated`, refused for `unchanged`**: what moved since the baseline, as dotted field names. Without it `updated` is a mood rather than a diff, and a reader cannot tell a severity correction from a fix that regressed. |
| `findings[].regression` | **A defect that was reported gone and came back**: how the previous engagement disposed of it, and what brought it back. It requires a `lineage`, and the previous disposition has to be one that concluded something — you cannot regress from `not measured`. |
| `findings[].limits` | What this finding does not establish. |
| `ruled_out` | **Top-level, once per artifact** — a sibling of `findings` and `engagement`, not a field inside a finding. What was tested and did not appear, with the bound of how far the test reached. |
| `carried_over` | **Top-level, once per artifact.** Every baseline finding this run did **not** report again, and what happened to it: `fixed`, `refuted`, `out of scope` or `not measured`, from dimension 6 of `vocabulary.md`. SARIF v2.1.0 synthesises these into the result list as `baselineState: absent`; they live in their own array here because a finding in this contract is the *assertion that a defect exists*, and filing an absent one beside the live ones would make severity, triage and invariant 11 each either false or a special case. Silence is the cheapest way to lose a defect: a finding that stops appearing reads, to anyone diffing two artifacts, exactly like a finding that was fixed. Each entry names a `fingerprint`, the `procedure` that produced it and a `disposition`; `fixed` adds `evidence` and `out of scope` adds a `surface`. |

## The invariants the validator enforces

These are not shape checks. They are the reasons the file is worth having:

1. **`confirmed` is expensive.** Every triage rule answered, none `HOLDS`, none `UNKNOWN`, and confidence not `low`. A finding cannot be promoted by writing a stronger word.
2. **`probable` names its gap** in `inference` **and the way to close it** in `what_would_settle_it`, and **`withdrawn` names its reason**.
3. **The inventory is accounted for.** Every surface in `engagement.coverage.inventoried` appears in `read` or in `not_read`, never in both and never in neither. A surface you inventoried and then left in neither list is the silence a reader mistakes for a clean bill, and refusing that inference is the whole point of the field.
4. **The unaided pass is accounted for.** Every label in `engagement.unaided_pass.candidates` appears in `reported` or in `dropped`, never in both and never in neither; every label in `reported` is carried by some finding's `unaided_label`; and a drop whose reason is that the corpus has no procedure for it is refused. A candidate that simply vanishes between your first reading and your report is the substitution this field was added to make impossible to perform quietly. **And a drop pays its own way**: `refuted` names the line of the control in `control_at`, `merged` names the finding in `merged_into` and that finding has to exist. Dismissing was the cheapest move in this contract and a short-budget reviewer took it — twice, against a defect that was real.
5. **`candidate` never ships.** It is working state, and `vocabulary.md` says so.
6. **Every `procedure` resolves** to a real identifier in the corpus, or is exactly `ad-hoc`. An invented procedure id would make a finding look methodical when it was not.
7. **Every `traceability` identifier matches a known family**, the same list `gate-corpus-contract.sh` uses.
8. **Every `triage.rule` exists** in `triage.md`, and a reason is present whenever the answer is not `DOES_NOT_HOLD`.
9. **No unredacted secret travels.** The high-precision formats — `ghp_`, `AKIA`, `sk-ant-`, PEM headers — are refused in any string, exactly as `gate-report-contract.sh` refuses them in the prose.
10. **A merge leaves a trace, and an undecided pair is not a merge.** `duplicate_of` points at a finding that exists in this artifact, is not itself a duplicate, and is not the finding itself; no id appears in both `duplicate_of` and `possible_duplicate_of`; and `duplicate_of` requires `merge_rules` with every rule of `triage.md`'s merge family answered and none `HOLDS`. Invariant 4 closed this one level down, for a candidate absorbed inside a single specialist's unaided pass. The leader's cross-specialist merge — ordered three times in `references/team.md`, governed by nothing — was the same substitution with nothing looking at it. The rule that no chain is allowed is not tidiness: a duplicate pointing at a duplicate is how a reader loses the surviving entry.

11. **A finding may not live where the report says it did not look.** No finding's `location.path` may lie inside a surface listed in `engagement.coverage.not_read`, matched at a path segment boundary. Invariant 3 makes the inventory account for itself; this one makes it account to the findings beside it, because until now they were two documents sharing a file. Measured: the fixture that models a *conforming* artifact could declare `not_read: ["migrations/"]`, report a defect at `migrations/003_add_invoices.sql:12`, and sign verdict 0. A finding is proof that someone looked, so one of the two sentences is false, and the reader cannot tell which. The segment boundary is what keeps this from accusing the compliant — `migrations-legacy/` is not inside `migrations/`, and the conforming fixture carries exactly that case as its control. Across the 60 real artifacts in `bench/runs`, 277 findings carry a path and **none** contradicts a `not_read` entry: the rule forbids a class that has not happened yet rather than convicting past work.

12. **A `critical` or a `high` answers the `always` caps.** An expensive label is paid for with the two questions `triage.md` marks obligatory. A cap nobody answered is a cap nobody applied, and that silence is exactly what an unexamined label buys.

13. **A cap that holds, holds.** The entry says the condition is true and the label sits above the ceiling that condition imposes. This is the one invariant here that is purely mechanical: the ceiling is `triage.md`'s, not the finding's to overrule.

14. **`UNKNOWN` binds exactly as `HOLDS` does.** Not knowing whether a cap applies is not permission to sit above it — the doctrine of exit code `2` applied to a label, and the deliberate inverse of CVSS v4.0 resolving an undefined Exploit Maturity to *Attacked*.

15. **Any answer that is not `DOES_NOT_HOLD` names its artifact**, the same price the `FP-*` family charges.

16. **A dismissal pays when it buys the expensive label.** The one place this family does not copy `FP-*`: there the costly claim is the exculpation, here it is the dismissal, because `DOES_NOT_HOLD` is the answer that raises the severity. On `critical` and `high` it carries a reason; below them it is free.

17. **Every `severity_calibration.rule` exists** in `triage.md` — the mirror of invariant 8 for the new family.

18. **A rule has one answer.** Two let a reader pick the convenient one.

19. **Derived caps are derived.** `SEV-10` is computed from `status` and is never asked: a `hardening` finding claims there is nothing to exploit while a `critical` or `high` severity claims how much the exploit matters, and answering the rule by hand can only agree with the artifact or contradict it.

20. **`ehs.findings/v2` requires the memory.** A target digest, a baseline or the reason there is none, a `baseline_state` on every finding, and a `carried_over` list whenever a baseline is declared. Below `v2` the block is optional — but every rule from here down applies the moment any part of it is present. An artifact does not get to opt into the field and out of the arithmetic.

21. **A state that claims a comparison requires something to compare against.** `new`, `unchanged` and `updated` are assertions about a previous run. Without `engagement.baseline` the only honest term is `unmeasured`. This is the rule that would have caught the failure mode in the field: Mantis's matcher falls back to embeddings, `compute_embedding` catches every exception and returns a mock vector, the dimension check then skips every candidate, and a deployment with no model reports each run as entirely new. Nothing in its output says so.

22. **And a key to compare on.** A finding with no `fingerprint` had nothing to match with, so `new` is not available to it either. No key, no comparison, `unmeasured`.

23. **A continuation names what it continues, and a discovery names nothing.** `unchanged` and `updated` carry a `lineage`; `new` and `unmeasured` may not.

24. **`updated` is a diff.** It names `changed_fields`, and `unchanged` may not — the two terms differ by exactly that field, so letting either borrow the other's shape erases the distinction.

25. **A key was computed over fields the finding has.** Every name in `fingerprint.inputs` resolves to a value present on this finding. A key over an absent field is a key over nothing, and it will match nothing forever without ever saying so.

26. **The ordinal is a tiebreak and nothing else.** Findings sharing a `fingerprint.value` inside one artifact have distinct ordinals; a value that is unique here has ordinal `0`. Otherwise the ordinal becomes a second identifier, smuggled in beside the one that admits it is not unique.

27. **A regression is a claim about somebody's conclusion.** It requires a `lineage`, and `previous_disposition` has to be a disposition that concluded something. A defect can only come back from having been declared gone; `not measured` declared nothing, so there is nothing to have come back from.

28. **The baseline is accounted for.** Every finding the baseline carried is either continued by a finding here or answered in `carried_over`, and the counts balance against `engagement.baseline.findings_count`. No fingerprint may be both continued and carried over — it cannot have come back and not come back. This is invariant 3 for the inventory and invariant 4 for the unaided pass, applied across engagements: the three of them refuse the same move, which is a thing that was written down once and then quietly stopped being mentioned.

29. **A carried-over entry pays for what it claims.** `fixed` names its `evidence` — it is the only disposition that lowers a reader's guard, so it is the only one that costs. `out of scope` names a `surface`, and that surface has to be one `engagement.coverage.not_read` actually excludes. `not measured` is free on purpose: the moment honesty costs more than the comfortable answer, the contract starts buying the comfortable answer.

30. **A carried-over entry names what found it.** `procedure` is required on every entry, `ad-hoc` included, and the id has to resolve against the corpus — an id that is well formed and belongs to nothing is the same dead end as no citation, one step further along, and it survives review by looking correct. The example that would go here is not written down: `A4` in `gate-corpus-identifiers.sh` refuses a citation that resolves to nothing, so illustrating the rule in prose would mean committing the thing it forbids. The negative fixture carries it instead, which is what a negative fixture is for. This array is the only place a defect leaves the live list, so it is the only place the audit trail can end: a store that says a defect was fixed and cannot say what found it hands the next engagement a list it cannot re-derive. That is the measured failure mode of the persistent-findings stores in this space rather than a hypothetical one, and it is the constraint the roadmap item for this work was written with — which is why it is a rule and not a recommendation.

31. **`confirmed` costs `high` confidence.** Confirmed means demonstrated; anything less is an inference, and `vocabulary.md` spells the status of an inference `probable`. The validator refused only `low` for a long time, which left the middle term — the one an author reaches for when they are almost sure and do not want to say `probable` — going through unchallenged. Measured over 153 artifacts and 807 findings before the rule was closed: three findings from real blinded bench runs took exactly that door. The rule is a restatement of the cross-dimension invariants in `vocabulary.md`, which had been written down and then quietly not enforced.

32. **A refutation retracts the claim.** `verification: refuted` requires `status: withdrawn`. A refutation is a verdict about the finding, not a note about the test that failed: it says a second look established there was no defect. A finding that survives its own refutation as `confirmed` or `probable` is a claim the reader may already have acted on with nothing in the artifact retracting it. The implication runs one way only — nothing except a refutation implies `withdrawn`, and a withdrawal has other reasons. Zero violations in those 807 findings, which is why it was gated now: a rule costs nothing on the day it already holds, and everything on the day it does not.


## What it does not do

It does not make a wrong finding right, and it does not decide **what** severity a finding deserves — a well-formed file can carry a confident mistake. Invariants 12–19 check the label against the ceilings the finding itself answered, and invariants 20–30 check this run against the last one, and 31–32 refuse a verdict that contradicts itself; both are arithmetic on the artifact rather than a judgement about the system. What it removes is the class of defect where the prose says one thing and the structure says another, and it gives a scorer something to count.
