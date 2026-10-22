# Squad orders

The leader staffs only the relevant roles. Every specialist returns evidence, impact, confidence, severity, recommendation and a verification method. No specialist widens the scope or runs remote tests without authorization.

Status, severity, confidence and verification outcome are a **closed vocabulary**, defined once in [vocabulary.md](vocabulary.md). Every role uses those exact terms; a role that needs a term the vocabulary does not have reports that as a defect instead of coining one.

Each role owns exactly one knowledge pack. The pack is the role's procedural memory: the specialist loads it itself, reads only the sections its inventory justifies, and cites the procedure ID (`WEB-07`, `AI-01`, `SUP-14`) in every finding so the leader can trace it. Six packs are stored as **more than one file** for size reasons — `mobile`, `supply-chain` and `ai-safety` as three — and every file of a pack belongs to the same role and shares one procedure numbering; the first file names its siblings in its header.

| Role | Plugin subagent | Knowledge pack | Procedure IDs |
|---|---|---|---|
| Leader | — (main thread) | `traceability.md`, `tooling.md` | — |
| Web and API AppSec | `ehs-web-api` | `knowledge/web-api.md` + `knowledge/web-api-clientside-logic.md` + `knowledge/web-api-logging.md` | `WEB-01`..`WEB-28` |
| Mobile and APK | `ehs-mobile` | `knowledge/mobile.md` + `knowledge/mobile-runtime-trust.md` + `knowledge/mobile-ios.md` | `MOB-01`..`MOB-18` |
| Infrastructure and cloud | `ehs-infra-cloud` | `knowledge/infra-cloud.md` + `knowledge/infra-cloud-cicd-exposure.md` + `knowledge/infra-cloud-cicd-platforms.md` | `INF-01`..`INF-24` |
| Supply chain and secrets | `ehs-supply-chain` | `knowledge/supply-chain.md` + `knowledge/supply-chain-secrets-malware.md` + `knowledge/supply-chain-source-lifecycle.md` | `SUP-01`..`SUP-26` |
| AI, agents and chatbots | `ehs-ai-safety` | `knowledge/ai-safety.md` + `knowledge/ai-safety-data-output.md` + `knowledge/ai-safety-agent-runtime.md` | `AI-01`..`AI-30` |
| Privacy and abuse | `ehs-privacy-abuse` | `knowledge/privacy-abuse.md` | `PRV-01`..`PRV-13` |
| Local applications | `ehs-local-app` | `knowledge/local-app.md` + `knowledge/local-app-desktop-ipc.md` | `LOC-01`..`LOC-16` |
| Remediator | `ehs-remediator` | `knowledge/remediation.md` | `REM-01`..`REM-07` |
| Verifier | `ehs-verifier` | `knowledge/remediation-verification.md` | `VER-01`..`VER-09` |

## Dispatching through Claude Code

- **You are the leader** (the main thread). You inventory, select roles, split paths, deduplicate under the merge rules of `references/triage.md`, and decide priorities. You do not delegate integration or judgement.
- **Each specialist runs through the `Agent` tool.** Send independent, non-colliding specialists in a single message so they run in parallel.

### Preferred path: the plugin's own subagents

When this skill is installed as a plugin, it ships dedicated subagents whose tool access is enforced by the harness, not merely requested in a prompt:

| `subagent_type` | Role | Write access |
|---|---|---|
| `ehs-web-api` | Web, backend and API | none (read-only tools) |
| `ehs-mobile` | Android, iOS, APK | none |
| `ehs-infra-cloud` | IaC, containers, Kubernetes, CI/CD | none |
| `ehs-supply-chain` | Dependencies, provenance, secrets | none |
| `ehs-ai-safety` | LLM applications, agents, MCP, RAG | none |
| `ehs-privacy-abuse` | Personal data and product abuse | none |
| `ehs-local-app` | CLI, desktop apps, published libraries, installers | none |
| `ehs-remediator` | Applies fixes (`harden` mode only) | `Edit`, `Write` |
| `ehs-verifier` | Independent verification | none |

Auditors have no `Edit` or `Write`. That is structural but incomplete: `Bash` can write through the shell, so in `audit` mode confirm with `git status --porcelain` that the tree is unchanged, and treat a modification as a contract breach worth reporting.

Each carries its own safety contract and loads its own pack, so your prompt supplies only: scope and paths, mode, target language, assigned components, and anything specific to this engagement.

