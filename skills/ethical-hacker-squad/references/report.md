# Report format

This file is a reference consumed by the skill: it defines the shape of the deliverable the squad leader produces.

Every verdict word in the report — status, severity, confidence and verification outcome — comes from the closed list in [vocabulary.md](vocabulary.md). Translate the surrounding prose into the user's language; do not invent, merge or soften a term.

## What is machine-checked here, and what is not

Two of the rules below stopped being intentions. `scripts/gates/gate-report-contract.sh` reads the `report:section` and `report:rule` markers in this file and fails when a mandatory section or rule is deleted or downgraded to optional, and it scans a deliverable for the secret formats that can be recognised offline. The markers are the gate's input, not decoration: keep each one attached to the section or the rule it names.

Run it over the deliverable before the deliverable leaves:

```
scripts/gates/gate-report-contract.sh --deliverable path/to/report-directory
```

It follows the repository's exit-code doctrine: `0` measured and clean, `1` measured and it leaks, `2` it could not measure. A `2` is not a pass — it says the deliverable was never checked, so it does not ship either.

Everything else in this file is enforced by whoever writes the report and whoever reviews it. The gate reads a specification and recognises formats; it cannot tell whether a coverage declaration is honest or whether an impact scenario is real.

## Language

Write the report in the language the user is using. Every label below describes what a section must contain, not a heading to copy verbatim: translate the headings, keep the content. The `report:section` markers belong to this specification and are never copied into a deliverable.

Never translate: standard identifiers (`WSTG-INPV-05`, `ASVS 5.0 V8`, `CWE-89`, `A01:2025`, `API1:2023`, `LLM01:2026`, `ASI06`, `MASVS-STORAGE-1`, `MASTG-TEST-0001`, `CAPEC-66`, `CICD-SEC-4`, `SSDF PW`, `SLSA Build L2`), procedure IDs from the packs (`WEB-07`, `AI-01`, `SUP-14`), tool names, command lines, file paths, code symbols, and CVE identifiers.

<!-- report:section id=redaction-pass class=mandatory -->
## Redaction pass — before writing, not after

Mandatory, and it happens **before** the first paragraph of the report is written. A redaction pass run afterwards is a search for something you have already pasted, and it only finds what you remember pasting.

The reason is blast radius. A secret sitting in a repository is exposed to whoever can read that repository. The same secret copied into the report is exposed to everyone on the distribution list, to the ticket it gets pasted into, to the chat thread it is forwarded through and to every mail server in between — a wider audience than the one that held it before we arrived, and this time we are the publisher. The same argument covers personal data, internal topology and a working exploit string. `tooling.md` carries the measurement that makes it concrete: 81% of secrets committed to public repositories are never removed, and most credentials found valid stay valid for years afterwards. A report is one more surface with that property.

<!-- report:rule redaction.classes -->
**The four placeholder classes.** Every value in one of these classes is replaced in place by its placeholder, as the evidence is collected. The set is closed: if something does not fit, that is a defect in this file to report, not a licence to invent a fifth marker.

| Placeholder | Replaces | What must still appear, so the finding stays actionable | What never appears |
|---|---|---|---|
| `[REDACTED:secret]` | credentials, tokens, API keys, passwords, session cookies, private keys, signing material | the format class and its prefix (a GitHub token, `ghp_`, 40 characters), the location — file, line, commit, artifact —, the blast radius, and whether the format still looks live | any character of the value itself |
| `[REDACTED:pii]` | personal data of real people | the field or column name, the order of magnitude of the records affected, where it is stored, logged or sent, and the category (name, national ID, health, precise location) | any real value, whole or partially masked |
| `[REDACTED:internal-host]` | internal hostnames, private addresses, bucket, queue and topic names, admin URLs, employee usernames | the role the host plays, plus a stable label (`host-A`, `bucket-1`) reused across the whole report so the reader can still follow the topology | the resolvable name or address |
| `[REDACTED:payload]` | the working exploit string of a finding that is still open | the parameter, the sink, the injection class, the procedure ID, and the minimal test that reproduces it in a controlled environment | a copy-pasteable weaponised string |

