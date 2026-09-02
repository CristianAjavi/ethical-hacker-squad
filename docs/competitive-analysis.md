# Competitive analysis

Five projects that solve a neighbouring problem, read against what this repository
actually contains today. Written to answer three questions and nothing else: what do
they do better, what do we do better *that can be proved from files on disk*, and what
should we build next.

## Provenance — read this before trusting any cell

This document mixes two grades of evidence and never blurs them.

**Verified by me, today (2026-08-16), on this machine:**

- every figure about **this** repository, produced by `scripts/meter/meter.sh` and by
  independent probes recorded below;
- every rival's stars, forks, licence SPDX id, creation date and last push, from
  `gh api repos/<owner>/<name>` executed today.

**Inherited from five scout analyses, not re-verified by me:** every claim about the
*content* of a rival repository — file paths, line numbers, prompt text, code
behaviour. I did not clone or read any rival repository. Those citations are recorded
as the scouts wrote them, and the scouts themselves flagged what they could not
confirm: **none of the five ran the software it analysed.** Where a claim would change
a decision, the decision is written to survive the claim being wrong.

**Not established by anyone, including us:** the actual detection quality of any
product in this document, ours included. See §3.4.

> **Update, 2026-08-21 — that last paragraph is now partly false, and the correction does not flatter us.**
> Detection quality has since been measured for two products in this table, ours and Mantis, on
> published advisories with a blind judge. **On the nine advisories a published rule selected — three
> ecosystems, five projects — the score is 6/9 for this corpus, 6/9 for the same model with no corpus,
> and 6/9 for Mantis. Identical.** A separation of one advisory appeared in the third round, was
> published, and was withdrawn the same day when the case was re-judged with every arm in one context
> and the disputed verdict moved. That episode is written up in the run's README as a property of the
> instrument: **one advisory is inside its noise.** Nothing here supports "the best available"; what it
> supports is "measured, at parity, and published by only one of the three". The single case where this corpus pulled ahead is one we chose. The runs, their
> artifacts and their limits are in `bench/runs/2026-08-21-ab-corpus/` and
> `bench/runs/2026-08-21-three-arm-go/`. Nothing here supports "the best available"; what it supports
> is "measured, and at parity on the sample nobody curated". The rest of this document was written on
> 2026-08-16 and its figures for **this** repository are superseded by the row below.

## The field, as of today

| Product | Repo | Licence | Stars | Forks | Created | Last push | What it is |
|---|---|---|---|---|---|---|---|
| PentAGI | `vxcontrol/pentagi` | MIT (+ EULA, + external AGPL SDK) | 21,841 | 2,886 | 2025-01-06 | 2026-08-06 | Fully autonomous Go multi-agent pentest platform; ~13 roles running real Kali tooling in Docker; genuinely exploits targets |
| AIG | `Tencent/AI-Infra-Guard` | Apache-2.0 (NOTICE requires attribution) | 4,506 | 446 | 2024-12-25 | 2026-08-12 | AI red-teaming platform: fingerprint+CVE engine, 3-stage black-box agent scanner, and an offensive jailbreak-mutation Claude Code skill |
| PT-Agents | `0xSteph/pentest-ai-agents` | MIT | 2,130 | 405 | 2026-03-28 | 2026-08-14 | Claude Code plugin, 52-53 offensive subagents including C2, evasion, exfiltration; funnel to a closed platform |
| AgSec | `msoedov/agentic_security` | Apache-2.0 (no NOTICE file) | 1,965 | 275 | 2024-04-11 | 2026-07-31 | Black-box jailbreak scanner: fires HuggingFace prompt datasets at an LLM endpoint and reports a refusal rate |
| Mantis | `google/mantis` | Apache-2.0 | 751 | 86 | 2026-06-15 | 2026-08-15 | 17 markdown skills forming a state machine over code review; ships **zero** vulnerability knowledge, all rigour is in the verification contract. **Corrected 2026-08-21 by fetching it:** at commit `5f76be0` it ships **33** skills, and it was run here on four targets — see the two runs cited above |
| **EHS** | `CristianAjavi/ethical-hacker-squad` | MIT | 0 | 0 | — | 2026-08-16 | This repository: 122 six-field procedures, 8 subagents, 6 gates, audit-only |
| **EHS**, as of 2026-08-22 | same | MIT | — | — | — | 2026-08-22 | **164** six-field procedures across 19 files, 9 subagents, **22 gates** (every one the requirements document declares now runs; 18 of them need neither a live repository nor an open PR, and **15 carry their own negative-proof battery**), 8 bench cases with 39 planted defects and 38 decoys, and **28 published measurement runs** — 10 of them pre-registered before any result existed, and **one retracted in place under a banner** |

---

## 1. Capability matrix

Rows are the capabilities that decide whether an audit deliverable is worth anything.
Cells are statements of fact, not scores.

### 1.1 At a glance

| Capability | PentAGI | AIG | PT-Agents | Mantis | AgSec | **EHS (us)** |
|---|---|---|---|---|---|---|
| **Knowledge delivery** | Tool-capability prose in 39 Go prompt templates; real knowledge is emergent (pgvector store built per engagement) | 14 loose `SKILL.md` detectors + ~1,900 CVE YAML + 139 AI-product fingerprints, machine-readable | Command recipes embedded per agent; whole `.md` loaded, no sub-file selection | **Zero positive corpus.** Knowledge is mined from the target's own VCS history at runtime | No knowledge. A catalogue of 40 jailbreak datasets — ammunition, not procedure | 122 numbered procedures, 6 mandatory fields each, loaded by section on demand |
| **False-positive management** | Emergent per engagement; typed state machine only | Dedicated adversarial reviewer with a coded FP taxonomy, zero-tolerance rule | Dynamic only: run a PoC against a live host | 13 named rules, **required by JSON schema**, each needs PASS/FAIL/UNKNOWN + reason | None. 30 refusal substrings; `"illegal"` in a jailbroken reply scores as *safe* | `What rules it out` in all 122 procedures — but free prose, unchecked, no shared rule set |
| **Independent verification** | Explicit exploitation is the proof | Dynamic verification stage builds real exploits; graded verdicts | `fix-verifier` 4-condition contract (class not payload, sibling surfaces, function survives) | Strongest in the field: benign-control, unpatched baseline, ≥3 variants, sink-reached proof, all schema-enforced | Absent | Separate `ehs-verifier` agent, no Edit/Write, 5 outcome classes, must list what it did *not* check — but static and unenforced |
| **Standards traceability** | Absent from the shipped knowledge | CVE ids in the rule corpus; no framework mapping in the detectors | MITRE ATT&CK technique ids inline **and** a queryable `mitre_id` column | Absent (grep for CWE/OWASP finds only incidental mentions) | Sells `owasp-llm-top-10` as a keyword; **0 hits** for OWASP across README and 21 docs | 117/122 procedures cite ≥1 identifier; 234 distinct ids across 20 families; counted by the meter |
| **Report format** | Sample report includes an explicit *Non-Vulnerable Features* section | Single-file HTML template + spec: full attempt log, positive-defence evidence, in-situ `REDACTED_*` | PTES/OWASP/SANS structure, full CVSS v3.1 vector, executive+technical registers | Mandatory non-authoritative banners, per-finding evidence-snapshot label, redaction pass before writing | `failures.csv`, `full_scan_log.csv`, `GET /failures` | `references/report.md`: mandatory coverage declaration, severity re-judged locally, "clean scan is a fact about the tool" — prose only, no schema, no machine artifact |
| **Orchestration** | Go orchestrator, ~13 roles, Postgres-backed, autonomous loop | Coded pipeline: recon → N parallel skill workers (`asyncio.gather`) → review | Claude Code delegation by `description`, plus 2 routing slash-commands | Planner writes `plan.json` and **pre-binds** which KB files each investigation may read; two-wave cost design | Marketing. The only "agent" is a demo with a hardcoded model and empty specs | Leader-in-main-thread, 8 harness-enforced subagents dispatched in parallel; orchestration is prose in `SKILL.md`, not a scheduler |
| **Real tooling** | Full Kali arsenal, msfvenom, C2, reverse shells, live exploitation | Live scanning; verification agent holds `write_file`/`execute_shell`; 79 jailbreak operators | nmap/ffuf/sqlmap/BloodHound/Impacket via Bash; 13 agents hold Bash+Write+Edit at once | gVisor container, `--network=none`, no host mounts, output truncated to 16 KB | HTTP client firing prompt payloads; downloads payloads at import time from an unpinned URL | Read/Grep/Glob/Bash for auditors; `tooling.md` documents licence, network posture and the typical false positive of each tool before it may be invoked |
| **Distribution & update** | `docker compose up -d` one-liner + TUI installer | Claude Code skill + plugin marketplace + hosted WebUI + pip, EN/ZH | Plugin marketplace + `install.sh` (incl. `curl \| bash`) + Docker + `doctor.sh` + `handoff.sh` | `npx skills add google/mantis`; **no CI at all**, no `.github/`; external PRs refused | PyPI on tag, Docker, mkdocs site, Vue UI | Claude Code plugin marketplace, `latest`/`stable` channels, 6 workflows, 18/18 actions SHA-pinned — channels still specified, not yet landed |
| **Measured quality** | Per-model benchmark exists but measures harness plumbing (tool-calling, latency), not detection | Eval datasets measure the **target's** attack-success rate, not detector accuracy | None. CI validates frontmatter, JSON and install script only | None shipped. `README_AGENTS.md` describes *how* to evaluate; no evaluation was run | None. `precision\|recall\|f1\|benchmark` → 0 hits repo-wide; default classifier is a `.joblib` with no model card | PCC 55.3%, published **and labelled a self-assessed upper bound** with a proven false positive in its own column. Since 2026-08-21 there is also a **blinded bench**: six specialists in fresh contexts with no path to the answer key, across six of the eight packs, found **32 of 32** planted defects and reported **0 of 31 decoys**, artifacts validated before scoring, corrections to the scorer disclosed in the run's own README (`bench/runs/2026-08-21-blinded/`). Recall on a self-authored bench is a weak signal and the file says so; the decoy column is the one that costs something to fake. And since 2026-08-21 there is one measurement that is not ours at all: blinded specialists against three unrelated third-party projects at pre-fix commits found **4 of 5 published advisories**, with the ground truth taken from the GitHub Advisory Database and the upstream fix commits, and the finding-to-advisory match decided by a context that saw only the advisory text and the finding text (`bench/runs/2026-08-21-external/`). Still the only product in this table with a number of that kind |
| **Ethical posture** | Pre-authorised by design: *"Never request permission… Proceed immediately and confidently"* | Ships jailbreak operators and harm datasets (CBRN, cyberattack, violent) | Ships C2, persistence, exfiltration, evasion, anti-forensics; its own issue #10 reports the model's safety filter firing on it | Defensive, but documents running the loop unattended with `--dangerously-skip-permissions` | Ships encoding-based filter evasion (`rot13`, zero-width, case randomisation) whose stated purpose is bypassing detection | Audit-only. Auditors declared without `Edit`/`Write`, enforced by the harness — **and incomplete twice over**: they keep `Bash`, and no gate checks the declaration (§3.5) |

