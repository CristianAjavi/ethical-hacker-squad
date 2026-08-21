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

| Field | Why it exists |
|---|---|
| `schema_version` | A consumer must be able to tell which contract a file was written against. |
| `engagement.scope` | The exact target. A finding without the scope it was found in cannot be re-checked. |
| `engagement.commit` | What the audit actually read. Without it, "fixed" and "not reproducible" are unarguable. |
| `engagement.mode` | `audit`, `harden` or `verify`: what the squad was allowed to do. |
| `engagement.language` | The language of the prose. Identifiers are never translated. |
| `engagement.generated_by` | Which skill version produced this. |
| `engagement.coverage_declaration` | What was exercised and what was not. A file of findings with no coverage statement invites the reader to assume the rest is clean. |
| `engagement.authorization` | The reference under which any remote or active test was run. Absent means none was. |
| `id` | Stable within the engagement, so the report, the annex and the issue can all point at the same thing. |
| `title` | One line a maintainer can triage from. |
| `procedure` | The pack procedure that produced it, or `ad-hoc`. This is what makes a finding traceable back to a written method instead of to a model's mood. |
| `status` | From `vocabulary.md`. `candidate` may never appear here: it is internal working state. |
| `severity` | Judged in this system, not copied from a tool's label. |
| `confidence` | How much of the chain was observed rather than inferred. |
| `location` | Path, and line when there is one. |
| `evidence` | The minimal trace, already redacted. |
| `impact` | What an attacker gets. |
| `preconditions` | What has to be true first. |
| `recommendation` | The fix at root-cause level. |
| `verification` | From `vocabulary.md`, when a fix was checked. |
| `inference` | **Required for `probable`**: the one link that was inferred. A `probable` finding that cannot name it is a `confirmed` finding without the evidence, or a `candidate` in disguise. |
| `withdrawn_reason` | **Required for `withdrawn`**: a claim already made that did not survive. It stays visible; that is the difference from `discarded`. |
| `traceability` | The standard identifiers, verbatim. |
| `triage` | Every rule the procedure invokes, its answer, and a reason whenever the answer is not `DOES_NOT_HOLD`. |
| `limits` | What this finding does not establish. |
| `ruled_out` | What was tested and did not appear, with the bound of how far the test reached. |

## The invariants the validator enforces

These are not shape checks. They are the reasons the file is worth having:

1. **`confirmed` is expensive.** Every triage rule answered, none `HOLDS`, none `UNKNOWN`, and confidence not `low`. A finding cannot be promoted by writing a stronger word.
2. **`probable` names its gap** in `inference`, and **`withdrawn` names its reason**.
3. **`candidate` never ships.** It is working state, and `vocabulary.md` says so.
4. **Every `procedure` resolves** to a real identifier in the corpus, or is exactly `ad-hoc`. An invented procedure id would make a finding look methodical when it was not.
5. **Every `traceability` identifier matches a known family**, the same list `gate-corpus-contract.sh` uses.
6. **Every `triage.rule` exists** in `triage.md`, and a reason is present whenever the answer is not `DOES_NOT_HOLD`.
7. **No unredacted secret travels.** The high-precision formats — `ghp_`, `AKIA`, `sk-ant-`, PEM headers — are refused in any string, exactly as `gate-report-contract.sh` refuses them in the prose.

## What it does not do

It does not make a wrong finding right, and it does not judge severity — a well-formed file can carry a confident mistake. What it removes is the class of defect where the prose says one thing and the structure says another, and it gives a scorer something to count.