<!-- report:rule redaction.no-partial-secret -->
**Truncation is not redaction.** Showing the first or the last four characters of a key is disclosure at a discount: it shrinks the search space, and in formats that encode account or environment structure it can identify the holder. Redact the value whole. What stays is the *format class* — `ghp_`, `AKIA`, `sk-ant-`, "PEM private key" — which is not part of the secret and which rotation depends on, because nobody can rotate what they cannot identify. Never keep a truncated value "so the client can find it": the location does that job, and a location cannot be replayed against the provider.

<!-- report:rule redaction.payload-annex -->
**A working payload for an open finding does not travel inside the report.** It goes into a separate evidence annex handed to the named technical contact, referenced from the body by ID, while the body carries `[REDACTED:payload]` plus the parameter, the sink and the injection class. The report circulates wider and lives longer than the window in which the bug stays open; this is an authorised audit, and an audit does not distribute a ready-to-run exploit to a mailing list. The same applies to the raw request that triggers it. If the client's process requires the payload in the main document, that is their decision, recorded in writing, and not our default.

<!-- report:rule redaction.self-check -->
**Check it, then deliver.** Run `scripts/gates/gate-report-contract.sh --deliverable <path>` over the finished deliverable, annexes, appendices and pasted tool output included — pasted tool output is where secrets actually survive, because nobody rereads it. A hit is `1` and the deliverable does not leave. An unmeasured deliverable is `2`, and `2` is not a pass: it says nobody checked, which is the state this rule exists to make visible. A secret found in the tree is treated as compromised and rotated whatever the report shows; write that in the finding instead of proving it with the value.

**What the gate cannot see, said plainly.** It recognises secrets because secrets have formats; personal data, internal hostnames and payloads do not. `[REDACTED:pii]`, `[REDACTED:internal-host]` and `[REDACTED:payload]` are enforced by the writer and by the reviewer, and this file says so rather than implying that a grep covers them. Scanning a whole repository for secrets is a different job with different tools, and `tooling.md` documents them together with their false-positive rates.
<!-- /report:section -->

<!-- report:section id=executive-summary class=mandatory -->
## Executive summary

State scope, mode, components reviewed, overall result and the most important risks. Avoid absolute guarantees. If nothing significant was found, say the review found nothing significant **at the depth reached** - not that the system is secure.
<!-- /report:section -->

<!-- report:section id=scope-and-method class=mandatory -->
## Scope and methodology

Record:

- folder, repository, artifact or authorized endpoint;
- commit or version when available;
- techniques and tools used, with the exact invocation;
- active tests actually performed, and against what;
- exclusions and limitations.
<!-- /report:section -->

<!-- report:section id=findings class=mandatory -->
## Findings

Order by severity, then by confidence. A severity written `critical` or `high` has answered the caps of `references/triage.md` — the ordering is only as honest as the labels it sorts. For each finding:

1. ID and title.
2. Status, severity and confidence, each taken verbatim from `vocabulary.md`:

<!-- vocabulary:use status -->
   - status: `confirmed`, `probable`, `hardening`, `discarded` or `withdrawn`. A `candidate` is not a finding and never reaches the report.
<!-- /vocabulary:use -->
<!-- vocabulary:use severity -->
   - severity: `critical`, `high`, `medium`, `low` or `informational`.
<!-- /vocabulary:use -->
<!-- vocabulary:use confidence -->
   - confidence: `high`, `medium` or `low`, always written with the word `confidence` beside it so it cannot be read as a severity.
<!-- /vocabulary:use -->

3. Precise location.
4. Minimal evidence, already through the redaction pass and carrying its placeholders.
5. Impact scenario and preconditions.
6. Root cause.
7. Recommended or applied fix.
8. Verification status.
9. Traceability: the pack procedure ID it came from, plus the standard identifiers it maps to.

Do not pad with generic recommendations. Keep `discarded` candidates only as a short note, and only when it saves someone repeating the work. A `withdrawn` finding is different and is not optional: it was already claimed to the reader, who may have acted on it, so it stays in the report with the reason it did not survive.

Severity is a judgement about **this** system, not a copy of a scanner label. A dependency advisory rated critical whose vulnerable symbol is never reached is not a critical finding here; say so and explain why, rather than inheriting the number.
<!-- /report:section -->