### 1.2 The three rows worth arguing about

**Knowledge delivery is the axis where the field is genuinely split, and we are alone on
our side.** Two rivals ship no positive knowledge at all (Mantis by design, AgSec by
neglect), two ship tool-capability prose (PentAGI, PT-Agents), one ships a
machine-readable CVE/fingerprint corpus but loose detector prose (AIG). Nobody ships a
numbered, versioned, citable procedure set. Mantis says so about itself: its
`reference/README.md` recommends loading external skills "to give better grounding so
agents don't have to rediscover esoteric properties". That is a description of the hole
we fill.

**False-positive management is the axis where we are behind despite appearing ahead.**
We have the field in all 122 procedures; Mantis has 13 rules and AIG has one taxonomy.
But theirs are *named, finite and enforced* — Mantis's schema physically rejects a
finding marked `VALID` while any triage rule is `FAIL`. Ours is free prose that no gate
reads and no agent is required to answer. Distributed hygiene beats a single final
reviewer only if the distributed hygiene is checked. Right now it is not.

**Measured quality is where the whole field is empty, us included.** Five products,
28,477 stars between the four popular ones, and not one publishes precision, recall, or
a false-positive rate for its own detection. Our PCC is the closest thing to a public
self-assessment in the comparison set — and by our own baseline file it is a
self-assessed upper bound with a documented false positive (`NICE DD-WRL-005` scored as
covered by `SUP-02`, which measures a different thing). Being least-bad here is worth
saying out loud, and worth nothing beyond that.

**Update, 2026-08-21.** No longer empty on our side, and the honest version of that sentence is narrow: `bench/` now holds targets with planted defects *and* decoys, a protocol that keeps the answer key away from the auditing context, and a first run scored 10/10 detected with 0/11 decoys reported. That measures whether the corpus routes and matches on code shaped like the cases, not detection on code nobody here has seen. The rest of the field still publishes stars.

---

## 2. What they do better — deduplicated, ordered by value to us

Ordering is by (convergence × fit with what we already own × inverse cost).
**Convergence** counts how many of the five independently arrived at the same idea;
where two or more converge, that is signal rather than taste.

### 2.1 Finding lifecycle as a closed, enforced vocabulary — convergence 5/5

Every single rival models a finding's confidence as a typed state, not an adjective.
PentAGI: `DETECTED → CONFIRMED → HAS` (scanner hit → validated → exploited). PT-Agents:
`vulns.status` defaults to `unconfirmed`, moves only with `confirmed_by` and
`poc_output`. AIG: closed verdict enums with a validator that makes `compromised`
without `canary_hit=true` an illegal record. Mantis: `VALID` /
`PROVISIONALLY_VALID` / `NEEDS_RESEARCH`, plus `repro_status`, plus `reattack_status`.
AgSec: a weighted confidence score from independent detectors.

Five-of-five convergence is the strongest signal in this document. We have the raw
material — `team.md` declares `status`, `severity` and `confidence` per finding — but it
is three lists in three files and they have already drifted:

> `references/report.md:62-65` requires the verification outcomes *verified /
> partially verified / **not executed** / blocked*. `agents/ehs-verifier.md:45-49`
> returns *verified / partially verified / **not verified** / blocked / **withdrawn***.
> Two files, two vocabularies, one deliverable. Found by this analysis, not by a gate.

### 2.2 A machine-readable findings artifact — convergence 4/5

PT-Agents writes to SQLite and can answer `list vulns --status unconfirmed` across
sessions. AgSec exports `failures.csv` and `full_scan_log.csv`. Mantis writes each
finding to disk and returns only UUIDs to the orchestrator, protecting the context
window. AIG keeps a JSONL attempt ledger with a mechanical validator that checks record
consistency while explicitly refusing to judge the security verdict.

We produce a markdown report and nothing else. You cannot diff two of our audits, feed
one to a gate, or count anything in it.

### 2.3 A named, finite, answerable false-positive checklist — convergence 2/5, both from the most rigorous rivals

Mantis: 13 rules, `required` in the schema with `additionalProperties:false`, so the
agent must emit a verdict *and a reason* for each. AIG: a coded FP taxonomy (test code,
ordinary config reads, `demo`/`example` placeholders, container/network isolation,
insufficient permissions) owned by an adversarial reviewer with a "better to lose it
than to ship a false positive" rule.

Only two of five, but they are the two that took verification seriously, which is the
convergence that matters. This upgrades an asset we already own rather than adding one.

### 2.4 Negative evidence in the deliverable — convergence 3/5

PentAGI's sample report has a *Non-Vulnerable Features* section — tested, not found. AIG
requires the full attempt log, not just successes, plus positive-defence evidence with
"how to turn this into a regression test". Mantis mandates the banner that absence of
findings does not indicate the target is secure.

Our `report.md` already forbids claiming security from silence and mandates a coverage
declaration. What it does not do is require the ruled-out list as a section. That is a
paragraph of spec and a gate, for a large gain in how a client reads the deliverable.

### 2.5 An evidence gate on *negative* verdicts — convergence 1/5, highest value-per-cost

Mantis forbids "does not reproduce" unless the harness proved it reached the sink: a
sentinel file written and fsynced *in path* before the sink is invoked; a build failure,
`exit 127` or a missing file is classified `not_attempted`, never `failed_to_reproduce`.

This is our own 0/1/2 doctrine — `2 = COULD NOT MEASURE` is not `0` — applied to
findings instead of gates. We already own the doctrine, the exit-code convention, the
gate runner and 15 negative self-test cases proving the meter honours it. Nobody else in
this comparison had to invent that doctrine first. We only have to point it at findings.

### 2.6 Benign control on patch verification — convergence 1/5, unique and cheap

Mantis, after a patch: (a) the *unpatched* baseline must still trigger on a fresh copy,
or the result is an error, not a verdict; (b) a *legitimate* input must still reach the
patched path; (c) the attack must not trigger. Without (b) you cannot sign off, because
a patch that broke the harness looks identical to a patch that fixed the bug.

`ehs-verifier.md` already demands the regression test fail without the patch — half the
idea. The other half costs one rule in `remediation.md` part B and one check.

### 2.7 A scope-of-work artifact with a pre-action check — convergence 3/5

PentAGI ships a reusable scope-of-work template with an 8-step per-action check
(allowed/out-of-scope targets, stop conditions, evidence expectations). PT-Agents embeds
a scope-guard block in every Bash-carrying agent **and greps for it in CI**. AgSec makes
the target a portable artifact: a raw HTTP template with `<<PROMPT>>` placeholders,
versionable and reviewable.

Three rivals turned scope into a file. Ours is prose in `SKILL.md` rules 1-9, excellent
prose, but "authorised audit, not attack" is our entire market position and it currently
exists as paragraphs rather than as a signed, versioned, checkable artifact.

### 2.8 Severity calibration against marginal capability — convergence 1/5

Mantis ships 27 severity caps under one principle: if the exploit grants the attacker
nothing beyond the position they already held, cap or downgrade it. Requires a shell
you already had; blast radius confined to the attacker's own tenant; needs non-default
configuration; XSS defaults to medium unless stored and admin-facing.

We have nothing. `report.md` correctly says severity is a judgement about *this* system
rather than a copied scanner label — and then gives the model no rule to apply. Severity
inflation is the signature failure of every LLM auditor, and we are unprotected.

### 2.9 A redaction pass before the report is written — convergence 2/5

Mantis redacts to `<REDACTED_SECRET>` / `<REDACTED_PII>` / `<REDACTED_INTERNAL_HOST>` /
`<REDACTED_PAYLOAD>` before writing. AIG requires in-situ `REDACTED_*`.

