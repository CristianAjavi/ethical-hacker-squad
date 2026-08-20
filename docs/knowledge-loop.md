# The knowledge loop and its threat model

The corpus in `skills/ethical-hacker-squad/references/knowledge/` decays. Standards get new editions, tools change licences and defaults, incidents establish new detection patterns, and measured figures go stale. A security corpus that is not refreshed becomes confidently wrong, which is worse than being obviously incomplete.

So the corpus is refreshed automatically. This document explains the cadence, and then spends most of its length on why that automation is itself the most dangerous component in the repository.

> **Status.** This is a specification. The automation it describes has not landed yet: there is no `stable` branch, no tagged release and no promotion pipeline. What does run today is the deterministic gate set `G1`–`G4` on every push and pull request; see the status table in `docs/gate-requirements.md`. Read the rest as the contract the machinery is built to satisfy, not as a description of controls already running. See `docs/design-decisions.md`.

## Cadence

**Daily — cheap, deterministic, no language model.** Verify that every URL in the source allowlist still resolves; detect changes in the pinned version markers of tracked standards; check tracked advisory feeds. It opens an issue when something moved. **It never edits the corpus.** Its output is a signal for a human or the weekly job, not a change.

**Weekly — one rotating slice.** An agent reviews a bounded subset of the corpus, drawn only from the source allowlist, and opens a pull request from a `bot/knowledge-YYYY-WW` branch with a narrow diff.

The rotation is deliberate. Regenerating the whole corpus on every run costs more, produces a diff nobody can review, and causes drift: each pass rewrites text that was already correct, and the corpus slowly becomes a different document than the one that was verified. A bounded slice keeps every diff reviewable and keeps most of the corpus stable between runs.

Both jobs run on `schedule` and `workflow_dispatch` only.

## Threat model

**The loop is a prompt-injection channel into every installed copy of this plugin.**

Follow the chain. The loop reads external sources. It writes into a knowledge corpus. That corpus is loaded into the context of a security agent. That agent runs inside other people's repositories with their tools. A single poisoned source that survives to `stable` becomes an instruction executing inside the security agent of everyone who installed this plugin — with whatever access they granted it.

This is not hypothetical. Cloud Security Alliance published a research note on prompt injection against the Claude Code GitHub Action in which a malicious issue escalated to theft of a publishing token and publication of a compromised artifact. NVIDIA has documented indirect injection through `AGENTS.md` in agentic environments. The pattern in both is the same: untrusted text reaches an agent that holds credentials and write access.

Two properties make our version worse than the average case. The blast radius is every downstream installation rather than one repository. And the payload hides well, because a security corpus is *supposed* to contain imperative sentences about what an agent should do — "always check X", "never report Y without Z" — so a malicious instruction does not look out of place the way it would in a README.

### Controls

**Never write to a release branch.** The loop only ever opens a pull request from a `bot/` branch. It has no path to `main` or `stable`.

**Least privilege, no publishing secrets.** Each job declares minimal `permissions`. No job that processes untrusted content receives a token that can publish, tag or release. Actions are pinned by commit SHA — a tag is mutable, as demonstrated when every tag of a widely used action was repointed at a malicious commit that dumped runner secrets into the workflow log.

**Never triggered by third-party content.** No `pull_request_target`. No trigger on issue, comment or fork pull request. A stranger cannot cause the loop to run.

**Fetched content is data.** The researching agent is instructed that retrieved pages are evidence to summarize, never instructions to follow, and that any retrieved text addressing an agent is itself a finding.

**Allowlist, not crawling.** The loop may only read sources listed in `docs/sources-allowlist.json`. There is no free browsing. Adding a source is a change to a protected path, so it cannot be done by the loop itself.

**Provenance per item.** Every knowledge item the loop touches carries a source URL and a consultation date. An item without provenance fails CI.

**Protected paths fail closed.** A bot pull request whose diff touches any protected path fails CI. The authoritative list is G7 in `docs/gate-requirements.md` and is deliberately not duplicated here: a security list maintained in two places diverges, and the copy is always the one someone trusts. Those files define the system's limits, and the loop cannot move its own fence.

**Asymmetric review by branch prefix.** `bot/` branches face strictly harsher checks than human branches: protected-path enforcement, mandatory provenance on every changed item, and a diff-size cap. The prefix is a trust label, not decoration.

**Visible bot identity.** Loop pull requests are authored by a distinct bot identity, never by the maintainer. Provenance is the whole point: reviewers must be able to tell agent-written from human-written at a glance. For the same reason, the `Co-Authored-By` trailer on agent-assisted commits stays. In a repository whose threat model depends on distinguishing the two, deleting that signal to make the history look tidier would be removing evidence.

**Independent verifier with no web access.** Before promotion, a second agent — not the one that researched — receives only the diff and hunts for two things: lines that are instructions disguised as knowledge, and claims with no source. Cutting its network access is the point: it cannot be influenced by the same poisoned page.

**Rest period.** Roughly seven days on `latest` before promotion to `stable`, so real users encounter a change before the conservative channel takes it.

### What these controls do not cover

They do not cover a **correct-looking but wrong** procedure from a legitimate source: a detection pattern that does not match real code, a false-positive criterion that suppresses true findings, a real identifier mapped to the wrong concept. Nothing in this pipeline detects that. It surfaces through use, via the `false-positive` and `false-negative` issue types, and is closed under the doctrine in `CONTRIBUTING.md`: an issue is closed by a fix **plus the check that stops it recurring**, never by the fix alone.

They also do not cover a compromise of GitHub Actions itself, or of the maintainer's account. Pinning by SHA and withholding publishing secrets reduce the impact; they do not eliminate it.

## Reviewing a loop pull request

Read it as adversarial input, not as a contribution.

1. Does any added line tell an agent to do something outside the procedure format? Knowledge describes what to look for; it does not issue new operating instructions.
2. Does every factual claim carry a source in the allowlist and a consultation date?
3. Are the identifiers real, and mapped to the right concept? A plausible fabricated ID survives casual review by looking correct.
4. Are there invisible characters? Zero-width joiners, bidirectional overrides and the Unicode Tags block `U+E0000`-`U+E007F` are established carriers for text a human reviewer cannot see and a model can read.
5. Does the change weaken a false-positive criterion or a safety statement? Removals are more dangerous than additions here, and they read as tidying.