<!-- report:section id=ruled-out class=mandatory -->
**The deliverable has a machine-readable half.** `findings.json`, beside the markdown, conforming to `references/findings-artifact.md`. It is not a substitute for the report — a JSON file is not something a client reads — and it is not optional either: it is what lets a second engagement diff against this one, what lets a pipeline check that a `confirmed` finding really carries a complete triage, and what finally makes this squad's own output measurable. Validate it before delivery with `scripts/gates/gate-findings-artifact.sh --deliverable <path>`; an unmeasured artifact is `2`, and `2` is not a pass.

**Every confirmed finding carries its triage.** The rules from `references/triage.md` that the procedure invokes, each with its answer — `HOLDS`, `DOES_NOT_HOLD`, `UNKNOWN` or `NOT_APPLICABLE` — and, whenever the answer is not `DOES_NOT_HOLD`, the artifact that supports it. This is the part a client can argue with: it shows which exculpations were considered and rejected, rather than asking them to trust that they were. A finding presented as `confirmed` with a rule left `UNKNOWN` is a finding presented above its evidence, and the ceiling for it is `probable`.

## What was ruled out, and what resisted

Mandatory. A list of problems is a complaint; the same list plus what was checked and did not appear is an audit. Without this section the reader cannot tell a thorough review of ten classes from a shallow look at two, and the natural reading of a short findings list — "then there is nothing else" — is the reading we most need to prevent.

<!-- report:rule ruled-out.tested-and-absent -->
**Tested, and it did not appear.** One entry per class actually exercised: the class, the procedure ID that drove it, where and how it was tested, and the outcome. Exactly one outcome from `vocabulary.md` belongs in this list:

<!-- vocabulary:use verification -->
- `refuted` — the check ran and settled the question.
<!-- /vocabulary:use -->

Anything else is a gap rather than a negative result, and gaps go to the coverage declaration. Promoting one into this list converts an absence of measurement into a reassurance, which is the failure the whole verdict vocabulary exists to prevent. An entry that names no check is padding: delete it.

<!-- report:rule ruled-out.depth -->
**Every entry is bounded by its depth, and says so in its own sentence.** "Traced from the three HTTP entry points that reach this module, with the ORM layer read end to end" is an entry. "No SQL injection" is a claim about the whole system that no audit can support. The bound belongs inside the sentence, not in a caveat at the end of the section, because the sentence is what gets quoted in the client's summary and the caveat is what gets left behind.

<!-- report:rule ruled-out.resisted -->
**What actively resisted.** The controls that were exercised and held: the parameterised query that survived the injection attempt, the token validation that rejected the forged token, the deserialiser that refused the crafted object, the pipeline step that blocked the unpinned action. Name the control, where it lives in the code, and the attempt it defeated. This is the only evidence in the deliverable that a defence *works* rather than merely *exists*, and it is the part a client almost never receives.

<!-- report:rule ruled-out.regression-test -->
**How to keep it.** For each control that resisted, the regression test that would fail if that control were removed: what to send, what the expected refusal looks like, and where the test belongs in the client's suite. A defence nobody tests is a defence that gets refactored away two quarters from now, and our successful attempt becomes worthless the day after it succeeded. Where the test cannot be written from here — it needs the live target, or an authorization we do not hold — say that and name what would unblock it, instead of writing "further testing recommended".
<!-- /report:section -->

<!-- report:section id=coverage-declaration class=mandatory -->
## Coverage declaration

Mandatory. This is what separates an honest report from a reassuring one. Using `traceability.md`, state:

- which standard families were exercised, at the granularity you can defend - for example, session management and authorization were covered, weak cryptography was not;
- which pack sections each specialist opened, and which it skipped;
- which surfaces present in the inventory had no matching pack;
- which checks were impossible in this environment.

<!-- report:rule coverage.gaps -->
**Every gap lands here, and only here.** A check that ran and settled nothing, a check that nothing prevented and that was not run, and a check that an external condition stopped are three different facts; they carry the outcomes `inconclusive`, `not executed` and `blocked` from `vocabulary.md`, and none of the three may appear in the ruled-out section. The two sections are complementary and the boundary between them is the entire point: the ruled-out list says what we looked for and did not find, this list says what we did not look for or could not settle, and a reader holding both can work out the residue without asking us.

Claiming coverage you did not exercise is worse than declaring a gap. A reader who knows what was not looked at can act on it; a reader who believes everything was looked at cannot.
<!-- /report:section -->