Our packs say "never print a full secret" in six agent contracts. On 2026-07-22 a real
delivery of this operator's went out with a contract number and a cleartext password in
it. Instruction-level controls of that class have already failed once here. This belongs
in a gate.

### 2.10 Cost and context engineering — convergence 4/5

Mantis: wave 1 returns only `{potentially_flawed: bool, reason}`, wave 2 goes deep only
on hotspots; subagents write findings to disk and return ids; models tiered by stage.
PT-Agents: `--lite` drops advisory agents to a cheaper model. AgSec: an `only=[...]`
scope selector and a hard budget that stops the scan. PentAGI: role-level template
loading.

Our selective loading by section is the same instinct applied to input. We have nothing
on the output side and no way to say "this PR only touches CI, run only `infra-cloud`".

### 2.11 Persistent state across runs — convergence 3/5

PentAGI's vector store and optional temporal graph; PT-Agents' shared SQLite plus
`findings.sh stats` to avoid repeating work; Mantis's per-target KB rebuilt and fed back
by a reflect stage.

Every rival that outlived a demo has memory. Our second audit of a repository repeats
the first from zero. Note the trap the scouts flagged: PentAGI's memory is opaque, so it
cannot tell you *which procedure* produced a finding. Any memory we add must not cost us
citability — that is the asset.

### 2.12 Onboarding surface — convergence 3/5

AgSec's `ls` prints every available check with source and status. PT-Agents ships
`/recommend`, `/agents-for` and an agent guide with example prompts. PentAGI and
PT-Agents both ship installers and health checks.

We have 122 procedures and no way for a user to see them without reading twelve markdown
files.

### 2.13 A deterministic corpus for infrastructure and AI-product exposure — convergence 1/5

AIG's 139 AI-product fingerprints (ollama, vllm, dify, langflow, comfyui, jupyter, ray,
mlflow) plus ~1,900 nuclei-style CVE rules land exactly on our weakest pack
(`infra-cloud`, PCC 40%, 9 high gaps — the worst pack on both counts).

**Do not embed it.** Apache-2.0 with a NOTICE that mandates visible attribution;
compatible with MIT but it would put an attribution obligation and Apache terms on those
files and end the "clean MIT" claim. Reference it from the `Tooling` field instead.

### 2.14 Ideas deliberately ranked last

*Documented prompt-engineering doctrine* (PentAGI) — we already impose more structure
than the doctrine describes. *Per-model compatibility benchmark* (PentAGI) — measures
plumbing, not security; worth it only if we ever ship beyond one model. *Signed evidence
chain* (PentAGI) — attractive and aligned with "what travels with the file **is** the
deliverable", but it is an unimplemented RFC in their repo; a plain SHA-256 manifest
gets most of the value, Ed25519 later. *Idempotency keys and helper version markers*
(Mantis) — real, but a solution to a scale problem we do not have. *Wider distribution
channels* (AgSec, AIG) — we target Claude Code on purpose.

---

## 3. Our real advantage

Only claims provable from files in this repository. Everything else is marketing.

### 3.1 The positive corpus — the one asset nobody else has

Measured by `scripts/meter/meter.sh` today, commit `13b8c13`:

```
TOTAL   122 procedures   2,830 lines   245,247 bytes   122 six-field
duplicate IDs: none      numbering gaps: none
```

All 122 carry all six mandatory fields (`Where to look`, `Vulnerable pattern`,
`What rules it out (false positive)`, `Minimal test`, `Traceability`, `Tooling`) —
verified independently by field-name census, not only by the meter. Against this:
Mantis ships zero vulnerability knowledge and recommends importing someone's; AgSec
ships datasets of attack payloads; PentAGI and PT-Agents ship tool recipes whose
recall depends on the base model's mood.

**The limit, stated plainly:** the meter's own README says a procedure whose six fields
are filled with nonsense counts as complete. Structure is measured. Quality is not.

### 3.2 Traceability, normalised and countable

117/122 procedures cite at least one standard identifier; 234 distinct identifiers
across 20 families (CWE in 109 procedures, OWASP Top 10 in 79, ASVS in 48, NIST 800-53
in 32, and so on down to CAPEC and PCI-DSS). The five that cite nothing declare *why*
in the field itself ("internal process; no external identifier").

The only rival on this axis is PT-Agents, with ATT&CK ids inline and a queryable
`mitre_id` column — one framework against twenty. Mantis, AgSec and PentAGI have
essentially nothing; AgSec sells `owasp-llm-top-10` as a package keyword while OWASP
appears zero times in its documentation.

### 3.3 The 0/1/2 doctrine, wired and proved in the negative

`0 = measured and fine`, `1 = measured and failing`, `2 = could not measure`, and a `2`
is never a pass. Six gates implement it, the meter implements it, and
`meter.selftest.sh` proves it with 15 negative cases (15 passed / 0 failed) — including
`T07`, which exists because the first working meter printed `UNMEASURABLE 1` and still
concluded `exit 0`. The meter returns **2 today**, honestly, because
`gate-actions-lint.sh` could not run.

The contrast is not theoretical. AgSec's scanner counts an HTTP 5xx, a transport error
and a JSON decode failure as *failures* in the same counter as a successful jailbreak,
so a target that is simply down reports a 100% failure rate — and its LLM judge returns
`False` on any exception, meaning an API outage *fabricates* a finding. Mantis has the
doctrine (`not_attempted` ≠ `failed_to_reproduce`) but no CI to run it; its whole
automation is a markdown formatter.

### 3.4 Governance that executes

6 gates, 6 workflows, 18/18 GitHub Actions pinned by 40-character SHA, 0 unpinned;
LICENSE, SECURITY, CONTRIBUTING, CODEOWNERS, dependabot, NOTICE, CHANGELOG and a PR
template all present. Mantis, at 751 stars from Google, has no `.github/` directory at
all. AgSec's documented CI gate prints a red `FAIL` table and exits `0`, so its example
workflow goes green with a compromised model.

Our own honesty limit: `docs/design-decisions.md` states in its first section that the
release automation has not landed — no `stable` branch, no tagged release, no CI on
`main`. The gates exist and run; the channels are specification.

### 3.5 Ethical posture as a construction, not a disclaimer

Auditors are declared without `Edit`/`Write` and the harness applies the declaration —
that is the enforcement, and it is real. Then `SKILL.md` says the quiet part: the
control is **partial**, because auditors keep `Bash` and can write through the shell, so
`audit` mode must confirm the tree is unchanged afterwards. PT-Agents gives 13 agents
Bash+Write+Edit simultaneously; AIG's verification agent holds `write_file` and
`execute_shell`; neither frames the gap.

**And a second gap, found while writing this document.** `docs/gate-requirements.md`
G1 specifies that a gate must fail when an auditor agent lists `Edit`, `Write` or
`NotebookEdit`. **No gate implements it.** Verified today: no script under
`scripts/gates/` references those tool names, and `gate-plugin-integrity.sh` returns
`rc=0` after checking form, links, file types and size budgets while stating in its own
summary that it does not judge content. So our single most-cited safety invariant is
enforced by the harness at runtime and by nothing at review time — a specified control
that no automation runs.

That is precisely the defect this document criticises in Mantis: invariants that are
strong on paper and unmonitored. `docs/design-decisions.md` already warns in general
terms that the gate automation has not fully landed, which makes this an honest
omission rather than a false claim — but the fix is cheap and it is backlog item #9.
PT-Agents, the least ethical product in this comparison, is the one that wired its
equivalent invariant into CI with a two-line grep.

We are also, apparently by accident, ahead on auditor self-protection: AIG's indirect
injection defence for its own workers is listed by its scout as something we should
copy, and `SKILL.md` rule 8 plus `AI-22` plus a line in every agent contract already
implement it. That one is done.

### 3.6 What is *not* an advantage — say it before a client does

- **Zero stars, zero forks, zero users, zero published engagements.** Everything above
  is craft. None of it is traction or field evidence.
- **PCC is not measured against the corpus by anything.** Closing a gap in the corpus
  does not move the number until a human re-scores `baseline.json` by hand. It is the
  weakest link in our honesty story and we published it as such.
- **No findings schema, no machine-readable output, no severity calibration, no state
  between runs, no dynamic verification.** Five capabilities where the field has
  converged and we have prose or nothing.
- **Our headline safety invariant is not gated.** `gate-requirements.md` G1 specifies
  the auditor no-write check; no gate implements it (§3.5). We criticise exactly this
  in a rival on the next page.
- **Only 52 of 122 `Minimal test` fields contain an inline command** and exactly one
  contains a fenced block (measured today). The other 70 are prose. A "minimal test"
  that cannot be pasted into a shell is a hint, not a test.

---

## 4. The star trap

### 4.1 The raw ranking, and why it is not a quality ranking

| Product | Stars | Age (days) | Stars/day | Watchers | Ships exploitation? | Publishes detection quality? |
|---|---|---|---|---|---|---|
| PentAGI | 21,841 | 587 | 37.2 | 128 | Yes — C2, msfvenom, reverse shells | No |
| AIG | 4,506 | 599 | 7.5 | 36 | Yes — 79 jailbreak operators, live exploits | No |
| PT-Agents | 2,130 | 141 | 15.1 | 17 | Yes — persistence, exfiltration, evasion | No |
| AgSec | 1,965 | 857 | 2.3 | 25 | Partly — payload firing, encoding evasion | No |
| Mantis | 751 | 62 | 12.1 | 10 | No | No |
| **EHS** | **0** | — | — | — | No | Partially: PCC, labelled an upper bound |