### Fallback path: no plugin agents available

Copied into `~/.claude/skills/` rather than installed as a plugin, those subagents do not exist. `references/team-roles.md` holds the fallback: what to copy into a `general-purpose` prompt, and why every constraint has to travel with it.

Never let the same agent both fix and verify.

## The order that comes before every pack

**Read your assigned files with your own judgement first, and write down what you would report with no corpus at all. Only then open your pack.**

Those labels go into `engagement.unaided_pass.candidates`, and the validator enforces what happens to them: each one ends as a finding carrying its `unaided_label`, or in `dropped` with the reason your second reading overturned your first.

**A dismissal costs what an assertion costs.** Dropping a candidate as `refuted` requires `control_at` - the `path:line` where the control that makes it harmless is enforced, on the path that reaches the sink. Dropping it as `merged` requires the id of the finding that absorbed it. This is not bookkeeping: measured on a small-context model, a reviewer short of budget does not fall silent, it refutes confidently - two runs dismissed a real unbounded allocation, one asserting the bounds were correct and one citing the length cap of a different method. Confirming cost every triage rule and dismissing cost a sentence, and that price difference is a thumb on the scale. **If you cannot point at the control, you have not refuted anything - you have run out of time, and `probable` with `what_would_settle_it` is how you say so.** `no procedure covers it` is refused as a reason - that case is `procedure: ad-hoc`, which is a first-class value precisely so nothing has to be bent to fit.

The measurement behind this rule is in `bench/`: against the same model working with no corpus at all, the packs found the same defects and no more, missed a published advisory while the right file was open, and produced *less* agreement between repeated runs than unaided review did. A pack that is opened first stops being a checklist and starts being a boundary. Opened second, it can only add.

## Leader / security-lead

Order: inventory the project, model trust boundaries, select specialists, split paths without overlap, enforce the safety contract, deduplicate results under `DUP-01`..`DUP-06` of `triage.md` — a merge is a claim, and an undecided pair is `possible_duplicate_of` rather than a merge — and decide priorities. Challenge any claim without evidence. In `harden` mode, coordinate the remediator and keep a separate verifier. Declare coverage honestly against `traceability.md`, including what was not covered.

## Role orders and the fallback dispatch

The order for each role, and how to dispatch without the plugin's subagents, are in [team-roles.md](team-roles.md). Read it only in that case: a plugin subagent carries its own order, contract and pack, and the copy would cost context for nothing.

## Return format to the leader

For each finding. The three verdict fields are closed lists from [vocabulary.md](vocabulary.md); the rest is free text.

- `ID and title`
- `procedure`: the pack procedure ID that produced it (`WEB-07`, `AI-01`, ...), or `ad-hoc` if none applies

<!-- vocabulary:use status -->
- status: `confirmed` | `probable` | `hardening` | `discarded` | `withdrawn`
<!-- /vocabulary:use -->
<!-- vocabulary:use severity -->
- severity: `critical` | `high` | `medium` | `low` | `informational`
<!-- /vocabulary:use -->
<!-- vocabulary:use confidence -->
- confidence: `high` | `medium` | `low`
<!-- /vocabulary:use -->

  A `candidate` is what you have before triage, and it is never returned as a finding. `confirmed` requires demonstrated impact and `confidence: high`; if one link is inferred, the status is `probable` and you name the link.

- `location`: file and line, component or artifact
- `evidence`: minimal trace or reproduction, no secrets
- `impact and preconditions`
- `recommended fix`
- `proposed verification`
- `traceability`: standard identifiers, verbatim and untranslated
- `triage`: every rule from `references/triage.md` that the procedure invokes, with its answer — `HOLDS`, `DOES_NOT_HOLD`, `UNKNOWN` or `NOT_APPLICABLE` — and a reason naming the artifact whenever the answer is not `DOES_NOT_HOLD`. A finding returned as `confirmed` has every invoked rule answered, none `HOLDS` and none `UNKNOWN`; an unanswered rule is not a silent pass, exactly as exit code `2` is not a green gate.
- `limits or open questions`

The leader assembles these returns into `findings.json` as specified in `references/findings-artifact.md`, and validates it before anything is delivered. A specialist returns prose; the artifact is the leader's job, because only the leader has deduplicated across specialists.

At the end of the run, each specialist also returns a **coverage declaration**: which sections of its pack it exercised, which it skipped, and why. The leader needs it to write an honest coverage section; a specialist that omits it has not finished.