<!-- report:section id=changes-made class=conditional -->
## Changes made

In `harden` mode, list modified files, the objective of each change, and any relevant compatibility impact. Separate rotations, deployments or operations that still require the user to act, and say plainly that they have **not** been done.

This section is the only conditional one: in a read-only audit there is nothing to list and an empty heading is noise. Every other section in this file is mandatory in every mode.
<!-- /report:section -->

<!-- report:section id=verification class=mandatory -->
## Verification

List the commands or tests executed and their result. Give every one of them a verification outcome from `vocabulary.md`, and distinguish clearly:

<!-- vocabulary:use verification -->
- `verified`;
- `partially verified`, with the class, variant or environment that stays open;
- `refuted`, when the check established that the finding did not hold;
- `inconclusive`, when the check ran and settled nothing;
- `not executed`, when nothing prevented it and it was not run;
- `blocked`, with what would unblock it.
<!-- /vocabulary:use -->

The last three are not weak results, they are the absence of a result, and each one names a different reason for it. Recording a check that errored, timed out or never reached the code as anything but `inconclusive` is the single most damaging thing this section can do: it converts a measurement that did not happen into a reassurance.

"Tests pass" is not the same as "the vulnerability no longer reproduces". State which one you actually established. A clean static-analysis run belongs here as a fact about the tool, never as evidence that a class of bug is absent.
<!-- /report:section -->

<!-- report:section id=residual-risk class=mandatory -->
## Residual risk and next steps

Prioritize concrete actions. Point out unreviewed surfaces, environment dependencies, and remote tests that need further authorization. Where a fix was deliberately not applied, record the reason and who has to decide.
<!-- /report:section -->

<!-- report:section id=handover class=mandatory -->
## The handover: where it landed, and what the reader sees on screen

Mandatory, and it is not part of the report file — it is what the leader prints in the session
after writing it. This section exists because the deliverable and the conversation are two
different channels, and for a long time this skill specified only the first. The measured
symptom: a user who ran the squad repeatedly and could not tell whether it had ever produced a
report. It had; nothing in the corpus ever told the leader to say where.

**Write the deliverable outside the audited tree.** In `audit` mode `references/team.md`
requires `git status --porcelain` to come back unchanged, so a report written inside the target
breaks the mode's own contract. Default to a sibling directory named for the engagement. If the
user named a destination, that one wins.

<!-- handover:field id=path -->
**The absolute path of the deliverable directory, and of both files in it.** Not "the report has
been generated", not a path relative to a working directory the user does not share with you: the
absolute path they can paste into an editor. This is the single field whose absence makes every
other one worthless, because a reader who cannot open the artifact is left with only the summary
they were told not to trust.

<!-- handover:field id=counts -->
**Confirmed findings by severity, then the `probable` count, then the `ruled_out` count.** Three
numbers, taken from `findings.json` rather than retyped from memory. The ruled-out count belongs
here for the same reason it has a section in the report: a bare "4 findings" reads as the whole
result, and "4 confirmed, 2 probable, 11 ruled out" reads as an audit.

<!-- handover:field id=validators -->
**The exit code of each validator that ran**, named: `gate-report-contract.sh --deliverable` and
`gate-findings-artifact.sh --deliverable`. Print the number. A `2` is reported as *not measured,
not a pass*, in those words — the whole verdict vocabulary is defeated the moment a `2` is
summarised on screen as "checks passed".

<!-- handover:field id=not-measured -->
**What could not be measured, in the same breath as what was.** The coverage declaration already
holds this, and it is precisely the part that never survives into the spoken summary. Name the
surfaces with no pack, the checks blocked on authorization, and any specialist that returned
nothing. A handover that lists only findings teaches the reader that silence means safety.

<!-- handover:field id=no-deliverable -->
**When there is no deliverable, that is the message.** If the run ended without files on disk —
the audit was cut short, the write failed, the leader ran out of context — say so plainly and
name what is missing. Do not print counts, do not print a narrative summary of findings held only
in the conversation, and do not describe the run as complete. An audit whose result exists only
in a chat transcript is an audit nobody can act on tomorrow, and presenting it as finished is the
one failure in this file that the client discovers instead of us.
<!-- /report:section -->