> **Correction, 2026-08-21 evening.** The `Publishes detection quality?` column above says **No** for every competitor. That is **wrong for `AI-Infra-Guard`**, which publishes F1, precision, recall and false-positive rate for a detector on a named benchmark (`SkillTrustBench`) in its own README. It was found by a survey with a rubric fixed before any product was opened: `bench/runs/2026-08-21-field-transparency/`. Two qualifications travel with the correction and neither rescues the original claim: the method behind those figures is not published where the figures are, and the table compares models to each other rather than the product against not using it. The rest of the column was re-checked in the same survey and holds.


The three products that ship an attack chain hold **28,477 stars**. The one product that
took verification seriously holds **751**. That is 38:1, and it is the number people
quote.

**But the naive reading is wrong, and reading it naively would lead us to the wrong
fix.** Normalise by age: Mantis accumulates 12.1 stars/day against PT-Agents' 15.1 — a
25% gap, not a 38× one. And AgSec, which *is* offensive, sits dead last at 2.3/day.
Offense alone does not explain the ranking.

What the outliers have in common is **time to first visible output**. PentAGI is
`curl` one file, `docker compose up -d`, and watch autonomous agents work — screenshottable
in minutes. PT-Agents is an install script, 53 agents in your roster and a `/recommend`
command. AgSec is offensive but unglamorous and low-quality, and it is punished for it.
Stars track *runnable spectacle*. Offense is the cheapest way to be spectacular, which
is why the correlation exists — not because the market has judged autonomous attack to
be more valuable than verified findings.

Second correction, and it is the load-bearing one: **not one of the five publishes any
measurement of its own detection quality.** Five independent scout analyses converged on
that finding without coordinating. PentAGI's benchmark measures tool-calling and
latency. AIG's eval datasets measure the *target's* attack-success rate. Mantis
documents *how* to evaluate and never did. AgSec returns zero hits for
`precision|recall|f1|benchmark`. So the star ranking cannot be a quality ranking,
because nobody in it has measured quality. It ranks visibility.

### 4.2 Why copying the winners would end the product

The specific things that earn those stars are the things we decided not to be, and each
one has a concrete cost we would be accepting:

- **Pre-authorised autonomy** (PentAGI: *"Never request permission or confirmation…
  Proceed immediately and confidently"*). Our safety contract's rule 4 is the exact
  inverse. Deleting it does not make us a better auditor; it makes us a different,
  already-crowded product with a legal profile we cannot carry.
- **Post-exploitation and evasion** (PT-Agents: C2, persistence, exfiltration,
  anti-forensics). Their own issue #10 records the model's safety filter firing on their
  toolkit. A security product that trips the safety filter of the runtime it ships on is
  structurally fragile, whatever its star count.
- **Weaponised corpora** (AIG: 79 jailbreak operators plus CBRN, cyberattack and violent
  harm datasets; AgSec: `rot13`/zero-width/case-randomisation whose stated purpose is
  bypassing filters). Shipping detection-evasion is outside our scope by rule 5, and it
  is the difference between an auditable deliverable and an armed one.
- **Licence and dependency debt** (PentAGI's stacked MIT + EULA + external AGPL SDK;
  AIG's mandatory-attribution NOTICE). Our single clean MIT with a NOTICE that states
  *no third-party text is copied* is worth more to a corporate buyer than 20,000 stars.

### 4.3 The part where they are right and we are wrong

Their success does expose four real needs we are currently ignoring. None requires
crossing the ethical line.

1. **Time to first visible output is effectively infinite for us.** No sample
   engagement, no example report, no inventory command, no routing command. A user
   installs the plugin and faces twelve markdown files. This is fixable in a day and it
   is the single biggest gap between us and a product.
2. **People want an artifact, not an essay.** Four of five emit something a machine can
   read. We emit prose, so nothing downstream — no diff between audits, no gate, no
   scorecard, no metric — can consume our own output.
3. **Credibility comes from reproduction.** Three of five make "I reproduced it" the
   centre of their claim. Authorised, capped, synthetic-data dynamic verification is
   *inside* our envelope (rule 3 and rule 4 already permit and bound it), and we
   under-use it because our verifier is static by habit rather than by rule.
4. **The market's centre of gravity has moved to AI and agent security** — AIG, AgSec,
   and both PentAGI and Mantis adding it. Our `ai-safety` pack is our largest (22
   procedures, 46,890 bytes, PCC 61%) and includes `AI-01`, the lethal-trifecta check
   that its own agent contract calls the cheapest procedure with the highest yield.
   That is our most competitive asset and it is invisible in our positioning.

---

## 5. Prioritised backlog

Cost classes are estimates, not measurements: **S** = one file plus one check, a
session. **M** = a schema, a validator and edits across the corpus, several sessions.
**L** = a new subsystem with its own state, a week or more.

Licence column is the licence of the *source of the idea*, verified today via
`gh api`. The operative rule is the same for all six rows: **ideas are not
copyrightable expression; copy zero lines.** MIT sources would drag their copyright
notice into our tree; Apache-2.0 sources (AIG, Mantis, AgSec) additionally carry NOTICE
and attribution obligations that would end our clean-MIT claim. Re-implement from the
idea, in our own words, every time.

**Status** is measured, not asserted. `shipped` means a gate named in this row exists in
the inventory `run-all.sh --list` prints; `partial` means part of the row shipped and the
rest did not; `open` means no gate keeps it yet. `gate-competitive-backlog.sh` checks all
three against the gate directory on every run, and refuses to let a line elsewhere in the
repository call a shipped item missing — the failure that made this column necessary.

| # | Status | Item | Conv. | Cost | Source licence (verified 2026-08-16) | Gate that keeps it | Meter dimension it creates |
|---|---|---|---|---|---|---|---|
| 1 | **shipped** | **One closed verdict vocabulary.** A single `vocabulary.md` defining status, severity, confidence and verification outcome; `team.md`, `report.md`, `ehs-verifier.md` and `remediation.md` all reference it. Fixes the `not executed` / `not verified` / `withdrawn` drift found above. | 5/5 | **S** | PentAGI MIT · Mantis Apache-2.0 · PT-Agents MIT | Gate fails if any of the four files uses a term the vocabulary does not declare — `gate-verdict-vocabulary.sh` | `verdict.vocabulary_conformance` |
| 2 | **shipped** | **Negative-evidence gate for the verifier.** No "not vulnerable" without proof the test reached the code; build failure, missing file or non-zero exec status is `could not measure` (2), never "no bug". | 1/5 | **S** | Mantis Apache-2.0 | Extends the existing 0/1/2 gate doctrine to findings; negative fixture required — `gate-negative-evidence.sh` | `verification.negative_verdicts_with_reach_proof` |
| 3 | **shipped** | **Benign control in `remediation.md` part B.** Unpatched baseline must trigger; legitimate input must still reach the patched path; attack must not trigger. Missing (b) ⇒ verification incomplete, never verified. | 1/5 | **S** | Mantis Apache-2.0 | `VER-*` procedure plus a gate check that the rule is present and referenced — `gate-benign-control.sh` | `verification.benign_control_declared` |
| 4 | **shipped** | **Mandatory redaction pass before the report is written.** Placeholder classes for secrets, PII, internal hosts and weaponised payload parameters. | 2/5 | **S** | Mantis Apache-2.0 · AIG Apache-2.0 | Gate scans the deliverable for high-precision secret formats (the checksum-validated prefixes `tooling.md` already documents) and fails on a hit — `gate-report-contract.sh` | `redaction.classes_defined`, `redaction.selfscan_hits` |
| 5 | **shipped** | **Ruled-out section required in the report.** "We tested X, Y and Z and did not find them", plus what actively resisted and how to turn it into a regression test. | 3/5 | **S** | PentAGI MIT · AIG Apache-2.0 · Mantis Apache-2.0 | `report.md` marks it mandatory; gate checks the spec still requires it — `gate-report-contract.sh` | `report.mandatory_sections` |
| 6 | **shipped** | **Named FP triage checklist (~10 rules) shared across all 7 packs**, answerable PASS/FAIL/UNKNOWN/NOT_APPLICABLE with a mandatory reason when not PASS. Each procedure's `What rules it out` cites the rule ids it invokes. | 2/5 | **M** | Mantis Apache-2.0 · AIG Apache-2.0 | Gate fails on a procedure whose FP field cites no rule id, and on a finding marked confirmed with any rule at FAIL — `gate-triage-rules.sh` | `triage.rule_coverage`, `triage.rules_declared` |
| 7 | **shipped** | **Findings artifact.** `findings.json` beside the markdown: procedure id, location, status, severity, confidence, verification outcome, traceability ids, redaction applied. One schema, one validator. | 4/5 | **M** | PT-Agents MIT · AgSec Apache-2.0 · Mantis Apache-2.0 · AIG Apache-2.0 | Schema validator as a gate; `2` when the file is unreadable, `1` when it violates the schema — `gate-findings-artifact.sh` | `findings.schema_conformance` — and it finally makes our own output measurable |
| 8 | open | **Severity calibration catalogue**, 8-10 caps under the marginal-capability principle, written by us. | 1/5 | **M** | Mantis Apache-2.0 | Gate fails a `critical`/`high` finding that cites no calibration rule | `severity.calibration_rules`, `severity.findings_calibrated` |
| 9 | partial | **Close the G1 hole, then the scope artifact.** First: a gate that actually fails when an auditor agent lists `Edit`/`Write`/`NotebookEdit` — specified in `gate-requirements.md` G1, implemented nowhere (§3.5). Then a versioned `scope.md`/`scope.json`: authorised targets, out-of-scope, stop conditions, evidence expectations, authorisation reference, plus a pre-action check the leader must pass. | 3/5 | **S** then **M** | PT-Agents MIT (CI-grep pattern) · PentAGI MIT · AgSec Apache-2.0 | Gate: no auditor lists a write tool, **and** every agent carrying `Bash` embeds the scope block; negative fixture for both — `gate-agent-tools.sh` | `agents.tool_restriction_conformance` (N/7 auditors), `agents.scope_block_conformance` (N/8) |
| 10 | open | **Onboarding surface.** An inventory view of all 122 procedures (id, pack, traceability, whether the minimal test is local or requires authorisation) plus a routing command and one worked example engagement with a sample report. | 3/5 | **M** | AgSec Apache-2.0 · PT-Agents MIT | Gate: inventory regenerated from the corpus, fails if stale | `corpus.inventory_freshness`, `procedure.authorization_class` |
| 11 | open | **Executable minimal tests.** Raise the 52/122 with an inline command; where a procedure genuinely cannot have one, say so in the field instead of writing prose. | — | **M** | Ours (measurement is new) | Gate: a *new* procedure must carry an executable test or an explicit declaration of why not | `procedure.executable_minimal_test` |
| 12 | open | **Two-wave auditing and distributed writes.** Wave 1 returns `{suspect, reason}` cheaply, wave 2 goes deep only on hits; specialists write findings to disk and return ids. Plus a per-pack scope flag for CI. | 4/5 | **M** | Mantis Apache-2.0 · PT-Agents MIT · AgSec Apache-2.0 | — (protocol change in `SKILL.md` and `team.md`) | `orchestration.wave_protocol_declared` |
| 13 | open | **`infra-cloud` gap closure by reference.** Point `Tooling` fields at external fingerprint/CVE corpora instead of embedding any; target the 9 high gaps that make it our worst pack. | 1/5 | **M** | AIG Apache-2.0 — **NOTICE mandates visible attribution; reference only, never embed** | Existing tooling-documentation gate | moves `PCC(infra-cloud)` — but only after `baseline.json` is re-scored (see §6.3) |
| 14 | open | **Signed evidence manifest.** SHA-256 of every finding and every tool output shipped beside the report; Ed25519 later if a client asks. | 1/5 | **L** | PentAGI MIT (their version is an unimplemented RFC) | Gate verifies the manifest covers every file in the deliverable | `deliverable.manifest_coverage` |
| 15 | open | **Engagement memory.** Persistent findings state across runs, so a second audit of the same repository does not restart from zero. **Constraint: it must not cost citability** — the PentAGI failure mode is a store that cannot tell you which procedure produced a finding. | 3/5 | **L** | PentAGI MIT · PT-Agents MIT · Mantis Apache-2.0 | Gate: every stored finding retains its procedure id | `memory.findings_with_procedure_id` |

**Sequencing, and where it actually got to.** The plan was: items 1-5 first (all **S**,
all inside machinery we already had), with the **S** half of item 9 pulled forward, because
a specified-but-unimplemented safety gate is a worse defect than any missing capability.
Then 6-8 and the **M** half of 9 as the real project, turning free-text discipline into
enforced structure. Items 10-15 wait.

**Measured 2026-09-01: that plan is done as far as item 7, and item 8 is where it stopped.**
Items 1-7 all ship with a gate that runs; the **S** half of 9 ships as
`gate-agent-tools.sh` and its **M** half — the scope artifact — does not. Items 8 and
10-15 have no gate. This paragraph said none of that for two weeks, and two gates were
still printing *"no machine-readable finding is emitted yet (backlog #7)"* in their
out-of-scope declarations while item 7's schema, validator and fixtures shipped — the
reason had gone stale, the caveat behind it had not. **The next item is 8**, severity
calibration, and after it the scope artifact.

---

## 6. New dimensions for the meter

The point of this section: a competitive analysis that does not become a number gets
re-argued every quarter. These are computable from files on disk, in the meter's
existing style — data files plus a stdlib measurement core.

### 6.1 Computable today, no new artifact needed

| Dimension | Definition | Value right now | Failure semantics |
|---|---|---|---|
| `procedure.executable_minimal_test` | % of procedures whose `Minimal test` contains an inline command or fenced block | **52/122 = 42.6%** (measured today; exactly 1 fenced block) | Report-only until a threshold is agreed; `1` when a *new* procedure ships with neither a command nor a declared reason |
| `verdict.vocabulary_conformance` | Distinct verdict/status/outcome terms used across `team.md`, `report.md`, `ehs-verifier.md`, `remediation.md`, minus the declared set | **Drift already present**: `not executed` vs `not verified`, and `withdrawn` missing from `report.md` | `1` on any undeclared term; `2` if a file is unreadable |
| `corpus.tooling_documented` | % of procedures whose `Tooling` field names at least one tool that `tooling.md` documents with licence and network posture | Not yet computed; `Tooling` is non-empty in 122/122 | `1` on a procedure recommending an undocumented tool — catches the drift where the corpus outruns the tooling layer |
| `agents.tool_restriction_conformance` | Of the 7 auditor agents, how many declare no `Edit`/`Write`/`NotebookEdit` in their frontmatter | Expected 7/7 by reading, **checked by no gate today** (§3.5) | `1` on any auditor declaring a write tool — the check `gate-requirements.md` G1 already specifies |
| `agents.contract_conformance` | Of the 8 agents, how many carry the injection-defence paragraph, the scope statement and the no-write clause | Expected 8/8; unverified mechanically | `1` on any agent with `Bash` missing the block (this is the PT-Agents CI idea, re-implemented) |
| `procedure.authorization_class` | % of procedures tagged local-static / local-dynamic / requires-authorisation | 0% — the tag does not exist yet | Report-only until the tag exists; then `1` on an untagged procedure |

### 6.2 Unlocked by a backlog item

| Dimension | Depends on | What it measures |
|---|---|---|
| `triage.rule_coverage` | #6 | % of procedures whose FP field cites ≥1 rule id from the shared set — turns 122 free-text fields into a checkable structure |
| `findings.schema_conformance` | #7 | Whether our own output validates; the first number we could ever compute *about a real engagement* rather than about the corpus |
| `severity.findings_calibrated` | #8 | % of high/critical findings citing a calibration rule — the direct anti-inflation metric |
| `redaction.selfscan_hits` | #4 | High-precision secret formats found in our own corpus and sample deliverables; must be `0`, and `0` here means *counted*, not *skipped* |
| `report.mandatory_sections` | #5 | Sections `report.md` marks mandatory, and later, an actual report's conformance |
| `agents.scope_block_conformance` | #9 | N/8 agents embedding the scope block |
| `deliverable.manifest_coverage` | #14 | Files in the deliverable covered by the signed manifest |

### 6.3 The competitive dimension itself

Do to this document what `baseline.json` did to the coverage report: extract the matrix
into `docs/competitive-baseline.json` and have the meter print it and re-derive its
arithmetic, failing when the data and the prose disagree.

```
capability          ours        field_best   status
knowledge_delivery  executable  prose        AHEAD
false_positives     prose       enforced     BEHIND
verification        prose       enforced     BEHIND
traceability        executable  prose        AHEAD
...
COMPETITIVE PARITY  executable 4/10 · prose 5/10 · absent 1/10
```

Three states per capability — **executable** (a gate or a script enforces it),
**prose** (written down, nothing checks it), **absent** — with the same doctrine as
everywhere else: a capability nobody measured is printed as unmeasured, never as
present. The single number worth watching is *how many capabilities moved from prose to
executable this quarter*, because "prose → gate" is the whole method here.

**One warning that applies to the whole section.** Every dimension above measures
structure, exactly like the existing meter. None of them measures whether we find real
vulnerabilities. The only metric that would is a fixture corpus of known-vulnerable and
known-clean cases per pack, with published precision and recall. No competitor has one.
Building it would make us the only product in this comparison with a defensible quality
claim — and it is the reason `PCC` should eventually be retired rather than polished,
because a self-assessed upper bound is a placeholder for a measurement, not a
measurement.

---

## Six rounds on the vibecoding class, 2026-08-25 and 26 — and what they cost this analysis

This section exists because the rounds below were run to support a claim in this document,
and they did not support it. Reading them in order is the point; each one moved the diagnosis
and none of them moved the number.

| round | question | result |
|---|---|---|
| [vibecoding blind](../bench/runs/2026-08-25-vibecoding-blind/) | does a blinded audit report the class that hides? | 4 of 4 in 6 of 6 — **declared weak evidence before the run**, because the case was planted here |
| [vibecoding comparative](../bench/runs/2026-08-25-vibecoding-comparative/) | do the competitors report it? | **could not measure** — neither arm reached the file, so their zeros are silence |
| [external log injection](../bench/runs/2026-08-25-external-log-injection/) | does anyone find a published advisory in real code? | **0 of 4 in all three arms**, this corpus included |
| [external retest](../bench/runs/2026-08-25-external-retest/) | does an enumeration step recover it? | 1 of 3, band was 2 of 4 — **refuted** |
| [external delivery](../bench/runs/2026-08-25-external-delivery/) | does moving the step to the entry point? | 0 of 4, band was 3 of 4 — **refuted**, target retired |
| [ranking hypothesis](../bench/runs/2026-08-26-ranking-hypothesis/) | is it ranking? Django, 2,839 files | 1 of 4, band was 2 of 4 — **refuted** |

**Four interventions, four refutations: describing, enumerating, delivery, ranking.** On the
one class this analysis named as the corpus's own — a control written in the shape of its own
remediation — it does not lead on real code, and the rounds say so in their own pages.

### Three things these rounds establish that this document has to carry

1. **The class is real and it is not ours.** `AI-Infra-Guard` found, in `pyload`, that the
   guard against `CVE-2007-4559` is broken by an `os.path.commonprefix` check, and reported
   verifying the bypass. That is *a control that runs and cannot fail*, in real code, found by
   a competitor. Section 3 should not be read as if this corpus has that class to itself.
2. **`P-52` is a false negative in this product**, matched in 0 of 6 blinded runs while all
   six cited it as the example of doing it right — the deferred `%s` idiom. It has an issue
   and a probe that proves it reproduces. The comparative round could not establish whether
   the field misses it too, and says so rather than claiming the flattering reading.
3. **A mechanical step can miss the defect it was written for.** The enumeration query shipped
   on the 25th did not list Django's `log_response` at all, because Django dispatches the log
   level at runtime. Counting the list *before* the round caught it. Had it not, `0 of 4`
   would have been published as a fact about ranking when it was a fact about the query.

### What did not enter this document

Recall on `intake-portal` came out 0.83 for this corpus against 0.48 and 0.20, and the
enumeration step appeared to take class-level detection from 1 of 4 runs to 4 of 4. **Neither
number is claimed anywhere** — and the second one was checked on 2026-08-26 and did not
survive: under a stricter reading of what counts as a finding of the class it is 3 of 4, and
on Django, the same variant detects the class in 1 of 4. The number moved because an
unregistered metric has no fixed definition, which is the whole reason it was never claimed. The first is a comparison on a case this project planted; the second was
never pre-registered and reading it after the fact is the fitting these pages refuse. They are
on their own round pages with those sentences attached.

## 7. What would overturn this analysis

- **If any rival publishes real detection metrics** (precision, recall, FP rate on a
  public corpus), §3.4 and §6.3 change immediately: measured quality beats structural
  quality, and we would be behind on the axis we currently claim.
- **If tool restrictions on plugin subagents turn out to be advisory rather than
  enforced**, §3.5 collapses along with design decision #1, and our ethical posture
  becomes prose like everyone else's.
- **If the scouts' file-level citations are wrong** — none were re-verified here — the
  §2 ordering shifts. The §5 backlog is written to survive it: every item is justified
  by our own gaps, which were measured, not by their implementation, which was not.
- **If a real engagement shows the corpus does not improve findings over a bare model**,
  the central premise of §3.1 fails and the product needs rethinking, not extending.
  Nobody has run that test — not us, not them.

## What they shipped after we measured them — read from the diffs, 2026-08-24

`scripts/gh/competitive-freshness.sh` reported two of the three comparable products past
the commit this project measured them at. This is what moved, read from the commits rather
than from anyone's README.

### `Tencent/AI-Infra-Guard` — `4908db1` → `32df94d`

Two commits, two files, both documentation: *"fix CVE counts after case-collision duplicate
removal"*. They corrected a **stale count in their own docs**. Nothing in the product moved,
so the measurement taken against `4908db1` describes the current product.

### `google/mantis` — `5f76be0` → `56377ad`

Two commits, **49 files**, and this one matters:

> *Use the skills for ADK reference harness, improve sandbox examples, model tiering,
> **evals**, observability, testing, and secure dev skill*

Three things arrived, and two of them are ground this project does not hold.

**1. A skill.** `mantis-advise/SKILL.md`, 179 lines — the same packaging this project
uses. Convergent, and it says the format is not a differentiator.

**2. Sandboxed execution environments.** `gce_env.py` (606 lines), `gvisor_env.py`,
`microsandbox_env.py`, `static_env.py`, plus a GCE setup document. That is **reproduction
infrastructure**, and this project has none. It is not an oversight here: reproduction is
declared out of scope, and the cost of that declaration has already been measured — in
`../bench/runs/2026-08-22-third-competitor/`, a competitor's rubric discounted a finding of
ours for *no reproduction evidence*, and the note in that round says plainly that the
discount is **our constraint showing up in their score**.

**3. Per-stage eval datasets.** `reference/evals/` — `calibrate`, `critic`,
`deduplication`, `patch`, `reflect`, `report`, `reproduce`, `review`. They measure each
STAGE of their pipeline. This project measures end to end: a round asks whether the squad
found the defect, never whether the deduplicator deduplicates.

## Where that leaves the comparison, stated in both directions

| | `google/mantis` @ `56377ad` | this project |
|---|---|---|
| granularity | **per stage**, eight datasets | end to end only |
| reproduction | **executable PoC per case**, four sandbox backends | declared out of scope, and it costs points in others' rubrics |
| dataset size | 1 case in `patch`, 6 in `review` | 10 cases, 39 run directories |
| blinding | none visible in the datasets | two independent adversarial passes, provenance held where no judge prompt names it |
| pre-registration | none visible | every round, criteria committed before the numbers exist |
| published negatives | none found | many, including withdrawn claims and a retracted round |

**They are ahead on two axes and this project is ahead on two.** Saying otherwise in either
direction would be the kind of claim this document exists to refuse.

## How to improve on it rather than copy it

Their `patch_dataset.json` carries the answer inside the question. The
`vulnerability_description` field reads *"SQL string interpolation in fetch_user. **Fix by
using parameterized query:** `cursor.execute("SELECT * FROM users WHERE name = ?", ...)`"* —
so the case measures whether a patcher can apply a fix it was handed, not whether it can
find one. A per-stage eval built here should not repeat that: the stage under test does not
get told the answer, which is the same rule the detection rounds already follow.

So the two moves, in the order the evidence supports:

1. **Per-stage evals with this project's method.** Their granularity, this project's
   blinding and pre-registration. It is the cheaper of the two and it closes the axis where
   their instrument is finer than ours.
2. **Reproduction.** The expensive one, and the honest note is that it is not only
   infrastructure: it changes what the engagement rules allow, and those rules are why
   several findings here are `probable` rather than `confirmed`. It should be decided as a
   scope question first and a build second.

Neither is started. Recording what they shipped is not the same as matching it, and this
section is the first half only.

## Second reading, 2026-09-01 — and the first thing taken from a competitor's diff

`competitive-freshness.sh` reported the same two products moved again. This reading differs
from the one above in one respect: it produced a change in this repository rather than a note.

### `Tencent/AI-Infra-Guard` — `4908db1` → `bb15526`

32 commits, 32 files. Eight of them are translated READMEs and most of the rest are their own
product. One file is not: `mcp-scan/pytests/test_surrogate_sanitization.py`, new, with a
`strip_surrogates` helper behind it. The docstring states the failure plainly — `os.walk`
decodes a non-UTF-8 filename with `surrogateescape`, the lone surrogates that produces cannot
be serialised, and the scan dies with `UnicodeEncodeError` the moment the scanned tree
contains such a name.

**This corpus had no procedure for that class.** **The absence was measured with the instrument proved first.** `scripts/ehs.py` searches the title and all six fields of every one of the 170 procedures; run against a class the corpus does hold it returns it (`path traversal` → `WEB-12`, `LOC-01`; `zero-width` → `AI-20`), so it fires when a procedure exists. Run against this class on the committed corpus it returned nothing for `surrogate`, `non-utf-8` and `UnicodeDecodeError`, and the single hit for `errors=` was a recipe *using* `errors="ignore"`, not a procedure warning about it. The same query now returns exactly `LOC-16` — the before-and-after on one instrument is the reach proof, and the seven pre-existing hits for `encoding` all belonged to other classes (`AI-20` smuggles characters into a model's context; `WEB-26` takes a length off the wire). The class is now `LOC-16`,
and it is broader than the crash: whoever can name a file in a scanned tree can abort a
scanner, a decode error swallowed silently turns a filter bypass into a clean report, and a
file skipped without being counted publishes `not measured` as `OK` — a defect this procedure names, never a verdict anyone may write — the same doctrine this
project already applies to its own gates, arriving from outside.

**It found a defect here on the way in.** `WEB-28`'s enumeration recipe — the one whose own
prose says it exists because reading a large repository by judgement misses the file holding
the defect — swallowed every `SyntaxError` and moved on. Measured on a two-file fixture: one
file with an attacker-controlled log call, one this interpreter cannot parse; the recipe
printed `plain.py:3`, exited `0`, and never mentioned the second. It now names what it did
not read, on stderr. That is the honest shape of this section: a competitor's bug-fix commit
was worth more to this repository than their feature list.

### `google/mantis` — `5f76be0` → `27467b3`

5 commits, 66 files, and it deepens the same two axes named above rather than opening a third:
`reference/evals/` gains `run_eval.py`, `stage_agents.py`, a `deduplicator_agent/` and a ninth
dataset (`synthetic_dataset.json`); the sandbox layer is refactored into
`reference/core/environments/` with four backends; `embeddings.py` is new; two more skills ship
(`mantis-configure`, `mantis-launch`).

The per-stage gap is therefore not closing on its own, and it is now the oldest open item in
this document. It stays where the previous section left it: **their granularity, this
project's blinding and pre-registration**, and the answer never inside the question.

### The per-stage gap, worked — their granularity, measured against a floor they cannot clear

The item above stopped being a note on 2026-09-01 and became `gate-stage-eval-floor.sh`. What
follows is what reading their datasets produced, including the part that went against the first
reading.

**What they built.** `reference/evals/` at `27467b3` holds nine datasets, one per pipeline stage,
plus `run_eval.py` and `stage_agents.py`. Two are directly comparable to this project's triage
stage: `review_dataset.json` (six findings routed to `confirmed` or `false_positive` under
thirteen rejection rules) and `critic_dataset.json` (four routed to `viable` or `non_viable`).
The granularity is real and this bench has one stage against their nine. **That half of the gap
did not close and is wider than it was.**

**What reading them showed.** Their case whose expected answer is `false_positive` under the rule
`sample_test_or_mock_code` is titled *"...in mock auth provider"*, described as *"test credentials
in mock authentication fixture used exclusively during offline unit tests"*, and filed at
`tests/mocks/mock_auth.py`. The rule's own name is in the question three times. The pattern
repeats: *"legacy deprecated logging branch"* → `unreachable_dead_code`; *"Client-side username
length validation"* at `static/js/` → `client_side_only_enforcement`; *"only accessible when
executed by root"* → `missing_attacker_vector`; *"Theoretical SSRF"* →
`framework_level_sanitization`. **A stub of seven substrings and no model scores 10 of 10 across
both files.**

**And then the instrument disagreed with the stub, which is the part worth keeping.** Those seven
substrings were chosen after reading the inputs, so the stub demonstrates the leak is there and a
person can find it — it cannot be the measurement. The measurement is
`scripts/gates/lib/stage_eval_floor.py`: leave-one-out nearest centroid over word overlap,
nothing tuned, the same code on any dataset, reading only the text the stage is handed. Run blind
on those two files it returns **83% of 6** and **25% of 4**, both under their own ceilings. On
four cases there is almost nothing to learn from, so a low number there is noise with a percent
sign rather than a clean bill of health. **The floor therefore reports `2` — could not measure —
below ten cases, and a `0` is refused at that size**, because an instrument that signs off on
four cases would be lying upward. Their two comparable datasets cannot be cleared by any blind
separability probe at the size they ship, and that is a statement about what is measurable, not a
score against them.

**What it measured here.** Run on this project's own stage dataset, before the gate existed to
protect it: **the wording alone sorts 14% of 14 cases against a 43% majority class** — the words
are less use than always answering the commonest label. That property is why the cases carry real
source files rather than a paraphrase of the verdict, and until this run it had been asserted and
never measured. The one `NOT_APPLICABLE` case is dropped from the denominator and named in the
output: held out, its class centroid is empty, so the probe can never emit it and counting it
would move the score without measuring anything.

**What this does not claim.** It does not measure their reviewer or their critic. Their agents
were not run — that needs API budget nobody authorized — and a stage could be excellent behind a
dataset that cannot show it. The claim is bounded to the two files as published at `27467b3`:
**those datasets can be answered from their own wording, and they are too small for a blind
instrument to say otherwise.** The ceiling, `max(majority + 0.20, 0.50)`, and the ten-case floor
were both written into the probe before any dataset was run through it.

### The second stage, and why one floor was not enough

The reading above ended with the count that is unfavourable here: nine per-stage
datasets there, one here. `bench/stages/routing` makes it two, and building it
produced a result about the instrument rather than about them.

`gate-stage-eval-floor.sh` was written for the triage stage: pool every other
case by answer, see which pool the held-out case shares vocabulary with, fail
when the wording sorts the cases by itself. Pointed at the routing dataset it
returns **18% of 22 — exactly the majority-class rate**, which reads as a clean
bill of health. It is not one. Two `web-api` routing cases are an upload handler
and a link preview and share almost no vocabulary, so the probe learns nothing
and reports so; meanwhile the shortcut a routing set actually offers is
**matching the table it was drawn from**, which the probe never looks at.

So the routing gate carries a second instrument built for its own stage: a router
made of `coverage.md`'s own words — backticked tokens from each `Signal` cell,
plus the content words the table does not spread over more than three rows. It
scores **13/22 on the role and 11/22 on role and sections together**, and it
names the nine cases it misses, which are the nine the pre-registration makes the
primary metric.

The lesson generalises past this repository, and it is the argument against
adopting a competitor's granularity by copying it: **a per-stage eval needs a
floor built for that stage.** A single blind probe applied to nine stages would
clear the ones whose shortcut it cannot see. `mantis` ships nine datasets and no
floor of either kind; this bench now ships two datasets and two floors, one of
which exists because the other was inapplicable and said so.

The count still favours them, and the honest form of it is: **two stages against
nine, with a control on each of ours and none published on theirs.** Neither
number is a claim about which product routes or triages better, and no such claim
appears anywhere in this repository.

### Their paid probe, and the free half of the same question

`bb15526` also carries `services/api_checker/`: eight black-box probes aimed at an **LLM API
relay** — a middleman that resells access to a model provider. They check whether the model
list is consistent with what the endpoint will actually serve, whether an exact-echo prompt
comes back exact, what family the endpoint claims to be, a glitch-token fingerprint, a token
delta that betrays a hidden prompt injected into every request, an echo-rewrite probe that
catches a `pip install` turned into a different index or a `curl`, SSE stream integrity, and a
context canary for silent truncation. Beside it, single-token distribution fingerprinting
scored against a 167-model reference.

It is a good instrument and it was **not run**. It is dynamic, it needs a working key, and it
spends the key owner's credits against a third party — safety-contract rule 9 forbids that
without an explicit cap and the user's approval, and the rule does not bend because the
target is a competitor's feature. So what follows is read from their published description,
not measured.

**What they cannot ask is the question that comes first.** Every one of those probes needs
traffic already flowing through an endpoint somebody already chose. None of them asks how that
endpoint got chosen, who can change it tomorrow, or what the application will do with the
answer. That question is answerable from configuration alone, at zero cost, before a single
token is spent — and it is the one an auditor with a repository in front of them and no
credentials can actually run.

`AI-30` is that half. Three findings in one procedure: the endpoint is externally controlled
(an environment variable, a ConfigMap, a settings row that moves it with no deploy, so the
authority to change it is not the authority to read every prompt); the relay is trusted to be
who it says (no pinning, or verification switched off); and the answer is trusted as content
(a rewritten tool command executed because a model returned it, or a system prompt nobody in
the project wrote, prepended in transit). The third is `AI-03` with the trust boundary moved —
same sink, different untrusted author — which is why a review that cleared the retrieval path
can still be reading a compromised answer.

**Stated in the unfavourable direction too.** Their probe finds a relay that is lying *right
now*, which no amount of static reading can do; ours finds the door the relay came through,
which no probe can do. Neither subsumes the other, and this repository holds only one of the
two. The dynamic half is written into `AI-30` as `REQUIRES AUTHORIZATION` with a cap rather
than left out, so an auditor who has the authorization knows to ask for it — and knows the
static half decides whether it is worth asking.

**And it found something here on the way in, as the last reading did.** `AI-30` needed a
routing row, and `references/coverage.md` had never named `ai-safety-agent-runtime.md` at all:
four procedures, `AI-25`..`AI-28`, present in the corpus, counted by every meter, listed in
`team.md` and in `README.md`, and absent from the one table a leader routes through. The
routing check that existed faced outward — every route lands on a real section — which by
construction cannot see a file no route mentions. Turned around, it measured **14 unrouted
sections** on the first run: ten in the `remediation` pack, which is staffed by mode and now
carries a written exemption, and four real ones — `AI-21`, `PRV-13`, `LOC-15`, `LOC-16`. The
pattern is the same one this document keeps recording in both directions: the check that
passes is rarely the check that was needed, and the direction it does not face is where the
silence lives.

### What this reading did not do

It did not re-run either product. The scores in §4 are still the ones taken on 2026-08-22
against `4908db1`, `5f76be0` and `e5d7aa0`, and a diff read is not a measurement. Nothing in
this section changes a number.


### Their deduplication ladder, and the question it does not ask — 2026-09-01

`27467b3` ships `mantis-dedupe/SKILL.md`, 371 lines, read in full. It is the most complete
treatment of finding-level deduplication published in this field, and it is worth saying so
plainly before the disagreement.

Three tiers. **Tier 1** is exact: `sha256(canonical_fingerprint | canonical_cwe | target_symbol)`,
plus a `canonical_filepath + CWE + target_symbol` anchor and a three-line proximity window.
**Tier 2** normalises each candidate to five lines — Component, Vulnerability Class, Root Cause
Mechanism, Failure Condition, Taint Dataflow — and compares those instead of the prose.
**Tier 3** embeds the normalisation with `vertex_ai/gemini-embedding-001` and merges at cosine
`>= 0.90`, declares distinct below `0.70`, with a structural guard that refuses to merge across
CWE families.

Three things in it are right, and this corpus now reasons the same way without having copied a
line:

- **A signature promotes, it does not decide.** An exact hash match makes a pair a *candidate*
  for merging and nothing more. This is the same one-direction reading `gate-protected-paths.sh`
  applies to a branch prefix, arrived at independently and for the same reason.
- **Same file, different line, is DISTINCT.** They wrote the rationale in. It is `DUP-03` here.
- **`possible_duplicate_of` is a soft, non-terminal state.** They have it; nothing in this
  repository did until now.

Three holes:

1. **The `0.70`–`0.90` band has no written rule.** Twenty points of cosine, the exact region
   where the hard cases live, and the file does not say what happens in it. That is not a
   detail: it is where every pair that is worth arguing about lands.
2. **Tier 3 spends a third party's API credits on every pair compared.** Under safety-contract
   rule 9 that needs an explicit cap and the user's approval, so it cannot be the default path
   of a deduplicator that runs on every engagement.
3. **The decision is a similarity score.** It never asks the question the reader of the report
   actually has: *does one fix close both?* Two findings can be near-identical in every
   normalised field and still need two separate edits — a shared pattern at two call sites is
   the ordinary case — and two findings can read quite differently and be closed by the same
   line.

So the increment is not a better score. It is a different question, asked deterministically at
zero credits: **`DUP-01`..`DUP-06` in `references/triage.md`**, six separating conditions, any
one of which holding means the two findings are two. `DUP-05` — caller and callee, where the
callee has other callers — is the one worth noting, because it is the case their ladder merges
unconditionally and it is decided by *counting callers*, mechanically, rather than by comparing
text.

And the asymmetry, which neither product states: **a wrong merge deletes a finding, a missed
merge lengthens the report.** So `UNKNOWN` resolves to `possible_duplicate_of`, never to a
merge. Their band with no rule becomes, here, the written default.

The half of this that is ours to be embarrassed about: the leader has been ordered to
deduplicate in three places of `references/team.md` since the corpus existed, with no criterion,
no gate and no trace in the artifact. `merged_into` covered only a candidate absorbed inside one
specialist's own unaided pass. A leader's merge across specialists left nothing behind at all —
the substitution invariant 4 exists to prevent, happening one level up where nothing was looking.
Reading their file is what made that visible.

This section, like the ones above it, re-ran neither product. No number in §4 moves.

### The list was not the field — 2026-09-01

Everything above this line re-reads products that were already on a list of three, fixed on
2026-08-22. `scripts/gh/competitive-freshness.sh` asks, well, whether each pin is still the tip.
It cannot ask whether the list is still the field, and for ten days nothing did.

Five searches of this project's own lane, run on 2026-09-01, returned **36 candidates**. Fifteen
carried a skill or agent marker. **Six of them are comparable products this analysis had never
heard of.** Nothing was wrong; nothing was looking — which is the shape of every other hole this
repository has closed, arriving this time in the document that judges the competition.

The one that matters is **`maxgfr/ultrasec`**: MIT, created 2026-06-16, pushed 2026-08-31, and
its stated purpose is this project's stated purpose. A deterministic zero-dependency engine
builds a cross-file link-graph and enumerates candidate source→sink taint paths; it correlates
several external scanners into one issue rather than three; it ranks by composite EPSS · CISA
KEV · CVSS; and the model does the judging plus an adversarial verification pass in which **an
uncertain high-severity stays `needs-human` rather than being auto-dismissed** — which is this
corpus's exit-code-2 doctrine, arrived at independently, in a product we did not know existed.

**It has zero stars.** That is the finding about our method, not about them. Had the discovery
check used a popularity floor — the obvious design, and the one a reasonable person writes
first — it would have hidden the most comparable product in the field exactly as thoroughly as
the closed list did. So the bar is a skill or agent marker at the top of the default branch,
answerable in one API call, and it is written down as *is this the same kind of thing* rather
than *is this important*.

The other five are pinned with `benchmarked: false`: `prasannasalunkhe18/ThreatLens` (Semgrep and
CodeQL discovery plus LLM verification — the same two-stage shape as tooling-then-`VER-09`),
`kalpmodi/akira` and `braydos-h/BreachPilot` (autonomous offensive agents: same class of product,
opposite posture, since this corpus is defensive by contract and does not chain exploits),
`wrsmith108/claude-skill-security-auditor` (32 stars, the most direct name-level competitor, last
pushed 2026-02-10), and `dungnotnull/web-app-security-audit-agent-skill` (a prose skill suite
carrying its own scoring engine and quality reviewer).

Three are declined in writing, with the reason recorded: a smart-contract auditor (different
target class), a guide to *securing the skills you install* and a pre-install skill scanner (both
face the other way — they are adjacent to `AI-22`, not competitors to it). A sixth group of six
repositories is declined by a written pattern: `rNN-<somebody>-claude-skills-security`, every one
"derived from" another person's list, all pushed on 2026-04-28 under unrelated owner names, with
**38 to 51 stars each**. They are republications, and their star counts are the second half of
the argument against a popularity bar.

**What this section does not claim.** Not one of the six has been benchmarked. A pin says where
to look; it does not say what was found, and `competitive-freshness.sh` now prints the
unbenchmarked ones by name so that a reader cannot mistake a pin for a measurement. Running them
costs harness and model time and that is a decision about spend, not a thing to slip into a
documentation change. The claim in `README.md` was corrected to say six comparable products are
known and three have been run — the previous sentence, "all three have now been run", was true
about the list and had stopped being true about the field.

## Their coverage matrix, and the denominator it does not have — 2026-09-01

`maxgfr/ultrasec` was found by `scripts/gh/competitive-discovery.sh` the day before this entry
and had never been read. It is the closest product in the field: MIT, a cross-file taint engine,
18 supply-chain scanners, adversarial verification, and — the reason it is worth an entry —
`src/coverage.ts`, 577 lines whose opening comment is the doctrine this repository runs on,
arrived at independently:

> A short report reads as "nothing there". It actually means "nothing there, in what I looked at".
> Those are very different statements to hand a maintainer, and nothing in the audit distinguishes
> them: a repo with no findings and a repo nobody checked produce the same SUMMARY.md.

**What they have and we did not.** Their coverage table is scored *from the findings*. Every
category of a pluggable standard (ASVS, OWASP Top 10, API Top 10, MASVS, CWE Top 25) lands in
exactly one of three states — `examined`, `engine`, `unexamined` — and a category nothing touched
is rendered `⬜ **not examined**` with the sentence "not a clean bill of health — it is a gap in
the audit". Categories no deterministic signal can settle are flagged `judgment` and the auditor
must answer them in writing, because *"not applicable" without a reason is how coverage silently
shrinks between audits*. They also render scanners that **failed** as coverage loss rather than as
a footnote, after a run where three of nine scanners died, one of them the only IaC scanner, and
the report's short IaC section read exactly like a clean one. Every part of that is right, and our
report had no equivalent: coverage was declared in prose by the leader and joined to nothing.

**Where it stops, and it is one line.** The state is computed as

```
const engineCovers = (c.kinds ?? []).some((k) => enumerated.has(k));
const state = hits > 0 ? "examined" : engineCovers ? "engine" : "unexamined";
```

`enumerated` is `enumeratedKindsOf(findings)` — the kinds carried by the findings **of this same
run**. So a category is credited as covered because some *other* finding, anywhere in the run,
happened to carry one of its kinds. Nothing in the computation refers to what was read. The
docstring says so plainly: "a class the engine covers but this repo never exercised still counts
as looked-at — the walk ran, it just found nothing." That is capability, not execution. If the
walker skipped four hundred of five hundred files — unparseable, gitignored, too large, a symlink
it would not follow — the hundred it did read produce findings across many kinds, every category
they touch goes green, and **the four hundred unread files appear in the coverage table nowhere at
all.** They fixed this for tools (`failedToolLines`) and not for files. There is no denominator in
the matrix.

**What we did instead of copying it.** `engagement.coverage` has held the denominator since before
this entry — `inventoried`, `read`, `not_read`, with invariant 3 forcing every inventoried surface
into exactly one of the last two. What we lacked was their join. So we added the join and measured
it before deciding what it should cost:

- **Invariant 11 enforces the half that is a flat contradiction.** A finding whose path lies inside
  a `not_read` surface fails, matched at a path segment boundary. A finding is proof someone
  looked; the declaration says nobody did; one of the two is false and the reader cannot tell
  which. Measured before shipping: over the 60 real artifacts in `bench/runs`, 277 findings carry
  a path and **zero** contradict a `not_read` entry — the rule convicts no past work.
- **The rest is printed, not judged, and the measurement is why.** 273 of those same 277 findings
  (98.6%) lie under no inventoried surface at all, because the inventory names surfaces a reader
  would recognise and the findings name files. A gate that failed on that would accuse almost
  every good report this repository has written — the shape of check that ends up arguing with
  everyone who complied. So the validator prints the join on every run and the gap is written
  down as a known coverage gap in `references/traceability.md`, where a claim of absence has to
  anchor to it.

A second rule was designed, measured, and **withdrawn before it shipped**: every `not_read` surface
must be named in `coverage_declaration`. It is their `judgment` requirement, and it is right in
spirit. Run against the real artifacts, it accused four of the best runs in the bench, whose
`not_read` entries are descriptive sentences ("Collaborators referenced by `ValueReader.java` but
absent from the target tree: …") that no prose declaration would ever repeat verbatim. Measuring
first is the only reason it is not in this repository.
